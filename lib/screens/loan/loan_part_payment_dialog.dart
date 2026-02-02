import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../models/loan.dart';
import '../../models/transaction.dart';
import '../../providers.dart';
import '../../widgets/form_utils.dart';

class LoanPartPaymentDialog extends ConsumerStatefulWidget {
  final Loan loan;

  const LoanPartPaymentDialog({super.key, required this.loan});

  @override
  ConsumerState<LoanPartPaymentDialog> createState() =>
      _LoanPartPaymentDialogState();
}

class _LoanPartPaymentDialogState extends ConsumerState<LoanPartPaymentDialog> {
  final _amountController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String? _selectedAccountId;

  @override
  void initState() {
    super.initState();
    _selectedAccountId = widget.loan.accountId;
  }

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(currencyProvider);

    return AlertDialog(
      title: const Text('Part Principal Payment'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
              'Reduce the outstanding principal. Interest on the reduced amount will decrease from the payment date.'),
          const SizedBox(height: 16),
          FormUtils.buildAmountField(
            controller: _amountController,
            currency: currency,
            label: 'Amount',
            autofocus: true,
          ),
          const SizedBox(height: 16),
          FormUtils.buildDatePickerField(
            context: context,
            selectedDate: _selectedDate,
            onDateTarget: (d) => setState(() => _selectedDate = d),
            label: 'Payment Date',
          ),
          const SizedBox(height: 16),
          ref.watch(accountsProvider).when(
                data: (accounts) {
                  return FormUtils.buildAccountSelector(
                    value: _selectedAccountId ?? 'manual',
                    accounts: accounts,
                    onChanged: (v) => setState(() => _selectedAccountId = v),
                    label: 'Paid From Account',
                    allowManual: true,
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const SizedBox(),
              ),
        ],
      ),
      actions: [
        TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context)),
        ElevatedButton(
          child: const Text('Pay Principal'),
          onPressed: () async {
            final amount = double.tryParse(_amountController.text);
            if (amount != null && amount > 0) {
              await _handlePartPayment(amount);
              if (mounted) Navigator.pop(context);
            }
          },
        )
      ],
    );
  }

  Future<void> _handlePartPayment(double amount) async {
    final storage = ref.read(storageServiceProvider);
    var loan = widget.loan;
    final accounts = ref.read(accountsProvider).value ?? [];

    // Create Prepayment Transaction
    final loanTxn = LoanTransaction(
      id: const Uuid().v4(),
      date: _selectedDate,
      amount: amount,
      type: LoanTransactionType.prepayment,
      principalComponent: amount,
      interestComponent: 0, // Assuming pure principal payment
      resultantPrincipal: loan.remainingPrincipal - amount,
    );

    loan.transactions = [...loan.transactions, loanTxn];
    loan.remainingPrincipal -= amount;

    // Record Expense Transaction
    if (_selectedAccountId != null && _selectedAccountId != 'manual') {
      final acc = accounts.firstWhere((a) => a.id == _selectedAccountId);
      final expTxn = Transaction.create(
        title: 'Loan Part Pay: ${loan.name}',
        amount: amount,
        type: TransactionType.expense,
        category: 'Loan Principal',
        accountId: _selectedAccountId!,
        date: _selectedDate,
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
  }
}
