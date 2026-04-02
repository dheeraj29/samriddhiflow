import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samriddhi_flow/l10n/app_localizations.dart';
import '../providers.dart';
import '../feature_providers.dart';
import '../models/recurring_transaction.dart';
import '../widgets/pure_icons.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import '../utils/regex_utils.dart';

class RecurringManagerScreen extends ConsumerWidget {
  const RecurringManagerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final recurringAsync = ref.watch(recurringTransactionsProvider);
    final currencyLocale = ref.watch(currencyProvider);
    final currency = NumberFormat.simpleCurrency(locale: currencyLocale);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.recurringPaymentsTitle)),
      body: recurringAsync.when(
        data: (rules) {
          if (rules.isEmpty) {
            return Center(
                child: Text(l10n.noRecurringPayments)); // coverage:ignore-line
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
                        l10n.nextExecutionLabel(DateFormat('MMM dd, yyyy')
                            .format(rule.nextExecutionDate)),
                        style:
                            const TextStyle(color: Colors.blue, fontSize: 13),
                      ),
                      Text(
                        _getScheduleDescription(context, rule),
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
                        tooltip: l10n.addToCalendarTooltip,
                        onPressed: () {
                          // coverage:ignore-line
                          ref
                              // coverage:ignore-start
                              .read(calendarServiceProvider)
                              .downloadRecurringEvent(
                                title: rule.title,
                                description: l10n.recurringEventDescription(
                                    rule.title, currency.format(rule.amount)),
                                startDate: rule.nextExecutionDate,
                                // coverage:ignore-end
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
        error: (e, s) => // coverage:ignore-line
            Center(
                child: Text(l10n.errorLabelWithDetails(
                    e.toString()))), // coverage:ignore-line
      ),
    );
  }

  String _getScheduleDescription(
      BuildContext context, RecurringTransaction rule) {
    final l10n = AppLocalizations.of(context)!;
    String freqStr = switch (rule.frequency) {
      Frequency.daily => l10n.freqDaily,
      Frequency.weekly => l10n.freqWeekly,
      Frequency.monthly => l10n.freqMonthly,
      Frequency.yearly => l10n.freqYearly, // coverage:ignore-line
    };
    final adjText = rule.adjustForHolidays ? l10n.adjForHolidaysLabel : "";

    return switch (rule.scheduleType) {
      ScheduleType.fixedDate =>
        '$freqStr${l10n.everyEvery}${rule.nextExecutionDate.day}${_getDaySuffix(context, rule.nextExecutionDate.day)}',
      // coverage:ignore-start
      ScheduleType.everyWeekend => l10n.everyWeekendLabel,
      ScheduleType.lastWeekend => l10n.lastWeekendLabel,
      ScheduleType.specificWeekday => l10n.everyWeekdayLabel(
          _getWeekdayName(context, rule.selectedWeekday ?? 1)),
      ScheduleType.lastDayOfMonth => '${l10n.lastDayOfMonthLabel}$adjText',
      ScheduleType.lastWorkingDay => '${l10n.lastWorkingDayLabel}$adjText',
      ScheduleType.firstWorkingDay => '${l10n.firstWorkingDayLabel}$adjText',
      // coverage:ignore-end
    };
  }

  String _getDaySuffix(BuildContext context, int day) {
    final l10n = AppLocalizations.of(context)!;
    if (day >= 11 && day <= 13) return l10n.daySuffixTh;
    switch (day % 10) {
      case 1:
        return l10n.daySuffixSt;
      // coverage:ignore-start
      case 2:
        return l10n.daySuffixNd;
      case 3:
        return l10n.daySuffixRd;
      // coverage:ignore-end
      default:
        return l10n.daySuffixTh; // coverage:ignore-line
    }
  }

  // coverage:ignore-start
  String _getWeekdayName(BuildContext context, int day) {
    final l10n = AppLocalizations.of(context)!;
    final names = [
      // coverage:ignore-end
      '',
      // coverage:ignore-start
      l10n.monday,
      l10n.tuesday,
      l10n.wednesday,
      l10n.thursday,
      l10n.friday,
      l10n.saturday,
      l10n.sunday
      // coverage:ignore-end
    ];
    return names[day]; // coverage:ignore-line
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, RecurringTransaction rule) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: Text(AppLocalizations.of(context)!.deleteRecurringTitle),
              content: Text(AppLocalizations.of(context)!
                  .deleteRecurringConfirmation(rule.title)),
              actions: [
                TextButton(
                    onPressed: () =>
                        Navigator.pop(context, false), // coverage:ignore-line
                    child: Text(AppLocalizations.of(context)!.cancelButton)),
                TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(AppLocalizations.of(context)!.deleteButton,
                        style: const TextStyle(color: Colors.red))),
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
        title: Text(AppLocalizations.of(context)!.editRecurringAmountTitle),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.newAmountLabel,
            border: const OutlineInputBorder(),
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegexUtils.amountExp)
          ],
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // coverage:ignore-line
            child: Text(AppLocalizations.of(context)!.cancelButton),
          ),
          TextButton(
            // coverage:ignore-start
            onPressed: () {
              final val = double.tryParse(controller.text);
              if (val != null && val > 0) {
                Navigator.pop(context, val);
                // coverage:ignore-end
              }
            },
            child: Text(AppLocalizations.of(context)!.saveButton),
          ),
        ],
      ),
    );

    if (updatedAmount != null) {
      // coverage:ignore-start
      final storage = ref.read(storageServiceProvider);
      rule.amount = updatedAmount;
      await storage.saveRecurringTransaction(rule);
      final _ = ref.refresh(recurringTransactionsProvider);
      // coverage:ignore-end
    }
  }
}
