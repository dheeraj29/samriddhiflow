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
            DropdownButtonFormField<LoanType>(
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
                    _calculateRateFromEMI = false;
                    _calculatedEMI = 0;
                    _emiController.clear();
                  }
                });
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: const InputDecoration(
                  labelText: 'Loan Name', border: OutlineInputBorder()),
              validator: (v) => v!.isEmpty ? 'Required' : null,
              onSaved: (v) => _name = v!,
            ),
            const SizedBox(height: 16),
            // Hide Rate Calc Toggle for Gold Loan
            if (!isGoldLoan) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: CheckboxListTile(
                      title: const Text('Calculate Rate from EMI?',
                          style: TextStyle(fontSize: 14)),
                      value: _calculateRateFromEMI,
                      onChanged: (v) =>
                          setState(() => _calculateRateFromEMI = v!),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    decoration: InputDecoration(
                        labelText: 'Principal Amount',
                        prefixText: '${currency.currencySymbol} ',
                        prefixStyle: AppTheme.offlineSafeTextStyle,
                        border: const OutlineInputBorder()),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}$'))
                    ],
                    validator: (v) =>
                        (double.tryParse(v ?? '') ?? 0) <= 0 ? 'Invalid' : null,
                    onChanged: (v) {
                      setState(() {
                        _principal = CurrencyUtils.roundTo2Decimals(
                            double.tryParse(v) ?? 0);
                        if (!isGoldLoan) {
                          if (_calculateRateFromEMI) {
                            _updateRate(loanService);
                          } else {
                            _updateEMI(loanService);
                          }
                        }
                      });
                    },
                    onSaved: (v) => _principal =
                        CurrencyUtils.roundTo2Decimals(double.parse(v!)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _calculateRateFromEMI && !isGoldLoan
                      ? TextFormField(
                          controller: _rateController,
                          decoration: const InputDecoration(
                              labelText: 'Calculated Rate',
                              suffixText: '%',
                              border: OutlineInputBorder()),
                          readOnly: true,
                        )
                      : TextFormField(
                          decoration: const InputDecoration(
                              labelText: 'Interest Rate (Annual)',
                              suffixText: '%',
                              border: OutlineInputBorder()),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d{0,2}$'))
                          ],
                          validator: (v) => (double.tryParse(v ?? '') ?? -1) < 0
                              ? 'Invalid'
                              : null,
                          onChanged: (v) {
                            setState(() {
                              _rate = CurrencyUtils.roundTo2Decimals(
                                  double.tryParse(v) ?? 0);
                              if (!isGoldLoan) _updateEMI(loanService);
                            });
                          },
                          onSaved: (v) => _rate =
                              CurrencyUtils.roundTo2Decimals(double.parse(v!)),
                        ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _tenureController,
                    decoration: const InputDecoration(
                        labelText: 'Tenure (Months)',
                        border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (v) {
                      setState(() {
                        _tenure = int.tryParse(v) ?? 0;
                        if (!isGoldLoan) {
                          if (_calculateRateFromEMI) {
                            _updateRate(loanService);
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
                // Hide EMI Input for Gold Loan
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
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d{0,2}$'))
                      ],
                      onChanged: (v) {
                        setState(() {
                          _calculatedEMI = CurrencyUtils.roundTo2Decimals(
                              double.tryParse(v) ?? 0);
                          if (_calculateRateFromEMI) {
                            _updateRate(loanService);
                          } else {
                            _updateTenure(loanService, excludeEMI: true);
                          }
                        });
                      },
                      onSaved: (v) => _calculatedEMI =
                          CurrencyUtils.roundTo2Decimals(
                              double.tryParse(v ?? '') ?? 0),
                    ),
                  )
                else
                  // Placeholder to keep layout balanced or just empty
                  const Spacer(),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final d = await showDatePicker(
                          context: context,
                          initialDate: _startDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2030));
                      if (d != null) setState(() => _startDate = d);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                          labelText: 'Start Date',
                          border: OutlineInputBorder()),
                      child: Text(DateFormat('yyyy-MM-dd').format(_startDate)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Hide First EMI Date for Gold Loan as it's bullet repayment usually or interest only
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
                            labelText: '1st EMI Date',
                            border: OutlineInputBorder()),
                        child: Text(
                            DateFormat('yyyy-MM-dd').format(_firstEmiDate)),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: InputDecorator(
                      decoration: const InputDecoration(
                          labelText: 'Maturity Date',
                          border: OutlineInputBorder()),
                      child: Text(DateFormat('yyyy-MM-dd').format(
                          _startDate.add(Duration(days: _tenure * 30)))),
                    ),
                  ),
              ],
            ),
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
                      onChanged: (v) => setState(() => _emiDay = v!),
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
                              value: a.id,
                              child: Text(
                                  '${a.name} (${_formatAccountBalance(a)})'))),
                    ],
                    onChanged: (v) => setState(() => _selectedAccountId = v),
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (e, s) => Text('Error: $e'),
                ),
            const SizedBox(height: 24),
            // Preview Card
            Card(
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
                      const Text('Projected Interest (Simple)',
                          style: TextStyle(color: Colors.white70)),
                      const SizedBox(height: 8),
                      Text(
                        // Simple Interest for Gold Loan: P * R * T / 100
                        // T is in months, so T/12 years
                        currency.format(
                            (_principal * _rate * (_tenure / 12)) / 100),
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
            ),

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

  void _updateTenure(LoanService loanService, {bool excludeEMI = false}) {
    if (_type == LoanType.gold) return;
    if (_principal > 0 && _rate >= 0 && _calculatedEMI > 0) {
      final tenure = loanService.calculateTenureForEMI(
        principal: _principal,
        annualRate: _rate,
        emi: _calculatedEMI,
      );
      if (tenure != _tenure) {
        setState(() {
          _tenure = tenure;
          _tenureController.text = _tenure > 0 ? _tenure.toString() : '';
          _tenureController.selection =
              TextSelection.collapsed(offset: _tenureController.text.length);
        });
      }
    }
    if (!excludeEMI) {
      _emiController.text =
          _calculatedEMI > 0 ? _calculatedEMI.toStringAsFixed(2) : '';
      _emiController.selection =
          TextSelection.collapsed(offset: _emiController.text.length);
    }
  }

  void _updateRate(LoanService loanService) {
    if (_type == LoanType.gold) return;
    if (_principal > 0 && _tenure > 0 && _calculatedEMI > 0) {
      final rate = loanService.calculateRateForEMITenure(
        principal: _principal,
        tenureMonths: _tenure,
        emi: _calculatedEMI,
      );
      if ((rate - _rate).abs() > 0.001) {
        setState(() {
          _rate = rate;
          _rateController.text = _rate.toStringAsFixed(2);
        });
      }
    } else if (_principal > 0 && _tenure > 0 && _calculatedEMI == 0) {
      if (_rate != 0) {
        setState(() {
          _rate = 0;
          _rateController.text = '0.00';
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
            ? _startDate.add(Duration(days: _tenure * 30))
            : _firstEmiDate,
        accountId: _selectedAccountId,
        profileId: activeProfileId,
      );

      await storage.saveLoan(newLoan);
      ref.invalidate(loansProvider);

      if (mounted) Navigator.pop(context);
    }
  }

  String _formatAccountBalance(Account a) {
    if (a.type == AccountType.creditCard && a.creditLimit != null) {
      final avail = a.creditLimit! - a.balance;
      return 'Avail: ${CurrencyUtils.getSmartFormat(avail, a.currency)}';
    }
    return 'Bal: ${CurrencyUtils.getSmartFormat(a.balance, a.currency)}';
  }
}
