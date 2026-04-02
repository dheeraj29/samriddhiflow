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
import '../l10n/app_localizations.dart';

const dateFormatMmmmYyyy = 'MMMM yyyy';

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
      appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.financialReportsTitle)),
      body: _buildContent(
        transactionsAsync,
        accountsAsync,
        loansAsync,
        currencyLocale,
      ),
    );
  }

  Widget _buildContent(
    AsyncValue<List<Transaction>> transactionsAsync,
    AsyncValue<List<dynamic>> accountsAsync,
    AsyncValue<List<Loan>> loansAsync,
    String currencyLocale,
  ) {
    if (transactionsAsync.isLoading ||
        accountsAsync.isLoading ||
        loansAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (transactionsAsync.hasError) {
      // coverage:ignore-start
      return Center(
          child: Text(AppLocalizations.of(context)!
              .errorLabelWithDetails(transactionsAsync.error.toString())));
      // coverage:ignore-end
    }
    if (accountsAsync.hasError) {
      // coverage:ignore-start
      return Center(
          child: Text(AppLocalizations.of(context)!
              .errorLabelWithDetails(accountsAsync.error.toString())));
      // coverage:ignore-end
    }
    if (loansAsync.hasError) {
      // coverage:ignore-start
      return Center(
          child: Text(AppLocalizations.of(context)!
              .errorLabelWithDetails(loansAsync.error.toString())));
      // coverage:ignore-end
    }

    final transactions = transactionsAsync.value ?? [];
    final accounts = accountsAsync.value ?? [];
    final loans = loansAsync.value ?? [];

    return _buildReportBody(transactions, accounts, loans, currencyLocale);
  }

  Widget _buildReportBody(List<Transaction> transactions,
      List<dynamic> accounts, List<Loan> loans, String currencyLocale) {
    if (transactions.isEmpty) {
      return Center(child: Text(AppLocalizations.of(context)!.noDataAvailable));
    }

    final dateInfo = _prepareDateInfo(transactions);
    final filtered = _getFilteredTransactions(transactions);
    final data = _aggregateData(filtered);
    final capitalGainsInfo = _prepareCapitalGains(filtered);

    final double total = data.values.fold(0, (sum, val) => sum + val);
    final chartEntries = _prepareChartEntries(data);
    final sortedEntries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return ListView(
      children: [
        _buildReportTypeSelector(),
        const Divider(height: 1),
        _buildFilterBar(
            accounts, loans, dateInfo.monthsAvailable, dateInfo.yearsAvailable),
        if (capitalGainsInfo.transactions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: _buildCapitalGainsCard(context, capitalGainsInfo.total,
                capitalGainsInfo.byCategory, currencyLocale),
          ),
        _buildMainReportContent(
            data, loans, sortedEntries, chartEntries, total, currencyLocale),
      ],
    );
  }

  Widget _buildMainReportContent(
    Map<String, double> data,
    List<Loan> loans,
    List<MapEntry<String, double>> sortedEntries,
    List<MapEntry<String, double>> chartEntries,
    double total,
    String currencyLocale,
  ) {
    if (data.isEmpty && _type != ReportType.loan) {
      return Padding(
        padding: const EdgeInsets.all(32.0),
        child: Center(
            child: Text(AppLocalizations.of(context)!.noDataSelectedCriteria)),
      );
    }

    return Column(
      children: [
        const SizedBox(height: 16),
        if (_type == ReportType.loan) _buildLoanSummary(loans, currencyLocale),
        if (data.isNotEmpty)
          _buildDataList(sortedEntries, chartEntries, total, currencyLocale),
      ],
    );
  }

  // --- Data Preparation Helpers ---

  _DateInfo _prepareDateInfo(List<Transaction> transactions) {
    final dates = transactions
        .where((t) => !t.isDeleted)
        .map((t) => t.date)
        .toList()
      ..sort((a, b) => b.compareTo(a));

    final Set<String> monthsAvailable = {};
    final Set<int> yearsAvailable = {};
    for (var d in dates) {
      monthsAvailable.add(
          DateFormat(dateFormatMmmmYyyy).format(DateTime(d.year, d.month)));
      yearsAvailable.add(d.year);
    }

    if (_selectedYear == null && yearsAvailable.isNotEmpty) {
      _selectedYear = yearsAvailable.first;
    }
    if (_selectedMonth == null && dates.isNotEmpty) {
      _selectedMonth = DateTime(dates.first.year, dates.first.month);
    }

    return _DateInfo(monthsAvailable, yearsAvailable);
  }

  List<Transaction> _getFilteredTransactions(List<Transaction> transactions) {
    return TransactionFilterUtils.filter(
      transactions: transactions,
      accountId: _selectedAccountId,
      loanId: _type == ReportType.loan ? _selectedLoanId : null,
      periodMode: _timeFilterMode,
      selectedMonth: _selectedMonth,
      selectedYear: _selectedYear,
      excludedCategories: _excludedCategories.toList(),
    );
  }

  Map<String, double> _aggregateData(List<Transaction> filtered) {
    if (_type == ReportType.spending) {
      return ReportUtils.aggregateByCategory(
          transactions: filtered, type: TransactionType.expense);
    } else if (_type == ReportType.income) {
      return ReportUtils.aggregateByCategory(
          transactions: filtered, type: TransactionType.income);
    } else {
      return ReportUtils.aggregateLoanPayments(transactions: filtered);
    }
  }

  _CapitalGainsInfo _prepareCapitalGains(List<Transaction> filtered) {
    final categories = ref.watch(categoriesProvider);
    final reportType = _type == ReportType.spending
        ? TransactionType.expense
        : TransactionType.income;

    final byCategory = ReportUtils.aggregateCapitalGains(
      transactions: filtered,
      categories: categories,
      reportType: reportType,
    );
    final total = byCategory.values.fold<double>(0, (a, b) => a + b);
    final transactions = ReportUtils.getCapitalGainTransactions(
      transactions: filtered,
      categories: categories,
      reportType: reportType,
    );

    return _CapitalGainsInfo(byCategory, total, transactions);
  }

  List<MapEntry<String, double>> _prepareChartEntries(
      Map<String, double> data) {
    final sortedEntries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (sortedEntries.length <= 6) return sortedEntries;

    final chartEntries = sortedEntries.take(6).toList();
    final rest = sortedEntries.skip(6);
    double othersSum = rest.fold(0, (sum, e) => sum + e.value);
    if (othersSum > 0) {
      chartEntries.add(
          MapEntry(AppLocalizations.of(context)!.othersCategory, othersSum));
    }
    return chartEntries;
  }

  // --- UI Building Helpers ---

  Widget _buildReportTypeSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          _buildFilterChip(AppLocalizations.of(context)!.spendingReport,
              ReportType.spending),
          _buildFilterChip(
              AppLocalizations.of(context)!.incomeReport, ReportType.income),
          _buildFilterChip(
              AppLocalizations.of(context)!.loanReport, ReportType.loan),
        ],
      ),
    );
  }

  Widget _buildFilterBar(List<dynamic> accounts, List<Loan> loans,
      Set<String> monthsAvailable, Set<int> yearsAvailable) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          _buildFilterOptions(accounts, loans),
          const SizedBox(height: 8),
          if (_timeFilterMode == 'month') _buildMonthPicker(monthsAvailable),
          if (_timeFilterMode == 'year') _buildYearPicker(yearsAvailable),
        ],
      ),
    );
  }

  Widget _buildFilterOptions(List<dynamic> accounts, List<Loan> loans) {
    return Wrap(
      spacing: 8,
      runSpacing: 10,
      children: [
        _buildPeriodDropdown(),
        if (_type == ReportType.loan)
          ..._buildLoanFilters(loans)
        else
          ..._buildAccountFilters(accounts),
      ],
    );
  }

  Widget _buildPeriodDropdown() {
    return SizedBox(
      width: 130,
      child: DropdownButtonFormField<String>(
        initialValue: _timeFilterMode,
        isExpanded: true,
        decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.periodLabel,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10),
            border: const OutlineInputBorder()),
        items: _getPeriodOptions(context).map((opt) {
          return DropdownMenuItem<String>(
            value: opt['val'],
            child: Text(opt['label']!, overflow: TextOverflow.ellipsis),
          );
        }).toList(),
        onChanged: (v) {
          FocusScope.of(context).unfocus();
          setState(() => _timeFilterMode = v!);
        },
      ),
    );
  }

  List<Map<String, String>> _getPeriodOptions(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return [
      {'val': '30', 'label': l10n.days30},
      {'val': '90', 'label': l10n.days90},
      {'val': '365', 'label': l10n.lastYear},
      {'val': 'month', 'label': l10n.monthOption},
      {'val': 'year', 'label': l10n.yearOption},
      {'val': 'all', 'label': l10n.allTime},
    ];
  }

  List<Widget> _buildLoanFilters(List<Loan> loans) {
    return [
      SizedBox(
        width: 130,
        child: DropdownButtonFormField<String?>(
          initialValue: _selectedLoanId,
          isExpanded: true,
          decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.loanLabel,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10),
              border: const OutlineInputBorder()),
          items: [
            DropdownMenuItem(
              value: null,
              child: Text(AppLocalizations.of(context)!.allLoans,
                  overflow: TextOverflow.ellipsis),
            ),
            ...loans.map((l) => DropdownMenuItem(
                  value: l.id,
                  child: Text(l.name, overflow: TextOverflow.ellipsis),
                ))
          ],
          onChanged: (val) {
            FocusScope.of(context).unfocus();
            setState(() => _selectedLoanId = val);
          },
        ),
      ),
      SizedBox(
        width: 130,
        child: DropdownButtonFormField<LoanType?>(
          initialValue: _selectedLoanType,
          isExpanded: true,
          decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.typeLabel,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10),
              border: const OutlineInputBorder()),
          items: <DropdownMenuItem<LoanType?>>[
            DropdownMenuItem<LoanType?>(
                value: null,
                child: Text(AppLocalizations.of(context)!.allOption,
                    overflow: TextOverflow.ellipsis)),
            ...LoanType.values.map((t) {
              final label = switch (t) {
                LoanType.personal =>
                  AppLocalizations.of(context)!.loanTypePersonal,
                LoanType.home => AppLocalizations.of(context)!.loanTypeHome,
                LoanType.education =>
                  AppLocalizations.of(context)!.loanTypeEducation,
                LoanType.car => AppLocalizations.of(context)!.loanTypeCar,
                LoanType.business =>
                  AppLocalizations.of(context)!.loanTypeBusiness,
                LoanType.gold => AppLocalizations.of(context)!.loanTypeGold,
                LoanType.other => AppLocalizations.of(context)!.loanTypeOther,
              };
              return DropdownMenuItem<LoanType?>(
                  value: t,
                  child: Text(label.toUpperCase(),
                      overflow: TextOverflow.ellipsis));
            }),
          ],
          // coverage:ignore-start
          onChanged: (v) {
            FocusScope.of(context).unfocus();
            setState(() => _selectedLoanType = v);
            // coverage:ignore-end
          },
        ),
      ),
    ];
  }

  List<Widget> _buildAccountFilters(List<dynamic> accounts) {
    return [
      SizedBox(
        width: 130,
        child: DropdownButtonFormField<String?>(
          initialValue: _selectedAccountId,
          isExpanded: true,
          decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.accountLabel,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10),
              border: const OutlineInputBorder()),
          items: <DropdownMenuItem<String?>>[
            DropdownMenuItem<String?>(
                value: null,
                child: Text(AppLocalizations.of(context)!.allAccounts,
                    overflow: TextOverflow.ellipsis)),
            DropdownMenuItem<String?>(
                value: 'none',
                child: Text(AppLocalizations.of(context)!.manualNoAccount,
                    overflow: TextOverflow.ellipsis)),
            ...accounts.map((a) => DropdownMenuItem<String?>(
                value: a.id, // coverage:ignore-line
                child: Text(a.name,
                    overflow: TextOverflow.ellipsis))), // coverage:ignore-line
          ],
          // coverage:ignore-start
          onChanged: (v) {
            FocusScope.of(context).unfocus();
            setState(() => _selectedAccountId = v);
            // coverage:ignore-end
          },
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: ActionChip(
          avatar: Icon(Icons.filter_list,
              size: 16,
              color: _excludedCategories.isEmpty ? Colors.grey : Colors.blue),
          label: Text(_excludedCategories.isEmpty
              ? AppLocalizations.of(context)!.filterCategories
              : AppLocalizations.of(context)!
                  .categoriesExcluded(_excludedCategories.length)),
          onPressed: () {
            FocusScope.of(context).unfocus();
            _showExclusionDialog(ref.read(transactionsProvider).value ?? []);
          },
        ),
      ),
    ];
  }

  // coverage:ignore-start
  Widget _buildMonthPicker(Set<String> monthsAvailable) {
    return DropdownButtonFormField<String>(
      initialValue: _selectedMonth != null
          ? DateFormat(dateFormatMmmmYyyy).format(_selectedMonth!)
          // coverage:ignore-end
          : null,
      decoration: InputDecoration(
          // coverage:ignore-line
          labelText: AppLocalizations.of(context)!
              .selectMonthLabel, // coverage:ignore-line
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
          border: const OutlineInputBorder()),
      items: monthsAvailable
          // coverage:ignore-start
          .map((m) => DropdownMenuItem(value: m, child: Text(m)))
          .toList(),
      onChanged: (v) {
        // coverage:ignore-end
        if (v != null) {
          final parse =
              DateFormat(dateFormatMmmmYyyy).parse(v); // coverage:ignore-line
          setState(() => _selectedMonth = parse); // coverage:ignore-line
        }
      },
    );
  }

  // coverage:ignore-start
  Widget _buildYearPicker(Set<int> yearsAvailable) {
    return DropdownButtonFormField<int>(
      initialValue: _selectedYear,
      decoration: InputDecoration(
          labelText: AppLocalizations.of(context)!.selectYearLabel,
          // coverage:ignore-end
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
          border: const OutlineInputBorder()),
      items: yearsAvailable
          // coverage:ignore-start
          .map((y) => DropdownMenuItem(value: y, child: Text(y.toString())))
          .toList(),
      onChanged: (v) => setState(() => _selectedYear = v),
      // coverage:ignore-end
    );
  }

  Widget _buildLoanSummary(List<Loan> loans, String currencyLocale) {
    final filteredLoans = _getFilteredLoans(loans);
    final totalLiability =
        filteredLoans.fold<double>(0, (sum, l) => sum + l.remainingPrincipal);
    final (emiPaid, prepaymentPaid) = _calculateLoanPayments(filteredLoans);

    return Column(
      children: [
        Text(AppLocalizations.of(context)!.totalLiability,
            style: const TextStyle(color: Colors.grey, fontSize: 12)),
        SmartCurrencyText(
          value: totalLiability,
          locale: currencyLocale,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.bold, color: Colors.redAccent),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  Text(AppLocalizations.of(context)!.emiPaid,
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  SmartCurrencyText(
                    value: emiPaid,
                    locale: currencyLocale,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  Text(AppLocalizations.of(context)!.prepayment,
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  SmartCurrencyText(
                    value: prepaymentPaid,
                    locale: currencyLocale,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.orange),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  List<Loan> _getFilteredLoans(List<Loan> loans) {
    return loans.where((l) {
      if (_selectedLoanId != null && l.id != _selectedLoanId) return false;
      if (_selectedLoanType != null && l.type != _selectedLoanType) {
        return false;
      }
      return true;
    }).toList();
  }

  (double, double) _calculateLoanPayments(List<Loan> filteredLoans) {
    double emiPaid = 0;
    double prepaymentPaid = 0;
    for (var loan in filteredLoans) {
      for (var txn in loan.transactions) {
        if (!_isInTimeRange(txn.date)) continue;
        // coverage:ignore-start
        if (txn.type == LoanTransactionType.emi) {
          emiPaid += txn.amount;
        } else if (txn.type == LoanTransactionType.prepayment) {
          prepaymentPaid += txn.amount;
          // coverage:ignore-end
        }
      }
    }
    return (emiPaid, prepaymentPaid);
  }

  bool _isInTimeRange(DateTime date) {
    final now = DateTime.now();
    return switch (_timeFilterMode) {
      'month' when _selectedMonth != null =>
        date.month == _selectedMonth!.month && // coverage:ignore-line
            date.year == _selectedMonth!.year, // coverage:ignore-line
      'year' => date.year == _selectedYear,
      '30' => date.isAfter(now.subtract(const Duration(days: 30))),
      '90' => date.isAfter(
          now.subtract(const Duration(days: 90))), // coverage:ignore-line
      '365' => date.isAfter(
          now.subtract(const Duration(days: 365))), // coverage:ignore-line
      _ => true, // 'all'
    };
  }

  Widget _buildDataList(
      List<MapEntry<String, double>> sortedEntries,
      List<MapEntry<String, double>> chartEntries,
      double total,
      String currencyLocale) {
    return Column(
      children: [
        _buildTotalSection(total, currencyLocale),
        const SizedBox(height: 24),
        ReportsPieChart(entries: chartEntries, total: total),
        const SizedBox(height: 16),
        _buildCategoryList(sortedEntries, currencyLocale),
      ],
    );
  }

  Widget _buildTotalSection(double total, String currencyLocale) {
    return Center(
      child: Column(
        children: [
          Text(
              _type == ReportType.loan
                  ? AppLocalizations.of(context)!
                      .totalPaid // coverage:ignore-line
                  : AppLocalizations.of(context)!.totalLabel,
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
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
    );
  }

  Widget _buildCategoryList(
      List<MapEntry<String, double>> sortedEntries, String currencyLocale) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sortedEntries.length,
      itemBuilder: (context, index) {
        final e = sortedEntries[index];
        return _CategoryReportItem(
          entry: e,
          index: index,
          currencyLocale: currencyLocale,
          onTap: () => _navigateToCategoryTransactions(e.key),
        );
      },
    );
  }

  void _navigateToCategoryTransactions(String category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionsScreen(
          initialCategory: category,
          initialRange: TimeRange.custom,
          initialCustomRange: _getTimeRange(),
          initialType: _getInitialTransactionType(),
        ),
      ),
    );
  }

  TransactionType? _getInitialTransactionType() {
    if (_type == ReportType.spending) return TransactionType.expense;
    if (_type == ReportType.income) {
      // coverage:ignore-line
      return TransactionType.income;
    }
    return null;
  }

  void _showExclusionDialog(List<Transaction> transactions) {
    if (transactions.isEmpty) return;

    final categoryTotals = <String, double>{};
    for (var t in transactions) {
      categoryTotals[t.category] = (categoryTotals[t.category] ?? 0) + t.amount;
    }

    final categories = categoryTotals.keys.toList()
      ..sort((a, b) => categoryTotals[b]!.compareTo(categoryTotals[a]!));

    showDialog(
      context: context,
      builder: (context) => _CategoryExclusionDialog(
        categories: categories,
        excludedCategories: _excludedCategories,
        onChanged: () => setState(() {}),
      ),
    );
  }

  DateTimeRange _getTimeRange() {
    final now = DateTime.now();

    return switch (_timeFilterMode) {
      '30' =>
        DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now),
      // coverage:ignore-start
      '90' =>
        DateTimeRange(start: now.subtract(const Duration(days: 90)), end: now),
      '365' =>
        DateTimeRange(start: now.subtract(const Duration(days: 365)), end: now),
      'month' when _selectedMonth != null => DateTimeRange(
          start: _selectedMonth!,
          end: DateTime(_selectedMonth!.year, _selectedMonth!.month + 1, 0),
          // coverage:ignore-end
        ),
      // coverage:ignore-start
      'year' when _selectedYear != null => DateTimeRange(
          start: DateTime(_selectedYear!, 1, 1),
          end: DateTime(_selectedYear!, 12, 31),
          // coverage:ignore-end
        ),
      _ =>
        DateTimeRange(start: DateTime(2000), end: now), // coverage:ignore-line
    };
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
                Flexible(
                  child: Text(
                    _type == ReportType.income
                        ? AppLocalizations.of(context)!.capitalGainsRealized
                        : AppLocalizations.of(context)!
                            .capitalLossesRealized, // coverage:ignore-line
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.blue[800]),
                    overflow: TextOverflow.ellipsis,
                  ),
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
            if (breakdown.isNotEmpty)
              _buildCapitalGainsBreakdown(breakdown, locale),
          ],
        ),
      ),
    );
  }

  Widget _buildCapitalGainsBreakdown(
      Map<String, double> breakdown, String locale) {
    return Column(
      children: [
        const Divider(height: 24),
        ...breakdown.entries.map((e) => _buildGainsItem(e, locale)),
      ],
    );
  }

  Widget _buildGainsItem(MapEntry<String, double> e, String locale) {
    return Padding(
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

// --- Private helper classes ---

class _CategoryExclusionDialog extends StatelessWidget {
  final List<String> categories;
  final Set<String> excludedCategories;
  final VoidCallback onChanged;

  const _CategoryExclusionDialog({
    required this.categories,
    required this.excludedCategories,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setLocalState) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context)!.filterCategories),
          content: SizedBox(
            width: double.maxFinite,
            child: _buildExclusionList(setLocalState),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setLocalState(() {
                  excludedCategories.clear();
                });
                onChanged();
              },
              child: Text(AppLocalizations.of(context)!.resetButton),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context)!.doneButton),
            ),
          ],
        );
      },
    );
  }

  Widget _buildExclusionList(StateSetter setLocalState) {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        return _CategoryExclusionItem(
          category: category,
          isExcluded: excludedCategories.contains(category),
          onChanged: (isSelected) => _handleExclusionChange(
            category,
            isSelected,
            setLocalState,
          ),
        );
      },
    );
  }

  void _handleExclusionChange(
      String category, bool isSelected, StateSetter setLocalState) {
    setLocalState(() {
      if (isSelected) {
        excludedCategories.remove(category); // coverage:ignore-line
      } else {
        excludedCategories.add(category);
      }
    });
    onChanged();
  }
}

class _DateInfo {
  final Set<String> monthsAvailable;
  final Set<int> yearsAvailable;
  _DateInfo(this.monthsAvailable, this.yearsAvailable);
}

class _CapitalGainsInfo {
  final Map<String, double> byCategory;
  final double total;
  final List<Transaction> transactions;
  _CapitalGainsInfo(this.byCategory, this.total, this.transactions);
}

class _CategoryExclusionItem extends StatelessWidget {
  final String category;
  final bool isExcluded;
  final ValueChanged<bool> onChanged;

  const _CategoryExclusionItem({
    required this.category,
    required this.isExcluded,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      title: Text(category),
      value: !isExcluded,
      onChanged: (bool? value) => onChanged(value ?? false),
    );
  }
}

class _CategoryReportItem extends StatelessWidget {
  final MapEntry<String, double> entry;
  final int index;
  final String currencyLocale;
  final VoidCallback onTap;

  const _CategoryReportItem({
    required this.entry,
    required this.index,
    required this.currencyLocale,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: index < 6
                      ? ReportUtils.getChartColor(index)
                      : Colors.grey,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  entry.key,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SmartCurrencyText(
                    value: entry.value,
                    locale: currencyLocale,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Details >',
                    style: TextStyle(fontSize: 10, color: Colors.blue),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
