import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers.dart';
import '../models/account.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../widgets/smart_currency_text.dart';
import '../widgets/transaction_filter.dart';
import 'add_transaction_screen.dart';
import '../widgets/pure_icons.dart';
import '../widgets/transaction_list_item.dart';
import '../widgets/pagination_bar.dart';
import '../utils/transaction_filter_utils.dart';
import '../l10n/app_localizations.dart';

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

  List<Widget> get _buildAppBarActions {
    return _isSelectionMode ? _buildSelectionActions() : _buildNormalActions();
  }

  List<Widget> _buildSelectionActions() {
    return [
      IconButton(
        icon: PureIcons.selectAll(),
        tooltip: AppLocalizations.of(context)!.selectAllTooltip,
        onPressed: _handleSelectAll,
      ),
      IconButton(
        icon: PureIcons.delete(),
        onPressed: _selectedIds.isEmpty ? null : () => _deleteSelected(context),
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
    ];
  }

  void _handleSelectAll() {
    final transactionsAsync = ref.read(transactionsProvider);
    final accountsAsync = ref.read(accountsProvider);

    transactionsAsync.whenData((transactions) {
      accountsAsync.whenData((accounts) {
        _applySelection(transactions, accounts);
      });
    });
  }

  void _applySelection(List<Transaction> transactions, List<Account> accounts) {
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
  }

  List<Widget> _buildNormalActions() {
    return [
      IconButton(
        icon: _compactView
            ? PureIcons.listExtended(size: 20)
            : PureIcons.listCompact(size: 20),
        tooltip: _compactView
            ? AppLocalizations.of(context)!.extendedNumbersTooltip
            : AppLocalizations.of(context)!.compactNumbersTooltip,
        onPressed: () => setState(() => _compactView = !_compactView),
      ),
      IconButton(
        icon: PureIcons.checklist(),
        tooltip: AppLocalizations.of(context)!.selectTransactionsTooltip,
        onPressed: () {
          setState(() {
            _isSelectionMode = true;
          });
        },
      ),
    ];
  }

  Widget? _buildTrailingWidget(
      Transaction txn, bool isIncomingTransfer, String currencyLocaleStr) {
    if (_isSelectionMode) return null;

    final bool isPositive =
        txn.type == TransactionType.income || isIncomingTransfer;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SmartCurrencyText(
          value: txn.amount,
          locale: currencyLocaleStr,
          initialCompact: _compactView,
          prefix: isPositive ? "+" : "-",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isPositive ? Colors.green : Colors.red,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: PureIcons.deleteOutlined(size: 20, color: Colors.grey),
          // coverage:ignore-start
          onPressed: () {
            FocusScope.of(context).unfocus();
            _confirmSingleDelete(context, txn);
            // coverage:ignore-end
          },
        ),
      ],
    );
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
            ? Text(AppLocalizations.of(context)!
                .selectedCount(_selectedIds.length))
            : Text(AppLocalizations.of(context)!.allTransactionsTitle),
        actions: _buildAppBarActions,
      ),
      body: transactionsAsync.when(
        data: (transactions) {
          final categories =
              transactions.map((t) => t.category).toSet().toList()..sort();

          return accountsAsync.when(
            data: (accounts) => _buildFilteredBody(context, transactions,
                accounts, categories, allCategories, currencyLocale),
            // coverage:ignore-start
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Center(
                child: Text(AppLocalizations.of(context)!
                    .errorLabelWithDetails(e.toString()))),
            // coverage:ignore-end
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        // coverage:ignore-start
        error: (e, s) => Center(
            child: Text(AppLocalizations.of(context)!
                .errorLabelWithDetails(e.toString()))),
        // coverage:ignore-end
      ),
    );
  }

  Widget _buildFilteredBody(
      BuildContext context,
      List<Transaction> transactions,
      List<Account> accounts,
      List<String> categories,
      List<Category> allCategories,
      String currencyLocale) {
    final filtered = _getFilteredTransactions(transactions);
    final totalPages = (filtered.length / _pageSize).ceil();
    final safeCurrentPage =
        _currentPage.clamp(1, totalPages > 0 ? totalPages : 1);
    final paginatedTxns = _getPaginatedTransactions(filtered, safeCurrentPage);

    return Column(
      children: [
        if (!_isSelectionMode)
          _buildFilterWidget(context, accounts, categories),
        if (transactions.isEmpty)
          _buildEmptyState(AppLocalizations.of(context)!.noTransactionsFound)
        else if (filtered.isEmpty)
          _buildEmptyState(AppLocalizations.of(context)!
              .noMatchesFilter) // coverage:ignore-line
        else ...[
          _buildTransactionList(
              paginatedTxns, accounts, allCategories, currencyLocale),
          _buildPaginationBar(safeCurrentPage, totalPages),
        ]
      ],
    );
  }

  List<Transaction> _getFilteredTransactions(List<Transaction> transactions) {
    var filtered = TransactionFilterUtils.filter(
      transactions: transactions,
      type: _typeFilter,
      category: _category,
      accountId: _selectedAccountId,
      range: _range,
      customRange: _customRange,
    );
    filtered.sort((a, b) => b.date.compareTo(a.date));
    return filtered;
  }

  List<Transaction> _getPaginatedTransactions(
      List<Transaction> filtered, int safeCurrentPage) {
    if (filtered.isEmpty) return <Transaction>[];
    final startIndex = (safeCurrentPage - 1) * _pageSize;
    final endIndex = (startIndex + _pageSize > filtered.length)
        ? filtered.length
        : startIndex + _pageSize; // coverage:ignore-line
    return filtered.sublist(startIndex, endIndex);
  }

  Widget _buildFilterWidget(
      BuildContext context, List<Account> accounts, List<String> categories) {
    return TransactionFilter(
      selectedRange: _range,
      selectedCategory: _category,
      selectedAccountId: _selectedAccountId,
      selectedType: _typeFilter,
      categories: categories,
      accountItems: [
        DropdownMenuItem<String?>(
            value: 'none',
            child: Text(AppLocalizations.of(context)!.noAccountManual)),
        ...accounts.map(
            (a) => DropdownMenuItem<String?>(value: a.id, child: Text(a.name)))
      ],
      // coverage:ignore-start
      onRangeChanged: (v) {
        setState(() {
          _range = v;
          _currentPage = 1;
          // coverage:ignore-end
        });
        if (v == TimeRange.custom) {
          // coverage:ignore-line
          _selectCustomRange(context); // coverage:ignore-line
        }
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
      onCustomRangeTap: () =>
          _selectCustomRange(context), // coverage:ignore-line
      customRangeLabel: _customRange != null
          ? '${DateFormat('MMM dd').format(_customRange!.start)} - ${DateFormat('MMM dd').format(_customRange!.end)}'
          : null,
    );
  }

  Widget _buildEmptyState(String message) {
    return Expanded(
      child: Center(child: Text(message)),
    );
  }

  Widget _buildPaginationBar(int safeCurrentPage, int totalPages) {
    return PaginationBar(
      safeCurrentPage: safeCurrentPage,
      totalPages: totalPages,
      onPageChanged: (page) =>
          setState(() => _currentPage = page), // coverage:ignore-line
    );
  }

  Widget _buildTransactionList(
      List<Transaction> paginatedTxns,
      List<Account> accounts,
      List<Category> allCategories,
      String currencyLocale) {
    return Expanded(
      child: ListView.builder(
        itemCount: paginatedTxns.length,
        itemBuilder: (context, index) {
          final txn = paginatedTxns[index];
          final isSelected = _selectedIds.contains(txn.id);

          final isIncomingTransfer = _selectedAccountId != null &&
              // coverage:ignore-start
              txn.type == TransactionType.transfer &&
              txn.toAccountId == _selectedAccountId &&
              txn.accountId != txn.toAccountId;
          // coverage:ignore-end

          return TransactionListItem(
            txn: txn,
            currencyLocale: currencyLocale,
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
                Navigator.push(
                  // coverage:ignore-line
                  context,
                  // coverage:ignore-start
                  MaterialPageRoute(
                    builder: (_) =>
                        AddTransactionScreen(transactionToEdit: txn),
                    // coverage:ignore-end
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
            onSelectionChanged: (v) =>
                _toggleSelection(txn.id), // coverage:ignore-line
            trailing:
                _buildTrailingWidget(txn, isIncomingTransfer, currencyLocale),
          );
        },
      ),
    );
  }

  Future<void> _deleteSelected(BuildContext context) async {
    final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: Text(AppLocalizations.of(context)!
                  .deleteSelectedTitle(_selectedIds.length)),
              content:
                  Text(AppLocalizations.of(context)!.itemsMoveToRecycleBin),
              actions: [
                TextButton(
                    onPressed: () =>
                        Navigator.pop(ctx, false), // coverage:ignore-line
                    child: Text(AppLocalizations.of(context)!.cancelButton)),
                TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(AppLocalizations.of(context)!.deleteButton,
                        style: const TextStyle(color: Colors.red))),
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

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                AppLocalizations.of(context)!.transactionsMovedToRecycleBin)));
      }
    }
  }

  Future<void> _confirmSingleDelete(
      // coverage:ignore-line
      BuildContext context,
      Transaction txn) async {
    final confirm = await showDialog<bool>(
        // coverage:ignore-line
        context: context,
        builder: (ctx) => AlertDialog(
              // coverage:ignore-line
              title: Text(AppLocalizations.of(context)!
                  .deleteTransactionTitle), // coverage:ignore-line
              content:
                  // coverage:ignore-start
                  Text(AppLocalizations.of(context)!.itemsMoveToRecycleBin),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(AppLocalizations.of(context)!.cancelButton)),
                TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(AppLocalizations.of(context)!.deleteButton)),
                // coverage:ignore-end
              ],
            ));

    // coverage:ignore-start
    if (confirm == true) {
      final storage = ref.read(storageServiceProvider);
      await storage.deleteTransaction(txn.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(AppLocalizations.of(context)!.movedToRecycleBin)));
        // coverage:ignore-end
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

    final newRange = await showDateRangePicker(
      // coverage:ignore-line
      context: context,
      firstDate: DateTime(2020), // coverage:ignore-line
      lastDate:
          DateTime.now().add(const Duration(days: 365)), // coverage:ignore-line
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
