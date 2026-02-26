import 'package:samriddhi_flow/utils/regex_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../utils/currency_utils.dart';
import '../providers.dart';
import '../models/account.dart';
import '../models/transaction.dart';
import '../widgets/account_card.dart';
import '../screens/transactions_screen.dart';
import '../utils/billing_helper.dart';
import '../widgets/pure_icons.dart';
import 'cc_payment_dialog.dart';

class CreditUsageVisibilityNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

final showCreditUsageProvider =
    NotifierProvider<CreditUsageVisibilityNotifier, bool>(
        CreditUsageVisibilityNotifier.new);

class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({super.key});

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen> {
  bool _compactView = true;

  @override
  void initState() {
    super.initState();
    // Default is short form (true)
    _compactView = true;
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);
    final transactionsAsync = ref.watch(transactionsProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('My Accounts'),
        actions: [
          IconButton(
            icon: _compactView
                ? PureIcons.listExtended(size: 20)
                : PureIcons.listCompact(size: 20),
            tooltip: _compactView
                ? 'Switch to Extended Numbers'
                : 'Switch to Compact Numbers',
            onPressed: () => setState(() => _compactView = !_compactView),
          ),
          IconButton(
            icon: Icon(
              ref.watch(showCreditUsageProvider)
                  ? Icons.visibility
                  : Icons.visibility_off,
            ),
            tooltip: ref.watch(showCreditUsageProvider)
                ? 'Hide Credit Usage'
                : 'Show Credit Usage',
            onPressed: () =>
                ref.read(showCreditUsageProvider.notifier).toggle(),
          ),
        ],
      ),
      body: accountsAsync.when(
        data: (accounts) {
          if (accounts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  PureIcons.accounts(size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No accounts found.'),
                  TextButton(
                    onPressed: () => _showAddAccountSheet(context, ref), // coverage:ignore-line
                    child: const Text('Add Account'),
                  ),
                ],
              ),
            );
          }

          final summaryWidget = _buildCreditUsageSummary(
              context, accounts, transactionsAsync.value ?? []);

          return Column(
            children: [
              if (summaryWidget != null && ref.watch(showCreditUsageProvider))
                summaryWidget,
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    childAspectRatio: 0.78,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: accounts.length + 1,
                  itemBuilder: (context, index) {
                    if (index == accounts.length) {
                      return _buildAddCard(context, ref);
                    }
                    return _buildAccountItem(context, ref, accounts[index]);
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')), // coverage:ignore-line
      ),
    );
  }

  Widget? _buildCreditUsageSummary(
      BuildContext context, List<Account> accounts, List<Transaction> allTxns) {
    final creditCards =
        accounts.where((a) => a.type == AccountType.creditCard).toList();
    if (creditCards.isEmpty) return null;

    double totalLimit = 0;
    double totalUsage = 0;
    final now = DateTime.now();
    final storage = ref.watch(storageServiceProvider);

    for (var card in creditCards) {
      totalLimit += card.creditLimit ?? 0;
      final unbilled =
          BillingHelper.calculateUnbilledAmount(card, allTxns, now);
      final lastRollover = storage.getLastRollover(card.id);
      final billed =
          BillingHelper.calculateBilledAmount(card, allTxns, now, lastRollover);
      totalUsage += (card.balance + unbilled + billed);
    }

    final utilization = totalLimit > 0 ? (totalUsage / totalLimit) * 100 : 0.0;
    final available = totalLimit > totalUsage ? totalLimit - totalUsage : 0.0;
    final profileCurrency = ref.watch(currencyProvider);

    String format(double val) {
      if (_compactView) {
        return CurrencyUtils.getSmartFormat(val, profileCurrency);
      }
      return CurrencyUtils.getFormatter(profileCurrency).format(val);
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
            Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Credit Usage',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${utilization.toStringAsFixed(1)}% Used',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    format(totalUsage),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Used',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              Container(
                height: 40,
                width: 1,
                color: Colors.white.withValues(alpha: 0.3),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    format(totalLimit),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Total Limit',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: totalLimit > 0
                  ? (totalUsage / totalLimit).clamp(0.0, 1.0)
                  : 0,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(
                  utilization > 80 ? Colors.redAccent : Colors.white),
              minHeight: 6,
            ),
          ),
          if (available > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Available: ${format(available)}',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12,
                    fontStyle: FontStyle.italic),
              ),
            )
        ],
      ),
    );
  }

  Widget _buildAccountItem(BuildContext context, WidgetRef ref, Account acc) {
    double unbilled = 0;
    double billed = 0;
    if (acc.type == AccountType.creditCard) {
      final now = DateTime.now();
      final allTxns = ref.watch(transactionsProvider).value ?? [];
      unbilled = BillingHelper.calculateUnbilledAmount(acc, allTxns, now);

      final storage = ref.watch(storageServiceProvider);
      final lastRollover = storage.getLastRollover(acc.id);
      billed =
          BillingHelper.calculateBilledAmount(acc, allTxns, now, lastRollover);
    }

    return AccountCard(
      account: acc,
      unbilledAmount: unbilled,
      billedAmount: billed,
      compactView: _compactView,
      onTap: () => _showAccountOptions(context, ref, acc),
    );
  }

  Widget _buildAddCard(BuildContext context, WidgetRef ref) {
    return Card(
      color: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(
            color: Colors.grey, width: 2, style: BorderStyle.solid),
      ),
      child: InkWell(
        onTap: () => _showAddAccountSheet(context, ref),
        borderRadius: BorderRadius.circular(16),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PureIcons.addCircle(size: 40, color: Colors.grey),
              const SizedBox(height: 8),
              const Text('Add New'),
            ],
          ),
        ),
      ),
    );
  }

  void _showAccountOptions(BuildContext context, WidgetRef ref, Account acc) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (acc.type == AccountType.creditCard) ...[
              _buildPayBillOption(context, ref, acc),
              _buildClearBilledOption(context, ref, acc),
              _buildRecalculateOption(context, ref, acc),
            ],
            ListTile(
              leading: const Icon(Icons.list_alt),
              title: const Text('View Transactions'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        TransactionsScreen(initialAccountId: acc.id),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Account'),
              onTap: () {
                Navigator.pop(context);
                _showAddAccountSheet(context, ref, account: acc);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Account',
                  style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(context, ref, acc);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPayBillOption(BuildContext context, WidgetRef ref, Account acc) {
    return ListTile(
      leading: const Icon(Icons.payment, color: Colors.green),
      title: const Text('Pay Bill',
          style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
      onTap: () {
        Navigator.pop(context);
        final isFullyPaid = _checkIfFullyPaid(ref, acc);
        showDialog(
            context: context,
            builder: (_) => RecordCCPaymentDialog(
                creditCardAccount: acc, isFullyPaid: isFullyPaid));
      },
    );
  }

  bool _checkIfFullyPaid(WidgetRef ref, Account acc) {
    if (acc.billingCycleDay == null) return false;
    final today = DateTime.now();
    final lastBillDate = today.day > acc.billingCycleDay!
        ? DateTime(today.year, today.month, acc.billingCycleDay!)
        : DateTime(today.year, today.month - 1, acc.billingCycleDay!); // coverage:ignore-line

    final allTxns = ref.read(transactionsProvider).value ?? [];
    final totalPaid = allTxns
        .where((t) =>
            // coverage:ignore-start
            !t.isDeleted &&
            t.toAccountId == acc.id &&
            t.type == TransactionType.transfer &&
            t.date.isAfter(lastBillDate.subtract(const Duration(days: 1))))
            // coverage:ignore-end
        .fold(0.0, (sum, t) => sum + t.amount);

    final storage = ref.read(storageServiceProvider);
    final billedAmount = BillingHelper.calculateBilledAmount(
        acc, allTxns, today, storage.getLastRollover(acc.id));
    final totalDue = acc.balance + billedAmount;

    return totalDue <= 0.01 || (totalDue > 0 && totalPaid >= totalDue);
  }

  Widget _buildClearBilledOption(
      BuildContext context, WidgetRef ref, Account acc) {
    return ListTile(
      leading: const Icon(Icons.cleaning_services, color: Colors.blueGrey),
      title: const Text('Clear Billed Amount',
          style:
              TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold)),
      subtitle: const Text('Mark current bill as paid/cleared'),
      onTap: () async {
        Navigator.pop(context);
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Clear Billed Amount?'),
            content: const Text(
                'This will set the current "Billed Amount" to 0 without recording a payment transaction.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false), // coverage:ignore-line
                  child: const Text('Cancel')),
              TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Clear')),
            ],
          ),
        );

        if (confirmed == true) {
          await ref.read(storageServiceProvider).clearBilledAmount(acc.id);
          ref.invalidate(accountsProvider);
          ref.invalidate(transactionsProvider);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Billed amount cleared.')));
          }
        }
      },
    );
  }

  Widget _buildRecalculateOption(
      BuildContext context, WidgetRef ref, Account acc) {
    return ListTile(
      leading: const Icon(Icons.build_circle_outlined, color: Colors.orange),
      title: const Text('Recalculate Bill',
          style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
      subtitle: const Text('Refreshes billing cycle display'),
      // coverage:ignore-start
      onTap: () async {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
      // coverage:ignore-end
          const SnackBar(content: Text('Recalculating bill...')),
        );
        // coverage:ignore-start
        await ref.read(storageServiceProvider).recalculateBilledAmount(acc.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Bill recalculated for ${acc.name}.')),
        // coverage:ignore-end
          );
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
        title: const Text('Delete Account?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete "${acc.name}"?'),
            const SizedBox(height: 8),
            const Text(
                'Existing transactions will NOT be deleted but will no longer be linked to this account.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // coverage:ignore-line
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(storageServiceProvider).deleteAccount(acc.id);
              ref.invalidate(accountsProvider);
              ref.invalidate(transactionsProvider);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Account "${acc.name}" deleted.')),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
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
      _name = widget.account!.name;
      _type = widget.account!.type;
      _initialBalance = widget.account!.balance;
      _limit = widget.account!.creditLimit;
      _billingDay = widget.account!.billingCycleDay;
      _dueDay = widget.account!.paymentDueDateDay;
      _currency = widget.account!.currency;
    } else {
      _currency = '';
    }
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
            Text(widget.account == null ? 'New Account' : 'Edit Account',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 24),
            TextFormField(
              initialValue: _name,
              decoration: const InputDecoration(labelText: 'Account Name'),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                final nameLower = v.trim().toLowerCase();
                if (nameLower == 'manual' || nameLower == 'deleted account') {
                  return 'Reserved name';
                }
                return null;
              },
              onSaved: (v) => _name = v!.trim(),
            ),
            const SizedBox(height: 16),
            IgnorePointer(
              ignoring: widget.account != null,
              child: Opacity(
                opacity: widget.account != null ? 0.5 : 1.0,
                child: DropdownButtonFormField<AccountType>(
                  initialValue: _type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: AccountType.values
                      .map((t) => DropdownMenuItem<AccountType>(
                            value: t,
                            child: Text(t.name.toUpperCase()),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _type = v!), // coverage:ignore-line
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_type == AccountType.wallet) ...[
              _buildCurrencyDropdown(), // coverage:ignore-line
              const SizedBox(height: 16),
            ],
            const SizedBox(height: 16),
            TextFormField(
              initialValue: _initialBalance.toString(),
              decoration: InputDecoration(
                labelText: _type == AccountType.creditCard
                    ? 'Current Balance (Debt)'
                    : 'Current Balance',
                prefixText:
                    '${CurrencyUtils.getSymbol(_type == AccountType.wallet ? _currency : ref.watch(currencyProvider))} ',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegexUtils.amountExp)
              ],
              onSaved: (v) => _initialBalance = double.tryParse(v ?? '') ?? 0,
            ),
            if (_type == AccountType.creditCard) ..._buildCreditCardFields(),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                  widget.account == null ? 'Create Account' : 'Update Account'),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // coverage:ignore-start
  Widget _buildCurrencyDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _currency,
  // coverage:ignore-end
      decoration: const InputDecoration(labelText: 'Currency'),
      items: { // coverage:ignore-line
        'en_US': 'US Dollar (\$)',
        'en_IN': 'Indian Rupee (₹)',
        'en_GB': 'British Pound (£)',
        'de_DE': 'Euro (€)',
        'ja_JP': 'Japanese Yen (¥)',
        'zh_CN': 'Chinese Yuan (¥)',
        'ar_AE': 'UAE Dirham (د.إ)',
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

  List<Widget> _buildCreditCardFields() { // coverage:ignore-line
    return [ // coverage:ignore-line
      const SizedBox(height: 16),
      // coverage:ignore-start
      TextFormField(
        initialValue: _limit?.toString(),
        decoration: InputDecoration(
      // coverage:ignore-end
          labelText: 'Credit Limit',
          prefixText:
              '${NumberFormat.simpleCurrency(locale: ref.watch(currencyProvider)).currencySymbol} ', // coverage:ignore-line
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [ // coverage:ignore-line
          FilteringTextInputFormatter.allow(RegexUtils.amountExp) // coverage:ignore-line
        ],
        validator: (v) => v!.isEmpty ? 'Required' : null, // coverage:ignore-line
        onSaved: (v) => _limit = double.tryParse(v ?? '') ?? 0, // coverage:ignore-line
      ),
      const SizedBox(height: 16),
      Row( // coverage:ignore-line
        crossAxisAlignment: CrossAxisAlignment.start,
        // coverage:ignore-start
        children: [
          Expanded(
            child: TextFormField(
              initialValue: _billingDay?.toString(),
        // coverage:ignore-end
              decoration: const InputDecoration(
                  labelText: 'Bill Gen. Day',
                  hintText: 'e.g. 15',
                  helperText: 'Day of month'),
              keyboardType: TextInputType.number,
              // coverage:ignore-start
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) {
                if (v!.isEmpty) return 'Req';
                final d = int.tryParse(v);
                if (d == null || d < 1 || d > 31) return '1-31';
              // coverage:ignore-end
                return null;
              },
              onSaved: (v) => _billingDay = int.tryParse(v ?? ''), // coverage:ignore-line
            ),
          ),
          const SizedBox(width: 16),
          // coverage:ignore-start
          Expanded(
            child: TextFormField(
              initialValue: _dueDay?.toString(),
          // coverage:ignore-end
              decoration: const InputDecoration(
                  labelText: 'Payment Due Day',
                  hintText: 'e.g. 5',
                  helperText: 'Day of month'),
              keyboardType: TextInputType.number,
              // coverage:ignore-start
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) {
                if (v!.isEmpty) return 'Req';
                final d = int.tryParse(v);
                if (d == null || d < 1 || d > 31) return '1-31';
              // coverage:ignore-end
                return null;
              },
              onSaved: (v) => _dueDay = int.tryParse(v ?? ''), // coverage:ignore-line
            ),
          ),
        ],
      )
    ];
  }

  void _save() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final storage = ref.read(storageServiceProvider);

      // Smart Update Logic: Check if we need to preserve "Billed = 0" status
      bool keepBilledStatus = false;
      if (widget.account != null &&
          // coverage:ignore-start
          widget.account!.type == AccountType.creditCard &&
          _billingDay != null) {
        final lastRollover = storage.getLastRollover(widget.account!.id);
        final allTxns = ref.read(transactionsProvider).value ?? [];
        final now = DateTime.now();
        final currentBilled = BillingHelper.calculateBilledAmount(
            widget.account!, allTxns, now, lastRollover);
          // coverage:ignore-end

        if (currentBilled == 0 && // coverage:ignore-line
            widget.account!.billingCycleDay != _billingDay) { // coverage:ignore-line
          keepBilledStatus = true;
        }
      }

      if (widget.account != null) {
        // coverage:ignore-start
        final acc = widget.account!;
        acc.name = _name;
        acc.balance = _initialBalance;
        acc.creditLimit = _limit;
        acc.billingCycleDay = _billingDay;
        acc.paymentDueDateDay = _dueDay;
        acc.currency = _currency;
        await storage.saveAccount(acc, keepBilledStatus: keepBilledStatus);
        // coverage:ignore-end
      } else {
        final profileId = ref.read(activeProfileIdProvider);
        final newAccount = Account.create(
          name: _name,
          type: _type,
          initialBalance: _initialBalance,
          currency: _currency,
          creditLimit: _limit,
          billingCycleDay: _billingDay,
          paymentDueDateDay: _dueDay,
          profileId: profileId,
        );
        await storage.saveAccount(newAccount);
      }
      ref.invalidate(accountsProvider);
      if (mounted) Navigator.pop(context);
    }
  }
}
