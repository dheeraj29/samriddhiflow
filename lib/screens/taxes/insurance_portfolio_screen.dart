import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/taxes/insurance_policy.dart';
import '../../models/taxes/tax_rules.dart';
import '../../services/taxes/insurance_tax_service.dart';
import '../../services/taxes/tax_config_service.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import '../../providers.dart';
import '../../widgets/pure_icons.dart';

class InsurancePortfolioScreen extends ConsumerStatefulWidget {
  const InsurancePortfolioScreen({super.key});

  @override
  ConsumerState<InsurancePortfolioScreen> createState() =>
      _InsurancePortfolioScreenState();
}

class _InsurancePortfolioScreenState
    extends ConsumerState<InsurancePortfolioScreen>
    with SingleTickerProviderStateMixin {
  late Box<InsurancePolicy> _box;
  bool _isInit = false;
  late TabController _tabController;

  // Tax Rule Controllers
  late TextEditingController _limitUlipCtrl;
  late TextEditingController _limitNonUlipCtrl;

  // Local state for rules
  List<InsurancePremiumRule> _premiumRules = [];
  DateTime _dateUlip = DateTime(2021, 2, 1);
  DateTime _dateNonUlip = DateTime(2023, 4, 1);
  bool _isInsuranceAggregateLimitEnabled = true;
  bool _isInsurancePremiumPercentEnabled = true;
  final int _selectedYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initFromStorage();
    });
  }

  void _initFromStorage() {
    final storage = ref.read(storageServiceProvider);
    _box = storage.getInsurancePoliciesBox();
    _loadTaxRules();
    setState(() => _isInit = true);
  }

  void _loadTaxRules() {
    final config = ref.read(taxConfigServiceProvider);
    final rules = config.getRulesForYear(_selectedYear);

    _limitUlipCtrl = TextEditingController(
        text: rules.limitInsuranceULIP.toStringAsFixed(0));
    _limitNonUlipCtrl = TextEditingController(
        text: rules.limitInsuranceNonULIP.toStringAsFixed(0));

    _dateUlip = rules.dateEffectiveULIP;
    _dateNonUlip = rules.dateEffectiveNonULIP;
    _isInsuranceAggregateLimitEnabled = rules.isInsuranceAggregateLimitEnabled;
    _isInsurancePremiumPercentEnabled = rules.isInsurancePremiumPercentEnabled;

    // Copy list to avoid mutation issues
    _premiumRules = List.from(rules.insurancePremiumRules);

    // Fallback if empty (should not happen with default constructor but safe to add)
    if (_premiumRules.isEmpty) {
      _premiumRules = [
        InsurancePremiumRule(DateTime(2003, 4, 1), 20.0),
        InsurancePremiumRule(DateTime(2012, 4, 1), 10.0),
      ];
    }
    // Sort by date desc for display? Or asc?
    _premiumRules.sort((a, b) => a.startDate.compareTo(b.startDate));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _limitUlipCtrl.dispose();
    _limitNonUlipCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveRules() async {
    final config = ref.read(taxConfigServiceProvider);
    final current = config.getRulesForYear(_selectedYear);

    final updated = current.copyWith(
        limitInsuranceULIP: double.tryParse(_limitUlipCtrl.text) ?? 250000,
        limitInsuranceNonULIP:
            double.tryParse(_limitNonUlipCtrl.text) ?? 500000,
        dateEffectiveULIP: _dateUlip,
        dateEffectiveNonULIP: _dateNonUlip,
        isInsuranceAggregateLimitEnabled: _isInsuranceAggregateLimitEnabled,
        isInsurancePremiumPercentEnabled: _isInsurancePremiumPercentEnabled,
        insurancePremiumRules: _premiumRules);

    await config.saveRulesForYear(_selectedYear, updated);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Tax Rules Updated')));
    }
  }

  void _addOrEditPolicy([InsurancePolicy? existing, dynamic key]) {
    final nameCtrl = TextEditingController(text: existing?.policyName ?? '');
    final premiumCtrl =
        TextEditingController(text: existing?.annualPremium.toString() ?? '');
    final sumAssuredCtrl =
        TextEditingController(text: existing?.sumAssured.toString() ?? '');
    DateTime selectedDate = existing?.startDate ?? DateTime.now();
    bool isUlip = existing?.isUnitLinked ?? false;
    DateTime maturityDate = existing?.maturityDate ??
        selectedDate.add(const Duration(days: 365 * 10));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (context, setState) {
        return AlertDialog(
          title: Text(existing == null ? 'Add Policy' : 'Edit Policy'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: nameCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Policy Name')),
                TextField(
                    controller: premiumCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Annual Premium'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*')),
                    ]),
                TextField(
                    controller: sumAssuredCtrl,
                    decoration: const InputDecoration(labelText: 'Sum Assured'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*')),
                    ]),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('Issue Date: '),
                    TextButton(
                      onPressed: () async {
                        final d = await showDatePicker(
                            context: context,
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                            initialDate: selectedDate);
                        if (d != null) setState(() => selectedDate = d);
                      },
                      child: Text(
                          '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}'),
                    )
                  ],
                ),
                Row(
                  children: [
                    const Text('Maturity Date: '),
                    TextButton(
                      onPressed: () async {
                        final d = await showDatePicker(
                            context: context,
                            firstDate: selectedDate,
                            lastDate: DateTime(2050),
                            initialDate: maturityDate);
                        if (d != null) setState(() => maturityDate = d);
                      },
                      child: Text(
                          '${maturityDate.day}/${maturityDate.month}/${maturityDate.year}'),
                    )
                  ],
                ),
                CheckboxListTile(
                  title: const Text('Is ULIP?'),
                  value: isUlip,
                  onChanged: (v) => setState(() => isUlip = v ?? false),
                )
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () {
                  final newPolicy = InsurancePolicy.create(
                    name: nameCtrl.text,
                    number: 'POL-${DateTime.now().millisecondsSinceEpoch}',
                    premium: double.tryParse(premiumCtrl.text) ?? 0,
                    sumAssured: double.tryParse(sumAssuredCtrl.text) ?? 0,
                    start: selectedDate,
                    maturity: maturityDate,
                    isUlip: isUlip,
                    isTaxExempt: null, // Reset status on edit
                  );

                  if (existing != null && key != null) {
                    _box.put(key, newPolicy);
                  } else {
                    _box.add(newPolicy);
                  }
                  Navigator.pop(context);
                },
                child: const Text('Save')),
          ],
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInit) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Insurance Portfolio'),
        bottom: TabBar(controller: _tabController, tabs: const [
          Tab(text: 'Policies'),
          Tab(text: 'Tax Rules (10(10D))')
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Sync & Recalculate Status',
            onPressed: () => _recalculateTax(),
          ),
          IconButton(
            icon: PureIcons.add(),
            tooltip: 'Add Policy',
            onPressed: () => _addOrEditPolicy(),
          ),
        ],
      ),
      body: TabBarView(controller: _tabController, children: [
        _buildPoliciesTab(),
        _buildTaxRulesTab(),
      ]),
    );
  }

  Widget _buildPoliciesTab() {
    return ValueListenableBuilder(
      valueListenable: _box.listenable(),
      builder: (context, Box<InsurancePolicy> box, _) {
        // Robust Sorting Handling using Map entries (Key, Value)
        final policiesMap = box.toMap();
        final sortedEntries = policiesMap.entries.toList()
          ..sort((a, b) => b.value.sumAssured.compareTo(a.value.sumAssured));

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSummary(sortedEntries.map((e) => e.value).toList()),
            const Divider(height: 32),
            const Text('Your Policies',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 16),
            ...sortedEntries.map((entry) {
              final key = entry.key;
              final p = entry.value;
              return _buildPolicyCard(p, key); // Extracted method
            }),
          ],
        );
      },
    );
  }

  Widget _buildPolicyCard(InsurancePolicy p, dynamic key) {
    return Card(
      child: ListTile(
        leading: Icon(
          p.isTaxExempt == true
              ? Icons.shield
              : (p.isTaxExempt == false ? Icons.warning : Icons.help_outline),
          color: p.isTaxExempt == true
              ? Colors.green
              : (p.isTaxExempt == false ? Colors.orange : Colors.grey),
        ),
        title: Text(p.policyName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Premium: ₹${p.annualPremium.toStringAsFixed(0)} / yr'),
            Text('Sum Assured: ₹${p.sumAssured.toStringAsFixed(0)}'),
            if (p.isTaxExempt == null)
              const Text('Status: Pending Calc',
                  style: TextStyle(color: Colors.blueGrey, fontSize: 12)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (p.isTaxExempt == false)
              const Chip(
                  label: Text('Taxable',
                      style: TextStyle(fontSize: 10, color: Colors.white)),
                  backgroundColor: Colors.redAccent)
            else if (p.isTaxExempt == true)
              const Chip(
                  label: Text('Exempt',
                      style: TextStyle(fontSize: 10, color: Colors.white)),
                  backgroundColor: Colors.green),
            IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _addOrEditPolicy(p, key)),
            IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => _box.delete(key)),
          ],
        ),
      ),
    );
  }

  Widget _buildTaxRulesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
            'Disclaimer: These rules determine tax exemption u/s 10(10D). Changes affect all policies upon recalculation.',
            style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
        const SizedBox(height: 16),
        const Divider(),
        SwitchListTile(
          title: const Text('Enable Aggregate Premium Limits'),
          subtitle:
              const Text('Limits on total premium paid for ULIPs/Non-ULIPs'),
          value: _isInsuranceAggregateLimitEnabled,
          onChanged: (v) =>
              setState(() => _isInsuranceAggregateLimitEnabled = v),
        ),
        if (_isInsuranceAggregateLimitEnabled) ...[
          _buildSectionHeader('Start Dates for Aggregate Limits'),
          _buildDatePickerRow('ULIP Limit (2.5L) Start Date', _dateUlip,
              (d) => setState(() => _dateUlip = d)),
          _buildDatePickerRow('Non-ULIP Limit (5L) Start Date', _dateNonUlip,
              (d) => setState(() => _dateNonUlip = d)),
          const Divider(),
          _buildSectionHeader('Aggregate Premium Limits'),
          _buildNumberField('ULIP Limit (₹)', _limitUlipCtrl),
          _buildNumberField('Non-ULIP Limit (₹)', _limitNonUlipCtrl),
        ],
        const Divider(),
        SwitchListTile(
          title: const Text('Enable Premium % Rules'),
          subtitle: const Text('Limits based on % of Sum Assured'),
          value: _isInsurancePremiumPercentEnabled,
          onChanged: (v) =>
              setState(() => _isInsurancePremiumPercentEnabled = v),
        ),
        if (_isInsurancePremiumPercentEnabled) ...[
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _buildSectionHeader('Premium % Rules Configuration'),
            IconButton(
                icon: const Icon(Icons.add), onPressed: _addPremiumRuleDialog),
          ]),
          const Text(
              'Policies issued on/after Date must have Premium <= % of Sum Assured.'),
          const SizedBox(height: 8),
          ..._premiumRules.asMap().entries.map((e) {
            final idx = e.key;
            final rule = e.value;
            return Card(
                child: ListTile(
              title: Text('${rule.limitPercentage}% Limit'),
              subtitle: Text(
                  'Effective from: ${rule.startDate.day}/${rule.startDate.month}/${rule.startDate.year}'),
              trailing: IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => setState(() => _premiumRules.removeAt(idx)),
              ),
            ));
          }),
        ],
        const SizedBox(height: 24),
        FilledButton.icon(
            onPressed: _saveRules,
            icon: const Icon(Icons.save),
            label: const Text('Save Rules'))
      ],
    );
  }

  void _addPremiumRuleDialog() {
    DateTime selectedDate = DateTime(2012, 4, 1);
    final pctCtrl = TextEditingController(text: '10.0');

    showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(builder: (context, setStateBuilder) {
              return AlertDialog(
                title: const Text('Add Premium Rule'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  Row(children: [
                    const Text('Start Date: '),
                    TextButton(
                        onPressed: () async {
                          final d = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime(1990),
                              lastDate: DateTime.now());
                          if (d != null) {
                            setStateBuilder(() => selectedDate = d);
                          }
                        },
                        child: Text(
                            '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}'))
                  ]),
                  TextField(
                    controller: pctCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Limit % (of Sum Assured)'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*')),
                    ],
                  )
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () {
                        final pct = double.tryParse(pctCtrl.text);
                        if (pct != null) {
                          setState(() {
                            _premiumRules
                                .add(InsurancePremiumRule(selectedDate, pct));
                            _premiumRules.sort(
                                (a, b) => a.startDate.compareTo(b.startDate));
                          });
                          Navigator.pop(ctx);
                        }
                      },
                      child: const Text('Add'))
                ],
              );
            }));
  }

  Widget _buildDatePickerRow(
      String label, DateTime date, Function(DateTime) onSelect) {
    return ListTile(
      title: Text(label),
      trailing: TextButton.icon(
        icon: const Icon(Icons.calendar_month),
        label: Text('${date.day}/${date.month}/${date.year}'),
        onPressed: () async {
          final d = await showDatePicker(
              context: context,
              initialDate: date,
              firstDate: DateTime(2000),
              lastDate: DateTime.now());
          if (d != null) onSelect(d);
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 8),
      child: Text(title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              )),
    );
  }

  Widget _buildNumberField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*')),
        ],
      ),
    );
  }

  Future<void> _recalculateTax() async {
    final policies = _box.values.toList();
    final service = ref.read(insuranceTaxServiceProvider);
    final updated = service.optimizeMaturityTax(policies);

    // Batch update Hive
    final boxMap = _box.toMap(); // key: value
    for (var newPolicy in updated) {
      dynamic keyFound;
      boxMap.forEach((key, val) {
        if (val.id == newPolicy.id) keyFound = key;
      });

      if (keyFound != null) {
        await _box.put(keyFound, newPolicy);
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tax status recalculated and saved.')));
    }
  }

  Widget _buildSummary(List<InsurancePolicy> all) {
    double totalPremium = all.fold(0, (sum, p) => sum + p.annualPremium);
    // Only count Explicitly Exempt policies
    double exemptPremium = all
        .where((p) => p.isTaxExempt == true)
        .fold(0, (sum, p) => sum + p.annualPremium);
    double taxablePremium = all
        .where((p) => p.isTaxExempt == false)
        .fold(0, (sum, p) => sum + p.annualPremium);

    return Card(
      color: Colors.blueGrey.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('10(10D) Tax Optimization',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              // Warning if pending
              if (all.any((p) => p.isTaxExempt == null))
                const Icon(Icons.info, color: Colors.orange, size: 16),
            ]),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStat('Total Premium', totalPremium, Colors.black),
                _buildStat('Exempt', exemptPremium, Colors.green),
                _buildStat('Taxable', taxablePremium, Colors.red),
              ],
            ),
            const SizedBox(height: 8),
            const Text('Based on persisted tax status (Click Sync to update)',
                style: TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, double val, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        Text('₹${val.toStringAsFixed(0)}',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: color, fontSize: 16)),
      ],
    );
  }
}
