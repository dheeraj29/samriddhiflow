import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samriddhi_flow/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'lending_history_screen.dart';
import 'add_lending_screen.dart';
import '../../widgets/app_list_item_card.dart';
import '../../models/lending_record.dart';
import '../../providers.dart';
import '../../services/lending/lending_provider.dart';
import '../../utils/currency_utils.dart';

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
        title: Text(AppLocalizations.of(context)!.lendingBorrowingTitle),
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
                    AppLocalizations.of(context)!.totalLentLabel,
                    totalLent,
                    Colors.green,
                    currencyLocale,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSummaryCard(
                    context,
                    AppLocalizations.of(context)!.totalBorrowedLabel,
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
                ? Center(
                    child: Text(AppLocalizations.of(context)!.noLendingRecords))
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
        label: Text(AppLocalizations.of(context)!.addRecordAction),
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
            title: Text(AppLocalizations.of(context)!.deleteLendingRecordTitle),
            content: Text(
                AppLocalizations.of(context)!.deleteLendingRecordConfirmation),
            actions: [
              TextButton(
                  onPressed: () =>
                      Navigator.of(ctx).pop(false), // coverage:ignore-line
                  child: Text(AppLocalizations.of(context)!.cancelButton)),
              TextButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: Text(AppLocalizations.of(context)!.deleteButton,
                      style: const TextStyle(color: Colors.red))),
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
          subtitle:
              _buildRecordSubtitle(context, record, formattedDate, locale),
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

  Widget _buildRecordSubtitle(BuildContext context, LendingRecord record,
      String formattedDate, String locale) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$formattedDate • ${record.reason}'),
        if (record.payments.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              AppLocalizations.of(context)!.paidSubtitle(
                  CurrencyUtils.formatCurrency(record.totalPaid, locale),
                  record.payments.length),
              style: const TextStyle(color: Colors.teal, fontSize: 12),
            ),
          ),
        if (record.isClosed)
          Padding(
            // coverage:ignore-line
            padding: const EdgeInsets.only(top: 2),
            // coverage:ignore-start
            child: Text(
              AppLocalizations.of(context)!.closedOnSubtitle(
                  DateFormat('dd MMM').format(record.closedDate!)),
              // coverage:ignore-end
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
                AppLocalizations.of(context)!.balanceTrailing(
                    CurrencyUtils.formatCurrency(
                        record.remainingAmount, locale)),
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
            PopupMenuItem<String>(
              value: 'pay',
              child: Row(
                children: [
                  const Icon(Icons.payment, color: Colors.orange),
                  const SizedBox(width: 8),
                  Text(AppLocalizations.of(context)!.recordPaymentAction),
                ],
              ),
            ),
            if (record.payments.isNotEmpty)
              PopupMenuItem<String>(
                value: 'history',
                child: Row(
                  children: [
                    const Icon(Icons.list, color: Colors.teal),
                    const SizedBox(width: 8),
                    Text(AppLocalizations.of(context)!.paymentHistoryAction),
                  ],
                ),
              ),
            PopupMenuItem<String>(
              value: 'settle',
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.teal),
                  const SizedBox(width: 8),
                  Text(AppLocalizations.of(context)!.settleFullAction),
                ],
              ),
            ),
          ],
          PopupMenuItem<String>(
            value: 'edit',
            child: Row(
              children: [
                const Icon(Icons.edit, color: Colors.blue),
                const SizedBox(width: 8),
                Text(AppLocalizations.of(context)!.editAction),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'delete',
            child: Row(
              children: [
                const Icon(Icons.delete, color: Colors.red),
                const SizedBox(width: 8),
                Text(AppLocalizations.of(context)!.deleteAction),
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
        title: Text(AppLocalizations.of(context)!.markAsSettledTitle),
        content: Text(record.type == LendingType.lent
            ? AppLocalizations.of(context)!.settleLentConfirmation(
                record.amount.toString(), record.personName)
            : AppLocalizations.of(context)!.settleBorrowedConfirmation(
                // coverage:ignore-line
                record.amount.toString(),
                record.personName)), // coverage:ignore-line
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(AppLocalizations.of(context)!.cancelButton)),
          ElevatedButton(
            onPressed: () {
              final updated =
                  record.copyWith(isClosed: true, closedDate: DateTime.now());
              ref.read(lendingProvider.notifier).updateRecord(updated);
              Navigator.of(ctx).pop();
            },
            child: Text(AppLocalizations.of(context)!.yesSettleAction),
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
        title: Text(AppLocalizations.of(context)!.deleteLendingRecordTitle),
        content:
            Text(AppLocalizations.of(context)!.deleteLendingRecordConfirmation),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(AppLocalizations.of(context)!.cancelButton)),
          TextButton(
              // coverage:ignore-start
              onPressed: () {
                ref.read(lendingProvider.notifier).deleteRecord(record.id);
                Navigator.of(ctx).pop();
                // coverage:ignore-end
              },
              child: Text(AppLocalizations.of(context)!.deleteAction,
                  style: const TextStyle(color: Colors.red))),
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
      title: Text(AppLocalizations.of(context)!.recordPaymentAction),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            AppLocalizations.of(context)!.remainingLabel(
                CurrencyUtils.formatCurrency(
                    widget.record.remainingAmount, widget.locale)),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.amountPaidLabel,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.currency_rupee),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.noteLabel,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.note),
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
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.dateLabel,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.calendar_today),
              ),
              child: Text(DateFormat(dateFormatDdMmmYyyy).format(_payDate)),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancelButton)),
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
          child: Text(AppLocalizations.of(context)!.savePaymentAction),
        ),
      ],
    );
  }
}
