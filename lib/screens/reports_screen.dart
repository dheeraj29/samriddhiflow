import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../providers.dart';
import '../models/transaction.dart';
import '../models/loan.dart';
import '../widgets/transaction_filter.dart';
import '../widgets/smart_currency_text.dart';

import 'transactions_screen.dart';
import '../theme/app_theme.dart';
import '../utils/transaction_filter_utils.dart';
import '../utils/report_utils.dart';

enum ReportType { spending, income, loan }

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  ReportType _type = ReportType.spending;
  int touchedIndex = -1;

  // Filter States
  String? _selectedAccountId;
  String? _selectedLoanId; // Added for Loan Filter
  String _timeFilterMode = '30'; // '30', '90', '365', 'all', 'month', 'year'
  DateTime? _selectedMonth; // For month mode (YYYY, MM, 1)
  int? _selectedYear; // For year mode (YYYY)
  LoanType? _selectedLoanType;
  Set<String> _excludedCategories = {};

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
                          SizedBox(
                            height: 250,
                            child: PieChart(
                              PieChartData(
                                sectionsSpace: 2,
                                centerSpaceRadius: 40,
                                pieTouchData: PieTouchData(
                                  touchCallback:
                                      (FlTouchEvent event, pieTouchResponse) {
                                    setState(() {
                                      if (!event.isInterestedForInteractions ||
                                          pieTouchResponse == null ||
                                          pieTouchResponse.touchedSection ==
                                              null) {
                                        touchedIndex = -1;
                                        return;
                                      }
                                      touchedIndex = pieTouchResponse
                                          .touchedSection!.touchedSectionIndex;
                                    });
                                  },
                                ),
                                sections: chartEntries.indexed.map((entry) {
                                  final index = entry.$1;
                                  final e = entry.$2;
                                  final isTouched = index == touchedIndex;
                                  final isOthers = e.key == 'Others';
                                  final fontSize = isTouched ? 16.0 : 12.0;
                                  final radius = isTouched ? 60.0 : 50.0;
                                  final percentage =
                                      total == 0 ? 0 : (e.value / total) * 100;
                                  final isTopSlice =
                                      chartEntries.length <= 6 || index < 6;
                                  final showLabel = isTouched ||
                                      percentage >= 10 ||
                                      (isTopSlice && percentage > 5);

                                  return PieChartSectionData(
                                    value: e.value == 0 ? 0.01 : e.value,
                                    titlePositionPercentageOffset: 1.6,
                                    title: showLabel
                                        ? '${e.key} (${percentage.toStringAsFixed(0)}%)'
                                        : '',
                                    radius: radius,
                                    titleStyle: AppTheme.offlineSafeTextStyle
                                        .copyWith(
                                            fontSize: fontSize,
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface),
                                    color: isOthers
                                        ? Colors.grey
                                        : _getChartColor(index),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
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
                                      ? _getChartColor(index)
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
                                        initialRange: _getTimeRange(),
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
                        ],
                      ]
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => Center(child: Text('Error: $e')),
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

  void _showExclusionDialog(List<Transaction> transactions) {
    // Get unique categories for this view type from the FULL list (before exclusion filter)
    final availableCategories = transactions
        .where((t) =>
            t.type ==
            (_type == ReportType.spending
                ? TransactionType.expense
                : TransactionType.income))
        .map((t) => t.category)
        .toSet()
        .toList();

    // Calculate totals for sorting
    final Map<String, double> categoryTotals = {};
    for (var t in transactions) {
      if ((_type == ReportType.spending && t.type == TransactionType.expense) ||
          (_type == ReportType.income && t.type == TransactionType.income)) {
        categoryTotals[t.category] =
            (categoryTotals[t.category] ?? 0) + t.amount;
      }
    }

    availableCategories.sort((a, b) {
      final totalA = categoryTotals[a] ?? 0;
      final totalB = categoryTotals[b] ?? 0;
      // Descending order (Highest first)
      return totalB.compareTo(totalA);
    });

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Exclude Categories'),
            content: SizedBox(
              width: double.maxFinite,
              child: availableCategories.isEmpty
                  ? const Center(child: Text('No categories found.'))
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: availableCategories.length,
                      itemBuilder: (context, index) {
                        final cat = availableCategories[index];
                        final isExcluded = _excludedCategories.contains(cat);
                        return CheckboxListTile(
                          title: Text(cat),
                          value: !isExcluded, // Value is 'Included'
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _excludedCategories.remove(cat);
                              } else {
                                _excludedCategories.add(cat);
                              }
                            });
                            setDialogState(() {});
                          },
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setState(() => _excludedCategories.clear());
                  Navigator.pop(ctx);
                },
                child: const Text('Reset'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          );
        });
      },
    );
  }

  TimeRange _getTimeRange() {
    switch (_timeFilterMode) {
      case '30':
        return TimeRange.last30Days;
      case '90':
        return TimeRange.all;
      case '365':
        return TimeRange.all;
      case 'month':
        return TimeRange.thisMonth;
      case 'year':
        return TimeRange.all;
      default:
        return TimeRange.all;
    }
  }

  Widget _buildCapitalGainsCard(BuildContext context, double total,
      Map<String, double> breakdown, String locale) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
              color: total >= 0
                  ? Colors.green.withValues(alpha: 0.3)
                  : Colors.red.withValues(alpha: 0.3))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Capital Gains Summary',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: total >= 0 ? Colors.green : Colors.redAccent)),
                SmartCurrencyText(
                  value: total,
                  locale: locale,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: total >= 0 ? Colors.green : Colors.redAccent),
                ),
              ],
            ),
            if (breakdown.length > 1) ...[
              const Divider(),
              ...breakdown.entries.map((e) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(e.key, style: const TextStyle(fontSize: 12)),
                      SmartCurrencyText(
                        value: e.value,
                        locale: locale,
                        style: TextStyle(
                            fontSize: 12,
                            color: e.value >= 0 ? Colors.green : Colors.red),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, ReportType type) {
    final isSelected = _type == type;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (bool selected) {
        setState(() {
          _type = type;
          _selectedAccountId = null;
          _selectedLoanId = null;
          _selectedLoanType = null;
          _excludedCategories = {};
        });
      },
    );
  }

  Color _getChartColor(int index) {
    const List<Color> palette = [
      Color(0xFF4CAF50),
      Color(0xFF2196F3),
      Color(0xFFFFC107),
      Color(0xFFE91E63),
      Color(0xFF9C27B0),
      Color(0xFF00BCD4),
    ];
    return palette[index % palette.length];
  }
}
