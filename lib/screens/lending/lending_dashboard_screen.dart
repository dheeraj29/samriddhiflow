import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers.dart';
import '../../services/lending/lending_provider.dart';
import '../../models/lending_record.dart';
import '../../utils/currency_utils.dart';
import 'add_lending_screen.dart';
import 'package:intl/intl.dart';

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
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddLendingScreen()),
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
                  onPressed: () => Navigator.of(ctx).pop(false),
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
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.1),
            child: Icon(
              isLent ? Icons.arrow_upward : Icons.arrow_downward,
              color: color,
            ),
          ),
          title: Text(record.personName,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Column(
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
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'Closed on ${DateFormat('dd MMM').format(record.closedDate!)}',
                    style: const TextStyle(
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                        fontSize: 12),
                  ),
                ),
            ],
          ),
          trailing: Row(
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
                      decoration:
                          record.isClosed ? TextDecoration.lineThrough : null,
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
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'pay':
                      _showPaymentDialog(context, ref, record, locale);
                      break;
                    case 'history':
                      _showHistoryDialog(context, record, locale);
                      break;
                    case 'settle':
                      _showCloseDialog(context, ref, record);
                      break;
                    case 'edit':
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                AddLendingScreen(recordToEdit: record)),
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
              ),
            ],
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => AddLendingScreen(recordToEdit: record)),
            );
          },
        ),
      ),
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
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    DateTime payDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Record Payment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Remaining: ${CurrencyUtils.formatCurrency(record.remainingAmount, locale)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Amount Paid',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.currency_rupee),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(
                  labelText: 'Note (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note),
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: payDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setDialogState(() => payDate = picked);
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(DateFormat(dateFormatDdMmmYyyy).format(payDate)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final amt = double.tryParse(amountController.text) ?? 0;
                if (amt <= 0) return;

                final payment = LendingPayment.create(
                  amount: amt,
                  date: payDate,
                  note: noteController.text.trim(),
                );

                final updated = record.copyWith(
                  payments: [...record.payments, payment],
                );

                // Auto-settle if balance hits 0
                if (updated.remainingAmount <= 0) {
                  ref.read(lendingProvider.notifier).updateRecord(
                      updated.copyWith(isClosed: true, closedDate: payDate));
                } else {
                  ref.read(lendingProvider.notifier).updateRecord(updated);
                }

                Navigator.pop(ctx);
              },
              child: const Text('Save Payment'),
            ),
          ],
        ),
      ),
    );
  }

  void _showHistoryDialog(
      BuildContext context, LendingRecord record, String locale) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Payment History'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...record.payments.reversed.map((p) => ListTile(
                    dense: true,
                    title: Text(CurrencyUtils.formatCurrency(p.amount, locale),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                        '${DateFormat(dateFormatDdMmmYyyy).format(p.date)}${p.note != null && p.note!.isNotEmpty ? ' • ${p.note}' : ''}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: () {
                        // Optional: allow deleting history item
                      },
                    ),
                  )),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
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
              onPressed: () {
                ref.read(lendingProvider.notifier).deleteRecord(record.id);
                Navigator.of(ctx).pop();
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }
}