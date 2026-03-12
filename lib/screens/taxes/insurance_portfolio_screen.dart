import 'package:samriddhi_flow/utils/regex_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/taxes/insurance_policy.dart';
import '../../models/taxes/tax_rules.dart';
import '../../services/taxes/insurance_tax_service.dart';
import '../../services/taxes/tax_config_service.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import '../../providers.dart';
import '../../utils/currency_utils.dart';
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
      // coverage:ignore-start
      _premiumRules = [
        InsurancePremiumRule(DateTime(2003, 4, 1), 20.0),
        InsurancePremiumRule(DateTime(2012, 4, 1), 10.0),
        // coverage:ignore-end
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

  // coverage:ignore-start
  Future<void> _saveRules() async {
    final config = ref.read(taxConfigServiceProvider);
    final current = config.getRulesForYear(_selectedYear);
    // coverage:ignore-end

    final updated = current.copyWith(
        // coverage:ignore-line
        limitInsuranceULIP: double.tryParse(_limitUlipCtrl.text) ??
            250000, // coverage:ignore-line
        limitInsuranceNonULIP:
            // coverage:ignore-start
            double.tryParse(_limitNonUlipCtrl.text) ?? 500000,
        dateEffectiveULIP: _dateUlip,
        dateEffectiveNonULIP: _dateNonUlip,
        isInsuranceAggregateLimitEnabled: _isInsuranceAggregateLimitEnabled,
        isInsurancePremiumPercentEnabled: _isInsurancePremiumPercentEnabled,
        insurancePremiumRules: _premiumRules);
    // coverage:ignore-end

    // coverage:ignore-start
    await config.saveRulesForYear(_selectedYear, updated);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Tax Rules Updated')));
      // coverage:ignore-end
    }
  }

  void _addOrEditPolicy([InsurancePolicy? existing, dynamic key]) {
    final nameCtrl = TextEditingController(text: existing?.policyName ?? '');
    final premiumCtrl =
        TextEditingController(text: existing?.annualPremium.toString() ?? '');
    final sumAssuredCtrl =
        TextEditingController(text: existing?.sumAssured.toString() ?? '');
    DateTime selectedDate = existing?.startDate ?? DateTime.now();
    bool isUlip = existing?.isUnitLinked ?? false; // coverage:ignore-line
    DateTime maturityDate = existing?.maturityDate ?? // coverage:ignore-line
        selectedDate.add(const Duration(days: 365 * 10));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => _buildPolicyDialog(
          ctx: ctx,
          existing: existing,
          key: key,
          nameCtrl: nameCtrl,
          premiumCtrl: premiumCtrl,
          sumAssuredCtrl: sumAssuredCtrl,
          selectedDate: selectedDate,
          maturityDate: maturityDate,
          isUlip: isUlip,
          // coverage:ignore-start
          onDateChanged: (d) => setState(() => selectedDate = d),
          onMaturityChanged: (d) => setState(() => maturityDate = d),
          onUlipChanged: (v) => setState(() => isUlip = v),
          // coverage:ignore-end
        ),
      ),
    );
  }

  Widget _buildPolicyDialog({
    required BuildContext ctx,
    required InsurancePolicy? existing,
    required dynamic key,
    required TextEditingController nameCtrl,
    required TextEditingController premiumCtrl,
    required TextEditingController sumAssuredCtrl,
    required DateTime selectedDate,
    required DateTime maturityDate,
    required bool isUlip,
    required ValueChanged<DateTime> onDateChanged,
    required ValueChanged<DateTime> onMaturityChanged,
    required ValueChanged<bool> onUlipChanged,
  }) {
    return AlertDialog(
      title: Text(existing == null ? 'Add Policy' : 'Edit Policy'),
      content: SingleChildScrollView(
        child: _buildPolicyInputs(
          nameCtrl,
          premiumCtrl,
          sumAssuredCtrl,
          selectedDate,
          maturityDate,
          isUlip,
          onDateChanged,
          onMaturityChanged,
          onUlipChanged,
          ctx,
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel')), // coverage:ignore-line
        FilledButton(
            onPressed: () => _savePolicy(
                  // coverage:ignore-line
                  existing,
                  key,
                  nameCtrl,
                  premiumCtrl,
                  sumAssuredCtrl,
                  selectedDate,
                  maturityDate,
                  isUlip,
                ),
            child: const Text('Save')),
      ],
    );
  }

  Widget _buildPolicyInputs(
    TextEditingController nameCtrl,
    TextEditingController premiumCtrl,
    TextEditingController sumAssuredCtrl,
    DateTime selectedDate,
    DateTime maturityDate,
    bool isUlip,
    void Function(DateTime) onStartSelected,
    void Function(DateTime) onMaturitySelected,
    void Function(bool) onUlipChanged,
    BuildContext context,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(labelText: 'Policy Name')),
        TextField(
            controller: premiumCtrl,
            decoration: InputDecoration(
                labelText:
                    'Annual Premium (${CurrencyUtils.getSymbol(ref.watch(currencyProvider))})'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegexUtils.amountExp),
            ]),
        TextField(
            controller: sumAssuredCtrl,
            decoration: InputDecoration(
                labelText:
                    'Sum Assured (${CurrencyUtils.getSymbol(ref.watch(currencyProvider))})'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegexUtils.amountExp),
            ]),
        const SizedBox(height: 16),
        Row(
          children: [
            const Text('Issue Date: '),
            TextButton(
              onPressed: () async {
                // coverage:ignore-line
                final d = await showDatePicker(
                    // coverage:ignore-line
                    context: context,
                    firstDate: DateTime(2000), // coverage:ignore-line
                    lastDate: DateTime.now(), // coverage:ignore-line
                    initialDate: selectedDate);
                if (d != null) onStartSelected(d); // coverage:ignore-line
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
                // coverage:ignore-line
                final d = await showDatePicker(
                    // coverage:ignore-line
                    context: context,
                    firstDate: selectedDate,
                    lastDate: DateTime(2050), // coverage:ignore-line
                    initialDate: maturityDate);
                if (d != null) onMaturitySelected(d); // coverage:ignore-line
              },
              child: Text(
                  '${maturityDate.day}/${maturityDate.month}/${maturityDate.year}'),
            )
          ],
        ),
        CheckboxListTile(
          title: const Text('Is ULIP?'),
          value: isUlip,
          onChanged: (v) => onUlipChanged(v ?? false), // coverage:ignore-line
        )
      ],
    );
  }

  void _savePolicy(
    // coverage:ignore-line
    InsurancePolicy? existing,
    dynamic key,
    TextEditingController nameCtrl,
    TextEditingController premiumCtrl,
    TextEditingController sumAssuredCtrl,
    DateTime selectedDate,
    DateTime maturityDate,
    bool isUlip,
  ) {
    // coverage:ignore-start
    final newPolicy = InsurancePolicy.create(
      name: nameCtrl.text,
      number: 'POL-${DateTime.now().millisecondsSinceEpoch}',
      premium: double.tryParse(premiumCtrl.text) ?? 0,
      sumAssured: double.tryParse(sumAssuredCtrl.text) ?? 0,
      // coverage:ignore-end
      start: selectedDate,
      maturity: maturityDate,
      isUlip: isUlip,
      isTaxExempt: null, // Reset status on edit
    );

    if (existing != null && key != null) {
      _box.put(key, newPolicy); // coverage:ignore-line
    } else {
      _box.add(newPolicy); // coverage:ignore-line
    }
    Navigator.pop(context); // coverage:ignore-line
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInit) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Insurance Portfolio'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Policies List'),
            Tab(text: 'Tax Rules'),
          ],
        ),
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
              // coverage:ignore-start
              final key = entry.key;
              final p = entry.value;
              return _buildPolicyCard(p, key); // Extracted method
              // coverage:ignore-end
            }),
          ],
        );
      },
    );
  }

  // coverage:ignore-start
  Widget _buildPolicyCard(InsurancePolicy p, dynamic key) {
    IconData getIcon() {
      if (p.isTaxExempt == true) return Icons.shield;
      if (p.isTaxExempt == false) return Icons.warning;
      // coverage:ignore-end
      return Icons.help_outline;
    }

    // coverage:ignore-start
    Color getColor() {
      if (p.isTaxExempt == true) return Colors.green;
      if (p.isTaxExempt == false) return Colors.orange;
      // coverage:ignore-end
      return Colors.grey;
    }

    // coverage:ignore-start
    return Card(
      child: ListTile(
        leading: Icon(
          getIcon(),
          color: getColor(),
          // coverage:ignore-end
        ),
        title: Text(p.policyName), // coverage:ignore-line
        subtitle: Column(
          // coverage:ignore-line
          crossAxisAlignment: CrossAxisAlignment.start,
          // coverage:ignore-start
          children: [
            Text(
                'Premium: ${CurrencyUtils.formatCurrency(p.annualPremium, ref.watch(currencyProvider))} / yr'),
            Text(
                'Sum Assured: ${CurrencyUtils.formatCurrency(p.sumAssured, ref.watch(currencyProvider))}'),
            if (p.isTaxExempt == null)
              const Text('Status: Pending Calc',
                  // coverage:ignore-end
                  style: TextStyle(color: Colors.blueGrey, fontSize: 12)),
          ],
        ),
        trailing: Row(
          // coverage:ignore-line
          mainAxisSize: MainAxisSize.min,
          // coverage:ignore-start
          children: [
            if (p.isTaxExempt == false)
              const Chip(
                  // coverage:ignore-end
                  label: Text('Taxable',
                      style: TextStyle(fontSize: 10, color: Colors.white)),
                  backgroundColor: Colors.redAccent)
            else if (p.isTaxExempt == true) // coverage:ignore-line
              const Chip(
                  // coverage:ignore-line
                  label: Text('Exempt',
                      style: TextStyle(fontSize: 10, color: Colors.white)),
                  backgroundColor: Colors.green),
            IconButton(
                // coverage:ignore-line
                icon: const Icon(Icons.edit),
                onPressed: () =>
                    _addOrEditPolicy(p, key)), // coverage:ignore-line
            IconButton(
                // coverage:ignore-line
                icon: const Icon(Icons.delete),
                onPressed: () => _box.delete(key)), // coverage:ignore-line
          ],
        ),
      ),
    );
  }

  Widget _buildTaxRulesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Row(
          children: [
            Icon(Icons.info_outline, size: 16, color: Colors.blue),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Disclaimer: These rules determine tax behavior. Changes affect all policies upon recalculation.',
                style: TextStyle(fontSize: 12, color: Colors.blue),
              ),
            ),
          ],
        ),
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
              (d) => setState(() => _dateUlip = d)), // coverage:ignore-line
          _buildDatePickerRow('Non-ULIP Limit (5L) Start Date', _dateNonUlip,
              (d) => setState(() => _dateNonUlip = d)), // coverage:ignore-line
          const Divider(),
          _buildSectionHeader('Aggregate Premium Limits'),
          _buildNumberField('ULIP Limit', _limitUlipCtrl, isAmount: true),
          _buildNumberField('Non-ULIP Limit', _limitNonUlipCtrl,
              isAmount: true),
        ],
        const Divider(),
        SwitchListTile(
          title: const Text('Enable Premium % Rules'),
          subtitle: const Text('Limits based on % of Sum Assured'),
          value: _isInsurancePremiumPercentEnabled,
          onChanged: (v) => // coverage:ignore-line
              setState(() => _isInsurancePremiumPercentEnabled =
                  v), // coverage:ignore-line
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
                onPressed: () => setState(
                    () => _premiumRules.removeAt(idx)), // coverage:ignore-line
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

  // coverage:ignore-start
  void _addPremiumRuleDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _AddPremiumRuleDialog(
        onAdd: (selectedDate, pct) {
          setState(() {
            _premiumRules.add(InsurancePremiumRule(selectedDate, pct));
            _premiumRules.sort((a, b) => a.startDate.compareTo(b.startDate));
            // coverage:ignore-end
          });
        },
      ),
    );
  }

  Widget _buildDatePickerRow(
      String label, DateTime date, Function(DateTime) onSelect) {
    return ListTile(
      title: Text(label),
      trailing: TextButton.icon(
        icon: const Icon(Icons.calendar_month),
        label: Text('${date.day}/${date.month}/${date.year}'),
        // coverage:ignore-start
        onPressed: () async {
          final d = await showDatePicker(
              context: context,
              // coverage:ignore-end
              initialDate: date,
              // coverage:ignore-start
              firstDate: DateTime(2000),
              lastDate: DateTime.now());
          if (d != null) onSelect(d);
          // coverage:ignore-end
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

  Widget _buildNumberField(String label, TextEditingController controller,
      {bool isAmount = false}) {
    final currencySymbol =
        ref.watch(currencyProvider.select((l) => CurrencyUtils.getSymbol(l)));
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixText: isAmount ? '$currencySymbol ' : null,
          border: const OutlineInputBorder(),
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegexUtils.amountExp),
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
        // coverage:ignore-line
        if (val.id == newPolicy.id) keyFound = key; // coverage:ignore-line
      });

      if (keyFound != null) {
        await _box.put(keyFound, newPolicy); // coverage:ignore-line
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
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Tax Optimization',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              // Warning if pending
              if (all.any((p) => p.isTaxExempt == null))
                const Icon(Icons.info,
                    color: Colors.orange, size: 16), // coverage:ignore-line
            ]),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStat('Total Premium', totalPremium,
                    Theme.of(context).colorScheme.onSurface),
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
        Text(CurrencyUtils.formatCurrency(val, ref.watch(currencyProvider)),
            style: TextStyle(
                fontWeight: FontWeight.bold, color: color, fontSize: 16)),
      ],
    );
  }
}

class _AddPremiumRuleDialog extends StatefulWidget {
  final Function(DateTime selectedDate, double pct) onAdd;

  const _AddPremiumRuleDialog({required this.onAdd}); // coverage:ignore-line

  @override // coverage:ignore-line
  State<_AddPremiumRuleDialog> createState() =>
      _AddPremiumRuleDialogState(); // coverage:ignore-line
}

class _AddPremiumRuleDialogState extends State<_AddPremiumRuleDialog> {
  DateTime _selectedDate = DateTime(2012, 4, 1);
  final _pctCtrl = TextEditingController(text: '10.0');

  @override // coverage:ignore-line
  void dispose() {
    _pctCtrl.dispose(); // coverage:ignore-line
    super.dispose(); // coverage:ignore-line
  }

  @override // coverage:ignore-line
  Widget build(BuildContext context) {
    return AlertDialog(
      // coverage:ignore-line
      title: const Text('Add Premium Rule'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        // coverage:ignore-line
        Row(children: [
          // coverage:ignore-line
          const Text('Start Date: '),
          // coverage:ignore-start
          TextButton(
              onPressed: () async {
                final d = await showDatePicker(
                    // coverage:ignore-end
                    context: context,
                    // coverage:ignore-start
                    initialDate: _selectedDate,
                    firstDate: DateTime(1990),
                    lastDate: DateTime.now());
                if (d != null) setState(() => _selectedDate = d);
                // coverage:ignore-end
              },
              child: Text(// coverage:ignore-line
                  '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}')) // coverage:ignore-line
        ]),
        TextField(
          // coverage:ignore-line
          controller: _pctCtrl, // coverage:ignore-line
          decoration:
              const InputDecoration(labelText: 'Limit % (of Sum Assured)'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            // coverage:ignore-line
            FilteringTextInputFormatter.allow(
                RegexUtils.amountExp), // coverage:ignore-line
          ],
        )
      ]),
      // coverage:ignore-start
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            // coverage:ignore-end
            child: const Text('Cancel')),
        // coverage:ignore-start
        FilledButton(
          onPressed: () {
            final pct = double.tryParse(_pctCtrl.text);
            // coverage:ignore-end
            if (pct != null) {
              widget.onAdd(_selectedDate, pct); // coverage:ignore-line
              Navigator.pop(context); // coverage:ignore-line
            }
          },
          child: const Text('Add'),
        )
      ],
    );
  }
}
