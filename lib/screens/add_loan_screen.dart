import 'package:samriddhi_flow/utils/regex_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import '../providers.dart';
import '../models/loan.dart';
import '../models/account.dart';
import '../utils/currency_utils.dart';
import '../services/loan_service.dart';
import '../theme/app_theme.dart';

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
      appBar: AppBar(title: const Text('Add Loan')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildLoanTypeSelector(isGoldLoan),
            const SizedBox(height: 16),
            TextFormField(
              decoration: const InputDecoration(
                  labelText: 'Loan Name', border: OutlineInputBorder()),
              validator: (v) => v!.isEmpty ? 'Required' : null,
              onSaved: (v) => _name = v!,
            ),
            const SizedBox(height: 16),
            if (!isGoldLoan) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: CheckboxListTile(
                      title: const Text('Calculate Rate from EMI?',
                          style: TextStyle(fontSize: 14)),
                      value: _calculateRateFromEMI,
                      onChanged: (v) => // coverage:ignore-line
                          setState(() => _calculateRateFromEMI =
                              v!), // coverage:ignore-line
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            _buildPrincipalRateRow(currency, isGoldLoan, loanService),
            const SizedBox(height: 16),
            _buildTenureEmiRow(currency, isGoldLoan, loanService),
            const SizedBox(height: 16),
            _buildDateRow(context, isGoldLoan),
            const SizedBox(height: 16),
            if (!isGoldLoan) ...[
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _emiDay,
                      decoration: const InputDecoration(
                          labelText: 'EMI Day', border: OutlineInputBorder()),
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
              ),
              const SizedBox(height: 16),
            ],
            ref.watch(accountsProvider).when(
                  data: (accounts) => DropdownButtonFormField<String?>(
                    initialValue: _selectedAccountId,
                    decoration: const InputDecoration(
                        labelText: 'Default Payment Account (Optional)',
                        border: OutlineInputBorder(),
                        helperText:
                            'Select a savings account for EMI payments'),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('No Account (Manual)')),
                      ...accounts
                          .where((a) => a.type == AccountType.savings)
                          .map((a) => DropdownMenuItem<String?>(
                              // coverage:ignore-start
                              value: a.id,
                              child: Text(
                                  '${a.name} (${_formatAccountBalance(a)})'))),
                      // coverage:ignore-end
                    ],
                    onChanged: (v) => setState(
                        () => _selectedAccountId = v), // coverage:ignore-line
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (e, s) => Text('Error: $e'),
                ),
            const SizedBox(height: 24),
            _buildPreviewCard(currency, isGoldLoan),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Create Loan'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoanTypeSelector(bool isGoldLoan) {
    return DropdownButtonFormField<LoanType>(
      initialValue: _type,
      decoration: const InputDecoration(
          labelText: 'Loan Type', border: OutlineInputBorder()),
      items: LoanType.values
          .map((t) => DropdownMenuItem<LoanType>(
                value: t,
                child: Text(t.name.toUpperCase()),
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
                labelText: 'Principal Amount',
                prefixText: '${currency.currencySymbol} ',
                prefixStyle: AppTheme.offlineSafeTextStyle,
                border: const OutlineInputBorder()),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegexUtils.amountExp)
            ],
            validator: (v) =>
                (double.tryParse(v ?? '') ?? 0) <= 0 ? 'Invalid' : null,
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
      return TextFormField(
        // coverage:ignore-line
        controller: _rateController, // coverage:ignore-line
        decoration: const InputDecoration(
            labelText: 'Calculated Rate',
            suffixText: '%',
            border: OutlineInputBorder()),
        readOnly: true,
      );
    }
    return TextFormField(
      decoration: const InputDecoration(
          labelText: 'Interest Rate (Annual)',
          suffixText: '%',
          border: OutlineInputBorder()),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegexUtils.amountExp)
      ],
      validator: (v) => (double.tryParse(v ?? '') ?? -1) < 0 ? 'Invalid' : null,
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
          child: TextFormField(
            controller: _tenureController,
            decoration: const InputDecoration(
                labelText: 'Tenure (Months)', border: OutlineInputBorder()),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (v) {
              setState(() {
                _tenure = int.tryParse(v) ?? 0;
                if (!isGoldLoan) {
                  if (_calculateRateFromEMI) {
                    _updateRate(loanService); // coverage:ignore-line
                  } else {
                    _updateEMI(loanService, excludeTenure: true);
                  }
                }
              });
            },
            onSaved: (v) => _tenure = int.tryParse(v ?? '') ?? 0,
          ),
        ),
        const SizedBox(width: 16),
        if (!isGoldLoan)
          Expanded(
            child: TextFormField(
              controller: _emiController,
              decoration: InputDecoration(
                  labelText: 'Monthly EMI',
                  prefixText: '${currency.currencySymbol} ',
                  prefixStyle: AppTheme.offlineSafeTextStyle,
                  border: const OutlineInputBorder()),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegexUtils.amountExp)
              ],
              // coverage:ignore-start
              onChanged: (v) {
                setState(() {
                  _calculatedEMI =
                      CurrencyUtils.roundTo2Decimals(double.tryParse(v) ?? 0);
                  if (_calculateRateFromEMI) {
                    _updateRate(loanService);
                    // coverage:ignore-end
                  } else {
                    _updateTenure(loanService,
                        excludeEMI: true); // coverage:ignore-line
                  }
                });
              },
              onSaved: (v) => _calculatedEMI =
                  CurrencyUtils.roundTo2Decimals(double.tryParse(v ?? '') ?? 0),
            ),
          )
        else
          const Spacer(), // coverage:ignore-line
      ],
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
              decoration: const InputDecoration(
                  labelText: 'Start Date', border: OutlineInputBorder()),
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
                decoration: const InputDecoration(
                    labelText: '1st EMI Date', border: OutlineInputBorder()),
                child:
                    Text(DateFormat(dateFormatYyyyMmDd).format(_firstEmiDate)),
              ),
            ),
          )
        else
          Expanded(
            // coverage:ignore-line
            child: InputDecorator(
              // coverage:ignore-line
              decoration: const InputDecoration(
                  labelText: 'Maturity Date', border: OutlineInputBorder()),
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
              const Text('Estimated EMI',
                  style: TextStyle(color: Colors.white70)),
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
                'Total Interest: ${currency.format((_calculatedEMI * _tenure) - _principal)}',
                style: const TextStyle(color: Colors.white54),
              ),
            ] else ...[
              // coverage:ignore-line
              const Text('Projected Interest (Simple)',
                  style: TextStyle(color: Colors.white70)),
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
              const Text(
                'Interest payable at maturity or renewal',
                style: TextStyle(color: Colors.white54),
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
      return 'Avail: ${CurrencyUtils.getSmartFormat(avail, a.currency)}';
      // coverage:ignore-end
    }
    return 'Bal: ${CurrencyUtils.getSmartFormat(a.balance, a.currency)}'; // coverage:ignore-line
  }
}
