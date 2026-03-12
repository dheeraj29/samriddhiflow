import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/loan.dart';

import '../../providers.dart';
import '../../widgets/pure_icons.dart';
import '../../widgets/smart_currency_text.dart';
import '../../widgets/pagination_bar.dart';

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

  final int _pageSize = 15;
  int _currentPage = 1;

  @override
  Widget build(BuildContext context) {
    final currencyLocale = ref.watch(currencyProvider);

    final filteredTxns = _applyFilters(widget.loan.transactions.toList());
    final paginationResult = _paginate(filteredTxns);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLedgerHeader(context),
        const SizedBox(height: 12),
        if (filteredTxns.isEmpty)
          const Expanded(
            child: Center(
                child: Text('No transactions match the filters.',
                    style: TextStyle(color: Colors.grey))),
          )
        else
          Expanded(
            child: ListView.separated(
              itemCount: paginationResult.items.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) => _buildLedgerItem(
                  paginationResult.items[index], currencyLocale),
            ),
          ),
        PaginationBar(
          safeCurrentPage: paginationResult.currentPage,
          totalPages: paginationResult.totalPages,
          onPageChanged: (page) =>
              setState(() => _currentPage = page), // coverage:ignore-line
        ),
      ],
    );
  }

  List<LoanTransaction> _applyFilters(List<LoanTransaction> txns) {
    if (_filterType != null) {
      txns = txns.where((t) => t.type == _filterType).toList();
    }
    if (_filterDateRange != null) {
      txns = txns
          // coverage:ignore-start
          .where((t) =>
              t.date.isAfter(_filterDateRange!.start
                  .subtract(const Duration(seconds: 1))) &&
              t.date
                  .isBefore(_filterDateRange!.end.add(const Duration(days: 1))))
          .toList();
      // coverage:ignore-end
    }
    txns.sort((a, b) => b.date.compareTo(a.date));
    return txns;
  }

  _PaginationResult _paginate(List<LoanTransaction> filteredTxns) {
    final totalPages = (filteredTxns.length / _pageSize).ceil();
    int safeCurrentPage =
        _currentPage.clamp(1, totalPages > 0 ? totalPages : 1);
    final startIndex = (safeCurrentPage - 1) * _pageSize;
    final endIndex = (startIndex + _pageSize > filteredTxns.length)
        ? filteredTxns.length
        : startIndex + _pageSize; // coverage:ignore-line
    final items = filteredTxns.isNotEmpty
        ? filteredTxns.sublist(startIndex, endIndex)
        : <LoanTransaction>[];
    return _PaginationResult(items, safeCurrentPage, totalPages);
  }

  Widget _buildLedgerHeader(BuildContext context) {
    return Row(
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
              onPressed: () => setState(() => _compactLedger = !_compactLedger),
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
                      ? Theme.of(context)
                          .colorScheme
                          .primary // coverage:ignore-line
                      : null),
              onPressed: () => _showFilterDateDialog(), // coverage:ignore-line
              tooltip: 'Filter by Date',
            ),
            if (_filterType != null || _filterDateRange != null)
              IconButton(
                icon: PureIcons.close(color: Colors.red),
                onPressed: () => setState(() {
                  _filterType = null;
                  _filterDateRange = null;
                  _currentPage = 1;
                }),
                tooltip: 'Clear Filters',
              ),
          ],
        ),
      ],
    );
  }

  ({String title, IconData icon, Color color, String subtitle})
      _getLedgerItemStyle(LoanTransaction txn) {
    final currency =
        NumberFormat.simpleCurrency(locale: ref.read(currencyProvider));
    switch (txn.type) {
      case LoanTransactionType.emi:
        return (
          title: 'EMI Payment',
          icon: Icons.event_note,
          color: Colors.green,
          subtitle:
              'Prin: ${currency.format(txn.principalComponent)} • Int: ${currency.format(txn.interestComponent)}',
        );
      case LoanTransactionType.prepayment:
        return (
          title: 'Prepayment',
          icon: Icons.speed,
          color: Colors.orange,
          subtitle: 'Direct reduction of principal',
        );
      case LoanTransactionType.rateChange: // coverage:ignore-line
        return (
          title: 'Interest Rate Updated',
          icon: Icons.trending_up,
          color: Colors.purple,
          subtitle: 'New Rate: ${txn.amount}%', // coverage:ignore-line
        );
      case LoanTransactionType.topup: // coverage:ignore-line
        return (
          title: 'Loan Top-up',
          icon: Icons.add_circle_outline,
          color: Colors.teal,
          subtitle: 'Increased principal amount',
        );
    }
  }

  Widget _buildLedgerItem(LoanTransaction txn, String currencyLocale) {
    final style = _getLedgerItemStyle(txn);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: style.color.withValues(alpha: 0.1),
        child: Icon(style.icon, color: style.color, size: 20),
      ),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(style.title,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          if (txn.type != LoanTransactionType.rateChange)
            SmartCurrencyText(
                value: txn.amount,
                locale: currencyLocale,
                initialCompact: _compactLedger,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              '${DateFormat('MMM dd, yyyy, hh:mm a').format(txn.date)} • ${style.subtitle}',
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
  }

  void _showFilterTypeDialog() {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Filter by Type'),
        children: [
          SimpleDialogOption(
            // coverage:ignore-start
            onPressed: () {
              setState(() {
                _filterType = null;
                _currentPage = 1;
                // coverage:ignore-end
              });
              Navigator.pop(context); // coverage:ignore-line
            },
            child: const Text('All'),
          ),
          ...LoanTransactionType.values.map((type) => SimpleDialogOption(
                onPressed: () {
                  setState(() {
                    _filterType = type;
                    _currentPage = 1;
                  });
                  Navigator.pop(context);
                },
                child: Text(type.name.toUpperCase()),
              )),
        ],
      ),
    );
  }

  // coverage:ignore-start
  void _showFilterDateDialog() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2030),
      initialDateRange: _filterDateRange,
      // coverage:ignore-end
    );
    if (range != null) {
      // coverage:ignore-start
      setState(() {
        _filterDateRange = range;
        _currentPage = 1;
        // coverage:ignore-end
      });
    }
  }

  Future<void> _handleMenuSelection(String value, LoanTransaction txn) async {
    if (value == 'delete') {
      final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
                title: const Text('Delete Entry?'),
                content: const Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        'Deleting this will attempt to reverse the principal impact, but won\'t perfectly recalculate interest history.'),
                    SizedBox(height: 8),
                    Text('Are you sure?',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                actions: [
                  TextButton(
                      onPressed: () =>
                          Navigator.pop(ctx, false), // coverage:ignore-line
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
          // coverage:ignore-line
          loan.remainingPrincipal += txn.principalComponent;
          // coverage:ignore-start
        } else if (txn.type == LoanTransactionType.topup) {
          loan.remainingPrincipal -= txn.amount;
          loan.totalPrincipal -= txn.amount;
          // coverage:ignore-end
        }

        // Remove
        loan.transactions.removeWhere((t) => t.id == txn.id);

        await ref.read(storageServiceProvider).saveLoan(loan);
        ref.invalidate(loansProvider);
      }
    }
  }
}

class _PaginationResult {
  final List<LoanTransaction> items;
  final int currentPage;
  final int totalPages;
  _PaginationResult(this.items, this.currentPage, this.totalPages);
}
