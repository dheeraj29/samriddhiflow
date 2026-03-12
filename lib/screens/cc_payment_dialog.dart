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
    final txnsAsync = ref.watch(transactionsProvider);

    return txnsAsync.when(
      data: (txns) {
        _initAmountIfNeeded(txns);

        return AlertDialog(
          title: Text('Pay ${widget.creditCardAccount.name} Bill'),
          content: SingleChildScrollView(child: _buildPaymentForm(context)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context), // coverage:ignore-line
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => _handlePayment(context),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => // coverage:ignore-line
          AlertDialog(
              title: const Text('Error'),
              content: Text('$e')), // coverage:ignore-line
    );
  }

  void _initAmountIfNeeded(List<Transaction> txns) {
    if (_amountController.text.isNotEmpty || widget.isFullyPaid) return;

    final storage = ref.read(storageServiceProvider);
    final billed = BillingHelper.calculateBilledAmount(
        widget.creditCardAccount,
        txns,
        DateTime.now(),
        storage.getLastRollover(widget.creditCardAccount.id));

    final totalDue = widget.creditCardAccount.balance + billed;
    _calculatedTotalDue = totalDue;

    if (totalDue > 0) {
      _amountController.text = totalDue.toStringAsFixed(2);
    }
  }

  Widget _buildPaymentForm(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.isFullyPaid)
          Container(
            // coverage:ignore-line
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(8),
            // coverage:ignore-start
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              // coverage:ignore-end
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 20),
                SizedBox(width: 8),
                Text('Bill is already marked as paid.',
                    style: TextStyle(color: Colors.green, fontSize: 13)),
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
          title: const Text('Round Off', style: TextStyle(fontSize: 14)),
          subtitle: const Text('Round to nearest number',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
          value: _isRounded,
          onChanged: (v) {
            setState(() {
              _isRounded = v ?? false;
              if (_isRounded) {
                _originalAmount = double.tryParse(_amountController.text) ?? 0;
                _amountController.text =
                    _originalAmount!.roundToDouble().toStringAsFixed(2);
              } else if (_originalAmount != null && _originalAmount! > 0) {
                // coverage:ignore-line
                _amountController.text =
                    _originalAmount!.toStringAsFixed(2); // coverage:ignore-line
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
          error: (_, __) =>
              const Text('Error loading accounts'), // coverage:ignore-line
        ),
        const SizedBox(height: 16),
        FormUtils.buildDatePickerField(
          context: context,
          selectedDate: _date,
          onDateTarget: (picked) =>
              setState(() => _date = picked), // coverage:ignore-line
          label: 'Payment Date',
        ),
      ],
    );
  }

  Future<void> _handlePayment(BuildContext context) async {
    final amount = CurrencyUtils.roundTo2Decimals(
        double.tryParse(_amountController.text) ?? 0);
    if (amount <= 0) return;

    final storage = ref.read(storageServiceProvider);

    await _recordTransferTransaction(storage, amount);
    await _advanceCycleIfNeeded(storage, amount);
    await _handleRoundingAdjustmentIfNeeded(storage, amount);

    ref.invalidate(accountsProvider);
    ref.invalidate(transactionsProvider);

    if (!context.mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Payment Recorded')));
  }

  Future<void> _recordTransferTransaction(
      dynamic storage, double amount) async {
    final txn = Transaction.create(
      title: 'CC Bill Payment: ${widget.creditCardAccount.name}',
      amount: amount,
      date: _date,
      type: TransactionType.transfer,
      category: 'Credit Card Bill',
      accountId: _sourceAccountId == 'manual' ? null : _sourceAccountId,
      toAccountId: widget.creditCardAccount.id,
    );
    await storage.saveTransaction(txn);
  }

  Future<void> _advanceCycleIfNeeded(dynamic storage, double amount) async {
    final targetDue =
        _isRounded ? _calculatedTotalDue.roundToDouble() : _calculatedTotalDue;
    if (!widget.isFullyPaid &&
        _calculatedTotalDue > 0 &&
        amount >= (targetDue - 0.01)) {
      await storage.resetCreditCardRollover(widget.creditCardAccount,
          keepBilledStatus: true);
    }
  }

  Future<void> _handleRoundingAdjustmentIfNeeded(
      dynamic storage, double amount) async {
    if (_isRounded &&
        _originalAmount != null &&
        (_originalAmount! - amount).abs() > 0.001) {
      await _createRoundingAdjustment(storage, amount);
    }
  }

  Future<void> _createRoundingAdjustment(dynamic storage, double amount) async {
    final diff = _originalAmount! - amount;
    final adjustmentType =
        diff > 0 ? TransactionType.income : TransactionType.expense;

    final adjustmentTxn = Transaction.create(
      title: 'Rounding Adjustment',
      amount: CurrencyUtils.roundTo2Decimals(diff.abs()),
      date: _date,
      type: adjustmentType,
      category: 'Adjustment',
      accountId: widget.creditCardAccount.id,
      toAccountId: null,
    );
    await storage.saveTransaction(adjustmentTxn);
  }
}
