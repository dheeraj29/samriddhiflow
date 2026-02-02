import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../models/loan.dart';
import '../../models/transaction.dart';
import '../../providers.dart';
import '../../widgets/pure_icons.dart';

class GoldLoanInterestPaymentDialog extends ConsumerStatefulWidget {
  final Loan loan;
  final double accruedInterest;

  const GoldLoanInterestPaymentDialog({
    super.key,
    required this.loan,
    required this.accruedInterest,
  });

  @override
  ConsumerState<GoldLoanInterestPaymentDialog> createState() =>
      _GoldLoanInterestPaymentDialogState();
}

class _GoldLoanInterestPaymentDialogState
    extends ConsumerState<GoldLoanInterestPaymentDialog> {
  late TextEditingController amountController;
  final dateController = TextEditingController(
      text: DateFormat('yyyy-MM-dd').format(DateTime.now()));
  DateTime selectedDate = DateTime.now();
  String? selectedAccountId;

  @override
  void initState() {
    super.initState();
    amountController =
        TextEditingController(text: widget.accruedInterest.toStringAsFixed(2));
    selectedAccountId = widget.loan.accountId;
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider).value ?? [];

    return AlertDialog(
      title: const Text('Pay Interest & Renew'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'Pay the interest due to renew the loan tenure or simply clear dues. Principal will NOT be reduced.'),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              decoration: const InputDecoration(
                  labelText: 'Interest Amount', prefixText: '₹ '),
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
              initialValue:
                  selectedAccountId, // Changed from initialValue to value for updates
              decoration: const InputDecoration(labelText: 'Paid From Account'),
              items: [
                const DropdownMenuItem(
                    value: null, child: Text('Manual (No account)')),
                ...accounts.map(
                    (a) => DropdownMenuItem(value: a.id, child: Text(a.name))),
              ],
              onChanged: (v) => setState(() => selectedAccountId = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context)),
        ElevatedButton(
          onPressed: _handlePayAndRenew,
          child: const Text('Pay & Renew'),
        )
      ],
    );
  }

  Future<void> _handlePayAndRenew() async {
    final amount = double.tryParse(amountController.text);
    if (amount != null && amount > 0) {
      final storage = ref.read(storageServiceProvider);
      var loan = widget.loan;

      // Create Loan Transaction (Interest Only)
      final loanTxn = LoanTransaction(
        id: const Uuid().v4(),
        date: selectedDate,
        amount: amount,
        type: LoanTransactionType.emi,
        principalComponent: 0,
        interestComponent: amount,
        resultantPrincipal: loan.remainingPrincipal, // Unchanged
      );

      loan.transactions = [...loan.transactions, loanTxn];

      // Record Expense Transaction
      if (selectedAccountId != null) {
        final accounts = ref.read(accountsProvider).value ?? [];
        final acc = accounts.firstWhere((a) => a.id == selectedAccountId);
        final expTxn = Transaction.create(
          title: 'Loan Interest: ${loan.name}',
          amount: amount,
          type: TransactionType.expense,
          category: 'Loan Interest',
          accountId: selectedAccountId!,
          date: selectedDate,
          loanId: loan.id,
        );
        acc.balance -= amount;
        await storage.saveAccount(acc);
        await storage.saveTransaction(expTxn);
      }

      await storage.saveLoan(loan);
      ref.invalidate(loansProvider);
      ref.invalidate(transactionsProvider);
      ref.invalidate(accountsProvider);
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }
}

class GoldLoanCloseDialog extends ConsumerStatefulWidget {
  final Loan loan;
  final double accruedInterest;

  const GoldLoanCloseDialog({
    super.key,
    required this.loan,
    required this.accruedInterest,
  });

  @override
  ConsumerState<GoldLoanCloseDialog> createState() =>
      _GoldLoanCloseDialogState();
}

class _GoldLoanCloseDialogState extends ConsumerState<GoldLoanCloseDialog> {
  late TextEditingController amountController;
  final dateController = TextEditingController(
      text: DateFormat('yyyy-MM-dd').format(DateTime.now()));
  DateTime selectedDate = DateTime.now();
  String? selectedAccountId;

  @override
  void initState() {
    super.initState();
    final totalDue = widget.loan.remainingPrincipal + widget.accruedInterest;
    amountController = TextEditingController(text: totalDue.toStringAsFixed(2));
    selectedAccountId = widget.loan.accountId;
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider).value ?? [];

    return AlertDialog(
      title: const Text('Close Gold Loan'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                'Pay Principal (₹${widget.loan.remainingPrincipal.toStringAsFixed(2)}) + Interest (₹${widget.accruedInterest.toStringAsFixed(2)}) to close this loan.'),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              decoration: const InputDecoration(
                  labelText: 'Total Payment Amount', prefixText: '₹ '),
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
              onChanged: (v) => setState(() => selectedAccountId = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context)),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red, foregroundColor: Colors.white),
          onPressed: _handleCloseLoan,
          child: const Text('Close Loan'),
        )
      ],
    );
  }

  Future<void> _handleCloseLoan() async {
    final amount = double.tryParse(amountController.text);
    if (amount != null && amount >= widget.loan.remainingPrincipal) {
      final storage = ref.read(storageServiceProvider);
      var loan = widget.loan;

      final interestPaid = amount - loan.remainingPrincipal;

      // Close Transaction
      final loanTxn = LoanTransaction(
        id: const Uuid().v4(),
        date: selectedDate,
        amount: amount,
        type: LoanTransactionType.emi, // Essentially a bullet payment
        principalComponent: loan.remainingPrincipal,
        interestComponent: interestPaid,
        resultantPrincipal: 0,
      );

      loan.transactions = [...loan.transactions, loanTxn];
      loan.remainingPrincipal = 0;

      // Record Expense Transaction
      if (selectedAccountId != null) {
        final accounts = ref.read(accountsProvider).value ?? [];
        final acc = accounts.firstWhere((a) => a.id == selectedAccountId);
        final expTxn = Transaction.create(
          title: 'Loan Closure: ${loan.name}',
          amount: amount,
          type: TransactionType.expense,
          category: 'Loan Repayment',
          accountId: selectedAccountId!,
          date: selectedDate,
          loanId: loan.id,
        );
        acc.balance -= amount;
        await storage.saveAccount(acc);
        await storage.saveTransaction(expTxn);
      }

      await storage.saveLoan(loan);
      ref.invalidate(loansProvider);
      ref.invalidate(transactionsProvider);
      ref.invalidate(accountsProvider);
      if (mounted) {
        // Pop the dialog
        Navigator.pop(context);
        // Maybe pop screen? Let's leave it to user to go back or see 0 balance.
      }
    }
  }
}
