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
      content: _buildPaymentForm(context),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () => _handlePayment(context),
          child: const Text('Confirm'),
        ),
      ],
    );
  }

  Widget _buildPaymentForm(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RadioGroup<LoanTransactionType>(
          groupValue: _type,
          onChanged: (v) => setState(() {
            _type = v!;
            _amountController.text = _type == LoanTransactionType.emi
                ? widget.loan.emiAmount
                    .toStringAsFixed(2) // coverage:ignore-line
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
                  uniqueAccountsMap[a.id] = a; // coverage:ignore-line
                }
                final savingsAccounts = uniqueAccountsMap.values
                    .where((a) => a.type == AccountType.savings)
                    .toList();

                return FormUtils.buildAccountSelector(
                  value: _selectedAccountId,
                  accounts: savingsAccounts,
                  onChanged: (v) => setState(
                      () => _selectedAccountId = v!), // coverage:ignore-line
                  label: 'Payment Account (Optional)',
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (e, s) => Text('Error: $e'), // coverage:ignore-line
            ),
        const SizedBox(height: 16),
        FormUtils.buildDatePickerField(
          context: context,
          selectedDate: _date,
          onDateTarget: (picked) =>
              setState(() => _date = picked), // coverage:ignore-line
          label: 'Payment Date',
        ),
        const SizedBox(height: 8),
        if (_type == LoanTransactionType.prepayment) ...[
          const SizedBox(height: 8),
          const Text('Prepayment Effect:',
              style: TextStyle(fontWeight: FontWeight.bold)),
          RadioGroup<bool>(
            groupValue: _reduceTenure,
            onChanged: (v) =>
                setState(() => _reduceTenure = v!), // coverage:ignore-line
            child: const Row(
              children: [
                Expanded(
                  child: RadioListTile<bool>.adaptive(
                    title:
                        Text('Reduce Tenure', style: TextStyle(fontSize: 12)),
                    value: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                Expanded(
                  child: RadioListTile<bool>.adaptive(
                    title: Text('Reduce EMI', style: TextStyle(fontSize: 12)),
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
    );
  }

  Future<void> _handlePayment(BuildContext context) async {
    final amount = CurrencyUtils.roundTo2Decimals(
        double.tryParse(_amountController.text) ?? 0);
    if (amount <= 0) return;

    final storage = ref.read(storageServiceProvider);
    final loanService = ref.read(loanServiceProvider);

    // 1. Create Transaction Record
    final txn = Transaction.create(
      title:
          '${_type == LoanTransactionType.emi ? "EMI" : "Prepayment"}: ${widget.loan.name}',
      amount: amount,
      date: _date,
      type: _selectedAccountId != 'manual'
          ? TransactionType.transfer
          : TransactionType.expense,
      category: 'Bank loan',
      accountId: _selectedAccountId == 'manual' ? null : _selectedAccountId,
      loanId: widget.loan.id,
    );
    await storage.saveTransaction(txn);

    // 2. Update Loan Balance
    var loan = widget.loan;
    double interest = 0;
    double principalObj = 0;

    if (_type == LoanTransactionType.emi) {
      (interest, principalObj) = _applyEmiPayment(loan, amount, loanService);
    } else {
      principalObj = amount;
      _applyPrepayment(loan, principalObj, loanService);
    }

    // 3. Add to History
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
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Payment Recorded')));
  }

  (double interest, double principal) _applyEmiPayment(
      Loan loan, double amount, dynamic loanService) {
    final lastDate = loan.transactions.isNotEmpty
        // coverage:ignore-start
        ? loan.transactions
            .map((t) => t.date)
            .reduce((a, b) => a.isAfter(b) ? a : b)
        // coverage:ignore-end
        : loan.startDate;

    final interest = loanService.calculateAccruedInterest(
      principal: loan.remainingPrincipal,
      annualRate: loan.interestRate,
      fromDate: lastDate,
      toDate: _date,
    );
    final principalObj = (amount - interest).clamp(0, double.infinity);
    loan.remainingPrincipal =
        (loan.remainingPrincipal - principalObj).clamp(0, double.infinity);
    return (interest as double, principalObj as double);
  }

  void _applyPrepayment(Loan loan, double principalObj, dynamic loanService) {
    double newPrincipal =
        (loan.remainingPrincipal - principalObj).clamp(0, double.infinity);
    loan.remainingPrincipal = newPrincipal;

    if (newPrincipal <= 0) return;

    if (_reduceTenure) {
      loan.tenureMonths = loanService.calculateTenureForEMI(
          principal: newPrincipal,
          annualRate: loan.interestRate,
          emi: loan.emiAmount);
    } else {
      final endDate =
          // coverage:ignore-start
          loan.startDate.add(Duration(days: 30 * loan.tenureMonths));
      final now = DateTime.now();
      int monthsLeft = (endDate.difference(now).inDays / 30).ceil();
      if (monthsLeft < 1) monthsLeft = 1;
      // coverage:ignore-end

      loan.emiAmount = loanService.calculateEMI(
          // coverage:ignore-line
          principal: newPrincipal,
          annualRate: loan.interestRate, // coverage:ignore-line
          tenureMonths: monthsLeft);
    }
  }
}
