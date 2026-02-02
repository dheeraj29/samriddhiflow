import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
import '../models/account.dart';
import '../models/transaction.dart';
import '../utils/currency_utils.dart';
import '../widgets/form_utils.dart';

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
        // Set initial amount strictly on first load
        if (_amountController.text.isEmpty) {
          final billed = widget.creditCardAccount.calculateBilledAmount(txns);
          _amountController.text = billed.toStringAsFixed(2);
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
                const SizedBox(height: 16),
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

                  final _ = ref.refresh(accountsProvider);
                  final __ = ref.refresh(transactionsProvider);

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
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) =>
          AlertDialog(title: const Text('Error'), content: Text('$e')),
    );
  }
}
