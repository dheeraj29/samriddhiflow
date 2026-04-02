import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:samriddhi_flow/l10n/app_localizations.dart';
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
      title: Text(AppLocalizations.of(context)!.partPrincipalPaymentTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(AppLocalizations.of(context)!.partPaymentDescription),
          const SizedBox(height: 16),
          FormUtils.buildAmountField(
            controller: _amountController,
            currency: currency,
            label: AppLocalizations.of(context)!.amountLabel,
            autofocus: true,
          ),
          const SizedBox(height: 16),
          FormUtils.buildDatePickerField(
            context: context,
            selectedDate: _selectedDate,
            onDateTarget: (d) =>
                setState(() => _selectedDate = d), // coverage:ignore-line
            label: AppLocalizations.of(context)!.paymentDateLabel,
          ),
          const SizedBox(height: 16),
          ref.watch(accountsProvider).when(
                data: (accounts) {
                  return FormUtils.buildAccountSelector(
                    value: _selectedAccountId ?? 'manual',
                    accounts: accounts,
                    onChanged: (v) => setState(
                        () => _selectedAccountId = v), // coverage:ignore-line
                    label: AppLocalizations.of(context)!.paidFromAccountLabel,
                    allowManual: true,
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const SizedBox(), // coverage:ignore-line
              ),
        ],
      ),
      actions: [
        TextButton(
            child: Text(AppLocalizations.of(context)!.cancelButton),
            onPressed: () => Navigator.pop(context)), // coverage:ignore-line
        ElevatedButton(
          child: Text(AppLocalizations.of(context)!.payPrincipalAction),
          onPressed: () async {
            final amount = double.tryParse(_amountController.text);
            if (amount != null && amount > 0) {
              await _handlePartPayment(amount);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(AppLocalizations.of(context)!
                        .partPaymentSuccessMessage)));
              }
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
        title: AppLocalizations.of(ref.context)!.loanPartPayTitle(loan.name),
        amount: amount,
        type: TransactionType.expense,
        category: AppLocalizations.of(ref.context)!.bankLoanCategory,
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
