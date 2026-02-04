import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../providers.dart';
import '../models/account.dart';
import '../models/loan.dart';
import '../models/transaction.dart';
import '../utils/currency_utils.dart';
import '../widgets/form_utils.dart';

class RecordLoanPaymentDialog extends ConsumerStatefulWidget {
  final Loan loan;
  const RecordLoanPaymentDialog({super.key, required this.loan});

  @override
  ConsumerState<RecordLoanPaymentDialog> createState() =>
      _RecordLoanPaymentDialogState();
}

class _RecordLoanPaymentDialogState
    extends ConsumerState<RecordLoanPaymentDialog> {
  final _amountController = TextEditingController();
  LoanTransactionType _type = LoanTransactionType.emi;
  DateTime _date = DateTime.now();
  String _selectedAccountId = 'manual';
  bool _reduceTenure = true;

  @override
  void initState() {
    super.initState();
    _amountController.text = widget.loan.emiAmount.toStringAsFixed(2);
    _selectedAccountId = widget.loan.accountId ?? 'manual';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Record Loan Payment'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RadioGroup<LoanTransactionType>(
            groupValue: _type,
            onChanged: (v) => setState(() {
              _type = v!;
              _amountController.text = _type == LoanTransactionType.emi
                  ? widget.loan.emiAmount.toStringAsFixed(2)
                  : '';
            }),
            child: const Row(
              children: [
                Expanded(
                  child: RadioListTile<LoanTransactionType>.adaptive(
                    title: Text('EMI'),
                    value: LoanTransactionType.emi,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                Expanded(
                  child: RadioListTile<LoanTransactionType>.adaptive(
                    title: Text('Prepayment'),
                    value: LoanTransactionType.prepayment,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
          FormUtils.buildAmountField(
            controller: _amountController,
            currency: ref.watch(currencyProvider),
          ),
          const SizedBox(height: 16),
          ref.watch(accountsProvider).when(
                data: (accounts) {
                  final uniqueAccountsMap = <String, Account>{};
                  for (var a in accounts) {
                    uniqueAccountsMap[a.id] = a;
                  }
                  final savingsAccounts = uniqueAccountsMap.values
                      .where((a) => a.type == AccountType.savings)
                      .toList();

                  return FormUtils.buildAccountSelector(
                    value: _selectedAccountId,
                    accounts: savingsAccounts,
                    onChanged: (v) => setState(() => _selectedAccountId = v!),
                    label: 'Payment Account (Optional)',
                  );
                },
                loading: () => const CircularProgressIndicator(),
                error: (e, s) => Text('Error: $e'),
              ),
          const SizedBox(height: 16),
          // Date Picker
          FormUtils.buildDatePickerField(
            context: context,
            selectedDate: _date,
            onDateTarget: (picked) => setState(() => _date = picked),
            label: 'Payment Date',
          ),
          const SizedBox(height: 8),
          if (_type == LoanTransactionType.prepayment) ...[
            const SizedBox(height: 8),
            const Text('Prepayment Effect:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            RadioGroup<bool>(
              groupValue: _reduceTenure,
              onChanged: (v) => setState(() => _reduceTenure = v!),
              child: const Row(
                children: [
                  Expanded(
                    child: RadioListTile<bool>.adaptive(
                      title: Text('Reduce Tenure',
                          style: TextStyle(fontSize: 12)),
                      value: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<bool>.adaptive(
                      title: Text('Reduce EMI',
                          style: TextStyle(fontSize: 12)),
                      value: false,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
          ],
          Text(
            _type == LoanTransactionType.emi
                ? 'Regular EMI covers Interest + Principal components.'
                : 'Prepayment reduces Principal. Choose impact above.',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () async {
            final amount = CurrencyUtils.roundTo2Decimals(
                double.tryParse(_amountController.text) ?? 0);
            if (amount > 0) {
              final storage = ref.read(storageServiceProvider);
              final loanService = ref.read(loanServiceProvider);

              // 1. Create Transaction Record (Transfer if account selected, else Expense)
              final txn = Transaction.create(
                title:
                    '${_type == LoanTransactionType.emi ? "EMI" : "Prepayment"}: ${widget.loan.name}',
                amount: amount,
                date: _date,
                type: _selectedAccountId != 'manual'
                    ? TransactionType.transfer
                    : TransactionType.expense,
                category: 'Loan',
                accountId:
                    _selectedAccountId == 'manual' ? null : _selectedAccountId,
                loanId: widget.loan.id,
              );
              await storage.saveTransaction(txn);

              // 2. Update Loan Balance using Logic
              var loan = widget.loan;
              double interest = 0;
              double principalObj = 0;

              if (_type == LoanTransactionType.emi) {
                // Calculate EXACT interest since last transaction (or start date)
                final lastDate = widget.loan.transactions.isNotEmpty
                    ? widget.loan.transactions
                        .map((t) => t.date)
                        .reduce((a, b) => a.isAfter(b) ? a : b)
                    : widget.loan.startDate;

                interest = loanService.calculateAccruedInterest(
                  principal: loan.remainingPrincipal,
                  annualRate: loan.interestRate,
                  fromDate: lastDate,
                  toDate: _date,
                );
                principalObj = (amount - interest).clamp(0, double.infinity);

                loan.remainingPrincipal =
                    (loan.remainingPrincipal - principalObj)
                        .clamp(0, double.infinity);
              } else {
                // Prepayment
                interest = 0;
                principalObj = amount;

                // logic to reduce tenure or emi
                double newPrincipal = (loan.remainingPrincipal - principalObj)
                    .clamp(0, double.infinity);
                loan.remainingPrincipal = newPrincipal;

                if (newPrincipal > 0) {
                  if (_reduceTenure) {
                    // Keep EMI, Recalculate Tenure
                    loan.tenureMonths = loanService.calculateTenureForEMI(
                        principal: newPrincipal,
                        annualRate: loan.interestRate,
                        emi: loan.emiAmount);
                  } else {
                    // Keep Tenure (remaining), Recalculate EMI
                    // Estimate remaining months based on start date vs now is tricky if we don't track it precisely.
                    // But effectively we want to spread the NEW principal over the REMAINING time.

                    // However, loan.tenureMonths is usually the original tenure.
                    // If we are strictly "keeping tenure", it means the END DATE shouldn't change.
                    // So we need to calculate remaining months from NOW to (StartDate + OriginalTenure).

                    final endDate = loan.startDate
                        .add(Duration(days: 30 * loan.tenureMonths));
                    final now = DateTime.now();
                    int monthsLeft =
                        (endDate.difference(now).inDays / 30).ceil();
                    if (monthsLeft < 1) monthsLeft = 1;

                    loan.emiAmount = loanService.calculateEMI(
                        principal: newPrincipal,
                        annualRate: loan.interestRate,
                        tenureMonths: monthsLeft);

                    // Note: We are NOT changing loan.tenureMonths here because the "Total Tenure" hasn't theoretically changed,
                    // just the EMI for the remainder.
                    // actually, if we re-calculate EMI for X months, that X becomes the effective remaining tenure.
                    // But for the sake of the loan object 'tenureMonths' usually represents the total agreed tenure.
                    // If the user wants to "Reduce Tenure", we DO change the total tenure.
                  }
                }
              }

              // Add to History (Internal Loan Transaction)
              final loanTxn = LoanTransaction(
                id: const Uuid().v4(),
                date: _date,
                amount: amount,
                type: _type,
                principalComponent: principalObj,
                interestComponent: interest,
                resultantPrincipal: loan.remainingPrincipal,
              );

              loan.transactions = [...loan.transactions, loanTxn];

              await storage.saveLoan(loan);

              ref.invalidate(transactionsProvider);
              ref.invalidate(loansProvider);

              if (!context.mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Payment Recorded')));
            }
          },
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
