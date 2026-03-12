import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/lending_record.dart';
import '../../services/lending/lending_provider.dart';
import '../../providers.dart';
import '../../widgets/pagination_bar.dart';
import '../../widgets/smart_currency_text.dart';
import '../../widgets/pure_icons.dart';

class LendingHistoryScreen extends ConsumerStatefulWidget {
  final String recordId;

  const LendingHistoryScreen({super.key, required this.recordId});

  @override
  ConsumerState<LendingHistoryScreen> createState() =>
      _LendingHistoryScreenState();
}

class _LendingHistoryScreenState extends ConsumerState<LendingHistoryScreen> {
  final int _pageSize = 15;
  int _currentPage = 1;

  @override
  Widget build(BuildContext context) {
    final records = ref.watch(lendingProvider);
    final currencyLocale = ref.watch(currencyProvider);

    final record = records.firstWhere((r) => r.id == widget.recordId);
    final payments = List<LendingPayment>.from(record.payments);
    payments.sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment History'),
      ),
      body: _buildBody(record, payments, currencyLocale),
    );
  }

  Widget _buildBody(LendingRecord record, List<LendingPayment> payments,
      String currencyLocale) {
    if (payments.isEmpty) {
      return Column(
        children: [
          _buildHeader(record, currencyLocale),
          const Divider(),
          const Expanded(
            child: Center(child: Text('No payments recorded.')),
          ),
        ],
      );
    }

    final totalPages = (payments.length / _pageSize).ceil();
    final safePage = _currentPage.clamp(1, totalPages);
    final startIndex = (safePage - 1) * _pageSize;
    final endIndex = (startIndex + _pageSize > payments.length)
        ? payments.length
        : startIndex + _pageSize;

    final paginatedPayments = payments.sublist(startIndex, endIndex);

    return Column(
      children: [
        _buildHeader(record, currencyLocale),
        const Divider(),
        Expanded(
          child: ListView.builder(
            itemCount: paginatedPayments.length,
            itemBuilder: (context, index) {
              final payment = paginatedPayments[index];
              return _buildPaymentTile(payment, currencyLocale, record);
            },
          ),
        ),
        if (totalPages > 1)
          PaginationBar(
            safeCurrentPage: safePage,
            totalPages: totalPages,
            onPageChanged: (page) => setState(() => _currentPage = page),
          ),
      ],
    );
  }

  Widget _buildHeader(LendingRecord record, String locale) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            record.personName,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            record.reason,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSummaryItem(
                  'Total Amount', record.amount, locale, Colors.blue),
              _buildSummaryItem(
                  'Remaining', record.remainingAmount, locale, Colors.orange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
      String label, double value, String locale, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        SmartCurrencyText(
          value: value,
          locale: locale,
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Widget _buildPaymentTile(
      LendingPayment payment, String locale, LendingRecord record) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: record.type == LendingType.lent
            ? Colors.green.withValues(alpha: 0.1)
            : Colors.red.withValues(alpha: 0.1), // coverage:ignore-line
        child: Icon(
          record.type == LendingType.lent
              ? Icons.arrow_downward
              : Icons.arrow_upward,
          color: record.type == LendingType.lent ? Colors.green : Colors.red,
          size: 20,
        ),
      ),
      title: SmartCurrencyText(
        value: payment.amount,
        locale: locale,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(DateFormat('MMM dd, yyyy').format(payment.date)),
          if (payment.note != null && payment.note!.isNotEmpty)
            Text(payment.note!,
                style:
                    const TextStyle(fontStyle: FontStyle.italic, fontSize: 12)),
        ],
      ),
      trailing: IconButton(
        icon: PureIcons.deleteOutlined(color: Colors.grey, size: 20),
        onPressed: () => _confirmDelete(payment, record),
      ),
    );
  }

  Future<void> _confirmDelete(
      LendingPayment payment, LendingRecord record) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Payment?'),
        content:
            const Text('This will permanently remove this payment record.'),
        actions: [
          TextButton(
              onPressed: () =>
                  Navigator.pop(ctx, false), // coverage:ignore-line
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final updatedPayments =
          record.payments.where((p) => p.id != payment.id).toList();
      final updatedRecord = record.copyWith(payments: updatedPayments);

      await ref.read(lendingProvider.notifier).updateRecord(updatedRecord);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment deleted')),
        );
      }
    }
  }
}
