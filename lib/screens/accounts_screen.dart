import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../utils/currency_utils.dart';
import '../providers.dart';
import '../models/account.dart';
import '../widgets/account_card.dart';
import '../screens/transactions_screen.dart';
import '../utils/billing_helper.dart';
import '../widgets/pure_icons.dart';

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
                    onPressed: () => _showAddAccountSheet(context, ref),
                    child: const Text('Add Account'),
                  ),
                ],
              ),
            );
          }

          final creditCards =
              accounts.where((a) => a.type == AccountType.creditCard).toList();
          Widget? summaryWidget;

          if (creditCards.isNotEmpty) {
            double totalLimit = 0;
            double totalUsage = 0;
            final allTxns = transactionsAsync.value ?? [];
            final now = DateTime.now();

            for (var card in creditCards) {
              totalLimit += card.creditLimit ?? 0;
              final unbilled =
                  BillingHelper.calculateUnbilledAmount(card, allTxns, now);
              totalUsage += (card.balance + unbilled);
            }

            final utilization =
                totalLimit > 0 ? (totalUsage / totalLimit) * 100 : 0.0;
            final available =
                totalLimit > totalUsage ? totalLimit - totalUsage : 0.0;

            // Use user's preferred currency for summary, or default to generic if mixed currencies logic is complex.
            // Assuming generic or profile currency.
            final profileCurrency = ref.watch(currencyProvider);

            String format(double val) {
              if (_compactView) {
                return CurrencyUtils.getSmartFormat(val, profileCurrency);
              }
              return CurrencyUtils.getFormatter(profileCurrency).format(val);
            }

            summaryWidget = Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.8),
                    Theme.of(context)
                        .colorScheme
                        .tertiary
                        .withValues(alpha: 0.8),
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
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
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildAccountItem(BuildContext context, WidgetRef ref, Account acc) {
    double unbilled = 0;
    if (acc.type == AccountType.creditCard) {
      final now = DateTime.now();
      final allTxns = ref.watch(transactionsProvider).value ?? [];
      unbilled = BillingHelper.calculateUnbilledAmount(acc, allTxns, now);
    }

    return AccountCard(
      account: acc,
      unbilledAmount: unbilled,
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

  void _confirmDelete(BuildContext context, WidgetRef ref, Account acc) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account?'),
        content: Text(
            'Are you sure you want to delete "${acc.name}"? \n\nExisting transactions will NOT be deleted but will no longer be linked to this account.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
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
                  onChanged: (v) => setState(() => _type = v!),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_type == AccountType.wallet) ...[
              DropdownButtonFormField<String>(
                initialValue: _currency,
                decoration: const InputDecoration(labelText: 'Currency'),
                items: {
                  'en_US': 'US Dollar (\$)',
                  'en_IN': 'Indian Rupee (₹)',
                  'en_GB': 'British Pound (£)',
                  'de_DE': 'Euro (€)',
                  'ja_JP': 'Japanese Yen (¥)',
                  'zh_CN': 'Chinese Yuan (¥)',
                  'ar_AE': 'UAE Dirham (د.إ)',
                }
                    .entries
                    .map((e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _currency = v!),
              ),
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
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}$'))
              ],
              onSaved: (v) => _initialBalance = double.tryParse(v ?? '') ?? 0,
            ),
            if (_type == AccountType.creditCard) ...[
              const SizedBox(height: 16),
              TextFormField(
                initialValue: _limit?.toString(),
                decoration: InputDecoration(
                  labelText: 'Credit Limit',
                  prefixText:
                      '${NumberFormat.simpleCurrency(locale: ref.watch(currencyProvider)).currencySymbol} ',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                ],
                validator: (v) => v!.isEmpty ? 'Required' : null,
                onSaved: (v) => _limit = double.tryParse(v ?? '') ?? 0,
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: _billingDay?.toString(),
                      decoration: const InputDecoration(
                          labelText: 'Bill Gen. Day',
                          hintText: 'e.g. 15',
                          helperText: 'Day of month'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (v) =>
                          setState(() => _billingDay = int.tryParse(v)),
                      onSaved: (v) => _billingDay = int.tryParse(v ?? ''),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      initialValue: _dueDay?.toString(),
                      decoration: const InputDecoration(
                          labelText: 'Payment Period',
                          hintText: 'e.g. 20',
                          helperText: 'Days to pay'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (v) =>
                          setState(() => _dueDay = int.tryParse(v)),
                      onSaved: (v) => _dueDay = int.tryParse(v ?? ''),
                    ),
                  ),
                ],
              ),
              if (_billingDay != null && _dueDay != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8)),
                  child: Builder(builder: (context) {
                    final today = DateTime.now();
                    final billDate =
                        DateTime(today.year, today.month, _billingDay!);
                    final dueDate = billDate.add(Duration(days: _dueDay!));
                    return Text(
                      'Example: Bill on ${_billingDay!}th \nDue on ${DateFormat("MMM dd").format(dueDate)}',
                      style:
                          const TextStyle(fontSize: 12, color: Colors.blueGrey),
                    );
                  }),
                )
              ]
            ],
            const SizedBox(height: 32),
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

  void _save() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final storage = ref.read(storageServiceProvider);
      if (widget.account != null) {
        final acc = widget.account!;
        acc.name = _name;
        acc.balance = _initialBalance;
        acc.creditLimit = _limit;
        acc.billingCycleDay = _billingDay;
        acc.paymentDueDateDay = _dueDay;
        acc.currency = _currency;
        await storage.saveAccount(acc);
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
