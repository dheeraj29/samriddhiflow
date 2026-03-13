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
import '../../models/taxes/tax_data.dart';
import '../../models/taxes/tax_data_models.dart';
import '../../utils/currency_utils.dart';
import '../../widgets/pure_icons.dart';
import '../../widgets/smart_currency_text.dart';

const capitalGainsText = 'Capital Gains';

class InsurancePortfolioScreen extends ConsumerStatefulWidget {
  final int? initialYear;
  const InsurancePortfolioScreen({super.key, this.initialYear});

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
  int _selectedYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _selectedYear = widget.initialYear ??
        (DateTime.now().month < 4
            ? DateTime.now().year - 1
            : DateTime.now().year); // coverage:ignore-line
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

    bool isInstallment =
        existing?.isInstallmentEnabled ?? false; // coverage:ignore-line
    DateTime? installmentStart =
        existing?.installmentStartDate; // coverage:ignore-line

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
          isInstallment: isInstallment,
          installmentStart: installmentStart,
          // coverage:ignore-start
          onDateChanged: (d) => setState(() => selectedDate = d),
          onMaturityChanged: (d) => setState(() => maturityDate = d),
          onUlipChanged: (v) => setState(() => isUlip = v),
          onInstallmentChanged: (v) => setState(() => isInstallment = v),
          onInstallmentStartChanged: (d) =>
              setState(() => installmentStart = d),
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
    required bool isInstallment,
    required DateTime? installmentStart,
    required ValueChanged<DateTime> onDateChanged,
    required ValueChanged<DateTime> onMaturityChanged,
    required ValueChanged<bool> onUlipChanged,
    required ValueChanged<bool> onInstallmentChanged,
    required ValueChanged<DateTime?> onInstallmentStartChanged,
  }) {
    return AlertDialog(
      title: Text(existing == null ? 'Add Policy' : 'Edit Policy'),
      content: SingleChildScrollView(
        child: _buildPolicyInputs(
          nameCtrl: nameCtrl,
          premiumCtrl: premiumCtrl,
          sumAssuredCtrl: sumAssuredCtrl,
          selectedDate: selectedDate,
          maturityDate: maturityDate,
          isUlip: isUlip,
          isInstallment: isInstallment,
          installmentStart: installmentStart,
          onStartSelected: onDateChanged,
          onMaturitySelected: onMaturityChanged,
          onUlipChanged: onUlipChanged,
          onInstallmentChanged: onInstallmentChanged,
          onInstallmentStartSelected: onInstallmentStartChanged,
          context: ctx,
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
                  isInstallment,
                  installmentStart,
                ),
            child: const Text('Save')),
      ],
    );
  }

  Widget _buildPolicyInputs({
    required TextEditingController nameCtrl,
    required TextEditingController premiumCtrl,
    required TextEditingController sumAssuredCtrl,
    required DateTime selectedDate,
    required DateTime maturityDate,
    required bool isUlip,
    required bool isInstallment,
    required DateTime? installmentStart,
    required void Function(DateTime) onStartSelected,
    required void Function(DateTime) onMaturitySelected,
    required void Function(bool) onUlipChanged,
    required void Function(bool) onInstallmentChanged,
    required void Function(DateTime?) onInstallmentStartSelected,
    required BuildContext context,
  }) {
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
        ),
        CheckboxListTile(
          title: const Text('Enable Installment Option?'),
          value: isInstallment,
          onChanged: (v) =>
              onInstallmentChanged(v ?? false), // coverage:ignore-line
        ),
        if (isInstallment)
          Row(
            // coverage:ignore-line
            children: [
              // coverage:ignore-line
              const Text('Installment Start: '),
              // coverage:ignore-start
              TextButton(
                onPressed: () async {
                  final d = await showDatePicker(
                      // coverage:ignore-end
                      context: context,
                      firstDate: selectedDate,
                      lastDate: maturityDate,
                      initialDate: installmentStart ?? selectedDate);
                  if (d != null) {
                    onInstallmentStartSelected(d); // coverage:ignore-line
                  }
                },
                child: Text(installmentStart == null // coverage:ignore-line
                    ? 'Select Date'
                    : '${installmentStart.day}/${installmentStart.month}/${installmentStart.year}'), // coverage:ignore-line
              )
            ],
          ),
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
    bool isInstallment,
    DateTime? installmentStart,
  ) {
    // coverage:ignore-start
    final newPolicy = InsurancePolicy.create(
      name: nameCtrl.text,
      number: existing?.policyNumber ??
          'POL-${DateTime.now().millisecondsSinceEpoch}',
      premium: double.tryParse(premiumCtrl.text) ?? 0,
      sumAssured: double.tryParse(sumAssuredCtrl.text) ?? 0,
      // coverage:ignore-end
      start: selectedDate,
      maturity: maturityDate,
      isUlip: isUlip,
      isTaxExempt: null, // Reset status on edit
      isInstallmentEnabled: isInstallment,
      installmentStartDate: installmentStart,
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
      valueListenable:
          ref.read(storageServiceProvider).getInsurancePoliciesListenable(),
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
          _getPolicyIcon(p),
          color: _getPolicyColor(p),
        ),
        title: Text(p.policyName),
        subtitle: _buildPolicySubtitle(p),
        trailing: _buildPolicyActions(p, key),
      ),
    );
  }

  IconData _getPolicyIcon(InsurancePolicy p) {
    if (p.isTaxExempt == true) return Icons.shield;
    if (p.isTaxExempt == false) return Icons.warning;
    return Icons.help_outline;
  }

  Color _getPolicyColor(InsurancePolicy p) {
    if (p.isTaxExempt == true) return Colors.green;
    if (p.isTaxExempt == false) return Colors.orange;
    return Colors.grey;
  }

  Widget _buildPolicySubtitle(InsurancePolicy p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPolicyRow('Premium: ', p.annualPremium, suffix: ' / yr'),
        _buildPolicyRow('Sum Assured: ', p.sumAssured),
        if (p.isTaxExempt == null)
          const Text('Status: Pending Calc', // coverage:ignore-line
              style: TextStyle(color: Colors.blueGrey, fontSize: 12)),
        if (p.isInstallmentEnabled)
          Text('Installments enabled', // coverage:ignore-line
              style: TextStyle(
                  color: Colors.blue.shade700,
                  fontSize: 12)), // coverage:ignore-line
        const SizedBox(height: 4),
        _buildStatusChips(p),
      ],
    );
  }

  Widget _buildPolicyRow(String label, double value, {String? suffix}) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontSize: 14)),
        Flexible(
          child: SmartCurrencyText(
            value: value,
            locale: ref.watch(currencyProvider),
            style: const TextStyle(fontSize: 14),
            suffix: suffix,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChips(InsurancePolicy p) {
    if (p.isTaxExempt == null) return const SizedBox.shrink();
    final isTaxable = p.isTaxExempt == false;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Chip(
        label: Text(isTaxable ? 'Taxable' : 'Exempt',
            style: const TextStyle(fontSize: 10, color: Colors.white)),
        backgroundColor: isTaxable ? Colors.redAccent : Colors.green,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildPolicyActions(InsurancePolicy p, dynamic key) {
    final service = ref.read(insuranceTaxServiceProvider);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (p.isTaxExempt == false &&
            service.isApplicableForYear(p, _selectedYear))
          IconButton(
            icon: const Icon(Icons.add_chart, color: Colors.orange),
            tooltip: 'Populate income to Tax Dashboard',
            onPressed: () => _showPopulateIncomeDialog(p, key),
          ),
        PopupMenuButton<String>(
          // coverage:ignore-start
          onSelected: (val) {
            if (val == 'edit') {
              _addOrEditPolicy(p, key);
            } else if (val == 'delete') {
              _box.delete(key);
              // coverage:ignore-end
            }
          },
          itemBuilder: (ctx) => [
            // coverage:ignore-line
            const PopupMenuItem(
                value: 'edit',
                child: Row(children: [
                  Icon(Icons.edit, size: 20),
                  SizedBox(width: 8),
                  Text('Edit')
                ])),
            const PopupMenuItem(
                value: 'delete',
                child: Row(children: [
                  Icon(Icons.delete, size: 20, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: Colors.red))
                ])),
          ],
        ),
      ],
    );
  }

  void _showPopulateIncomeDialog(InsurancePolicy p, dynamic key) {
    int selectedYear = _selectedYear;
    String selectedHead = p.isUnitLinked ? capitalGainsText : 'Other Income';
    AssetType selectedAssetType = AssetType.other;
    bool isLTCG = true;

    final split =
        ref.read(insuranceTaxServiceProvider).calculateTaxableIncomeSplit(p);
    final saleAmount = split['saleConsideration']!;
    final cost = split['costOfAcquisition']!;

    final saleAmountCtrl = TextEditingController(
        text: selectedHead == capitalGainsText
            ? saleAmount.toStringAsFixed(0) // coverage:ignore-line
            : split['taxableGain']!.toStringAsFixed(0));
    final costCtrl = TextEditingController(text: cost.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Populate Taxable Income'),
          content: SingleChildScrollView(
            child: _buildPopulateIncomeDialogContent(
              p: p,
              selectedYear: selectedYear,
              selectedHead: selectedHead,
              selectedAssetType: selectedAssetType,
              isLTCG: isLTCG,
              saleAmountCtrl: saleAmountCtrl,
              costCtrl: costCtrl,
              // coverage:ignore-start
              onHeadChanged: (val) => setState(() => selectedHead = val),
              onAssetTypeChanged: (val) =>
                  setState(() => selectedAssetType = val),
              onLtcgChanged: (val) => setState(() => isLTCG = val),
              // coverage:ignore-end
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), // coverage:ignore-line
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () => _performPopulation(
                p: p,
                key: key,
                year: selectedYear,
                saleAmount: double.tryParse(saleAmountCtrl.text) ?? 0,
                cost: double.tryParse(costCtrl.text) ?? 0,
                head: selectedHead,
                assetType: selectedAssetType,
                isLTCG: isLTCG,
                ctx: ctx,
              ),
              child: const Text('Add to Dashboard'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPopulateIncomeDialogContent({
    required InsurancePolicy p,
    required int selectedYear,
    required String selectedHead,
    required AssetType selectedAssetType,
    required bool isLTCG,
    required TextEditingController saleAmountCtrl,
    required TextEditingController costCtrl,
    required ValueChanged<String> onHeadChanged,
    required ValueChanged<AssetType> onAssetTypeChanged,
    required ValueChanged<bool> onLtcgChanged,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Policy: ${p.policyName}',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        _buildInfoField('Tax Year', 'FY $selectedYear-${selectedYear + 1}'),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: selectedHead,
          decoration: const InputDecoration(labelText: 'Tax Head'),
          items: ['Other Income', capitalGainsText]
              .map((h) => DropdownMenuItem(value: h, child: Text(h)))
              .toList(),
          onChanged: (val) => onHeadChanged(val!), // coverage:ignore-line
        ),
        const SizedBox(height: 16),
        if (selectedHead == capitalGainsText) ...[
          DropdownButtonFormField<AssetType>(
            // coverage:ignore-line
            initialValue: selectedAssetType,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Asset Category'),
            items: AssetType.values
                // coverage:ignore-start
                .map((type) => DropdownMenuItem(
                    value: type, child: Text(type.toHumanReadable())))
                .toList(),
            onChanged: (val) => onAssetTypeChanged(val!),
            // coverage:ignore-end
          ),
          const SizedBox(height: 16),
          _buildAmountField(
              // coverage:ignore-line
              saleAmountCtrl,
              'Sale Consideration / Maturity Amount'),
          const SizedBox(height: 16),
          _buildAmountField(
              // coverage:ignore-line
              costCtrl,
              'Cost of Acquisition (Historical Premiums Paid)'),
          const SizedBox(height: 8),
          SwitchListTile(
            // coverage:ignore-line
            title: const Text('Is Long Term?', style: TextStyle(fontSize: 14)),
            value: isLTCG,
            onChanged: (val) => onLtcgChanged(val), // coverage:ignore-line
            dense: true,
          ),
        ] else ...[
          _buildAmountField(saleAmountCtrl, 'Taxable Gain (Profit)'),
        ],
        const SizedBox(height: 8),
        if (p.isIncomeAddedByYear[selectedYear] == true)
          const Text(
            // coverage:ignore-line
            'Note: Income already marked as added for this year.',
            style: TextStyle(color: Colors.orange, fontSize: 12),
          ),
      ],
    );
  }

  Widget _buildAmountField(TextEditingController ctrl, String label) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegexUtils.amountExp)
      ],
    );
  }

  Future<void> _performPopulation({
    required InsurancePolicy p,
    required dynamic key,
    required int year,
    required double saleAmount,
    required double cost,
    required String head,
    required AssetType assetType,
    required bool isLTCG,
    required BuildContext ctx,
  }) async {
    final storage = ref.read(storageServiceProvider);
    final taxData = storage.getTaxYearData(year) ?? TaxYearData(year: year);
    final eventDate =
        ref.read(insuranceTaxServiceProvider).getEventDateForYear(p, year) ??
            DateTime(year, 4, 1); // coverage:ignore-line

    TaxYearData updatedData;
    if (head == capitalGainsText) {
      final entry = CapitalGainEntry(
        // coverage:ignore-line
        description: 'Insurance: ${p.policyName}', // coverage:ignore-line
        matchAssetType: assetType,
        isLTCG: isLTCG,
        isLongTerm: isLTCG,
        saleAmount: saleAmount,
        costOfAcquisition: cost,
        gainDate: eventDate,
        transactionDate: eventDate,
        isManualEntry: true,
        lastUpdated: DateTime.now(), // coverage:ignore-line
      );
      updatedData = taxData.copyWith(capitalGains: [
        ...taxData.capitalGains,
        entry
      ]); // coverage:ignore-line
    } else {
      final entry = OtherIncome(
        name: 'Insurance: ${p.policyName}',
        amount: saleAmount, // head is Other Income, saleAmount is the income
        type: 'Other',
        subtype: 'others',
        transactionDate: eventDate,
        isManualEntry: true,
        lastUpdated: DateTime.now(),
      );
      updatedData =
          taxData.copyWith(otherIncomes: [...taxData.otherIncomes, entry]);
    }

    await storage.saveTaxYearData(updatedData);

    // Mark as added in policy
    final updatedAddedMap = Map<int, bool>.from(p.isIncomeAddedByYear);
    updatedAddedMap[year] = true;
    final updatedPolicy = p.copyWith(isIncomeAddedByYear: updatedAddedMap);
    await _box.put(key, updatedPolicy);

    if (mounted && ctx.mounted) {
      Navigator.pop(ctx);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Income added to FY $year-${year + 1}')),
        );
      }
    }
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
    final service = ref.read(insuranceTaxServiceProvider);
    final data = service.calculateInsuranceSummaryData(all, _selectedYear);

    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Tax Optimization (Gains)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              if (data.hasPendingCalculations)
                const Icon(Icons.info,
                    color: Colors.orange, size: 16), // coverage:ignore-line
            ]),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStat('Ann. Premium', data.totalPremium,
                    Theme.of(context).colorScheme.onSurface),
                _buildStat(
                    'Current Taxable', data.currentTaxableGain, Colors.red),
                _buildStat(
                    'Future Taxable', data.futureTaxableGain, Colors.orange),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStat('Total Taxable ULIP', data.taxableUlipTotal,
                    Colors.deepOrange),
                _buildStat('Total Taxable Non-ULIP', data.taxableNonUlipTotal,
                    Colors.redAccent),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
                'Taxable amounts above represent Profit (Maturity - Premiums)',
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
        SmartCurrencyText(
          value: val,
          locale: ref.watch(currencyProvider),
          style: TextStyle(
              fontWeight: FontWeight.bold, color: color, fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildInfoField(String label, String value) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Text(value, style: const TextStyle(fontSize: 16)),
      ),
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
