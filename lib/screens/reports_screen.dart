import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers.dart';
import '../models/transaction.dart';
import '../models/loan.dart';
import '../widgets/smart_currency_text.dart';
import '../widgets/charts/reports_pie_chart.dart';

import 'transactions_screen.dart';
import '../utils/transaction_filter_utils.dart';
import '../utils/report_utils.dart';
import '../widgets/transaction_filter.dart'; // Needed for TimeRange enum

enum ReportType { spending, income, loan }

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  ReportType _type = ReportType.spending;

  // Filter States
  String? _selectedAccountId;
  String? _selectedLoanId; // Added for Loan Filter
  String _timeFilterMode = '30'; // '30', '90', '365', 'all', 'month', 'year'
  DateTime? _selectedMonth; // For month mode (YYYY, MM, 1)
  int? _selectedYear; // For year mode (YYYY)
  LoanType? _selectedLoanType;
  final Set<String> _excludedCategories = {};

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(transactionsProvider);
    final accountsAsync = ref.watch(accountsProvider);
    final loansAsync = ref.watch(loansProvider);
    final currencyLocale = ref.watch(currencyProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(title: const Text('Financial Reports')),
      body: transactionsAsync.when(
        data: (transactions) {
          return accountsAsync.when(
            data: (accounts) {
              return loansAsync.when(
                data: (loans) {
                  if (transactions.isEmpty) {
                    return const Center(child: Text('No data available.'));
                  }

                  // 1. Prepare available Month/Year options from data
                  final dates = transactions
                      .where((t) => !t.isDeleted)
                      .map((t) => t.date)
                      .toList()
                    ..sort((a, b) => b.compareTo(a));
                  final Set<String> monthsAvailable = {};
                  final Set<int> yearsAvailable = {};

                  for (var d in dates) {
                    monthsAvailable.add(DateFormat('MMMM yyyy')
                        .format(DateTime(d.year, d.month)));
                    yearsAvailable.add(d.year);
                  }

                  if (_selectedYear == null && yearsAvailable.isNotEmpty) {
                    _selectedYear = yearsAvailable.first;
                  }
                  if (_selectedMonth == null && dates.isNotEmpty) {
                    _selectedMonth =
                        DateTime(dates.first.year, dates.first.month);
                  }

                  // 2. Filter Transactions
                  var filtered = TransactionFilterUtils.filter(
                    transactions: transactions,
                    accountId: _selectedAccountId,
                    loanId: _type == ReportType.loan ? _selectedLoanId : null,
                    periodMode: _timeFilterMode,
                    selectedMonth: _selectedMonth,
                    selectedYear: _selectedYear,
                    excludedCategories: _excludedCategories.toList(),
                  );

                  // 3. Aggregate Data
                  Map<String, double> data = {};
                  if (_type == ReportType.spending) {
                    data = ReportUtils.aggregateByCategory(
                        transactions: filtered, type: TransactionType.expense);
                  } else if (_type == ReportType.income) {
                    data = ReportUtils.aggregateByCategory(
                        transactions: filtered, type: TransactionType.income);
                  } else if (_type == ReportType.loan) {
                    data = ReportUtils.aggregateLoanPayments(
                        transactions: filtered);
                  }

                  // Capital Gains Aggregation
                  final categories = ref.watch(categoriesProvider);
                  final gainsByCategory = ReportUtils.aggregateCapitalGains(
                    transactions: filtered,
                    categories: categories,
                    reportType: _type == ReportType.spending
                        ? TransactionType.expense
                        : TransactionType.income,
                  );
                  final double totalGains =
                      gainsByCategory.values.fold(0, (a, b) => a + b);
                  final gainTxns = ReportUtils.getCapitalGainTransactions(
                    transactions: filtered,
                    categories: categories,
                    reportType: _type == ReportType.spending
                        ? TransactionType.expense
                        : TransactionType.income,
                  );

                  final double total =
                      data.values.fold(0, (sum, val) => sum + val);

                  // --- CHART DATA PREPARATION (Top 6 + Others) ---
                  final sortedEntries = data.entries.toList()
                    ..sort((a, b) => b.value.compareTo(a.value));

                  List<MapEntry<String, double>> chartEntries = [];
                  if (sortedEntries.length <= 6) {
                    chartEntries = sortedEntries;
                  } else {
                    chartEntries = sortedEntries.take(6).toList();
                    final rest = sortedEntries.skip(6);
                    double othersSum = rest.fold(0, (sum, e) => sum + e.value);
                    if (othersSum > 0) {
                      chartEntries.add(MapEntry('Others', othersSum));
                    }
                  }

                  return ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            _buildFilterChip('Spending', ReportType.spending),
                            _buildFilterChip('Income', ReportType.income),
                            _buildFilterChip('Loan', ReportType.loan),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 10,
                              children: [
                                SizedBox(
                                  width: 130,
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _timeFilterMode,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                        labelText: 'Period',
                                        contentPadding: EdgeInsets.symmetric(
                                            horizontal: 10),
                                        border: OutlineInputBorder()),
                                    items: const [
                                      DropdownMenuItem(
                                          value: '30',
                                          child: Text('30 Days',
                                              overflow: TextOverflow.ellipsis)),
                                      DropdownMenuItem(
                                          value: '90',
                                          child: Text('90 Days',
                                              overflow: TextOverflow.ellipsis)),
                                      DropdownMenuItem(
                                          value: '365',
                                          child: Text('Last Year',
                                              overflow: TextOverflow.ellipsis)),
                                      DropdownMenuItem(
                                          value: 'month',
                                          child: Text('Month',
                                              overflow: TextOverflow.ellipsis)),
                                      DropdownMenuItem(
                                          value: 'year',
                                          child: Text('Year',
                                              overflow: TextOverflow.ellipsis)),
                                      DropdownMenuItem(
                                          value: 'all',
                                          child: Text('All Time',
                                              overflow: TextOverflow.ellipsis)),
                                    ],
                                    onChanged: (v) =>
                                        setState(() => _timeFilterMode = v!),
                                  ),
                                ),
                                if (_type == ReportType.loan) ...[
                                  SizedBox(
                                    width: 130,
                                    child: DropdownButtonFormField<String?>(
                                      initialValue: _selectedLoanId,
                                      isExpanded: true,
                                      decoration: const InputDecoration(
                                          labelText: 'Loan',
                                          contentPadding: EdgeInsets.symmetric(
                                              horizontal: 10),
                                          border: OutlineInputBorder()),
                                      items: [
                                        const DropdownMenuItem(
                                          value: null,
                                          child: Text('All Loans',
                                              overflow: TextOverflow.ellipsis),
                                        ),
                                        ...loans.map((l) => DropdownMenuItem(
                                              value: l.id,
                                              child: Text(l.name,
                                                  overflow:
                                                      TextOverflow.ellipsis),
                                            ))
                                      ],
                                      onChanged: (val) =>
                                          setState(() => _selectedLoanId = val),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 130,
                                    child: DropdownButtonFormField<LoanType?>(
                                      initialValue: _selectedLoanType,
                                      isExpanded: true,
                                      decoration: const InputDecoration(
                                          labelText: 'Type',
                                          contentPadding: EdgeInsets.symmetric(
                                              horizontal: 10),
                                          border: OutlineInputBorder()),
                                      items: <DropdownMenuItem<LoanType?>>[
                                        const DropdownMenuItem<LoanType?>(
                                            value: null,
                                            child: Text('All',
                                                overflow:
                                                    TextOverflow.ellipsis)),
                                        ...LoanType.values.map((t) =>
                                            DropdownMenuItem<LoanType?>(
                                                value: t,
                                                child: Text(
                                                    t.name.toUpperCase(),
                                                    overflow: TextOverflow
                                                        .ellipsis))),
                                      ],
                                      onChanged: (v) =>
                                          setState(() => _selectedLoanType = v),
                                    ),
                                  ),
                                ] else ...[
                                  SizedBox(
                                    width: 130,
                                    child: DropdownButtonFormField<String?>(
                                      initialValue: _selectedAccountId,
                                      isExpanded: true,
                                      decoration: const InputDecoration(
                                          labelText: 'Account',
                                          contentPadding: EdgeInsets.symmetric(
                                              horizontal: 10),
                                          border: OutlineInputBorder()),
                                      items: <DropdownMenuItem<String?>>[
                                        const DropdownMenuItem<String?>(
                                            value: null,
                                            child: Text('All Accounts',
                                                overflow:
                                                    TextOverflow.ellipsis)),
                                        const DropdownMenuItem<String?>(
                                            value: 'none',
                                            child: Text('Manual (No Account)',
                                                overflow:
                                                    TextOverflow.ellipsis)),
                                        ...accounts.map((a) =>
                                            DropdownMenuItem<String?>(
                                                value: a.id,
                                                child: Text(a.name,
                                                    overflow: TextOverflow
                                                        .ellipsis))),
                                      ],
                                      onChanged: (v) => setState(
                                          () => _selectedAccountId = v),
                                    ),
                                  ),
                                  // Category Exclusion UI
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: ActionChip(
                                      avatar: Icon(Icons.filter_list,
                                          size: 16,
                                          color: _excludedCategories.isEmpty
                                              ? Colors.grey
                                              : Colors.blue),
                                      label: Text(_excludedCategories.isEmpty
                                          ? 'Filter Categories'
                                          : '${_excludedCategories.length} Categories Excluded'),
                                      onPressed: () =>
                                          _showExclusionDialog(transactions),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (_timeFilterMode == 'month')
                              DropdownButtonFormField<String>(
                                initialValue: _selectedMonth != null
                                    ? DateFormat('MMMM yyyy')
                                        .format(_selectedMonth!)
                                    : null,
                                decoration: const InputDecoration(
                                    labelText: 'Select Month',
                                    contentPadding:
                                        EdgeInsets.symmetric(horizontal: 10),
                                    border: OutlineInputBorder()),
                                items: monthsAvailable
                                    .map((m) => DropdownMenuItem(
                                        value: m, child: Text(m)))
                                    .toList(),
                                onChanged: (v) {
                                  if (v != null) {
                                    final parse =
                                        DateFormat('MMMM yyyy').parse(v);
                                    setState(() => _selectedMonth = parse);
                                  }
                                },
                              ),
                            if (_timeFilterMode == 'year')
                              DropdownButtonFormField<int>(
                                initialValue: _selectedYear,
                                decoration: const InputDecoration(
                                    labelText: 'Select Year',
                                    contentPadding:
                                        EdgeInsets.symmetric(horizontal: 10),
                                    border: OutlineInputBorder()),
                                items: yearsAvailable
                                    .map((y) => DropdownMenuItem(
                                        value: y, child: Text(y.toString())))
                                    .toList(),
                                onChanged: (v) =>
                                    setState(() => _selectedYear = v),
                              ),
                          ],
                        ),
                      ),
                      if (gainTxns.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _buildCapitalGainsCard(context, totalGains,
                            gainsByCategory, currencyLocale),
                      ],
                      if (data.isEmpty && _type != ReportType.loan)
                        const Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Center(
                              child: Text('No data for selected criteria.')),
                        )
                      else ...[
                        const SizedBox(height: 16),
                        if (_type == ReportType.loan) ...[
                          Builder(builder: (context) {
                            double emiPaid = 0;
                            double prepaymentPaid = 0;
                            final filteredLoans = loans.where((l) {
                              if (_selectedLoanId != null &&
                                  l.id != _selectedLoanId) {
                                return false;
                              }
                              if (_selectedLoanType != null &&
                                  l.type != _selectedLoanType) {
                                return false;
                              }
                              return true;
                            }).toList();

                            final totalLiability = filteredLoans.fold<double>(
                                0, (sum, l) => sum + l.remainingPrincipal);

                            for (var loan in filteredLoans) {
                              for (var txn in loan.transactions) {
                                bool inRange = false;
                                final now = DateTime.now();
                                if (_timeFilterMode == 'month' &&
                                    _selectedMonth != null) {
                                  inRange =
                                      txn.date.month == _selectedMonth!.month &&
                                          txn.date.year == _selectedMonth!.year;
                                } else if (_timeFilterMode == 'year') {
                                  inRange = txn.date.year == _selectedYear;
                                } else if (_timeFilterMode == '30') {
                                  inRange = txn.date.isAfter(
                                      now.subtract(const Duration(days: 30)));
                                } else if (_timeFilterMode == '90') {
                                  inRange = txn.date.isAfter(
                                      now.subtract(const Duration(days: 90)));
                                } else if (_timeFilterMode == '365') {
                                  inRange = txn.date.isAfter(
                                      now.subtract(const Duration(days: 365)));
                                } else {
                                  inRange = true;
                                }

                                if (inRange) {
                                  if (txn.type == LoanTransactionType.emi) {
                                    emiPaid += txn.amount;
                                  } else if (txn.type ==
                                      LoanTransactionType.prepayment) {
                                    prepaymentPaid += txn.amount;
                                  }
                                }
                              }
                            }

                            return Column(
                              children: [
                                const Text('Total Liability',
                                    style: TextStyle(
                                        color: Colors.grey, fontSize: 12)),
                                SmartCurrencyText(
                                  value: totalLiability,
                                  locale: currencyLocale,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.redAccent),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        children: [
                                          const Text('EMI Paid',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey)),
                                          SmartCurrencyText(
                                            value: emiPaid,
                                            locale: currencyLocale,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blue),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: Column(
                                        children: [
                                          const Text('Prepayment',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey)),
                                          SmartCurrencyText(
                                            value: prepaymentPaid,
                                            locale: currencyLocale,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.orange),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                              ],
                            );
                          }),
                        ],
                        if (data.isNotEmpty) ...[
                          Center(
                            child: Column(
                              children: [
                                Text(
                                    _type == ReportType.loan
                                        ? 'Total Paid'
                                        : 'Total',
                                    style: const TextStyle(
                                        color: Colors.grey, fontSize: 12)),
                                SmartCurrencyText(
                                  value: total,
                                  locale: currencyLocale,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          ReportsPieChart(entries: chartEntries, total: total),
                          const SizedBox(height: 16),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: sortedEntries.length,
                            itemBuilder: (context, index) {
                              final e = sortedEntries[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: index < 6
                                      ? ReportUtils.getChartColor(index)
                                      : Colors.grey,
                                  radius: 8,
                                ),
                                title: Text(e.key),
                                trailing: SmartCurrencyText(
                                  value: e.value,
                                  locale: currencyLocale,
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => TransactionsScreen(
                                        initialCategory: e.key,
                                        initialRange: TimeRange.custom,
                                        initialCustomRange: _getTimeRange(),
                                        initialType:
                                            _type == ReportType.spending
                                                ? TransactionType.expense
                                                : (_type == ReportType.income
                                                    ? TransactionType.income
                                                    : null),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ]
                      ],
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(child: Text('Error: $error')),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text('Error: $error')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }

  void _showExclusionDialog(List<Transaction> transactions) {
    if (transactions.isEmpty) return;

    // Get all unique categories with amounts
    final categoryTotals = <String, double>{};
    for (var t in transactions) {
      categoryTotals[t.category] = (categoryTotals[t.category] ?? 0) + t.amount;
    }

    final categories = categoryTotals.keys.toList()
      ..sort((a, b) => categoryTotals[b]!.compareTo(categoryTotals[a]!));

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Filter Categories'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    final isExcluded = _excludedCategories.contains(category);

                    return CheckboxListTile(
                      title: Text(category),
                      value: !isExcluded, // Checked means INCLUDED
                      onChanged: (bool? value) {
                        setState(() {
                          if (value == true) {
                            _excludedCategories.remove(category);
                          } else {
                            _excludedCategories.add(category);
                          }
                        });
                        // Update main screen as well
                        this.setState(() {});
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _excludedCategories.clear();
                    this.setState(() {});
                    setState(() {});
                  },
                  child: const Text('Reset'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  DateTimeRange _getTimeRange() {
    final now = DateTime.now();
    if (_timeFilterMode == '30') {
      return DateTimeRange(
          start: now.subtract(const Duration(days: 30)), end: now);
    } else if (_timeFilterMode == '90') {
      return DateTimeRange(
          start: now.subtract(const Duration(days: 90)), end: now);
    } else if (_timeFilterMode == '365') {
      return DateTimeRange(
          start: now.subtract(const Duration(days: 365)), end: now);
    } else if (_timeFilterMode == 'month' && _selectedMonth != null) {
      final start = _selectedMonth!;
      final end = DateTime(start.year, start.month + 1, 0); // Last day of month
      return DateTimeRange(start: start, end: end);
    } else if (_timeFilterMode == 'year' && _selectedYear != null) {
      final start = DateTime(_selectedYear!, 1, 1);
      final end = DateTime(_selectedYear!, 12, 31);
      return DateTimeRange(start: start, end: end);
    }
    // Default or 'all'
    return DateTimeRange(start: DateTime(2000), end: now);
  }

  Widget _buildCapitalGainsCard(BuildContext context, double total,
      Map<String, double> breakdown, String locale) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: Colors.blue.withValues(alpha: 0.1),
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.blue.withValues(alpha: 0.3))),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Text(
                  _type == ReportType.income
                      ? 'Capital Gains (Realized)'
                      : 'Capital Losses (Realized)',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.blue[800]),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SmartCurrencyText(
              value: total,
              locale: locale,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[900],
                  ),
            ),
            if (breakdown.isNotEmpty) ...[
              const Divider(height: 24),
              ...breakdown.entries.map((e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(e.key, style: TextStyle(color: Colors.blue[800])),
                        SmartCurrencyText(
                          value: e.value,
                          locale: locale,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, ReportType type) {
    final isSelected = _type == type;
    return FilterChip(
      selected: isSelected,
      label: Text(label),
      onSelected: (bool selected) {
        setState(() {
          _type = type;
        });
      },
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      selectedColor: Theme.of(context).colorScheme.primaryContainer,
      checkmarkColor: Theme.of(context).colorScheme.primary,
    );
  }
}
