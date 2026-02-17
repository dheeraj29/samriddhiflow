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
  final bool isFullyPaid;
  const RecordCCPaymentDialog(
      {super.key, required this.creditCardAccount, required this.isFullyPaid});

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
  double _calculatedTotalDue = 0;

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
        // Only calculate and autofill if NOT fully paid and text is empty
        if (_amountController.text.isEmpty && !widget.isFullyPaid) {
          final storage = ref.read(storageServiceProvider);
          final billed = BillingHelper.calculateBilledAmount(
              widget.creditCardAccount,
              txns,
              DateTime.now(),
              storage.getLastRollover(widget.creditCardAccount.id));

          final totalDue = widget.creditCardAccount.balance + billed;

          // Store for later comparison
          _calculatedTotalDue = totalDue;

          // Only autofill if due amount is positive (debt)
          if (totalDue > 0) {
            _amountController.text = totalDue.toStringAsFixed(2);
          }
        }

        return AlertDialog(
          title: Text('Pay ${widget.creditCardAccount.name} Bill'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.isFullyPaid)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Colors.green.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 20),
                        SizedBox(width: 8),
                        Text('Bill is already marked as paid.',
                            style:
                                TextStyle(color: Colors.green, fontSize: 13)),
                      ],
                    ),
                  ),
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

                  // Auto-advance Cycle Logic
                  // If payment covers the calculated due amount (within small tolerance)
                  // Or if the user is paying significantly to clear debt.
                  // We use _calculatedTotalDue calculated at opening.
                  // Only auto-advance if we weren't already paid.
                  if (!widget.isFullyPaid && _calculatedTotalDue > 0) {
                    // Check if payment covers the due amount (tolerance 1.0)
                    if (amount >= (_calculatedTotalDue - 1.0)) {
                      // Full Payment! Advance the cycle.
                      await storage.resetCreditCardRollover(
                          widget.creditCardAccount,
                          keepBilledStatus: true);
                    }
                  }

                  // Auto-create Rounding Adjustment if enabled
                  if (_isRounded &&
                      _originalAmount != null &&
                      (_originalAmount! - amount).abs() > 0.001) {
                    final diff = _originalAmount! - amount;
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
