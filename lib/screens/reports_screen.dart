import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../providers.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../models/loan.dart';
import '../widgets/transaction_filter.dart';
import '../widgets/smart_currency_text.dart';

import 'transactions_screen.dart';
import '../theme/app_theme.dart';

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
                  var filtered =
                      transactions.where((t) => !t.isDeleted).toList();

                  // Account Filter
                  if (_selectedAccountId != null) {
                    if (_selectedAccountId == 'none') {
                      filtered =
                          filtered.where((t) => t.accountId == null).toList();
                    } else {
                      filtered = filtered
                          .where((t) => t.accountId == _selectedAccountId)
                          .toList();
                    }
                  }

                  // Loan Specific Filter Logic
                  if (_type == ReportType.loan) {
                    if (_selectedLoanId != null) {
                      filtered = filtered
                          .where((t) => t.loanId == _selectedLoanId)
                          .toList();
                    }
                  }

                  // Time Filter
                  final now = DateTime.now();
                  if (_timeFilterMode == '30') {
                    final start = now.subtract(const Duration(days: 30));
                    filtered =
                        filtered.where((t) => t.date.isAfter(start)).toList();
                  } else if (_timeFilterMode == '90') {
                    final start = now.subtract(const Duration(days: 90));
                    filtered =
                        filtered.where((t) => t.date.isAfter(start)).toList();
                  } else if (_timeFilterMode == '365') {
                    final start = now.subtract(const Duration(days: 365));
                    filtered =
                        filtered.where((t) => t.date.isAfter(start)).toList();
                  } else if (_timeFilterMode == 'month' &&
                      _selectedMonth != null) {
                    filtered = filtered
                        .where((t) =>
                            t.date.year == _selectedMonth!.year &&
                            t.date.month == _selectedMonth!.month)
                        .toList();
                  } else if (_timeFilterMode == 'year' &&
                      _selectedYear != null) {
                    filtered = filtered
                        .where((t) => t.date.year == _selectedYear)
                        .toList();
                  }
                  // 3. Aggregate Data
                  Map<String, double> data = {};
                  double total = 0;

                  if (_type == ReportType.spending) {
                    final expenses = filtered
                        .where((t) => t.type == TransactionType.expense)
                        .toList();
                    for (var t in expenses) {
                      data[t.category] = (data[t.category] ?? 0) + t.amount;
                    }
                  } else if (_type == ReportType.income) {
                    final income = filtered
                        .where((t) => t.type == TransactionType.income)
                        .toList();
                    for (var t in income) {
                      data[t.category] = (data[t.category] ?? 0) + t.amount;
                    }
                  } else if (_type == ReportType.loan) {
                    final loanTransactions = filtered
                        .where((t) =>
                            t.loanId != null &&
                            (t.category == 'EMI' ||
                                t.category == 'Prepayment' ||
                                t.category == 'Loan Payment'))
                        .toList();
                    for (var t in loanTransactions) {
                      data[t.title] = (data[t.title] ?? 0) + t.amount;
                    }
                  }

                  // Capital Gains Aggregation
                  final categories = ref.watch(categoriesProvider);
                  final catMap = <String, Category>{};
                  for (var c in categories) {
                    catMap[c.name] = c;
                  }
                  double totalGains = 0;
                  Map<String, double> gainsByCategory = {};

                  // Filter gains based on report type
                  final gainTxns = filtered.where((t) {
                    final catObj = catMap[t.category];

                    if (catObj?.tag != CategoryTag.capitalGain) return false;

                    // Match report type
                    if (_type == ReportType.spending) {
                      return t.type == TransactionType.expense;
                    } else if (_type == ReportType.income) {
                      return t.type == TransactionType.income;
                    }
                    return false;
                  }).toList();

                  for (var t in gainTxns) {
                    final amount = t.gainAmount ?? 0;
                    totalGains += amount;
                    gainsByCategory[t.category] =
                        (gainsByCategory[t.category] ?? 0) + amount;
                  }

                  total = data.values.fold(0, (sum, val) => sum + val);

                  // --- CHART DATA PREPARATION (Top 6 + Others) ---
                  // 1. Exclude Transfers from Chart Data
                  // Note: 'data' map is built from 'filtered' transactions.
                  // If we are in Spending mode, we show Expenses.
                  // If Income mode, Income.
                  // We should ensure Transfer type is explicitly excluded if it somehow got in.

                  // 2. Convert to List and Sort
                  final sortedEntries = data.entries.toList()
                    ..sort((a, b) => b.value.compareTo(a.value));

                  List<MapEntry<String, double>> chartEntries = [];
                  if (sortedEntries.length <= 6) {
                    chartEntries = sortedEntries;
                  } else {
                    // Take Top 6
                    chartEntries = sortedEntries.take(6).toList();

                    // Sum the rest
                    final rest = sortedEntries.skip(6);
                    double othersSum = rest.fold(0, (sum, e) => sum + e.value);

                    // Add "Others" entry
                    if (othersSum > 0) {
                      chartEntries.add(MapEntry('Others', othersSum));
                    }
                  }
                  // --------------------------------------------------

                  return ListView(
                    children: [
                      // Filters Area
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
                                ] else
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
                                            child: Text('Manual',
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
                            // Calculate Breakdown (EMI vs Prepayment) for selected period
                            double emiPaid = 0;
                            double prepaymentPaid = 0;

                            // FILTER LOANS based on selection
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
                                if (_timeFilterMode == 'month' &&
                                    _selectedMonth != null) {
                                  inRange =
                                      txn.date.month == _selectedMonth!.month &&
                                          txn.date.year == _selectedMonth!.year;
                                } else if (_timeFilterMode == 'year') {
                                  inRange = txn.date.year == _selectedYear;
                                } else {
                                  // For 30/90/365/All, we rely on the helper or manual calc
                                  // Simplified: Use _getTimeRange logic mapping if possible
                                  // Or just re-implement simple date check since custom range isn't fully exposed in helpers here
                                  final now = DateTime.now();
                                  if (_timeFilterMode == '30') {
                                    inRange = txn.date.isAfter(
                                        now.subtract(const Duration(days: 30)));
                                  } else if (_timeFilterMode == '90') {
                                    inRange = txn.date.isAfter(
                                        now.subtract(const Duration(days: 90)));
                                  } else if (_timeFilterMode == '365') {
                                    inRange = txn.date.isAfter(now
                                        .subtract(const Duration(days: 365)));
                                  } else {
                                    inRange = true; // All Time
                                  }
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
                                  final radius = isTouched
                                      ? 60.0
                                      : 50.0; // Smaller radius to make room for external labels
                                  final percentage =
                                      total == 0 ? 0 : (e.value / total) * 100;

                                  // Determine visibility: Touched OR > 10% OR (Top 6 AND > 5%)
                                  final isTopSlice = chartEntries.length <= 6 ||
                                      index <
                                          6; // Entries are sorted by value desc

                                  final showLabel = isTouched ||
                                      percentage >= 10 ||
                                      (isTopSlice && percentage > 5);

                                  return PieChartSectionData(
                                    value: e.value == 0 ? 0.01 : e.value,
                                    titlePositionPercentageOffset:
                                        1.6, // Move Outside
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
                                                .onSurface), // Visible on background
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
                                  // Use standard palette color if it's in Top 6, else Grey
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

  TimeRange _getTimeRange() {
    switch (_timeFilterMode) {
      case '30':
        return TimeRange.last30Days;
      case '90':
        return TimeRange.all; // Default if no direct map
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
                  ? Colors.green.withOpacity(0.3)
                  : Colors.red.withOpacity(0.3))),
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
          _selectedAccountId = null; // Reset filters on switch
          _selectedLoanId = null;
          _selectedLoanType = null;
        });
      },
    );
  }

  Color _getChartColor(int index) {
    const List<Color> palette = [
      Color(0xFF4CAF50), // Green
      Color(0xFF2196F3), // Blue
      Color(0xFFFFC107), // Amber
      Color(0xFFE91E63), // Pink
      Color(0xFF9C27B0), // Purple
      Color(0xFF00BCD4), // Cyan
    ];
    return palette[index % palette.length];
  }
}
