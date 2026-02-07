import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/taxes/tax_data_fetcher.dart';
import '../../services/taxes/tax_config_service.dart';
import '../../services/taxes/indian_tax_service.dart';
import '../../widgets/pure_icons.dart';
import '../../widgets/smart_currency_text.dart';
import '../../models/taxes/tax_data.dart';
import '../../models/taxes/tax_data_models.dart';
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
  bool _isServiceInitialized = false;

  @override
  void initState() {
    super.initState();
    _initServices();
  }

  Future<void> _initServices() async {
    await ref.read(taxConfigServiceProvider).init();
    if (mounted) {
      setState(() {
        _isServiceInitialized = true;
        _loadData();
      });
    }
  }

  // Placeholder load - in real persistence we'd save TaxYearData to Hive too
  // For now, we start fresh or empty.
  void _loadData() {
    setState(() {
      _taxData = TaxYearData(year: _selectedYear);
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
        title: const Text('Tax Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Sync from Transactions',
            onPressed: _syncData,
          ),
          IconButton(
            icon: const Icon(Icons.health_and_safety),
            tooltip: 'Insurance Portfolio',
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const InsurancePortfolioScreen())),
          ),
          IconButton(
            icon: PureIcons.settings(),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const TaxRulesScreen())),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => TaxDetailsScreen(
                        data: _taxData ?? TaxYearData(year: _selectedYear),
                        onSave: (newData) {
                          setState(() => _taxData = newData);
                        },
                      )));
        },
        label: const Text('Edit Details'),
        icon: const Icon(Icons.edit),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildYearSelector(),
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
    DateTime start = DateTime(_selectedYear, 4, 1);
    DateTime end = DateTime(_selectedYear + 1, 3, 31);
    bool overwriteAll = true;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (context, setStateBuilder) {
        return AlertDialog(
          title: const Text('Sync Tax Data'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select Date Range for Transactions:'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text('${start.day}/${start.month}/${start.year}'),
                      onPressed: () async {
                        final d = await showDatePicker(
                            context: context,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2030),
                            initialDate: start);
                        if (d != null) setStateBuilder(() => start = d);
                      },
                    ),
                  ),
                  const Text(' - '),
                  Expanded(
                    child: TextButton.icon(
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text('${end.day}/${end.month}/${end.year}'),
                      onPressed: () async {
                        final d = await showDatePicker(
                            context: context,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2030),
                            initialDate: end);
                        if (d != null) setStateBuilder(() => end = d);
                      },
                    ),
                  ),
                ],
              ),
              const Divider(),
              const Divider(),
              RadioListTile<bool>(
                title: const Text('Overwrite All Headers'),
                subtitle: const Text('Replaces Salary, Business, CG, Other'),
                value: true,
                // ignore: deprecated_member_use
                groupValue: overwriteAll,
                // ignore: deprecated_member_use
                onChanged: (v) => setStateBuilder(() => overwriteAll = v!),
              ),
              RadioListTile<bool>(
                title: const Text('Smart Merge (Interest Only)'),
                subtitle: const Text(
                    'Updates Interest for tagged loans only. Keeps other entries.'),
                value: false,
                // ignore: deprecated_member_use
                groupValue: overwriteAll,
                // ignore: deprecated_member_use
                onChanged: (v) => setStateBuilder(() => overwriteAll = v!),
              ),
              if (overwriteAll)
                const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Text(
                      'Note: Manual entries in Rent/Tax will be preserved if "Loan Tag" is used.',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
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
                await _performSync(fetcher, start, end, overwriteAll);
              },
              child: const Text('Sync Now'),
            ),
          ],
        );
      }),
    );
  }

  Future<void> _performSync(TaxDataFetcher fetcher, DateTime start,
      DateTime end, bool overwriteAll) async {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Syncing...')));

    try {
      final result = await fetcher.fetchAndAggregate(_selectedYear,
          customStart: start, customEnd: end);
      final newData = result.data;

      // Preserve existing HP config but update Interest
      List<HouseProperty> mergedHP = [];
      if (_taxData != null) {
        mergedHP = List.from(_taxData!.houseProperties);
      }

      // Update Interest for each HP
      // Update Interest for each HP
      final loans = await ref.read(
          loansProvider.future); // Assume loansProvider returns List<Loan>

      for (int i = 0; i < mergedHP.length; i++) {
        final hp = mergedHP[i];
        if (hp.loanId != null) {
          try {
            final loan = loans.firstWhere((l) => l.id == hp.loanId);

            // Calculate Interest from Loan Transactions directly
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
                rentReceived: hp.rentReceived, // Keep manual
                municipalTaxes: hp.municipalTaxes, // Keep manual
                interestOnLoan: interest, // UPDATE
                loanId: hp.loanId,
              );
            }
          } catch (e) {
            // Loan not found or other error, skip update
          }
        }
      }

      TaxYearData finalData;

      if (overwriteAll) {
        // Overwrite everything EXCEPT House Property Structure (we use mergedHP)
        finalData = newData.copyWith(
          houseProperties:
              mergedHP.isNotEmpty ? mergedHP : newData.houseProperties,
        );
      } else {
        // Only update HP Interest, keep everything else from _taxData
        finalData = (_taxData ?? newData).copyWith(
          houseProperties: mergedHP,
        );
      }

      setState(() {
        _taxData = finalData;
      });

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

  Widget _buildExemptionsCard(TaxYearData data) {
    final rules =
        ref.watch(taxConfigServiceProvider).getRulesForYear(data.year);
    if (data.capitalGains.isEmpty) return const SizedBox.shrink();

    // Filter relevant gains for tracking (Active Window)
    final trackingGains = data.capitalGains.where((gain) {
      // Calculate years passed
      int gainFyStart = gain.gainDate.year;
      if (gain.gainDate.month < 4) gainFyStart -= 1;
      int currentFYStart = data.year;
      return (currentFYStart - gainFyStart) <= rules.windowGainReinvest;
    }).toList();

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
            ...trackingGains.map((gain) {
              final deadline = DateTime(
                  gain.gainDate.year + rules.windowGainReinvest,
                  gain.gainDate.month,
                  gain.gainDate.day);
              final remainingDays = deadline.difference(DateTime.now()).inDays;

              // Warning color if deadline is close (< 180 days)
              final isUrgent = remainingDays > 0 && remainingDays < 180;
              final isExpired = remainingDays < 0;

              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                    '${gain.description.isNotEmpty ? gain.description : 'Capital Gain'} (${gain.matchAssetType.name})'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        'Gain: ₹${gain.capitalGainAmount.toStringAsFixed(0)} | Reinvested: ₹${gain.reinvestedAmount.toStringAsFixed(0)}'),
                    Text(
                        'Deadline: ${deadline.day}/${deadline.month}/${deadline.year}',
                        style: TextStyle(
                            color: isExpired
                                ? Colors.red
                                : (isUrgent ? Colors.orange : Colors.grey),
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                trailing: isExpired
                    ? const Chip(
                        label: Text('Expired'),
                        backgroundColor: Colors.redAccent,
                        labelStyle: TextStyle(color: Colors.white))
                    : gain.reinvestedAmount >= gain.capitalGainAmount
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : const Icon(Icons.timelapse, color: Colors.orange),
              );
            }),
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
              locale: 'en_IN',
              style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.redAccent),
            ),
            const Divider(height: 32),
            _buildRow('Gross Income', taxDetails['grossIncome'] ?? 0),
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
                  color: Colors.blueGrey.shade50,
                  borderRadius: BorderRadius.circular(8)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.description,
                      size: 16, color: Colors.blueGrey),
                  const SizedBox(width: 8),
                  Text('Suggested: ${service.suggestITR(data)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.blueGrey)),
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
            locale: 'en_IN',
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color ?? Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYearSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Year Selector
          Row(
            children: [
              const Text('FY: ', style: TextStyle(fontWeight: FontWeight.bold)),
              DropdownButton<int>(
                value: _selectedYear,
                underline: Container(),
                isDense: true,
                items: [2023, 2024, 2025, 2026]
                    .map((y) => DropdownMenuItem(
                          value: y,
                          child: Text('$y-${y + 1}'),
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
              width: 1, height: 24, color: Colors.grey.withValues(alpha: 0.3)),
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
                            child:
                                Text(j, style: const TextStyle(fontSize: 14)),
                          ))
                      .toList(),
                  onChanged: (val) async {
                    if (val != null) {
                      // Update Rules
                      final newRules = rules.copyWith(jurisdiction: val);
                      await config.saveRulesForYear(_selectedYear, newRules);
                      if (context.mounted) {
                        setState(() {}); // Refresh UI
                      }
                    }
                  },
                );
              }),
            ],
          ),
        ],
      ),
    );
  }
}
