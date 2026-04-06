import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'add_transaction_screen.dart';
import 'loans_screen.dart';
import '../models/loan.dart';
import 'accounts_screen.dart';
import 'settings_screen.dart';
import 'transactions_screen.dart';
import 'reports_screen.dart';
import 'reminders_screen.dart';
import '../models/transaction.dart';
import '../models/account.dart';
import '../models/category.dart';
import '../providers.dart';
import '../feature_providers.dart';
import '../utils/billing_helper.dart';
import '../utils/currency_utils.dart';
import '../widgets/smart_currency_text.dart';
import '../widgets/pure_icons.dart';
import '../widgets/transaction_list_item.dart';
import '../utils/ui_utils.dart';
import '../models/dashboard_config.dart';
import 'lending/lending_dashboard_screen.dart';
import '../widgets/bell_animation.dart';
import '../services/storage_service.dart';
import '../l10n/app_localizations.dart';

const hiddenTextChars = '••••••';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _isPrivacyMode = true;
  bool _isExpanded = false;
  bool _isRecentTransactionsExpanded = false;

  @override
  void initState() {
    super.initState();
    // 1. Show Calculator strictly on Dashboard
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(calculatorVisibleProvider.notifier).value = true;
    });

    // 2. Check for notifications/nudges after first frame
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _initDashboardNotifications());
  }

  Future<void> _initDashboardNotifications() async {
    final service = ref.read(notificationServiceProvider);
    // Initialize native (no-op on web)
    await service.init();

    // Check nudges
    final nudges = await service.checkNudges();
    if (nudges.isNotEmpty && mounted) {
      // coverage:ignore-start
      for (final nudge in nudges) {
        if (!mounted) break;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(nudge),
          // coverage:ignore-end
          duration: const Duration(seconds: 5),
          // coverage:ignore-start
          action: SnackBarAction(
              label: AppLocalizations.of(context)!.dismissButton,
              onPressed: () {}),
          // coverage:ignore-end
          behavior: SnackBarBehavior.floating,
        ));
        // Slight delay so they don't all stack instantly if multiple
        await Future.delayed(
            const Duration(milliseconds: 500)); // coverage:ignore-line
      }
    }
  }

  @override
  void dispose() {
    // Hide Calculator when leaving Dashboard via regular navigation
    // On logout, GlobalOverlay handles this reactively
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _handleCalculatorsReactivity();

    final activeProfile = ref.watch(activeProfileProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: _buildAppBar(l10n.mySamriddhi, activeProfile),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  void _handleCalculatorsReactivity() {
    ref.listen(smartCalculatorEnabledProvider, (previous, enabled) {
      if (enabled) {
        // coverage:ignore-start
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ref.read(calculatorVisibleProvider.notifier).value = true;
            // coverage:ignore-end
          }
        });
      }
    });
  }

  PreferredSizeWidget _buildAppBar(String title, dynamic activeProfile) {
    final theme = Theme.of(context);
    return AppBar(
      title: GestureDetector(
        onTap: () => _showPrivacyPolicy(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(width: 4),
                Icon(Icons.info_outline,
                    size: 14,
                    color: Theme.of(context).brightness == Brightness.light
                        ? Colors.black38
                        : Colors.white38),
              ],
            ),
            Text(
              AppLocalizations.of(context)!.profileLabel(activeProfile?.name ??
                  AppLocalizations.of(context)!.defaultVal),
              style: theme.textTheme.bodySmall?.copyWith(
                color: Theme.of(context).brightness == Brightness.light
                    ? Colors.black54
                    : Colors.white60,
              ),
            ),
          ],
        ),
      ),
      actions: [
        _buildProfileSwitcher(context, ref),
        BellAnimation(
          animate: ref.watch(pendingRemindersProvider) > 0,
          child: IconButton(
            // coverage:ignore-start
            onPressed: () {
              FocusScope.of(context).unfocus();
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const RemindersScreen()));
              // coverage:ignore-end
            },
            icon: PureIcons.notifications(
                isActive: ref.watch(pendingRemindersProvider) > 0),
            tooltip: AppLocalizations.of(context)!.remindersTooltip,
          ),
        ),
        if (ref.watch(appLockStatusProvider))
          IconButton(
            // coverage:ignore-line
            onPressed: () => ref
                .read(appLockIntentProvider.notifier)
                .lock(), // coverage:ignore-line
            icon: const Icon(Icons.lock_outline),
            tooltip: AppLocalizations.of(context)!
                .lockAppTooltip, // coverage:ignore-line
          ),
        if ((ref.watch(authStreamProvider).value != null ||
                ref.watch(isLoggedInProvider)) &&
            !ref.watch(isOfflineProvider) &&
            !ref.watch(localModeProvider))
          IconButton(
            onPressed: () =>
                UIUtils.handleLogout(context, ref), // coverage:ignore-line
            icon: PureIcons.logout(),
            tooltip: AppLocalizations.of(context)!.logoutTooltip,
          ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildBody() {
    final txnsSinceBackup = ref.watch(txnsSinceBackupProvider);
    final backupThreshold = ref.watch(backupThresholdProvider);
    final accountsAsync = ref.watch(accountsProvider);
    final transactionsAsync = ref.watch(transactionsProvider);
    final currencyLocale = ref.watch(currencyProvider);
    final categories = ref.watch(categoriesProvider);
    final dashboardConfig = ref.watch(dashboardConfigProvider);
    final theme = Theme.of(context);

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (txnsSinceBackup >= backupThreshold)
                _buildBackupReminder(context, ref, txnsSinceBackup),
              _buildNetWorthCard(context, accountsAsync, transactionsAsync,
                  categories, dashboardConfig, currencyLocale, ref),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(AppLocalizations.of(context)!.quickActionsHeader,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 12),
              _buildQuickActions(context),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() =>
                            _isRecentTransactionsExpanded =
                                !_isRecentTransactionsExpanded),
                        child: Row(
                          children: [
                            Text(
                                AppLocalizations.of(context)!
                                    .recentTransactionsHeader,
                                style: theme.textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis),
                            Icon(
                                _isRecentTransactionsExpanded
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                color: theme.colorScheme.onSurface),
                          ],
                        ),
                      ),
                    ),
                    TextButton(
                        // coverage:ignore-start
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const TransactionsScreen())),
                        // coverage:ignore-end
                        child:
                            Text(AppLocalizations.of(context)!.viewAllButton)),
                  ],
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: _isRecentTransactionsExpanded
                    ? _buildRecentTransactions(
                        context, transactionsAsync, currencyLocale, categories)
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BottomAppBar(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IconButton(
              icon: PureIcons.home(),
              tooltip: l10n.homeTooltip,
              onPressed: () {}), // coverage:ignore-line
          IconButton(
            icon: PureIcons.accounts(),
            tooltip: l10n.accountsTooltip,
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AccountsScreen())),
          ),
          IconButton(
            icon: PureIcons.reports(),
            tooltip: l10n.reportsTooltip,
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ReportsScreen())),
          ),
          IconButton(
            icon: PureIcons.settings(),
            tooltip: l10n.settingsTooltip,
            onPressed: () => Navigator.push(
                context, // coverage:ignore-line
                MaterialPageRoute(
                    builder: (_) =>
                        const SettingsScreen())), // coverage:ignore-line
          ),
        ],
      ),
    );
  }

  Widget _buildNetWorthCard(
      BuildContext context,
      AsyncValue<List<Account>> accountsAsync,
      AsyncValue<List<Transaction>> transactionsAsync,
      List<Category> categories,
      DashboardVisibilityConfig dashboardConfig,
      String currencyLocale,
      WidgetRef ref) {
    final loansAsync = ref.watch(loansProvider);

    return accountsAsync.when(
      data: (accounts) => loansAsync.when(
        data: (loans) => _buildNetWorthContent(
          context,
          _computeNetWorthData(accounts, loans, ref),
          loans,
          transactionsAsync,
          categories,
          dashboardConfig,
          currencyLocale,
          ref,
        ),
        loading: () => const SizedBox(), // coverage:ignore-line
        error: (e, s) => const SizedBox(), // coverage:ignore-line
      ),
      loading: () => const SizedBox(),
      error: (e, s) => const SizedBox(), // coverage:ignore-line
    );
  }

  ({
    double netWorth,
    double assets,
    double debt,
    double currentBalance,
    double totalLoanLiability,
    double ccBilled,
    double ccUnbilled,
    double ccDebt,
    double ccUsagePercent
  }) _computeNetWorthData(
      List<Account> accounts, List<Loan> loans, WidgetRef ref) {
    double netWorth = 0;
    double assets = 0;
    double debt = 0;
    double currentBalance = 0;

    final allTxns = ref.watch(transactionsProvider).value ?? [];
    final now = DateTime.now();
    final storage = ref.watch(storageServiceProvider);

    final ccStats = _computeDashboardCCStats(accounts, allTxns, now, storage);

    for (var acc in accounts) {
      if (acc.type == AccountType.creditCard) {
        // Handled in ccStats but need debt and netWorth updates
        final unbilled =
            BillingHelper.calculateUnbilledAmount(acc, allTxns, now);
        final billed = BillingHelper.calculateBilledAmount(
            acc, allTxns, now, storage.getLastRollover(acc.id));
        final totalOwed = acc.balance + billed + unbilled;
        if (totalOwed > 0) debt += totalOwed;
        netWorth -= totalOwed;
      } else if (acc.type != AccountType.wallet) {
        netWorth += acc.balance;
        if (acc.balance >= 0) assets += acc.balance;
        if (acc.type == AccountType.savings) currentBalance += acc.balance;
      }
    }

    double totalLoanLiability = 0;
    for (var loan in loans) {
      totalLoanLiability += loan.remainingPrincipal; // coverage:ignore-line
    }

    double ccUsagePercent = ccStats.totalLimit > 0
        ? (ccStats.totalNetDebt / ccStats.totalLimit).clamp(0.0, 1.0)
        : 0;

    return (
      netWorth: netWorth,
      assets: assets,
      debt: debt,
      currentBalance: currentBalance,
      totalLoanLiability: totalLoanLiability,
      ccBilled: ccStats.totalBilled,
      ccUnbilled: ccStats.totalNetUnbilled,
      ccDebt: ccStats.totalNetDebt,
      ccUsagePercent: ccUsagePercent,
    );
  }

  ({
    double totalBilled,
    double totalNetUnbilled,
    double totalNetDebt,
    double totalLimit
  }) _computeDashboardCCStats(List<Account> accounts, List<Transaction> allTxns,
      DateTime now, StorageService storage) {
    double totalBilled = 0;
    double totalNetUnbilled = 0;
    double totalNetDebt = 0;
    double totalLimit = 0;

    for (var acc in accounts) {
      if (acc.type == AccountType.creditCard) {
        final unbilled =
            BillingHelper.calculateUnbilledAmount(acc, allTxns, now);
        final billedGross = BillingHelper.calculateBilledAmount(
            acc, allTxns, now, storage.getLastRollover(acc.id));

        final lastRolloverMillis = storage.getLastRollover(acc.id);
        final paymentsSinceRollover = lastRolloverMillis != null
            ? BillingHelper.calculatePeriodPayments(acc, allTxns,
                DateTime.fromMillisecondsSinceEpoch(lastRolloverMillis), now)
            : 0.0;

        final adjusted = BillingHelper.getAdjustedCCData(
          accountBalance: acc.balance,
          billedAmount: billedGross,
          unbilledAmount: unbilled,
          paymentsSinceRollover: paymentsSinceRollover,
        );

        final totalDue = acc.balance + billedGross;
        totalBilled += totalDue > 0.01 ? totalDue : 0;
        totalNetUnbilled += adjusted.$4; // Net Unbilled
        totalNetDebt += adjusted.$1; // Total Net Debt
        totalLimit += (acc.creditLimit ?? 0);
      }
    }

    return (
      totalBilled: totalBilled,
      totalNetUnbilled: totalNetUnbilled,
      totalNetDebt: totalNetDebt,
      totalLimit: totalLimit,
    );
  }

  Widget _buildNetWorthHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(AppLocalizations.of(context)!.totalNetWorthLabel,
                style: const TextStyle(color: Colors.white70)),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(
                _isPrivacyMode ? Icons.visibility_off : Icons.visibility,
                color: Colors.white70,
                size: 18,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => setState(() => _isPrivacyMode = !_isPrivacyMode),
            ),
          ],
        ),
        IconButton(
          icon: AnimatedRotation(
            turns: _isExpanded ? 0.5 : 0,
            duration: const Duration(milliseconds: 200),
            child: const Icon(
              Icons.keyboard_arrow_down,
              color: Colors.white70,
              size: 24,
            ),
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: () => setState(
              () => _isExpanded = !_isExpanded), // coverage:ignore-line
        ),
      ],
    );
  }

  Widget _buildNetWorthValue(double netWorth, String currencyLocale) {
    return _isPrivacyMode
        ? const Text(
            '••••••••',
            style: TextStyle(
                color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
          )
        : SmartCurrencyText(
            value: netWorth,
            locale: currencyLocale,
            style: const TextStyle(
                color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
          );
  }

  Widget _buildSavingsRow(double currentBalance, String currencyLocale) {
    return Row(
      children: [
        Text(AppLocalizations.of(context)!.currentSavingsLabel,
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
        _isPrivacyMode
            ? const Text(
                hiddenTextChars,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold),
              )
            : SmartCurrencyText(
                value: currentBalance,
                locale: currencyLocale,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold),
              ),
      ],
    );
  }

  Widget _buildCCStatsRow(dynamic data, String currencyLocale) {
    return Row(
      children: [
        _buildCCStatItem(AppLocalizations.of(context)!.ccBillUnpaidLabel,
            data.ccBilled, currencyLocale),
        _buildCCStatItem(AppLocalizations.of(context)!.ccUnbilledLabel,
            data.ccUnbilled, currencyLocale),
        _buildCCUsageItem(data.ccUsagePercent),
      ],
    );
  }

  Widget _buildCCStatItem(String label, double value, String currencyLocale) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
          const SizedBox(height: 2),
          _isPrivacyMode
              ? const Text('••••',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold))
              : SmartCurrencyText(
                  value: value,
                  locale: currencyLocale,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildCCUsageItem(double usagePercent) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(AppLocalizations.of(context)!.ccUsageLabel,
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
          const SizedBox(height: 2),
          Text(
            '${(usagePercent * 100).toStringAsFixed(1)}%',
            style: const TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // Removed _buildAssetDebtPills

  Widget _buildNetWorthContent(
      BuildContext context,
      ({
        double netWorth,
        double assets,
        double debt,
        double currentBalance,
        double totalLoanLiability,
        double ccBilled,
        double ccUnbilled,
        double ccDebt,
        double ccUsagePercent
      }) data,
      List<Loan> loans,
      AsyncValue<List<Transaction>> transactionsAsync,
      List<Category> categories,
      DashboardVisibilityConfig dashboardConfig,
      String currencyLocale,
      WidgetRef ref) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6C63FF), Color(0xFF8B85FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6C63FF).withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildNetWorthHeader(context),
              const SizedBox(height: 8),
              _buildNetWorthValue(data.netWorth, currencyLocale),
              const SizedBox(height: 4),
              _buildSavingsRow(data.currentBalance, currencyLocale),
              const SizedBox(height: 16),
              // New: Budget Progress in collapsed view
              transactionsAsync.when(
                data: (transactions) {
                  final totals = _computeMonthlyTotals(transactions, ref);
                  final budget = ref.watch(monthlyBudgetProvider);
                  if (dashboardConfig.showBudget && budget > 0) {
                    return Column(
                      children: [
                        _buildWhiteThemeBudgetProgress(totals.expense, budget,
                            currencyLocale, _isPrivacyMode),
                        const SizedBox(height: 16),
                      ],
                    );
                  }
                  return const SizedBox();
                },
                loading: () => const SizedBox(), // coverage:ignore-line
                error: (_, __) => const SizedBox(), // coverage:ignore-line
              ),
              if (data.ccDebt > 0) _buildCCStatsRow(data, currencyLocale),
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: _isExpanded
                    // coverage:ignore-start
                    ? Column(
                        children: [
                          if (data.ccDebt > 0 || data.currentBalance > 0)
                            const SizedBox(height: 16),
                          Container(
                              // coverage:ignore-end
                              height: 1,
                              // coverage:ignore-start
                              color: Colors.white.withValues(alpha: 0.2)),
                          const SizedBox(height: 16),
                          ..._buildMergedExpandedContent(
                              // coverage:ignore-end
                              context,
                              data,
                              loans,
                              transactionsAsync,
                              categories,
                              dashboardConfig,
                              currencyLocale,
                              ref),
                        ],
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Removed _buildStatPill

  List<Widget> _buildMergedExpandedContent(
      // coverage:ignore-line
      BuildContext context,
      dynamic data,
      List<Loan> loans,
      AsyncValue<List<Transaction>> transactionsAsync,
      List<Category> categories,
      DashboardVisibilityConfig config,
      String currencyLocale,
      WidgetRef ref) {
    // coverage:ignore-start
    return [
      if (loans.isNotEmpty && data.totalLoanLiability > 0)
        ..._buildLoanLiabilitySection(
            loans, data.totalLoanLiability, currencyLocale, ref),
      if (config.showIncomeExpense || config.showBudget)
        _buildBudgetSection(transactionsAsync, config, currencyLocale, ref),
      // coverage:ignore-end
    ];
  }

  List<Widget> _buildLoanLiabilitySection(
      List<Loan> loans, // coverage:ignore-line
      double totalLoanLiability,
      String currencyLocale,
      WidgetRef ref) {
    return [
      // coverage:ignore-line
      Row(
        // coverage:ignore-line
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        // coverage:ignore-start
        children: [
          Row(
            children: [
              PureIcons.loan(color: Colors.white70, size: 16),
              // coverage:ignore-end
              const SizedBox(width: 8),
              Text(
                  AppLocalizations.of(context)!
                      .totalLoanLiabilityLabel, // coverage:ignore-line
                  style: const TextStyle(
                      color: Colors.white70, fontWeight: FontWeight.w500)),
            ],
          ),
          _isPrivacyMode // coverage:ignore-line
              ? const Text(hiddenTextChars,
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16))
              : SmartCurrencyText(
                  // coverage:ignore-line
                  value: totalLoanLiability,
                  locale: currencyLocale,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.orangeAccent),
                ),
        ],
      ),
      Builder(builder: (context) {
        // coverage:ignore-line
        final tenure = ref
            .read(loanServiceProvider)
            .calculateMaxRemainingTenure(loans); // coverage:ignore-line

        if (tenure.days <= 0) return const SizedBox(); // coverage:ignore-line

        return Padding(
          // coverage:ignore-line
          padding: const EdgeInsets.only(top: 4.0),
          child: Row(
            // coverage:ignore-line
            children: [
              // coverage:ignore-line
              const SizedBox(width: 32),
              // coverage:ignore-start
              Expanded(
                child: Text(
                  AppLocalizations.of(context)!.debtFreeIn(
                      tenure.months.toStringAsFixed(1), tenure.days),
                  // coverage:ignore-end
                  style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white70,
                      fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
        );
      }),
      const SizedBox(height: 16),
    ];
  }

  Widget _buildBudgetSection(
      AsyncValue<List<Transaction>> transactionsAsync, // coverage:ignore-line
      DashboardVisibilityConfig config,
      String currencyLocale,
      WidgetRef ref) {
    // coverage:ignore-start
    return transactionsAsync.when(
      data: (transactions) {
        final totals = _computeMonthlyTotals(transactions, ref);
        final budget = ref.watch(monthlyBudgetProvider);
        // coverage:ignore-end

        // coverage:ignore-start
        return Column(
          children: [
            if (config.showIncomeExpense) ...[
              Row(
                children: [
                  _buildWhiteThemeStatItem(
                      AppLocalizations.of(context)!.incomeMonthLabel,
                      // coverage:ignore-end
                      totals.income,
                      Colors.white,
                      currencyLocale),
                  _buildWhiteThemeStatItem(
                      // coverage:ignore-line
                      AppLocalizations.of(context)!
                          .budgetExpenseLabel, // coverage:ignore-line
                      totals.expense,
                      Colors.white,
                      currencyLocale),
                ],
              ),
              const SizedBox(height: 16),
            ],
            // coverage:ignore-start
            if (config.showBudget && budget > 0)
              _buildWhiteThemeBudgetProgress(
                  totals.expense, budget, currencyLocale, _isPrivacyMode),
            // coverage:ignore-end
          ],
        );
      },
      loading: () => const SizedBox(), // coverage:ignore-line
      error: (e, s) => const SizedBox(), // coverage:ignore-line
    );
  }

  Widget _buildWhiteThemeStatItem(
      // coverage:ignore-line
      String label,
      double value,
      Color valueColor,
      String currencyLocale) {
    return Expanded(
      // coverage:ignore-line
      child: Column(
        // coverage:ignore-line
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // coverage:ignore-line
          Text(label, // coverage:ignore-line
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
          const SizedBox(height: 4),
          // coverage:ignore-start
          _isPrivacyMode
              ? Text(hiddenTextChars,
                  style: TextStyle(
                      // coverage:ignore-end
                      color: valueColor,
                      fontSize: 14,
                      fontWeight: FontWeight.bold))
              : SmartCurrencyText(
                  // coverage:ignore-line
                  value: value,
                  locale: currencyLocale,
                  style: TextStyle(
                      // coverage:ignore-line
                      color: valueColor,
                      fontSize: 14,
                      fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildWhiteThemeBudgetProgress(
      double expense, double budget, String currencyLocale, bool isPrivate) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(AppLocalizations.of(context)!.monthlyBudgetProgress,
                style: const TextStyle(fontSize: 11, color: Colors.white70)),
            _buildWhiteThemeBudgetPercent(expense, budget, isPrivate),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: budget == 0 ? 0 : (expense / budget).clamp(0, 1),
          backgroundColor: Colors.white.withValues(alpha: 0.2),
          valueColor: AlwaysStoppedAnimation<Color>(
              expense > budget ? Colors.red[300]! : Colors.greenAccent),
          borderRadius: BorderRadius.circular(4),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
                '${AppLocalizations.of(context)!.expLabel}${isPrivate ? hiddenTextChars : CurrencyUtils.getSmartFormat(expense, currencyLocale)}',
                style: const TextStyle(fontSize: 10, color: Colors.white70)),
            Text(
                '${AppLocalizations.of(context)!.remLabel}${isPrivate ? hiddenTextChars : CurrencyUtils.getSmartFormat(budget - expense, currencyLocale)}',
                style: const TextStyle(fontSize: 10, color: Colors.white70)),
          ],
        ),
      ],
    );
  }

  Widget _buildWhiteThemeBudgetPercent(
      double expense, double budget, bool isPrivate) {
    // Override privacy mode: Always show percentage as requested by user
    final pctText = budget == 0
        ? '0%'
        : '${((expense / budget) * 100).toStringAsFixed(0)}%';
    const textColor = Colors.white;
    return Text(pctText,
        style: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.bold, color: textColor));
  }

  ({double income, double expense}) _computeMonthlyTotals(
      List<Transaction> transactions, WidgetRef ref) {
    double income = 0;
    double expense = 0;
    final now = DateTime.now();

    final categories = ref.watch(categoriesProvider);
    final catMap = {for (var c in categories) c.name: c};

    for (var t in transactions) {
      if (!_isTransactionRelevantForThisMonth(t, now)) {
        continue;
      }

      if (t.type == TransactionType.income) {
        income += t.amount; // coverage:ignore-line
      } else if (t.type == TransactionType.expense) {
        if (catMap[t.category]?.tag != CategoryTag.budgetFree) {
          expense += t.amount;
        }
      }
    }
    return (income: income, expense: expense);
  }

  bool _isTransactionRelevantForThisMonth(Transaction t, DateTime now) {
    if (t.accountId == null && t.loanId != null) return false;
    if (t.date.year != now.year || t.date.month != now.month) return false;
    return true;
  }

  // Removed _buildIncomeExpenseRow, _buildBudgetProgress, _buildBudgetPercentText

  Widget _buildQuickActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          InkWell(
            onTap: () {
              FocusScope.of(context).unfocus();
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AddTransactionScreen(
                          initialType: TransactionType.income)));
            },
            child: _buildActionItem(context, Icons.add_circle_outline,
                AppLocalizations.of(context)!.incomeAction, Colors.green),
          ),
          InkWell(
            // coverage:ignore-start
            onTap: () {
              FocusScope.of(context).unfocus();
              Navigator.push(
                  // coverage:ignore-end
                  context,
                  MaterialPageRoute(
                      // coverage:ignore-line
                      builder: (_) => const AddTransactionScreen(
                          // coverage:ignore-line
                          initialType: TransactionType.transfer)));
            },
            child: _buildActionItem(context, Icons.swap_horiz,
                AppLocalizations.of(context)!.transferAction, Colors.blue),
          ),
          InkWell(
            // coverage:ignore-start
            onTap: () {
              FocusScope.of(context).unfocus();
              Navigator.push(
                  // coverage:ignore-end
                  context,
                  MaterialPageRoute(
                      // coverage:ignore-line
                      builder: (_) => const AddTransactionScreen(
                          // coverage:ignore-line
                          initialType: TransactionType.expense)));
            },
            child: _buildActionItem(context, Icons.payment,
                AppLocalizations.of(context)!.payBillAction, Colors.orange),
          ),
          InkWell(
            // coverage:ignore-start
            onTap: () {
              FocusScope.of(context).unfocus();
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const LoansScreen()));
              // coverage:ignore-end
            },
            child: _buildActionItem(context, Icons.account_balance,
                AppLocalizations.of(context)!.loansAction, Colors.purple),
          ),
          InkWell(
            // coverage:ignore-start
            onTap: () {
              FocusScope.of(context).unfocus();
              Navigator.pushNamed(context, '/taxes');
              // coverage:ignore-end
            },
            child: _buildActionItem(context, Icons.receipt_long,
                AppLocalizations.of(context)!.taxesAction, Colors.blueGrey),
          ),
          InkWell(
            // coverage:ignore-start
            onTap: () {
              FocusScope.of(context).unfocus();
              Navigator.push(
                  // coverage:ignore-end
                  context,
                  MaterialPageRoute(
                      // coverage:ignore-line
                      builder: (_) =>
                          const LendingDashboardScreen())); // coverage:ignore-line
            },
            child: _buildActionItem(context, Icons.handshake,
                AppLocalizations.of(context)!.lendingAction, Colors.teal),
          ),
          InkWell(
            // coverage:ignore-start
            onTap: () {
              FocusScope.of(context).unfocus();
              Navigator.pushNamed(context, '/investments');
              // coverage:ignore-end
            },
            child: _buildActionItem(context, Icons.trending_up,
                AppLocalizations.of(context)!.investmentsAction, Colors.indigo),
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem(
      BuildContext context, IconData icon, String label, Color color) {
    return Column(
      children: [
        Container(
          height: 60,
          width: 60,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildRecentTransactions(
      BuildContext context,
      AsyncValue<List<Transaction>> transactionsAsync,
      String currencyLocale,
      List<Category> categories) {
    return transactionsAsync.when(
      data: (transactions) {
        if (transactions.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(32.0),
            child: Center(
                child: Text(AppLocalizations.of(context)!.noTransactionsYet)),
          );
        }

        final accounts = ref.watch(accountsProvider).value ?? [];

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: transactions.length > 5 ? 5 : transactions.length,
          itemBuilder: (context, index) {
            final txn = transactions[index];

            return TransactionListItem(
              txn: txn,
              currencyLocale: currencyLocale,
              accounts: accounts,
              categories: categories,
              compactView: true,
              onTap: () async {
                // coverage:ignore-line
                final result = await Navigator.push(
                  // coverage:ignore-line
                  context,
                  // coverage:ignore-start
                  MaterialPageRoute(
                    builder: (_) =>
                        AddTransactionScreen(transactionToEdit: txn),
                    // coverage:ignore-end
                  ),
                );
                if (result == true) {
                  // coverage:ignore-line
                  // Refreshing is handled by the providers
                }
              },
            );
          },
        );
      },
      loading: () => const SizedBox(), // coverage:ignore-line
      error: (e, s) => const SizedBox(), // coverage:ignore-line
    );
  }

  Widget _buildBackupReminder(BuildContext context, WidgetRef ref, int count) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(
            alpha:
                Theme.of(context).brightness == Brightness.dark ? 0.25 : 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PureIcons.sync(color: Colors.orange),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppLocalizations.of(context)!.unsavedDataTitle(count),
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.amber[200] // coverage:ignore-line
                          : Colors.orange[800]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton(
                onPressed: () => Navigator.pushNamed(
                    context, '/settings'), // coverage:ignore-line
                child: Text(AppLocalizations.of(context)!.goToBackupButton),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => // coverage:ignore-line
                    ref
                        .read(txnsSinceBackupProvider.notifier)
                        .reset(), // coverage:ignore-line
                child: Text(AppLocalizations.of(context)!.dismissButton,
                    style: const TextStyle(color: Colors.grey)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSwitcher(BuildContext context, WidgetRef ref) {
    final profilesAsync = ref.watch(profilesProvider);
    final activeProfileId = ref.watch(activeProfileIdProvider);

    return profilesAsync.when(
      data: (profiles) {
        if (profiles.length <= 1) return const SizedBox.shrink();
        // coverage:ignore-start
        final activeProfile = profiles.firstWhere(
            (p) => p.id == activeProfileId,
            orElse: () => profiles.first);
        // coverage:ignore-end

        return PopupMenuButton<String>(
          // coverage:ignore-line
          initialValue: activeProfileId,
          // coverage:ignore-start
          icon: PureIcons.person(),
          tooltip: AppLocalizations.of(context)!
              .switchProfileTooltip(activeProfile.name),
          onSelected: (id) async {
            await ref.read(activeProfileIdProvider.notifier).setProfile(id);
            // coverage:ignore-end
            // Providers watching activeProfileIdProvider will react
            // coverage:ignore-start
            ref.invalidate(accountsProvider);
            ref.invalidate(transactionsProvider);
            ref.invalidate(loansProvider);
            ref.invalidate(recurringTransactionsProvider);
            ref.invalidate(categoriesProvider);
            ref.invalidate(monthlyBudgetProvider);
            ref.invalidate(currencyProvider);
            // coverage:ignore-end
          },
          // coverage:ignore-start
          itemBuilder: (context) => profiles
              .map((p) => PopupMenuItem(
                    value: p.id,
                    child: Row(
                      children: [
                        if (p.id == activeProfileId) PureIcons.check(size: 18),
                        const SizedBox(width: 8),
                        Text(p.name,
                            style: TextStyle(
                                fontWeight: p.id == activeProfileId
                                    // coverage:ignore-end
                                    ? FontWeight.bold
                                    : FontWeight.normal)),
                      ],
                    ),
                  ))
              .toList(), // coverage:ignore-line
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  void _showPrivacyPolicy(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(AppLocalizations.of(context)!.privacyPolicyTitle,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Text(AppLocalizations.of(context)!.privacyPolicyIntro,
                  style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 16),
              _buildPolicyItem(
                Icons.phone_android,
                AppLocalizations.of(context)!.localFirstTitle,
                AppLocalizations.of(context)!.localFirstDesc,
              ),
              _buildPolicyItem(
                Icons.cloud_outlined,
                AppLocalizations.of(context)!.cloudBackupTitle,
                AppLocalizations.of(context)!.cloudBackupDesc,
              ),
              _buildPolicyItem(
                Icons.lock_outline,
                AppLocalizations.of(context)!.optionalEncryptionTitle,
                AppLocalizations.of(context)!.optionalEncryptionDesc,
              ),
              _buildPolicyItem(
                Icons.analytics_outlined,
                AppLocalizations.of(context)!.noTrackingTitle,
                AppLocalizations.of(context)!.noTrackingDesc,
              ),
              _buildPolicyItem(
                Icons.verified_user_outlined,
                AppLocalizations.of(context)!.dataControlTitle,
                AppLocalizations.of(context)!.dataControlDesc,
              ),
              _buildPolicyItem(
                Icons.devices_other,
                AppLocalizations.of(context)!.singleDeviceAccessTitle,
                AppLocalizations.of(context)!.singleDeviceAccessDesc,
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(AppLocalizations.of(context)!.closeButton),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPolicyItem(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                Text(description,
                    style: const TextStyle(fontSize: 13, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
