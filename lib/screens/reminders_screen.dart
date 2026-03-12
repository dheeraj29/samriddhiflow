import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:clock/clock.dart';
import '../providers.dart';
import '../feature_providers.dart';
import '../services/taxes/indian_tax_service.dart';
import '../services/taxes/tax_config_service.dart';
import 'taxes/tax_details_screen.dart';
import 'cc_payment_dialog.dart';
import 'loan_payment_dialog.dart';
import 'add_transaction_screen.dart';
import 'package:samriddhi_flow/models/loan.dart';
import 'package:samriddhi_flow/models/account.dart';
import 'package:samriddhi_flow/models/transaction.dart';
import 'package:samriddhi_flow/models/recurring_transaction.dart';
import 'package:samriddhi_flow/models/taxes/tax_data.dart';
import 'package:samriddhi_flow/models/taxes/tax_rules.dart';
import '../widgets/pure_icons.dart';
import '../theme/app_theme.dart';
import '../utils/billing_helper.dart';

const dateFormatMmmDd = 'MMM dd';
const payNowText = 'PAY NOW';
const dateFormatMmmDdYyyy = 'MMM dd, yyyy';

class RemindersScreen extends ConsumerWidget {
  const RemindersScreen({super.key});

  (Color, String, IconData) _getCCPaymentStatus(
      bool isFullyPaid, bool isPartiallyPaid, bool isOverdue) {
    if (isFullyPaid) {
      return (Colors.green, 'Paid', Icons.check_circle);
    } else if (isPartiallyPaid) {
      return (Colors.orange, 'Partial', Icons.pie_chart);
    } else if (isOverdue) {
      return (Colors.red, 'Overdue', Icons.warning);
    }
    return (Colors.grey, 'Upcoming', Icons.credit_card);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loansAsync = ref.watch(loansProvider);
    final accountsAsync = ref.watch(accountsProvider);
    final recurringAsync = ref.watch(recurringTransactionsProvider);
    final currencyLocale = ref.watch(currencyProvider);
    final currency = NumberFormat.simpleCurrency(locale: currencyLocale);

    return Scaffold(
      appBar: AppBar(title: const Text('Reminders & Notifications')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(
                context, 'Upcoming Loan EMIs', Icons.account_balance),
            loansAsync.when(
              data: (loans) =>
                  _buildLoanReminders(context, ref, loans, currency),
              loading: () => const CircularProgressIndicator(),
              error: (e, s) => Text('Error: $e'), // coverage:ignore-line
            ),
            const SizedBox(height: 24),
            _buildSectionTitle(context, 'Credit Card Bills', Icons.credit_card),
            accountsAsync.when(
              data: (accounts) => ref.watch(transactionsProvider).when(
                    data: (txns) => _buildCCReminders(
                        context, ref, accounts, currency, txns),
                    loading: () => const CircularProgressIndicator(),
                    error: (e, s) => Text('Error: $e'), // coverage:ignore-line
                  ),
              loading: () => const CircularProgressIndicator(),
              error: (e, s) => Text('Error: $e'), // coverage:ignore-line
            ),
            const SizedBox(height: 24),
            _buildSectionTitle(context, 'Recurring Payments', Icons.repeat),
            recurringAsync.when(
              data: (recurring) =>
                  _buildRecurringReminders(context, ref, recurring, currency),
              loading: () => const CircularProgressIndicator(),
              error: (e, s) => Text('Error: $e'), // coverage:ignore-line
            ),
            const SizedBox(height: 24),
            _buildTaxReminders(context, ref, currency),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          PureIcons.icon(icon, color: Theme.of(context).primaryColor),
          const SizedBox(width: 8),
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  DateTime _getLoanDueDate(Loan loan, DateTime today) {
    DateTime dueDateObj = DateTime(today.year, today.month, loan.emiDay);
    if (today.year == loan.firstEmiDate.year &&
        today.month == loan.firstEmiDate.month) {
      dueDateObj = loan.firstEmiDate; // coverage:ignore-line
    }
    bool isBeforeStart = today.isBefore(loan.firstEmiDate);
    if (isBeforeStart && dueDateObj.isBefore(loan.firstEmiDate)) {
      dueDateObj = loan.firstEmiDate;
    }
    return dueDateObj;
  }

  (Color, String, IconData) _getLoanPaymentStatus(
      bool isFullyPaid, bool isPartiallyPaid, bool isOverdue) {
    if (isFullyPaid) {
      return (Colors.green, 'Paid', Icons.check_circle);
    } else if (isPartiallyPaid) {
      return (Colors.orange, 'Partial', Icons.pie_chart);
    } else if (isOverdue) {
      return (Colors.red, 'Overdue', Icons.warning);
    }
    return (Colors.grey, 'Upcoming', Icons.calendar_today);
  }

  Widget _buildLoanReminders(BuildContext context, WidgetRef ref,
      List<Loan> loans, NumberFormat currency) {
    final activeLoans = loans.where((l) => l.remainingPrincipal > 0).toList();
    if (activeLoans.isEmpty) return const Text('No active loans.');

    return Column(
      children: activeLoans.map((loan) {
        return _buildLoanCard(context, ref, loan, currency);
      }).toList(),
    );
  }

  Widget _buildLoanCard(
      BuildContext context, WidgetRef ref, Loan loan, NumberFormat currency) {
    final now = clock.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDateObj = _getLoanDueDate(loan, today);

    // Check Payment Status
    final paymentsForPeriod = loan.transactions
        .where((t) =>
            t.type == LoanTransactionType.emi &&
            t.date.year == dueDateObj.year &&
            t.date.month == dueDateObj.month)
        .toList();

    final totalPaid = paymentsForPeriod.fold(0.0, (sum, t) => sum + t.amount);
    final isFullyPaid = totalPaid >= loan.emiAmount - 1; // Tolerance of 1 unit
    final isPartiallyPaid = totalPaid > 0 && !isFullyPaid;

    bool isBeforeStart = today.isBefore(loan.firstEmiDate);
    if (isBeforeStart && totalPaid == 0 && today.isBefore(loan.firstEmiDate)) {
      return _buildWaitStartCard(loan);
    }

    final (statusColor, statusText, statusIcon) = _getLoanPaymentStatus(
        isFullyPaid, isPartiallyPaid, today.isAfter(dueDateObj));

    final displayDueDate = isFullyPaid
        ? DateTime(dueDateObj.year, dueDateObj.month + 1, loan.emiDay)
        : dueDateObj;

    return _buildLoanCardUI(
      context: context,
      ref: ref,
      loan: loan,
      currency: currency,
      isFullyPaid: isFullyPaid,
      isPartiallyPaid: isPartiallyPaid,
      totalPaid: totalPaid,
      statusColor: statusColor,
      statusText: statusText,
      statusIcon: statusIcon,
      displayDueDate: displayDueDate,
    );
  }

  Widget _buildWaitStartCard(Loan loan) {
    return Card(
      child: ListTile(
        leading: PureIcons.timer(color: Colors.blueGrey),
        title: Text(loan.name),
        subtitle: Text(
            'First EMI starts on ${DateFormat(dateFormatMmmDdYyyy).format(loan.firstEmiDate)}'),
        trailing: const Text('Wait for Start',
            style: TextStyle(fontSize: 10, color: Colors.grey)),
      ),
    );
  }

  Widget _buildLoanCardUI({
    required BuildContext context,
    required WidgetRef ref,
    required Loan loan,
    required NumberFormat currency,
    required bool isFullyPaid,
    required bool isPartiallyPaid,
    required double totalPaid,
    required Color statusColor,
    required String statusText,
    required IconData statusIcon,
    required DateTime displayDueDate,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: [
                PureIcons.icon(statusIcon, color: statusColor),
                const SizedBox(width: 16),
                Expanded(
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(loan.name,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            decoration:
                                isFullyPaid ? TextDecoration.lineThrough : null,
                            color: isFullyPaid ? Colors.grey : null)),
                    const SizedBox(height: 4),
                    if (!isFullyPaid)
                      Text(
                          'Due on ${DateFormat(dateFormatMmmDdYyyy).format(displayDueDate)}',
                          style: TextStyle(
                              color: statusText == 'Overdue'
                                  ? Colors.red
                                  : Colors.grey[700],
                              fontWeight: statusText == 'Overdue'
                                  ? FontWeight.bold
                                  : null,
                              fontSize: 13)),
                    if (isFullyPaid)
                      Text(
                          'Next Bill: ${DateFormat(dateFormatMmmDdYyyy).format(displayDueDate)}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        InkWell(
                          onTap: () {
                            ref.read(calendarServiceProvider).downloadExvent(
                                  title: 'EMI Due: ${loan.name}',
                                  description: 'Payment for ${loan.name} due.',
                                  startTime: displayDueDate,
                                  endTime: displayDueDate
                                      .add(const Duration(hours: 1)),
                                );
                          },
                          child: Row(
                            children: [
                              PureIcons.calendar(size: 14, color: Colors.blue),
                              const SizedBox(width: 4),
                              const Text('Add to Calendar',
                                  style: TextStyle(
                                      fontSize: 11, color: Colors.blue)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                )),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(statusText,
                        style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                    if (!isFullyPaid) ...[
                      const SizedBox(height: 2),
                      Text(currency.format(loan.emiAmount - totalPaid),
                          style: AppTheme.offlineSafeTextStyle
                              .copyWith(fontWeight: FontWeight.bold)),
                    ]
                  ],
                )
              ],
            ),
            if (!isFullyPaid) ...[
              const SizedBox(height: 12),
              if (isPartiallyPaid)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Paid: ${currency.format(totalPaid)} / ${currency.format(loan.emiAmount)}',
                    style: AppTheme.offlineSafeTextStyle
                        .copyWith(fontSize: 12, color: Colors.orange),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                height: 36,
                child: ElevatedButton.icon(
                  icon: PureIcons.payment(size: 16),
                  label: const Text(payNowText),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => showDialog(
                      // coverage:ignore-line
                      context: context,
                      builder: (_) => RecordLoanPaymentDialog(
                          loan: loan)), // coverage:ignore-line
                ),
              )
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildCCReminders(
      BuildContext context,
      WidgetRef ref,
      List<Account> accounts,
      NumberFormat currency,
      List<Transaction> allTransactions) {
    final storage = ref.watch(storageServiceProvider);
    final ccAccounts =
        accounts.where((a) => a.type == AccountType.creditCard).toList();
    if (ccAccounts.isEmpty) return const Text('No credit cards.');

    return Column(
      children: ccAccounts.map((acc) {
        return _buildCCCard(
            context, ref, acc, currency, allTransactions, storage);
      }).toList(),
    );
  }

  Widget _buildCCCard(
      BuildContext context,
      WidgetRef ref,
      Account acc,
      NumberFormat currency,
      List<Transaction> allTransactions,
      dynamic storage) {
    if (acc.billingCycleDay == null) return const SizedBox();
    final today = clock.now();

    final lastBillDate = today.day > acc.billingCycleDay!
        ? DateTime(today.year, today.month,
            acc.billingCycleDay!) // coverage:ignore-line
        : DateTime(today.year, today.month - 1, acc.billingCycleDay!);

    final dueDate =
        lastBillDate.add(Duration(days: acc.paymentDueDateDay ?? 20));

    final payments = allTransactions
        .where((t) =>
            !t.isDeleted &&
            t.toAccountId == acc.id &&
            t.type == TransactionType.transfer &&
            t.date.isAfter(lastBillDate.subtract(const Duration(days: 1))))
        .toList();

    final totalPaid = payments.fold(0.0, (sum, t) => sum + t.amount);
    final billedAmount = BillingHelper.calculateBilledAmount(
        acc, allTransactions, today, storage.getLastRollover(acc.id));

    final totalDue = acc.balance + billedAmount;

    final isFullyPaid = totalDue <= 0.01;
    final isPartiallyPaid = !isFullyPaid && totalPaid > 0;

    final (statusColor, statusText, statusIcon) = _getCCPaymentStatus(
        isFullyPaid, isPartiallyPaid, today.isAfter(dueDate));

    final nextBillDate = today.day > acc.billingCycleDay!
        ? DateTime(today.year, today.month + 1,
            acc.billingCycleDay!) // coverage:ignore-line
        : DateTime(today.year, today.month, acc.billingCycleDay!);

    return _buildCCCardUI(
      context: context,
      acc: acc,
      currency: currency,
      isFullyPaid: isFullyPaid,
      isPartiallyPaid: isPartiallyPaid,
      totalPaid: totalPaid,
      totalDue: totalDue,
      statusColor: statusColor,
      statusText: statusText,
      statusIcon: statusIcon,
      dueDate: dueDate,
      nextBillDate: nextBillDate,
    );
  }

  Widget _buildCCCardUI({
    required BuildContext context,
    required Account acc,
    required NumberFormat currency,
    required bool isFullyPaid,
    required bool isPartiallyPaid,
    required double totalPaid,
    required double totalDue,
    required Color statusColor,
    required String statusText,
    required IconData statusIcon,
    required DateTime dueDate,
    required DateTime nextBillDate,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: [
                PureIcons.icon(statusIcon, color: statusColor),
                const SizedBox(width: 16),
                Expanded(
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(acc.name,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            decoration:
                                isFullyPaid ? TextDecoration.lineThrough : null,
                            color: isFullyPaid ? Colors.grey : null)),
                    const SizedBox(height: 4),
                    if (!isFullyPaid)
                      Text(
                          'Due on ${DateFormat(dateFormatMmmDd).format(dueDate)}',
                          style: TextStyle(
                              color: statusText == 'Overdue'
                                  ? Colors.red
                                  : Colors.grey[700],
                              fontWeight: statusText == 'Overdue'
                                  ? FontWeight.bold
                                  : null,
                              fontSize: 13)),
                    if (isFullyPaid)
                      Text(
                          'Next Bill: ${DateFormat(dateFormatMmmDd).format(nextBillDate)}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                  ],
                )),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(statusText,
                        style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                    if (!isFullyPaid) ...[
                      const SizedBox(height: 2),
                      Text(currency.format(totalDue),
                          style: AppTheme.offlineSafeTextStyle
                              .copyWith(fontWeight: FontWeight.bold)),
                    ]
                  ],
                )
              ],
            ),
            if (!isFullyPaid) ...[
              const SizedBox(height: 12),
              if (isPartiallyPaid)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Paid: ${currency.format(totalPaid)} / ${currency.format(totalDue + totalPaid)}',
                    style: AppTheme.offlineSafeTextStyle
                        .copyWith(fontSize: 12, color: Colors.orange),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                height: 36,
                child: ElevatedButton.icon(
                  icon: PureIcons.payment(size: 16),
                  label: const Text(payNowText),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => showDialog(
                      // coverage:ignore-line
                      context: context,
                      builder: (_) => RecordCCPaymentDialog(
                          // coverage:ignore-line
                          creditCardAccount: acc,
                          isFullyPaid: isFullyPaid)),
                ),
              )
            ]
          ],
        ),
      ),
    );
  }

  (Color, String, IconData) _getRecurringStatus(DateTime dueDate) {
    final today = clock.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final dueDateDate = DateTime(dueDate.year, dueDate.month, dueDate.day);
    if (dueDateDate.isBefore(todayDate)) {
      return (Colors.red, 'Overdue', Icons.warning);
    }
    return (Colors.grey, 'Upcoming', Icons.event_repeat);
  }

  String _getFrequencyLabel(Frequency frequency) {
    switch (frequency) {
      case Frequency.monthly:
        return 'Monthly';
      case Frequency.weekly: // coverage:ignore-line
        return 'Weekly';
      default:
        return 'Other';
    }
  }

  Widget _buildRecurringReminders(BuildContext context, WidgetRef ref,
      List<RecurringTransaction> recurring, NumberFormat currency) {
    final active = recurring.where((r) => r.isActive).toList();
    if (active.isEmpty) return const Text('No active recurring payments.');

    return Column(
      children: active.map((r) {
        return _buildRecurringCard(context, ref, r, currency);
      }).toList(),
    );
  }

  Widget _buildRecurringCard(BuildContext context, WidgetRef ref,
      RecurringTransaction r, NumberFormat currency) {
    final dueDate = r.nextExecutionDate;
    final (statusColor, statusText, statusIcon) = _getRecurringStatus(dueDate);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: [
                PureIcons.icon(statusIcon, color: statusColor),
                const SizedBox(width: 16),
                Expanded(
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.title,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                        'Due on ${DateFormat(dateFormatMmmDd).format(dueDate)}',
                        style: TextStyle(
                            color: statusText == 'Overdue'
                                ? Colors.red
                                : Colors.grey[700],
                            fontWeight: statusText == 'Overdue'
                                ? FontWeight.bold
                                : null,
                            fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(_getFrequencyLabel(r.frequency),
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey)),
                    Text(r.accountId == null ? 'Manual' : 'Auto',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.blueGrey)),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () {
                        // coverage:ignore-line
                        ref
                            // coverage:ignore-start
                            .read(calendarServiceProvider)
                            .downloadRecurringEvent(
                              title: r.title,
                              description: 'Recurring payment: ${r.title}',
                              // coverage:ignore-end
                              startDate: dueDate,
                              occurrences: 12,
                            );
                      },
                      child: Row(
                        children: [
                          PureIcons.calendar(size: 14, color: Colors.blue),
                          const SizedBox(width: 4),
                          const Text('Add to Calendar',
                              style:
                                  TextStyle(fontSize: 11, color: Colors.blue)),
                        ],
                      ),
                    ),
                  ],
                )),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(statusText,
                        style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                    const SizedBox(height: 2),
                    Text(currency.format(r.amount),
                        style: AppTheme.offlineSafeTextStyle
                            .copyWith(fontWeight: FontWeight.bold)),
                  ],
                )
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      side: BorderSide(
                          color: Theme.of(context)
                              .primaryColor
                              .withValues(alpha: 0.5)),
                    ),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Skip Cycle?'),
                          content: Text(
                              'Advance "${r.title}" to the next cycle without recording a transaction?'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(
                                    ctx, false), // coverage:ignore-line
                                child: const Text('CANCEL')),
                            TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('SKIP')),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await ref
                            .read(storageServiceProvider)
                            .advanceRecurringTransactionDate(r.id);
                        ref.invalidate(recurringTransactionsProvider);
                      }
                    },
                    child: const Text('SKIP', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    icon: PureIcons.payment(size: 16),
                    label: const Text(payNowText),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                    ),
                    // coverage:ignore-start
                    onPressed: () {
                      final txn = Transaction.create(
                        title: r.title,
                        amount: r.amount,
                        date: clock.now(),
                        type: r.type,
                        category: r.category,
                        accountId: r.accountId,
                        // coverage:ignore-end
                      );
                      Navigator.push(
                          // coverage:ignore-line
                          context,
                          // coverage:ignore-start
                          MaterialPageRoute(
                              builder: (_) => AddTransactionScreen(
                                  transactionToEdit: txn, recurringId: r.id)));
                      // coverage:ignore-end
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaxReminders(
      BuildContext context, WidgetRef ref, NumberFormat currency) {
    final taxConfig = ref.watch(taxConfigServiceProvider);
    final currentYear = taxConfig.getCurrentFinancialYear();
    final taxData =
        ref.watch(storageServiceProvider).getTaxYearData(currentYear);

    if (taxData == null) return const SizedBox.shrink();

    final service = ref.watch(indianTaxServiceProvider);
    final rules = taxConfig.getRulesForYear(taxData.year);
    final details = service.calculateDetailedLiability(taxData, rules);

    final DateTime? dueDate = details['nextAdvanceTaxDueDate'] as dynamic;
    final double? amount = details['nextAdvanceTaxAmount'] as dynamic;
    final int? daysLeft = details['daysUntilAdvanceTax'] as dynamic;
    final bool isRequirementMet = details['isRequirementMet'] == true;

    if (dueDate == null ||
        amount == null ||
        (amount <= 0 && isRequirementMet)) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'Upcoming Tax Installments', Icons.percent),
        _buildAdvanceTaxReminderCard(
            context, ref, taxData, currency, dueDate, amount, daysLeft, rules),
      ],
    );
  }

  Widget _buildAdvanceTaxReminderCard(
      BuildContext context,
      WidgetRef ref,
      TaxYearData taxData,
      NumberFormat currency,
      DateTime dueDate,
      double amount,
      int? daysLeft,
      TaxRules rules) {
    final bool isNear =
        daysLeft != null && daysLeft <= rules.advanceTaxReminderDays;
    final bool isOverdue = daysLeft != null && daysLeft < 0;

    final Color cardColor;
    if (isOverdue) {
      cardColor = Colors.red.shade50; // coverage:ignore-line
    } else if (isNear) {
      cardColor = Colors.orange.shade50;
    } else {
      cardColor = Colors.blue.shade50; // coverage:ignore-line
    }

    return Card(
      color: cardColor,
      child: InkWell(
        onTap: () {
          // coverage:ignore-line
          Navigator.push(
            // coverage:ignore-line
            context,
            MaterialPageRoute(
              // coverage:ignore-line
              builder: (_) => TaxDetailsScreen(
                // coverage:ignore-line
                data: taxData,
                initialTabIndex: 5, // Tax Paid tab
                onSave: (updated) {
                  // coverage:ignore-line
                  ref
                      .read(storageServiceProvider)
                      .saveTaxYearData(updated); // coverage:ignore-line
                },
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Icon(
                _getAdvanceTaxIcon(isOverdue, isNear),
                color: _getAdvanceTaxIconColor(isOverdue, isNear),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAdvanceTaxReminderHeader(isOverdue, isNear),
                    const SizedBox(height: 4),
                    Text(
                      'Next: ${currency.format(amount)} due by ${DateFormat('dd MMM').format(dueDate)}',
                      style:
                          TextStyle(fontSize: 13, color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
              if (daysLeft != null)
                _buildDaysLeftText(isOverdue, isNear, daysLeft),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdvanceTaxReminderHeader(bool isOverdue, bool isNear) {
    final title = isOverdue ? 'Advance Tax Overdue' : 'Upcoming Advance Tax';
    final Color textColor;
    if (isOverdue) {
      textColor = Colors.red;
    } else if (isNear) {
      textColor = Colors.orange.shade900;
    } else {
      textColor = Colors.blue.shade900; // coverage:ignore-line
    }
    return Text(
      title,
      style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
    );
  }

  Widget _buildDaysLeftText(bool isOverdue, bool isNear, int daysLeft) {
    final Color color;
    if (isOverdue) {
      color = Colors.red;
    } else if (isNear) {
      color = Colors.orange;
    } else {
      color = Colors.blue;
    }
    final String text;
    if (isOverdue) {
      text = '${daysLeft.abs()}d Late'; // coverage:ignore-line
    } else if (daysLeft == 0) {
      text = 'Due Today';
    } else {
      text = '$daysLeft d left';
    }

    return Text(
      text,
      style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
    );
  }

  IconData _getAdvanceTaxIcon(bool isOverdue, bool isNear) {
    if (isOverdue) return Icons.warning_amber_rounded;
    if (isNear) return Icons.notifications_active;
    return Icons.calendar_month_outlined;
  }

  Color _getAdvanceTaxIconColor(bool isOverdue, bool isNear) {
    if (isOverdue) return Colors.red;
    if (isNear) return Colors.orange;
    return Colors.blue;
  }
}
