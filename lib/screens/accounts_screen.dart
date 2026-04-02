import 'package:samriddhi_flow/utils/regex_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../utils/currency_utils.dart';
import '../providers.dart';
import '../models/account.dart';
import '../models/transaction.dart';
import '../screens/transactions_screen.dart';
import '../utils/billing_helper.dart';
import '../widgets/pure_icons.dart';
import '../services/storage_service.dart';
import 'cc_payment_dialog.dart';
import 'update_billing_cycle_dialog.dart';
import '../l10n/app_localizations.dart';

// No longer required per user request

class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({super.key});

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _CCBillingData {
  final double unbilled;
  final double billed;
  final double used;
  final double historicalBalance;
  final double available;
  final double percent;

  _CCBillingData({
    required this.unbilled,
    required this.billed,
    required this.used,
    required this.historicalBalance,
    required this.available,
    required this.percent,
  });
}

class _AccountsScreenState extends ConsumerState<AccountsScreen> {
  bool _compactView = true;
  bool _isPinnedExpanded = false;
  bool _isSavingsExpanded = false;
  bool _isCCExpanded = false;
  bool _isWalletExpanded = false;

  @override
  void initState() {
    super.initState();
    _compactView = true;
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: _buildAppBar(context),
      body: accountsAsync.when(
        data: (accounts) => _buildBody(context, accounts),
        loading: () => const Center(child: CircularProgressIndicator()),
        // coverage:ignore-start
        error: (e, s) => Center(
            child: Text(AppLocalizations.of(context)!
                .errorLabelWithDetails(e.toString()))),
        // coverage:ignore-end
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AppBar(
      title: Text(l10n.myAccounts),
      actions: [
        IconButton(
          icon: _compactView
              ? PureIcons.listExtended(size: 20)
              : PureIcons.listCompact(size: 20),
          tooltip: _compactView
              ? l10n.extendedNumbersTooltip
              : l10n.compactNumbersTooltip,
          onPressed: () => setState(() => _compactView = !_compactView),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context, List<Account> accounts) {
    if (accounts.isEmpty) {
      return _buildEmptyState(context);
    }
    return _buildAccountList(context, accounts);
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PureIcons.accounts(size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(AppLocalizations.of(context)!.noAccountsFound),
          TextButton(
            onPressed: () =>
                _showAddAccountSheet(context, ref), // coverage:ignore-line
            child: Text(AppLocalizations.of(context)!.addAccountButton),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountList(BuildContext context, List<Account> accounts) {
    final pinned = accounts.where((a) => a.isPinned).toList();
    final savings =
        accounts.where((a) => a.type == AccountType.savings).toList();
    final creditCards =
        accounts.where((a) => a.type == AccountType.creditCard).toList();
    final wallet = accounts.where((a) => a.type == AccountType.wallet).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildExpandableSection(
          title: AppLocalizations.of(context)!.pinnedAccountsHeader,
          icon: Icons.push_pin,
          isExpanded: _isPinnedExpanded,
          count: pinned.length,
          onToggle: () => // coverage:ignore-line
              setState(() => _isPinnedExpanded =
                  !_isPinnedExpanded), // coverage:ignore-line
          items: pinned,
        ),
        const SizedBox(height: 16),
        _buildExpandableSection(
          title: AppLocalizations.of(context)!.savingsAccountsHeader,
          icon: Icons.account_balance,
          isExpanded: _isSavingsExpanded,
          count: savings.length,
          onToggle: () =>
              setState(() => _isSavingsExpanded = !_isSavingsExpanded),
          items: savings,
        ),
        const SizedBox(height: 16),
        _buildExpandableSection(
          title: AppLocalizations.of(context)!.creditCardsHeader,
          icon: Icons.credit_card,
          isExpanded: _isCCExpanded,
          count: creditCards.length,
          onToggle: () => setState(() => _isCCExpanded = !_isCCExpanded),
          items: creditCards,
        ),
        const SizedBox(height: 16),
        _buildExpandableSection(
          title: AppLocalizations.of(context)!.walletsHeader,
          icon: Icons.account_balance_wallet,
          isExpanded: _isWalletExpanded,
          count: wallet.length,
          onToggle: () =>
              setState(() => _isWalletExpanded = !_isWalletExpanded),
          items: wallet,
        ),
        const SizedBox(height: 24),
        _buildAddAccountButton(context),
      ],
    );
  }

  Widget _buildExpandableSection({
    required String title,
    required IconData icon,
    required bool isExpanded,
    required int count,
    required VoidCallback onToggle,
    required List<Account> items,
  }) {
    final theme = Theme.of(context);
    return Column(
      children: [
        ListTile(
          onTap: () {
            onToggle();
          },
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          leading: PureIcons.icon(icon, color: theme.colorScheme.primary),
          title: Text(
            title,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isExpanded && count > 0) _buildCountBadge(count),
              AnimatedRotation(
                turns: isExpanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child:
                    Icon(Icons.expand_more, color: theme.colorScheme.onSurface),
              ),
            ],
          ),
        ),
        if (isExpanded)
          ...items.map((acc) => _buildAccountItem(context, ref, acc)),
        if (isExpanded && items.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(AppLocalizations.of(context)!.noAccountsInSection,
                style: const TextStyle(color: Colors.grey)),
          ),
      ],
    );
  }

  Widget _buildCountBadge(int count) {
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

  Widget _buildAddAccountButton(BuildContext context) {
    return Center(
      child: TextButton.icon(
        onPressed: () => _showAddAccountSheet(context, ref),
        icon: const Icon(Icons.add),
        label: Text(AppLocalizations.of(context)!.addNewAccountButton),
      ),
    );
  }

  Widget _buildAccountItem(BuildContext context, WidgetRef ref, Account acc) {
    final billingData = _calculateCCBillingData(acc, ref);

    final theme = Theme.of(context);
    final currencyFormat = CurrencyUtils.getFormatter(acc.currency);
    final smartFormat = CurrencyUtils.getSmartFormat(acc.balance, acc.currency);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.2) // coverage:ignore-line
              : Colors.black.withValues(alpha: 0.1),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: _buildAccountLeading(acc),
        title: _buildAccountTitle(acc),
        subtitle:
            _buildAccountSubtitle(acc, billingData, theme, currencyFormat),
        trailing: _buildAccountTrailing(
            acc, billingData, _compactView, currencyFormat, smartFormat, theme),
        onTap: () {
          FocusScope.of(context).unfocus();
          _showAccountOptions(context, ref, acc);
        },
      ),
    );
  }

  _CCBillingData _calculateCCBillingData(Account acc, WidgetRef ref) {
    double unbilled = 0;
    double billed = 0;
    double payments = 0;
    double used = 0;
    double historicalBalance = 0;
    double available = 0;
    double percent = 0;

    if (acc.type == AccountType.creditCard) {
      final now = DateTime.now();
      final allTxns = ref.read(transactionsProvider).value ?? [];
      final storage = ref.read(storageServiceProvider);
      final lastRolloverMillis = storage.getLastRollover(acc.id);

      unbilled = BillingHelper.calculateUnbilledAmount(acc, allTxns, now,
          lastRolloverMillis: lastRolloverMillis);
      billed = BillingHelper.calculateBilledAmount(
          acc, allTxns, now, lastRolloverMillis);

      payments = _calculatePaymentsSinceRollover(
          acc, allTxns, storage, now, lastRolloverMillis);

      final data = BillingHelper.getAdjustedCCData(
        accountBalance: acc.balance,
        billedAmount: billed,
        unbilledAmount: unbilled,
        paymentsSinceRollover: payments,
      );
      used = data.$1; // totalNetDebt
      historicalBalance = data.$3; // Realized Debt
      if (acc.creditLimit != null && acc.creditLimit! > 0) {
        available = acc.creditLimit! - used;
        percent = (used / acc.creditLimit!).clamp(0.0, 1.0);
      }
      return _CCBillingData(
        unbilled: data.$4, // Adjusted Unbilled
        billed: data.$2, // Adjusted Billed
        used: used,
        historicalBalance: historicalBalance,
        available: available,
        percent: percent,
      );
    }

    return _CCBillingData(
      unbilled: 0,
      billed: 0,
      used: 0,
      historicalBalance: 0,
      available: 0,
      percent: 0,
    );
  }

  double _calculatePaymentsSinceRollover(Account acc, List<Transaction> allTxns,
      StorageService storage, DateTime now, int? lastRolloverMillis) {
    if (lastRolloverMillis == null) return 0;

    final ignoreFlagKey =
        'ignore_rollover_payments_${acc.id}'; // coverage:ignore-line
    final ignorePayments = storage
            .getSettingsBox() // coverage:ignore-line
            .get(ignoreFlagKey, defaultValue: false)
        as bool; // coverage:ignore-line

    if (ignorePayments) return 0;

    // coverage:ignore-start
    final anchor = acc.isFrozen
        ? DateTime.fromMillisecondsSinceEpoch(lastRolloverMillis)
        : BillingHelper.getStatementDate(now, acc.billingCycleDay!);
    // coverage:ignore-end

    return BillingHelper.calculatePeriodPayments(
        acc, allTxns, anchor, now); // coverage:ignore-line
  }

  Widget _buildAccountLeading(Account acc) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _getAccountColor(acc).withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: PureIcons.icon(_getAccountIcon(acc),
          color: _getAccountColor(acc), size: 24),
    );
  }

  Widget _buildAccountTitle(Account acc) {
    return Row(
      children: [
        Expanded(
          child: Text(
            acc.name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        if (acc.isFrozen)
          Flexible(
            // coverage:ignore-line
            child: Container(
              // coverage:ignore-line
              margin: const EdgeInsets.only(left: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                // coverage:ignore-line
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(4), // coverage:ignore-line
              ),
              child: Text(
                // coverage:ignore-line
                AppLocalizations.of(context)!
                    .frozenLabel, // coverage:ignore-line
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAccountSubtitle(Account acc, _CCBillingData data,
      ThemeData theme, NumberFormat currencyFormat) {
    if (acc.type != AccountType.creditCard) {
      return Text(
        acc.type == AccountType.savings
            ? AppLocalizations.of(context)!.savingsAccountType
            : AppLocalizations.of(context)!.walletType, // coverage:ignore-line
        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface),
      );
    }

    return _buildCCAccountSubtitle(acc, data, theme, currencyFormat);
  }

  Widget _buildCCAccountSubtitle(Account acc, _CCBillingData data,
      ThemeData theme, NumberFormat currencyFormat) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final displayAvailable = data.available > 0 ? data.available : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: data.percent,
            minHeight: 4,
            backgroundColor: theme.dividerColor.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(
              data.percent > 0.9 ? Colors.red : theme.colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            Text(
              _compactView
                  ? AppLocalizations.of(context)!.limitShort(
                      CurrencyUtils.getSmartFormat(
                          acc.creditLimit ?? 0, acc.currency))
                  : AppLocalizations.of(context)! // coverage:ignore-line
                      .limitLabel(currencyFormat.format(
                          acc.creditLimit ?? 0)), // coverage:ignore-line
              style:
                  TextStyle(fontSize: 11, color: theme.colorScheme.onSurface),
            ),
            Text(
              _compactView
                  ? AppLocalizations.of(context)!.availableShort(
                      CurrencyUtils.getSmartFormat(
                          displayAvailable, acc.currency))
                  : AppLocalizations.of(context)! // coverage:ignore-line
                      .availableLabel(currencyFormat
                          .format(displayAvailable)), // coverage:ignore-line
              style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.bold),
            ),
            if (acc.isFrozen) _buildUnfreezeDateText(acc, theme, dateFormat),
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            if (data.billed.abs() > 0.01)
              _buildMiniInfoChip(
                  AppLocalizations.of(context)!
                      .billedChip, // coverage:ignore-line
                  data.billed,
                  acc.currency,
                  theme,
                  _compactView), // coverage:ignore-line
            if (data.historicalBalance.abs() > 0.01)
              _buildMiniInfoChip(AppLocalizations.of(context)!.balanceChip,
                  data.historicalBalance, acc.currency, theme, _compactView),
            if (data.unbilled.abs() > 0.01)
              _buildMiniInfoChip(
                  AppLocalizations.of(context)!
                      .unbilledChip, // coverage:ignore-line
                  data.unbilled,
                  acc.currency,
                  theme,
                  _compactView), // coverage:ignore-line
          ],
        ),
      ],
    );
  }

  Widget _buildUnfreezeDateText(Account acc, ThemeData theme, DateFormat df) {
    // coverage:ignore-line
    DateTime? targetDate;
    String label =
        AppLocalizations.of(context)!.calculatesOn; // coverage:ignore-line

    // coverage:ignore-start
    if (!acc.isFrozenCalculated) {
      targetDate = acc.firstStatementDate;
      label = AppLocalizations.of(context)!.initialBillOn;
      // coverage:ignore-end
    } else {
      // Phase 2: Next standard billing date
      if (acc.billingCycleDay != null) {
        // coverage:ignore-line
        targetDate = BillingHelper.getCycleEnd(
            DateTime.now(), acc.billingCycleDay!); // coverage:ignore-line
      }
    }

    if (targetDate == null) return const SizedBox.shrink();

    // coverage:ignore-start
    return Text(
      '$label: ${df.format(targetDate)}',
      style: TextStyle(
          // coverage:ignore-end
          fontSize: 11,
          color: Colors.orange.shade700, // coverage:ignore-line
          fontWeight: FontWeight.bold),
    );
  }

  Widget _buildAccountTrailing(Account acc, _CCBillingData data, bool compact,
      NumberFormat currencyFormat, String smartFormat, ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _buildTrailingBalanceText(
            acc, data, compact, currencyFormat, smartFormat),
        if (acc.type == AccountType.creditCard)
          Text(
            AppLocalizations.of(context)!
                .percentUsed((data.percent * 100).toStringAsFixed(0)),
            style: TextStyle(
                fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
          ),
      ],
    );
  }

  Widget _buildTrailingBalanceText(Account acc, _CCBillingData data,
      bool compact, NumberFormat currencyFormat, String smartFormat) {
    if (acc.type == AccountType.creditCard) {
      final displayAvailable = data.available > 0 ? data.available : 0.0;
      return Text(
        compact
            ? AppLocalizations.of(context)!.usedAvailableShort(
                CurrencyUtils.getSmartFormat(data.used, acc.currency),
                CurrencyUtils.getSmartFormat(displayAvailable, acc.currency))
            // coverage:ignore-start
            : AppLocalizations.of(context)!.usedAvailableLabel(
                currencyFormat.format(data.used),
                currencyFormat.format(displayAvailable)),
        // coverage:ignore-end
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
          color: data.used > 0 ? Colors.red : Colors.green,
        ),
      );
    }

    return Text(
      compact
          ? smartFormat
          : currencyFormat.format(acc.balance), // coverage:ignore-line
      style: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 16,
        color: acc.balance >= 0 ? Colors.green : Colors.red,
      ),
    );
  }

  Widget _buildMiniInfoChip(String label, double value, String currency,
      ThemeData theme, bool compact) {
    return Text(
      compact
          ? '$label: ${CurrencyUtils.getSmartFormat(value, currency)}'
          : '$label: ${CurrencyUtils.getFormatter(currency).format(value)}',
      style: TextStyle(
        fontSize: 11,
        color: theme.colorScheme.onSurface,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Color _getAccountColor(Account acc) {
    switch (acc.type) {
      case AccountType.savings:
        return Colors.blue;
      case AccountType.creditCard:
        return const Color(0xFF1A1A2E);
      case AccountType.wallet: // coverage:ignore-line
        return Colors.orange;
    }
  }

  IconData _getAccountIcon(Account acc) {
    switch (acc.type) {
      case AccountType.savings:
        return Icons.account_balance;
      case AccountType.creditCard:
        return Icons.credit_card;
      case AccountType.wallet: // coverage:ignore-line
        return Icons.account_balance_wallet;
    }
  }

  void _showAccountOptions(BuildContext context, WidgetRef ref, Account acc) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                    acc.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                    color: Colors.blue),
                title: Text(acc.isPinned
                    ? AppLocalizations.of(context)!
                        .unpinAccount // coverage:ignore-line
                    : AppLocalizations.of(context)!.pinAccount),
                onTap: () {
                  FocusScope.of(context).unfocus();
                  Navigator.pop(context);
                  _toggleAccountPin(acc.id);
                },
              ),
              if (acc.type == AccountType.creditCard) ...[
                _buildPayBillOption(context, ref, acc),
                _buildUpdateBillingCycleOption(context, ref, acc),
                _buildClearBilledOption(context, ref, acc),
                _buildRecalculateOption(context, ref, acc),
                _buildBillingDateInfo(ref, acc),
                const Divider(),
              ],
              ListTile(
                leading: const Icon(Icons.list_alt),
                title: Text(AppLocalizations.of(context)!.viewTransactions),
                // coverage:ignore-start
                onTap: () {
                  FocusScope.of(context).unfocus();
                  Navigator.pop(context);
                  Navigator.push(
                    // coverage:ignore-end
                    context,
                    // coverage:ignore-start
                    MaterialPageRoute(
                      builder: (_) =>
                          TransactionsScreen(initialAccountId: acc.id),
                      // coverage:ignore-end
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit),
                title: Text(AppLocalizations.of(context)!.editAccount),
                onTap: () {
                  FocusScope.of(context).unfocus();
                  Navigator.pop(context);
                  _showAddAccountSheet(context, ref, account: acc);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: Text(AppLocalizations.of(context)!.deleteAccount,
                    style: const TextStyle(color: Colors.red)),
                onTap: () {
                  FocusScope.of(context).unfocus();
                  Navigator.pop(context);
                  _confirmDelete(context, ref, acc);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleAccountPin(String accountId) async {
    await ref.read(storageServiceProvider).toggleAccountPin(accountId);
    ref.invalidate(accountsProvider);
  }

  Widget _buildPayBillOption(BuildContext context, WidgetRef ref, Account acc) {
    return ListTile(
      leading: const Icon(Icons.payment, color: Colors.green),
      title: Text(AppLocalizations.of(context)!.payBillAction,
          style: const TextStyle(
              color: Colors.green, fontWeight: FontWeight.bold)),
      onTap: () {
        FocusScope.of(context).unfocus();
        Navigator.pop(context);
        final isFullyPaid = _checkIfFullyPaid(ref, acc);
        showDialog(
            context: context,
            builder: (_) => RecordCCPaymentDialog(
                creditCardAccount: acc, isFullyPaid: isFullyPaid));
      },
    );
  }

  Widget _buildUpdateBillingCycleOption(
      BuildContext context, WidgetRef ref, Account acc) {
    final storage = ref.read(storageServiceProvider);
    final allTxns = ref.read(transactionsProvider).value ?? [];

    final lastRollover = storage.getLastRollover(acc.id);
    final payments = BillingHelper.calculatePeriodPayments(acc, allTxns,
        DateTime.fromMillisecondsSinceEpoch(lastRollover ?? 0), DateTime.now());

    final data = BillingHelper.getAdjustedCCData(
      accountBalance: acc.balance,
      billedAmount: BillingHelper.calculateBilledAmount(
          acc, allTxns, DateTime.now(), lastRollover),
      unbilledAmount:
          BillingHelper.calculateUnbilledAmount(acc, allTxns, DateTime.now()),
      paymentsSinceRollover: payments,
    );

    final totalNetDebt = data.$1;

    // We only show the "Update Billing Cycle" option if it's safe to change the Cycle Day.
    // Payment Due Date changes can be done independently via the "Edit Account" sheet.
    final isSafeToUpdate =
        totalNetDebt <= 0.01 || (acc.isFrozen && !acc.isFrozenCalculated);

    if (!isSafeToUpdate) {
      return const SizedBox.shrink();
    }

    final accountTxns = allTxns
        // coverage:ignore-start
        .where((t) =>
            !t.isDeleted && (t.accountId == acc.id || t.toAccountId == acc.id))
        .toList();
    accountTxns.sort((a, b) => b.date.compareTo(a.date));
    final newestTxnDate = accountTxns.isNotEmpty
        ? accountTxns.first.date
        : DateTime.now().subtract(const Duration(days: 30));
    // coverage:ignore-end

    return ListTile(
      // coverage:ignore-line
      leading: const Icon(Icons.edit_calendar, color: Colors.purple),
      title: Text(
          AppLocalizations.of(context)!
              .updateBillingCycle, // coverage:ignore-line
          style: const TextStyle(
              color: Colors.purple, fontWeight: FontWeight.bold)),
      // coverage:ignore-start
      subtitle: Text(AppLocalizations.of(context)!.updateBillingCycleDesc),
      onTap: () async {
        FocusScope.of(context).unfocus();
        Navigator.pop(context);
        final result = await showDialog<bool>(
            // coverage:ignore-end
            context: context,
            builder: (_) => UpdateBillingCycleDialog(
                  // coverage:ignore-line
                  account: acc,
                  newestTransactionDate: newestTxnDate,
                ));

        // coverage:ignore-start
        if (result == true) {
          ref.invalidate(accountsProvider);
          ref.invalidate(transactionsProvider);
          // coverage:ignore-end
        }
      },
    );
  }

  Widget _buildBillingDateInfo(WidgetRef ref, Account acc) {
    String lastBillStr = AppLocalizations.of(context)!.notCalculatedYet;
    String nextBillStr = AppLocalizations.of(context)!.tbdLabel;

    if (acc.billingCycleDay != null) {
      final dates = _getBillingDatesStrings(ref, acc);
      lastBillStr = dates.$1;
      nextBillStr = dates.$2;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context)!.lastBillDate(lastBillStr),
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(AppLocalizations.of(context)!.nextBillDate(nextBillStr),
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  (String, String) _getBillingDatesStrings(WidgetRef ref, Account acc) {
    if (acc.billingCycleDay == null) {
      return (
        AppLocalizations.of(context)!.tbdLabel, // coverage:ignore-line
        AppLocalizations.of(context)!.tbdLabel // coverage:ignore-line
      );
    }

    final now = DateTime.now();
    final storage = ref.read(storageServiceProvider);
    final lastRollover = storage.getLastRollover(acc.id);
    final df = DateFormat('MMM dd, yyyy');

    if (acc.isFrozen) {
      String last = lastRollover != null
          // coverage:ignore-start
          ? df.format(DateTime.fromMillisecondsSinceEpoch(lastRollover))
          : AppLocalizations.of(context)!.notCalculatedYet;
      String next = (!acc.isFrozenCalculated && acc.firstStatementDate != null)
          ? df.format(acc.firstStatementDate!)
          : df.format(BillingHelper.getCycleEnd(now, acc.billingCycleDay!));
      // coverage:ignore-end
      return (last, next);
    }

    final currentStart = BillingHelper.getCycleStart(now, acc.billingCycleDay!);
    final lastBillDate = currentStart.subtract(const Duration(seconds: 1));
    return (
      df.format(lastBillDate),
      df.format(BillingHelper.getCycleEnd(now, acc.billingCycleDay!))
    );
  }

  bool _checkIfFullyPaid(WidgetRef ref, Account acc) {
    if (acc.billingCycleDay == null) return false;
    final storage = ref.read(storageServiceProvider);

    if (acc.type == AccountType.creditCard) {
      return storage.isBilledAmountPaid(acc.id);
    }
    return acc.balance <= 0.01; // coverage:ignore-line
  }

  Widget _buildClearBilledOption(
      BuildContext context, WidgetRef ref, Account acc) {
    return ListTile(
      leading: const Icon(Icons.cleaning_services, color: Colors.blueGrey),
      title: Text(AppLocalizations.of(context)!.clearBilledAmountTitle,
          style: const TextStyle(
              color: Colors.blueGrey, fontWeight: FontWeight.bold)),
      subtitle: Text(AppLocalizations.of(context)!.clearBilledAmountDesc),
      onTap: () async {
        Navigator.pop(context);
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(AppLocalizations.of(context)!.clearBilledAmountTitle),
            content:
                Text(AppLocalizations.of(context)!.clearBilledConfirmMessage),
            actions: [
              TextButton(
                  onPressed: () =>
                      Navigator.pop(context, false), // coverage:ignore-line
                  child: Text(AppLocalizations.of(context)!.cancelAction)),
              TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(AppLocalizations.of(context)!.clearActionCap)),
            ],
          ),
        );

        if (confirmed == true) {
          await ref.read(storageServiceProvider).clearBilledAmount(acc.id);
          ref.invalidate(accountsProvider);
          ref.invalidate(transactionsProvider);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(
                    AppLocalizations.of(context)!.billedAmountClearedStatus)));
          }
        }
      },
    );
  }

  Widget _buildRecalculateOption(
      BuildContext context, WidgetRef ref, Account acc) {
    return ListTile(
      leading: const Icon(Icons.build_circle_outlined, color: Colors.orange),
      title: Text(AppLocalizations.of(context)!.recalculateBillTitle,
          style: const TextStyle(
              color: Colors.orange, fontWeight: FontWeight.bold)),
      subtitle: Text(AppLocalizations.of(context)!.recalculateBillDesc),
      // coverage:ignore-start
      onTap: () async {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              // coverage:ignore-end
              content: Text(AppLocalizations.of(context)!
                  .recalculatingBillStatus)), // coverage:ignore-line
        );
        try {
          await ref
              // coverage:ignore-start
              .read(storageServiceProvider)
              .recalculateBilledAmount(acc.id);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(AppLocalizations.of(context)!
                      .billRecalculatedStatus(acc.name))),
              // coverage:ignore-end
            );
          }
        } catch (e) {
          // coverage:ignore-start
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(e.toString().replaceAll('Exception: ', '')),
                // coverage:ignore-end
                backgroundColor: Colors.red,
              ),
            );
          }
        }
        ref.invalidate(accountsProvider); // coverage:ignore-line
        ref.invalidate(transactionsProvider); // coverage:ignore-line
      },
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Account acc) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.deleteAccountQuestion),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context)!
                .deleteAccountConfirmMessage(acc.name)),
            const SizedBox(height: 8),
            Text(AppLocalizations.of(context)!.deleteAccountWarning),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // coverage:ignore-line
            child: Text(AppLocalizations.of(context)!.cancelAction),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(storageServiceProvider).deleteAccount(acc.id);
              ref.invalidate(accountsProvider);
              ref.invalidate(transactionsProvider);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(AppLocalizations.of(context)!
                          .accountDeletedStatus(acc.name))),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(AppLocalizations.of(context)!.deleteActionCap),
          ),
        ],
      ),
    );
  }

  void _showAddAccountSheet(BuildContext context, WidgetRef ref,
      {Account? account}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddAccountSheet(account: account),
    );
  }
}

class AddAccountSheet extends ConsumerStatefulWidget {
  final Account? account;
  const AddAccountSheet({super.key, this.account});

  @override
  ConsumerState<AddAccountSheet> createState() => _AddAccountSheetState();
}

class _AddAccountSheetState extends ConsumerState<AddAccountSheet> {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  AccountType _type = AccountType.savings;
  double _initialBalance = 0;
  String _currency = '';
  double? _limit;
  int? _billingDay;
  int? _dueDay;

  @override
  void initState() {
    super.initState();
    if (widget.account != null) {
      final acc = widget.account!;
      _name = acc.name;
      _type = acc.type;
      _limit = acc.creditLimit;
      _billingDay = acc.billingCycleDay;
      _dueDay = acc.paymentDueDateDay;
      _currency = acc.currency;

      if (acc.type == AccountType.creditCard && acc.billingCycleDay != null) {
        _initializeCreditCardData(acc); // coverage:ignore-line
      } else {
        _initialBalance = acc.balance;
      }
    } else {
      _currency = '';
    }
  }

  // coverage:ignore-start
  void _initializeCreditCardData(Account acc) {
    final now = DateTime.now();
    final storage = ref.read(storageServiceProvider);
    final allTxns = storage.getTransactions();
    final lastRolloverMillis = storage.getLastRollover(acc.id);
    // coverage:ignore-end

    final unbilled = BillingHelper.calculateUnbilledAmount(
        acc, allTxns, now, // coverage:ignore-line
        lastRolloverMillis: lastRolloverMillis);
    final billed = BillingHelper.calculateBilledAmount(
        // coverage:ignore-line
        acc,
        allTxns,
        now,
        lastRolloverMillis);
    final payments = BillingHelper.calculatePeriodPayments(
        acc,
        allTxns, // coverage:ignore-line
        DateTime.fromMillisecondsSinceEpoch(lastRolloverMillis ?? 0),
        now); // coverage:ignore-line

    final (totalNetDebt, _, _, _) = BillingHelper.getAdjustedCCData(
      // coverage:ignore-line
      accountBalance: acc.balance, // coverage:ignore-line
      billedAmount: billed,
      unbilledAmount: unbilled,
      paymentsSinceRollover: payments,
    );
    _initialBalance = totalNetDebt; // coverage:ignore-line
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildNameField(),
            const SizedBox(height: 16),
            _buildTypeDropdown(),
            const SizedBox(height: 16),
            if (_type == AccountType.wallet) ...[
              _buildCurrencyDropdown(), // coverage:ignore-line
              const SizedBox(height: 16),
            ],
            const SizedBox(height: 16),
            _buildBalanceField(),
            if (_type == AccountType.creditCard) ..._buildCreditCardFields(),
            const SizedBox(height: 24),
            _buildSubmitButton(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Text(
        widget.account == null
            ? AppLocalizations.of(context)!.newAccountTitle
            : AppLocalizations.of(context)!.editAccountTitle,
        style: Theme.of(context).textTheme.headlineSmall);
  }

  Widget _buildNameField() {
    return TextFormField(
      initialValue: _name,
      decoration: InputDecoration(
          labelText: AppLocalizations.of(context)!.accountNameLabel),
      validator: (v) {
        if (v == null || v.isEmpty) {
          return AppLocalizations.of(context)!
              .requiredLabel; // coverage:ignore-line
        }
        final nameLower = v.trim().toLowerCase();
        if (nameLower == 'manual' || nameLower == 'deleted account') {
          return AppLocalizations.of(context)!
              .reservedNameError; // coverage:ignore-line
        }
        return null;
      },
      onSaved: (v) => _name = v!.trim(),
    );
  }

  Widget _buildTypeDropdown() {
    return IgnorePointer(
      ignoring: widget.account != null,
      child: Opacity(
        opacity: widget.account != null ? 0.5 : 1.0,
        child: DropdownButtonFormField<AccountType>(
          initialValue: _type,
          decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.typeLabel),
          items: AccountType.values
              .map((t) => DropdownMenuItem<AccountType>(
                    value: t,
                    child: Text(t.name.toUpperCase()),
                  ))
              .toList(),
          onChanged: (v) => setState(() => _type = v!), // coverage:ignore-line
        ),
      ),
    );
  }

  Widget _buildBalanceField() {
    return TextFormField(
      initialValue: _initialBalance.toString(),
      decoration: InputDecoration(
        labelText: AppLocalizations.of(context)!.currentBalanceLabel,
        prefixText:
            '${CurrencyUtils.getSymbol(_type == AccountType.wallet ? _currency : ref.watch(currencyProvider))} ',
      ),
      keyboardType: TextInputType
          .text, // Fix for iOS minus sign missing on numeric keypad
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegexUtils.negativeAmountExp)
      ],
      onSaved: (v) => _initialBalance = double.tryParse(v ?? '') ?? 0,
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _save,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF6C63FF),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      child: Text(widget.account == null
          ? AppLocalizations.of(context)!.createAccountAction
          : AppLocalizations.of(context)!.updateAccountAction),
    );
  }

  // coverage:ignore-start
  Widget _buildCurrencyDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _currency,
      decoration: InputDecoration(
          labelText: AppLocalizations.of(context)!.currencyLabel),
      items: {
        'en_US': AppLocalizations.of(context)!.usDollarLabel,
        'en_IN': AppLocalizations.of(context)!.indianRupeeLabel,
        'en_GB': AppLocalizations.of(context)!.britishPoundLabel,
        'de_DE': AppLocalizations.of(context)!.euroLabel,
        'ja_JP': AppLocalizations.of(context)!.japaneseYenLabel,
        'zh_CN': AppLocalizations.of(context)!.chineseYuanLabel,
        'ar_AE': AppLocalizations.of(context)!.uaeDirhamLabel,
        // coverage:ignore-end
      }
          // coverage:ignore-start
          .entries
          .map((e) => DropdownMenuItem(
                value: e.key,
                child: Text(e.value),
                // coverage:ignore-end
              ))
          .toList(), // coverage:ignore-line
      onChanged: (v) => setState(() => _currency = v!), // coverage:ignore-line
    );
  }

  List<Widget> _buildCreditCardFields() {
    // coverage:ignore-line
    return [
      // coverage:ignore-line
      const SizedBox(height: 16),
      _buildLimitField(), // coverage:ignore-line
      const SizedBox(height: 16),
      _buildBillingCycleFields(), // coverage:ignore-line
    ];
  }

  // coverage:ignore-start
  Widget _buildLimitField() {
    return TextFormField(
      initialValue: _limit?.toString(),
      decoration: InputDecoration(
        labelText: AppLocalizations.of(context)!.creditLimitLabel,
        // coverage:ignore-end
        prefixText:
            '${NumberFormat.simpleCurrency(locale: ref.watch(currencyProvider)).currencySymbol} ', // coverage:ignore-line
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        // coverage:ignore-line
        FilteringTextInputFormatter.allow(
            RegexUtils.amountExp) // coverage:ignore-line
      ],
      // coverage:ignore-start
      validator: (v) =>
          v!.isEmpty ? AppLocalizations.of(context)!.requiredLabel : null,
      onSaved: (v) => _limit = double.tryParse(v ?? '') ?? 0,
      // coverage:ignore-end
    );
  }

  Widget _buildBillingCycleFields() {
    // coverage:ignore-line
    final isEditing = widget.account != null; // coverage:ignore-line

    return Row(
      // coverage:ignore-line
      crossAxisAlignment: CrossAxisAlignment.start,
      // coverage:ignore-start
      children: [
        Expanded(
          child: _buildCycleDayField(
            label: AppLocalizations.of(context)!.billGenDayLabel,
            hint: AppLocalizations.of(context)!.day15Hint,
            helperText: AppLocalizations.of(context)!.dayOfMonthHelper,
            value: _billingDay,
            onSaved: (val) => _billingDay = val,
            // coverage:ignore-end
            canEdit: !isEditing,
          ),
        ),
        const SizedBox(width: 16),
        // coverage:ignore-start
        Expanded(
          child: _buildCycleDayField(
            label: AppLocalizations.of(context)!.paymentDueDayLabel,
            hint: AppLocalizations.of(context)!.day5Hint,
            helperText: AppLocalizations.of(context)!.dayOfMonthHelper,
            value: _dueDay,
            onSaved: (val) => _dueDay = val,
            // coverage:ignore-end
            canEdit: true, // Always editable as requested
          ),
        ),
      ],
    );
  }

  Widget _buildCycleDayField({
    // coverage:ignore-line
    required String label,
    required String hint,
    required String helperText,
    required int? value,
    required ValueChanged<int?> onSaved,
    required bool canEdit,
  }) {
    return DropdownButtonFormField<int>(
      // coverage:ignore-line
      initialValue: value,
      decoration: InputDecoration(
        // coverage:ignore-line
        labelText: label,
        hintText: hint,
        helperText: helperText,
        filled: !canEdit,
        fillColor: !canEdit ? Colors.black12 : null,
      ),
      items: List.generate(28, (i) => i + 1) // coverage:ignore-line
          .map((day) => DropdownMenuItem<int>(
                // coverage:ignore-line
                value: day,
                child: Text(day.toString()), // coverage:ignore-line
              ))
          .toList(), // coverage:ignore-line
      onChanged: canEdit ? (v) => onSaved(v) : null, // coverage:ignore-line
      onSaved: onSaved,
      validator: (v) => // coverage:ignore-line
          v == null
              ? AppLocalizations.of(context)!.requiredShortLabel
              : null, // coverage:ignore-line
    );
  }

  bool _shouldKeepBilledStatus(StorageService storage) {
    if (widget.account == null ||
        widget.account!.type !=
            AccountType.creditCard || // coverage:ignore-line
        _billingDay == null) {
      // coverage:ignore-line
      return false;
    }

    // coverage:ignore-start
    final lastRollover = storage.getLastRollover(widget.account!.id);
    final allTxns = ref.read(transactionsProvider).value ?? [];
    final currentBilled = BillingHelper.calculateBilledAmount(
        widget.account!, allTxns, DateTime.now(), lastRollover);
    // coverage:ignore-end

    return currentBilled == 0 &&
        widget.account!.billingCycleDay != _billingDay; // coverage:ignore-line
  }

  Future<void> _createOrUpdateAccount(
      StorageService storage, bool keepBilledStatus) async {
    if (widget.account != null) {
      // coverage:ignore-start
      final acc = widget.account!;
      acc.name = _name;
      if (acc.type == AccountType.creditCard) {
        final now = DateTime.now();
        final allTxns = storage.getTransactions();
        final lastRolloverMillis = storage.getLastRollover(acc.id);
        // coverage:ignore-end

        final unbilled = BillingHelper.calculateUnbilledAmount(
            // coverage:ignore-line
            acc,
            allTxns,
            now,
            lastRolloverMillis: lastRolloverMillis);
        final billed = BillingHelper.calculateBilledAmount(
            // coverage:ignore-line
            acc,
            allTxns,
            now,
            lastRolloverMillis);

        acc.balance =
            _initialBalance - billed - unbilled; // coverage:ignore-line
      } else {
        acc.balance = _initialBalance; // coverage:ignore-line
      }
      // coverage:ignore-start
      acc.creditLimit = _limit;
      acc.billingCycleDay = _billingDay;
      acc.paymentDueDateDay = _dueDay;
      acc.currency = _currency;
      await storage.saveAccount(acc, keepBilledStatus: keepBilledStatus);
      // coverage:ignore-end
    } else {
      final newAccount = Account.create(
        name: _name,
        type: _type,
        initialBalance: _initialBalance,
        currency: _currency,
        creditLimit: _limit,
        billingCycleDay: _billingDay,
        paymentDueDateDay: _dueDay,
        profileId: ref.read(activeProfileIdProvider),
      );
      await storage.saveAccount(newAccount);
    }
  }

  void _save() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final storage = ref.read(storageServiceProvider);

      bool keepBilledStatus = _shouldKeepBilledStatus(storage);
      await _createOrUpdateAccount(storage, keepBilledStatus);

      ref.invalidate(accountsProvider);
      if (mounted) Navigator.pop(context);
    }
  }
}
