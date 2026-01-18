import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../widgets/smart_currency_text.dart';
import '../widgets/transaction_filter.dart';
import 'add_transaction_screen.dart';
import '../widgets/pure_icons.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  final String? initialCategory;
  final TimeRange? initialRange;
  final String? initialAccountId;
  const TransactionsScreen(
      {super.key,
      this.initialCategory,
      this.initialRange,
      this.initialAccountId});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  late TimeRange _range;
  late String? _category;
  String? _selectedAccountId;
  DateTimeRange? _customRange;

  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};
  bool _compactView = false;

  @override
  void initState() {
    super.initState();
    _range = widget.initialRange ?? TimeRange.all;
    _category = widget.initialCategory;
    _selectedAccountId = widget.initialAccountId;
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(transactionsProvider);
    final accountsAsync = ref.watch(accountsProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: _isSelectionMode
            ? Text('${_selectedIds.length} Selected')
            : const Text('All Transactions'),
        actions: _isSelectionMode
            ? [
                // Select All Button
                IconButton(
                  icon: PureIcons.selectAll(),
                  tooltip: 'Select All (Filtered)',
                  onPressed: () {
                    // We need the filtered list here
                    // Since build is called, we can compute it or use the data from AsyncValue
                    transactionsAsync.whenData((transactions) {
                      accountsAsync.whenData((accounts) {
                        var filtered = transactions.toList();
                        if (_category != null) {
                          filtered = filtered
                              .where((t) => t.category == _category)
                              .toList();
                        }
                        if (_selectedAccountId != null) {
                          if (_selectedAccountId == 'none') {
                            filtered = filtered
                                .where((t) => t.accountId == null)
                                .toList();
                          } else {
                            filtered = filtered
                                .where((t) => t.accountId == _selectedAccountId)
                                .toList();
                          }
                        }

                        final now = DateTime.now();
                        if (_range == TimeRange.last30Days) {
                          final start = now.subtract(const Duration(days: 30));
                          filtered = filtered
                              .where((t) => t.date.isAfter(start))
                              .toList();
                        } else if (_range == TimeRange.thisMonth) {
                          final start = DateTime(now.year, now.month, 1);
                          filtered = filtered
                              .where((t) =>
                                  t.date.isAfter(start) ||
                                  t.date.isAtSameMomentAs(start))
                              .toList();
                        } else if (_range == TimeRange.lastMonth) {
                          final start = DateTime(now.year, now.month - 1, 1);
                          final end = DateTime(now.year, now.month, 0);
                          filtered = filtered
                              .where((t) =>
                                  t.date.isAfter(start) && t.date.isBefore(end))
                              .toList();
                        } else if (_range == TimeRange.custom &&
                            _customRange != null) {
                          final start = _customRange!.start;
                          final end = _customRange!.end
                              .add(const Duration(days: 1))
                              .subtract(const Duration(milliseconds: 1));
                          filtered = filtered
                              .where((t) =>
                                  t.date.isAfter(start) && t.date.isBefore(end))
                              .toList();
                        }

                        final filteredIds = filtered.map((t) => t.id).toSet();
                        setState(() {
                          if (_selectedIds.containsAll(filteredIds)) {
                            _selectedIds.removeAll(filteredIds);
                            if (_selectedIds.isEmpty) _isSelectionMode = false;
                          } else {
                            _selectedIds.addAll(filteredIds);
                          }
                        });
                      });
                    });
                  },
                ),
                IconButton(
                  icon: PureIcons.delete(),
                  onPressed: _selectedIds.isEmpty
                      ? null
                      : () => _deleteSelected(context),
                ),
                IconButton(
                  icon: PureIcons.close(),
                  onPressed: () {
                    setState(() {
                      _isSelectionMode = false;
                      _selectedIds.clear();
                    });
                  },
                ),
              ]
            : [
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
                  icon: PureIcons.checklist(),
                  tooltip: 'Select Transactions',
                  onPressed: () {
                    setState(() {
                      _isSelectionMode = true;
                    });
                  },
                ),
              ],
      ),
      body: transactionsAsync.when(
        data: (transactions) {
          return accountsAsync.when(
            data: (accounts) {
              if (transactions.isEmpty) {
                return const Center(child: Text('No transactions found.'));
              }

              // Unique categories for filter
              final categories =
                  transactions.map((t) => t.category).toSet().toList()..sort();

              // Filter Logic
              var filtered = transactions.toList();
              if (_category != null) {
                filtered =
                    filtered.where((t) => t.category == _category).toList();
              }
              if (_selectedAccountId != null) {
                filtered = filtered
                    .where((t) => t.accountId == _selectedAccountId)
                    .toList();
              }

              final now = DateTime.now();
              if (_range == TimeRange.last30Days) {
                final start = now.subtract(const Duration(days: 30));
                filtered =
                    filtered.where((t) => t.date.isAfter(start)).toList();
              } else if (_range == TimeRange.thisMonth) {
                final start = DateTime(now.year, now.month, 1);
                filtered = filtered
                    .where((t) =>
                        t.date.isAfter(start) || t.date.isAtSameMomentAs(start))
                    .toList();
              } else if (_range == TimeRange.lastMonth) {
                final start = DateTime(now.year, now.month - 1, 1);
                final end = DateTime(now.year, now.month, 0);
                filtered = filtered
                    .where((t) => t.date.isAfter(start) && t.date.isBefore(end))
                    .toList();
              } else if (_range == TimeRange.custom && _customRange != null) {
                final start = _customRange!.start;
                final end = _customRange!.end
                    .add(const Duration(days: 1))
                    .subtract(const Duration(milliseconds: 1));
                filtered = filtered
                    .where((t) => t.date.isAfter(start) && t.date.isBefore(end))
                    .toList();
              }

              filtered.sort((a, b) => b.date.compareTo(a.date));

              return Column(
                children: [
                  if (!_isSelectionMode) ...[
                    TransactionFilter(
                      selectedRange: _range,
                      selectedCategory: _category,
                      selectedAccountId: _selectedAccountId,
                      categories: categories,
                      accountItems: [
                        const DropdownMenuItem<String?>(
                            value: 'none', child: Text('No Account (Manual)')),
                        ...accounts.map((a) => DropdownMenuItem<String?>(
                            value: a.id, child: Text(a.name)))
                      ],
                      onRangeChanged: (v) {
                        setState(() => _range = v);
                        if (v == TimeRange.custom) _selectCustomRange(context);
                      },
                      onCategoryChanged: (v) => setState(() => _category = v),
                      onAccountChanged: (v) =>
                          setState(() => _selectedAccountId = v),
                      onCustomRangeTap: () => _selectCustomRange(context),
                      customRangeLabel: _customRange != null
                          ? '${DateFormat('MMM dd').format(_customRange!.start)} - ${DateFormat('MMM dd').format(_customRange!.end)}'
                          : null,
                    ),
                  ],
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final txn = filtered[index];
                        final isSelected = _selectedIds.contains(txn.id);

                        final categories = ref.watch(categoriesProvider);
                        final catObj = categories.firstWhere(
                            (c) => c.name == txn.category,
                            orElse: () => categories.first);
                        final isCapitalGain =
                            catObj.tag == CategoryTag.capitalGain;

                        return ListTile(
                          selected: isSelected,
                          onTap: () {
                            if (_isSelectionMode) {
                              setState(() {
                                if (isSelected) {
                                  _selectedIds.remove(txn.id);
                                  if (_selectedIds.isEmpty) {
                                    _isSelectionMode = false;
                                  }
                                } else {
                                  _selectedIds.add(txn.id);
                                }
                              });
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AddTransactionScreen(
                                      transactionToEdit: txn),
                                ),
                              );
                            }
                          },
                          onLongPress: () {
                            if (!_isSelectionMode) {
                              setState(() {
                                _isSelectionMode = true;
                                _selectedIds.add(txn.id);
                              });
                            }
                          },
                          leading: _isSelectionMode
                              ? Checkbox(
                                  value: _selectedIds.contains(txn.id),
                                  onChanged: (v) => _toggleSelection(txn.id),
                                )
                              : CircleAvatar(
                                  backgroundColor: txn.type ==
                                          TransactionType.income
                                      ? Colors.green.withOpacity(0.1)
                                      : (txn.type == TransactionType.transfer
                                          ? Colors.blue.withOpacity(0.1)
                                          : Colors.red.withOpacity(0.1)),
                                  child: txn.type == TransactionType.income
                                      ? PureIcons.income(size: 18)
                                      : (txn.type == TransactionType.transfer
                                          ? PureIcons.transfer(size: 18)
                                          : PureIcons.expense(size: 18)),
                                ),
                          title: Text(txn.title,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${DateFormat('MMM dd, yyyy, hh:mm a').format(txn.date)} • ${txn.category}${txn.accountId == null ? ' • Manual' : ''}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              if (isCapitalGain &&
                                  (txn.gainAmount != null ||
                                      txn.holdingTenureMonths != null))
                                Padding(
                                  padding: const EdgeInsets.only(top: 2.0),
                                  child: Row(
                                    children: [
                                      if (txn.gainAmount != null) ...[
                                        Text(
                                          '${txn.gainAmount! >= 0 ? "Profit" : "Loss"}: ',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: txn.gainAmount! >= 0
                                                ? Colors.green
                                                : Colors.redAccent,
                                          ),
                                        ),
                                        SmartCurrencyText(
                                          value: txn.gainAmount!.abs(),
                                          locale: ref.read(currencyProvider),
                                          initialCompact: _compactView,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: txn.gainAmount! >= 0
                                                ? Colors.green
                                                : Colors.redAccent,
                                          ),
                                        ),
                                      ] else if (isCapitalGain) ...[
                                        const Text(
                                          'Profit: ',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        SmartCurrencyText(
                                          value: 0,
                                          locale: ref.read(currencyProvider),
                                          initialCompact: _compactView,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                      if (txn.gainAmount != null &&
                                          txn.holdingTenureMonths != null)
                                        const Text(' • ',
                                            style: TextStyle(fontSize: 11)),
                                      if (txn.holdingTenureMonths != null)
                                        Text(
                                          'Held: ${_formatTenure(txn.holdingTenureMonths!)}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SmartCurrencyText(
                                value: txn.amount,
                                locale: ref.watch(currencyProvider),
                                initialCompact: _compactView,
                                prefix: txn.type == TransactionType.income
                                    ? "+"
                                    : "-",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: txn.type == TransactionType.income
                                      ? Colors.green
                                      : Colors.red,
                                ),
                              ),
                              if (!_isSelectionMode) ...[
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: PureIcons.deleteOutlined(
                                      size: 20, color: Colors.grey),
                                  onPressed: () =>
                                      _confirmSingleDelete(context, txn),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Center(child: Text('Error: $e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Future<void> _deleteSelected(BuildContext context) async {
    final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: Text('Delete ${_selectedIds.length} Transactions?'),
              content: const Text('Items will be moved to Recycle Bin.'),
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
      final storage = ref.read(storageServiceProvider);
      for (final id in _selectedIds) {
        await storage.deleteTransaction(id);
      }

      setState(() {
        _isSelectionMode = false;
        _selectedIds.clear();
        final _ = ref.refresh(transactionsProvider);
        final __ = ref.refresh(accountsProvider);
      });

      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transactions moved to Recycle Bin')));
    }
  }

  Future<void> _confirmSingleDelete(
      BuildContext context, Transaction txn) async {
    final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('Delete Transaction?'),
              content: const Text('This will be moved to Recycle Bin.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel')),
                TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Delete')),
              ],
            ));

    if (confirm == true) {
      final storage = ref.read(storageServiceProvider);
      await storage.deleteTransaction(txn.id);
      final _ = ref.refresh(transactionsProvider);
      final __ = ref.refresh(accountsProvider);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Moved to Recycle Bin')));
    }
  }

  Future<void> _selectCustomRange(BuildContext context) async {
    final initialDateRange = _customRange ??
        DateTimeRange(
          start: DateTime.now().subtract(const Duration(days: 7)),
          end: DateTime.now(),
        );

    final newRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: initialDateRange,
    );

    if (newRange != null) {
      setState(() {
        _range = TimeRange.custom;
        _customRange = newRange;
      });
    }
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedIds.add(id);
      }
    });
  }

  String _formatTenure(int months) {
    if (months < 12) return '$months mos';
    final years = months ~/ 12;
    final remainingMonths = months % 12;
    if (remainingMonths == 0) return '$years ${years == 1 ? "yr" : "yrs"}';
    return '$years ${years == 1 ? "yr" : "yrs"} $remainingMonths ${remainingMonths == 1 ? "mo" : "mos"}';
  }
}
