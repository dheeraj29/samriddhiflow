import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers.dart';
import '../feature_providers.dart';
import '../models/recurring_transaction.dart';
import '../widgets/pure_icons.dart';

class RecurringManagerScreen extends ConsumerWidget {
  const RecurringManagerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recurringAsync = ref.watch(recurringTransactionsProvider);
    final currencyLocale = ref.watch(currencyProvider);
    final currency = NumberFormat.simpleCurrency(locale: currencyLocale);

    return Scaffold(
      appBar: AppBar(title: const Text('Recurring Payments')),
      body: recurringAsync.when(
        data: (rules) {
          if (rules.isEmpty) {
            return const Center(child: Text('No recurring payments set up.'));
          }
          return ListView.builder(
            itemCount: rules.length,
            itemBuilder: (context, index) {
              final rule = rules[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(rule.title,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          '${rule.category} • ${currency.format(rule.amount)}'),
                      Text(
                        'Next: ${DateFormat('MMM dd, yyyy').format(rule.nextExecutionDate)}',
                        style:
                            const TextStyle(color: Colors.blue, fontSize: 13),
                      ),
                      Text(
                        _getScheduleDescription(rule),
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: PureIcons.calendar(color: Colors.blueGrey),
                        tooltip: 'Add to System Calendar',
                        onPressed: () {
                          ref
                              .read(calendarServiceProvider)
                              .downloadRecurringEvent(
                                title: rule.title,
                                description:
                                    'Recurring payment: ${rule.title} for ${currency.format(rule.amount)}',
                                startDate: rule.nextExecutionDate,
                                occurrences: 12, // Default to 1 year
                              );
                        },
                      ),
                      IconButton(
                        icon: PureIcons.editOutlined(color: Colors.orange),
                        onPressed: () =>
                            _showEditAmountDialog(context, ref, rule),
                      ),
                      IconButton(
                        icon: PureIcons.deleteOutlined(color: Colors.red),
                        onPressed: () => _confirmDelete(context, ref, rule),
                      ),
                    ],
                  ),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }

  String _getScheduleDescription(RecurringTransaction rule) {
    String freqStr = rule.frequency.name.toUpperCase();
    switch (rule.scheduleType) {
      case ScheduleType.fixedDate:
        return '$freqStr - Every ${rule.nextExecutionDate.day}${_getDaySuffix(rule.nextExecutionDate.day)}';
      case ScheduleType.everyWeekend:
        return 'Every Weekend (Sat/Sun)';
      case ScheduleType.lastWeekend:
        return 'Last Weekend of Month';
      case ScheduleType.specificWeekday:
        return 'Every ${_getWeekdayName(rule.selectedWeekday ?? 1)}';
      case ScheduleType.lastDayOfMonth:
        return 'Last Day of Month${rule.adjustForHolidays ? " (Adj. for Holidays)" : ""}';
      case ScheduleType.lastWorkingDay:
        return 'Last Working Day${rule.adjustForHolidays ? " (Adj. for Holidays)" : ""}';
    }
  }

  String _getDaySuffix(int day) {
    if (day >= 11 && day <= 13) return 'th';
    switch (day % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }

  String _getWeekdayName(int day) {
    const names = [
      '',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    return names[day];
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, RecurringTransaction rule) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Delete recurring rule?'),
              content: Text(
                  'This will stop automatic payments for "${rule.title}". Past transactions will NOT be deleted.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel')),
                TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Delete',
                        style: TextStyle(color: Colors.red))),
              ],
            ));

    if (confirmed == true) {
      await ref
          .read(storageServiceProvider)
          .deleteRecurringTransaction(rule.id);
      final _ = ref.refresh(recurringTransactionsProvider);
    }
  }

  Future<void> _showEditAmountDialog(
      BuildContext context, WidgetRef ref, RecurringTransaction rule) async {
    final controller =
        TextEditingController(text: rule.amount.toStringAsFixed(2));
    final updatedAmount = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Recurring Amount'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'New Amount',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final val = double.tryParse(controller.text);
              if (val != null && val > 0) {
                Navigator.pop(context, val);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (updatedAmount != null) {
      final storage = ref.read(storageServiceProvider);
      rule.amount = updatedAmount;
      await storage.saveRecurringTransaction(rule);
      final _ = ref.refresh(recurringTransactionsProvider);
    }
  }
}
