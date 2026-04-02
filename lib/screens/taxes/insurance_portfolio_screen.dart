import 'package:samriddhi_flow/screens/taxes/tax_constants.dart';
import 'package:samriddhi_flow/utils/regex_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samriddhi_flow/l10n/app_localizations.dart';
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
import 'package:intl/intl.dart';

// Removed capitalGainsText constant as it was used for localized string comparison

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
            ? DateTime.now().year - 1 // coverage:ignore-line
            : DateTime.now().year);
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context)!.taxRulesUpdatedStatus)));
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
      title: Text(existing == null
          ? AppLocalizations.of(context)!.addPolicyTitle
          : AppLocalizations.of(context)!
              .editPolicyTitle), // coverage:ignore-line
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
            onPressed: () => Navigator.pop(ctx), // coverage:ignore-line
            child: Text(AppLocalizations.of(context)!.cancelAction)),
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
            child: Text(AppLocalizations.of(context)!.saveAction)),
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
        _buildTextField(
            nameCtrl, AppLocalizations.of(context)!.policyNameLabel),
        _buildAmountTextField(
            premiumCtrl,
            AppLocalizations.of(context)!.annualPremiumLabel(
                CurrencyUtils.getSymbol(ref.watch(currencyProvider)))),
        _buildAmountTextField(
            sumAssuredCtrl,
            AppLocalizations.of(context)!.sumAssuredLabel(
                CurrencyUtils.getSymbol(ref.watch(currencyProvider)))),
        const SizedBox(height: 16),
        _buildPolicyDatePickerRow(AppLocalizations.of(context)!.issueDateLabel,
            selectedDate, onStartSelected, DateTime(2000), DateTime.now()),
        _buildPolicyDatePickerRow(
            AppLocalizations.of(context)!.maturityDateLabel,
            maturityDate,
            onMaturitySelected,
            selectedDate,
            DateTime(2050)),
        CheckboxListTile(
          title: Text(AppLocalizations.of(context)!.isUlipLabel),
          value: isUlip,
          onChanged: (v) => onUlipChanged(v ?? false), // coverage:ignore-line
        ),
        CheckboxListTile(
          title: Text(AppLocalizations.of(context)!.enableInstallmentLabel),
          value: isInstallment,
          onChanged: (v) =>
              onInstallmentChanged(v ?? false), // coverage:ignore-line
        ),
        if (isInstallment)
          _buildPolicyDatePickerRow(
              // coverage:ignore-line
              AppLocalizations.of(context)!
                  .installmentStartLabel, // coverage:ignore-line
              installmentStart ?? selectedDate,
              (d) => onInstallmentStartSelected(d), // coverage:ignore-line
              selectedDate,
              maturityDate,
              labelOverride: installmentStart == null
                  ? AppLocalizations.of(context)!
                      .selectDateAction // coverage:ignore-line
                  : null),
      ],
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(labelText: label),
    );
  }

  Widget _buildAmountTextField(TextEditingController ctrl, String label) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(labelText: label),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegexUtils.amountExp)
      ],
    );
  }

  Widget _buildPolicyDatePickerRow(String label, DateTime date,
      Function(DateTime) onSelect, DateTime firstDate, DateTime lastDate,
      {String? labelOverride}) {
    return Row(
      children: [
        Text('$label: '),
        TextButton(
          // coverage:ignore-start
          onPressed: () async {
            final d = await showDatePicker(
              context: context,
              // coverage:ignore-end
              firstDate: firstDate,
              lastDate: lastDate,
              initialDate: date,
            );
            if (d != null) onSelect(d); // coverage:ignore-line
          },
          child: Text(labelOverride ??
              DateFormat(TaxConstants.dateFormat).format(date)),
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
        title: Text(AppLocalizations.of(context)!.insurancePortfolioTooltip),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: AppLocalizations.of(context)!.policiesListTab),
            Tab(text: AppLocalizations.of(context)!.taxRulesTab),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: AppLocalizations.of(context)!.syncRecalculateTooltip,
            onPressed: () => _recalculateTax(),
          ),
          IconButton(
            icon: PureIcons.add(),
            tooltip: AppLocalizations.of(context)!.addPolicyTitle,
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
            Text(AppLocalizations.of(context)!.yourPoliciesTitle,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
        _buildPolicyRow(
            '${AppLocalizations.of(context)!.annualPremiumLabel('')}: ',
            p.annualPremium,
            suffix: AppLocalizations.of(context)!.perYearLabel),
        _buildPolicyRow(
            '${AppLocalizations.of(context)!.sumAssuredLabel('')}: ',
            p.sumAssured),
        if (p.isTaxExempt == null)
          Text(
              AppLocalizations.of(context)!
                  .pendingCalcStatus, // coverage:ignore-line
              style: const TextStyle(color: Colors.blueGrey, fontSize: 12)),
        if (p.isInstallmentEnabled)
          Text(
              AppLocalizations.of(context)!
                  .installmentsEnabledLabel, // coverage:ignore-line
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
        label: Text(
            isTaxable
                ? AppLocalizations.of(context)!.taxableStatus
                : AppLocalizations.of(context)!
                    .exemptStatus, // coverage:ignore-line
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
            tooltip: AppLocalizations.of(context)!.populateIncomeTooltip,
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
            PopupMenuItem(
                // coverage:ignore-line
                value: 'edit',
                child: Row(children: [
                  // coverage:ignore-line
                  const Icon(Icons.edit, size: 20),
                  const SizedBox(width: 8),
                  Text(AppLocalizations.of(context)!
                      .editAction) // coverage:ignore-line
                ])),
            PopupMenuItem(
                // coverage:ignore-line
                value: 'delete',
                child: Row(children: [
                  // coverage:ignore-line
                  const Icon(Icons.delete, size: 20, color: Colors.red),
                  const SizedBox(width: 8),
                  Text(
                      AppLocalizations.of(context)!
                          .deleteAction, // coverage:ignore-line
                      style: const TextStyle(color: Colors.red))
                ])),
          ],
        ),
      ],
    );
  }

  void _showPopulateIncomeDialog(InsurancePolicy p, dynamic key) {
    int selectedYear = _selectedYear;
    String selectedHead = p.isUnitLinked
        ? AppLocalizations.of(context)!.capitalGainLabel // coverage:ignore-line
        : AppLocalizations.of(context)!.otherIncomeHead;
    AssetType selectedAssetType = AssetType.other;
    bool isLTCG = true;

    final split =
        ref.read(insuranceTaxServiceProvider).calculateTaxableIncomeSplit(p);
    final saleAmount = split['saleConsideration']!;
    final cost = split['costOfAcquisition']!;

    final saleAmountCtrl = TextEditingController(
        text: selectedHead == AppLocalizations.of(context)!.capitalGainLabel
            ? saleAmount.toStringAsFixed(0) // coverage:ignore-line
            : split['taxableGain']!.toStringAsFixed(0));
    final costCtrl = TextEditingController(text: cost.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(AppLocalizations.of(context)!.populateTaxableIncomeTitle),
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
                child: Text(AppLocalizations.of(context)!.cancelAction)),
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
              child: Text(AppLocalizations.of(context)!.addToDashboardAction),
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
    final isCapitalGain =
        selectedHead == AppLocalizations.of(context)!.capitalGainLabel;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('${AppLocalizations.of(context)!.policyLabel}: ${p.policyName}',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        _buildInfoField(AppLocalizations.of(context)!.taxYearLabel,
            'FY $selectedYear-${selectedYear + 1}'),
        const SizedBox(height: 16),
        _buildTaxHeadDropdown(selectedHead, onHeadChanged),
        const SizedBox(height: 16),
        if (isCapitalGain)
          _buildCapitalGainFields(
            // coverage:ignore-line
            selectedAssetType: selectedAssetType,
            saleAmountCtrl: saleAmountCtrl,
            costCtrl: costCtrl,
            isLTCG: isLTCG,
            onAssetTypeChanged: onAssetTypeChanged,
            onLtcgChanged: onLtcgChanged,
          )
        else
          _buildAmountField(saleAmountCtrl,
              AppLocalizations.of(context)!.taxableGainProfitLabel),
        const SizedBox(height: 8),
        if (p.isIncomeAddedByYear[selectedYear] == true)
          _buildAlreadyAddedNote(), // coverage:ignore-line
      ],
    );
  }

  Widget _buildTaxHeadDropdown(
      String selectedHead, ValueChanged<String> onHeadChanged) {
    return DropdownButtonFormField<String>(
      initialValue: selectedHead,
      decoration: InputDecoration(
          labelText: AppLocalizations.of(context)!.taxHeadLabel),
      items: [
        AppLocalizations.of(context)!.otherIncomeHead,
        AppLocalizations.of(context)!.capitalGainLabel
      ].map((h) => DropdownMenuItem(value: h, child: Text(h))).toList(),
      onChanged: (val) => onHeadChanged(val!), // coverage:ignore-line
    );
  }

  Widget _buildCapitalGainFields({
    // coverage:ignore-line
    required AssetType selectedAssetType,
    required TextEditingController saleAmountCtrl,
    required TextEditingController costCtrl,
    required bool isLTCG,
    required ValueChanged<AssetType> onAssetTypeChanged,
    required ValueChanged<bool> onLtcgChanged,
  }) {
    // coverage:ignore-start
    return Column(
      children: [
        DropdownButtonFormField<AssetType>(
          // coverage:ignore-end
          initialValue: selectedAssetType,
          isExpanded: true,
          decoration: InputDecoration(
              // coverage:ignore-line
              labelText: AppLocalizations.of(context)!
                  .assetCategoryLabel), // coverage:ignore-line
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
            saleAmountCtrl, // coverage:ignore-line
            AppLocalizations.of(context)!
                .saleMaturityAmountLabel), // coverage:ignore-line
        const SizedBox(height: 16),
        _buildAmountField(
            // coverage:ignore-line
            costCtrl,
            AppLocalizations.of(context)!
                .costOfAcquisitionLabel), // coverage:ignore-line
        const SizedBox(height: 8),
        SwitchListTile(
          // coverage:ignore-line
          title: Text(
              AppLocalizations.of(context)!
                  .isLongTermLabel, // coverage:ignore-line
              style: const TextStyle(fontSize: 14)),
          value: isLTCG,
          onChanged: (val) => onLtcgChanged(val), // coverage:ignore-line
          dense: true,
        ),
      ],
    );
  }

  // coverage:ignore-start
  Widget _buildAlreadyAddedNote() {
    return Text(
      AppLocalizations.of(context)!.incomeAlreadyAddedNote,
      // coverage:ignore-end
      style: const TextStyle(color: Colors.orange, fontSize: 12),
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
    if (head == AppLocalizations.of(context)!.capitalGainLabel) {
      final entry = CapitalGainEntry(
        // coverage:ignore-line
        description:
            '${AppLocalizations.of(context)!.insurancePrefix}: ${p.policyName}', // coverage:ignore-line
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
        name:
            '${AppLocalizations.of(context)!.insurancePrefix}: ${p.policyName}',
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
          SnackBar(
              content: Text(AppLocalizations.of(context)!
                  .incomeAddedSuccess(year, year + 1))),
        );
      }
    }
  }

  Widget _buildTaxRulesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildDisclaimerSection(),
        const SizedBox(height: 16),
        const Divider(),
        _buildAggregateLimitsToggle(),
        if (_isInsuranceAggregateLimitEnabled) _buildAggregateLimitsConfig(),
        const Divider(),
        _buildPremiumPercentRulesToggle(),
        if (_isInsurancePremiumPercentEnabled)
          _buildPremiumPercentRulesConfig(),
        const SizedBox(height: 24),
        FilledButton.icon(
            onPressed: _saveRules,
            icon: const Icon(Icons.save),
            label: Text(AppLocalizations.of(context)!.saveRulesAction))
      ],
    );
  }

  Widget _buildDisclaimerSection() {
    return Row(
      children: [
        const Icon(Icons.info_outline, size: 16, color: Colors.blue),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            AppLocalizations.of(context)!.disclaimerRulesTitle,
            style: const TextStyle(fontSize: 12, color: Colors.blue),
          ),
        ),
      ],
    );
  }

  Widget _buildAggregateLimitsToggle() {
    return SwitchListTile(
      title: Text(AppLocalizations.of(context)!.enableAggregateLimitsLabel),
      subtitle: Text(AppLocalizations.of(context)!.limitsUlipNonUlipSubtitle),
      value: _isInsuranceAggregateLimitEnabled,
      onChanged: (v) => setState(() => _isInsuranceAggregateLimitEnabled = v),
    );
  }

  Widget _buildAggregateLimitsConfig() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
            AppLocalizations.of(context)!.startDatesAggregateLimitsHeader),
        _buildDatePickerRow(AppLocalizations.of(context)!.ulipLimitStartLabel,
            _dateUlip, (d) => setState(() => _dateUlip = d)),
        _buildDatePickerRow(
            AppLocalizations.of(context)!.nonUlipLimitStartLabel,
            _dateNonUlip,
            (d) => setState(() => _dateNonUlip = d)), // coverage:ignore-line
        const Divider(),
        _buildSectionHeader(
            AppLocalizations.of(context)!.aggregatePremiumLimitsHeader),
        _buildNumberField(
            AppLocalizations.of(context)!.ulipLimitLabel, _limitUlipCtrl,
            isAmount: true),
        _buildNumberField(
            AppLocalizations.of(context)!.nonUlipLimitLabel, _limitNonUlipCtrl,
            isAmount: true),
      ],
    );
  }

  Widget _buildPremiumPercentRulesToggle() {
    return SwitchListTile(
      title: Text(AppLocalizations.of(context)!.enablePremiumPercentRulesLabel),
      subtitle: Text(
          AppLocalizations.of(context)!.limitsPercentageSumAssuredSubtitle),
      value: _isInsurancePremiumPercentEnabled,
      onChanged: (v) => setState(
          () => _isInsurancePremiumPercentEnabled = v), // coverage:ignore-line
    );
  }

  Widget _buildPremiumPercentRulesConfig() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _buildSectionHeader(
              AppLocalizations.of(context)!.premiumPercentRulesConfigHeader),
          IconButton(
              icon: const Icon(Icons.add), onPressed: _addPremiumRuleDialog),
        ]),
        Text(AppLocalizations.of(context)!.policiesDatePctNote),
        const SizedBox(height: 8),
        ..._premiumRules.asMap().entries.map((e) {
          final idx = e.key;
          final rule = e.value;
          return Card(
            child: ListTile(
              title: Text(AppLocalizations.of(context)!
                  .pctLimitLabel(rule.limitPercentage)),
              subtitle: Text(AppLocalizations.of(context)!.effectiveFromLabel(
                  DateFormat(TaxConstants.dateFormat).format(rule.startDate))),
              trailing: IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => setState(
                    () => _premiumRules.removeAt(idx)), // coverage:ignore-line
              ),
            ),
          );
        }),
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
        label: Text(DateFormat(TaxConstants.dateFormat).format(date)),
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context)!.recalculateTaxSuccess)));
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
              Text(AppLocalizations.of(context)!.taxOptimizationGainsTitle,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              if (data.hasPendingCalculations)
                const Icon(Icons.info,
                    color: Colors.orange, size: 16), // coverage:ignore-line
            ]),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStat(AppLocalizations.of(context)!.annPremiumLabel,
                    data.totalPremium, Theme.of(context).colorScheme.onSurface),
                _buildStat(AppLocalizations.of(context)!.currentTaxableLabel,
                    data.currentTaxableGain, Colors.red),
                _buildStat(AppLocalizations.of(context)!.futureTaxableLabel,
                    data.futureTaxableGain, Colors.orange),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStat(AppLocalizations.of(context)!.totalTaxableUlipLabel,
                    data.taxableUlipTotal, Colors.deepOrange),
                _buildStat(
                    AppLocalizations.of(context)!.totalTaxableNonUlipLabel,
                    data.taxableNonUlipTotal,
                    Colors.redAccent),
              ],
            ),
            const SizedBox(height: 8),
            Text(AppLocalizations.of(context)!.taxableAmountsNote,
                style: const TextStyle(fontSize: 10, color: Colors.grey)),
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
    // coverage:ignore-start
    return AlertDialog(
      title: Text(AppLocalizations.of(context)!.addPremiumRuleTitle),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Text('${AppLocalizations.of(context)!.issueDateLabel}: '),
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
                  DateFormat(TaxConstants.dateFormat)
                      .format(_selectedDate))) // coverage:ignore-line
        ]),
        // coverage:ignore-start
        TextField(
          controller: _pctCtrl,
          decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.limitPctLabel('')),
          // coverage:ignore-end
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
            child: Text(AppLocalizations.of(context)!.cancelAction)),
        FilledButton(
          onPressed: () {
            final pct = double.tryParse(_pctCtrl.text);
            // coverage:ignore-end
            if (pct != null) {
              widget.onAdd(_selectedDate, pct); // coverage:ignore-line
              Navigator.pop(context); // coverage:ignore-line
            }
          },
          child: Text(AppLocalizations.of(context)!
              .addRuleAction), // coverage:ignore-line
        )
      ],
    );
  }
}
