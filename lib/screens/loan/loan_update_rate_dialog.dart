import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../models/loan.dart';

import '../../providers.dart';
import '../../widgets/form_utils.dart';

class LoanUpdateRateDialog extends ConsumerStatefulWidget {
  final Loan loan;

  const LoanUpdateRateDialog({super.key, required this.loan});

  @override
  ConsumerState<LoanUpdateRateDialog> createState() =>
      _LoanUpdateRateDialogState();
}

class _LoanUpdateRateDialogState extends ConsumerState<LoanUpdateRateDialog> {
  late TextEditingController _rateController;
  bool _updateTenure = false; // false = Adjust EMI, true = Adjust Tenure
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _rateController =
        TextEditingController(text: widget.loan.interestRate.toString());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Update Interest Rate'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Enter new annual interest rate.'),
          const SizedBox(height: 16),
          TextField(
            controller: _rateController,
            decoration: const InputDecoration(
                labelText: 'New Annual Rate (%)', suffixText: '%'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 16),
          FormUtils.buildDatePickerField(
            context: context,
            selectedDate: _selectedDate,
            onDateTarget: (d) => setState(() => _selectedDate = d),
            label: 'Effective Date',
          ),
          const SizedBox(height: 16),
          const Text('Recalculation Mode:',
              style: TextStyle(fontWeight: FontWeight.bold)),
          RadioGroup<bool>(
            groupValue: _updateTenure,
            onChanged: (v) {
              if (v != null) setState(() => _updateTenure = v);
            },
            child: const Column(
              children: [
                RadioListTile<bool>.adaptive(
                  title: Text('Adjust EMI'),
                  subtitle: Text(
                      'Keep Tenure constant.\nMonthly payment will change.'),
                  value: false,
                ),
                RadioListTile<bool>.adaptive(
                  title: Text('Adjust Tenure'),
                  subtitle: Text(
                      'Keep EMI constant.\nLoan duration will change.'),
                  value: true,
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () async {
            final newRate = double.tryParse(_rateController.text);
            if (newRate != null && newRate > 0) {
              await _handleUpdateInterestRate(
                loan: widget.loan,
                newRate: newRate,
                effectiveDate: _selectedDate,
                updateTenure: _updateTenure,
              );
              if (context.mounted) {
                Navigator.pop(context);
              }
            }
          },
          child: const Text('Update'),
        ),
      ],
    );
  }

  Future<void> _handleUpdateInterestRate({
    required Loan loan,
    required double newRate,
    required DateTime effectiveDate,
    required bool updateTenure,
  }) async {
    final storage = ref.read(storageServiceProvider);
    final loanService = ref.read(loanServiceProvider);

    // 1. Calculate and lock-in interest at OLD rate until effective date
    final lastDate = loan.transactions.isNotEmpty
        ? loan.transactions
            .map((t) => t.date)
            .reduce((a, b) => a.isAfter(b) ? a : b)
        : loan.startDate;

    final accruedInterest = loanService.calculateAccruedInterest(
      principal: loan.remainingPrincipal,
      annualRate: loan.interestRate,
      fromDate: lastDate,
      toDate: effectiveDate,
    );

    // 2. Record Rate Change Event with Accrued Interest
    final rateTxn = LoanTransaction(
      id: const Uuid().v4(),
      date: effectiveDate,
      amount: newRate, // New rate recorded in amount
      type: LoanTransactionType.rateChange,
      principalComponent: 0,
      interestComponent: accruedInterest,
      resultantPrincipal: loan.remainingPrincipal,
    );

    loan.transactions = [...loan.transactions, rateTxn];
    loan.interestRate = newRate;

    // 3. Recalibrate (Adjust EMI or Adjust Tenure)
    if (!updateTenure) {
      // Adjust EMI (Keep Tenure)
      final monthsPassed =
          effectiveDate.difference(loan.startDate).inDays ~/ 30;
      final remainingMonths = (loan.tenureMonths - monthsPassed).clamp(1, 600);

      loan.emiAmount = loanService.calculateEMI(
        principal: loan.remainingPrincipal,
        annualRate: newRate,
        tenureMonths: remainingMonths,
      );
    } else {
      // Adjust Tenure (Keep EMI)
      loan.tenureMonths = loanService.calculateTenureForEMI(
        principal: loan.remainingPrincipal,
        annualRate: newRate,
        emi: loan.emiAmount,
      );
    }

    await storage.saveLoan(loan);
    ref.invalidate(loansProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rate updated and loan recalibrated.')));
    }
  }
}
