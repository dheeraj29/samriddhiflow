import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samriddhi_flow/l10n/app_localizations.dart';
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
import '../services/storage_service.dart';
import 'package:clock/clock.dart';
import 'package:intl/intl.dart';

const dateFormatMmmDd = 'MMM dd';
const dateFormatMmmDdYyyy = 'MMM dd, yyyy';

class RemindersScreen extends ConsumerStatefulWidget {
  const RemindersScreen({super.key});

  @override
  ConsumerState<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends ConsumerState<RemindersScreen> {
  bool _isLoanExpanded = false;
  bool _isCCExpanded = false;
  bool _isRecurringExpanded = false;
  bool _isTaxExpanded = false;

  (Color, String, IconData) _getCCPaymentStatus(BuildContext context,
      bool isFullyPaid, bool isPartiallyPaid, bool isOverdue) {
    final l10n = AppLocalizations.of(context)!;
    if (isFullyPaid) {
      return (
        Colors.green,
        l10n.paidStatus,
        Icons.check_circle
      ); // coverage:ignore-line
    } else if (isPartiallyPaid) {
      return (Colors.orange, l10n.partialStatus, Icons.pie_chart);
    } else if (isOverdue) {
      return (Colors.red, l10n.overdueStatus, Icons.warning);
    }
    return (
      Colors.grey,
      l10n.upcomingStatus,
      Icons.credit_card
    ); // coverage:ignore-line
  }

  @override
  Widget build(BuildContext context) {
    final loansAsync = ref.watch(loansProvider);
    final accountsAsync = ref.watch(accountsProvider);
    final transactionsAsync = ref.watch(transactionsProvider);
    final recurringAsync = ref.watch(recurringTransactionsProvider);
    final currencyLocale = ref.watch(currencyProvider);
    final currency = NumberFormat.simpleCurrency(locale: currencyLocale);
    final now = clock.now();
    final today = DateTime(now.year, now.month, now.day);

    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.remindersTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            loansAsync.when(
              data: (loans) => _buildExpandableSection(
                context: context,
                title: l10n.upcomingLoanEMIs,
                icon: Icons.account_balance,
                isExpanded: _isLoanExpanded,
                onToggle: () =>
                    setState(() => _isLoanExpanded = !_isLoanExpanded),
                pendingCount: _countPendingLoans(loans, today),
                child: _buildLoanReminders(context, ref, loans, currency),
              ),
              loading: () => _buildExpandableSection(
                context: context,
                title: l10n.upcomingLoanEMIs,
                icon: Icons.account_balance,
                isExpanded: _isLoanExpanded,
                onToggle: () => // coverage:ignore-line
                    setState(() => _isLoanExpanded =
                        !_isLoanExpanded), // coverage:ignore-line
                pendingCount: 0,
                child: const CircularProgressIndicator(),
              ),
              error: (e, s) => _buildExpandableSection(
                // coverage:ignore-line
                context: context,
                title: l10n.upcomingLoanEMIs, // coverage:ignore-line
                icon: Icons.account_balance,
                // coverage:ignore-start
                isExpanded: _isLoanExpanded,
                onToggle: () =>
                    setState(() => _isLoanExpanded = !_isLoanExpanded),
                // coverage:ignore-end
                pendingCount: 0,
                child:
                    Text(l10n.errorLabel(e.toString())), // coverage:ignore-line
              ),
            ),
            const SizedBox(height: 24),
            accountsAsync.when(
              data: (accounts) => transactionsAsync.when(
                data: (txns) => _buildExpandableSection(
                  context: context,
                  title: l10n.creditCardBills,
                  icon: Icons.credit_card,
                  isExpanded: _isCCExpanded,
                  onToggle: () =>
                      setState(() => _isCCExpanded = !_isCCExpanded),
                  pendingCount: _countPendingCreditCards(accounts, txns, now),
                  child:
                      _buildCCReminders(context, ref, accounts, currency, txns),
                ),
                loading: () => _buildExpandableSection(
                  // coverage:ignore-line
                  context: context,
                  title: l10n.creditCardBills, // coverage:ignore-line
                  icon: Icons.credit_card,
                  // coverage:ignore-start
                  isExpanded: _isCCExpanded,
                  onToggle: () =>
                      setState(() => _isCCExpanded = !_isCCExpanded),
                  // coverage:ignore-end
                  pendingCount: 0,
                  child: const CircularProgressIndicator(),
                ),
                error: (e, s) => _buildExpandableSection(
                  // coverage:ignore-line
                  context: context,
                  title: l10n.creditCardBills, // coverage:ignore-line
                  icon: Icons.credit_card,
                  // coverage:ignore-start
                  isExpanded: _isCCExpanded,
                  onToggle: () =>
                      setState(() => _isCCExpanded = !_isCCExpanded),
                  // coverage:ignore-end
                  pendingCount: 0,
                  child: Text(
                      l10n.errorLabel(e.toString())), // coverage:ignore-line
                ),
              ),
              loading: () => _buildExpandableSection(
                context: context,
                title: l10n.creditCardBills,
                icon: Icons.credit_card,
                isExpanded: _isCCExpanded,
                onToggle: () => setState(() =>
                    _isCCExpanded = !_isCCExpanded), // coverage:ignore-line
                pendingCount: 0,
                child: const CircularProgressIndicator(),
              ),
              error: (e, s) => _buildExpandableSection(
                // coverage:ignore-line
                context: context,
                title: l10n.creditCardBills, // coverage:ignore-line
                icon: Icons.credit_card,
                isExpanded: _isCCExpanded, // coverage:ignore-line
                onToggle: () => setState(() =>
                    _isCCExpanded = !_isCCExpanded), // coverage:ignore-line
                pendingCount: 0,
                child:
                    Text(l10n.errorLabel(e.toString())), // coverage:ignore-line
              ),
            ),
            const SizedBox(height: 24),
            recurringAsync.when(
              data: (recurring) => _buildExpandableSection(
                context: context,
                title: l10n.recurringPaymentsTitle,
                icon: Icons.repeat,
                isExpanded: _isRecurringExpanded,
                onToggle: () => setState(
                    () => _isRecurringExpanded = !_isRecurringExpanded),
                pendingCount: _countPendingRecurring(recurring, today),
                child:
                    _buildRecurringReminders(context, ref, recurring, currency),
              ),
              loading: () => _buildExpandableSection(
                context: context,
                title: l10n.recurringPaymentsTitle,
                icon: Icons.repeat,
                isExpanded: _isRecurringExpanded,
                onToggle: () => setState(// coverage:ignore-line
                    () => _isRecurringExpanded =
                        !_isRecurringExpanded), // coverage:ignore-line
                pendingCount: 0,
                child: const CircularProgressIndicator(),
              ),
              error: (e, s) => _buildExpandableSection(
                // coverage:ignore-line
                context: context,
                title: l10n.recurringPaymentsTitle, // coverage:ignore-line
                icon: Icons.repeat,
                // coverage:ignore-start
                isExpanded: _isRecurringExpanded,
                onToggle: () => setState(
                    () => _isRecurringExpanded = !_isRecurringExpanded),
                // coverage:ignore-end
                pendingCount: 0,
                child:
                    Text(l10n.errorLabel(e.toString())), // coverage:ignore-line
              ),
            ),
            const SizedBox(height: 24),
            _buildTaxSection(context, currency),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandableSection({
    required BuildContext context,
    required String title,
    required IconData icon,
    required bool isExpanded,
    required VoidCallback onToggle,
    required int pendingCount,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          onTap: () {
            onToggle();
          },
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          leading: PureIcons.icon(icon, color: theme.colorScheme.primary),
          title: Text(title,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isExpanded && pendingCount > 0)
                _buildPendingCountBadge(pendingCount),
              AnimatedRotation(
                turns: isExpanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child:
                    Icon(Icons.expand_more, color: theme.colorScheme.onSurface),
              ),
            ],
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: child,
          ),
          crossFadeState:
              isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
      ],
    );
  }

  Widget _buildPendingCountBadge(int count) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.red.shade100,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        count.toString(),
        style: TextStyle(
          color: Colors.red.shade700,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  DateTime _getLoanDueDate(Loan loan, DateTime today) {
    DateTime dueDateObj = DateTime(today.year, today.month, loan.emiDay);
    if (today.year == loan.firstEmiDate.year &&
        today.month == loan.firstEmiDate.month) {
      dueDateObj = loan.firstEmiDate;
    }
    bool isBeforeStart = today.isBefore(loan.firstEmiDate);
    if (isBeforeStart && dueDateObj.isBefore(loan.firstEmiDate)) {
      dueDateObj = loan.firstEmiDate; // coverage:ignore-line
    }
    return dueDateObj;
  }

  (Color, String, IconData) _getLoanPaymentStatus(BuildContext context,
      bool isFullyPaid, bool isPartiallyPaid, bool isOverdue) {
    final l10n = AppLocalizations.of(context)!;
    if (isFullyPaid) {
      return (
        Colors.green,
        l10n.paidStatus,
        Icons.check_circle
      ); // coverage:ignore-line
    } else if (isPartiallyPaid) {
      return (Colors.orange, l10n.partialStatus, Icons.pie_chart);
    } else if (isOverdue) {
      return (Colors.red, l10n.overdueStatus, Icons.warning);
    }
    return (Colors.grey, l10n.upcomingStatus, Icons.calendar_today);
  }

  Widget _buildLoanReminders(BuildContext context, WidgetRef ref,
      List<Loan> loans, NumberFormat currency) {
    final now = clock.now();
    final today = DateTime(now.year, now.month, now.day);

    final actionableLoans = loans.where((loan) {
      return _shouldShowLoanReminder(loan, today);
    }).toList();

    if (actionableLoans.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(AppLocalizations.of(context)!.noLoanEMIsDue),
      );
    }

    return Column(
      children: actionableLoans.map((loan) {
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
        context, isFullyPaid, isPartiallyPaid, today.isAfter(dueDateObj));

    final displayDueDate = isFullyPaid
        ? DateTime(dueDateObj.year, dueDateObj.month + 1,
            loan.emiDay) // coverage:ignore-line
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.2) // coverage:ignore-line
              : Colors.black.withValues(alpha: 0.1),
        ),
      ),
      child: ListTile(
        leading: PureIcons.timer(color: Colors.blueGrey),
        title: Text(loan.name),
        subtitle: Text(AppLocalizations.of(context)!.firstEMIStartsOn(
            DateFormat(dateFormatMmmDdYyyy).format(loan.firstEmiDate))),
        trailing: Text(AppLocalizations.of(context)!.waitForStartLabel,
            style: const TextStyle(fontSize: 10, color: Colors.grey)),
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
            _buildLoanCardHeader(
              context: context,
              ref: ref,
              loan: loan,
              isFullyPaid: isFullyPaid,
              statusIcon: statusIcon,
              statusColor: statusColor,
              statusText: statusText,
              displayDueDate: displayDueDate,
              totalPaid: totalPaid,
              currency: currency,
            ),
            if (!isFullyPaid) ...[
              const SizedBox(height: 12),
              if (isPartiallyPaid)
                _buildLoanPartialPaymentInfo(
                    context, totalPaid, loan.emiAmount, currency),
              _buildLoanPayNowButton(context, loan),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildLoanCardHeader({
    required BuildContext context,
    required WidgetRef ref,
    required Loan loan,
    required bool isFullyPaid,
    required IconData statusIcon,
    required Color statusColor,
    required String statusText,
    required DateTime displayDueDate,
    required double totalPaid,
    required NumberFormat currency,
  }) {
    return Row(
      children: [
        PureIcons.icon(statusIcon, color: statusColor),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                loan.name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  decoration: isFullyPaid ? TextDecoration.lineThrough : null,
                  color: isFullyPaid ? Colors.grey : null,
                ),
              ),
              const SizedBox(height: 4),
              _buildLoanDueDateText(
                  context, isFullyPaid, displayDueDate, statusText),
              const SizedBox(height: 4),
              _buildLoanCalendarAction(context, ref, loan, displayDueDate),
            ],
          ),
        ),
        _buildLoanStatusInfo(statusText, statusColor, isFullyPaid,
            loan.emiAmount - totalPaid, currency),
      ],
    );
  }

  Widget _buildLoanDueDateText(BuildContext context, bool isFullyPaid,
      DateTime displayDueDate, String statusText) {
    if (isFullyPaid) {
      // coverage:ignore-start
      return Text(
        AppLocalizations.of(context)!.nextBillLabel(
            DateFormat(dateFormatMmmDdYyyy).format(displayDueDate)),
        // coverage:ignore-end
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      );
    }
    final isOverdue = statusText == AppLocalizations.of(context)!.overdueStatus;
    return Text(
      AppLocalizations.of(context)!
          .dueOnLabel(DateFormat(dateFormatMmmDdYyyy).format(displayDueDate)),
      style: TextStyle(
        color: isOverdue ? Colors.red : Colors.grey[700],
        fontWeight: isOverdue ? FontWeight.bold : null,
        fontSize: 13,
      ),
    );
  }

  Widget _buildLoanCalendarAction(
      BuildContext context, WidgetRef ref, Loan loan, DateTime displayDueDate) {
    return InkWell(
      onTap: () {
        ref.read(calendarServiceProvider).downloadExvent(
              title:
                  AppLocalizations.of(context)!.emiDueCalendarTitle(loan.name),
              description: AppLocalizations.of(context)!
                  .emiDueCalendarDescription(loan.name),
              startTime: displayDueDate,
              endTime: displayDueDate.add(const Duration(hours: 1)),
            );
      },
      child: Row(
        children: [
          PureIcons.calendar(size: 14, color: Colors.blue),
          const SizedBox(width: 4),
          Text(
            AppLocalizations.of(context)!.addToCalendarAction,
            style: const TextStyle(fontSize: 11, color: Colors.blue),
          ),
        ],
      ),
    );
  }

  Widget _buildLoanStatusInfo(String statusText, Color statusColor,
      bool isFullyPaid, double remainingDue, NumberFormat currency) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(statusText,
            style: TextStyle(
                color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
        if (!isFullyPaid) ...[
          const SizedBox(height: 2),
          Text(currency.format(remainingDue),
              style: AppTheme.offlineSafeTextStyle
                  .copyWith(fontWeight: FontWeight.bold)),
        ]
      ],
    );
  }

  Widget _buildLoanPartialPaymentInfo(BuildContext context, double totalPaid,
      double emiAmount, NumberFormat currency) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        '${AppLocalizations.of(context)!.paidStatus}: ${currency.format(totalPaid)} / ${currency.format(emiAmount)}',
        style: AppTheme.offlineSafeTextStyle
            .copyWith(fontSize: 12, color: Colors.orange),
      ),
    );
  }

  Widget _buildLoanPayNowButton(BuildContext context, Loan loan) {
    return SizedBox(
      width: double.infinity,
      height: 36,
      child: ElevatedButton.icon(
        icon: PureIcons.payment(size: 16),
        label: Text(AppLocalizations.of(context)!.payNowAction),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
        ),
        // coverage:ignore-start
        onPressed: () {
          FocusScope.of(context).unfocus();
          showDialog(
              // coverage:ignore-end
              context: context,
              builder: (_) =>
                  RecordLoanPaymentDialog(loan: loan)); // coverage:ignore-line
        },
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
    final now = clock.now();

    final actionableCCs = accounts.where((acc) {
      return _shouldShowCCReminder(acc, allTransactions, now, storage);
    }).toList();

    if (actionableCCs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(AppLocalizations.of(context)!.noCCBillsDue),
      );
    }

    return Column(
      children: actionableCCs.map((acc) {
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
    if (acc.billingCycleDay == null) {
      return const SizedBox();
    }
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
            (t.toAccountId == acc.id ||
                (t.accountId == acc.id &&
                    t.type ==
                        TransactionType.income)) && // coverage:ignore-line
            t.date.isAfter(lastBillDate.subtract(const Duration(days: 1))))
        .toList();

    final totalPaid = payments.fold(0.0, (sum, t) => sum + t.amount);
    final billedAmount = BillingHelper.calculateBilledAmount(
        acc, allTransactions, today, storage.getLastRollover(acc.id));

    final totalDue = acc.balance + billedAmount;

    final isFullyPaid = totalDue < 0.01;
    final isPartiallyPaid = !isFullyPaid && totalPaid > 0;

    final (statusColor, statusText, statusIcon) = _getCCPaymentStatus(
        context, isFullyPaid, isPartiallyPaid, today.isAfter(dueDate));

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
            _buildCCCardHeader(
              context: context,
              acc: acc,
              isFullyPaid: isFullyPaid,
              statusIcon: statusIcon,
              statusColor: statusColor,
              statusText: statusText,
              dueDate: dueDate,
              nextBillDate: nextBillDate,
              totalDue: totalDue,
              currency: currency,
            ),
            if (!isFullyPaid) ...[
              const SizedBox(height: 12),
              if (isPartiallyPaid)
                _buildCCPartialPaymentInfo(
                    context, totalPaid, totalDue + totalPaid, currency),
              _buildCCPayNowButton(context, acc, isFullyPaid),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildCCCardHeader({
    required BuildContext context,
    required Account acc,
    required bool isFullyPaid,
    required IconData statusIcon,
    required Color statusColor,
    required String statusText,
    required DateTime dueDate,
    required DateTime nextBillDate,
    required double totalDue,
    required NumberFormat currency,
  }) {
    return Row(
      children: [
        PureIcons.icon(statusIcon, color: statusColor),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                acc.name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  decoration: isFullyPaid ? TextDecoration.lineThrough : null,
                  color: isFullyPaid ? Colors.grey : null,
                ),
              ),
              const SizedBox(height: 4),
              _buildCCDueDateText(
                  context, isFullyPaid, dueDate, nextBillDate, statusText),
            ],
          ),
        ),
        _buildCCStatusInfo(
            statusText, statusColor, isFullyPaid, totalDue, currency),
      ],
    );
  }

  Widget _buildCCDueDateText(BuildContext context, bool isFullyPaid,
      DateTime dueDate, DateTime nextBillDate, String statusText) {
    if (isFullyPaid) {
      // coverage:ignore-start
      return Text(
        AppLocalizations.of(context)!
            .nextBillLabel(DateFormat(dateFormatMmmDd).format(nextBillDate)),
        // coverage:ignore-end
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      );
    }
    final isOverdue = statusText == AppLocalizations.of(context)!.overdueStatus;
    return Text(
      AppLocalizations.of(context)!
          .dueOnLabel(DateFormat(dateFormatMmmDd).format(dueDate)),
      style: TextStyle(
        color: isOverdue ? Colors.red : Colors.grey[700],
        fontWeight: isOverdue ? FontWeight.bold : null,
        fontSize: 13,
      ),
    );
  }

  Widget _buildCCStatusInfo(String statusText, Color statusColor,
      bool isFullyPaid, double totalDue, NumberFormat currency) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(statusText,
            style: TextStyle(
                color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
        if (!isFullyPaid) ...[
          const SizedBox(height: 2),
          Text(currency.format(totalDue),
              style: AppTheme.offlineSafeTextStyle
                  .copyWith(fontWeight: FontWeight.bold)),
        ]
      ],
    );
  }

  Widget _buildCCPartialPaymentInfo(BuildContext context, double totalPaid,
      double totalPossible, NumberFormat currency) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        '${AppLocalizations.of(context)!.paidStatus}: ${currency.format(totalPaid)} / ${currency.format(totalPossible)}',
        style: AppTheme.offlineSafeTextStyle
            .copyWith(fontSize: 12, color: Colors.orange),
      ),
    );
  }

  Widget _buildCCPayNowButton(
      BuildContext context, Account acc, bool isFullyPaid) {
    return SizedBox(
      width: double.infinity,
      height: 36,
      child: ElevatedButton.icon(
        icon: PureIcons.payment(size: 16),
        label: Text(AppLocalizations.of(context)!.payNowAction),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
        ),
        onPressed: () => showDialog(
          // coverage:ignore-line
          context: context,
          builder: (_) => RecordCCPaymentDialog(
              // coverage:ignore-line
              creditCardAccount: acc,
              isFullyPaid: isFullyPaid),
        ),
      ),
    );
  }

  (Color, String, IconData) _getRecurringStatus(
      BuildContext context, DateTime dueDate) {
    final l10n = AppLocalizations.of(context)!;
    final today = clock.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final dueDateDate = DateTime(dueDate.year, dueDate.month, dueDate.day);
    if (dueDateDate.isBefore(todayDate)) {
      return (Colors.red, l10n.overdueStatus, Icons.warning);
    }
    return (Colors.grey, l10n.upcomingStatus, Icons.event_repeat);
  }

  String _getFrequencyLabel(BuildContext context, Frequency frequency) {
    final l10n = AppLocalizations.of(context)!;
    switch (frequency) {
      case Frequency.monthly:
        return l10n.frequencyMonthly;
      case Frequency.weekly: // coverage:ignore-line
        return l10n.frequencyWeekly; // coverage:ignore-line
      default:
        return l10n.frequencyOther; // coverage:ignore-line
    }
  }

  Widget _buildRecurringReminders(BuildContext context, WidgetRef ref,
      List<RecurringTransaction> recurring, NumberFormat currency) {
    final now = clock.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = recurring
        .where((r) => r.isActive && !_isRecurringInFuture(r, today))
        .toList();
    if (due.isEmpty) {
      return Text(AppLocalizations.of(context)!.noRecurringPaymentsDue);
    }

    return Column(
      children: due.map((r) {
        return _buildRecurringCard(context, ref, r, currency);
      }).toList(),
    );
  }

  Widget _buildRecurringCard(BuildContext context, WidgetRef ref,
      RecurringTransaction r, NumberFormat currency) {
    final dueDate = r.nextExecutionDate;
    final (statusColor, statusText, statusIcon) =
        _getRecurringStatus(context, dueDate);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            _buildRecurringCardHeader(
              context: context,
              ref: ref,
              r: r,
              dueDate: dueDate,
              statusIcon: statusIcon,
              statusColor: statusColor,
              statusText: statusText,
              currency: currency,
            ),
            const SizedBox(height: 12),
            _buildRecurringCardActions(context, ref, r),
          ],
        ),
      ),
    );
  }

  Widget _buildRecurringCardHeader({
    required BuildContext context,
    required WidgetRef ref,
    required RecurringTransaction r,
    required DateTime dueDate,
    required IconData statusIcon,
    required Color statusColor,
    required String statusText,
    required NumberFormat currency,
  }) {
    return Row(
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
              _buildRecurringDueDateText(context, dueDate, statusText),
              const SizedBox(height: 2),
              Text(_getFrequencyLabel(context, r.frequency),
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
              Text(
                r.accountId == null
                    ? AppLocalizations.of(context)!.manualLabel
                    : AppLocalizations.of(context)!
                        .autoLabel, // coverage:ignore-line
                style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
              ),
              const SizedBox(height: 4),
              _buildRecurringCalendarAction(context, ref, r, dueDate),
            ],
          ),
        ),
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
    );
  }

  Widget _buildRecurringDueDateText(
      BuildContext context, DateTime dueDate, String statusText) {
    final isOverdue = statusText == AppLocalizations.of(context)!.overdueStatus;
    return Text(
      AppLocalizations.of(context)!
          .dueOnLabel(DateFormat(dateFormatMmmDd).format(dueDate)),
      style: TextStyle(
        color: isOverdue ? Colors.red : Colors.grey[700],
        fontWeight: isOverdue ? FontWeight.bold : null,
        fontSize: 13,
      ),
    );
  }

  Widget _buildRecurringCalendarAction(BuildContext context, WidgetRef ref,
      RecurringTransaction r, DateTime dueDate) {
    return InkWell(
      // coverage:ignore-start
      onTap: () {
        ref.read(calendarServiceProvider).downloadRecurringEvent(
              title: r.title,
              description: AppLocalizations.of(context)!
                  .recurringPaymentCalendarDescription(r.title),
              // coverage:ignore-end
              startDate: dueDate,
              occurrences: 12,
            );
      },
      child: Row(
        children: [
          PureIcons.calendar(size: 14, color: Colors.blue),
          const SizedBox(width: 4),
          Text(
            AppLocalizations.of(context)!.addToCalendarAction,
            style: const TextStyle(fontSize: 11, color: Colors.blue),
          ),
        ],
      ),
    );
  }

  Widget _buildRecurringCardActions(
      BuildContext context, WidgetRef ref, RecurringTransaction r) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              side: BorderSide(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.5)),
            ),
            onPressed: () => _handleSkipCycle(context, ref, r),
            child: Text(AppLocalizations.of(context)!.skipAction.toUpperCase(),
                style: const TextStyle(fontSize: 12)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            icon: PureIcons.payment(size: 16),
            label: Text(AppLocalizations.of(context)!.payNowAction),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              padding: EdgeInsets.zero,
            ),
            onPressed: () =>
                _handleRecurringPayment(context, r), // coverage:ignore-line
          ),
        ),
      ],
    );
  }

  Future<void> _handleSkipCycle(
      BuildContext context, WidgetRef ref, RecurringTransaction r) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.skipCycleTitle),
        content:
            Text(AppLocalizations.of(context)!.skipCycleConfirmation(r.title)),
        actions: [
          TextButton(
              onPressed: () =>
                  Navigator.pop(ctx, false), // coverage:ignore-line
              child: Text(
                  AppLocalizations.of(context)!.cancelAction.toUpperCase())),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child:
                  Text(AppLocalizations.of(context)!.skipAction.toUpperCase())),
        ],
      ),
    );
    if (confirm == true) {
      await ref
          .read(storageServiceProvider)
          .advanceRecurringTransactionDate(r.id);
      ref.invalidate(recurringTransactionsProvider);
    }
  }

  // coverage:ignore-start
  void _handleRecurringPayment(BuildContext context, RecurringTransaction r) {
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
        builder: (_) =>
            AddTransactionScreen(transactionToEdit: txn, recurringId: r.id),
        // coverage:ignore-end
      ),
    );
  }

  Widget _buildTaxSection(BuildContext context, NumberFormat currency) {
    final taxConfig = ref.watch(taxConfigServiceProvider);
    final currentYear = taxConfig.getCurrentFinancialYear();
    final service = ref.watch(indianTaxServiceProvider);
    final taxDataAsync = ref.watch(taxYearDataProvider(currentYear));

    int pendingCount = 0;
    Widget child = taxDataAsync.when(
      data: (taxData) {
        if (taxData == null) {
          return Text(AppLocalizations.of(context)!.noTaxInstallmentsDue);
        }
        final rules = taxConfig.getRulesForYear(taxData.year);
        final details = service.calculateDetailedLiability(taxData, rules);

        final DateTime? dueDate = details['nextAdvanceTaxDueDate'] as dynamic;
        final double? amount = details['nextAdvanceTaxAmount'] as dynamic;
        final int? daysLeft = details['daysUntilAdvanceTax'] as dynamic;
        final bool isRequirementMet = details['isRequirementMet'] == true;
        final double baseAmount = details['nextAdvanceTaxBase'] ?? 0.0;
        final double cessAmount = details['nextAdvanceTaxCess'] ?? 0.0;
        final double intAmount = details['nextAdvanceTaxInterest'] ?? 0.0;

        if (dueDate != null &&
            amount != null &&
            daysLeft != null &&
            _shouldShowAdvanceTaxReminder(
                amount, daysLeft, rules, isRequirementMet)) {
          pendingCount = 1;
          return _buildAdvanceTaxReminderCard(
              context,
              ref,
              taxData,
              currency,
              dueDate,
              amount,
              daysLeft,
              rules,
              baseAmount,
              cessAmount,
              intAmount);
        }
        return const Text('No upcoming tax installments.');
      },
      loading: () => const CircularProgressIndicator(),
      error: (e, s) => // coverage:ignore-line
          Text(AppLocalizations.of(context)!
              .errorLabel(e.toString())), // coverage:ignore-line
    );

    return _buildExpandableSection(
      context: context,
      title: AppLocalizations.of(context)!.upcomingTaxInstallments,
      icon: Icons.percent,
      isExpanded: _isTaxExpanded,
      onToggle: () => setState(() => _isTaxExpanded = !_isTaxExpanded),
      pendingCount: pendingCount,
      child: child,
    );
  }

  bool _shouldShowAdvanceTaxReminder(
      double amount, int daysLeft, TaxRules rules, bool isRequirementMet) {
    if (isRequirementMet) return false;
    if (amount <= 0.01) return false;
    return daysLeft <= rules.advanceTaxReminderDays;
  }

  bool _isRecurringInFuture(RecurringTransaction r, DateTime today) {
    final dueDate = DateTime(r.nextExecutionDate.year,
        r.nextExecutionDate.month, r.nextExecutionDate.day);
    return dueDate.isAfter(today);
  }

  bool _shouldShowLoanReminder(Loan loan, DateTime today) {
    if (loan.remainingPrincipal <= 0) return false;
    final dueDateObj = _getLoanDueDate(loan, today);
    final paymentsForPeriod = loan.transactions
        .where((t) =>
            t.type == LoanTransactionType.emi &&
            t.date.year == dueDateObj.year &&
            t.date.month == dueDateObj.month)
        .toList();
    final totalPaid = paymentsForPeriod.fold(0.0, (sum, t) => sum + t.amount);
    final isFullyPaid = totalPaid >= loan.emiAmount - 1;
    // Requirement: Show if NOT fully paid AND within 7 days
    return !isFullyPaid && dueDateObj.difference(today).inDays <= 7;
  }

  bool _shouldShowCCReminder(Account acc, List<Transaction> txns, DateTime now,
      StorageService storage) {
    if (acc.type != AccountType.creditCard || acc.billingCycleDay == null) {
      return false;
    }
    // Check cycle tracker
    if (storage.isBilledAmountPaid(acc.id)) {
      return false;
    }

    // Check current due
    final lastRolloverMillis = storage.getLastRollover(acc.id);
    final billedAmount =
        BillingHelper.calculateBilledAmount(acc, txns, now, lastRolloverMillis);

    double payments = 0;
    if (lastRolloverMillis != null) {
      final statementDate =
          BillingHelper.getStatementDate(now, acc.billingCycleDay!);
      payments =
          BillingHelper.calculatePeriodPayments(acc, txns, statementDate, now);
    }

    final adjustedData = BillingHelper.getAdjustedCCData(
      accountBalance: acc.balance,
      billedAmount: billedAmount,
      unbilledAmount: 0,
      paymentsSinceRollover: payments,
    );

    final debtDue = adjustedData.$2 + adjustedData.$3;
    return debtDue > 0.01;
  }

  int _countPendingLoans(List<Loan> loans, DateTime today) {
    return loans.where((l) => _shouldShowLoanReminder(l, today)).length;
  }

  int _countPendingCreditCards(
      List<Account> accounts, List<Transaction> txns, DateTime now) {
    final storage = ref.read(storageServiceProvider);
    return accounts
        .where((acc) => _shouldShowCCReminder(acc, txns, now, storage))
        .length;
  }

  int _countPendingRecurring(
      List<RecurringTransaction> recurring, DateTime today) {
    int count = 0;
    for (final r in recurring) {
      if (r.isActive && !_isRecurringInFuture(r, today)) {
        count++;
      }
    }
    return count;
  }

  Widget _buildAdvanceTaxReminderCard(
      BuildContext context,
      WidgetRef ref,
      TaxYearData taxData,
      NumberFormat currency,
      DateTime dueDate,
      double amount,
      int? daysLeft,
      TaxRules rules,
      double baseAmount,
      double cessAmount,
      double intAmount) {
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
                    _buildAdvanceTaxReminderHeader(context, isOverdue, isNear),
                    const SizedBox(height: 4),
                    Text(
                      AppLocalizations.of(context)!.nextTaxInstallmentLabel(
                          currency.format(amount),
                          DateFormat('dd MMM').format(dueDate)),
                      style:
                          TextStyle(fontSize: 13, color: Colors.grey.shade700),
                    ),
                    Text(
                      AppLocalizations.of(context)!.advanceTaxBreakdownLabel(
                          currency.format(baseAmount),
                          currency.format(cessAmount),
                          currency.format(intAmount)),
                      style: TextStyle(
                          fontSize: 11,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (daysLeft != null)
                _buildDaysLeftText(context, isOverdue, isNear, daysLeft),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdvanceTaxReminderHeader(
      BuildContext context, bool isOverdue, bool isNear) {
    final title = isOverdue
        ? AppLocalizations.of(context)!
            .advanceTaxOverdue // coverage:ignore-line
        : AppLocalizations.of(context)!.upcomingAdvanceTax;
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

  Widget _buildDaysLeftText(
      BuildContext context, bool isOverdue, bool isNear, int daysLeft) {
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
      text = AppLocalizations.of(context)!
          .daysLate(daysLeft.abs()); // coverage:ignore-line
    } else if (daysLeft == 0) {
      text = AppLocalizations.of(context)!.dueToday; // coverage:ignore-line
    } else {
      text = AppLocalizations.of(context)!.daysLeftLabel(daysLeft);
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
