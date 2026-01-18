import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Added for FilteringTextInputFormatter
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers.dart';
import '../models/account.dart';
import '../models/transaction.dart';
import '../utils/currency_utils.dart';
import '../widgets/pure_icons.dart';
import '../theme/app_theme.dart';

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
  String _sourceAccountId = 'none';

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
                TextField(
                  controller: _amountController,
                  decoration: InputDecoration(
                    labelText: 'Payment Amount',
                    prefixText:
                        '${NumberFormat.simpleCurrency(locale: ref.watch(currencyProvider)).currencySymbol} ',
                    prefixStyle: AppTheme.offlineSafeTextStyle,
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))
                  ],
                ),
                const SizedBox(height: 16),
                accountsAsync.when(
                  data: (accounts) {
                    final sourceAccounts = accounts
                        .where((a) =>
                            a.id != widget.creditCardAccount.id &&
                            a.type != AccountType.creditCard)
                        .toList();
                    final allIds = ['none', ...sourceAccounts.map((a) => a.id)];
                    final safeValue = allIds.contains(_sourceAccountId)
                        ? _sourceAccountId
                        : 'none';

                    return DropdownButtonFormField<String>(
                      initialValue: safeValue,
                      decoration: const InputDecoration(
                        labelText: 'Pay From Account',
                        border: OutlineInputBorder(),
                      ),
                      items: <DropdownMenuItem<String>>[
                        const DropdownMenuItem<String>(
                            value: 'none', child: Text('No Account (Manual)')),
                        ...sourceAccounts.map((a) => DropdownMenuItem<String>(
                              value: a.id,
                              child: Text(
                                  '${a.name} (${CurrencyUtils.getFormatter(a.currency, compact: true).format(a.balance)})'),
                            )),
                      ],
                      onChanged: (v) => setState(() => _sourceAccountId = v!),
                      // Validator removed to allow Manual
                    );
                  },
                  loading: () => const CircularProgressIndicator(),
                  error: (_, __) => const Text('Error loading accounts'),
                ),
                const SizedBox(height: 16),
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
                        _sourceAccountId == 'none' ? null : _sourceAccountId,
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
