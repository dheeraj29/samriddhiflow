import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers.dart';
import '../../services/lending/lending_provider.dart';
import '../../models/lending_record.dart';
import '../../utils/currency_utils.dart';
import 'add_lending_screen.dart';
import 'package:intl/intl.dart';

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
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'View History',
            onPressed: () {
              // Future: Navigate to history or filter
            },
          ),
        ],
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
    final formattedDate = DateFormat('dd MMM yyyy').format(record.date);

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
              if (record.isClosed)
                Text(
                  'Closed/Settled on ${DateFormat('dd MMM').format(record.closedDate!)}',
                  style: const TextStyle(
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                      fontSize: 12),
                ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
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
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
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
                    if (!record.isClosed)
                      const PopupMenuItem<String>(
                        value: 'settle',
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.teal),
                            SizedBox(width: 8),
                            Text('Settle'),
                          ],
                        ),
                      ),
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
