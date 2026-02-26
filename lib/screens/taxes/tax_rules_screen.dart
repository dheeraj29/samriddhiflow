import 'package:samriddhi_flow/utils/regex_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/taxes/tax_config_service.dart';
import '../../models/taxes/tax_rules.dart';
import '../../models/taxes/tax_data_models.dart';
import '../../widgets/pure_icons.dart';
import '../../models/category.dart';
import '../../providers.dart';

class TaxRulesScreen extends ConsumerStatefulWidget {
  const TaxRulesScreen({super.key});

  @override
  ConsumerState<TaxRulesScreen> createState() => _TaxRulesScreenState();
}

class _TaxRulesScreenState extends ConsumerState<TaxRulesScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  int _selectedYear = DateTime.now().year;
  late TabController _tabController;
  bool _hasUnsavedChanges = false;

  // Controllers
  late TextEditingController _stdDedSalaryCtrl;
  late TextEditingController _stdDedHPCtrl;
  late TextEditingController _stdExempt112ACtrl;
  late TextEditingController _ltcgRateCtrl;
  late TextEditingController _stcgRateCtrl;
  late TextEditingController _winReinvestCtrl;
  late TextEditingController _rebateLimitCtrl;
  late TextEditingController _cessRateCtrl;
  late TextEditingController _maxCGReinvestLimitCtrl;
  late TextEditingController _maxHPDedLimit;
  late TextEditingController _limitGratuityCtrl;
  late TextEditingController _limitLeaveEncashmentCtrl;
  late TextEditingController _cashGiftLimitCtrl;
  late TextEditingController _agriThresholdCtrl;
  late TextEditingController _agriBasicLimitCtrl;

  late TextEditingController _employerGiftLimitCtrl;
  late TextEditingController _customCountryCtrl;

  late TextEditingController _limit44ADCtrl;
  late TextEditingController _rate44ADCtrl;
  late TextEditingController _limit44ADACtrl;
  late TextEditingController _rate44ADACtrl;

  // Booleans
  bool _isCashGiftExempt = false;
  bool _isStdDedSalaryEnabled = true;
  bool _isStdDedHPEnabled = true;
  bool _isCessEnabled = true;
  bool _isRebateEnabled = true;
  bool _isLTCGExemption112AEnabled = true;
  bool _isInsuranceExemptEnabled = true;
  bool _isInsuranceAggregateLimitEnabled = true;
  bool _isInsurancePremiumPercentEnabled = true;
  bool _isRetirementExemptionEnabled = true;
  bool _isHPMaxInterestEnabled = true;
  bool _isCGReinvestmentEnabled = true;
  bool _isCGRatesEnabled = true;
  bool _isAgriIncomeEnabled = true;
  bool _isEmployerGiftEnabled = true;
  bool _is44ADEnabled = true;
  bool _is44ADAEnabled = true;

  String _jurisdiction = 'India';
  int _fyStartMonth = 4; // Default April

  List<TaxSlab> _slabs = [];
  Map<String, String> _tagMappings = {};
  List<TaxMappingRule> _advancedMappings = [];
  List<TaxExemptionRule> _customExemptions = [];
  List<String> _transactionDescriptions = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    // Fix: Initialize with Financial Year to match the Dropdown list
    _selectedYear =
        ref.read(taxConfigServiceProvider).getCurrentFinancialYear();
    _loadRulesForYear(_selectedYear);
    _loadTransactionDescriptions();
  }

  void _loadTransactionDescriptions() {
    final storage = ref.read(storageServiceProvider);
    final txs = storage.getAllTransactions();
    _transactionDescriptions = txs
        .map((t) => t.title)
        .where((d) => d.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  void _loadRulesForYear(int year) {
    final config = ref.read(taxConfigServiceProvider);
    final rules = config.getRulesForYear(year);

    _stdDedSalaryCtrl =
        TextEditingController(text: rules.stdDeductionSalary.toString());
    _stdDedHPCtrl =
        TextEditingController(text: rules.standardDeductionRateHP.toString());
    _stdExempt112ACtrl =
        TextEditingController(text: rules.stdExemption112A.toString());
    _ltcgRateCtrl =
        TextEditingController(text: rules.ltcgRateEquity.toString());
    _stcgRateCtrl = TextEditingController(text: rules.stcgRate.toString());
    _winReinvestCtrl =
        TextEditingController(text: rules.windowGainReinvest.toString());
    _rebateLimitCtrl =
        TextEditingController(text: rules.rebateLimit.toString());
    _cessRateCtrl = TextEditingController(text: rules.cessRate.toString());
    _maxCGReinvestLimitCtrl =
        TextEditingController(text: rules.maxCGReinvestLimit.toString());
    _maxHPDedLimit =
        TextEditingController(text: rules.maxHPDeductionLimit.toString());
    _limitGratuityCtrl =
        TextEditingController(text: rules.limitGratuity.toString());
    _limitLeaveEncashmentCtrl =
        TextEditingController(text: rules.limitLeaveEncashment.toString());
    _cashGiftLimitCtrl =
        TextEditingController(text: rules.cashGiftExemptionLimit.toString());
    _agriThresholdCtrl = TextEditingController(
        text: rules.agricultureIncomeThreshold.toString());
    _agriBasicLimitCtrl = TextEditingController(
        text: rules.agricultureBasicExemptionLimit.toString());
    _employerGiftLimitCtrl = TextEditingController(
        text: rules.giftFromEmployerExemptionLimit.toString());
    _customCountryCtrl =
        TextEditingController(text: rules.customJurisdictionName);

    _limit44ADCtrl = TextEditingController(text: rules.limit44AD.toString());
    _rate44ADCtrl = TextEditingController(text: rules.rate44AD.toString());
    _limit44ADACtrl = TextEditingController(text: rules.limit44ADA.toString());
    _rate44ADACtrl = TextEditingController(text: rules.rate44ADA.toString());

    _isCashGiftExempt = rules.isCashGiftExemptionEnabled;
    _isStdDedSalaryEnabled = rules.isStdDeductionSalaryEnabled;
    _isStdDedHPEnabled = rules.isStdDeductionHPEnabled;
    _isCessEnabled = rules.isCessEnabled;
    _isRebateEnabled = rules.isRebateEnabled;
    _isLTCGExemption112AEnabled = rules.isLTCGExemption112AEnabled;
    _isInsuranceExemptEnabled = rules.isInsuranceExemptionEnabled;
    _isInsuranceAggregateLimitEnabled = rules.isInsuranceAggregateLimitEnabled;
    _isInsurancePremiumPercentEnabled = rules.isInsurancePremiumPercentEnabled;
    _isRetirementExemptionEnabled = rules.isRetirementExemptionEnabled;
    _isHPMaxInterestEnabled = rules.isHPMaxInterestEnabled;
    _isCGReinvestmentEnabled = rules.isCGReinvestmentEnabled;
    _isCGRatesEnabled = rules.isCGRatesEnabled;
    _isAgriIncomeEnabled = rules.isAgriIncomeEnabled;
    _isEmployerGiftEnabled = rules.isGiftFromEmployerEnabled;
    _is44ADEnabled = rules.is44ADEnabled;
    _is44ADAEnabled = rules.is44ADAEnabled;

    _jurisdiction = rules.jurisdiction == 'India' ? 'India' : 'Custom';
    _fyStartMonth = rules.financialYearStartMonth;

    _slabs = List.from(rules.slabs);
    _tagMappings = Map.from(rules.tagMappings);
    _advancedMappings = List.from(rules.advancedTagMappings);
    _customExemptions = List.from(rules.customExemptions);
    _hasUnsavedChanges = false;
    setState(() {});
  }

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    if (month < 1 || month > 12) return '';
    return months[month - 1];
  }

  @override
  void dispose() {
    _tabController.dispose();
    _stdDedSalaryCtrl.dispose();
    _stdDedHPCtrl.dispose();
    _stdExempt112ACtrl.dispose();
    _ltcgRateCtrl.dispose();
    _stcgRateCtrl.dispose();
    _winReinvestCtrl.dispose();
    _rebateLimitCtrl.dispose();
    _cessRateCtrl.dispose();
    _maxCGReinvestLimitCtrl.dispose();
    _maxHPDedLimit.dispose();
    _limitGratuityCtrl.dispose();
    _limitLeaveEncashmentCtrl.dispose();
    _cashGiftLimitCtrl.dispose();
    _agriThresholdCtrl.dispose();
    _agriBasicLimitCtrl.dispose();
    _employerGiftLimitCtrl.dispose();
    _limit44ADCtrl.dispose();
    _rate44ADCtrl.dispose();
    _limit44ADACtrl.dispose();
    _rate44ADACtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_formKey.currentState!.validate()) {
      final config = ref.read(taxConfigServiceProvider);
      final currentRules = config.getRulesForYear(_selectedYear);

      final newRules = currentRules.copyWith(
        stdDeductionSalary: double.parse(_stdDedSalaryCtrl.text),
        standardDeductionRateHP: double.parse(_stdDedHPCtrl.text),
        stdExemption112A: double.parse(_stdExempt112ACtrl.text),
        ltcgRateEquity: double.parse(_ltcgRateCtrl.text),
        stcgRate: double.parse(_stcgRateCtrl.text),
        windowGainReinvest: double.tryParse(_winReinvestCtrl.text) ?? 2.0,
        rebateLimit: double.parse(_rebateLimitCtrl.text),
        cessRate: double.parse(_cessRateCtrl.text),
        maxCGReinvestLimit: double.parse(_maxCGReinvestLimitCtrl.text),
        maxHPDeductionLimit: double.parse(_maxHPDedLimit.text),
        limitGratuity: double.parse(_limitGratuityCtrl.text),
        limitLeaveEncashment: double.parse(_limitLeaveEncashmentCtrl.text),
        cashGiftExemptionLimit: double.parse(_cashGiftLimitCtrl.text),
        isCashGiftExemptionEnabled: _isCashGiftExempt,
        isStdDeductionSalaryEnabled: _isStdDedSalaryEnabled,
        isStdDeductionHPEnabled: _isStdDedHPEnabled,
        isCessEnabled: _isCessEnabled,
        isRebateEnabled: _isRebateEnabled,
        isLTCGExemption112AEnabled: _isLTCGExemption112AEnabled,
        isInsuranceExemptionEnabled: _isInsuranceExemptEnabled,
        isInsuranceAggregateLimitEnabled: _isInsuranceAggregateLimitEnabled,
        isInsurancePremiumPercentEnabled: _isInsurancePremiumPercentEnabled,
        isRetirementExemptionEnabled: _isRetirementExemptionEnabled,
        isHPMaxInterestEnabled: _isHPMaxInterestEnabled,
        isCGReinvestmentEnabled: _isCGReinvestmentEnabled,
        isCGRatesEnabled: _isCGRatesEnabled,
        isAgriIncomeEnabled: _isAgriIncomeEnabled,
        customJurisdictionName: _customCountryCtrl.text,
        agricultureIncomeThreshold: double.parse(_agriThresholdCtrl.text),
        agricultureBasicExemptionLimit: double.parse(_agriBasicLimitCtrl.text),
        jurisdiction:
            _jurisdiction == 'Custom' ? _customCountryCtrl.text : _jurisdiction,
        slabs: _slabs,
        tagMappings: _tagMappings,
        advancedTagMappings: _advancedMappings,
        customExemptions: _customExemptions,
        financialYearStartMonth: _fyStartMonth,
        giftFromEmployerExemptionLimit:
            double.parse(_employerGiftLimitCtrl.text),
        isGiftFromEmployerEnabled: _isEmployerGiftEnabled,
        // Business Rules
        is44ADEnabled: _is44ADEnabled,
        limit44AD: double.tryParse(_limit44ADCtrl.text) ?? 20000000,
        rate44AD: double.tryParse(_rate44ADCtrl.text) ?? 6.0,
        is44ADAEnabled: _is44ADAEnabled,
        limit44ADA: double.tryParse(_limit44ADACtrl.text) ?? 5000000,
        rate44ADA: double.tryParse(_rate44ADACtrl.text) ?? 50.0,
      );

      await config.saveRulesForYear(_selectedYear, newRules);
      setState(() => _hasUnsavedChanges = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tax Rules Saved Successfully')));
      }
    }
  }

  Future<void> _handleYearChange(int? val) async {
    if (val == null) return;
    if (_hasUnsavedChanges) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Unsaved Changes'),
          content: const Text(
              'You have unsaved changes. Switching years will discard them. Continue?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Continue')),
          ],
        ),
      );
      if (!(confirm ?? false)) return;
    }
    setState(() => _selectedYear = val);
    _loadRulesForYear(val);
  }

  void _handleJurisdictionChange(String? val) {
    if (val == null) return;
    setState(() {
      _jurisdiction = val;
      if (val != 'India') {
        _isStdDedSalaryEnabled = false;
        _isStdDedHPEnabled = false;
        _isRebateEnabled = false;
        _isCessEnabled = false;
        _isLTCGExemption112AEnabled = false;
        _isInsuranceExemptEnabled = false;
        _isInsuranceAggregateLimitEnabled = false;
        _isInsurancePremiumPercentEnabled = false;
        _isRetirementExemptionEnabled = false;
        _isHPMaxInterestEnabled = false;
        _isCGReinvestmentEnabled = false;
        _isCGRatesEnabled = false;
        _isAgriIncomeEnabled = false;
      }
      _hasUnsavedChanges = true;
    });
  }

  Future<void> _handleRestoreDefaults(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore System Defaults?'),
        content: const Text(
            'This will delete custom tax rules for this year and revert to system defaults (or previous year). Continue?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final config = ref.read(taxConfigServiceProvider);
      await config.deleteRulesForYear(_selectedYear);
      _loadRulesForYear(_selectedYear);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tax Rules reset for FY.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Fix: Use the calculated Financial Year as the anchor, not calendar year.
    // This prevents showing "2026-2027" when we are still in "2025-2026" (e.g. Feb 2026).
    final currentYear =
        ref.read(taxConfigServiceProvider).getCurrentFinancialYear();

    // Feedback: FY shall not be future, it shall be only present and 8 years old.
    final years = List.generate(8, (i) => currentYear - i);
    final theme = Theme.of(context);
    final appBarFgColor = theme.appBarTheme.foregroundColor ??
        (theme.brightness == Brightness.dark ? Colors.white : Colors.black);

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Unsaved Changes'),
            content: const Text(
                'You have unsaved changes. Are you sure you want to leave?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Discard',
                      style: TextStyle(color: Colors.red))),
            ],
          ),
        );
        if (shouldPop ?? false) {
          if (context.mounted) Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tax Configuration'),
          actions: [
            // Financial Year Dropdown
            DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value:
                    years.contains(_selectedYear) ? _selectedYear : years.first,
                dropdownColor: theme.cardColor,
                iconEnabledColor: appBarFgColor,
                style: TextStyle(
                    color: theme.textTheme.bodyLarge?.color,
                    fontWeight: FontWeight.bold),
                selectedItemBuilder: (BuildContext context) {
                  return years.map((int value) {
                    return Center(
                      child: Text(
                        'FY $value-${value + 1}',
                        style: TextStyle(
                            color: appBarFgColor, fontWeight: FontWeight.bold),
                      ),
                    );
                  }).toList();
                },
                items: years
                    .map((y) => DropdownMenuItem(
                          value: y,
                          child: Text('FY $y-${y + 1}'),
                        ))
                    .toList(),
                onChanged: (val) => _handleYearChange(val),
              ),
            ),
            // Copy Previous Year
            IconButton(
              icon: const Icon(Icons.copy_all),
              tooltip: 'Copy Rules from Previous Year',
              onPressed: () {
                _loadRulesForYear(_selectedYear - 1);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text(
                        'Values copied from previous year. Click Save to apply.')));
              },
            ),
            // Restore Defaults
            IconButton(
              icon: const Icon(Icons.restore),
              tooltip: 'Restore System Defaults',
              onPressed: () => _handleRestoreDefaults(context),
            ),
            // Save
            IconButton(
              icon: PureIcons.save(),
              onPressed: _save,
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabs: const [
              Tab(text: 'General'),
              Tab(text: 'Salary'),
              Tab(text: 'Business'),
              Tab(text: 'House Prop'),
              Tab(text: 'Cap Gains'),
              Tab(text: 'Agri Income'),
              Tab(text: 'Mappings'),
            ],
          ),
        ),
        body: Form(
          key: _formKey,
          child: Column(
            children: [
              // TOP LEVEL JURISDICTION
              Container(
                padding: const EdgeInsets.all(16),
                color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Tax Jurisdiction',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _jurisdiction,
                                isDense: true,
                                items: ['India', 'Custom']
                                    .map((j) => DropdownMenuItem(
                                        value: j, child: Text(j)))
                                    .toList(),
                                onChanged: (val) =>
                                    _handleJurisdictionChange(val),
                              ),
                            ),
                          ),
                        ),
                        if (_jurisdiction == 'Custom') ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _customCountryCtrl,
                              onChanged: (v) =>
                                  setState(() => _hasUnsavedChanges = true),
                              decoration: const InputDecoration(
                                labelText: 'Country Name',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Financial Year Start Month
                    Row(
                      children: [
                        Expanded(
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Financial Year Start Month',
                              helperText:
                                  'Determines the start of the financial year (e.g. April 1st). Affects tax calculations.',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: _fyStartMonth,
                                isDense: true,
                                items: [
                                  for (int i = 1; i <= 12; i++)
                                    DropdownMenuItem(
                                      value: i,
                                      child: Text(_getMonthName(i)),
                                    ),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _fyStartMonth = val;
                                      _hasUnsavedChanges = true;
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildGeneralTab(),
                    _buildSalaryTab(),
                    _buildBusinessTab(),
                    _buildHousePropertyTab(),
                    _buildCapitalGainsTab(),
                    _buildAgriConfigTab(),
                    _buildMappingsTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGeneralTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('Tax Rates & Slabs'),
        // if (_jurisdiction == 'Custom') // Allow for all for now, or just remove check

        SwitchListTile(
          title: const Text('Enable Rebate (u/s 87A)'),
          value: _isRebateEnabled,
          onChanged: (v) => setState(() => _isRebateEnabled = v),
        ),
        if (_isRebateEnabled)
          _buildNumberField('Rebate Limit', _rebateLimitCtrl),
        SwitchListTile(
          title: const Text('Enable Health & Edu Cess'),
          value: _isCessEnabled,
          onChanged: (v) => setState(() => _isCessEnabled = v),
        ),
        if (_isCessEnabled) _buildNumberField('Cess Rate (%)', _cessRateCtrl),
        SwitchListTile(
          title: const Text('Enable Cash Gift Exemption'),
          value: _isCashGiftExempt,
          onChanged: (v) => setState(() => _isCashGiftExempt = v),
        ),
        if (_isCashGiftExempt)
          _buildNumberField('Cash Gift Exemption Limit', _cashGiftLimitCtrl),
        const SizedBox(height: 8),
        _buildSlabsEditor(),
        const Divider(),
        const Divider(),
        _buildSectionHeader('Custom General Exemptions'),
        _buildCustomExemptionsEditor(),
        Center(
          child: TextButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add Custom Exemption'),
            onPressed: _addCustomRuleDialog,
          ),
        ),
      ],
    );
  }

  Widget _buildMappingsTab() {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addMappingDialog,
        label: const Text('Add Mapping'),
        icon: const Icon(Icons.add_link),
      ),
      body: (_tagMappings.isEmpty && _advancedMappings.isEmpty)
          ? const Center(child: Text('No mappings defined.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                    'Map Transaction Tags or Descriptions to Tax Heads for auto-assignment.'),
                const SizedBox(height: 16),
                ..._tagMappings.entries.map((e) {
                  return Card(
                    child: ListTile(
                      title: Text(e.key), // Tag or Description
                      subtitle: Text('Maps to: ${e.value.toHumanReadable()}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          setState(() {
                            _tagMappings.remove(e.key);
                            _hasUnsavedChanges = true;
                          });
                        },
                      ),
                    ),
                  );
                }),
                const Divider(),
                const Text('Advanced Mappings (CG / Filters)',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ..._advancedMappings.asMap().entries.map((e) {
                  final i = e.key;
                  final r = e.value;
                  return Card(
                    child: ListTile(
                      title: Text(r.categoryName),
                      subtitle: Text(
                          'Maps to: ${r.taxHead.toHumanReadable()}  •  Patterns: ${r.matchDescriptions.join(", ")}${r.minHoldingMonths != null ? "  •  Min Holding: ${r.minHoldingMonths} mo" : ""}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          setState(() {
                            _advancedMappings.removeAt(i);
                            _hasUnsavedChanges = true;
                          });
                        },
                      ),
                      onTap: () => _addMappingDialog(existingRule: r, index: i),
                    ),
                  );
                }),
              ],
            ),
    );
  }

  void _addMappingDialog({TaxMappingRule? existingRule, int? index}) {
    bool mapByTag = true;
    CategoryTag selectedTag = CategoryTag.values.firstWhere(
        (t) => t != CategoryTag.none,
        orElse: () => CategoryTag.none);
    String selectedCat = existingRule?.categoryName ?? '';
    String selectedHead = existingRule?.taxHead ?? 'other';

    List<String> matchDescriptions =
        existingRule != null ? List.from(existingRule.matchDescriptions) : [];
    List<String> excludeDescriptions =
        existingRule != null ? List.from(existingRule.excludeDescriptions) : [];

    final matchDescCtrl = TextEditingController();
    final excludeDescCtrl = TextEditingController();

    final minMonthsCtrl = TextEditingController(
        text: existingRule?.minHoldingMonths?.toString() ?? '');
    final storage = ref.read(storageServiceProvider);
    final incomeCategories = storage
        .getCategories()
        .where((c) => c.usage == CategoryUsage.income)
        .toList();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateBuilder) {
          return AlertDialog(
            title: const Text('Add Mapping'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildMappingTypeSelector(
                      mapByTag, (v) => setStateBuilder(() => mapByTag = v!)),
                  const SizedBox(height: 16),
                  _buildTagOrCategoryDropdown(
                      mapByTag, selectedTag, selectedCat, incomeCategories,
                      onTagChanged: (v) =>
                          setStateBuilder(() => selectedTag = v),
                      onCatChanged: (v) =>
                          setStateBuilder(() => selectedCat = v)),
                  const SizedBox(height: 16),
                  _buildTaxHeadDropdown(selectedHead,
                      (v) => setStateBuilder(() => selectedHead = v)),
                  if (selectedHead == 'ltcg' || selectedHead == 'stcg')
                    _buildAdvancedCriteria(
                        selectedHead,
                        minMonthsCtrl,
                        matchDescCtrl,
                        matchDescriptions,
                        excludeDescCtrl,
                        excludeDescriptions,
                        setStateBuilder),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel')),
              FilledButton(
                onPressed: () {
                  _handleMappingSave(
                      mapByTag,
                      selectedTag,
                      selectedCat,
                      selectedHead,
                      matchDescCtrl,
                      matchDescriptions,
                      excludeDescCtrl,
                      excludeDescriptions,
                      minMonthsCtrl,
                      index);
                  Navigator.pop(ctx);
                },
                child: Text(index != null ? 'Update' : 'Add'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMappingTypeSelector(
      bool mapByTag, ValueChanged<bool?> onChanged) {
    return RadioGroup<bool>(
      groupValue: mapByTag,
      onChanged: onChanged,
      child: const Row(
        children: [
          Expanded(
            child: RadioListTile<bool>.adaptive(
              title: Text('Tag', style: TextStyle(fontSize: 12)),
              value: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          Expanded(
            child: RadioListTile<bool>.adaptive(
              title: Text('Category', style: TextStyle(fontSize: 12)),
              value: false,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagOrCategoryDropdown(bool mapByTag, CategoryTag selectedTag,
      String selectedCat, List<Category> incomeCategories,
      {required ValueChanged<CategoryTag> onTagChanged,
      required ValueChanged<String> onCatChanged}) {
    if (mapByTag) {
      return DropdownButtonFormField<CategoryTag>(
        initialValue: selectedTag,
        decoration: const InputDecoration(
          labelText: 'Select Tag',
          border: OutlineInputBorder(),
        ),
        items: CategoryTag.values
            .where((t) => t != CategoryTag.none)
            .map((t) => DropdownMenuItem(
                  value: t,
                  child: Text(t.name.toHumanReadable()),
                ))
            .toList(),
        onChanged: (v) {
          if (v != null) onTagChanged(v);
        },
      );
    }
    return DropdownButtonFormField<String>(
      initialValue: selectedCat.isEmpty && incomeCategories.isNotEmpty
          ? incomeCategories.first.name
          : selectedCat,
      decoration: const InputDecoration(
        labelText: 'Select Category',
        border: OutlineInputBorder(),
      ),
      items: incomeCategories
          .map((c) => DropdownMenuItem(
                value: c.name,
                child: Text(c.name),
              ))
          .toList(),
      onChanged: (v) {
        if (v != null) onCatChanged(v);
      },
    );
  }

  Widget _buildTaxHeadDropdown(
      String selectedHead, ValueChanged<String> onChanged) {
    return DropdownButtonFormField<String>(
      initialValue: selectedHead,
      decoration: const InputDecoration(
        labelText: 'Maps to Tax Head',
        border: OutlineInputBorder(),
      ),
      items: [
        'houseProp',
        'business',
        'ltcg',
        'stcg',
        'dividend',
        'other',
        'agriIncome',
        'gift',
        if (selectedHead == 'salary') 'salary',
      ]
          .map((h) =>
              DropdownMenuItem(value: h, child: Text(h.toHumanReadable())))
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }

  String _getHoldingPeriodLabel(String selectedHead) {
    if (selectedHead == 'stcg') return 'STCG if holding period < (months)';
    if (selectedHead == 'ltcg') return 'LTCG if holding period >= (months)';
    return 'Holding period threshold (months)';
  }

  Widget _buildAdvancedCriteria(
      String selectedHead,
      TextEditingController minMonthsCtrl,
      TextEditingController matchDescCtrl,
      List<String> matchDescriptions,
      TextEditingController excludeDescCtrl,
      List<String> excludeDescriptions,
      StateSetter setStateBuilder) {
    return Column(
      children: [
        const SizedBox(height: 16),
        const Text('Advanced Mapping Criteria',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: minMonthsCtrl,
          decoration: InputDecoration(
            labelText: _getHoldingPeriodLabel(selectedHead),
            border: const OutlineInputBorder(),
            helperText: 'Leave empty for any period',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: false),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        const SizedBox(height: 12),
        _buildDescriptionField(matchDescCtrl, 'Must Match Description',
            'e.g., Sold', matchDescriptions, setStateBuilder),
        if (matchDescriptions.isNotEmpty)
          _buildDescriptionChips(matchDescriptions, setStateBuilder),
        const SizedBox(height: 12),
        _buildDescriptionField(excludeDescCtrl, 'Exclude Description',
            'e.g., Transfer', excludeDescriptions, setStateBuilder,
            isExclude: true),
        if (excludeDescriptions.isNotEmpty)
          _buildDescriptionChips(excludeDescriptions, setStateBuilder,
              isExclude: true),
      ],
    );
  }

  Widget _buildDescriptionField(TextEditingController ctrl, String labelText,
      String hintText, List<String> descriptions, StateSetter setStateBuilder,
      {bool isExclude = false}) {
    return Row(
      children: [
        Expanded(
          child: _buildDescriptionAutocomplete(
            controller: ctrl,
            labelText: labelText,
            hintText: hintText,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: () {
            if (ctrl.text.isNotEmpty) {
              setStateBuilder(() {
                descriptions.add(ctrl.text);
                ctrl.clear();
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildDescriptionChips(
      List<String> descriptions, StateSetter setStateBuilder,
      {bool isExclude = false}) {
    return Wrap(
      spacing: 8,
      children: descriptions.map((d) {
        return Chip(
          label: Text(d,
              style: TextStyle(
                  fontSize: 10, color: isExclude ? Colors.red : null)),
          onDeleted: () => setStateBuilder(() => descriptions.remove(d)),
        );
      }).toList(),
    );
  }

  void _handleMappingSave(
      bool mapByTag,
      CategoryTag selectedTag,
      String selectedCat,
      String selectedHead,
      TextEditingController matchDescCtrl,
      List<String> matchDescriptions,
      TextEditingController excludeDescCtrl,
      List<String> excludeDescriptions,
      TextEditingController minMonthsCtrl,
      int? index) {
    // Add any pending text from controllers
    if (matchDescCtrl.text.isNotEmpty) {
      matchDescriptions.add(matchDescCtrl.text);
    }
    if (excludeDescCtrl.text.isNotEmpty) {
      excludeDescriptions.add(excludeDescCtrl.text);
    }

    setState(() {
      if (selectedHead == 'ltcg' || selectedHead == 'stcg') {
        _saveAdvancedMapping(mapByTag, selectedTag, selectedCat, selectedHead,
            matchDescriptions, excludeDescriptions, minMonthsCtrl, index);
      } else {
        _saveSimpleMapping(mapByTag, selectedTag, selectedCat, selectedHead);
      }
      _hasUnsavedChanges = true;
    });
  }

  void _saveAdvancedMapping(
      bool mapByTag,
      CategoryTag selectedTag,
      String selectedCat,
      String selectedHead,
      List<String> matchDescriptions,
      List<String> excludeDescriptions,
      TextEditingController minMonthsCtrl,
      int? index) {
    final newRule = TaxMappingRule(
      categoryName: mapByTag ? selectedTag.name : selectedCat,
      taxHead: selectedHead,
      matchDescriptions: matchDescriptions,
      excludeDescriptions: excludeDescriptions,
      minHoldingMonths: int.tryParse(minMonthsCtrl.text),
    );
    if (index != null) {
      _advancedMappings[index] = newRule;
    } else {
      _advancedMappings.add(newRule);
    }
  }

  void _saveSimpleMapping(bool mapByTag, CategoryTag selectedTag,
      String selectedCat, String selectedHead) {
    final key = mapByTag ? selectedTag.name : selectedCat;
    if (key.isNotEmpty) {
      _tagMappings[key] = selectedHead;
    }
  }

  Widget _buildSlabsEditor() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Income Slabs',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      setState(() {
                        _slabs.add(
                            const TaxSlab(TaxRules.infinitySubstitute, 30));
                        _hasUnsavedChanges = true;
                      });
                    }),
              ],
            ),
            ..._slabs.asMap().entries.map((entry) {
              final index = entry.key;
              final slab = entry.value;
              return Row(
                children: [
                  const Text('Up to  '),
                  SizedBox(
                    width: 100,
                    child: TextFormField(
                      initialValue:
                          slab.isUnlimited ? '' : slab.upto.toStringAsFixed(0),
                      decoration: InputDecoration(
                        hintText: slab.isUnlimited ? 'Unlimited' : '',
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegexUtils.amountExp),
                      ],
                      onChanged: (val) {
                        setState(() {
                          double limit = val.isEmpty
                              ? TaxRules.infinitySubstitute
                              : double.tryParse(val) ??
                                  TaxRules.infinitySubstitute;
                          _slabs[index] = TaxSlab(limit, slab.rate);
                          _hasUnsavedChanges = true;
                        });
                      },
                    ),
                  ),
                  const Text('  Rate: '),
                  SizedBox(
                    width: 60,
                    child: TextFormField(
                      initialValue: slab.rate.toString(),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegexUtils.amountExp),
                      ],
                      onChanged: (val) {
                        setState(() {
                          _slabs[index] =
                              TaxSlab(slab.upto, double.tryParse(val) ?? 0);
                          _hasUnsavedChanges = true;
                        });
                      },
                    ),
                  ),
                  const Text('%'),
                  IconButton(
                      icon: const Icon(Icons.delete, size: 16),
                      onPressed: () {
                        setState(() {
                          _slabs.removeAt(index);
                          _hasUnsavedChanges = true;
                        });
                      }),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              )),
    );
  }

  Widget _buildNumberField(String label, TextEditingController controller,
      {bool isInt = false, String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        onChanged: (v) {
          if (!_hasUnsavedChanges) {
            setState(() => _hasUnsavedChanges = true);
          }
        },
        decoration: InputDecoration(
          labelText: label,
          helperText: subtitle,
          border: const OutlineInputBorder(),
        ),
        keyboardType: TextInputType.numberWithOptions(decimal: !isInt),
        inputFormatters: [
          if (isInt)
            FilteringTextInputFormatter.digitsOnly
          else
            FilteringTextInputFormatter.allow(RegexUtils.amountExp),
        ],
        validator: (val) {
          if (val == null || val.isEmpty) return 'Required';
          if (double.tryParse(val) == null) return 'Invalid Number';
          return null;
        },
      ),
    );
  }

  Widget _buildSalaryTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('Standard Deductions'),
        SwitchListTile(
          title: const Text('Enable Standard Deduction'),
          value: _isStdDedSalaryEnabled,
          onChanged: (v) => setState(() {
            _isStdDedSalaryEnabled = v;
            _hasUnsavedChanges = true;
          }),
        ),
        if (_isStdDedSalaryEnabled)
          _buildNumberField('Standard Deduction (Salary)', _stdDedSalaryCtrl),
        const Divider(),
        _buildSectionHeader('Retirement Exemptions'),
        SwitchListTile(
          title: const Text('Enable Retirement / Resignation Exemptions'),
          subtitle: const Text('Gratuity & Leave Encashment'),
          value: _isRetirementExemptionEnabled,
          onChanged: (v) => setState(() {
            _isRetirementExemptionEnabled = v;
            _hasUnsavedChanges = true;
          }),
        ),
        if (_isRetirementExemptionEnabled) ...[
          _buildNumberField(
              'Gratuity Exemption Limit (10(10))', _limitGratuityCtrl),
          _buildNumberField(
              'Leave Encashment Limit (10(10AA))', _limitLeaveEncashmentCtrl),
        ],
        const Divider(),
        _buildSectionHeader('Employer Gifts'),
        SwitchListTile(
          title: const Text('Enable Gifts from Employer Rule'),
          subtitle: const Text('Exempt up to a limit'),
          value: _isEmployerGiftEnabled,
          onChanged: (v) => setState(() {
            _isEmployerGiftEnabled = v;
            _hasUnsavedChanges = true;
          }),
        ),
        if (_isEmployerGiftEnabled)
          _buildNumberField('Gift Exemption Limit', _employerGiftLimitCtrl,
              subtitle: 'Default: 5000'),
      ],
    );
  }

  Widget _buildBusinessTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('Presumptive Income (Sec 44AD/ADA)'),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text('Enable Sec 44AD'),
          subtitle: const Text('Presumptive income for Businesses'),
          value: _is44ADEnabled,
          onChanged: (v) => setState(() {
            _is44ADEnabled = v;
            _hasUnsavedChanges = true;
          }),
        ),
        if (_is44ADEnabled) ...[
          _buildNumberField('Turnover Limit for 44AD', _limit44ADCtrl,
              isInt: true),
          _buildNumberField('Presumptive Profit Rate (%)', _rate44ADCtrl),
        ],
        const Divider(),
        SwitchListTile(
          title: const Text('Enable Sec 44ADA'),
          subtitle: const Text('Presumptive income for Professionals'),
          value: _is44ADAEnabled,
          onChanged: (v) => setState(() {
            _is44ADAEnabled = v;
            _hasUnsavedChanges = true;
          }),
        ),
        if (_is44ADAEnabled) ...[
          _buildNumberField('Gross Receipts Limit for 44ADA', _limit44ADACtrl,
              isInt: true),
          _buildNumberField('Presumptive Profit Rate (%)', _rate44ADACtrl),
        ],
      ],
    );
  }

  Widget _buildHousePropertyTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('House Property Configuration'),
        SwitchListTile(
          title: const Text('Enable 30% Standard Deduction'),
          value: _isStdDedHPEnabled,
          onChanged: (v) => setState(() {
            _isStdDedHPEnabled = v;
            _hasUnsavedChanges = true;
          }),
        ),
        if (_isStdDedHPEnabled)
          _buildNumberField('Standard Deduction Rate (%)', _stdDedHPCtrl,
              subtitle: 'Usually 30%'),
        const Divider(),
        SwitchListTile(
          title: const Text('Enable Interest Deduction Cap'),
          subtitle:
              const Text('Limit max interest deduction for self-occupied'),
          value: _isHPMaxInterestEnabled,
          onChanged: (v) => setState(() {
            _isHPMaxInterestEnabled = v;
            _hasUnsavedChanges = true;
          }),
        ),
        if (_isHPMaxInterestEnabled)
          _buildNumberField(
              'Max Interest Deduction (Self-Occ)', _maxHPDedLimit),
      ],
    );
  }

  Widget _buildCapitalGainsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('Capital Gains Rates'),
        SwitchListTile(
          title: const Text('Enable Special CG Rates'),
          subtitle: const Text('Use special rates instead of normal slabs'),
          value: _isCGRatesEnabled,
          onChanged: (v) => setState(() {
            _isCGRatesEnabled = v;
            _hasUnsavedChanges = true;
          }),
        ),
        if (_isCGRatesEnabled) ...[
          _buildNumberField('LTCG Rate (Equity) %', _ltcgRateCtrl),
          _buildNumberField('STCG Rate (Equity) %', _stcgRateCtrl),
        ],
        SwitchListTile(
          title: const Text('Enable 112A Exemption'),
          value: _isLTCGExemption112AEnabled,
          onChanged: (v) => setState(() {
            _isLTCGExemption112AEnabled = v;
            _hasUnsavedChanges = true;
          }),
        ),
        if (_isLTCGExemption112AEnabled)
          _buildNumberField(
              'Standard Exemption 112A (LTCG)', _stdExempt112ACtrl),
        const Divider(),
        _buildSectionHeader('Reinvestment Rules'),
        SwitchListTile(
          title: const Text('Enable Reinvestment Exemptions'),
          value: _isCGReinvestmentEnabled,
          onChanged: (v) => setState(() {
            _isCGReinvestmentEnabled = v;
            _hasUnsavedChanges = true;
          }),
        ),
        if (_isCGReinvestmentEnabled) ...[
          _buildNumberField('Reinvestment Window (Years)', _winReinvestCtrl),
          _buildNumberField(
              'Max Capital Gain Reinvest Limit', _maxCGReinvestLimitCtrl),
        ],
      ],
    );
  }

  Widget _buildAgriConfigTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('Agriculture Income Configuration'),
        SwitchListTile(
          title: const Text('Enable Partial Integration'),
          subtitle:
              const Text('Determines tax using partial integration method'),
          value: _isAgriIncomeEnabled,
          onChanged: (v) => setState(() {
            _isAgriIncomeEnabled = v;
            _hasUnsavedChanges = true;
          }),
        ),
        if (_isAgriIncomeEnabled) ...[
          const Text(
              'Partial Integration Method determines tax on Agriculture Income if it exceeds the threshold and non-agri income exceeds basic exemption.'),
          const SizedBox(height: 16),
          _buildNumberField('Agriculture Income Threshold', _agriThresholdCtrl,
              subtitle: 'Default: ₹5,000'),
          _buildNumberField('Agri Basic Exemption Limit', _agriBasicLimitCtrl,
              subtitle: 'Default: ₹4,00,000 (Used for Partial Integration)'),
        ],
      ],
    );
  }

  Widget _buildDescriptionAutocomplete({
    required TextEditingController controller,
    required String labelText,
    required String hintText,
  }) {
    return RawAutocomplete<String>(
      textEditingController: controller,
      focusNode: FocusNode(),
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return const Iterable<String>.empty();
        }
        return _transactionDescriptions.where((String option) {
          return option
              .toLowerCase()
              .contains(textEditingValue.text.toLowerCase());
        });
      },
      fieldViewBuilder:
          (context, fieldController, focusNode, onFieldSubmitted) {
        return TextField(
          controller: fieldController,
          focusNode: focusNode,
          decoration: InputDecoration(
              labelText: labelText,
              border: const OutlineInputBorder(),
              hintText: hintText),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4.0,
            child: SizedBox(
              height: 200,
              width: 300,
              child: ListView.builder(
                padding: const EdgeInsets.all(8.0),
                itemCount: options.length,
                itemBuilder: (BuildContext context, int index) {
                  final String option = options.elementAt(index);
                  return GestureDetector(
                    onTap: () {
                      onSelected(option);
                    },
                    child: ListTile(
                      title: Text(option),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCustomExemptionsEditor() {
    // Defines custom exemptions displayed in General or Mappings
    if (_customExemptions.isEmpty) {
      return const Padding(
          padding: EdgeInsets.all(8),
          child: Text('No custom exemptions defined.'));
    }
    final otherExemptions = _customExemptions
        .asMap()
        .entries
        .where((e) => e.value.incomeHead == 'Other') // Restrict to 'Other'
        .toList();

    if (otherExemptions.isEmpty) {
      return const Padding(
          padding: EdgeInsets.all(8),
          child: Text('No custom exemptions defined for Other Income.'));
    }

    return Column(
        children: otherExemptions.map((e) {
      final i = e.key;
      final rule = e.value;
      return SwitchListTile(
        title: Text(rule.name),
        subtitle: Text('Other Income • Max: ₹${rule.limit}'),
        value: rule.isEnabled,
        onChanged: (val) {
          setState(() {
            _customExemptions[i] = rule.copyWith(isEnabled: val);
            _hasUnsavedChanges = true;
          });
        },
        secondary: IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => setState(() {
                  _customExemptions.removeAt(i);
                  _hasUnsavedChanges = true;
                })),
      );
    }).toList());
  }

  void _addCustomRuleDialog() {
    final nameCtrl = TextEditingController();
    final limitCtrl = TextEditingController();
    String head = 'Other';

    showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(builder: (context, setStateBuilder) {
              return AlertDialog(
                  title: const Text('Add Custom Exemption'),
                  content: Column(mainAxisSize: MainAxisSize.min, children: [
                    TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(labelText: 'Name'),
                        textCapitalization: TextCapitalization.words),
                    const SizedBox(height: 12),
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Income Head',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      child: Text(
                        'Other',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                        controller: limitCtrl,
                        decoration: const InputDecoration(labelText: 'Limit'),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegexUtils.amountExp),
                        ]),
                  ]),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () {
                          setState(() {
                            _customExemptions.add(TaxExemptionRule(
                                id: 'rule_${DateTime.now().millisecondsSinceEpoch}',
                                name: nameCtrl.text,
                                incomeHead: head,
                                limit: double.tryParse(limitCtrl.text) ?? 0,
                                isPercentage: false));
                            _hasUnsavedChanges = true;
                          });
                          Navigator.pop(ctx);
                        },
                        child: const Text('Add'))
                  ]);
            }));
  }
}
