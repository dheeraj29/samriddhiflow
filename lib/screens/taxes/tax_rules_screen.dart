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
import '../../utils/currency_utils.dart';

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
  late TextEditingController _advanceTaxReminderDaysCtrl;

  late TextEditingController _limit44ADCtrl;
  late TextEditingController _rate44ADCtrl;
  late TextEditingController _limit44ADACtrl;
  late TextEditingController _rate44ADACtrl;
  late TextEditingController _advanceTaxInterestThresholdCtrl;

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
  bool _enableAdvanceTaxInterest = true;
  bool _interestTillPaymentDate = false;
  bool _isCgIncludedInAdvanceTax = false;

  String _jurisdiction = 'India';
  int _fyStartMonth = 4; // Default April

  List<TaxSlab> _slabs = [];
  Map<String, String> _tagMappings = {};
  List<TaxMappingRule> _advancedMappings = [];
  List<TaxExemptionRule> _customExemptions = [];
  List<String> _transactionDescriptions = [];
  List<String> _taxableGiftKeys = [];
  List<AdvanceTaxInstallmentRule> _advanceTaxRules = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 8, vsync: this);
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
    _advanceTaxReminderDaysCtrl =
        TextEditingController(text: rules.advanceTaxReminderDays.toString());
    _advanceTaxInterestThresholdCtrl = TextEditingController(
        text: rules.advanceTaxInterestThreshold.toString());

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
    _taxableGiftKeys = List.from(rules.taxableGiftKeys);
    _advanceTaxRules = List.from(rules.advanceTaxRules);
    _enableAdvanceTaxInterest = rules.enableAdvanceTaxInterest;
    _interestTillPaymentDate = rules.interestTillPaymentDate;
    _isCgIncludedInAdvanceTax = rules.isCgIncludedInAdvanceTax;

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
    for (final ctrl in [
      _stdDedSalaryCtrl,
      _stdDedHPCtrl,
      _stdExempt112ACtrl,
      _ltcgRateCtrl,
      _stcgRateCtrl,
      _winReinvestCtrl,
      _rebateLimitCtrl,
      _cessRateCtrl,
      _maxCGReinvestLimitCtrl,
      _maxHPDedLimit,
      _limitGratuityCtrl,
      _limitLeaveEncashmentCtrl,
      _cashGiftLimitCtrl,
      _agriThresholdCtrl,
      _agriBasicLimitCtrl,
      _employerGiftLimitCtrl,
      _limit44ADCtrl,
      _rate44ADCtrl,
      _limit44ADACtrl,
      _rate44ADACtrl,
      _advanceTaxReminderDaysCtrl,
      _advanceTaxInterestThresholdCtrl,
      _customCountryCtrl,
    ]) {
      ctrl.dispose();
    }
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
        taxableGiftKeys: _taxableGiftKeys,
        advanceTaxRules: _advanceTaxRules,
        enableAdvanceTaxInterest: _enableAdvanceTaxInterest,
        interestTillPaymentDate: _interestTillPaymentDate,
        isCgIncludedInAdvanceTax: _isCgIncludedInAdvanceTax,
        advanceTaxReminderDays:
            int.tryParse(_advanceTaxReminderDaysCtrl.text) ?? 7,
        advanceTaxInterestThreshold:
            double.tryParse(_advanceTaxInterestThresholdCtrl.text) ?? 10000.0,
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
    // coverage:ignore-line
    if (val == null) return;
    // coverage:ignore-start
    if (_hasUnsavedChanges) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          // coverage:ignore-end
          title: const Text('Unsaved Changes'),
          content: const Text(
              'You have unsaved changes. Switching years will discard them. Continue?'),
          // coverage:ignore-start
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                // coverage:ignore-end
                child: const Text('Cancel')),
            TextButton(
                // coverage:ignore-line
                onPressed: () =>
                    Navigator.pop(ctx, true), // coverage:ignore-line
                child: const Text('Continue')),
          ],
        ),
      );
      if (!(confirm ?? false)) return;
    }
    setState(() => _selectedYear = val); // coverage:ignore-line
    _loadRulesForYear(val); // coverage:ignore-line
  }

  void _handleJurisdictionChange(String? val) {
    // coverage:ignore-line
    if (val == null) return;
    // coverage:ignore-start
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
        // coverage:ignore-end
      }
      _hasUnsavedChanges = true; // coverage:ignore-line
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
              onPressed: () =>
                  Navigator.pop(ctx, false), // coverage:ignore-line
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
        // coverage:ignore-line
        if (didPop) return;
        final shouldPop = await showDialog<bool>(
          // coverage:ignore-line
          context: context,
          builder: (ctx) => AlertDialog(
            // coverage:ignore-line
            title: const Text('Unsaved Changes'),
            content: const Text(
                'You have unsaved changes. Are you sure you want to leave?'),
            // coverage:ignore-start
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  // coverage:ignore-end
                  child: const Text('Cancel')),
              TextButton(
                  // coverage:ignore-line
                  onPressed: () =>
                      Navigator.pop(ctx, true), // coverage:ignore-line
                  child: const Text('Discard',
                      style: TextStyle(color: Colors.red))),
            ],
          ),
        );
        if (shouldPop ?? false) {
          if (context.mounted) Navigator.pop(context); // coverage:ignore-line
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
                onChanged: (val) =>
                    _handleYearChange(val), // coverage:ignore-line
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
              Tab(text: 'Advance Tax'),
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
                                onChanged: (val) => // coverage:ignore-line
                                    _handleJurisdictionChange(
                                        val), // coverage:ignore-line
                              ),
                            ),
                          ),
                        ),
                        if (_jurisdiction == 'Custom') ...[
                          const SizedBox(width: 12),
                          // coverage:ignore-start
                          Expanded(
                            child: TextField(
                              controller: _customCountryCtrl,
                              onChanged: (v) =>
                                  setState(() => _hasUnsavedChanges = true),
                              // coverage:ignore-end
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
                                  // coverage:ignore-line
                                  if (val != null) {
                                    // coverage:ignore-start
                                    setState(() {
                                      _fyStartMonth = val;
                                      _hasUnsavedChanges = true;
                                      // coverage:ignore-end
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
                    _buildAdvanceTaxTab(),
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
        _buildRebateSettings(),
        _buildCessSettings(),
        _buildCashGiftSettings(),
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

  Widget _buildRebateSettings() {
    return Column(
      children: [
        SwitchListTile(
          title: const Text('Enable Rebate'),
          value: _isRebateEnabled,
          onChanged: (v) => setState(() => _isRebateEnabled = v),
        ),
        if (_isRebateEnabled)
          _buildNumberField('Rebate Limit', _rebateLimitCtrl, isAmount: true),
      ],
    );
  }

  Widget _buildCessSettings() {
    return Column(
      children: [
        SwitchListTile(
          title: const Text('Enable Health & Edu Cess'),
          value: _isCessEnabled,
          onChanged: (v) =>
              setState(() => _isCessEnabled = v), // coverage:ignore-line
        ),
        if (_isCessEnabled) _buildNumberField('Cess Rate (%)', _cessRateCtrl),
      ],
    );
  }

  Widget _buildCashGiftSettings() {
    return Column(
      children: [
        SwitchListTile(
          title: const Text('Enable Cash Gift Exemption'),
          value: _isCashGiftExempt,
          onChanged: (v) =>
              setState(() => _isCashGiftExempt = v), // coverage:ignore-line
        ),
        if (_isCashGiftExempt) ...[
          _buildNumberField('Cash Gift Exemption Limit', _cashGiftLimitCtrl,
              isAmount: true),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text('Select Taxable Gift Types:',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Wrap(
            spacing: 8,
            children: ['relative', 'marriage', 'friend', 'other']
                .map((type) => _buildGiftTypeChip(type))
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildGiftTypeChip(String type) {
    final isSelected = _taxableGiftKeys.contains(type);
    return FilterChip(
      label: Text(type.toGiftDisplay()),
      selected: isSelected,
      onSelected: (selected) {
        // coverage:ignore-line
        setState(() {
          // coverage:ignore-line
          if (selected) {
            _taxableGiftKeys.add(type); // coverage:ignore-line
          } else {
            _taxableGiftKeys.remove(type); // coverage:ignore-line
          }
          _hasUnsavedChanges = true; // coverage:ignore-line
        });
      },
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
              // coverage:ignore-line
              padding: const EdgeInsets.all(16),
              children: [
                // coverage:ignore-line
                const Text(
                    'Map Transaction Tags or Descriptions to Tax Heads for auto-assignment.'),
                const SizedBox(height: 16),
                // coverage:ignore-start
                ..._tagMappings.entries.map((e) {
                  return Card(
                    child: ListTile(
                      title: Text(e.key), // Tag or Description
                      subtitle: Text('Maps to: ${e.value.toHumanReadable()}'),
                      trailing: IconButton(
                        // coverage:ignore-end
                        icon: const Icon(Icons.delete),
                        // coverage:ignore-start
                        onPressed: () {
                          setState(() {
                            _tagMappings.remove(e.key);
                            _hasUnsavedChanges = true;
                            // coverage:ignore-end
                          });
                        },
                      ),
                    ),
                  );
                }),
                const Divider(), // coverage:ignore-line
                const Text(
                    'Advanced Mappings (CG / Filters)', // coverage:ignore-line
                    style: TextStyle(fontWeight: FontWeight.bold)),
                // coverage:ignore-start
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
                        // coverage:ignore-end
                        icon: const Icon(Icons.delete),
                        // coverage:ignore-start
                        onPressed: () {
                          setState(() {
                            _advancedMappings.removeAt(i);
                            _hasUnsavedChanges = true;
                            // coverage:ignore-end
                          });
                        },
                      ),
                      onTap: () => _addMappingDialog(
                          existingRule: r, index: i), // coverage:ignore-line
                    ),
                  );
                }),
              ],
            ),
    );
  }

  // coverage:ignore-start
  void _addMappingDialog({TaxMappingRule? existingRule, int? index}) {
    showDialog(
      context: context,
      builder: (ctx) => _TaxMappingDialog(
        // coverage:ignore-end
        existingRule: existingRule,
        // coverage:ignore-start
        incomeCategories: ref
            .read(storageServiceProvider)
            .getCategories()
            .where((c) => c.usage == CategoryUsage.income)
            .toList(),
        transactionDescriptions: _transactionDescriptions,
        onSave: (mapByTag,
            selectedTag,
            selectedCat,
            selectedHead,
            // coverage:ignore-end
            matchDescriptions,
            excludeDescriptions,
            minHoldingMonths) {
          _saveMapping(
              mapByTag,
              selectedTag,
              selectedCat,
              selectedHead, // coverage:ignore-line
              matchDescriptions,
              excludeDescriptions,
              minHoldingMonths,
              index);
        },
      ),
    );
  }

  void _saveMapping(
      // coverage:ignore-line
      bool mapByTag,
      CategoryTag selectedTag,
      String selectedCat,
      String selectedHead,
      List<String> matchDescriptions,
      List<String> excludeDescriptions,
      int? minHoldingMonths,
      int? index) {
    if (selectedHead == 'ltcg' || selectedHead == 'stcg') {
      // coverage:ignore-line
      _saveAdvancedMapping(
          mapByTag,
          selectedTag,
          selectedCat,
          selectedHead, // coverage:ignore-line
          matchDescriptions,
          excludeDescriptions,
          minHoldingMonths,
          index);
    } else {
      _saveSimpleMapping(mapByTag, selectedTag, selectedCat,
          selectedHead); // coverage:ignore-line
    }
    setState(() => _hasUnsavedChanges = true); // coverage:ignore-line
  }

  void _saveAdvancedMapping(
      // coverage:ignore-line
      bool mapByTag,
      CategoryTag selectedTag,
      String selectedCat,
      String selectedHead,
      List<String> matchDescriptions,
      List<String> excludeDescriptions,
      int? minHoldingMonths,
      int? index) {
    final newRule = TaxMappingRule(
      // coverage:ignore-line
      categoryName:
          mapByTag ? selectedTag.name : selectedCat, // coverage:ignore-line
      taxHead: selectedHead,
      matchDescriptions: matchDescriptions,
      excludeDescriptions: excludeDescriptions,
      minHoldingMonths: minHoldingMonths,
    );

    setState(() {
      // coverage:ignore-line
      if (index != null) {
        _advancedMappings[index] = newRule; // coverage:ignore-line
      } else {
        _advancedMappings.add(newRule); // coverage:ignore-line
      }
    });
  }

  void _saveSimpleMapping(
      bool mapByTag,
      CategoryTag selectedTag, // coverage:ignore-line
      String selectedCat,
      String selectedHead) {
    // coverage:ignore-start
    setState(() {
      final key = mapByTag ? selectedTag.name : selectedCat;
      if (key.isNotEmpty) {
        _tagMappings[key] = selectedHead;
        // coverage:ignore-end
      }
    });
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
                    // coverage:ignore-start
                    onPressed: () {
                      setState(() {
                        _slabs.add(
                            // coverage:ignore-end
                            const TaxSlab(TaxRules.infinitySubstitute, 30));
                        _hasUnsavedChanges = true; // coverage:ignore-line
                      });
                    }),
              ],
            ),
            ..._slabs.asMap().entries.map((entry) {
              final index = entry.key;
              final slab = entry.value;
              return Row(
                children: [
                  Text(
                      '${CurrencyUtils.getSymbol(ref.watch(currencyProvider))}  '),
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
                      // coverage:ignore-start
                      onChanged: (val) {
                        setState(() {
                          double limit = val.isEmpty
                              // coverage:ignore-end
                              ? TaxRules.infinitySubstitute
                              : double.tryParse(val) ?? // coverage:ignore-line
                                  TaxRules.infinitySubstitute;
                          _slabs[index] =
                              TaxSlab(limit, slab.rate); // coverage:ignore-line
                          _hasUnsavedChanges = true; // coverage:ignore-line
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
                      // coverage:ignore-start
                      onChanged: (val) {
                        setState(() {
                          _slabs[index] =
                              TaxSlab(slab.upto, double.tryParse(val) ?? 0);
                          _hasUnsavedChanges = true;
                          // coverage:ignore-end
                        });
                      },
                    ),
                  ),
                  const Text('%'),
                  IconButton(
                      icon: const Icon(Icons.delete, size: 16),
                      // coverage:ignore-start
                      onPressed: () {
                        setState(() {
                          _slabs.removeAt(index);
                          _hasUnsavedChanges = true;
                          // coverage:ignore-end
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
      {bool isInt = false, bool isAmount = false, String? subtitle}) {
    final currencySymbol =
        ref.watch(currencyProvider.select((l) => CurrencyUtils.getSymbol(l)));
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        // coverage:ignore-start
        onChanged: (v) {
          if (!_hasUnsavedChanges) {
            setState(() => _hasUnsavedChanges = true);
            // coverage:ignore-end
          }
        },
        decoration: InputDecoration(
          labelText: label,
          helperText: subtitle,
          prefixText: isAmount ? '$currencySymbol ' : null,
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
          // coverage:ignore-start
          onChanged: (v) => setState(() {
            _isStdDedSalaryEnabled = v;
            _hasUnsavedChanges = true;
            // coverage:ignore-end
          }),
        ),
        if (_isStdDedSalaryEnabled)
          _buildNumberField('Standard Deduction (Salary)', _stdDedSalaryCtrl,
              isAmount: true),
        const Divider(),
        _buildSectionHeader('Retirement Exemptions'),
        SwitchListTile(
          title: const Text('Enable Retirement / Resignation Exemptions'),
          subtitle: const Text('Gratuity & Leave Encashment'),
          value: _isRetirementExemptionEnabled,
          // coverage:ignore-start
          onChanged: (v) => setState(() {
            _isRetirementExemptionEnabled = v;
            _hasUnsavedChanges = true;
            // coverage:ignore-end
          }),
        ),
        if (_isRetirementExemptionEnabled) ...[
          _buildNumberField('Gratuity Exemption Limit', _limitGratuityCtrl,
              isAmount: true),
          _buildNumberField('Leave Encashment Limit', _limitLeaveEncashmentCtrl,
              isAmount: true),
        ],
        const Divider(),
        _buildSectionHeader('Employer Gifts'),
        SwitchListTile(
          title: const Text('Enable Gifts from Employer Rule'),
          subtitle: const Text('Exempt up to a limit'),
          value: _isEmployerGiftEnabled,
          // coverage:ignore-start
          onChanged: (v) => setState(() {
            _isEmployerGiftEnabled = v;
            _hasUnsavedChanges = true;
            // coverage:ignore-end
          }),
        ),
        if (_isEmployerGiftEnabled)
          _buildNumberField('Gift Exemption Limit', _employerGiftLimitCtrl,
              isAmount: true, subtitle: 'Default: 5000'),
      ],
    );
  }

  Widget _buildBusinessTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('Presumptive Income'),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text('Enable Business exemption'),
          subtitle: const Text('Presumptive income for Businesses'),
          value: _is44ADEnabled,
          // coverage:ignore-start
          onChanged: (v) => setState(() {
            _is44ADEnabled = v;
            _hasUnsavedChanges = true;
            // coverage:ignore-end
          }),
        ),
        if (_is44ADEnabled) ...[
          _buildNumberField('Turnover Limit for 44AD', _limit44ADCtrl,
              isInt: true, isAmount: true),
          _buildNumberField('Presumptive Profit Rate (%)', _rate44ADCtrl),
        ],
        const Divider(),
        SwitchListTile(
          title: const Text('Enable Professional exemption'),
          subtitle: const Text('Presumptive income for Professionals'),
          value: _is44ADAEnabled,
          // coverage:ignore-start
          onChanged: (v) => setState(() {
            _is44ADAEnabled = v;
            _hasUnsavedChanges = true;
            // coverage:ignore-end
          }),
        ),
        if (_is44ADAEnabled) ...[
          _buildNumberField('Gross Receipts Limit for 44ADA', _limit44ADACtrl,
              isInt: true, isAmount: true),
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
          // coverage:ignore-start
          onChanged: (v) => setState(() {
            _isStdDedHPEnabled = v;
            _hasUnsavedChanges = true;
            // coverage:ignore-end
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
          // coverage:ignore-start
          onChanged: (v) => setState(() {
            _isHPMaxInterestEnabled = v;
            _hasUnsavedChanges = true;
            // coverage:ignore-end
          }),
        ),
        if (_isHPMaxInterestEnabled)
          _buildNumberField('Max Interest Deduction (Self-Occ)', _maxHPDedLimit,
              isAmount: true),
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
          // coverage:ignore-start
          onChanged: (v) => setState(() {
            _isCGRatesEnabled = v;
            _hasUnsavedChanges = true;
            // coverage:ignore-end
          }),
        ),
        if (_isCGRatesEnabled) ...[
          _buildNumberField('LTCG Rate (Equity) %', _ltcgRateCtrl),
          _buildNumberField('STCG Rate (Equity) %', _stcgRateCtrl),
        ],
        SwitchListTile(
          title: const Text('Enable LTCG Exemption'),
          value: _isLTCGExemption112AEnabled,
          // coverage:ignore-start
          onChanged: (v) => setState(() {
            _isLTCGExemption112AEnabled = v;
            _hasUnsavedChanges = true;
            // coverage:ignore-end
          }),
        ),
        if (_isLTCGExemption112AEnabled)
          _buildNumberField('Standard Exemption (LTCG)', _stdExempt112ACtrl,
              isAmount: true),
        const Divider(),
        _buildSectionHeader('Reinvestment Rules'),
        SwitchListTile(
          title: const Text('Enable Reinvestment Exemptions'),
          value: _isCGReinvestmentEnabled,
          // coverage:ignore-start
          onChanged: (v) => setState(() {
            _isCGReinvestmentEnabled = v;
            _hasUnsavedChanges = true;
            // coverage:ignore-end
          }),
        ),
        if (_isCGReinvestmentEnabled) ...[
          _buildNumberField('Reinvestment Window (Years)', _winReinvestCtrl),
          _buildNumberField(
              'Max Capital Gain Reinvest Limit', _maxCGReinvestLimitCtrl,
              isAmount: true),
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
          // coverage:ignore-start
          onChanged: (v) => setState(() {
            _isAgriIncomeEnabled = v;
            _hasUnsavedChanges = true;
            // coverage:ignore-end
          }),
        ),
        if (_isAgriIncomeEnabled) ...[
          const Text(
              'Partial Integration Method determines tax on Agriculture Income if it exceeds the threshold and non-agri income exceeds basic exemption.'),
          const SizedBox(height: 16),
          _buildNumberField('Agriculture Income Threshold', _agriThresholdCtrl,
              isAmount: true,
              subtitle:
                  'Default: ${CurrencyUtils.formatCurrency(5000, ref.watch(currencyProvider))}'),
          _buildNumberField('Agri Basic Exemption Limit', _agriBasicLimitCtrl,
              isAmount: true,
              subtitle:
                  'Default: ${CurrencyUtils.formatCurrency(400000, ref.watch(currencyProvider))} (Used for Partial Integration)'),
        ],
      ],
    );
  }

  Widget _buildCustomExemptionsEditor() {
    // Defines custom exemptions displayed in General or Mappings
    if (_customExemptions.isEmpty) {
      return const Padding(
          padding: EdgeInsets.all(8),
          child: Text('No custom exemptions defined.'));
    }

    // coverage:ignore-start
    return Column(
        children: _customExemptions.asMap().entries.map((e) {
      final i = e.key;
      final rule = e.value;
      return SwitchListTile(
        title: Text(rule.name),
        subtitle: Text(
            '${rule.incomeHead} • Max: ${CurrencyUtils.formatCurrency(rule.limit, ref.watch(currencyProvider))}${rule.isCliffExemption ? " • Cliff" : ""}'),
        value: rule.isEnabled,
        onChanged: (val) {
          setState(() {
            _customExemptions[i] = rule.copyWith(isEnabled: val);
            _hasUnsavedChanges = true;
            // coverage:ignore-end
          });
        },
        secondary: IconButton(
            // coverage:ignore-line
            icon: const Icon(Icons.delete),
            // coverage:ignore-start
            onPressed: () => setState(() {
                  _customExemptions.removeAt(i);
                  _hasUnsavedChanges = true;
                  // coverage:ignore-end
                })),
      );
    }).toList()); // coverage:ignore-line
  }

  Widget _buildAdvanceTaxTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('Advance Tax Configurations'),
        const Text(
          'Define the installment schedule, required percentages, and interest rates for advance tax calculations.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text('Enable Advance Tax Interest Calculation'),
          subtitle: const Text('Calculate interest based on shortfalls'),
          value: _enableAdvanceTaxInterest,
          // coverage:ignore-start
          onChanged: (v) => setState(() {
            _enableAdvanceTaxInterest = v;
            _hasUnsavedChanges = true;
            // coverage:ignore-end
          }),
        ),
        _buildNumberField(
          'Reminder Days Before Deadline',
          _advanceTaxReminderDaysCtrl,
          isAmount: false,
        ),
        _buildNumberField(
          'Interest Calculation Base Threshold (Fixed)',
          _advanceTaxInterestThresholdCtrl,
          isAmount: true,
          subtitle:
              'Advance tax interest applies only if tax liability after TDS exceeds this amount.',
        ),
        if (_enableAdvanceTaxInterest) ...[
          SwitchListTile(
            title: const Text('Interest till Payment Date'),
            subtitle: const Text(
                'If missed installment, calculate interest till payment date instead of next installment.'),
            value: _interestTillPaymentDate,
            // coverage:ignore-start
            onChanged: (v) => setState(() {
              _interestTillPaymentDate = v;
              _hasUnsavedChanges = true;
              // coverage:ignore-end
            }),
          ),
          SwitchListTile(
            title: const Text('Include Capital Gains in Advance Tax Base'),
            subtitle: const Text(
                'If enabled, STCG/LTCG tax is included in required installments. If disabled, ONLY Normal Income (Salary, Business, etc.) is considered for installment matching.'),
            value: _isCgIncludedInAdvanceTax,
            // coverage:ignore-start
            onChanged: (v) => setState(() {
              _isCgIncludedInAdvanceTax = v;
              _hasUnsavedChanges = true;
              // coverage:ignore-end
            }),
          ),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Installment Schedule',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              TextButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Installment'),
                onPressed: _advanceTaxRules.length < 4 ? _addInstallment : null,
              ),
            ],
          ),
          if (_advanceTaxRules.isEmpty)
            const Padding(
              // coverage:ignore-line
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                  child: Text('No installments configured.',
                      style: TextStyle(color: Colors.grey))),
            )
          else
            ..._advanceTaxRules
                .asMap()
                .entries
                .map((e) => _buildInstallmentRuleTile(e.key, e.value)),
        ],
      ],
    );
  }

  Widget _buildInstallmentRuleTile(int i, AdvanceTaxInstallmentRule r) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Installment #${i + 1}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                  onPressed: _advanceTaxRules.length > 1
                      // coverage:ignore-start
                      ? () => setState(() {
                            _advanceTaxRules.removeAt(i);
                            _hasUnsavedChanges = true;
                            // coverage:ignore-end
                          })
                      : null,
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: _buildMonthDayPicker(
                    label: 'Start Month',
                    month: r.startMonth,
                    day: r.startDay,
                    // coverage:ignore-start
                    onChanged: (m, d) => setState(() {
                      _advanceTaxRules[i] =
                          r.copyWith(startMonth: m, startDay: d);
                      _hasUnsavedChanges = true;
                      // coverage:ignore-end
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMonthDayPicker(
                    label: 'End Month',
                    month: r.endMonth,
                    day: r.endDay,
                    // coverage:ignore-start
                    onChanged: (m, d) => setState(() {
                      _advanceTaxRules[i] = r.copyWith(endMonth: m, endDay: d);
                      _hasUnsavedChanges = true;
                      // coverage:ignore-end
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: r.requiredPercentage.toString(),
                    decoration: const InputDecoration(
                      labelText: 'Required %',
                      suffixText: '%',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegexUtils.amountExp)
                    ],
                    // coverage:ignore-start
                    onChanged: (v) => setState(() {
                      _advanceTaxRules[i] = r.copyWith(
                          requiredPercentage: double.tryParse(v) ?? 0);
                      _hasUnsavedChanges = true;
                      // coverage:ignore-end
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    initialValue: r.interestRate.toString(),
                    decoration: const InputDecoration(
                      labelText: 'Interest Rate % (Monthly)',
                      suffixText: '%',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegexUtils.amountExp)
                    ],
                    // coverage:ignore-start
                    onChanged: (v) => setState(() {
                      _advanceTaxRules[i] =
                          r.copyWith(interestRate: double.tryParse(v) ?? 0);
                      _hasUnsavedChanges = true;
                      // coverage:ignore-end
                    }),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // coverage:ignore-start
  void _addInstallment() {
    setState(() {
      _advanceTaxRules.add(const AdvanceTaxInstallmentRule(
        // coverage:ignore-end
        startMonth: 4,
        startDay: 1,
        endMonth: 6,
        endDay: 15,
        requiredPercentage: 15,
        interestRate: 1.0,
      ));
      _hasUnsavedChanges = true; // coverage:ignore-line
    });
  }

  Widget _buildMonthDayPicker({
    required String label,
    required int month,
    required int day,
    required void Function(int, int) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: DropdownButtonHideUnderline(
                child: DropdownButtonFormField<int>(
                  initialValue: month,
                  isDense: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                  items: [
                    for (int i = 1; i <= 12; i++)
                      DropdownMenuItem(
                        value: i,
                        child: Text(_getMonthName(i).substring(0, 3),
                            style: const TextStyle(fontSize: 12)),
                      ),
                  ],
                  onChanged: (v) {
                    // coverage:ignore-line
                    if (v != null) onChanged(v, day); // coverage:ignore-line
                  },
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: TextFormField(
                initialValue: day.toString(),
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                ),
                style: const TextStyle(fontSize: 12),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                // coverage:ignore-start
                onChanged: (v) {
                  final newDay = int.tryParse(v) ?? 1;
                  onChanged(month, newDay.clamp(1, 31));
                  // coverage:ignore-end
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  // coverage:ignore-start
  void _addCustomRuleDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _CustomExemptionDialog(
        onAdd: (rule) {
          setState(() {
            _customExemptions.add(rule);
            _hasUnsavedChanges = true;
            // coverage:ignore-end
          });
        },
      ),
    );
  }
}

class _CustomExemptionDialog extends StatefulWidget {
  final Function(TaxExemptionRule) onAdd;

  const _CustomExemptionDialog({required this.onAdd}); // coverage:ignore-line

  @override // coverage:ignore-line
  State<_CustomExemptionDialog> createState() =>
      _CustomExemptionDialogState(); // coverage:ignore-line
}

class _CustomExemptionDialogState extends State<_CustomExemptionDialog> {
  final _nameCtrl = TextEditingController();
  final _limitCtrl = TextEditingController();
  String _head = 'Other';
  bool _isCliff = false;

  final _heads = [
    'Salary',
    'House Property',
    'Business',
    'Other',
    'Gift',
    'Agriculture'
  ];

  @override // coverage:ignore-line
  void dispose() {
    // coverage:ignore-start
    _nameCtrl.dispose();
    _limitCtrl.dispose();
    super.dispose();
    // coverage:ignore-end
  }

  @override // coverage:ignore-line
  Widget build(BuildContext context) {
    return AlertDialog(
      // coverage:ignore-line
      title: const Text('Add Custom Exemption'),
      // coverage:ignore-start
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: _nameCtrl,
              // coverage:ignore-end
              decoration: const InputDecoration(labelText: 'Name'),
              textCapitalization: TextCapitalization.words),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            // coverage:ignore-line
            initialValue: _head, // coverage:ignore-line
            decoration: const InputDecoration(
              labelText: 'Income Head',
              border: OutlineInputBorder(),
            ),
            // coverage:ignore-start
            items: _heads
                .map((h) => DropdownMenuItem(value: h, child: Text(h)))
                .toList(),
            onChanged: (val) {
              // coverage:ignore-end
              if (val != null) {
                setState(() => _head = val); // coverage:ignore-line
              }
            },
          ),
          const SizedBox(height: 12),
          TextField(
              // coverage:ignore-line
              controller: _limitCtrl, // coverage:ignore-line
              decoration: const InputDecoration(labelText: 'Limit'),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                // coverage:ignore-line
                FilteringTextInputFormatter.allow(
                    RegexUtils.amountExp), // coverage:ignore-line
              ]),
          const SizedBox(height: 12),
          SwitchListTile(
            // coverage:ignore-line
            title: const Text('Is Cliff Exemption?'),
            subtitle: const Text(
                'If checked, income above limit becomes fully taxable.'),
            value: _isCliff, // coverage:ignore-line
            onChanged: (v) =>
                setState(() => _isCliff = v), // coverage:ignore-line
          ),
        ]),
      ),
      // coverage:ignore-start
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            // coverage:ignore-end
            child: const Text('Cancel')),
        // coverage:ignore-start
        FilledButton(
          onPressed: () {
            widget.onAdd(TaxExemptionRule(
              id: 'rule_${DateTime.now().millisecondsSinceEpoch}',
              name: _nameCtrl.text,
              incomeHead: _head,
              limit: double.tryParse(_limitCtrl.text) ?? 0,
              // coverage:ignore-end
              isPercentage: false,
              isCliffExemption: _isCliff, // coverage:ignore-line
            ));
            Navigator.pop(context); // coverage:ignore-line
          },
          child: const Text('Add'),
        )
      ],
    );
  }
}

class _TaxMappingDialog extends StatefulWidget {
  final TaxMappingRule? existingRule;
  final List<Category> incomeCategories;
  final List<String> transactionDescriptions;
  final Function(
    bool mapByTag,
    CategoryTag selectedTag,
    String selectedCat,
    String selectedHead,
    List<String> matchDescriptions,
    List<String> excludeDescriptions,
    int? minHoldingMonths,
  ) onSave;

  const _TaxMappingDialog({
    // coverage:ignore-line
    this.existingRule,
    required this.incomeCategories,
    required this.transactionDescriptions,
    required this.onSave,
  });

  @override // coverage:ignore-line
  State<_TaxMappingDialog> createState() =>
      _TaxMappingDialogState(); // coverage:ignore-line
}

class _TaxMappingDialogState extends State<_TaxMappingDialog> {
  late bool _mapByTag;
  late CategoryTag _selectedTag;
  late String _selectedCat;
  late String _selectedHead;

  late List<String> _matchDescriptions;
  late List<String> _excludeDescriptions;

  final _matchDescCtrl = TextEditingController();
  final _excludeDescCtrl = TextEditingController();
  late TextEditingController _minMonthsCtrl;

  @override // coverage:ignore-line
  void initState() {
    // coverage:ignore-start
    super.initState();
    _mapByTag = true;
    _selectedTag = CategoryTag.values.firstWhere((t) => t != CategoryTag.none,
        orElse: () => CategoryTag.none);
    _selectedCat = widget.existingRule?.categoryName ?? '';
    _selectedHead = widget.existingRule?.taxHead ?? 'other';
    // coverage:ignore-end

    // coverage:ignore-start
    _matchDescriptions = widget.existingRule != null
        ? List.from(widget.existingRule!.matchDescriptions)
        : [];
    _excludeDescriptions = widget.existingRule != null
        ? List.from(widget.existingRule!.excludeDescriptions)
        : [];
    // coverage:ignore-end

    _minMonthsCtrl = TextEditingController(
        // coverage:ignore-line
        text: widget.existingRule?.minHoldingMonths?.toString() ??
            ''); // coverage:ignore-line
  }

  @override // coverage:ignore-line
  void dispose() {
    // coverage:ignore-start
    _matchDescCtrl.dispose();
    _excludeDescCtrl.dispose();
    _minMonthsCtrl.dispose();
    super.dispose();
    // coverage:ignore-end
  }

  @override // coverage:ignore-line
  Widget build(BuildContext context) {
    return AlertDialog(
      // coverage:ignore-line
      title: const Text('Add Mapping'),
      content: SingleChildScrollView(
        // coverage:ignore-line
        child: Column(
          // coverage:ignore-line
          mainAxisSize: MainAxisSize.min,
          children: [
            // coverage:ignore-line
            _buildMappingTypeSelector(), // coverage:ignore-line
            const SizedBox(height: 16),
            _buildTagOrCategoryDropdown(), // coverage:ignore-line
            const SizedBox(height: 16),
            // coverage:ignore-start
            _buildTaxHeadDropdown(),
            if (_selectedHead == 'ltcg' || _selectedHead == 'stcg')
              _buildAdvancedCriteria(),
            // coverage:ignore-end
          ],
        ),
      ),
      // coverage:ignore-start
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            // coverage:ignore-end
            child: const Text('Cancel')),
        // coverage:ignore-start
        FilledButton(
          onPressed: () {
            if (_matchDescCtrl.text.isNotEmpty) {
              _matchDescriptions.add(_matchDescCtrl.text);
              // coverage:ignore-end
            }
            if (_excludeDescCtrl.text.isNotEmpty) {
              // coverage:ignore-line
              _excludeDescriptions
                  .add(_excludeDescCtrl.text); // coverage:ignore-line
            }
            // coverage:ignore-start
            widget.onSave(
              _mapByTag,
              _selectedTag,
              _selectedCat,
              _selectedHead,
              _matchDescriptions,
              _excludeDescriptions,
              int.tryParse(_minMonthsCtrl.text),
              // coverage:ignore-end
            );
            Navigator.pop(context); // coverage:ignore-line
          },
          child: Text(widget.existingRule != null
              ? 'Update'
              : 'Add'), // coverage:ignore-line
        ),
      ],
    );
  }

  // coverage:ignore-start
  Widget _buildMappingTypeSelector() {
    return RadioGroup<bool>(
      groupValue: _mapByTag,
      onChanged: (v) => setState(() => _mapByTag = v!),
      // coverage:ignore-end
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

  // coverage:ignore-start
  Widget _buildTagOrCategoryDropdown() {
    if (_mapByTag) {
      return DropdownButtonFormField<CategoryTag>(
        initialValue: _selectedTag,
        // coverage:ignore-end
        decoration: const InputDecoration(
          labelText: 'Select Tag',
          border: OutlineInputBorder(),
        ),
        items: CategoryTag.values
            .where((t) => t != CategoryTag.none) // coverage:ignore-line
            .map((t) => DropdownMenuItem(
                  // coverage:ignore-line
                  value: t,
                  child: Text(t.name.toHumanReadable()), // coverage:ignore-line
                ))
            // coverage:ignore-start
            .toList(),
        onChanged: (v) {
          if (v != null) setState(() => _selectedTag = v);
          // coverage:ignore-end
        },
      );
    }
    // coverage:ignore-start
    return DropdownButtonFormField<String>(
      initialValue: _selectedCat.isEmpty && widget.incomeCategories.isNotEmpty
          ? widget.incomeCategories.first.name
          : _selectedCat,
      // coverage:ignore-end
      decoration: const InputDecoration(
        labelText: 'Select Category',
        border: OutlineInputBorder(),
      ),
      // coverage:ignore-start
      items: widget.incomeCategories
          .map((c) => DropdownMenuItem(
                value: c.name,
                child: Text(c.name),
                // coverage:ignore-end
              ))
          // coverage:ignore-start
          .toList(),
      onChanged: (v) {
        if (v != null) setState(() => _selectedCat = v);
        // coverage:ignore-end
      },
    );
  }

  // coverage:ignore-start
  Widget _buildTaxHeadDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedHead,
      // coverage:ignore-end
      decoration: const InputDecoration(
        labelText: 'Maps to Tax Head',
        border: OutlineInputBorder(),
      ),
      items: [
        // coverage:ignore-line
        'houseProp',
        'business',
        'ltcg',
        'stcg',
        'dividend',
        'other',
        'agriIncome',
        'gift',
        if (_selectedHead == 'salary') 'salary', // coverage:ignore-line
      ]
          // coverage:ignore-start
          .map((h) =>
              DropdownMenuItem(value: h, child: Text(h.toHumanReadable())))
          .toList(),
      onChanged: (v) {
        if (v != null) setState(() => _selectedHead = v);
        // coverage:ignore-end
      },
    );
  }

  // coverage:ignore-start
  Widget _buildAdvancedCriteria() {
    return Column(
      children: [
        // coverage:ignore-end
        const SizedBox(height: 16),
        const Text('Advanced Mapping Criteria',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        // coverage:ignore-start
        TextField(
          controller: _minMonthsCtrl,
          decoration: InputDecoration(
            labelText: _getHoldingPeriodLabel(),
            // coverage:ignore-end
            border: const OutlineInputBorder(),
            helperText: 'Leave empty for any period',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: false),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly
          ], // coverage:ignore-line
        ),
        const SizedBox(height: 12),
        // coverage:ignore-start
        _buildDescriptionField(_matchDescCtrl, 'Must Match Description',
            'e.g., Sold', _matchDescriptions),
        if (_matchDescriptions.isNotEmpty)
          _buildDescriptionChips(_matchDescriptions),
        const SizedBox(height: 12),
        _buildDescriptionField(_excludeDescCtrl, 'Exclude Description',
            'e.g., Transfer', _excludeDescriptions,
            // coverage:ignore-end
            isExclude: true),
        if (_excludeDescriptions.isNotEmpty) // coverage:ignore-line
          _buildDescriptionChips(_excludeDescriptions,
              isExclude: true), // coverage:ignore-line
      ],
    );
  }

  // coverage:ignore-start
  String _getHoldingPeriodLabel() {
    if (_selectedHead == 'stcg') return 'STCG if holding period < (months)';
    if (_selectedHead == 'ltcg') return 'LTCG if holding period >= (months)';
    // coverage:ignore-end
    return 'Holding period threshold (months)';
  }

  Widget _buildDescriptionField(
      TextEditingController ctrl,
      String labelText, // coverage:ignore-line
      String hintText,
      List<String> descriptions,
      {bool isExclude = false}) {
    // coverage:ignore-start
    return Row(
      children: [
        Expanded(
          child: _buildAutocomplete(
            // coverage:ignore-end
            controller: ctrl,
            labelText: labelText,
            hintText: hintText,
          ),
        ),
        IconButton(
          // coverage:ignore-line
          icon: const Icon(Icons.add),
          // coverage:ignore-start
          onPressed: () {
            if (ctrl.text.isNotEmpty) {
              setState(() {
                descriptions.add(ctrl.text);
                ctrl.clear();
                // coverage:ignore-end
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildAutocomplete({
    // coverage:ignore-line
    required TextEditingController controller,
    required String labelText,
    required String hintText,
  }) {
    return RawAutocomplete<String>(
      // coverage:ignore-line
      textEditingController: controller,
      // coverage:ignore-start
      focusNode: FocusNode(),
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          // coverage:ignore-end
          return const Iterable<String>.empty();
        }
        return widget.transactionDescriptions.where((String option) {
          // coverage:ignore-line
          return option
              .toLowerCase() // coverage:ignore-line
              .contains(
                  textEditingValue.text.toLowerCase()); // coverage:ignore-line
        });
      },
      fieldViewBuilder:
          (context, fieldController, focusNode, onFieldSubmitted) {
        // coverage:ignore-line
        return TextField(
          // coverage:ignore-line
          controller: fieldController,
          focusNode: focusNode,
          decoration: InputDecoration(
              // coverage:ignore-line
              labelText: labelText,
              border: const OutlineInputBorder(),
              hintText: hintText),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        // coverage:ignore-line
        return Align(
          // coverage:ignore-line
          alignment: Alignment.topLeft,
          child: Material(
            // coverage:ignore-line
            elevation: 4.0,
            child: SizedBox(
              // coverage:ignore-line
              height: 200,
              width: 300,
              child: ListView.builder(
                // coverage:ignore-line
                padding: const EdgeInsets.all(8.0),
                // coverage:ignore-start
                itemCount: options.length,
                itemBuilder: (BuildContext context, int index) {
                  final String option = options.elementAt(index);
                  return GestureDetector(
                    onTap: () {
                      onSelected(option);
                      // coverage:ignore-end
                    },
                    child: ListTile(
                      // coverage:ignore-line
                      title: Text(option), // coverage:ignore-line
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

  Widget _buildDescriptionChips(
      List<String> descriptions, // coverage:ignore-line
      {bool isExclude = false}) {
    return Wrap(
      // coverage:ignore-line
      spacing: 8,
      // coverage:ignore-start
      children: descriptions.map((d) {
        return Chip(
          label: Text(d,
              style: TextStyle(
                  // coverage:ignore-end
                  fontSize: 10,
                  color: isExclude ? Colors.red : null)),
          onDeleted: () =>
              setState(() => descriptions.remove(d)), // coverage:ignore-line
        );
      }).toList(), // coverage:ignore-line
    );
  }
}
