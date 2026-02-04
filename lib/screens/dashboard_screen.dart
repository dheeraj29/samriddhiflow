import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'add_transaction_screen.dart';
import 'loans_screen.dart';
import 'accounts_screen.dart';
import 'settings_screen.dart';
import '../utils/debug_logger.dart';
import 'transactions_screen.dart';
import 'reports_screen.dart';
import 'reminders_screen.dart';
import '../models/transaction.dart';
import '../models/account.dart';
import '../models/category.dart';
import '../providers.dart';
import '../feature_providers.dart';
import '../utils/billing_helper.dart';
import '../widgets/smart_currency_text.dart';
import '../widgets/pure_icons.dart';
import '../widgets/transaction_list_item.dart';
import '../utils/ui_utils.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // 1. Show Calculator strictly on Dashboard
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(calculatorVisibleProvider.notifier).value = true;
    });

    // 2. Check for notifications/nudges after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final service = ref.read(notificationServiceProvider);
      // Initialize native (no-op on web)
      await service.init();

      // Check nudges
      final nudges = await service.checkNudges();
      if (nudges.isNotEmpty && mounted) {
        for (final nudge in nudges) {
          if (!mounted) break;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(nudge),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(label: 'Dismiss', onPressed: () {}),
            behavior: SnackBarBehavior.floating,
          ));
          // Slight delay so they don't all stack instantly if multiple
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
    });
  }

  @override
  void dispose() {
    DebugLogger().log("DashboardScreen: Disposing...");
    // Hide Calculator when leaving Dashboard via regular navigation
    // On logout, GlobalOverlay handles this reactively
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);
    final transactionsAsync = ref.watch(transactionsProvider);
    final txnsSinceBackup = ref.watch(txnsSinceBackupProvider);
    final backupThreshold = ref.watch(backupThresholdProvider);
    final theme = Theme.of(context);
    final activeProfile = ref.watch(activeProfileProvider);
    final categories = ref.watch(categoriesProvider);
    final currencyLocale = ref.watch(currencyProvider);

    // 3. Calculator Reactivity: Ensure overlay reappears if toggled ON
    ref.listen(smartCalculatorEnabledProvider, (previous, enabled) {
      if (enabled) {
        // Slight delay to allow overlay to rebuild
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ref.read(calculatorVisibleProvider.notifier).value = true;
          }
        });
      }
    });

    final title = (activeProfile == null || activeProfile.id == 'default')
        ? 'My Samriddh'
        : '${activeProfile.name} Budget';

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          _buildProfileSwitcher(context, ref),
          IconButton(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const RemindersScreen())),
            icon: PureIcons.notifications(),
            tooltip: 'Reminders',
          ),
          // Show logout if logged in (Stream value) OR local offline login flag
          // But only if ONLINE (logout requires connectivity).
          if ((ref.watch(authStreamProvider).value != null ||
                  ref.watch(isLoggedInProvider)) &&
              !ref.watch(isOfflineProvider))
            IconButton(
              onPressed: () => UIUtils.handleLogout(context, ref),
              icon: PureIcons.logout(),
              tooltip: 'Logout',
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (txnsSinceBackup >= backupThreshold)
                  _buildBackupReminder(context, ref, txnsSinceBackup),
                _buildNetWorthCard(context, accountsAsync, currencyLocale, ref),
                const SizedBox(height: 16),
                _buildMonthlySummary(context, transactionsAsync, categories,
                    currencyLocale, ref),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text('Quick Actions',
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
                        child: Text('Recent Transactions',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis),
                      ),
                      TextButton(
                          onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const TransactionsScreen())),
                          child: const Text('View All')),
                    ],
                  ),
                ),
                _buildRecentTransactions(
                    context, transactionsAsync, currencyLocale, categories),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
                icon: PureIcons.home(), tooltip: 'Home', onPressed: () {}),
            IconButton(
              icon: PureIcons.accounts(),
              tooltip: 'Accounts',
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const AccountsScreen())),
            ),
            IconButton(
              icon: PureIcons.reports(),
              tooltip: 'Reports',
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ReportsScreen())),
            ),
            IconButton(
              icon: PureIcons.settings(),
              tooltip: 'Settings',
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen())),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNetWorthCard(
      BuildContext context,
      AsyncValue<List<Account>> accountsAsync,
      String currencyLocale,
      WidgetRef ref) {
    final loansAsync = ref.watch(loansProvider);

    return accountsAsync.when(
      data: (accounts) {
        return loansAsync.when(
          data: (loans) {
            double netWorth = 0;
            double assets = 0;
            double debt = 0;

            final allTxns = ref.watch(transactionsProvider).value ?? [];
            final now = DateTime.now();

            for (var acc in accounts) {
              double unbilled = 0;
              if (acc.type == AccountType.creditCard) {
                unbilled =
                    BillingHelper.calculateUnbilledAmount(acc, allTxns, now);
              }

              if (acc.type == AccountType.creditCard) {
                // For Credit Cards, positive balance + unbilled is Debt
                final totalOwed = acc.balance + unbilled;
                if (totalOwed > 0) {
                  debt += totalOwed;
                }
                // CC Balance + Unbilled reduces Net Worth (assuming positive balance = owed)
                netWorth -= totalOwed;
              } else {
                // For other accounts (Savings, Cash), balance is Asset
                netWorth += acc.balance;

                if (acc.balance >= 0) {
                  assets += acc.balance;
                }
              }
            }

            double totalLoanLiability = 0;
            for (var loan in loans) {
              totalLoanLiability += loan.remainingPrincipal;
            }

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
                      const Text('Total Net Worth',
                          style: TextStyle(color: Colors.white70)),
                      const SizedBox(height: 8),
                      SmartCurrencyText(
                        value: netWorth,
                        locale: currencyLocale,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatPill(
                                'Assets', assets, currencyLocale,
                                color: Colors.greenAccent),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildStatPill('Debt', debt, currencyLocale,
                                color: Colors.redAccent),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          PureIcons.loan(color: Colors.orange),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text('Total Loan Liability',
                                style: TextStyle(fontWeight: FontWeight.w500)),
                          ),
                          SmartCurrencyText(
                            value: totalLoanLiability,
                            locale: currencyLocale,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.orange),
                          ),
                        ],
                      ),
                      if (loans.isNotEmpty && totalLoanLiability > 0) ...[
                        const SizedBox(height: 8),
                        Builder(builder: (context) {
                          final tenure = ref
                              .read(loanServiceProvider)
                              .calculateMaxRemainingTenure(loans);

                          if (tenure.days <= 0) return const SizedBox();

                          return Row(
                            children: [
                              const SizedBox(
                                  width: 36), // Indent to align with text
                              Text(
                                'Debt Free in ~${tenure.months.toStringAsFixed(1)} months (${tenure.days} days)',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange.withValues(alpha: 0.8),
                                    fontStyle: FontStyle.italic),
                              ),
                            ],
                          );
                        })
                      ]
                    ],
                  ),
                ),
              ],
            );
          },
          loading: () => const SizedBox(),
          error: (e, s) => const SizedBox(),
        );
      },
      loading: () => const SizedBox(),
      error: (e, s) => const SizedBox(),
    );
  }

  Widget _buildStatPill(String label, double value, String locale,
      {required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PureIcons.income(color: color, size: 16),
          const SizedBox(width: 4),
          Flexible(
            child: Text('$label: ',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12),
                overflow: TextOverflow.ellipsis),
          ),
          Flexible(
            child: SmartCurrencyText(
              value: value,
              locale: locale,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlySummary(
      BuildContext context,
      AsyncValue<List<Transaction>> transactionsAsync,
      List<Category> categories,
      String currencyLocale,
      WidgetRef ref) {
    return transactionsAsync.when(
      data: (transactions) {
        double income = 0;
        double expense = 0;
        final now = DateTime.now();

        final categories = ref.watch(categoriesProvider);
        final catMap = <String, Category>{};
        for (var c in categories) {
          // Prevent crash on duplicates
          catMap[c.name] = c;
        }

        for (var t in transactions) {
          // EXCLUDE Manual Loan Transactions from Expenses Stats
          if (t.accountId == null && t.loanId != null) continue;

          if (t.date.year == now.year && t.date.month == now.month) {
            if (t.type == TransactionType.income) income += t.amount;
            if (t.type == TransactionType.expense) {
              // Check for budgetFree tag
              final cat = catMap[t.category];
              if (cat?.tag != CategoryTag.budgetFree) {
                expense += t.amount; // Only count if not budgetFree
              }
            }
          }
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Income (This Month)',
                            style: TextStyle(color: Colors.grey, fontSize: 12)),
                        const SizedBox(height: 4),
                        SmartCurrencyText(
                          value: income,
                          locale: currencyLocale,
                          style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 18),
                        ),
                      ],
                    ),
                  ),
                  Container(
                      width: 1,
                      height: 40,
                      color: Colors.grey.withValues(alpha: 0.2)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Expense (Budgeted)',
                            style: TextStyle(color: Colors.grey, fontSize: 12)),
                        const SizedBox(height: 4),
                        SmartCurrencyText(
                          value: expense,
                          locale: currencyLocale,
                          style: const TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 18),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (ref.watch(monthlyBudgetProvider) > 0) ...[
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Monthly Budget Progress',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text(
                            (ref.watch(monthlyBudgetProvider) == 0)
                                ? '0%'
                                : '${((expense / ref.watch(monthlyBudgetProvider)) * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color:
                                    expense > ref.watch(monthlyBudgetProvider)
                                        ? Colors.redAccent
                                        : Colors.blueGrey)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: (ref.watch(monthlyBudgetProvider) == 0)
                          ? 0
                          : (expense / ref.watch(monthlyBudgetProvider))
                              .clamp(0, 1),
                      backgroundColor: Colors.grey.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(
                          expense > ref.watch(monthlyBudgetProvider)
                              ? Colors.redAccent
                              : Colors.green),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text('Spent: ',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey)),
                            SmartCurrencyText(
                              value: expense,
                              locale: currencyLocale,
                              style: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            const Text('Remaining: ',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey)),
                            SmartCurrencyText(
                              value: ref.watch(monthlyBudgetProvider) - expense,
                              locale: currencyLocale,
                              style: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    )
                  ],
                )
              ]
            ],
          ),
        );
      },
      loading: () => const SizedBox(),
      error: (e, s) => const SizedBox(),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const AddTransactionScreen(
                        initialType: TransactionType.income))),
            child: _buildActionItem(
                context, Icons.add_circle_outline, 'Income', Colors.green),
          ),
          const SizedBox(width: 16),
          InkWell(
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const AddTransactionScreen(
                        initialType: TransactionType.transfer))),
            child: _buildActionItem(
                context, Icons.swap_horiz, 'Transfer', Colors.blue),
          ),
          const SizedBox(width: 16),
          InkWell(
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const AddTransactionScreen(
                        initialType: TransactionType.expense))),
            child: _buildActionItem(
                context, Icons.payment, 'Pay Bill', Colors.orange),
          ),
          const SizedBox(width: 16),
          InkWell(
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const LoansScreen())),
            child: _buildActionItem(
                context, Icons.account_balance, 'Loans', Colors.purple),
          ),
          const SizedBox(width: 16),
          _buildActionItem(
              context, Icons.receipt_long, 'Taxes', Colors.blueGrey),
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
          return const Padding(
            padding: EdgeInsets.all(32.0),
            child: Center(child: Text('No transactions yet.')),
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
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        AddTransactionScreen(transactionToEdit: txn),
                  ),
                );
                if (result == true) {
                  // Refreshing is handled by the providers
                }
              },
            );
          },
        );
      },
      loading: () => const SizedBox(),
      error: (e, s) => const SizedBox(),
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
                  'Unsaved Data: $count transactions recorded since last backup.',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.amber[200]
                          : Colors.orange[800]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/settings'),
                child: const Text('Go to Backup'),
              ),
              const Spacer(),
              TextButton(
                onPressed: () =>
                    ref.read(txnsSinceBackupProvider.notifier).reset(),
                child:
                    const Text('Dismiss', style: TextStyle(color: Colors.grey)),
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
        final activeProfile = profiles.firstWhere(
            (p) => p.id == activeProfileId,
            orElse: () => profiles.first);

        return PopupMenuButton<String>(
          initialValue: activeProfileId,
          icon: PureIcons.person(),
          tooltip: 'Switch Profile (${activeProfile.name})',
          onSelected: (id) async {
            await ref.read(activeProfileIdProvider.notifier).setProfile(id);
            // Providers watching activeProfileIdProvider will react
            ref.invalidate(accountsProvider);
            ref.invalidate(transactionsProvider);
            ref.invalidate(loansProvider);
            ref.invalidate(recurringTransactionsProvider);
            ref.invalidate(categoriesProvider);
            ref.invalidate(monthlyBudgetProvider);
            ref.invalidate(currencyProvider);
          },
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
                                    ? FontWeight.bold
                                    : FontWeight.normal)),
                      ],
                    ),
                  ))
              .toList(),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
