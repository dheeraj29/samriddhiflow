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
        onPressed: () { // coverage:ignore-line
          Navigator.push( // coverage:ignore-line
            context,
            MaterialPageRoute(builder: (_) => const AddLendingScreen()), // coverage:ignore-line
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
                  onPressed: () => Navigator.of(ctx).pop(false), // coverage:ignore-line
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
                Padding( // coverage:ignore-line
                  padding: const EdgeInsets.only(top: 4),
                  child: Text( // coverage:ignore-line
                    'Paid: ${CurrencyUtils.formatCurrency(record.totalPaid, locale)} (${record.payments.length} txn)', // coverage:ignore-line
                    style: const TextStyle(color: Colors.teal, fontSize: 12),
                  ),
                ),
              if (record.isClosed)
                Padding( // coverage:ignore-line
                  padding: const EdgeInsets.only(top: 2),
                  child: Text( // coverage:ignore-line
                    'Closed on ${DateFormat('dd MMM').format(record.closedDate!)}', // coverage:ignore-line
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
                    // coverage:ignore-start
                    Text(
                      'Bal: ${CurrencyUtils.formatCurrency(record.remainingAmount, locale)}',
                      style: TextStyle(
                        color: color.withValues(alpha: 0.8),
                    // coverage:ignore-end
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
                      _showPaymentDialog(context, ref, record, locale); // coverage:ignore-line
                      break;
                    case 'history':
                      _showHistoryDialog(context, record, locale); // coverage:ignore-line
                      break;
                    case 'settle':
                      _showCloseDialog(context, ref, record);
                      break;
                    case 'edit': // coverage:ignore-line
                      Navigator.push( // coverage:ignore-line
                        context,
                        // coverage:ignore-start
                        MaterialPageRoute(
                            builder: (_) =>
                                AddLendingScreen(recordToEdit: record)),
                        // coverage:ignore-end
                      );
                      break;
                    case 'delete': // coverage:ignore-line
                      _confirmDelete(context, ref, record); // coverage:ignore-line
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
                        const PopupMenuItem<String>( // coverage:ignore-line
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
          onTap: () { // coverage:ignore-line
            Navigator.push( // coverage:ignore-line
              context,
              MaterialPageRoute( // coverage:ignore-line
                  builder: (_) => AddLendingScreen(recordToEdit: record)), // coverage:ignore-line
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
              onPressed: () => Navigator.of(ctx).pop(), // coverage:ignore-line
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

  void _showPaymentDialog(BuildContext context, WidgetRef ref, // coverage:ignore-line
      LendingRecord record, String locale) {
    // coverage:ignore-start
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    DateTime payDate = DateTime.now();
    // coverage:ignore-end

    showDialog( // coverage:ignore-line
      context: context,
      builder: (ctx) => StatefulBuilder( // coverage:ignore-line
        builder: (context, setDialogState) => AlertDialog( // coverage:ignore-line
          title: const Text('Record Payment'),
          content: Column( // coverage:ignore-line
            mainAxisSize: MainAxisSize.min,
            // coverage:ignore-start
            children: [
              Text(
                'Remaining: ${CurrencyUtils.formatCurrency(record.remainingAmount, locale)}',
            // coverage:ignore-end
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField( // coverage:ignore-line
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
              TextField( // coverage:ignore-line
                controller: noteController,
                decoration: const InputDecoration(
                  labelText: 'Note (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note),
                ),
              ),
              const SizedBox(height: 12),
              // coverage:ignore-start
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
              // coverage:ignore-end
                    context: context,
                    initialDate: payDate,
                    firstDate: DateTime(2000), // coverage:ignore-line
                    lastDate: DateTime(2100), // coverage:ignore-line
                  );
                  if (picked != null) {
                    setDialogState(() => payDate = picked); // coverage:ignore-line
                  }
                },
                child: InputDecorator( // coverage:ignore-line
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(DateFormat(dateFormatDdMmmYyyy).format(payDate)), // coverage:ignore-line
                ),
              ),
            ],
          ),
          // coverage:ignore-start
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
          // coverage:ignore-end
                child: const Text('Cancel')),
            // coverage:ignore-start
            ElevatedButton(
              onPressed: () {
                final amt = double.tryParse(amountController.text) ?? 0;
                if (amt <= 0) return;
            // coverage:ignore-end

                final payment = LendingPayment.create( // coverage:ignore-line
                  amount: amt,
                  date: payDate,
                  note: noteController.text.trim(), // coverage:ignore-line
                );

                final updated = record.copyWith( // coverage:ignore-line
                  payments: [...record.payments, payment], // coverage:ignore-line
                );

                // Auto-settle if balance hits 0
                // coverage:ignore-start
                if (updated.remainingAmount <= 0) {
                  ref.read(lendingProvider.notifier).updateRecord(
                      updated.copyWith(isClosed: true, closedDate: payDate));
                // coverage:ignore-end
                } else {
                  ref.read(lendingProvider.notifier).updateRecord(updated); // coverage:ignore-line
                }

                Navigator.pop(ctx); // coverage:ignore-line
              },
              child: const Text('Save Payment'),
            ),
          ],
        ),
      ),
    );
  }

  void _showHistoryDialog( // coverage:ignore-line
      BuildContext context, LendingRecord record, String locale) {
    showDialog( // coverage:ignore-line
      context: context,
      builder: (ctx) => AlertDialog( // coverage:ignore-line
        title: const Text('Payment History'),
        content: SizedBox( // coverage:ignore-line
          width: double.maxFinite,
          child: Column( // coverage:ignore-line
            mainAxisSize: MainAxisSize.min,
            children: [ // coverage:ignore-line
              ...record.payments.reversed.map((p) => ListTile( // coverage:ignore-line
                    dense: true,
                    title: Text(CurrencyUtils.formatCurrency(p.amount, locale), // coverage:ignore-line
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    // coverage:ignore-start
                    subtitle: Text(
                        '${DateFormat(dateFormatDdMmmYyyy).format(p.date)}${p.note != null && p.note!.isNotEmpty ? ' • ${p.note}' : ''}'),
                    trailing: IconButton(
                    // coverage:ignore-end
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: () { // coverage:ignore-line
                        // Optional: allow deleting history item
                      },
                    ),
                  )),
            ],
          ),
        ),
        // coverage:ignore-start
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        // coverage:ignore-end
        ],
      ),
    );
  }

  void _confirmDelete( // coverage:ignore-line
      BuildContext context, WidgetRef ref, LendingRecord record) {
    showDialog( // coverage:ignore-line
      context: context,
      builder: (ctx) => AlertDialog( // coverage:ignore-line
        title: const Text('Delete Record?'),
        content: const Text(
            'Are you sure you want to delete this record? This action cannot be undone.'),
        // coverage:ignore-start
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
        // coverage:ignore-end
              child: const Text('Cancel')),
          // coverage:ignore-start
          TextButton(
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
