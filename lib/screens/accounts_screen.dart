import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../utils/currency_utils.dart'; // Keep this for CurrencyUtils
import '../providers.dart'; // Keep this for currencyProvider
import '../models/account.dart';
import '../widgets/account_card.dart';
import 'cc_payment_dialog.dart';
import '../screens/transactions_screen.dart'; // Added for navigation
import '../utils/billing_helper.dart';
import '../models/transaction.dart';
import '../widgets/pure_icons.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsProvider);

    // Trigger Rollover check once (fire and forget, or awaited in provider?)
    // Best to do it in provider creation, but here we can just do it.
    // Or better, update accountsProvider to do it.
    // Let's do it in a useEffect-like way or FutureBuilder if simpler.
    // Actually, accountsProvider is a Stream/Provider.
    // Let's rely on init. But Init is main.
    // Let's call it here.
    ref.listen(accountsProvider, (prev, next) {
      if (next.value != null) {
        ref.read(storageServiceProvider).checkCreditCardRollovers().then((_) {
          // If rollover happened, we might need to refresh?
          // storageService updates Hive directly.
          // accountsProvider watches Hive. So it should auto-update.
        });
      }
    });

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(title: const Text('My Accounts')),
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

          // Credit Card Summary Logic
          final creditCards =
              accounts.where((a) => a.type == AccountType.creditCard).toList();
          Widget? summaryWidget;

          if (creditCards.isNotEmpty) {
            double totalLimit = 0;
            double totalUsage = 0;

            for (var card in creditCards) {
              totalLimit += card.creditLimit ?? 0;
              // If balance is negative, it represents debt/usage.
              if (card.balance < 0) {
                totalUsage += card.balance.abs();
              }
            }

            final utilization =
                totalLimit > 0 ? (totalUsage / totalLimit) * 100 : 0.0;
            final available = totalLimit > totalUsage ? totalLimit - totalUsage : 0.0;

            summaryWidget = Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary.withOpacity(0.8),
                    Theme.of(context).colorScheme.tertiary.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
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
                          color: Colors.white.withOpacity(0.2),
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
                            CurrencyUtils.formatCurrency(totalUsage),
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
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        height: 40,
                        width: 1,
                        color: Colors.white.withOpacity(0.3),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            CurrencyUtils.formatCurrency(totalLimit),
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
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                   const SizedBox(height: 12),
                   // Progress Bar
                   ClipRRect(
                     borderRadius: BorderRadius.circular(4),
                     child: LinearProgressIndicator(
                       value: totalLimit > 0 ? (totalUsage / totalLimit).clamp(0.0, 1.0) : 0,
                       backgroundColor: Colors.white.withOpacity(0.2),
                       valueColor: AlwaysStoppedAnimation<Color>(
                         utilization > 80 ? Colors.redAccent : Colors.white
                       ),
                       minHeight: 6,
                     ),
                   ),
                   if (available > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Available: ${CurrencyUtils.formatCurrency(available)}',
                         style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 12,
                              fontStyle: FontStyle.italic
                            ),
                      ),
                    )
                ],
              ),
            );
          }

          return Column(
            children: [
              if (summaryWidget != null) summaryWidget,
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    childAspectRatio: 0.9,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: accounts.length + 1,
                  itemBuilder: (context, index) {
                    if (index == accounts.length) {
                      return _buildAddCard(context, ref);
                    }
                    // Continue with existing item builder...
                    // We need to access the rest of the method, but replace_file does distinct chunks.
                    // The original code returned GridView directly.
                    // I am replacing the START of the `data:` block.
                    // I need to ensure I don't break the closure.
                    
                    // Original code:
                    // return GridView.builder(
                    //   padding: ...
                    
                    // New code:
                    // return Column(children: [..., Expanded(child: GridView.builder(...))]);
                    
                    // The `itemBuilder` Logic follows.
                    
                    // I'll execute the replacement carefully.
                    // The TargetContent should match exactly lines 60-69 of original.
                    return _buildAccountItem(context, ref, accounts[index]);
                  },
                ),
              ),
            ],
          );
        },

              // Calculate Unbilled for Credit Cards
              double unbilled = 0;
              final acc = accounts[index];
              if (acc.type == AccountType.creditCard &&
                  acc.billingCycleDay != null) {
                final now = DateTime.now();
                final cycleStart =
                    BillingHelper.getCycleStart(now, acc.billingCycleDay!);

                final allTxns = ref.watch(transactionsProvider).value ?? [];
                final relevantTxns = allTxns.where((t) =>
                    !t.isDeleted &&
                    t.accountId ==
                        acc
                            .id && // Only Transactions FROM this account (Expenses)
                    // What about transfers TO this account (Payments)? Payments reduce billed usually.
                    // Our unbilled logic: Expenses in current cycle.
                    // Transfers FROM this account (Cash Advance) also unbilled?
                    DateTime(t.date.year, t.date.month, t.date.day)
                        .isAfter(cycleStart));

                for (var t in relevantTxns) {
                  if (t.type == TransactionType.expense) unbilled += t.amount;
                  if (t.type == TransactionType.income) unbilled -= t.amount;
                  if (t.type == TransactionType.transfer &&
                      t.accountId == acc.id) {
                    unbilled += t.amount; // Transfer OUT
                  }
                  // Transfer TO (Payment) is usually applied to Billed balance.
                  // Unless user makes payment for unbilled?
                  // StorageService logic applies Payment to Balance. So we ignore it here.
                }
              }

              return AccountCard(
                  account: accounts[index],
                  unbilledAmount: unbilled,
                  onTap: () {
                    // Show Details Dialog
                    final acc = accounts[index];
                    showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                              title: Text(acc.name),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Type: ${acc.type.name.toUpperCase()}'),
                                  const SizedBox(height: 8),
                                  Text(
                                      'Balance: ${CurrencyUtils.getFormatter(acc.currency).format(acc.balance)}'),
                                  if (acc.type == AccountType.creditCard) ...[
                                    const Divider(),
                                    Text(
                                        'Credit Limit: ${NumberFormat.simpleCurrency(locale: ref.watch(currencyProvider)).format(acc.creditLimit)}'),
                                    Text(
                                        'Bill Generation: Day ${acc.billingCycleDay}'),
                                    Text(
                                        'Grace Period: ${acc.paymentDueDateDay} days'),
                                    // Calculate approximate next due date
                                    Builder(builder: (context) {
                                      final today = DateTime.now();
                                      // Simplified logic for display
                                      return Text(
                                          'Next Est. Due Date: ${acc.billingCycleDay != null ? DateFormat("MMM dd").format(DateTime(today.year, today.month, acc.billingCycleDay!).add(Duration(days: acc.paymentDueDateDay ?? 0))) : "N/A"}',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey));
                                    })
                                  ],
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context); // Close dialog
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => TransactionsScreen(
                                            initialAccountId: acc.id),
                                      ),
                                    );
                                  },
                                  child: const Text('View Transactions'),
                                ),
                                if (acc.type == AccountType.creditCard)
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(context); // Close details
                                      showDialog(
                                          context: context,
                                          builder: (_) => RecordCCPaymentDialog(
                                              creditCardAccount: acc));
                                    },
                                    child: const Text('Pay Bill',
                                        style: TextStyle(color: Colors.green)),
                                  ),
                                TextButton(
                                  onPressed: () async {
                                    // Delete Logic
                                    final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                                title: const Text(
                                                    'Delete Account?'),
                                                content: const Text(
                                                    'This will remove the account. Existing transactions associated with this account will be kept for your records. This cannot be undone.'),
                                                actions: [
                                                  TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                              ctx, false),
                                                      child:
                                                          const Text('Cancel')),
                                                  TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                              ctx, true),
                                                      child: const Text(
                                                          'Delete',
                                                          style: TextStyle(
                                                              color:
                                                                  Colors.red))),
                                                ]));
                                    if (confirm == true) {
                                      final storage =
                                          ref.read(storageServiceProvider);
                                      // Delete transactions first?
                                      // StorageService currently only has deleteAccount.
                                      // We need to implement deleteAccount with cascade or notify user.
                                      // For now, let's just delete the account reference.
                                      await storage.deleteAccount(acc.id);
                                      final _ = ref.refresh(accountsProvider);
                                      if (context.mounted) {
                                        Navigator.pop(context);
                                      }
                                    }
                                  },
                                  child: const Text('Delete',
                                      style: TextStyle(color: Colors.red)),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context); // Close dialog
                                    showModalBottomSheet(
                                        context: context,
                                        isScrollControlled: true,
                                        builder: (_) =>
                                            AddAccountSheet(account: acc));
                                  },
                                  child: const Text('Edit'),
                                ),
                                TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Close')),
                              ],
                            ));
                  });
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
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

  void _showAddAccountSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const AddAccountSheet(),
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

  String _currency = 'en_US';

  // CC fields
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
      _currency = ref.read(currencyProvider);
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
            // Disable Type change for existing accounts to avoid logic break
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
                      onChanged: (v) => setState(() => _dueDay = int.tryParse(
                          v)), // Storing grace period in dueDay field
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
                      color: Colors.blue.withOpacity(0.1),
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
        // Edit logic
        final acc = widget.account!;
        acc.name = _name;
        // acc.type = _type; // Cannot change type easily without breaking history
        acc.balance = _initialBalance; // Manual correction
        acc.creditLimit = _limit;
        acc.billingCycleDay = _billingDay;
        acc.paymentDueDateDay = _dueDay;
        acc.currency = _currency;

        await storage.saveAccount(acc);
      } else {
        // Create logic
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

      final _ = ref.refresh(accountsProvider); // Refresh list

      if (mounted) Navigator.pop(context);
    }
  }

  Widget _buildAccountItem(BuildContext context, WidgetRef ref, Account acc) {
    double unbilled = 0;
    if (acc.type == AccountType.creditCard && acc.billingCycleDay != null) {
      final now = DateTime.now();
      final cycleStart = BillingHelper.getCycleStart(now, acc.billingCycleDay!);

      final allTxns = ref.watch(transactionsProvider).value ?? [];
      final relevantTxns = allTxns.where((t) =>
          !t.isDeleted &&
          t.accountId == acc.id &&
          DateTime(t.date.year, t.date.month, t.date.day).isAfter(cycleStart));

      for (var t in relevantTxns) {
        if (t.type == TransactionType.expense) unbilled += t.amount;
        if (t.type == TransactionType.income) unbilled -= t.amount;
        if (t.type == TransactionType.transfer && t.accountId == acc.id) {
          unbilled += t.amount;
        }
      }
    }

    return AccountCard(
      account: acc,
      unbilledAmount: unbilled,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TransactionsScreen(accountId: acc.id),
        ),
      ),
    );
  }
}
