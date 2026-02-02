import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../models/loan.dart';
import '../../models/transaction.dart';
import '../../providers.dart';
import '../../widgets/pure_icons.dart';

class GoldLoanInterestPaymentDialog extends ConsumerWidget {
  final Loan loan;
  final double accruedInterest;

  const GoldLoanInterestPaymentDialog({
    super.key,
    required this.loan,
    required this.accruedInterest,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _GoldLoanActionDialog(
      title: 'Pay Interest & Renew',
      description:
          'Pay the interest due to renew the loan tenure or simply clear dues. Principal will NOT be reduced.',
      initialAmount: accruedInterest,
      confirmButtonText: 'Pay & Renew',
      loanAccountId: loan.accountId,
      onConfirm: (amount, date, accountId) async {
        if (amount <= 0) return;

        // Create Loan Transaction (Interest Only)
        final loanTxn = LoanTransaction(
          id: const Uuid().v4(),
          date: date,
          amount: amount,
          type: LoanTransactionType.emi,
          principalComponent: 0,
          interestComponent: amount,
          resultantPrincipal: loan.remainingPrincipal, // Unchanged
        );

        await _recordLoanPayment(
          ref: ref,
          loan: loan,
          amount: amount,
          date: date,
          accountId: accountId,
          loanTxn: loanTxn,
          transactionTitle: 'Loan Interest: ${loan.name}',
          transactionCategory: 'Loan Interest',
        );
      },
    );
  }
}

class GoldLoanCloseDialog extends ConsumerWidget {
  final Loan loan;
  final double accruedInterest;

  const GoldLoanCloseDialog({
    super.key,
    required this.loan,
    required this.accruedInterest,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalDue = loan.remainingPrincipal + accruedInterest;

    return _GoldLoanActionDialog(
      title: 'Close Gold Loan',
      description:
          'Pay Principal (₹${loan.remainingPrincipal.toStringAsFixed(2)}) + Interest (₹${accruedInterest.toStringAsFixed(2)}) to close this loan.',
      initialAmount: totalDue,
      confirmButtonText: 'Close Loan',
      confirmButtonColor: Colors.red,
      loanAccountId: loan.accountId,
      onConfirm: (amount, date, accountId) async {
        if (amount < loan.remainingPrincipal) return; // Basic validation

        final interestPaid = amount - loan.remainingPrincipal;

        // Close Transaction
        final loanTxn = LoanTransaction(
          id: const Uuid().v4(),
          date: date,
          amount: amount,
          type: LoanTransactionType.emi, // Essentially a bullet payment
          principalComponent: loan.remainingPrincipal,
          interestComponent: interestPaid,
          resultantPrincipal: 0,
        );

        // Update loan state before saving
        loan.remainingPrincipal = 0; // Marked as closed

        await _recordLoanPayment(
          ref: ref,
          loan: loan,
          amount: amount,
          date: date,
          accountId: accountId,
          loanTxn: loanTxn,
          transactionTitle: 'Loan Closure: ${loan.name}',
          transactionCategory: 'Loan Repayment',
        );
      },
    );
  }
}

Future<void> _recordLoanPayment({
  required WidgetRef ref,
  required Loan loan,
  required double amount,
  required DateTime date,
  required String? accountId,
  required LoanTransaction loanTxn,
  required String transactionTitle,
  required String transactionCategory,
}) async {
  final storage = ref.read(storageServiceProvider);

  // 1. Add Loan Transaction
  loan.transactions = [...loan.transactions, loanTxn];

  // 2. Handle Expense Transaction
  if (accountId != null) {
    final accounts = ref.read(accountsProvider).value ?? [];
    try {
      final acc = accounts.firstWhere((a) => a.id == accountId);
      final expTxn = Transaction.create(
        title: transactionTitle,
        amount: amount,
        type: TransactionType.expense,
        category: transactionCategory,
        accountId: accountId,
        date: date,
        loanId: loan.id,
      );
      acc.balance -= amount;
      await storage.saveAccount(acc);
      await storage.saveTransaction(expTxn);
    } catch (e) {
      // Account not found or other error? logic remains safe
    }
  }

  // 3. Save Loan & Invalidate
  await storage.saveLoan(loan);
  ref.invalidate(loansProvider);
  ref.invalidate(transactionsProvider);
  ref.invalidate(accountsProvider);
}

class _GoldLoanActionDialog extends ConsumerStatefulWidget {
  final String title;
  final String description;
  final double initialAmount;
  final String confirmButtonText;
  final Color? confirmButtonColor;
  final String? loanAccountId;
  final Future<void> Function(double amount, DateTime date, String? accountId)
      onConfirm;

  const _GoldLoanActionDialog({
    required this.title,
    required this.description,
    required this.initialAmount,
    required this.confirmButtonText,
    required this.onConfirm,
    this.confirmButtonColor,
    this.loanAccountId,
  });

  @override
  ConsumerState<_GoldLoanActionDialog> createState() =>
      _GoldLoanActionDialogState();
}

class _GoldLoanActionDialogState extends ConsumerState<_GoldLoanActionDialog> {
  late TextEditingController amountController;
  final dateController = TextEditingController(
      text: DateFormat('yyyy-MM-dd').format(DateTime.now()));
  DateTime selectedDate = DateTime.now();
  String? selectedAccountId;

  @override
  void initState() {
    super.initState();
    amountController =
        TextEditingController(text: widget.initialAmount.toStringAsFixed(2));
    selectedAccountId = widget.loanAccountId;
  }

  Future<void> _handleConfirm() async {
    final amount = double.tryParse(amountController.text);
    if (amount != null) {
      await widget.onConfirm(amount, selectedDate, selectedAccountId);
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider).value ?? [];

    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.description),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              decoration: const InputDecoration(
                  labelText: 'Payment Amount', prefixText: '₹ '),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () async {
                final d = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2030));
                if (d != null) {
                  setState(() {
                    selectedDate = d;
                    dateController.text = DateFormat('yyyy-MM-dd').format(d);
                  });
                }
              },
              child: TextField(
                controller: dateController,
                decoration: InputDecoration(
                    labelText: 'Date Effective',
                    prefixIcon: PureIcons.calendar()),
                readOnly: true,
                enabled: false,
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              initialValue: selectedAccountId,
              decoration: const InputDecoration(labelText: 'Paid From Account'),
              items: [
                const DropdownMenuItem(
                    value: null, child: Text('Manual (No account)')),
                ...accounts.map(
                    (a) => DropdownMenuItem(value: a.id, child: Text(a.name))),
              ],
              onChanged: (v) => selectedAccountId = v,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context)),
        ElevatedButton(
          style: widget.confirmButtonColor != null
              ? ElevatedButton.styleFrom(
                  backgroundColor: widget.confirmButtonColor,
                  foregroundColor: Colors.white)
              : null,
          onPressed: _handleConfirm,
          child: Text(widget.confirmButtonText),
        )
      ],
    );
  }
}
