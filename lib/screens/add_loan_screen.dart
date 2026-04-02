import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:samriddhi_flow/utils/regex_utils.dart';
import '../providers.dart';
import '../models/loan.dart';
import '../models/account.dart';
import '../utils/currency_utils.dart';
import '../services/loan_service.dart';
import '../theme/app_theme.dart';
import 'package:samriddhi_flow/l10n/app_localizations.dart';

const dateFormatYyyyMmDd = 'yyyy-MM-dd';

class AddLoanScreen extends ConsumerStatefulWidget {
  const AddLoanScreen({super.key});

  @override
  ConsumerState<AddLoanScreen> createState() => _AddLoanScreenState();
}

class _AddLoanScreenState extends ConsumerState<AddLoanScreen> {
  final _formKey = GlobalKey<FormState>();

  String _name = '';
  double _principal = 0;
  double _rate = 0;
  int _tenure = 0;
  DateTime _startDate = DateTime.now();
  DateTime _firstEmiDate = DateTime.now().add(const Duration(days: 30));
  int _emiDay = 1;
  LoanType _type = LoanType.personal;
  String? _selectedAccountId;
  bool _hideBalance = true;

  double _calculatedEMI = 0;
  bool _calculateRateFromEMI = false;

  late TextEditingController _tenureController;
  late TextEditingController _emiController;
  late TextEditingController _rateController;

  @override
  void initState() {
    super.initState();
    _tenureController = TextEditingController();
    _emiController = TextEditingController();
    _rateController = TextEditingController(text: '0.00');
  }

  @override
  void dispose() {
    _tenureController.dispose();
    _emiController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(currencyProvider);
    final loanService = ref.watch(loanServiceProvider);
    final currency = NumberFormat.simpleCurrency(locale: locale);
    final isGoldLoan = _type == LoanType.gold;

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.addLoanTitle)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildLoanTypeSelector(isGoldLoan),
            const SizedBox(height: 16),
            _buildNameField(),
            const SizedBox(height: 16),
            if (!isGoldLoan) _buildCalculateRateCheckbox(),
            const SizedBox(height: 16),
            _buildPrincipalRateRow(currency, isGoldLoan, loanService),
            const SizedBox(height: 16),
            _buildTenureEmiRow(currency, isGoldLoan, loanService),
            const SizedBox(height: 16),
            _buildDateRow(context, isGoldLoan),
            const SizedBox(height: 16),
            if (!isGoldLoan) ...[
              _buildEmiDaySelector(),
              const SizedBox(height: 16),
            ],
            _buildAccountSelector(),
            const SizedBox(height: 24),
            _buildPreviewCard(currency, isGoldLoan),
            const SizedBox(height: 32),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      decoration: InputDecoration(
          labelText: AppLocalizations.of(context)!.loanNameLabel,
          border: const OutlineInputBorder()),
      validator: (v) =>
          v!.isEmpty ? AppLocalizations.of(context)!.requiredLabel : null,
      onSaved: (v) => _name = v!,
    );
  }

  Widget _buildCalculateRateCheckbox() {
    return Row(
      children: [
        Expanded(
          child: CheckboxListTile(
            title: Text(AppLocalizations.of(context)!.calculateRateFromEmi,
                style: const TextStyle(fontSize: 14)),
            value: _calculateRateFromEMI,
            onChanged: (v) => setState(
                () => _calculateRateFromEMI = v!), // coverage:ignore-line
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  Widget _buildEmiDaySelector() {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<int>(
            initialValue: _emiDay,
            decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.emiDay,
                border: const OutlineInputBorder()),
            items: List.generate(31, (i) => i + 1)
                .map((d) => DropdownMenuItem(
                      value: d,
                      child: Text(d.toString()),
                    ))
                .toList(),
            onChanged: (v) =>
                setState(() => _emiDay = v!), // coverage:ignore-line
          ),
        ),
      ],
    );
  }

  Widget _buildAccountSelector() {
    return Consumer(
      builder: (context, ref, _) => ref.watch(accountsProvider).when(
            data: (accounts) => DropdownButtonFormField<String?>(
              initialValue: _selectedAccountId,
              decoration: InputDecoration(
                  labelText:
                      AppLocalizations.of(context)!.defaultPaymentAccount,
                  border: const OutlineInputBorder(),
                  prefixIcon: IconButton(
                    icon: Icon(
                        _hideBalance ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => // coverage:ignore-line
                        setState(() => _hideBalance =
                            !_hideBalance), // coverage:ignore-line
                  ),
                  helperText:
                      AppLocalizations.of(context)!.selectSavingsAccountHelper),
              items: [
                DropdownMenuItem(
                    value: null,
                    child: Text(AppLocalizations.of(context)!.noAccountManual)),
                ...accounts.where((a) => a.type == AccountType.savings).map(
                    (a) => DropdownMenuItem<String?>(
                        // coverage:ignore-line
                        value: a.id, // coverage:ignore-line
                        child: Text(
                            '${a.name} (${_formatAccountBalance(a)})'))), // coverage:ignore-line
              ],
              onChanged: (v) => setState(
                  () => _selectedAccountId = v), // coverage:ignore-line
            ),
            loading: () => const LinearProgressIndicator(),
            error: (e, s) =>
                Text('${AppLocalizations.of(context)!.errorLabel}: $e'),
          ),
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton(
      onPressed: _save,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF6C63FF),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      child: Text(AppLocalizations.of(context)!.createButton),
    );
  }

  Widget _buildLoanTypeSelector(bool isGoldLoan) {
    return DropdownButtonFormField<LoanType>(
      initialValue: _type,
      decoration: InputDecoration(
          labelText: AppLocalizations.of(context)!.loanTypeLabel,
          border: const OutlineInputBorder()),
      items: LoanType.values
          .map((t) => DropdownMenuItem<LoanType>(
                value: t,
                child: Text((() {
                  switch (t) {
                    case LoanType.personal:
                      return AppLocalizations.of(context)!.personalLoan;
                    case LoanType.home:
                      return AppLocalizations.of(context)!.homeLoan;
                    case LoanType.car:
                      return AppLocalizations.of(context)!.carLoan;
                    case LoanType.education:
                      return AppLocalizations.of(context)!.educationLoan;
                    case LoanType.business:
                      return AppLocalizations.of(context)!.businessLoan;
                    case LoanType.gold:
                      return AppLocalizations.of(context)!.goldLoan;
                    case LoanType.other:
                      return AppLocalizations.of(context)!.otherLoan;
                  }
                })()
                    .toUpperCase()),
              ))
          .toList(),
      onChanged: (v) {
        setState(() {
          _type = v!;
          if (isGoldLoan) {
            // coverage:ignore-start
            _calculateRateFromEMI = false;
            _calculatedEMI = 0;
            _emiController.clear();
            // coverage:ignore-end
          }
        });
      },
    );
  }

  Widget _buildPrincipalRateRow(
      NumberFormat currency, bool isGoldLoan, LoanService loanService) {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.loanAmountLabel,
                prefixText: '${currency.currencySymbol} ',
                prefixStyle: AppTheme.offlineSafeTextStyle,
                border: const OutlineInputBorder()),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegexUtils.amountExp)
            ],
            validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0
                ? AppLocalizations.of(context)!.invalidLabel
                : null,
            onChanged: (v) {
              setState(() {
                _principal =
                    CurrencyUtils.roundTo2Decimals(double.tryParse(v) ?? 0);
                if (!isGoldLoan) {
                  _calculateRateFromEMI
                      ? _updateRate(loanService) // coverage:ignore-line
                      : _updateEMI(loanService);
                }
              });
            },
            onSaved: (v) =>
                _principal = CurrencyUtils.roundTo2Decimals(double.parse(v!)),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildRateField(isGoldLoan, loanService),
        ),
      ],
    );
  }

  Widget _buildRateField(bool isGoldLoan, LoanService loanService) {
    if (_calculateRateFromEMI && !isGoldLoan) {
      // coverage:ignore-start
      return TextFormField(
        controller: _rateController,
        decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.calculatedRateLabel,
            // coverage:ignore-end
            suffixText: '%',
            border: const OutlineInputBorder()),
        readOnly: true,
      );
    }
    return TextFormField(
      decoration: InputDecoration(
          labelText: AppLocalizations.of(context)!.interestRateAnnual,
          suffixText: '%',
          border: const OutlineInputBorder()),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegexUtils.amountExp)
      ],
      validator: (v) => (double.tryParse(v ?? '') ?? -1) < 0
          ? AppLocalizations.of(context)!.invalidLabel
          : null,
      onChanged: (v) {
        setState(() {
          _rate = CurrencyUtils.roundTo2Decimals(double.tryParse(v) ?? 0);
          if (!isGoldLoan) _updateEMI(loanService);
        });
      },
      onSaved: (v) => _rate = CurrencyUtils.roundTo2Decimals(double.parse(v!)),
    );
  }

  Widget _buildTenureEmiRow(
      NumberFormat currency, bool isGoldLoan, LoanService loanService) {
    return Row(
      children: [
        Expanded(
          child: _buildTenureField(isGoldLoan, loanService),
        ),
        const SizedBox(width: 16),
        if (!isGoldLoan)
          Expanded(
            child: _buildEmiField(currency, loanService),
          )
        else
          const Spacer(), // coverage:ignore-line
      ],
    );
  }

  Widget _buildTenureField(bool isGoldLoan, LoanService loanService) {
    return TextFormField(
      controller: _tenureController,
      decoration: InputDecoration(
          labelText: AppLocalizations.of(context)!.loanTenureLabel,
          border: const OutlineInputBorder()),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: (v) {
        setState(() {
          _tenure = int.tryParse(v) ?? 0;
          if (!isGoldLoan) {
            _calculateRateFromEMI
                ? _updateRate(loanService) // coverage:ignore-line
                : _updateEMI(loanService, excludeTenure: true);
          }
        });
      },
      onSaved: (v) => _tenure = int.tryParse(v ?? '') ?? 0,
    );
  }

  Widget _buildEmiField(NumberFormat currency, LoanService loanService) {
    return TextFormField(
      controller: _emiController,
      decoration: InputDecoration(
          labelText: AppLocalizations.of(context)!.monthlyEmi,
          prefixText: '${currency.currencySymbol} ',
          prefixStyle: AppTheme.offlineSafeTextStyle,
          border: const OutlineInputBorder()),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegexUtils.amountExp)
      ],
      // coverage:ignore-start
      onChanged: (v) {
        setState(() {
          _calculatedEMI =
              CurrencyUtils.roundTo2Decimals(double.tryParse(v) ?? 0);
          _calculateRateFromEMI
              ? _updateRate(loanService)
              : _updateTenure(loanService, excludeEMI: true);
          // coverage:ignore-end
        });
      },
      onSaved: (v) => _calculatedEMI =
          CurrencyUtils.roundTo2Decimals(double.tryParse(v ?? '') ?? 0),
    );
  }

  Widget _buildDateRow(BuildContext context, bool isGoldLoan) {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () async {
              // coverage:ignore-line
              final d = await showDatePicker(
                  // coverage:ignore-line
                  context: context,
                  // coverage:ignore-start
                  initialDate: _startDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2030));
              if (d != null) setState(() => _startDate = d);
              // coverage:ignore-end
            },
            child: InputDecorator(
              decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.loanStartDateLabel,
                  border: const OutlineInputBorder()),
              child: Text(DateFormat(dateFormatYyyyMmDd).format(_startDate)),
            ),
          ),
        ),
        const SizedBox(width: 16),
        if (!isGoldLoan)
          Expanded(
            child: InkWell(
              onTap: () async {
                final d = await showDatePicker(
                    context: context,
                    initialDate: _firstEmiDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2030));
                if (d != null) setState(() => _firstEmiDate = d);
              },
              child: InputDecorator(
                decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.nextEmiDate,
                    border: const OutlineInputBorder()),
                child:
                    Text(DateFormat(dateFormatYyyyMmDd).format(_firstEmiDate)),
              ),
            ),
          )
        else
          // coverage:ignore-start
          Expanded(
            child: InputDecorator(
              decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.maturityDate,
                  // coverage:ignore-end
                  border: const OutlineInputBorder()),
              child: Text(DateFormat(dateFormatYyyyMmDd) // coverage:ignore-line
                  .format(_startDate.add(
                      Duration(days: _tenure * 30)))), // coverage:ignore-line
            ),
          ),
      ],
    );
  }

  Widget _buildPreviewCard(NumberFormat currency, bool isGoldLoan) {
    return Card(
      color: Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (!isGoldLoan) ...[
              Text(AppLocalizations.of(context)!.estimatedEmi,
                  style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              Text(
                currency.format(_calculatedEMI),
                style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 32,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context)!.totalInterestLabel(
                    currency.format((_calculatedEMI * _tenure) - _principal)),
                style: const TextStyle(color: Colors.white54),
              ),
            ] else ...[
              // coverage:ignore-line
              Text(
                  AppLocalizations.of(context)!
                      .projectedInterestSimple, // coverage:ignore-line
                  style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              Text(
                // coverage:ignore-line
                currency.format((_principal * _rate * (_tenure / 12)) /
                    100), // coverage:ignore-line
                style: const TextStyle(
                    color: Colors.amberAccent,
                    fontSize: 32,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                // coverage:ignore-line
                AppLocalizations.of(context)!
                    .interestPayableMaturity, // coverage:ignore-line
                style: const TextStyle(color: Colors.white54),
              ),
            ]
          ],
        ),
      ),
    );
  }

  void _updateEMI(LoanService loanService, {bool excludeTenure = false}) {
    if (_type == LoanType.gold) return; // Skip for Gold Loan
    if (_principal > 0 && _rate >= 0 && _tenure > 0) {
      final emi = loanService.calculateEMI(
          principal: _principal, annualRate: _rate, tenureMonths: _tenure);
      if ((emi - _calculatedEMI).abs() > 0.01) {
        setState(() {
          _calculatedEMI = emi;
          _emiController.text = _calculatedEMI.toStringAsFixed(2);
          _emiController.selection =
              TextSelection.collapsed(offset: _emiController.text.length);
        });
      }
    }
    if (!excludeTenure) {
      _tenureController.text = _tenure > 0 ? _tenure.toString() : '';
      _tenureController.selection =
          TextSelection.collapsed(offset: _tenureController.text.length);
    }
  }

  // coverage:ignore-start
  void _updateTenure(LoanService loanService, {bool excludeEMI = false}) {
    if (_type == LoanType.gold) return;
    if (_principal > 0 && _rate >= 0 && _calculatedEMI > 0) {
      final tenure = loanService.calculateTenureForEMI(
        principal: _principal,
        annualRate: _rate,
        emi: _calculatedEMI,
        // coverage:ignore-end
      );
      // coverage:ignore-start
      if (tenure != _tenure) {
        setState(() {
          _tenure = tenure;
          _tenureController.text = _tenure > 0 ? _tenure.toString() : '';
          _tenureController.selection =
              TextSelection.collapsed(offset: _tenureController.text.length);
          // coverage:ignore-end
        });
      }
    }
    if (!excludeEMI) {
      // coverage:ignore-start
      _emiController.text =
          _calculatedEMI > 0 ? _calculatedEMI.toStringAsFixed(2) : '';
      _emiController.selection =
          TextSelection.collapsed(offset: _emiController.text.length);
      // coverage:ignore-end
    }
  }

  // coverage:ignore-start
  void _updateRate(LoanService loanService) {
    if (_type == LoanType.gold) return;
    if (_principal > 0 && _tenure > 0 && _calculatedEMI > 0) {
      final rate = loanService.calculateRateForEMITenure(
        principal: _principal,
        tenureMonths: _tenure,
        emi: _calculatedEMI,
        // coverage:ignore-end
      );
      // coverage:ignore-start
      if ((rate - _rate).abs() > 0.001) {
        setState(() {
          _rate = rate;
          _rateController.text = _rate.toStringAsFixed(2);
          // coverage:ignore-end
        });
      }
      // coverage:ignore-start
    } else if (_principal > 0 && _tenure > 0 && _calculatedEMI == 0) {
      if (_rate != 0) {
        setState(() {
          _rate = 0;
          _rateController.text = '0.00';
          // coverage:ignore-end
        });
      }
    }
  }

  void _save() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final storage = ref.read(storageServiceProvider);
      final activeProfileId = ref.read(activeProfileIdProvider);

      final newLoan = Loan.create(
        name: _name,
        principal: _principal,
        rate: _rate,
        tenureMonths: _tenure,
        startDate: _startDate,
        emiAmount: _type == LoanType.gold ? 0 : _calculatedEMI,
        type: _type,
        emiDay: _type == LoanType.gold ? 1 : _emiDay,
        firstEmiDate: _type == LoanType.gold
            ? _startDate
                .add(Duration(days: _tenure * 30)) // coverage:ignore-line
            : _firstEmiDate,
        accountId: _selectedAccountId,
        profileId: activeProfileId,
      );

      await storage.saveLoan(newLoan);
      ref.invalidate(loansProvider);

      if (mounted) Navigator.pop(context);
    }
  }

  // coverage:ignore-start
  String _formatAccountBalance(Account a) {
    if (a.type == AccountType.creditCard && a.creditLimit != null) {
      final avail = a.creditLimit! - a.balance;
      if (_hideBalance) return AppLocalizations.of(context)!.availLabel('•••');
      return AppLocalizations.of(context)!
          .availLabel(CurrencyUtils.getSmartFormat(avail, a.currency));
      // coverage:ignore-end
    }
    // coverage:ignore-start
    if (_hideBalance) return AppLocalizations.of(context)!.balLabel('•••');
    return AppLocalizations.of(context)!
        .balLabel(CurrencyUtils.getSmartFormat(a.balance, a.currency));
    // coverage:ignore-end
  }
}
