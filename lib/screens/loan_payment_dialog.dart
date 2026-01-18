import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Added for FilteringTextInputFormatter
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../providers.dart';
import '../models/account.dart';
import '../models/loan.dart';
import '../models/transaction.dart';
import '../utils/currency_utils.dart';
import '../widgets/pure_icons.dart';
import '../theme/app_theme.dart';

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
          Row(
            children: [
              Expanded(
                child: RadioListTile<LoanTransactionType>(
                  title: const Text('EMI'),
                  value: LoanTransactionType.emi,
                  groupValue: _type,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) => setState(() {
                    _type = v!;
                    _amountController.text =
                        widget.loan.emiAmount.toStringAsFixed(2);
                  }),
                ),
              ),
              Expanded(
                child: RadioListTile<LoanTransactionType>(
                  title: const Text('Prepayment'),
                  value: LoanTransactionType.prepayment,
                  groupValue: _type,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) => setState(() {
                    _type = v!;
                    _amountController.text = '';
                  }),
                ),
              ),
            ],
          ),
          TextField(
            controller: _amountController,
            decoration: InputDecoration(
              labelText: 'Amount',
              prefixText:
                  '${CurrencyUtils.getSymbol(ref.watch(currencyProvider))} ',
              prefixStyle: AppTheme.offlineSafeTextStyle,
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))
            ],
          ),
          const SizedBox(height: 16),
          // Account Selector
          ref.watch(accountsProvider).when(
                data: (accounts) {
                  // Deduplicate by ID to be extra safe
                  final uniqueAccountsMap = <String, Account>{};
                  for (var a in accounts) {
                    uniqueAccountsMap[a.id] = a;
                  }
                  final uniqueAccounts = uniqueAccountsMap.values.toList();

                  final allIds = ['manual', ...uniqueAccounts.map((a) => a.id)];
                  final safeValue = allIds.contains(_selectedAccountId)
                      ? _selectedAccountId
                      : 'manual';

                  return DropdownButtonFormField<String>(
                    initialValue: safeValue,
                    decoration: const InputDecoration(
                      labelText: 'Payment Account (Optional)',
                      border: OutlineInputBorder(),
                      helperText: 'Select to deduct from account balance',
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                          value: 'manual', child: Text('No Account (Manual)')),
                      ...uniqueAccounts
                          .where((a) => a.type == AccountType.savings)
                          .map((a) => DropdownMenuItem<String>(
                                value: a.id,
                                child: Text(
                                    '${a.name} (${_formatAccountBalance(a)})'),
                              )),
                    ],
                    onChanged: (v) => setState(() => _selectedAccountId = v!),
                  );
                },
                loading: () => const CircularProgressIndicator(),
                error: (e, s) => Text('Error: $e'),
              ),
          const SizedBox(height: 16),
          // Date Picker
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) setState(() => _date = picked);
            },
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Payment Date',
                border: const OutlineInputBorder(),
                prefixIcon: PureIcons.calendar(),
              ),
              child: Text(
                DateFormat('yyyy-MM-dd').format(_date),
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (_type == LoanTransactionType.prepayment) ...[
            const SizedBox(height: 8),
            const Text('Prepayment Effect:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<bool>(
                    title: const Text('Reduce Tenure',
                        style: TextStyle(fontSize: 12)),
                    value: true,
                    groupValue: _reduceTenure,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (v) => setState(() => _reduceTenure = v!),
                  ),
                ),
                Expanded(
                  child: RadioListTile<bool>(
                    title: const Text('Reduce EMI',
                        style: TextStyle(fontSize: 12)),
                    value: false,
                    groupValue: _reduceTenure,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (v) => setState(() => _reduceTenure = v!),
                  ),
                ),
              ],
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

              final _ = ref.refresh(transactionsProvider);
              final __ = ref.refresh(loansProvider);

              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Payment Recorded')));
              }
            }
          },
          child: const Text('Confirm'),
        ),
      ],
    );
  }

  String _formatAccountBalance(Account a) {
    if (a.type == AccountType.creditCard && a.creditLimit != null) {
      final avail = a.creditLimit! - a.balance;
      return 'Avail: ${CurrencyUtils.getSmartFormat(avail, a.currency)}';
    }
    return 'Bal: ${CurrencyUtils.getSmartFormat(a.balance, a.currency)}';
  }
}
