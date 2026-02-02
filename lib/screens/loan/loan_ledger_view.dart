import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/loan.dart';

import '../../providers.dart';
import '../../widgets/pure_icons.dart';
import '../../widgets/smart_currency_text.dart';

class LoanLedgerView extends ConsumerStatefulWidget {
  final Loan loan;

  const LoanLedgerView({super.key, required this.loan});

  @override
  ConsumerState<LoanLedgerView> createState() => _LoanLedgerViewState();
}

class _LoanLedgerViewState extends ConsumerState<LoanLedgerView> {
  // Ledger Filter State
  LoanTransactionType? _filterType;
  DateTimeRange? _filterDateRange;
  bool _compactLedger = false;

  @override
  Widget build(BuildContext context) {
    final currencyLocale = ref.watch(currencyProvider);
    final currency = NumberFormat.simpleCurrency(locale: currencyLocale);

    // Create a mutable list for sorting/filtering
    List<LoanTransaction> filteredTxns = widget.loan.transactions.toList();

    if (_filterType != null) {
      filteredTxns = filteredTxns.where((t) => t.type == _filterType).toList();
    }

    if (_filterDateRange != null) {
      filteredTxns = filteredTxns
          .where((t) =>
              t.date.isAfter(_filterDateRange!.start
                  .subtract(const Duration(seconds: 1))) &&
              t.date
                  .isBefore(_filterDateRange!.end.add(const Duration(days: 1))))
          .toList();
    }

    filteredTxns.sort((a, b) => b.date.compareTo(a.date));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Loan Ledger',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Row(
              children: [
                IconButton(
                  icon: PureIcons.icon(
                      _compactLedger
                          ? Icons.format_align_justify
                          : Icons.format_align_center,
                      size: 20,
                      color: Colors.grey),
                  onPressed: () =>
                      setState(() => _compactLedger = !_compactLedger),
                  tooltip: _compactLedger
                      ? 'Switch to Extended Numbers'
                      : 'Switch to Compact Numbers',
                ),
                IconButton(
                  icon: PureIcons.icon(Icons.filter_list,
                      color: _filterType != null
                          ? Theme.of(context).colorScheme.primary
                          : null),
                  onPressed: () => _showFilterTypeDialog(),
                  tooltip: 'Filter by Type',
                ),
                IconButton(
                  icon: PureIcons.icon(Icons.date_range,
                      color: _filterDateRange != null
                          ? Theme.of(context).colorScheme.primary
                          : null),
                  onPressed: () => _showFilterDateDialog(),
                  tooltip: 'Filter by Date',
                ),
                if (_filterType != null || _filterDateRange != null)
                  IconButton(
                    icon: PureIcons.close(color: Colors.red),
                    onPressed: () => setState(() {
                      _filterType = null;
                      _filterDateRange = null;
                    }),
                    tooltip: 'Clear Filters',
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (filteredTxns.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32.0),
            child: Center(
                child: Text('No transactions match the filters.',
                    style: TextStyle(color: Colors.grey))),
          ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filteredTxns.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (context, index) {
            final txn = filteredTxns[index];
            String title = '';
            IconData icon = Icons.payment;
            Color color = Colors.blue;
            String subtitle = '';

            if (txn.type == LoanTransactionType.emi) {
              title = 'EMI Payment';
              icon = Icons.event_note;
              color = Colors.green;
              subtitle =
                  'Prin: ${currency.format(txn.principalComponent)} • Int: ${currency.format(txn.interestComponent)}';
            } else if (txn.type == LoanTransactionType.prepayment) {
              title = 'Prepayment';
              icon = Icons.speed;
              color = Colors.orange;
              subtitle = 'Direct reduction of principal';
            } else if (txn.type == LoanTransactionType.rateChange) {
              title = 'Interest Rate Updated';
              icon = Icons.trending_up;
              color = Colors.purple;
              subtitle = 'New Rate: ${txn.amount}%';
            } else if (txn.type == LoanTransactionType.topup) {
              title = 'Loan Top-up';
              icon = Icons.add_circle_outline;
              color = Colors.teal;
              subtitle = 'Increased principal amount';
            }

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.1),
                child: Icon(icon, color: color, size: 20),
              ),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  if (txn.type != LoanTransactionType.rateChange)
                    SmartCurrencyText(
                        value: txn.amount,
                        locale: currencyLocale,
                        initialCompact: _compactLedger,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      '${DateFormat('MMM dd, yyyy, hh:mm a').format(txn.date)} • $subtitle',
                      style: const TextStyle(fontSize: 12)),
                  const Text('Balance: ',
                      style: TextStyle(fontSize: 11, color: Colors.grey)),
                  SmartCurrencyText(
                    value: txn.resultantPrincipal,
                    locale: currencyLocale,
                    initialCompact: _compactLedger,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (v) async => _handleMenuSelection(v, txn),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red, size: 20),
                        SizedBox(width: 8),
                        Text('Delete'),
                      ],
                    ),
                  )
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  void _showFilterTypeDialog() {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Filter by Type'),
        children: [
          SimpleDialogOption(
            onPressed: () {
              setState(() => _filterType = null);
              Navigator.pop(context);
            },
            child: const Text('All'),
          ),
          ...LoanTransactionType.values.map((type) => SimpleDialogOption(
                onPressed: () {
                  setState(() => _filterType = type);
                  Navigator.pop(context);
                },
                child: Text(type.name.toUpperCase()),
              )),
        ],
      ),
    );
  }

  void _showFilterDateDialog() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2030),
      initialDateRange: _filterDateRange,
    );
    if (range != null) {
      setState(() => _filterDateRange = range);
    }
  }

  Future<void> _handleMenuSelection(String value, LoanTransaction txn) async {
    if (value == 'delete') {
      final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
                title: const Text('Delete Entry?'),
                content: const Text(
                    'Deleting this will attempt to reverse the principal impact, but won\'t perfectly recalculate interest history.\n\nAre you sure?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel')),
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Delete',
                          style: TextStyle(color: Colors.red))),
                ],
              ));

      if (confirm == true) {
        var loan = widget.loan;
        // Reverse Impact
        if (txn.type == LoanTransactionType.emi ||
            txn.type == LoanTransactionType.prepayment) {
          loan.remainingPrincipal += txn.principalComponent;
        } else if (txn.type == LoanTransactionType.topup) {
          loan.remainingPrincipal -= txn.amount;
          loan.totalPrincipal -= txn.amount;
        }

        // Remove
        loan.transactions.removeWhere((t) => t.id == txn.id);

        await ref.read(storageServiceProvider).saveLoan(loan);
        ref.invalidate(loansProvider);
      }
    }
  }
}
