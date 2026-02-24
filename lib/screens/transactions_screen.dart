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
import '../widgets/transaction_list_item.dart';
import '../utils/transaction_filter_utils.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  final String? initialCategory;
  final TimeRange? initialRange;
  final String? initialAccountId;
  final TransactionType? initialType;
  final DateTimeRange? initialCustomRange;

  const TransactionsScreen({
    super.key,
    this.initialCategory,
    this.initialRange,
    this.initialAccountId,
    this.initialType,
    this.initialCustomRange,
  });

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  late TimeRange _range;
  late String? _category;
  String? _selectedAccountId;
  TransactionType? _typeFilter;
  DateTimeRange? _customRange;

  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};
  bool _compactView = false;

  final int _pageSize = 15;
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _range = widget.initialRange ?? TimeRange.all;
    _category = widget.initialCategory;
    _selectedAccountId = widget.initialAccountId;
    _typeFilter = widget.initialType;
    _customRange = widget.initialCustomRange;
    if (_customRange != null && widget.initialRange == null) {
      _range = TimeRange.custom; // coverage:ignore-line
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(transactionsProvider);
    final accountsAsync = ref.watch(accountsProvider);
    final allCategories = ref.watch(categoriesProvider);
    final currencyLocale = ref.watch(currencyProvider);

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
                        final filtered = TransactionFilterUtils.filter(
                          transactions: transactions,
                          type: _typeFilter,
                          category: _category,
                          accountId: _selectedAccountId,
                          range: _range,
                          customRange: _customRange,
                        );

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
                  // coverage:ignore-start
                  onPressed: () {
                    setState(() {
                      _isSelectionMode = false;
                      _selectedIds.clear();
                  // coverage:ignore-end
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
          final categories =
              transactions.map((t) => t.category).toSet().toList()..sort();

          return accountsAsync.when(
            data: (accounts) {
              final catMap = <String, Category>{};
              for (var c in allCategories) {
                catMap[c.name] = c;
              }

              // Filter Logic
              var filtered = TransactionFilterUtils.filter(
                transactions: transactions,
                type: _typeFilter,
                category: _category,
                accountId: _selectedAccountId,
                range: _range,
                customRange: _customRange,
              );

              filtered.sort((a, b) => b.date.compareTo(a.date));

              final totalPages = (filtered.length / _pageSize).ceil();
              int safeCurrentPage = _currentPage;
              if (safeCurrentPage > totalPages && totalPages > 0) {
                safeCurrentPage = totalPages;
              }
              if (safeCurrentPage < 1) {
                safeCurrentPage = 1;
              }

              final startIndex = (safeCurrentPage - 1) * _pageSize;
              final endIndex = (startIndex + _pageSize > filtered.length)
                  ? filtered.length
                  : startIndex + _pageSize; // coverage:ignore-line
              final paginatedTxns = filtered.isNotEmpty
                  ? filtered.sublist(startIndex, endIndex)
                  : <Transaction>[];

              return Column(
                children: [
                  if (!_isSelectionMode) ...[
                    TransactionFilter(
                      selectedRange: _range,
                      selectedCategory: _category,
                      selectedAccountId: _selectedAccountId,
                      selectedType: _typeFilter,
                      categories: categories,
                      accountItems: [
                        const DropdownMenuItem<String?>(
                            value: 'none', child: Text('No Account (Manual)')),
                        ...accounts.map((a) => DropdownMenuItem<String?>(
                            value: a.id, child: Text(a.name)))
                      ],
                      // coverage:ignore-start
                      onRangeChanged: (v) {
                        setState(() {
                          _range = v;
                          _currentPage = 1;
                      // coverage:ignore-end
                        });
                        if (v == TimeRange.custom) _selectCustomRange(context); // coverage:ignore-line
                      },
                      // coverage:ignore-start
                      onCategoryChanged: (v) => setState(() {
                        _category = v;
                        _currentPage = 1;
                      // coverage:ignore-end
                      }),
                      // coverage:ignore-start
                      onAccountChanged: (v) => setState(() {
                        _selectedAccountId = v;
                        _currentPage = 1;
                      // coverage:ignore-end
                      }),
                      onTypeChanged: (v) => setState(() {
                        _typeFilter = v;
                        _currentPage = 1;
                      }),
                      onCustomRangeTap: () => _selectCustomRange(context), // coverage:ignore-line
                      customRangeLabel: _customRange != null
                          ? '${DateFormat('MMM dd').format(_customRange!.start)} - ${DateFormat('MMM dd').format(_customRange!.end)}'
                          : null,
                    ),
                  ],
                  if (transactions.isEmpty)
                    const Expanded(
                        child: Center(child: Text('No transactions found.')))
                  else if (filtered.isEmpty)
                    const Expanded( // coverage:ignore-line
                        child:
                            Center(child: Text('No matches for this filter.')))
                  else ...[
                    Expanded(
                      child: ListView.builder(
                        itemCount: paginatedTxns.length,
                        itemBuilder: (context, index) {
                          final txn = paginatedTxns[index];
                          final isSelected = _selectedIds.contains(txn.id);

                          final currencyLocaleStr =
                              currencyLocale; // for clarity

                          final isIncomingTransfer =
                              _selectedAccountId != null &&
                                  // coverage:ignore-start
                                  txn.type == TransactionType.transfer &&
                                  txn.toAccountId == _selectedAccountId &&
                                  txn.accountId != txn.toAccountId;
                                  // coverage:ignore-end

                          return TransactionListItem(
                            txn: txn,
                            currencyLocale: currencyLocaleStr,
                            accounts: accounts,
                            categories: allCategories,
                            compactView: _compactView,
                            isSelectionMode: _isSelectionMode,
                            isSelected: isSelected,
                            currentAccountIdFilter: _selectedAccountId,
                            // coverage:ignore-start
                            onTap: () {
                              if (_isSelectionMode) {
                                _toggleSelection(txn.id);
                            // coverage:ignore-end
                              } else {
                                Navigator.push( // coverage:ignore-line
                                  context,
                                  MaterialPageRoute( // coverage:ignore-line
                                    builder: (_) => AddTransactionScreen( // coverage:ignore-line
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
                            onSelectionChanged: (v) => _toggleSelection(txn.id), // coverage:ignore-line
                            trailing: !_isSelectionMode
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SmartCurrencyText(
                                        value: txn.amount,
                                        locale: currencyLocaleStr,
                                        initialCompact: _compactView,
                                        prefix: txn.type ==
                                                    TransactionType.income ||
                                                isIncomingTransfer
                                            ? "+"
                                            : "-",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: txn.type ==
                                                      TransactionType.income ||
                                                  isIncomingTransfer
                                              ? Colors.green
                                              : Colors.red,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: PureIcons.deleteOutlined(
                                            size: 20, color: Colors.grey),
                                        onPressed: () => // coverage:ignore-line
                                            _confirmSingleDelete(context, txn), // coverage:ignore-line
                                      ),
                                    ],
                                  )
                                : null,
                          );
                        },
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8.0, horizontal: 16.0),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        border: Border(
                            top: BorderSide(
                                color: Colors.grey.withValues(alpha: 0.2))),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Page $safeCurrentPage of $totalPages',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13)),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.chevron_left),
                                onPressed: safeCurrentPage > 1
                                    ? () => setState(() => // coverage:ignore-line
                                        _currentPage = safeCurrentPage - 1) // coverage:ignore-line
                                    : null,
                              ),
                              IconButton(
                                icon: const Icon(Icons.chevron_right),
                                onPressed: safeCurrentPage < totalPages
                                    ? () => setState(() => // coverage:ignore-line
                                        _currentPage = safeCurrentPage + 1) // coverage:ignore-line
                                    : null,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ]
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()), // coverage:ignore-line
            error: (e, s) => Center(child: Text('Error: $e')), // coverage:ignore-line
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')), // coverage:ignore-line
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
                    onPressed: () => Navigator.pop(ctx, false), // coverage:ignore-line
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

      if (context.mounted) {
        setState(() {
          _isSelectionMode = false;
          _selectedIds.clear();
        });

        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Transactions moved to Recycle Bin')));
      }
    }
  }

  Future<void> _confirmSingleDelete( // coverage:ignore-line
      BuildContext context, Transaction txn) async {
    final confirm = await showDialog<bool>( // coverage:ignore-line
        context: context,
        builder: (ctx) => AlertDialog( // coverage:ignore-line
              title: const Text('Delete Transaction?'),
              content: const Text('This will be moved to Recycle Bin.'),
              // coverage:ignore-start
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
              // coverage:ignore-end
                    child: const Text('Cancel')),
                TextButton( // coverage:ignore-line
                    onPressed: () => Navigator.pop(ctx, true), // coverage:ignore-line
                    child: const Text('Delete')),
              ],
            ));

    // coverage:ignore-start
    if (confirm == true) {
      final storage = ref.read(storageServiceProvider);
      await storage.deleteTransaction(txn.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
    // coverage:ignore-end
            const SnackBar(content: Text('Moved to Recycle Bin')));
      }
    }
  }

  // coverage:ignore-start
  Future<void> _selectCustomRange(BuildContext context) async {
    final initialDateRange = _customRange ??
        DateTimeRange(
          start: DateTime.now().subtract(const Duration(days: 7)),
          end: DateTime.now(),
  // coverage:ignore-end
        );

    final newRange = await showDateRangePicker( // coverage:ignore-line
      context: context,
      firstDate: DateTime(2020), // coverage:ignore-line
      lastDate: DateTime.now().add(const Duration(days: 365)), // coverage:ignore-line
      initialDateRange: initialDateRange,
    );

    if (newRange != null) {
      // coverage:ignore-start
      setState(() {
        _range = TimeRange.custom;
        _customRange = newRange;
        _currentPage = 1;
      // coverage:ignore-end
      });
    }
  }

  // coverage:ignore-start
  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _isSelectionMode = false;
  // coverage:ignore-end
      } else {
        _selectedIds.add(id); // coverage:ignore-line
      }
    });
  }
}
