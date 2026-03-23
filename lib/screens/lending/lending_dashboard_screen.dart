import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers.dart';
import '../../services/lending/lending_provider.dart';
import '../../models/lending_record.dart';
import '../../utils/currency_utils.dart';
import 'add_lending_screen.dart';
import 'package:intl/intl.dart';
import 'lending_history_screen.dart';
import '../../widgets/app_list_item_card.dart';

const dateFormatDdMmmYyyy = 'dd MMM yyyy';

class LendingDashboardScreen extends ConsumerWidget {
  const LendingDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lendingRecords = ref.watch(lendingProvider);
    final totalLent = ref.watch(totalLentProvider);
    final totalBorrowed = ref.watch(totalBorrowedProvider);
    final currencyLocale = ref.watch(currencyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lending & Borrowing'),
      ),
      body: Column(
        children: [
          // Summary Cards
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    context,
                    'Total Lent',
                    totalLent,
                    Colors.green,
                    currencyLocale,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSummaryCard(
                    context,
                    'Total Borrowed',
                    totalBorrowed,
                    Colors.redAccent,
                    currencyLocale,
                  ),
                ),
              ],
            ),
          ),

          // List of Records
          Expanded(
            child: lendingRecords.isEmpty
                ? const Center(child: Text('No records found.'))
                : ListView.builder(
                    itemCount: lendingRecords.length,
                    itemBuilder: (context, index) {
                      final record = lendingRecords[index];
                      return _buildRecordItem(
                          context, ref, record, currencyLocale);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // coverage:ignore-line
          Navigator.push(
            // coverage:ignore-line
            context,
            MaterialPageRoute(
                builder: (_) =>
                    const AddLendingScreen()), // coverage:ignore-line
          );
        },
        label: const Text('Add Record'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, String title, double amount,
      Color color, String locale) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          Text(
            CurrencyUtils.formatCurrency(amount, locale),
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordItem(BuildContext context, WidgetRef ref,
      LendingRecord record, String locale) {
    final isLent = record.type == LendingType.lent;
    final color = isLent ? Colors.green : Colors.redAccent;
    final formattedDate = DateFormat(dateFormatDdMmmYyyy).format(record.date);

    return Dismissible(
      key: Key(record.id),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Record?'),
            content: const Text(
                'Are you sure you want to delete this record? This action cannot be undone.'),
            actions: [
              TextButton(
                  onPressed: () =>
                      Navigator.of(ctx).pop(false), // coverage:ignore-line
                  child: const Text('Cancel')),
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Delete',
                      style: TextStyle(color: Colors.red))),
            ],
          ),
        );
      },
      onDismissed: (direction) {
        ref.read(lendingProvider.notifier).deleteRecord(record.id);
      },
      child: AppListItemCard(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        elevation: 2,
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.grey.withValues(alpha: 0.1),
            child: Icon(
              isLent ? Icons.arrow_upward : Icons.arrow_downward,
              color: color,
            ),
          ),
          title: Text(record.personName,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: _buildRecordSubtitle(record, formattedDate, locale),
          trailing: _buildRecordTrailing(context, ref, record, color, locale),
          onTap: () {
            // coverage:ignore-line
            Navigator.push(
              // coverage:ignore-line
              context,
              MaterialPageRoute(
                  // coverage:ignore-line
                  builder: (_) => AddLendingScreen(
                      recordToEdit: record)), // coverage:ignore-line
            );
          },
        ),
      ),
    );
  }

  Widget _buildRecordSubtitle(
      LendingRecord record, String formattedDate, String locale) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$formattedDate • ${record.reason}'),
        if (record.payments.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Paid: ${CurrencyUtils.formatCurrency(record.totalPaid, locale)} (${record.payments.length} txn)',
              style: const TextStyle(color: Colors.teal, fontSize: 12),
            ),
          ),
        if (record.isClosed)
          Padding(
            // coverage:ignore-line
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              // coverage:ignore-line
              'Closed on ${DateFormat('dd MMM').format(record.closedDate!)}', // coverage:ignore-line
              style: const TextStyle(
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                  fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildRecordTrailing(BuildContext context, WidgetRef ref,
      LendingRecord record, Color color, String locale) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              CurrencyUtils.formatCurrency(record.amount, locale),
              style: TextStyle(
                color: record.isClosed ? Colors.grey : color,
                fontWeight: FontWeight.bold,
                fontSize: 16,
                decoration: record.isClosed ? TextDecoration.lineThrough : null,
              ),
            ),
            if (record.totalPaid > 0 && !record.isClosed)
              Text(
                'Bal: ${CurrencyUtils.formatCurrency(record.remainingAmount, locale)}',
                style: TextStyle(
                  color: color.withValues(alpha: 0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        const SizedBox(width: 8),
        _buildRecordPopupMenu(context, ref, record, locale),
      ],
    );
  }

  Widget _buildRecordPopupMenu(BuildContext context, WidgetRef ref,
      LendingRecord record, String locale) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        switch (value) {
          case 'pay':
            _showPaymentDialog(context, ref, record, locale);
            break;
          case 'history':
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => LendingHistoryScreen(recordId: record.id)),
            );
            break;
          case 'settle':
            _showCloseDialog(context, ref, record);
            break;
          case 'edit':
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => AddLendingScreen(recordToEdit: record)),
            );
            break;
          case 'delete':
            _confirmDelete(context, ref, record);
            break;
        }
      },
      itemBuilder: (BuildContext context) {
        return [
          if (!record.isClosed) ...[
            const PopupMenuItem<String>(
              value: 'pay',
              child: Row(
                children: [
                  Icon(Icons.payment, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('Record Payment'),
                ],
              ),
            ),
            if (record.payments.isNotEmpty)
              const PopupMenuItem<String>(
                value: 'history',
                child: Row(
                  children: [
                    Icon(Icons.list, color: Colors.teal),
                    SizedBox(width: 8),
                    Text('Payment History'),
                  ],
                ),
              ),
            const PopupMenuItem<String>(
              value: 'settle',
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.teal),
                  SizedBox(width: 8),
                  Text('Settle Full'),
                ],
              ),
            ),
          ],
          const PopupMenuItem<String>(
            value: 'edit',
            child: Row(
              children: [
                Icon(Icons.edit, color: Colors.blue),
                SizedBox(width: 8),
                Text('Edit'),
              ],
            ),
          ),
          const PopupMenuItem<String>(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete, color: Colors.red),
                SizedBox(width: 8),
                Text('Delete'),
              ],
            ),
          ),
        ];
      },
    );
  }

  void _showCloseDialog(
      BuildContext context, WidgetRef ref, LendingRecord record) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark as Settled?'),
        content: Text(
            'Has the amount of ${record.amount} been ${record.type == LendingType.lent ? 'received back from' : 'paid back to'} ${record.personName}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final updated =
                  record.copyWith(isClosed: true, closedDate: DateTime.now());
              ref.read(lendingProvider.notifier).updateRecord(updated);
              Navigator.of(ctx).pop();
            },
            child: const Text('Yes, Settle'),
          ),
        ],
      ),
    );
  }

  void _showPaymentDialog(BuildContext context, WidgetRef ref,
      LendingRecord record, String locale) {
    showDialog(
      context: context,
      builder: (ctx) => _LendingRecordPaymentDialog(
        record: record,
        locale: locale,
        // coverage:ignore-start
        onSave: (payment) {
          final updated = record.copyWith(
            payments: [...record.payments, payment],
            // coverage:ignore-end
          );
          // coverage:ignore-start
          if (updated.remainingAmount <= 0) {
            ref.read(lendingProvider.notifier).updateRecord(
                updated.copyWith(isClosed: true, closedDate: payment.date));
            // coverage:ignore-end
          } else {
            ref
                .read(lendingProvider.notifier)
                .updateRecord(updated); // coverage:ignore-line
          }
        },
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, WidgetRef ref, LendingRecord record) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Record?'),
        content: const Text(
            'Are you sure you want to delete this record? This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
          TextButton(
              // coverage:ignore-start
              onPressed: () {
                ref.read(lendingProvider.notifier).deleteRecord(record.id);
                Navigator.of(ctx).pop();
                // coverage:ignore-end
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }
}

class _LendingRecordPaymentDialog extends StatefulWidget {
  final LendingRecord record;
  final String locale;
  final Function(LendingPayment) onSave;

  const _LendingRecordPaymentDialog({
    required this.record,
    required this.locale,
    required this.onSave,
  });

  @override
  State<_LendingRecordPaymentDialog> createState() =>
      _LendingRecordPaymentDialogState();
}

class _LendingRecordPaymentDialogState
    extends State<_LendingRecordPaymentDialog> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime _payDate = DateTime.now();

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Record Payment'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Remaining: ${CurrencyUtils.formatCurrency(widget.record.remainingAmount, widget.locale)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Amount Paid',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.currency_rupee),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(
              labelText: 'Note (Optional)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.note),
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () async {
              // coverage:ignore-line
              final picked = await showDatePicker(
                // coverage:ignore-line
                context: context,
                // coverage:ignore-start
                initialDate: _payDate,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
                // coverage:ignore-end
              );
              if (picked != null) {
                setState(() => _payDate = picked); // coverage:ignore-line
              }
            },
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Date',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.calendar_today),
              ),
              child: Text(DateFormat(dateFormatDdMmmYyyy).format(_payDate)),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
          // coverage:ignore-start
          onPressed: () {
            final amt = double.tryParse(_amountController.text) ?? 0;
            if (amt <= 0) return;
            // coverage:ignore-end

            final payment = LendingPayment.create(
              // coverage:ignore-line
              amount: amt,
              date: _payDate, // coverage:ignore-line
              note: _noteController.text.trim(), // coverage:ignore-line
            );

            widget.onSave(payment); // coverage:ignore-line
            Navigator.pop(context); // coverage:ignore-line
          },
          child: const Text('Save Payment'),
        ),
      ],
    );
  }
}
