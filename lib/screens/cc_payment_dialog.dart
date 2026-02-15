import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
import '../models/account.dart';
import '../models/transaction.dart';
import '../utils/currency_utils.dart';
import '../widgets/form_utils.dart';
import '../utils/billing_helper.dart';

class RecordCCPaymentDialog extends ConsumerStatefulWidget {
  final Account creditCardAccount;
  const RecordCCPaymentDialog({super.key, required this.creditCardAccount});

  @override
  ConsumerState<RecordCCPaymentDialog> createState() =>
      _RecordCCPaymentDialogState();
}

class _RecordCCPaymentDialogState extends ConsumerState<RecordCCPaymentDialog> {
  final _amountController = TextEditingController();
  DateTime _date = DateTime.now();
  String _sourceAccountId = 'manual';
  bool _isRounded = false;
  double? _originalAmount;

  @override
  void initState() {
    super.initState();
    // Amount will be set in build method once transactions are loaded
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);
    final txnsAsync = ref.watch(transactionsProvider);

    return txnsAsync.when(
      data: (txns) {
        if (_amountController.text.isEmpty) {
          final storage = ref.read(storageServiceProvider);
          final billed = BillingHelper.calculateBilledAmount(
              widget.creditCardAccount,
              txns,
              DateTime.now(),
              storage.getLastRollover(widget.creditCardAccount.id));
          final totalDue = widget.creditCardAccount.balance + billed;
          _amountController.text = totalDue.toStringAsFixed(2);
        }

        return AlertDialog(
          title: Text('Pay ${widget.creditCardAccount.name} Bill'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FormUtils.buildAmountField(
                  controller: _amountController,
                  currency: ref.watch(currencyProvider),
                  label: 'Payment Amount',
                ),
                CheckboxListTile(
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  title:
                      const Text('Round Off', style: TextStyle(fontSize: 14)),
                  subtitle: const Text('Round to nearest ₹1',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                  value: _isRounded,
                  onChanged: (v) {
                    setState(() {
                      _isRounded = v ?? false;
                      if (_isRounded) {
                        _originalAmount =
                            double.tryParse(_amountController.text) ?? 0;
                        final rounded = _originalAmount!.roundToDouble();
                        _amountController.text = rounded.toStringAsFixed(2);
                      } else {
                        // Restore original only if it matches the rounded value (user didn't manually edit)
                        // Actually, simplified: just re-calculate bill or use stored original
                        // Better: If user manually edits, we shouldn't overwrite unless they toggle.
                        // Strategy: Always calculate from current text when rounding.
                        // When un-rounding, we can't easily guess "original" if user edited.
                        // So, let's just use the strict bill amount IF available, or just toggle rounding on current value.
                        if (_originalAmount != null && _originalAmount! > 0) {
                          _amountController.text =
                              _originalAmount!.toStringAsFixed(2);
                        }
                      }
                    });
                  },
                ),
                const SizedBox(height: 8),
                accountsAsync.when(
                  data: (accounts) {
                    final sourceAccounts = accounts
                        .where((a) =>
                            a.id != widget.creditCardAccount.id &&
                            a.type != AccountType.creditCard)
                        .toList();

                    return FormUtils.buildAccountSelector(
                      value: _sourceAccountId,
                      accounts: sourceAccounts,
                      onChanged: (v) => setState(() => _sourceAccountId = v!),
                      label: 'Pay From Account',
                    );
                  },
                  loading: () => const CircularProgressIndicator(),
                  error: (_, __) => const Text('Error loading accounts'),
                ),
                const SizedBox(height: 16),
                FormUtils.buildDatePickerField(
                  context: context,
                  selectedDate: _date,
                  onDateTarget: (picked) => setState(() => _date = picked),
                  label: 'Payment Date',
                ),
              ],
            ),
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

                  // Record Transfer
                  final txn = Transaction.create(
                    title: 'CC Bill Payment: ${widget.creditCardAccount.name}',
                    amount: amount,
                    date: _date,
                    type: TransactionType.transfer,
                    category: 'Credit Card Bill',
                    accountId:
                        _sourceAccountId == 'manual' ? null : _sourceAccountId,
                    toAccountId: widget.creditCardAccount.id,
                  );

                  await storage.saveTransaction(txn);

                  // Auto-create Rounding Adjustment if enabled
                  if (_isRounded &&
                      _originalAmount != null &&
                      (_originalAmount! - amount).abs() > 0.001) {
                    final diff = _originalAmount! - amount;
                    // If diff > 0 (e.g. 100.4 - 100.0 = 0.4): We underpaid 0.4 -> Need Income to reduce debt.
                    // If diff < 0 (e.g. 100.6 - 101.0 = -0.4): We overpaid 0.4 -> Need Expense to increase debt back (technically "Bank Fee" logic, but effectively balances it).
                    // Actually:
                    // Bill: 100.4. Paid: 100. Rem: 0.4.
                    // To make Rem 0, we need to "pay" 0.4 more.
                    // An "Income" on CC acts as a credit/payment.
                    // So Income of 0.4 works.

                    final adjustmentType = diff > 0
                        ? TransactionType.income
                        : TransactionType.expense;

                    final adjustmentTxn = Transaction.create(
                      title: 'Rounding Adjustment',
                      amount: diff.abs(),
                      date: _date,
                      type: adjustmentType,
                      category: 'Adjustment',
                      accountId: widget.creditCardAccount.id,
                      toAccountId: null,
                    );
                    await storage.saveTransaction(adjustmentTxn);
                  }

                  ref.invalidate(accountsProvider);
                  ref.invalidate(transactionsProvider);

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
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) =>
          AlertDialog(title: const Text('Error'), content: Text('$e')),
    );
  }
}
