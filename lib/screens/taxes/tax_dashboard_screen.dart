import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/taxes/tax_data_fetcher.dart';
import '../../services/taxes/tax_config_service.dart';
import '../../services/taxes/indian_tax_service.dart';
import '../../widgets/smart_currency_text.dart';
import '../../models/taxes/tax_data.dart';
import '../../models/taxes/tax_data_models.dart';
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
          _loadData();
        });
      }
    } catch (e) {
      if (mounted) {
        // Fallback or show error
        setState(() {
          _isServiceInitialized = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error initializing tax data: $e')));
      }
    }
  }

  // Load TaxYearData from Hive
  void _loadData() {
    final storage = ref.read(storageServiceProvider);
    final savedData = storage.getTaxYearData(_selectedYear);
    final allData = storage.getAllTaxYearData();

    setState(() {
      _taxData = savedData ?? TaxYearData(year: _selectedYear);
      _allTaxData = allData..sort((a, b) => b.year.compareTo(a.year));
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isServiceInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

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
                    builder: (_) => const InsurancePortfolioScreen())),
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
            const SizedBox(height: 16),
            if (_taxData != null) ...[
              _buildSummaryCard(_taxData!),
              const SizedBox(height: 16),
              _buildExemptionsCard(_taxData!),
            ],
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
    // Get FY Start Month
    final config = ref.read(taxConfigServiceProvider);
    final rules = config.getRulesForYear(_selectedYear);
    final startMonth = rules.financialYearStartMonth;

    // Fixed Start Date (FY Start)
    DateTime start = DateTime(_selectedYear, startMonth, 1);

    // Default End Date (Today or FY End)
    DateTime defaultEnd = DateTime.now();
    DateTime fyEnd;
    if (startMonth == 1) {
      fyEnd = DateTime(_selectedYear, 12, 31);
    } else {
      fyEnd = DateTime(_selectedYear + 1, startMonth, 1)
          .subtract(const Duration(days: 1));
    }

    if (defaultEnd.isAfter(fyEnd)) {
      defaultEnd = fyEnd;
    }
    if (defaultEnd.isBefore(start)) {
      defaultEnd = start;
    }

    DateTime end = defaultEnd;
    bool smartSync = true; // Default to Smart Sync

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (context, setStateBuilder) {
        return AlertDialog(
          title: const Text('Sync Tax Data'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Sync Period (YTD)',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              // Start Date (Editable now)
              Row(
                children: [
                  const Icon(Icons.event_available,
                      size: 16, color: Colors.blue),
                  const SizedBox(width: 8),
                  const Text('From: '),
                  TextButton(
                    onPressed: () async {
                      final d = await showDatePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                          initialDate: start);
                      if (d != null) setStateBuilder(() => start = d);
                    },
                    child: Text(
                      '${start.day}/${start.month}/${start.year}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // End Date (Editable)
              Row(
                children: [
                  const Icon(Icons.calendar_today,
                      size: 16, color: Colors.blue),
                  const SizedBox(width: 8),
                  const Text('To: '),
                  TextButton(
                    onPressed: () async {
                      final d = await showDatePicker(
                          context: context,
                          firstDate: start,
                          lastDate: DateTime(2030),
                          initialDate: end);
                      if (d != null) setStateBuilder(() => end = d);
                    },
                    child: Text('${end.day}/${end.month}/${end.year}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ],
              ),
              const Divider(height: 24),
              RadioGroup<bool>(
                groupValue: smartSync,
                onChanged: (v) => setStateBuilder(() => smartSync = v!),
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
                      subtitle: Text(
                          'Overwrites EVERYTHING. Manual edits will be lost.'),
                      value: false,
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                Navigator.pop(context);
                await _performSync(fetcher, start, end, true,
                    forceReset: !smartSync);
              },
              child: const Text('Sync Now'),
            ),
          ],
        );
      }),
    );
  }

  Future<void> _performSync(
      TaxDataFetcher fetcher, DateTime start, DateTime end, bool smartSync,
      {bool forceReset = false}) async {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Syncing...')));

    try {
      final result = await fetcher.fetchAndAggregate(_selectedYear,
          customStart: start, customEnd: end);
      final newData = result.data;

      final mergedHP = await _mergeHousePropertyInterest(start, end);
      final finalData =
          _buildFinalSyncData(newData, mergedHP, forceReset: forceReset);

      setState(() => _taxData = finalData);
      await ref.read(storageServiceProvider).saveTaxYearData(finalData);

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Sync Complete')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Sync Failed: $e')));
      }
    }
  }

  Future<List<HouseProperty>> _mergeHousePropertyInterest(
      DateTime start, DateTime end) async {
    List<HouseProperty> mergedHP = [];
    if (_taxData != null) {
      mergedHP = List.from(_taxData!.houseProperties);
    }

    final loans = await ref.read(loansProvider.future);

    for (int i = 0; i < mergedHP.length; i++) {
      final hp = mergedHP[i];
      if (hp.loanId == null) continue;

      try {
        final loan = loans.firstWhere((l) => l.id == hp.loanId);
        double interest = 0;
        for (var txn in loan.transactions) {
          if (txn.date.isAfter(start.subtract(const Duration(days: 1))) &&
              txn.date.isBefore(end.add(const Duration(days: 1)))) {
            interest += txn.interestComponent;
          }
        }
        if (interest > 0) {
          mergedHP[i] = HouseProperty(
            name: hp.name,
            isSelfOccupied: hp.isSelfOccupied,
            rentReceived: hp.rentReceived,
            municipalTaxes: hp.municipalTaxes,
            interestOnLoan: interest,
            loanId: hp.loanId,
          );
        }
      } catch (e) {
        // Loan not found
      }
    }
    return mergedHP;
  }

  TaxYearData _buildFinalSyncData(
      TaxYearData newData, List<HouseProperty> mergedHP,
      {required bool forceReset}) {
    final hpToUse = mergedHP.isNotEmpty ? mergedHP : newData.houseProperties;

    if (forceReset) {
      return newData.copyWith(
        salary: _taxData?.salary ?? newData.salary,
        houseProperties: hpToUse,
        lockedFields: [],
        lastSyncDate: DateTime.now(),
      );
    }

    final old = _taxData;
    if (old != null && old.lockedFields.isNotEmpty) {
      final locked = old.lockedFields;
      bool isLocked(String id) => locked.contains(id);

      return newData.copyWith(
        salary: old.salary,
        houseProperties: hpToUse,
        agricultureIncome: isLocked('agri.income')
            ? old.agricultureIncome
            : newData.agricultureIncome,
        advanceTax:
            isLocked('tax.advance') ? old.advanceTax : newData.advanceTax,
        lockedFields: old.lockedFields,
        lastSyncDate: DateTime.now(),
      );
    }

    // No locks, overwrite but PROTECT manual salary
    return newData.copyWith(
      salary: _taxData?.salary ?? newData.salary,
      houseProperties: hpToUse,
      lastSyncDate: DateTime.now(),
    );
  }

  List<MapEntry<TaxYearData, CapitalGainEntry>> _collectTrackingGains(
      TaxYearData data, int reinvestWindow) {
    final trackingGains = <MapEntry<TaxYearData, CapitalGainEntry>>[];
    for (var yearData in _allTaxData) {
      for (var gain in yearData.capitalGains) {
        if (!gain.intendToReinvest) continue;
        int gainFyStart = gain.gainDate.year;
        if (gain.gainDate.month < 4) gainFyStart -= 1;
        final yearsPassed = data.year - gainFyStart;
        if (yearsPassed >= 0 && yearsPassed <= reinvestWindow) {
          trackingGains.add(MapEntry(yearData, gain));
        }
      }
    }
    return trackingGains;
  }

  Color _getDeadlineColor(int remainingDays) {
    if (remainingDays < 0) return Colors.red;
    if (remainingDays < 180) return Colors.orange;
    return Colors.grey;
  }

  Widget _buildGainStatusIcon(CapitalGainEntry gain, bool isExpired) {
    if (isExpired) {
      return const Chip(
          label: Text('Expired'),
          backgroundColor: Colors.redAccent,
          labelStyle: TextStyle(color: Colors.white));
    }
    if (gain.reinvestedAmount >= gain.capitalGainAmount) {
      return const Icon(Icons.check_circle, color: Colors.green);
    }
    return const Icon(Icons.timelapse, color: Colors.orange);
  }

  Widget _buildGainTile(
      TaxYearData gainYearData, CapitalGainEntry gain, int reinvestWindow) {
    final days = (reinvestWindow * 365.25).round();
    final deadline = gain.gainDate.add(Duration(days: days));
    final remainingDays = deadline.difference(DateTime.now()).inDays;
    final isExpired = remainingDays < 0;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
          '${gain.description.isNotEmpty ? gain.description : 'Capital Gain'} (${gain.matchAssetType.toHumanReadable()})'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              'FY ${gainYearData.year}-${gainYearData.year + 1} | Gain: ${CurrencyUtils.formatCurrency(gain.capitalGainAmount, ref.watch(currencyProvider))}'),
          Text(
              'Reinvested: ${CurrencyUtils.formatCurrency(gain.reinvestedAmount, ref.watch(currencyProvider))} | Deadline: ${deadline.day}/${deadline.month}/${deadline.year}',
              style: TextStyle(
                  color: _getDeadlineColor(remainingDays),
                  fontWeight: FontWeight.bold)),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isExpired && gain.reinvestedAmount < gain.capitalGainAmount)
            IconButton(
              icon: const Icon(Icons.add_task, color: Colors.blue),
              tooltip: 'Add Reinvestment',
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TaxDetailsScreen(
                      data: gainYearData,
                      initialTabIndex: 3,
                      onSave: (updated) {
                        ref
                            .read(storageServiceProvider)
                            .saveTaxYearData(updated);
                      },
                      onDelete: () async {
                        await ref
                            .read(storageServiceProvider)
                            .deleteTaxYearData(gainYearData.year);
                        _loadData();
                      },
                    ),
                  ),
                );
                _loadData();
              },
            ),
          _buildGainStatusIcon(gain, isExpired),
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

    if (trackingGains.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Capital Gains Reinvestment Tracker',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
                'Reinvest within ${rules.windowGainReinvest} years to claim exemption under 54/54F',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const Divider(),
            ...trackingGains.map((entry) => _buildGainTile(
                entry.key, entry.value, rules.windowGainReinvest.toInt())),
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
            _buildRow('Gross Income', taxDetails['grossIncome'] ?? 0),
            _buildRow('Capital Gains', taxDetails['capitalGainsTotal'] ?? 0),
            _buildRow('Deductions', taxDetails['totalDeductions'] ?? 0),
            _buildRow('Taxable Income', taxDetails['taxableIncome'] ?? 0),
            const Divider(),
            _buildRow('Tax on Income (Slab)', taxDetails['slabTax'] ?? 0),
            _buildRow('Tax on Capital Gains', taxDetails['specialTax'] ?? 0),
            _buildRow('Cess (4%)', taxDetails['cess'] ?? 0),
            const Divider(),
            _buildRow('Total Tax Liability', taxDetails['totalTax'] ?? 0,
                isBold: true),
            _buildRow('Advance Tax', taxDetails['advanceTax'] ?? 0),
            _buildRow('TDS / TCS',
                (taxDetails['tds'] ?? 0) + (taxDetails['tcs'] ?? 0)),
            const SizedBox(height: 8),
            _buildRow('Net Tax Payable', taxDetails['netTaxPayable'] ?? 0,
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
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
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

  Widget _buildRow(String label, double amount,
      {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
                  isBold ? const TextStyle(fontWeight: FontWeight.bold) : null),
          SmartCurrencyText(
            value: amount,
            locale: ref.watch(currencyProvider),
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
        ],
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
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Year Selector
            Row(
              children: [
                const Text('Tax Year: ',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                DropdownButton<int>(
                  value: years.contains(_selectedYear)
                      ? _selectedYear
                      : years.first,
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
                        _loadData();
                      });
                    }
                  },
                ),
              ],
            ),
            Container(
                width: 1,
                height: 24,
                color: Colors.grey.withValues(alpha: 0.3)),
            // Jurisdiction Selector
            Row(
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
                    items: [
                      'India',
                      if (rules.customJurisdictionName.isNotEmpty)
                        rules.customJurisdictionName
                    ]
                        .map((j) => DropdownMenuItem(
                              value: j,
                              child: Text(j),
                            ))
                        .toList(),
                    onChanged: (val) async {
                      if (val != null) {
                        final newRules = rules.copyWith(jurisdiction: val);
                        await config.saveRulesForYear(_selectedYear, newRules);
                        _loadData();
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
                      _loadData();
                    },
                    onDelete: () async {
                      await ref
                          .read(storageServiceProvider)
                          .deleteTaxYearData(_selectedYear);
                      _loadData();
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
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TaxRulesScreen()),
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
