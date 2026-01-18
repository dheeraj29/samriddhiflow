import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers.dart';
import '../feature_providers.dart';
import 'cc_payment_dialog.dart';
import 'loan_payment_dialog.dart';
import 'add_transaction_screen.dart';
import 'package:samriddhi_flow/models/loan.dart';
import 'package:samriddhi_flow/models/account.dart';
import 'package:samriddhi_flow/models/transaction.dart';
import 'package:samriddhi_flow/models/recurring_transaction.dart';
import '../widgets/pure_icons.dart';
import '../theme/app_theme.dart';

class RemindersScreen extends ConsumerWidget {
  const RemindersScreen({super.key});

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
              error: (e, s) => Text('Error: $e'),
            ),
            const SizedBox(height: 24),
            _buildSectionTitle(context, 'Credit Card Bills', Icons.credit_card),
            accountsAsync.when(
              data: (accounts) => ref.watch(transactionsProvider).when(
                    data: (txns) =>
                        _buildCCReminders(context, accounts, currency, txns),
                    loading: () => const CircularProgressIndicator(),
                    error: (e, s) => Text('Error: $e'),
                  ),
              loading: () => const CircularProgressIndicator(),
              error: (e, s) => Text('Error: $e'),
            ),
            const SizedBox(height: 24),
            _buildSectionTitle(context, 'Recurring Payments', Icons.repeat),
            recurringAsync.when(
              data: (recurring) =>
                  _buildRecurringReminders(context, ref, recurring, currency),
              loading: () => const CircularProgressIndicator(),
              error: (e, s) => Text('Error: $e'),
            ),
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

  Widget _buildLoanReminders(BuildContext context, WidgetRef ref,
      List<Loan> loans, NumberFormat currency) {
    final activeLoans = loans.where((l) => l.remainingPrincipal > 0).toList();
    if (activeLoans.isEmpty) return const Text('No active loans.');

    return Column(
      children: activeLoans.map((loan) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        // 1. Determine Correct Due Date
        DateTime dueDateObj = DateTime(today.year, today.month, loan.emiDay);

        if (today.year == loan.firstEmiDate.year &&
            today.month == loan.firstEmiDate.month) {
          dueDateObj = loan.firstEmiDate;
        }

        bool isBeforeStart = today.isBefore(loan.firstEmiDate);
        if (isBeforeStart && dueDateObj.isBefore(loan.firstEmiDate)) {
          dueDateObj = loan.firstEmiDate;
        }

        // 2. Check Payment Status
        final checkDate = dueDateObj;

        final paymentsForPeriod = loan.transactions
            .where((t) =>
                t.type == LoanTransactionType.emi &&
                t.date.year == checkDate.year &&
                t.date.month == checkDate.month)
            .toList();

        final totalPaid =
            paymentsForPeriod.fold(0.0, (sum, t) => sum + t.amount);
        final isFullyPaid =
            totalPaid >= loan.emiAmount - 1; // Tolerance of 1 unit
        final isPartiallyPaid = totalPaid > 0 && !isFullyPaid;

        if (isBeforeStart &&
            totalPaid == 0 &&
            today.isBefore(loan.firstEmiDate)) {
          // Display "Wait for Start" card
          return Card(
            child: ListTile(
              leading: PureIcons.timer(color: Colors.blueGrey),
              title: Text(loan.name),
              subtitle: Text(
                  'First EMI starts on ${DateFormat('MMM dd, yyyy').format(loan.firstEmiDate)}'),
              trailing: const Text('Wait for Start',
                  style: TextStyle(fontSize: 10, color: Colors.grey)),
            ),
          );
        }

        Color statusColor = Colors.grey;
        String statusText = 'Upcoming';
        IconData statusIcon = Icons.calendar_today;

        if (isFullyPaid) {
          statusColor = Colors.green;
          statusText = 'Paid';
          statusIcon = Icons.check_circle;
        } else if (isPartiallyPaid) {
          statusColor = Colors.orange;
          statusText = 'Partial';
          statusIcon = Icons.pie_chart;
        } else if (today.isAfter(dueDateObj)) {
          statusColor = Colors.red;
          statusText = 'Overdue';
          statusIcon = Icons.warning;
        }

        final displayDueDate = isFullyPaid
            ? DateTime(dueDateObj.year, dueDateObj.month + 1, loan.emiDay)
            : dueDateObj;

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
                                decoration: isFullyPaid
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: isFullyPaid ? Colors.grey : null)),
                        const SizedBox(height: 4),
                        if (!isFullyPaid)
                          Text(
                              'Due on ${DateFormat('MMM dd, yyyy').format(displayDueDate)}',
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
                              'Next Bill: ${DateFormat('MMM dd, yyyy').format(displayDueDate)}',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            InkWell(
                              onTap: () {
                                ref
                                    .read(calendarServiceProvider)
                                    .downloadExvent(
                                      title: 'EMI Due: ${loan.name}',
                                      description:
                                          'Payment for ${loan.name} due.',
                                      startTime: displayDueDate,
                                      endTime: displayDueDate
                                          .add(const Duration(hours: 1)),
                                    );
                              },
                              child: Row(
                                children: [
                                  PureIcons.calendar(
                                      size: 14, color: Colors.blue),
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
                      label: const Text('PAY NOW'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => showDialog(
                          context: context,
                          builder: (_) => RecordLoanPaymentDialog(loan: loan)),
                    ),
                  )
                ]
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCCReminders(BuildContext context, List<Account> accounts,
      NumberFormat currency, List<Transaction> allTransactions) {
    final ccAccounts =
        accounts.where((a) => a.type == AccountType.creditCard).toList();
    if (ccAccounts.isEmpty) return const Text('No credit cards.');

    return Column(
      children: ccAccounts.map((acc) {
        if (acc.billingCycleDay == null) return const SizedBox();

        final today = DateTime.now();
        final lastBillDate = today.day >= acc.billingCycleDay!
            ? DateTime(today.year, today.month, acc.billingCycleDay!)
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
        final billedAmount = acc.calculateBilledAmount(allTransactions);

        final isFullyPaid =
            acc.balance <= 0 || (billedAmount > 0 && totalPaid >= billedAmount);
        final isPartiallyPaid = !isFullyPaid && totalPaid > 0;

        Color statusColor = Colors.grey;
        String statusText = 'Upcoming';
        IconData statusIcon = Icons.credit_card;

        if (isFullyPaid) {
          statusColor = Colors.green;
          statusText = 'Paid';
          statusIcon = Icons.check_circle;
        } else if (isPartiallyPaid) {
          statusColor = Colors.orange;
          statusText = 'Partial';
          statusIcon = Icons.pie_chart;
        } else if (today.isAfter(dueDate)) {
          statusColor = Colors.red;
          statusText = 'Overdue';
          statusIcon = Icons.warning;
        }

        final nextBillDate =
            DateTime(today.year, today.month + 1, acc.billingCycleDay!);

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
                                decoration: isFullyPaid
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: isFullyPaid ? Colors.grey : null)),
                        const SizedBox(height: 4),
                        if (!isFullyPaid)
                          Text('Due on ${DateFormat('MMM dd').format(dueDate)}',
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
                              'Next Bill: ${DateFormat('MMM dd').format(nextBillDate)}',
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
                          Text(currency.format(acc.balance),
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
                        'Paid: ${currency.format(totalPaid)} / ${currency.format(billedAmount > 0 ? billedAmount : acc.balance)}',
                        style: AppTheme.offlineSafeTextStyle
                            .copyWith(fontSize: 12, color: Colors.orange),
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    height: 36,
                    child: ElevatedButton.icon(
                      icon: PureIcons.payment(size: 16),
                      label: const Text('PAY NOW'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => showDialog(
                          context: context,
                          builder: (_) =>
                              RecordCCPaymentDialog(creditCardAccount: acc)),
                    ),
                  )
                ]
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRecurringReminders(BuildContext context, WidgetRef ref,
      List<RecurringTransaction> recurring, NumberFormat currency) {
    final active = recurring.where((r) => r.isActive).toList();
    if (active.isEmpty) return const Text('No active recurring payments.');

    return Column(
      children: active.map((r) {
        final today = DateTime.now();
        final dueDate = r.nextExecutionDate;

        Color statusColor = Colors.grey;
        String statusText = 'Upcoming';
        IconData statusIcon = Icons.event_repeat;

        final todayDate = DateTime(today.year, today.month, today.day);
        final dueDateDate = DateTime(dueDate.year, dueDate.month, dueDate.day);

        if (dueDateDate.isBefore(todayDate)) {
          statusColor = Colors.red;
          statusText = 'Overdue';
          statusIcon = Icons.warning;
        }

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
                        Text('Due on ${DateFormat('MMM dd').format(dueDate)}',
                            style: TextStyle(
                                color: statusText == 'Overdue'
                                    ? Colors.red
                                    : Colors.grey[700],
                                fontWeight: statusText == 'Overdue'
                                    ? FontWeight.bold
                                    : null,
                                fontSize: 13)),
                        const SizedBox(height: 2),
                        Text(
                            r.frequency == Frequency.monthly
                                ? 'Monthly'
                                : (r.frequency == Frequency.weekly
                                    ? 'Weekly'
                                    : 'Other'),
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey)),
                        Text(r.accountId == null ? 'Manual' : 'Auto',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.blueGrey)),
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: () {
                            ref
                                .read(calendarServiceProvider)
                                .downloadRecurringEvent(
                                  title: r.title,
                                  description: 'Recurring payment: ${r.title}',
                                  startDate: dueDate,
                                  occurrences: 12,
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
                SizedBox(
                  width: double.infinity,
                  height: 36,
                  child: ElevatedButton.icon(
                    icon: PureIcons.payment(size: 16),
                    label: const Text('PAY NOW'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      final txn = Transaction.create(
                        title: r.title,
                        amount: r.amount,
                        date: DateTime.now(),
                        type: TransactionType.expense,
                        category: r.category,
                        accountId: r.accountId,
                      );
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => AddTransactionScreen(
                                  transactionToEdit: txn, recurringId: r.id)));
                    },
                  ),
                )
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
