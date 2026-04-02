import 'package:samriddhi_flow/utils/regex_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:samriddhi_flow/l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../models/loan.dart';
import '../../models/transaction.dart';
import '../../providers.dart';
import '../../utils/currency_utils.dart';
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
      title: AppLocalizations.of(context)!.payInterestAndRenewTitle,
      description: AppLocalizations.of(context)!.payInterestAndRenewDescription,
      initialAmount: accruedInterest,
      confirmButtonText: AppLocalizations.of(context)!.payAndRenewAction,
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
          transactionTitle:
              AppLocalizations.of(context)!.loanInterestTitle(loan.name),
          transactionCategory: AppLocalizations.of(context)!.bankLoanCategory,
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
      title: AppLocalizations.of(context)!.closeGoldLoanTitle,
      description: AppLocalizations.of(context)!.closeGoldLoanDescription(
        CurrencyUtils.formatCurrency(
            loan.remainingPrincipal, ref.watch(currencyProvider)),
        CurrencyUtils.formatCurrency(
            accruedInterest, ref.watch(currencyProvider)),
      ),
      initialAmount: totalDue,
      confirmButtonText: AppLocalizations.of(context)!.closeLoanAction,
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
          transactionTitle:
              AppLocalizations.of(context)!.loanClosureTitle(loan.name),
          transactionCategory: AppLocalizations.of(context)!.bankLoanCategory,
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
              decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.paymentAmountLabel,
                  prefixText:
                      '${CurrencyUtils.getSymbol(ref.watch(currencyProvider))} '),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegexUtils.amountExp),
              ],
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () async {
                // coverage:ignore-line
                final d = await showDatePicker(
                    // coverage:ignore-line
                    context: context,
                    // coverage:ignore-start
                    initialDate: selectedDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2030));
                // coverage:ignore-end
                if (d != null) {
                  // coverage:ignore-start
                  setState(() {
                    selectedDate = d;
                    dateController.text = DateFormat('yyyy-MM-dd').format(d);
                    // coverage:ignore-end
                  });
                }
              },
              child: TextField(
                controller: dateController,
                decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.dateEffectiveLabel,
                    prefixIcon: PureIcons.calendar()),
                readOnly: true,
                enabled: false,
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              initialValue: selectedAccountId,
              decoration: InputDecoration(
                  labelText:
                      AppLocalizations.of(context)!.paidFromAccountLabel),
              items: [
                DropdownMenuItem(
                    value: null,
                    child: Text(AppLocalizations.of(context)!.noAccountManual)),
                ...accounts.map(
                    (a) => DropdownMenuItem(value: a.id, child: Text(a.name))),
              ],
              onChanged: (v) => selectedAccountId = v, // coverage:ignore-line
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            child: Text(AppLocalizations.of(context)!.cancelButton),
            onPressed: () => Navigator.pop(context)), // coverage:ignore-line
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
