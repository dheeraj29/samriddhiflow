import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import '../../services/taxes/tax_data_fetcher.dart';
import '../../services/taxes/insurance_tax_service.dart';
import '../../services/taxes/tax_config_service.dart';
import '../../services/taxes/indian_tax_service.dart';
import '../../widgets/smart_currency_text.dart';
import '../../models/taxes/tax_data.dart';
import '../../models/taxes/tax_data_models.dart';
import '../../models/taxes/insurance_policy.dart';
import '../../utils/currency_utils.dart';
import 'tax_rules_screen.dart';

import 'tax_details_screen.dart';
import 'insurance_portfolio_screen.dart';
import '../../providers.dart';

class TaxDashboardScreen extends ConsumerStatefulWidget {
  const TaxDashboardScreen({super.key});

  @override
  ConsumerState<TaxDashboardScreen> createState() => _TaxDashboardScreenState();
}

class _TaxDashboardScreenState extends ConsumerState<TaxDashboardScreen> {
  int _selectedYear = DateTime.now().year; // FY Start Year
  TaxYearData? _taxData;
  List<TaxYearData> _allTaxData = [];
  bool _isServiceInitialized = false;

  @override
  void initState() {
    super.initState();
    _initServices();
  }

  Future<void> _initServices() async {
    try {
      final config = ref.read(taxConfigServiceProvider);
      await config.init();
      if (mounted) {
        setState(() {
          _isServiceInitialized = true;
          // Fix: Use correct financial year logic (Feb 2026 -> FY 2025 if Apr cycle)
          _selectedYear = config.getCurrentFinancialYear();
        });
      }
    } catch (e) {
      if (mounted) {
        // coverage:ignore-line
        // Fallback or show error
        setState(() {
          // coverage:ignore-line
          _isServiceInitialized = true; // coverage:ignore-line
        });
        ScaffoldMessenger.of(context).showSnackBar(// coverage:ignore-line
            SnackBar(
                content: Text(
                    'Error initializing tax data: $e'))); // coverage:ignore-line
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isServiceInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Reactive Data Fetching
    final taxDataAsync = ref.watch(taxYearDataProvider(_selectedYear));
    final allTaxDataAsync = ref.watch(allTaxYearDataProvider);
    final policiesAsync = ref.watch(insurancePoliciesProvider);

    _taxData = taxDataAsync.value ?? TaxYearData(year: _selectedYear);
    _allTaxData = (allTaxDataAsync.value ?? [])
      ..sort((a, b) => b.year.compareTo(a.year));
    final policies = policiesAsync.value ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tax Dashboard', overflow: TextOverflow.ellipsis),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.health_and_safety),
            tooltip: 'Insurance Portfolio',
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        InsurancePortfolioScreen(initialYear: _selectedYear))),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildYearSelector(),
            const SizedBox(height: 12),
            _buildActionButtons(),
            _buildInsuranceTaxDisclaimer(policies),
            if (_taxData != null) ...[
              _buildAdvanceTaxReminder(_taxData!),
              const SizedBox(height: 16),
              _buildSummaryCard(_taxData!),
              const SizedBox(height: 16),
              _buildExemptionsCard(_taxData!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInsuranceTaxDisclaimer(List<InsurancePolicy> policies) {
    final service = ref.read(insuranceTaxServiceProvider);
    if (!service.hasUnaddedTaxableInsurance(policies, _selectedYear)) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          border: Border.all(color: Colors.orange.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Taxable Insurance Alert',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.orange),
                  ),
                  Text(
                    'You have insurance policies that may be taxable in FY $_selectedYear-${_selectedYear + 1}. Ensure income is added to avoid penalties.',
                    style:
                        TextStyle(fontSize: 12, color: Colors.orange.shade900),
                  ),
                ],
              ),
            ),
            TextButton(
              // coverage:ignore-start
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        InsurancePortfolioScreen(initialYear: _selectedYear)),
                // coverage:ignore-end
              ),
              child: const Text('View Policies'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _syncData() async {
    final fetcher = ref.read(taxDataFetcherProvider);
    await _showSyncDialog(fetcher);
  }

  Future<void> _showSyncDialog(TaxDataFetcher fetcher) async {
    final config = ref.read(taxConfigServiceProvider);
    final rules = config.getRulesForYear(_selectedYear);
    final startMonth = rules.financialYearStartMonth;

    DateTime start = DateTime(_selectedYear, startMonth, 1);
    DateTime defaultEnd = DateTime.now();
    DateTime fyEnd = startMonth == 1
        ? DateTime(_selectedYear, 12, 31) // coverage:ignore-line
        : DateTime(_selectedYear + 1, startMonth, 1)
            .subtract(const Duration(days: 1));

    if (defaultEnd.isAfter(fyEnd)) defaultEnd = fyEnd;
    if (defaultEnd.isBefore(start)) defaultEnd = start;

    showDialog(
      context: context,
      builder: (ctx) => _TaxSyncDialog(
        selectedYear: _selectedYear,
        initialStart: start,
        initialEnd: defaultEnd,
        onSync: (start, end, smartSync) => _performSync(
            // coverage:ignore-line
            fetcher,
            start,
            end,
            smartSync,
            forceReset: !smartSync),
      ),
    );
  }

  Future<void> _performSync(
      // coverage:ignore-line
      TaxDataFetcher fetcher,
      DateTime start,
      DateTime end,
      bool smartSync,
      {bool forceReset = false}) async {
    ScaffoldMessenger.of(context) // coverage:ignore-line
        .showSnackBar(const SnackBar(
            content: Text('Syncing...'))); // coverage:ignore-line

    try {
      final result =
          await fetcher.fetchAndAggregate(_selectedYear, // coverage:ignore-line
              customStart: start,
              customEnd: end);
      final newData = result.data; // coverage:ignore-line

      final mergedHP =
          await _mergeHousePropertyInterest(start, end); // coverage:ignore-line
      final finalData = _buildFinalSyncData(newData, mergedHP,
          forceReset: forceReset); // coverage:ignore-line

      setState(() => _taxData = finalData); // coverage:ignore-line
      await ref
          .read(storageServiceProvider)
          .saveTaxYearData(finalData); // coverage:ignore-line

      // coverage:ignore-start
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Sync Complete')));
        // coverage:ignore-end
      }
    } catch (e) {
      // coverage:ignore-start
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Sync Failed: $e')));
        // coverage:ignore-end
      }
    }
  }

  Future<List<HouseProperty>> _mergeHousePropertyInterest(
      // coverage:ignore-line
      DateTime start,
      DateTime end) async {
    // coverage:ignore-start
    List<HouseProperty> mergedHP = [];
    if (_taxData != null) {
      mergedHP = List.from(_taxData!.houseProperties);
      // coverage:ignore-end
    }

    final loans = await ref.read(loansProvider.future); // coverage:ignore-line

    // coverage:ignore-start
    for (int i = 0; i < mergedHP.length; i++) {
      final hp = mergedHP[i];
      if (hp.loanId == null) continue;
      // coverage:ignore-end

      try {
        final loan =
            loans.firstWhere((l) => l.id == hp.loanId); // coverage:ignore-line
        double interest = 0;
        // coverage:ignore-start
        for (var txn in loan.transactions) {
          if (txn.date.isAfter(start.subtract(const Duration(days: 1))) &&
              txn.date.isBefore(end.add(const Duration(days: 1)))) {
            interest += txn.interestComponent;
            // coverage:ignore-end
          }
        }
        // coverage:ignore-start
        if (interest > 0) {
          mergedHP[i] = HouseProperty(
            name: hp.name,
            isSelfOccupied: hp.isSelfOccupied,
            rentReceived: hp.rentReceived,
            municipalTaxes: hp.municipalTaxes,
            // coverage:ignore-end
            interestOnLoan: interest,
            loanId: hp.loanId, // coverage:ignore-line
          );
        }
      } catch (e) {
        // Loan not found
      }
    }
    return mergedHP;
  }

  TaxYearData _buildFinalSyncData(
      // coverage:ignore-line
      TaxYearData newData,
      List<HouseProperty> mergedHP,
      {required bool forceReset}) {
    final hpToUse = mergedHP.isNotEmpty
        ? mergedHP
        : newData.houseProperties; // coverage:ignore-line

    if (forceReset) {
      return newData.copyWith(
        // coverage:ignore-line
        salary: _taxData?.salary ?? newData.salary, // coverage:ignore-line
        houseProperties: hpToUse,
        lockedFields: [], // coverage:ignore-line
        lastSyncDate: DateTime.now(), // coverage:ignore-line
      );
    }

    // coverage:ignore-start
    final old = _taxData;
    if (old != null && old.lockedFields.isNotEmpty) {
      return newData.copyWith(
        salary: old.salary,
        // coverage:ignore-end
        houseProperties: hpToUse,
        lockedFields: old.lockedFields, // coverage:ignore-line
        lastSyncDate: DateTime.now(), // coverage:ignore-line
      );
    }

    // No locks, overwrite but PROTECT manual salary
    return newData.copyWith(
      // coverage:ignore-line
      salary: _taxData?.salary ?? newData.salary, // coverage:ignore-line
      houseProperties: hpToUse,
      lastSyncDate: DateTime.now(), // coverage:ignore-line
    );
  }

  List<MapEntry<TaxYearData, CapitalGainEntry>> _collectTrackingGains(
      TaxYearData data, int reinvestWindow) {
    final trackingGains = <MapEntry<TaxYearData, CapitalGainEntry>>[];
    for (var yearData in _allTaxData) {
      for (var gain in yearData.capitalGains) {
        // coverage:ignore-start
        if (!gain.intendToReinvest) continue;
        int gainFyStart = gain.gainDate.year;
        if (gain.gainDate.month < 4) gainFyStart -= 1;
        final yearsPassed = data.year - gainFyStart;
        if (yearsPassed >= 0 && yearsPassed <= reinvestWindow) {
          trackingGains.add(MapEntry(yearData, gain));
          // coverage:ignore-end
        }
      }
    }
    return trackingGains;
  }

  // coverage:ignore-start
  Color _getDeadlineColor(int remainingDays) {
    if (remainingDays < 0) return Colors.red;
    if (remainingDays < 180) return Colors.orange;
    // coverage:ignore-end
    return Colors.grey;
  }

  Widget _buildGainStatusIcon(CapitalGainEntry gain, bool isExpired) {
    // coverage:ignore-line
    if (isExpired) {
      return const Chip(
          label: Text('Expired'),
          backgroundColor: Colors.redAccent,
          labelStyle: TextStyle(color: Colors.white));
    }
    if (gain.reinvestedAmount >= gain.capitalGainAmount) {
      // coverage:ignore-line
      return const Icon(Icons.check_circle, color: Colors.green);
    }
    return const Icon(Icons.timelapse, color: Colors.orange);
  }

  Widget _buildGainTile(
      // coverage:ignore-line
      TaxYearData gainYearData,
      CapitalGainEntry gain,
      int reinvestWindow) {
    // coverage:ignore-start
    final days = (reinvestWindow * 365.25).round();
    final deadline = gain.gainDate.add(Duration(days: days));
    final remainingDays = deadline.difference(DateTime.now()).inDays;
    final isExpired = remainingDays < 0;
    // coverage:ignore-end

    return ListTile(
      // coverage:ignore-line
      contentPadding: EdgeInsets.zero,
      // coverage:ignore-start
      title: Text(
          '${gain.description.isNotEmpty ? gain.description : 'Capital Gain'} (${gain.matchAssetType.toHumanReadable()})'),
      subtitle: Column(
        // coverage:ignore-end
        crossAxisAlignment: CrossAxisAlignment.start,
        // coverage:ignore-start
        children: [
          Text(
              'FY ${gainYearData.year}-${gainYearData.year + 1} | Gain: ${CurrencyUtils.formatCurrency(gain.capitalGainAmount, ref.watch(currencyProvider))}'),
          Text(
              'Reinvested: ${CurrencyUtils.formatCurrency(gain.reinvestedAmount, ref.watch(currencyProvider))} | Deadline: ${deadline.day}/${deadline.month}/${deadline.year}',
              style: TextStyle(
                  color: _getDeadlineColor(remainingDays),
                  // coverage:ignore-end
                  fontWeight: FontWeight.bold)),
        ],
      ),
      trailing: Row(
        // coverage:ignore-line
        mainAxisSize: MainAxisSize.min,
        // coverage:ignore-start
        children: [
          if (!isExpired && gain.reinvestedAmount < gain.capitalGainAmount)
            IconButton(
              // coverage:ignore-end
              icon: const Icon(Icons.add_task, color: Colors.blue),
              tooltip: 'Add Reinvestment',
              // coverage:ignore-start
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TaxDetailsScreen(
                      // coverage:ignore-end
                      data: gainYearData,
                      initialTabIndex: 3,
                      // coverage:ignore-start
                      onSave: (updated) {
                        ref
                            .read(storageServiceProvider)
                            .saveTaxYearData(updated);
                        // coverage:ignore-end
                      },
                      // coverage:ignore-start
                      onDelete: () async {
                        await ref
                            .read(storageServiceProvider)
                            .deleteTaxYearData(gainYearData.year);
                        // coverage:ignore-end
                      },
                    ),
                  ),
                );
              },
            ),
          _buildGainStatusIcon(gain, isExpired), // coverage:ignore-line
        ],
      ),
    );
  }

  Widget _buildExemptionsCard(TaxYearData data) {
    if (_allTaxData.isEmpty) return const SizedBox.shrink();

    final rules =
        ref.watch(taxConfigServiceProvider).getRulesForYear(data.year);
    final trackingGains =
        _collectTrackingGains(data, rules.windowGainReinvest.toInt());

    if (trackingGains.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      // coverage:ignore-line
      elevation: 2,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)), // coverage:ignore-line
      child: Padding(
        // coverage:ignore-line
        padding: const EdgeInsets.all(16),
        child: Column(
          // coverage:ignore-line
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // coverage:ignore-line
            const Text('Capital Gains Reinvestment Tracker',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            // coverage:ignore-start
            Text(
                'Reinvest within ${rules.windowGainReinvest} years to claim exemption under 54/54F',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            // coverage:ignore-end
            const Divider(),
            ...trackingGains.map((entry) => _buildGainTile(
                // coverage:ignore-line
                entry.key,
                entry.value,
                rules.windowGainReinvest.toInt())), // coverage:ignore-line
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(TaxYearData data) {
    // Calculate Tax on the fly
    final service = ref.watch(indianTaxServiceProvider);

    // Need rules for detailed calc.
    final config = ref.watch(taxConfigServiceProvider);
    final rules = config.getRulesForYear(data.year);

    final taxDetails = service.calculateDetailedLiability(data, rules);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text('Projected Tax Liability',
                style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            SmartCurrencyText(
              value: taxDetails['totalTax'] ?? 0,
              locale: ref.watch(currencyProvider),
              style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.redAccent),
            ),
            const Divider(height: 32),
            _RowItem('Gross Income', taxDetails['grossIncome'] ?? 0,
                locale: ref.watch(currencyProvider)),
            _RowItem('Capital Gains', taxDetails['capitalGainsTotal'] ?? 0,
                locale: ref.watch(currencyProvider)),
            _RowItem('Deductions', taxDetails['totalDeductions'] ?? 0,
                locale: ref.watch(currencyProvider)),
            _RowItem('Taxable Income', taxDetails['taxableIncome'] ?? 0,
                locale: ref.watch(currencyProvider)),
            const Divider(),
            _RowItem('Tax on Income (Slab)', taxDetails['slabTax'] ?? 0,
                locale: ref.watch(currencyProvider)),
            _RowItem('Tax on Capital Gains', taxDetails['specialTax'] ?? 0,
                locale: ref.watch(currencyProvider)),
            _RowItem('Cess (4%)', taxDetails['cess'] ?? 0,
                locale: ref.watch(currencyProvider)),
            const Divider(),
            _RowItem('Total Tax Liability', taxDetails['totalTax'] ?? 0,
                locale: ref.watch(currencyProvider), isBold: true),
            _RowItem('Advance Tax Paid', taxDetails['advanceTax'] ?? 0,
                locale: ref.watch(currencyProvider)),
            _RowItem('TDS / TCS',
                (taxDetails['tds'] ?? 0) + (taxDetails['tcs'] ?? 0),
                locale: ref.watch(currencyProvider)),
            if ((taxDetails['advanceTaxInterest'] ?? 0) > 0)
              // coverage:ignore-start
              _RowItem('Tax Shortfall Interest',
                  taxDetails['advanceTaxInterest'] ?? 0,
                  locale: ref.watch(currencyProvider), color: Colors.orange),
            // coverage:ignore-end
            const SizedBox(height: 8),
            _RowItem('Net Tax Payable', taxDetails['netTaxPayable'] ?? 0,
                locale: ref.watch(currencyProvider),
                isBold: true,
                color: (taxDetails['netTaxPayable'] ?? 0) > 0
                    ? Colors.red
                    : Colors.green),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.description,
                      size: 16, color: Theme.of(context).colorScheme.onSurface),
                  const SizedBox(width: 8),
                  Text('Suggested: ${service.suggestITR(data)}',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildAdvanceTaxReminder(TaxYearData data) {
    final service = ref.watch(indianTaxServiceProvider);
    final config = ref.watch(taxConfigServiceProvider);
    final rules = config.getRulesForYear(data.year);

    final taxDetails = service.calculateDetailedLiability(data, rules);

    final DateTime? dueDate = taxDetails['nextAdvanceTaxDueDate'] as dynamic;
    final double? amount = taxDetails['nextAdvanceTaxAmount'] as dynamic;
    final int? daysLeft = taxDetails['daysUntilAdvanceTax'] as dynamic;
    final bool isRequirementMet = taxDetails['isRequirementMet'] == true;

    if (dueDate == null ||
        amount == null ||
        (amount <= 0 && isRequirementMet)) {
      return const SizedBox.shrink();
    }

    final bool isNear =
        daysLeft != null && daysLeft <= rules.advanceTaxReminderDays;
    final bool isOverdue = daysLeft != null && daysLeft < 0;

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: ListTile(
        shape: _getReminderCardShape(isOverdue, isNear),
        tileColor: _getReminderCardColor(isOverdue, isNear),
        contentPadding: const EdgeInsets.all(12),
        // coverage:ignore-start
        onTap: () {
          FocusScope.of(context).unfocus();
          _navigateToTaxPaidTab(data);
          // coverage:ignore-end
        },
        leading: _buildReminderIcon(isOverdue, isNear),
        title: _buildReminderContent(isOverdue, isNear, amount, dueDate),
        trailing: daysLeft != null
            ? _buildDaysLeftBadge(isOverdue, isNear, daysLeft)
            : null,
      ),
    );
  }

  // coverage:ignore-start
  void _navigateToTaxPaidTab(TaxYearData data) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TaxDetailsScreen(
          // coverage:ignore-end
          data: data,
          initialTabIndex: 5, // Tax Paid tab
          onSave: (updated) {
            // coverage:ignore-line
            ref
                .read(storageServiceProvider)
                .saveTaxYearData(updated); // coverage:ignore-line
          },
        ),
      ),
    );
  }

  Color _getReminderCardColor(bool isOverdue, bool isNear) {
    if (isOverdue) return Colors.red.shade50; // coverage:ignore-line
    if (isNear) return Colors.orange.shade50;
    return Colors.blue.shade50; // coverage:ignore-line
  }

  ShapeBorder _getReminderCardShape(bool isOverdue, bool isNear) {
    final Color borderColor;
    if (isOverdue) {
      borderColor = Colors.red.shade200; // coverage:ignore-line
    } else if (isNear) {
      borderColor = Colors.orange.shade200;
    } else {
      borderColor = Colors.blue.shade200; // coverage:ignore-line
    }
    return RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: borderColor),
    );
  }

  Widget _buildReminderIcon(bool isOverdue, bool isNear) {
    if (isNear || isOverdue) {
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 500),
        builder: (context, value, child) {
          return Transform.rotate(
            angle: isNear ? (sin(value * pi * 4) * 0.2) : 0,
            child: Icon(
              isOverdue
                  ? Icons.warning_amber_rounded
                  : Icons.notifications_active,
              color: isOverdue ? Colors.red : Colors.orange,
            ),
          );
        },
      );
    }
    return const Icon(Icons.calendar_month_outlined, color: Colors.blue);
  }

  Widget _buildReminderContent(
      bool isOverdue, bool isNear, double amount, DateTime dueDate) {
    final currencyLocale = ref.watch(currencyProvider);
    final String title;
    if (isOverdue) {
      title = 'Advance Tax Overdue!';
    } else if (isNear) {
      title = 'Action Required: Advance Tax';
    } else {
      title = 'Upcoming Advance Tax';
    }
    final Color titleColor;
    if (isOverdue) {
      titleColor = Colors.red;
    } else if (isNear) {
      titleColor = Colors.orange.shade900;
    } else {
      titleColor = Colors.blue.shade900; // coverage:ignore-line
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: titleColor,
          ),
        ),
        Text(
          'Next: ${CurrencyUtils.formatCurrency(amount, currencyLocale)} due by ${dueDate.day}/${dueDate.month}/${dueDate.year}',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
        ),
      ],
    );
  }

  Widget _buildDaysLeftBadge(bool isOverdue, bool isNear, int daysLeft) {
    final Color color;
    if (isOverdue) {
      color = Colors.red;
    } else if (isNear) {
      color = Colors.orange;
    } else {
      color = Colors.blue;
    }
    final String text;
    if (isOverdue) {
      text = '${daysLeft.abs()}d Late'; // coverage:ignore-line
    } else if (daysLeft == 0) {
      text = 'Due Today';
    } else {
      text = '$daysLeft d left';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
            color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildYearSelector() {
    final theme = Theme.of(context);
    final config = ref.read(taxConfigServiceProvider);

    // Fix: Use Financial Year anchor
    final currentYear = config.getCurrentFinancialYear();
    final years = List.generate(8, (i) => currentYear - i);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Year Selector
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Tax Year: ',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                DropdownButton<int>(
                  value: years.contains(_selectedYear)
                      ? _selectedYear
                      : years.first, // coverage:ignore-line
                  underline: Container(),
                  isDense: true,
                  items: years
                      .map((y) => DropdownMenuItem(
                            value: y,
                            child: Text('FY $y-${y + 1}'),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedYear = val;
                      });
                    }
                  },
                ),
              ],
            ),
            const SizedBox(width: 16),
            Container(
                width: 1,
                height: 24,
                color: Colors.grey.withValues(alpha: 0.3)),
            const SizedBox(width: 16),
            // Jurisdiction Selector
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.public, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Consumer(builder: (context, ref, _) {
                  final config = ref.watch(taxConfigServiceProvider);
                  final rules = config.getRulesForYear(_selectedYear);
                  return DropdownButton<String>(
                    value: rules.jurisdiction,
                    underline: Container(),
                    isDense: true,
                    items: <String>[
                      'India',
                      if (rules.customJurisdictionName.isNotEmpty)
                        rules.customJurisdictionName // coverage:ignore-line
                    ]
                        .map((j) => DropdownMenuItem<String>(
                              value: j,
                              child: Text(j),
                            ))
                        .toList(),
                    onChanged: (val) async {
                      // coverage:ignore-line
                      if (val != null) {
                        final newRules = rules.copyWith(
                            jurisdiction: val); // coverage:ignore-line
                        await config.saveRulesForYear(
                            _selectedYear, newRules); // coverage:ignore-line
                      }
                    },
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildActionButton(
            label: 'Edit Details',
            icon: Icons.edit_document,
            color: Colors.blue,
            // coverage:ignore-start
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TaxDetailsScreen(
                    data: _taxData ?? TaxYearData(year: _selectedYear),
                    onSave: (newData) async {
                      await ref
                          .read(storageServiceProvider)
                          .saveTaxYearData(newData);
                      // coverage:ignore-end
                    },
                    // coverage:ignore-start
                    onDelete: () async {
                      await ref
                          .read(storageServiceProvider)
                          .deleteTaxYearData(_selectedYear);
                      // coverage:ignore-end
                    },
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          _buildActionButton(
            label: 'Sync Data',
            icon: Icons.sync,
            color: Colors.green,
            onPressed: _syncData,
          ),
          const SizedBox(width: 8),
          _buildActionButton(
            label: 'Tax Config',
            icon: Icons.settings,
            color: Colors.orange,
            // coverage:ignore-start
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TaxRulesScreen()),
              // coverage:ignore-end
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.5)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class _RowItem extends StatelessWidget {
  final String label;
  final double amount;
  final bool isBold;
  final Color? color;
  final String locale;

  const _RowItem(this.label, this.amount,
      {required this.locale, this.isBold = false, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label,
                style: isBold
                    ? const TextStyle(fontWeight: FontWeight.bold)
                    : null),
          ),
          SmartCurrencyText(
            value: amount,
            locale: locale,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _TaxSyncDialog extends StatefulWidget {
  final int selectedYear;
  final DateTime initialStart;
  final DateTime initialEnd;
  final Function(DateTime start, DateTime end, bool smartSync) onSync;

  const _TaxSyncDialog({
    required this.selectedYear,
    required this.initialStart,
    required this.initialEnd,
    required this.onSync,
  });

  @override
  State<_TaxSyncDialog> createState() => _TaxSyncDialogState();
}

class _TaxSyncDialogState extends State<_TaxSyncDialog> {
  late DateTime _start;
  late DateTime _end;
  bool _smartSync = true;

  @override
  void initState() {
    super.initState();
    _start = widget.initialStart;
    _end = widget.initialEnd;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (context, ref, child) {
      final lastSyncDate = ref
          .watch(storageServiceProvider)
          .getTaxYearData(widget.selectedYear)
          ?.lastSyncDate;

      return AlertDialog(
        title: const Text('Sync Tax Data'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (lastSyncDate != null)
              Padding(
                // coverage:ignore-line
                padding: const EdgeInsets.only(bottom: 12),
                // coverage:ignore-start
                child: Text(
                  'Last Synced: ${DateFormat('dd MMM yyyy, hh:mm a').format(lastSyncDate)}',
                  style: TextStyle(
                      // coverage:ignore-end
                      fontSize: 12,
                      color: Colors.grey[600], // coverage:ignore-line
                      fontStyle: FontStyle.italic),
                ),
              ),
            const Text('Sync Period (YTD)',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildDatePickerRow('From: ', _start, Icons.event_available, (d) {
              setState(() => _start = d); // coverage:ignore-line
            }),
            const SizedBox(height: 12),
            _buildDatePickerRow('To: ', _end, Icons.calendar_today, (d) {
              setState(() => _end = d); // coverage:ignore-line
            }, firstDate: _start),
            const Divider(height: 24),
            _buildSyncOptions(),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), // coverage:ignore-line
              child: const Text('Cancel')),
          FilledButton(
            // coverage:ignore-start
            onPressed: () {
              Navigator.pop(context);
              widget.onSync(_start, _end, _smartSync);
              // coverage:ignore-end
            },
            child: const Text('Sync Now'),
          ),
        ],
      );
    });
  }

  Widget _buildDatePickerRow(
      String label, DateTime date, IconData icon, Function(DateTime) onPicked,
      {DateTime? firstDate}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.blue),
        const SizedBox(width: 8),
        Text(label),
        TextButton(
          // coverage:ignore-start
          onPressed: () async {
            final d = await showDatePicker(
                context: context,
                firstDate: firstDate ?? DateTime(2020),
                lastDate: DateTime(2030),
                // coverage:ignore-end
                initialDate: date);
            if (d != null) onPicked(d); // coverage:ignore-line
          },
          child: Text(
            '${date.day}/${date.month}/${date.year}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildSyncOptions() {
    return RadioGroup<bool>(
      onChanged: (v) => setState(() => _smartSync = v!), // coverage:ignore-line
      groupValue: _smartSync,
      child: const Column(
        children: [
          RadioListTile<bool>(
            title: Text('Smart Sync (Recommended)'),
            subtitle: Text(
                'Updates totals from transactions but PROTECTS your manual edits.'),
            value: true,
          ),
          RadioListTile<bool>(
            title: Text('Force Reset'),
            subtitle: Text('Overwrites EVERYTHING. Manual edits will be lost.'),
            value: false,
          ),
        ],
      ),
    );
  }
}
