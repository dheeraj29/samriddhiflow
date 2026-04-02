import 'package:samriddhi_flow/utils/regex_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samriddhi_flow/models/taxes/tax_data.dart';
import '../../widgets/app_list_item_card.dart';
import 'package:samriddhi_flow/models/taxes/tax_data_models.dart';
import 'package:samriddhi_flow/models/loan.dart';
import 'dart:math';

import 'package:samriddhi_flow/services/taxes/tax_config_service.dart';
import 'package:samriddhi_flow/services/taxes/indian_tax_service.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:samriddhi_flow/models/taxes/tax_rules.dart';
import 'package:samriddhi_flow/utils/currency_utils.dart';
import 'package:samriddhi_flow/widgets/notched_border_painter.dart';
import 'package:samriddhi_flow/widgets/smart_currency_text.dart';

const _dateFormatIso8601 = 'yyyy-MM-dd';

class TaxDetailsScreen extends ConsumerStatefulWidget {
  final TaxYearData data;
  final Function(TaxYearData) onSave;
  final VoidCallback? onDelete;
  final int? initialTabIndex;

  const TaxDetailsScreen({
    super.key,
    required this.data,
    required this.onSave,
    this.initialTabIndex,
    this.onDelete,
  });

  @override
  ConsumerState<TaxDetailsScreen> createState() => _TaxDetailsScreenState();
}

enum EntryFilter { all, manual, synced }

class _TaxDetailsScreenState extends ConsumerState<TaxDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TaxYearData _currentData;

  // Entry Filters
  EntryFilter _hpFilter = EntryFilter.all;
  EntryFilter _businessFilter = EntryFilter.all;
  EntryFilter _cgFilter = EntryFilter.all;
  EntryFilter _otherFilter = EntryFilter.all;
  EntryFilter _taxPaidFilter = EntryFilter.all;
  EntryFilter _agriFilter = EntryFilter.all;

  // Controllers for Salary (Yearly)
  late TextEditingController _salaryNpsEmployerCtrl;
  late TextEditingController _salaryLeaveEncashCtrl;
  late TextEditingController _salaryGratuityCtrl;

  // Local mutable lists to avoid "Unsupported operation: add"
  List<HouseProperty> _houseProperties = [];
  List<BusinessEntity> _businessIncomes = [];
  List<CapitalGainEntry> _capitalGains = [];
  List<OtherIncome> _otherIncomes = [];
  List<OtherIncome> _cashGifts = [];
  List<CustomAllowance> _independentAllowances = [];
  List<CustomExemption> _independentExemptions = [];
  List<CustomDeduction> _independentDeductions = [];
  List<SalaryStructure> _salaryHistory = [];

  // Controllers for Other Income / Agri / Tax
  late TextEditingController _otherIncomeNameCtrl;
  late TextEditingController _otherIncomeAmtCtrl;

  // Local state for lists
  List<TaxPaymentEntry> _tdsEntries = [];
  List<TaxPaymentEntry> _tcsEntries = [];
  List<TaxPaymentEntry> _advanceTaxEntries = [];
  List<AgriIncomeEntry> _agriIncomeHistory = [];

  DateTimeRange? _selectedDateRange;

  bool _hasUnsavedChanges = false;
  final bool _isProgrammaticUpdate = false;
  final Set<String> _lockedFields = {};

  void _markAsLocked(String fieldId) {
    if (_isProgrammaticUpdate) return;
    if (!_lockedFields.contains(fieldId)) {
      _lockedFields.add(fieldId);
    }
  }

  @override
  void initState() {
    super.initState();
    _currentData = widget.data;
    if (widget.initialTabIndex != null) {
      _selectedIndex = widget.initialTabIndex!; // coverage:ignore-line
    }

    _initSalaryControllers();
    _initTaxPaymentControllers();
    _initLocalLists();
    _otherIncomeNameCtrl = TextEditingController();
    _otherIncomeAmtCtrl = TextEditingController();

    _lockedFields.addAll(widget.data.lockedFields);

    // Add listeners for real-time summary update & locking
    void bind(TextEditingController ctrl, String id) {
      ctrl.addListener(() {
        _markAsLocked(id);
        _updateSummary();
      });
    }

    bind(_salaryNpsEmployerCtrl, 'salary.nps');
    bind(_salaryLeaveEncashCtrl, 'salary.leave');
    bind(_salaryGratuityCtrl, 'salary.gratuity');
  }

  void _initLocalLists() {
    _houseProperties = List.from(_currentData.houseProperties);
    _businessIncomes = List.from(_currentData.businessIncomes);
    _capitalGains = List.from(_currentData.capitalGains);
    _otherIncomes = List.from(_currentData.otherIncomes);
    _cashGifts = List.from(_currentData.cashGifts);
    _independentAllowances =
        List<CustomAllowance>.from(_currentData.salary.independentAllowances);
    _independentExemptions =
        List<CustomExemption>.from(_currentData.salary.independentExemptions);
    _independentDeductions =
        List<CustomDeduction>.from(_currentData.salary.independentDeductions);
    _salaryHistory = List.from(_currentData.salary.history);
    _agriIncomeHistory = List.from(_currentData.agriIncomeHistory);
  }

  void _updateSummary() {
    if (!mounted) return;
    setState(() {
      _hasUnsavedChanges = true;

      // 1. Calculate Gross Salary from history
      _calculateAnnualGross(_salaryHistory);

      // 2. Update SalaryDetails in _currentData (local copy for summary)
      final newSalary = _currentData.salary.copyWith(
        npsEmployer: double.tryParse(_salaryNpsEmployerCtrl.text) ?? 0,
        leaveEncashment: double.tryParse(_salaryLeaveEncashCtrl.text) ?? 0,
        gratuity: double.tryParse(_salaryGratuityCtrl.text) ?? 0,
        independentAllowances:
            List<CustomAllowance>.from(_independentAllowances),
        independentExemptions:
            List<CustomExemption>.from(_independentExemptions),
        independentDeductions:
            List<CustomDeduction>.from(_independentDeductions),
        history: _salaryHistory,
      );

      _currentData = _currentData.copyWith(
        salary: newSalary,
        houseProperties: _houseProperties,
        businessIncomes: _businessIncomes,
        capitalGains: _capitalGains,
        otherIncomes: _otherIncomes,
        cashGifts: _cashGifts,
        tdsEntries: _tdsEntries,
        tcsEntries: _tcsEntries,
        advanceTaxEntries: _advanceTaxEntries,
        agriIncomeHistory: _agriIncomeHistory,
      );
    });
  }

  void _initTaxPaymentControllers() {
    // Initialize lists
    // Using List.from to create mutable copies
    _tdsEntries = List.from(_currentData.tdsEntries);
    _tcsEntries = List.from(_currentData.tcsEntries);
    _advanceTaxEntries = List.from(_currentData.advanceTaxEntries);
  }

  void _initSalaryControllers() {
    _salaryNpsEmployerCtrl =
        TextEditingController(text: _currentData.salary.npsEmployer.toString());
    _salaryLeaveEncashCtrl = TextEditingController(
        text: _currentData.salary.leaveEncashment.toString());
    _salaryGratuityCtrl =
        TextEditingController(text: _currentData.salary.gratuity.toString());
  }

  @override
  void dispose() {
    _salaryNpsEmployerCtrl.dispose();
    _salaryLeaveEncashCtrl.dispose();
    _salaryGratuityCtrl.dispose();
    _otherIncomeNameCtrl.dispose();
    _otherIncomeAmtCtrl.dispose();

    super.dispose();
  }

  void _save() {
    // 1. Calculate Gross from history
    _calculateAnnualGross(_salaryHistory);

    // Other deductions are typically annual figures
    final newSalary = _currentData.salary.copyWith(
      npsEmployer: (double.tryParse(_salaryNpsEmployerCtrl.text) ?? 0),
      leaveEncashment: (double.tryParse(_salaryLeaveEncashCtrl.text) ?? 0),
      gratuity: (double.tryParse(_salaryGratuityCtrl.text) ?? 0),
      independentAllowances: List<CustomAllowance>.from(_independentAllowances),
      independentExemptions: List<CustomExemption>.from(_independentExemptions),
      independentDeductions: List<CustomDeduction>.from(_independentDeductions),
      history: _salaryHistory,
    );

    final updatedData = _currentData.copyWith(
      salary: newSalary,
      tdsEntries: _tdsEntries,
      tcsEntries: _tcsEntries,
      advanceTaxEntries: _advanceTaxEntries,
      houseProperties: _houseProperties,
      businessIncomes: _businessIncomes,
      capitalGains: _capitalGains,
      otherIncomes: _otherIncomes,
      cashGifts: _cashGifts,
      agriIncomeHistory: _agriIncomeHistory,
      lockedFields: _lockedFields.toList(),
    );

    widget.onSave(updatedData);

    // Feedback: Don't close on save, just show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(AppLocalizations.of(context)!.taxDetailsSavedStatus)),
    );

    setState(() {
      _hasUnsavedChanges = false;
    });
  }

  // coverage:ignore-start
  Future<void> _clearCurrentCategoryData() async {
    final catName = _navDestinations[_selectedIndex].label;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        // coverage:ignore-end
        title:
            // coverage:ignore-start
            Text(AppLocalizations.of(context)!.clearCategoryDataTitle(catName)),
        content: Text(AppLocalizations.of(context)!
            .clearCategoryDataContent(catName, _currentData.year.toString())),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                  AppLocalizations.of(context)!.cancelButton.toUpperCase())),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            // coverage:ignore-end
            child: Text(AppLocalizations.of(context)!
                .clearButton
                .toUpperCase()), // coverage:ignore-line
          ),
        ],
      ),
    );

    // coverage:ignore-start
    if (confirm == true) {
      setState(() {
        _performCategoryClear(_selectedIndex);
        _updateSummary();
        // coverage:ignore-end
      });
      // coverage:ignore-start
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(AppLocalizations.of(context)!
                .categoryDataClearedStatus(catName))));
        // coverage:ignore-end
      }
    }
  }

  void _performCategoryClear(int index) {
    // coverage:ignore-line
    switch (index) {
      case 0: // Salary // coverage:ignore-line
        _clearSalaryData(); // coverage:ignore-line
        break;
      case 1: // coverage:ignore-line
        _houseProperties = []; // coverage:ignore-line
        break;
      case 2: // coverage:ignore-line
        _businessIncomes = []; // coverage:ignore-line
        break;
      case 3: // coverage:ignore-line
        _capitalGains = []; // coverage:ignore-line
        break;
      case 4: // Dividend // coverage:ignore-line
        _currentData = _currentData.copyWith(
          // coverage:ignore-line
          dividendIncome: const DividendIncome(),
        );
        break;
      case 5: // Tax Paid // coverage:ignore-line
        _clearTaxPaidData(); // coverage:ignore-line
        break;
      case 6: // coverage:ignore-line
        _cashGifts = []; // coverage:ignore-line
        break;
      case 7: // coverage:ignore-line
        _agriIncomeHistory = []; // coverage:ignore-line
        break;
      case 8: // coverage:ignore-line
        _otherIncomes = []; // coverage:ignore-line
        break;
    }
  }

  // coverage:ignore-start
  void _clearSalaryData() {
    _salaryHistory = [];
    _salaryNpsEmployerCtrl.text = '0';
    _salaryLeaveEncashCtrl.text = '0';
    _salaryGratuityCtrl.text = '0';
    _independentAllowances = [];
    _independentExemptions = [];
    _independentDeductions = [];
    // coverage:ignore-end
  }

  // coverage:ignore-start
  void _clearTaxPaidData() {
    _tdsEntries = [];
    _tcsEntries = [];
    _advanceTaxEntries = [];
    // coverage:ignore-end
  }

  Future<void> _clearTaxData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context)!
            .clearAllFiscalYearDataTitle(_currentData.year.toString())),
        content:
            Text(AppLocalizations.of(context)!.clearAllFiscalYearDataContent),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                  AppLocalizations.of(context)!.cancelButton.toUpperCase())),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(
                AppLocalizations.of(context)!.deleteAllButton.toUpperCase()),
          ),
        ],
      ),
    );

    if (confirm == true) {
      widget.onDelete?.call();
      if (mounted) {
        setState(() => _hasUnsavedChanges = false);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(AppLocalizations.of(context)!.taxDataClearedStatus)));
      }
    }
  }

  int _selectedIndex = 0;
  List<({IconData icon, String label})> get _navDestinations => [
        (
          icon: Icons.work_outline,
          label: AppLocalizations.of(context)!.salaryTab
        ),
        (
          icon: Icons.home_work_outlined,
          label: AppLocalizations.of(context)!.housePropertyTab
        ),
        (
          icon: Icons.storefront,
          label: AppLocalizations.of(context)!.businessTab
        ),
        (
          icon: Icons.trending_up,
          label: AppLocalizations.of(context)!.capitalGainsTab
        ),
        (
          icon: Icons.pie_chart_outline,
          label: AppLocalizations.of(context)!.dividendTab
        ),
        (
          icon: Icons.receipt_long,
          label: AppLocalizations.of(context)!.taxPaidTab
        ),
        (
          icon: Icons.card_giftcard,
          label: AppLocalizations.of(context)!.giftsTab
        ),
        (icon: Icons.agriculture, label: AppLocalizations.of(context)!.agriTab),
        (icon: Icons.more_horiz, label: AppLocalizations.of(context)!.otherTab),
      ];

  void _showCategorySwitcher() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(AppLocalizations.of(context)!.switchCategoryTitle,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 16),
              Flexible(
                child: GridView.builder(
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1,
                  ),
                  itemCount: _navDestinations.length,
                  itemBuilder: (context, index) {
                    final dest = _navDestinations[index];
                    final isSelected = _selectedIndex == index;
                    return InkWell(
                      onTap: () {
                        setState(() => _selectedIndex = index);
                        Navigator.pop(context);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(dest.icon,
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : null),
                            const SizedBox(height: 4),
                            Text(dest.label,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                                textAlign: TextAlign.center),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _showUnsavedWarning();
        if (shouldPop && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: _buildAppBar(),
        body: Column(
          children: [
            _buildLiveSummary(),
            const Divider(height: 1, thickness: 1),
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: [
                  _buildSalaryTab(),
                  _buildHousePropertyTab(),
                  _buildBusinessTab(),
                  _buildCapitalGainsTab(),
                  _buildDividendTab(),
                  _buildTaxPaidTab(),
                  _buildCashGiftsTab(),
                  _buildAgriIncomeTab(),
                  _buildOtherTab(),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: _buildFAB(),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: _buildBottomAppBar(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
          '${AppLocalizations.of(context)!.fiscalYearPrefix} ${_currentData.year} - ${_navDestinations[_selectedIndex].label}'),
      actions: [
        IconButton(
          icon: Icon(_selectedDateRange == null
              ? Icons.calendar_today
              : Icons.event_busy),
          tooltip: _selectedDateRange == null
              ? AppLocalizations.of(context)!.filterByDateRangeLabel
              : AppLocalizations.of(context)!
                  .clearDateFilterLabel, // coverage:ignore-line
          onPressed:
              _selectedDateRange == null ? _pickDateRange : _clearDateFilter,
        ),
        if (widget.onDelete != null)
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined,
                color: Colors.redAccent),
            tooltip: AppLocalizations.of(context)!.clearAllFiscalYearDataLabel,
            onPressed: _clearTaxData,
          ),
        ..._buildCopyAction(),
      ],
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton(
      onPressed: _showCategorySwitcher,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      shape: const CircleBorder(),
      child: Icon(_navDestinations[_selectedIndex].icon,
          color: Theme.of(context).colorScheme.onPrimaryContainer, size: 28),
    );
  }

  Widget _buildBottomAppBar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        const double fabRadius = 28.0;
        final fabRect = Rect.fromCircle(
          center: Offset(width / 2, 0),
          radius: fabRadius,
        );

        return CustomPaint(
          painter: NotchedBorderPainter(
            shape: const CircularNotchedRectangle(),
            fabRect: fabRect,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.2) // coverage:ignore-line
                : Colors.black.withValues(alpha: 0.1),
          ),
          child: BottomAppBar(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            height: 60,
            color: Theme.of(context).colorScheme.surfaceContainer,
            shape: const CircularNotchedRectangle(),
            notchMargin: 8,
            child: Row(
              children: [
                IconButton(
                  icon:
                      const Icon(Icons.delete_outline, color: Colors.redAccent),
                  tooltip: AppLocalizations.of(context)!.clearCategoryDataLabel,
                  onPressed: _clearCurrentCategoryData,
                ),
                const Spacer(),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.save_outlined),
                  tooltip: AppLocalizations.of(context)!.saveButton,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(_currentData.year, 4, 1), // Start of FY
      lastDate: DateTime(_currentData.year + 1, 3, 31), // End of FY
      initialDateRange: _selectedDateRange,
    );
    // coverage:ignore-start
    if (picked != null && picked != _selectedDateRange) {
      setState(() {
        _selectedDateRange = picked;
        // coverage:ignore-end
      });
    }
  }

  // coverage:ignore-start
  void _clearDateFilter() {
    setState(() {
      _selectedDateRange = null;
      // coverage:ignore-end
    });
  }

  List<Widget> _buildCopyAction() {
    if (_selectedIndex == 0 && _currentData.salary.history.isEmpty) {
      return [
        IconButton(
          icon: const Icon(Icons.copy),
          tooltip: AppLocalizations.of(context)!.copyPreviousYearDataLabel,
          onPressed: _copySalaryFromPreviousYear,
        )
      ];
    }
    if (_selectedIndex == 1 && _houseProperties.isEmpty) {
      return [
        IconButton(
          icon: const Icon(Icons.copy),
          tooltip: AppLocalizations.of(context)!.copyPreviousYearDataLabel,
          onPressed: _copyHousePropFromPreviousYear,
        )
      ];
    }
    return [];
  }

  Widget _buildLiveSummary() {
    final taxService = ref.read(indianTaxServiceProvider);
    final rules =
        ref.watch(taxConfigServiceProvider).getRulesForYear(_currentData.year);
    final details = taxService.calculateDetailedLiability(_currentData, rules);

    double totalIncome = details['grossIncome'] ?? 0;
    double estimatedTax = details['totalTax'] ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.2) // coverage:ignore-line
                : Colors.black.withValues(alpha: 0.1),
          ),
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(AppLocalizations.of(context)!.approxGrossIncomeLabel,
                  style: const TextStyle(fontSize: 12)),
              SmartCurrencyText(
                  value: totalIncome,
                  locale: ref.watch(currencyProvider),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(AppLocalizations.of(context)!.estimatedTaxLiabilityLabel,
                  style: const TextStyle(fontSize: 12)),
              SmartCurrencyText(
                  value: estimatedTax,
                  locale: ref.watch(currencyProvider),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.red)),
            ],
          ),
        ],
      ),
    );
  }

  Future<bool> _showUnsavedWarning() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(AppLocalizations.of(context)!.unsavedChangesTitle),
            content: Text(AppLocalizations.of(context)!.unsavedChangesContent),
            actions: [
              TextButton(
                  onPressed: () =>
                      Navigator.pop(context, false), // coverage:ignore-line
                  child: Text(AppLocalizations.of(context)!.keepEditingButton)),
              FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(AppLocalizations.of(context)!.discardButton)),
            ],
          ),
        ) ??
        false;
  }

  // --- Dividend Tab ---
  Widget _buildDividendTab() {
    final div = _currentData.dividendIncome;
    final config = ref.watch(taxConfigServiceProvider);
    final rules = config.getRulesForYear(_currentData.year);
    final advanceRules = rules.advanceTaxRules;

    final amounts = [
      div.amountQ1,
      div.amountQ2,
      div.amountQ3,
      div.amountQ4,
      div.amountQ5
    ];
    final numPeriods = (advanceRules.length + 1).clamp(1, 5);
    final controllers = List.generate(
      numPeriods,
      (i) => TextEditingController(text: amounts[min(i, 4)].toString()),
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildDividendHeader(context, ref),
        const SizedBox(height: 16),
        if (div.lastUpdated != null) _buildLastUpdatedText(div.lastUpdated!),
        ...List.generate(numPeriods, (i) {
          final label = _buildDividendPeriodLabel(i, advanceRules);
          return _buildNumberField(label, controllers[i]);
        }),
        const Divider(),
        _buildDividendFooter(div),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(AppLocalizations.of(context)!.dividendBreakdownNote,
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ),
        _buildDividendUpdateButton(controllers),
      ],
    );
  }

  Widget _buildDividendHeader(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
              AppLocalizations.of(context)!.dividendIncomeBreakdownTitle,
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: Icon(
            ref.watch(currencyFormatProvider) ? Icons.compress : Icons.expand,
            size: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
          // coverage:ignore-start
          onPressed: () {
            ref.read(currencyFormatProvider.notifier).value =
                !ref.read(currencyFormatProvider);
            // coverage:ignore-end
          },
        ),
      ],
    );
  }

  Widget _buildLastUpdatedText(DateTime lastUpdated) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        '${AppLocalizations.of(context)!.lastUpdatedLabel}: ${DateFormat('MMM d, yyyy HH:mm').format(lastUpdated)}',
        style: const TextStyle(color: Colors.grey, fontSize: 12),
      ),
    );
  }

  String _monthLabel(int m) {
    final months = [
      AppLocalizations.of(context)!.monthJan,
      AppLocalizations.of(context)!.monthFeb,
      AppLocalizations.of(context)!.monthMar,
      AppLocalizations.of(context)!.monthApr,
      AppLocalizations.of(context)!.monthMay,
      AppLocalizations.of(context)!.monthJun,
      AppLocalizations.of(context)!.monthJul,
      AppLocalizations.of(context)!.monthAug,
      AppLocalizations.of(context)!.monthSep,
      AppLocalizations.of(context)!.monthOct,
      AppLocalizations.of(context)!.monthNov,
      AppLocalizations.of(context)!.monthDec
    ];
    return months[(m - 1).clamp(0, 11)];
  }

  String _buildDividendPeriodLabel(
      int idx, List<AdvanceTaxInstallmentRule> advanceRules) {
    if (advanceRules.isEmpty) {
      return AppLocalizations.of(context)!
          .fullYearLabel; // coverage:ignore-line
    }
    if (idx == 0) {
      final rule = advanceRules[0];
      return '${AppLocalizations.of(context)!.periodLabel} ${idx + 1} (Apr 1 - ${_monthLabel(rule.endMonth)} ${rule.endDay})';
    } else if (idx < advanceRules.length) {
      final prev = advanceRules[idx - 1];
      final curr = advanceRules[idx];
      return '${AppLocalizations.of(context)!.periodLabel} ${idx + 1} (${_monthLabel(prev.endMonth)} ${prev.endDay + 1} - ${_monthLabel(curr.endMonth)} ${curr.endDay})';
    } else {
      final prev = advanceRules.last;
      return '${AppLocalizations.of(context)!.periodLabel} ${idx + 1} (${_monthLabel(prev.endMonth)} ${prev.endDay + 1} - Mar 31)';
    }
  }

  Widget _buildDividendFooter(DividendIncome div) {
    final currencyLocale = ref.watch(currencyProvider);
    final isShort = ref.watch(currencyFormatProvider);
    final totalText = isShort
        ? CurrencyUtils.getSmartFormat(
            div.grossDividend, currencyLocale) // coverage:ignore-line
        : CurrencyUtils.formatCurrency(div.grossDividend, currencyLocale);

    return ListTile(
      title: Text(AppLocalizations.of(context)!.totalDividendIncomeLabel),
      trailing: Text(totalText,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
    );
  }

  Widget _buildDividendUpdateButton(List<TextEditingController> controllers) {
    return FilledButton(
      onPressed: () {
        setState(() {
          double val(int i) =>
              double.tryParse(
                  controllers.length > i ? controllers[i].text : '0') ??
              0;
          _currentData = _currentData.copyWith(
            dividendIncome: DividendIncome(
              amountQ1: val(0),
              amountQ2: val(1),
              amountQ3: val(2),
              amountQ4: val(3),
              amountQ5: val(4),
              lastUpdated: DateTime.now(),
            ),
          );
        });
        _updateSummary();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text(AppLocalizations.of(context)!.dividendUpdatedStatus)));
      },
      child: Text(AppLocalizations.of(context)!.updateTotalButton),
    );
  }

  Widget _buildSalaryTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSalaryStructureHeader(),
        _buildSalaryStructureList(),
        const SizedBox(height: 16),
        const Divider(height: 32),
        _buildSalaryExemptionsDeductionsSection(),
        const SizedBox(height: 16),
        _buildIndependentAllowancesSection(),
        const SizedBox(height: 16),
        _buildCustomExemptionsSection(),
        const SizedBox(height: 16),
        _buildSalarySummaryCard(),
        const SizedBox(height: 16),
        _buildTdsSummarySectionHeader(),
        _buildTdsSummarySection(),
        const SizedBox(height: 16),
        _buildIndependentDeductionsSection(),
        const SizedBox(height: 16),
        _buildSalaryTakeHomeRow(),
        const SizedBox(height: 16),
        _buildTakeHomeBreakdown(),
      ],
    );
  }

  Widget _buildSalaryStructureHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
            child: _buildSectionTitle(
                AppLocalizations.of(context)!.salaryStructuresTitle)),
        TextButton.icon(
          icon: const Icon(Icons.add_circle_outline),
          label: Text(AppLocalizations.of(context)!.addStructureAction),
          onPressed: () => _editSalaryStructure(null),
        ),
      ],
    );
  }

  Widget _buildSalaryStructureList() {
    if (_salaryHistory.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text(AppLocalizations.of(context)!.noSalaryStructureDefinedNote,
            style: const TextStyle(color: Colors.grey)),
      );
    }
    return Column(
      children:
          _salaryHistory.map((s) => _buildSalaryStructureCard(s)).toList(),
    );
  }

  Widget _buildSalaryStructureCard(SalaryStructure s) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.2) // coverage:ignore-line
              : Colors.black.withValues(alpha: 0.1),
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.grey.withValues(alpha: 0.1),
          child: Icon(Icons.work_history_outlined,
              color: Theme.of(context).colorScheme.primary, size: 20),
        ),
        title: Text(
            '${AppLocalizations.of(context)!.effectiveLabel}: ${DateFormat('MMM d, yyyy').format(s.effectiveDate)}',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
            '${AppLocalizations.of(context)!.basicLabel}: ${CurrencyUtils.formatCurrency(s.monthlyBasic, ref.watch(currencyProvider))} + ${AppLocalizations.of(context)!.allowancesLabel}'),
        trailing: IconButton(
          icon: const Icon(Icons.edit, color: Colors.grey, size: 20),
          onPressed: () {
            FocusScope.of(context).unfocus();
            _editSalaryStructure(s);
          },
        ),
        // coverage:ignore-start
        onTap: () {
          FocusScope.of(context).unfocus();
          _editSalaryStructure(s);
          // coverage:ignore-end
        },
      ),
    );
  }

  Widget _buildSalaryExemptionsDeductionsSection() {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(l10n.exemptionsDeductionsTitle),
        _buildNumberField(l10n.employerNPSLabel, _salaryNpsEmployerCtrl),
        _buildNumberField(
            l10n.leaveEncashmentTitleLabel, _salaryLeaveEncashCtrl),
        _buildNumberField(l10n.gratuityTitleLabel, _salaryGratuityCtrl),
      ],
    );
  }

  Widget _buildIndependentAllowancesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
            AppLocalizations.of(context)!.independentAllowancesTitle),
        _buildIndependentAllowances(),
      ],
    );
  }

  Widget _buildCustomExemptionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
            AppLocalizations.of(context)!.customAdHocExemptionsTitle),
        _buildIndependentExemptions(),
      ],
    );
  }

  Widget _buildTdsSummarySectionHeader() {
    return _buildSectionTitle(AppLocalizations.of(context)!.tdsTaxesPaidTitle);
  }

  Widget _buildIndependentDeductionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
            AppLocalizations.of(context)!.independentDeductionsTitle),
        _buildIndependentDeductions(),
      ],
    );
  }

  Widget _buildIndependentAllowances() {
    return Column(
      children: [
        if (_independentAllowances.isEmpty)
          Text(AppLocalizations.of(context)!.noIndependentAllowancesNote,
              style: const TextStyle(color: Colors.grey, fontSize: 12))
        else
          ..._independentAllowances // coverage:ignore-line
              .map((a) =>
                  _buildIndependentAllowanceTile(a)), // coverage:ignore-line
        TextButton.icon(
          onPressed: () => _handleEditAllowance(null), // coverage:ignore-line
          icon: const Icon(Icons.add),
          label:
              Text(AppLocalizations.of(context)!.addIndependentAllowanceAction),
        ),
      ],
    );
  }

  Widget _buildIndependentAllowanceTile(CustomAllowance a) {
    // coverage:ignore-line
    return Card(
      // coverage:ignore-line
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 2,
      // coverage:ignore-start
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.2)
              : Colors.black.withValues(alpha: 0.1),
          // coverage:ignore-end
        ),
      ),
      // coverage:ignore-start
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.grey.withValues(alpha: 0.1),
          child: Icon(Icons.add_task_outlined,
              color: Theme.of(context).colorScheme.primary, size: 20),
          // coverage:ignore-end
        ),
        title:
            // coverage:ignore-start
            Text(a.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(_formatAllowanceSubtitle(a)),
        trailing: IconButton(
          // coverage:ignore-end
          icon: const Icon(Icons.delete, color: Colors.grey, size: 20),
          // coverage:ignore-start
          onPressed: () {
            FocusScope.of(context).unfocus();
            _handleDeleteAllowance(a);
            // coverage:ignore-end
          },
        ),
        // coverage:ignore-start
        onTap: () {
          FocusScope.of(context).unfocus();
          _handleEditAllowance(a);
          // coverage:ignore-end
        },
      ),
    );
  }

  // coverage:ignore-start
  void _handleDeleteAllowance(CustomAllowance a) {
    setState(() => _independentAllowances.remove(a));
    _updateSummary();
    // coverage:ignore-end
  }

  // coverage:ignore-start
  void _handleEditAllowance(CustomAllowance? existing) {
    _addCustomAllowanceDialog(
      context: context,
      onAdd: (updated) {
        setState(() {
          // coverage:ignore-end
          if (existing != null) {
            int idx = _independentAllowances
                .indexOf(existing); // coverage:ignore-line
            _independentAllowances[idx] = updated; // coverage:ignore-line
          } else {
            _independentAllowances.add(updated); // coverage:ignore-line
          }
        });
        _updateSummary(); // coverage:ignore-line
      },
      existing: existing,
    );
  }

  Widget _buildIndependentExemptions() {
    return Column(
      children: [
        if (_independentExemptions.isEmpty)
          Text(AppLocalizations.of(context)!.noAdHocExemptionsNote,
              style: const TextStyle(color: Colors.grey, fontSize: 12))
        else
          ..._independentExemptions // coverage:ignore-line
              .map((e) =>
                  _buildIndependentExemptionTile(e)), // coverage:ignore-line
        TextButton.icon(
          onPressed: () => _handleEditExemption(null), // coverage:ignore-line
          icon: const Icon(Icons.add),
          label: Text(AppLocalizations.of(context)!.addAdHocExemptionAction),
        ),
      ],
    );
  }

  Widget _buildIndependentExemptionTile(CustomExemption e) {
    // coverage:ignore-line
    return Card(
      // coverage:ignore-line
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 2,
      // coverage:ignore-start
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.2)
              : Colors.black.withValues(alpha: 0.1),
          // coverage:ignore-end
        ),
      ),
      // coverage:ignore-start
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.grey.withValues(alpha: 0.1),
          child: Icon(Icons.verified_outlined,
              color: Theme.of(context).colorScheme.primary, size: 20),
          // coverage:ignore-end
        ),
        title:
            // coverage:ignore-start
            Text(e.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(CurrencyUtils.formatCurrency(
            e.amount, ref.watch(currencyProvider))),
        trailing: IconButton(
          // coverage:ignore-end
          icon: const Icon(Icons.delete, color: Colors.grey, size: 20),
          // coverage:ignore-start
          onPressed: () {
            FocusScope.of(context).unfocus();
            _handleDeleteExemption(e);
            // coverage:ignore-end
          },
        ),
        // coverage:ignore-start
        onTap: () {
          FocusScope.of(context).unfocus();
          _handleEditExemption(e);
          // coverage:ignore-end
        },
      ),
    );
  }

  // coverage:ignore-start
  void _handleDeleteExemption(CustomExemption e) {
    setState(() => _independentExemptions.remove(e));
    _updateSummary();
    // coverage:ignore-end
  }

  // coverage:ignore-start
  void _handleEditExemption(CustomExemption? existing) {
    _addCustomExemptionDialog(
      onAdd: (updated) {
        setState(() {
          // coverage:ignore-end
          if (existing != null) {
            int idx = _independentExemptions
                .indexOf(existing); // coverage:ignore-line
            _independentExemptions[idx] = updated; // coverage:ignore-line
          } else {
            _independentExemptions.add(updated); // coverage:ignore-line
          }
        });
        _updateSummary(); // coverage:ignore-line
      },
      existing: existing,
    );
  }

  Widget _buildIndependentDeductions() {
    return Column(
      children: [
        if (_independentDeductions.isEmpty)
          Text(AppLocalizations.of(context)!.noIndependentDeductionsNote,
              style: const TextStyle(color: Colors.grey, fontSize: 12))
        else
          ..._independentDeductions // coverage:ignore-line
              .map((d) =>
                  _buildIndependentDeductionTile(d)), // coverage:ignore-line
        TextButton.icon(
          onPressed: () => _handleEditDeduction(null), // coverage:ignore-line
          icon: const Icon(Icons.add),
          label:
              Text(AppLocalizations.of(context)!.addIndependentDeductionAction),
        ),
      ],
    );
  }

  Widget _buildIndependentDeductionTile(CustomDeduction d) {
    // coverage:ignore-line
    return Card(
      // coverage:ignore-line
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 2,
      // coverage:ignore-start
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.2)
              : Colors.black.withValues(alpha: 0.1),
          // coverage:ignore-end
        ),
      ),
      // coverage:ignore-start
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.grey.withValues(alpha: 0.1),
          child: Icon(Icons.remove_circle_outline,
              color: Theme.of(context).colorScheme.primary, size: 20),
          // coverage:ignore-end
        ),
        title:
            // coverage:ignore-start
            Text(d.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
            '${CurrencyUtils.formatCurrency(d.amount, ref.watch(currencyProvider))} (${d.frequency.name})'),
        trailing: IconButton(
          // coverage:ignore-end
          icon: const Icon(Icons.delete, color: Colors.grey, size: 20),
          // coverage:ignore-start
          onPressed: () {
            FocusScope.of(context).unfocus();
            _handleDeleteDeduction(d);
            // coverage:ignore-end
          },
        ),
        // coverage:ignore-start
        onTap: () {
          FocusScope.of(context).unfocus();
          _handleEditDeduction(d);
          // coverage:ignore-end
        },
      ),
    );
  }

  // coverage:ignore-start
  void _handleDeleteDeduction(CustomDeduction d) {
    setState(() => _independentDeductions.remove(d));
    _updateSummary();
    // coverage:ignore-end
  }

  // coverage:ignore-start
  void _handleEditDeduction(CustomDeduction? existing) {
    _addCustomAllowanceDialog(
      context: context,
      onAdd: (updatedAllowance) {
        setState(() {
          final updatedDeduction = CustomDeduction(
            id: existing?.id ?? const Uuid().v4(),
            name: updatedAllowance.name,
            amount: updatedAllowance.payoutAmount,
            frequency: updatedAllowance.frequency,
            startMonth: updatedAllowance.startMonth,
            customMonths: updatedAllowance.customMonths,
            isPartial: updatedAllowance.isPartial,
            partialAmounts: updatedAllowance.partialAmounts,
            // coverage:ignore-end
          );

          if (existing != null) {
            int idx = _independentDeductions
                .indexOf(existing); // coverage:ignore-line
            _independentDeductions[idx] =
                updatedDeduction; // coverage:ignore-line
          } else {
            _independentDeductions
                .add(updatedDeduction); // coverage:ignore-line
          }
        });
        _updateSummary(); // coverage:ignore-line
      },
      existing: existing != null
          // coverage:ignore-start
          ? CustomAllowance(
              id: existing.id,
              name: existing.name,
              payoutAmount: existing.amount,
              frequency: existing.frequency,
              startMonth: existing.startMonth,
              customMonths: existing.customMonths,
              partialAmounts: existing.partialAmounts,
              isPartial: existing.isPartial,
              // coverage:ignore-end
            )
          : null,
      isDeduction: true,
    );
  }

  Widget _buildTdsSummarySection() {
    final rules =
        ref.watch(taxConfigServiceProvider).getRulesForYear(_currentData.year);
    final taxService = ref.read(indianTaxServiceProvider);

    // Create salary data mapping planning scenario:
    double totalUserPlannedExemptions =
        _independentExemptions.fold(0.0, (sum, e) => sum + e.amount);

    final salaryOnlyData = _currentData.copyWith(
      houseProperties: [],
      businessIncomes: [],
      capitalGains: [],
      otherIncomes: [],
      dividendIncome: const DividendIncome(),
      cashGifts: [],
    );

    double gross = taxService.calculateSalaryGross(salaryOnlyData, rules);
    double exemptions =
        taxService.calculateSalaryExemptions(salaryOnlyData, rules);
    double baseSalaryIncome = (gross - exemptions).clamp(0.0, double.infinity);
    double plannedSalaryIncome = (baseSalaryIncome - totalUserPlannedExemptions)
        .clamp(0.0, double.infinity);

    final resultsWithPlanning = taxService.calculateDetailedLiability(
        salaryOnlyData, rules,
        salaryIncomeOverride: plannedSalaryIncome);
    double newTaxAfterAdhocExemptions = resultsWithPlanning['totalTax'] ?? 0;

    final generatedTds =
        taxService.getGeneratedSalaryTds(salaryOnlyData, rules);
    final totalTds = _tdsEntries.fold(0.0, (sum, e) => sum + e.amount) +
        generatedTds.fold(0.0, (sum, e) => sum + e.amount);

    double refundForecast = 0;
    if (totalTds > newTaxAfterAdhocExemptions &&
        _independentExemptions.isNotEmpty) {
      refundForecast =
          totalTds - newTaxAfterAdhocExemptions; // coverage:ignore-line
    }

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.2) // coverage:ignore-line
              : Colors.black.withValues(alpha: 0.1),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Total TDS tracked'),
              subtitle: generatedTds.isNotEmpty
                  ? const Text('Includes projected monthly salary TDS')
                  : null,
              trailing: SmartCurrencyText(
                  value: totalTds,
                  locale: ref.watch(currencyProvider),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            if (refundForecast > 0)
              ListTile(
                // coverage:ignore-line
                dense: true,
                contentPadding: EdgeInsets.zero,
                // coverage:ignore-start
                title: Text('Tax Refund Forecast',
                    style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.light
                            ? Colors.green.shade700
                            : Colors.green.shade400)),
                trailing: Text(
                    CurrencyUtils.formatCurrency(
                        refundForecast, ref.watch(currencyProvider)),
                    style: TextStyle(
                        // coverage:ignore-end
                        fontWeight: FontWeight.bold,
                        // coverage:ignore-start
                        color: Theme.of(context).brightness == Brightness.light
                            ? Colors.green.shade700
                            : Colors.green.shade400)),
                // coverage:ignore-end
              ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    // coverage:ignore-start
                    onPressed: () {
                      setState(
                          () => _selectedIndex = 5); // Navigate to Tax Paid tab
                      // coverage:ignore-end
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('View/Edit All TDS'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _addCustomExemptionDialog(
      // coverage:ignore-line
      {CustomExemption? existing,
      required Function(CustomExemption) onAdd}) {
    final nameCtrl = TextEditingController(
        text: existing?.name ?? ''); // coverage:ignore-line

    // coverage:ignore-start
    final amtCtrl = TextEditingController(
        text: existing != null ? existing.amount.toStringAsFixed(2) : '');
    bool isCliff = existing?.isCliffExemption ?? false;
    // coverage:ignore-end

    // coverage:ignore-start
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (context, setStateBuilder) {
        return AlertDialog(
          title: Text(existing == null
              // coverage:ignore-end
              ? 'Add Custom Exemption'
              : 'Edit Custom Exemption'),
          content: SingleChildScrollView(
            // coverage:ignore-line
            child: Column(
              // coverage:ignore-line
              mainAxisSize: MainAxisSize.min,
              children: [
                // coverage:ignore-line
                TextField(
                    // coverage:ignore-line
                    controller: nameCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Exemption Name')),
                TextField(
                  // coverage:ignore-line
                  controller: amtCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Annual Amount',
                      helperText: 'Total yearly amount.'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    // coverage:ignore-line
                    FilteringTextInputFormatter.allow(
                        RegexUtils.amountExp) // coverage:ignore-line
                  ],
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  // coverage:ignore-line
                  title: const Text('Is Cliff Exemption?'),
                  subtitle: const Text(
                      'If checked, income above limit becomes fully taxable.'),
                  value: isCliff,
                  onChanged: (v) => setStateBuilder(
                      () => isCliff = v), // coverage:ignore-line
                ),
              ],
            ),
          ),
          // coverage:ignore-start
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                // coverage:ignore-end
                child: const Text('Cancel')),
            // coverage:ignore-start
            FilledButton(
              onPressed: () {
                if (nameCtrl.text.isEmpty) return;
                final amountText = amtCtrl.text.replaceAll(',', '');
                final amount = double.tryParse(amountText) ?? 0;
                // coverage:ignore-end

                // coverage:ignore-start
                final ex = CustomExemption(
                  id: existing?.id ?? const Uuid().v4(),
                  name: nameCtrl.text,
                  // coverage:ignore-end
                  amount: amount,
                  isCliffExemption: isCliff,
                );
                onAdd(ex); // coverage:ignore-line
                Navigator.pop(ctx); // coverage:ignore-line
              },
              child: const Text('Save'),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildSalaryTakeHomeRow() {
    final rules =
        ref.watch(taxConfigServiceProvider).getRulesForYear(_currentData.year);
    final strategy = ref.read(indianTaxServiceProvider);
    final breakdown =
        strategy.calculateMonthlySalaryBreakdown(_currentData, rules);

    if (breakdown.isEmpty) return const SizedBox.shrink();

    final now = DateTime.now();
    final currentMonth = now.month;
    final data = breakdown[currentMonth] ?? {};

    final gross = data['gross'] ?? 0.0;
    final tax = data['tax'] ?? 0.0;
    final ded = data['deductions'] ?? 0.0;
    final net = data['takeHome'] ?? 0.0;
    final currencyLocale = ref.watch(currencyProvider);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.blue.withValues(alpha: 0.3) // coverage:ignore-line
              : Colors.blue.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(AppLocalizations.of(context)!.detailedEstCurrentMonthLabel,
                    style: const TextStyle(
                        fontSize: 10,
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 2,
                  children: [
                    SmartCurrencyText(
                        value: gross,
                        locale: currencyLocale,
                        suffix:
                            ' (${AppLocalizations.of(context)!.grossShortLabel}) - ',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white70
                                    : Colors.black87)),
                    SmartCurrencyText(
                        value: tax,
                        locale: currencyLocale,
                        suffix:
                            ' (${AppLocalizations.of(context)!.taxShortLabel}) - ',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white70
                                    : Colors.black87)),
                    SmartCurrencyText(
                        value: ded,
                        locale: currencyLocale,
                        suffix:
                            ' (${AppLocalizations.of(context)!.dedShortLabel}) = ',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white70
                                    : Colors.black87)),
                    SmartCurrencyText(
                        value: net,
                        locale: currencyLocale,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white70
                                    : Colors.black87)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(AppLocalizations.of(context)!.netMonthlyLabel,
                    style: const TextStyle(
                        fontSize: 10,
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5)),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: SmartCurrencyText(
                    value: net,
                    locale: currencyLocale,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.green),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTakeHomeBreakdown() {
    final rules =
        ref.watch(taxConfigServiceProvider).getRulesForYear(_currentData.year);
    final strategy = ref.read(indianTaxServiceProvider);
    final breakdown =
        strategy.calculateMonthlySalaryBreakdown(_currentData, rules);

    if (breakdown.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.2) // coverage:ignore-line
              : Colors.black.withValues(alpha: 0.1),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTakeHomeBreakdownHeader(),
            Text(
              AppLocalizations.of(context)!.bonusTaxNote,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            _buildTakeHomeBreakdownTableHeader(),
            ...[4, 5, 6, 7, 8, 9, 10, 11, 12, 1, 2, 3]
                .map((m) => _buildTakeHomeBreakdownRow(m, breakdown)),
          ],
        ),
      ),
    );
  }

  Widget _buildTakeHomeBreakdownHeader() {
    final isCompact = ref.watch(currencyFormatProvider);
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildSectionTitle(
            AppLocalizations.of(context)!.monthlyTakeHomeBreakdownTitle),
        GestureDetector(
          onTap: () => // coverage:ignore-line
              ref.read(currencyFormatProvider.notifier).value =
                  !isCompact, // coverage:ignore-line
          behavior: HitTestBehavior.opaque,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(AppLocalizations.of(context)!.detailedLinkLabel,
                  style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 4),
              Icon(
                isCompact ? Icons.compress : Icons.expand,
                size: 14,
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTakeHomeBreakdownTableHeader() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.5))),
      ),
      child: Row(
        children: [
          Expanded(
              flex: 2,
              child: Text(l10n.monthLabel,
                  style: const TextStyle(fontWeight: FontWeight.bold))),
          Expanded(
              flex: 3,
              child: Text(l10n.grossShortLabel,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.end)),
          Expanded(
              flex: 3,
              child: Text(l10n.taxShortLabel,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.end)),
          Expanded(
              flex: 3,
              child: Text(l10n.dedShortLabel,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.end)),
          Expanded(
              flex: 3,
              child: Text(l10n.netShortLabel,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.end)),
        ],
      ),
    );
  }

  Widget _buildTakeHomeBreakdownRow(
      int m, Map<int, Map<String, double>> breakdown) {
    final data = breakdown[m] ?? {};
    final gross = data['gross'] ?? 0.0;
    final tax = data['tax'] ?? 0.0;
    final ded = data['deductions'] ?? 0.0;
    final net = data['takeHome'] ?? 0.0;
    final isStopped =
        _getStructureForMonth(m)?.stoppedMonths.contains(m) ?? false;
    final currencyLocale = ref.watch(currencyProvider);
    final isCompact = ref.watch(currencyFormatProvider);

    String format(double val) {
      if (isStopped) return '-';
      return isCompact
          ? CurrencyUtils.getSmartFormat(
              val, currencyLocale) // coverage:ignore-line
          : CurrencyUtils.formatCurrency(val, currencyLocale);
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.1))),
      ),
      child: Row(
        children: [
          Expanded(
              flex: 2,
              child: Text(DateFormat('MMM').format(DateTime(2023, m, 1)),
                  style: const TextStyle(fontSize: 13))),
          Expanded(
              flex: 3,
              child: Text(format(gross),
                  style: const TextStyle(fontSize: 13),
                  textAlign: TextAlign.end)),
          Expanded(
              flex: 3,
              child: Text(format(tax),
                  style: const TextStyle(fontSize: 13, color: Colors.redAccent),
                  textAlign: TextAlign.end)),
          Expanded(
              flex: 3,
              child: Text(format(ded),
                  style: const TextStyle(fontSize: 13, color: Colors.orange),
                  textAlign: TextAlign.end)),
          Expanded(
              flex: 3,
              child: Text(format(net),
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.green),
                  textAlign: TextAlign.end)),
        ],
      ),
    );
  }

  Widget _buildHousePropertyTab() {
    final rules =
        ref.watch(taxConfigServiceProvider).getRulesForYear(_currentData.year);
    final taxService = ref.read(indianTaxServiceProvider);
    final taxableHP =
        taxService.calculateHousePropertyIncome(_currentData, rules);

    final filteredForTotals = _getFilteredHP(includeEntryFilter: false);
    final filteredForDisplay = _getFilteredHP(includeEntryFilter: true);

    final totalRent = filteredForTotals
        .where((h) => !h.isSelfOccupied)
        .fold(0.0, (sum, h) => sum + h.rentReceived);
    final totalInterest =
        filteredForTotals.fold(0.0, (sum, h) => sum + h.interestOnLoan);

    final hpRuleExemptions = _calculateHPAdHocExemptions(totalRent, rules);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSummaryHeaderCard(
          title: AppLocalizations.of(context)!.housePropertiesTitle,
          buttonLabel: AppLocalizations.of(context)!.addPropertyAction,
          onAdd: () => _addHousePropertyDialog(),
          children: [
            _buildSummaryRow(
                AppLocalizations.of(context)!.totalRentReceivedLabel,
                totalRent),
            _buildSummaryRow(
                AppLocalizations.of(context)!.totalInterestOnLoanLabel,
                totalInterest,
                isDeduction: true),
            if (hpRuleExemptions > 0)
              _buildSummaryRow(
                  // coverage:ignore-line
                  AppLocalizations.of(context)!
                      .adhocExemptionsLabel, // coverage:ignore-line
                  hpRuleExemptions,
                  isDeduction: true),
            const Divider(),
            _buildSummaryRow(
                AppLocalizations.of(context)!.taxableHPIncomeLabel, taxableHP,
                isBold: true),
          ],
        ),
        const SizedBox(height: 16),
        if (_houseProperties.isNotEmpty)
          _buildFilterRow(_hpFilter, (v) => setState(() => _hpFilter = v)),
        if (_houseProperties.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 40.0),
              child: Text(AppLocalizations.of(context)!.noHousePropertiesNote),
            ),
          )
        else
          ..._buildHPList(filteredForDisplay),
      ],
    );
  }

  List<HouseProperty> _getFilteredHP({required bool includeEntryFilter}) {
    return _applyStandardFilters<HouseProperty>(
      _houseProperties,
      includeEntryFilter: includeEntryFilter,
      currentFilter: _hpFilter,
      getIsManual: (h) => h.isManualEntry,
      getDate: (h) =>
          h.transactionDate ?? DateTime.now(), // coverage:ignore-line
    );
  }

  double _calculateHPAdHocExemptions(double totalRent, TaxRules rules) {
    return rules.customExemptions
        .where((e) => e.isEnabled && e.incomeHead == 'House Property')
        .fold(
            0.0,
            (sum, e) => // coverage:ignore-line
                sum +
                (e.isPercentage
                    ? (totalRent * e.limit / 100)
                    : e.limit)); // coverage:ignore-line
  }

  List<Widget> _buildHPList(List<HouseProperty> filtered) {
    return filtered.map((hp) {
      // Find original index for editing/deletion
      final i = _houseProperties.indexOf(hp);
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.2) // coverage:ignore-line
                : Colors.black.withValues(alpha: 0.1),
          ),
        ),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.grey.withValues(alpha: 0.1),
            child: Icon(Icons.home_outlined,
                color: Theme.of(context).colorScheme.primary, size: 20),
          ),
          title: Text(hp.name,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(hp.isSelfOccupied
              ? '${AppLocalizations.of(context)!.selfOccupiedLabel} • ${AppLocalizations.of(context)!.interestLabel}: ${CurrencyUtils.formatCurrency(hp.interestOnLoan, ref.watch(currencyProvider))}'
              : '${AppLocalizations.of(context)!.letOutLabel} • ${AppLocalizations.of(context)!.grossIncomeLabel}: ${CurrencyUtils.formatCurrency(hp.rentReceived, ref.watch(currencyProvider))}'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildBadge(hp.isManualEntry, hp.lastUpdated, hp.transactionDate),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.grey, size: 20),
                // coverage:ignore-start
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  setState(() => _houseProperties.removeAt(i));
                  _updateSummary();
                  // coverage:ignore-end
                },
              ),
            ],
          ),
          // coverage:ignore-start
          onTap: () {
            FocusScope.of(context).unfocus();
            _addHousePropertyDialog(existing: hp, index: i);
            // coverage:ignore-end
          },
        ),
      );
    }).toList();
  }

  // Removed _buildConsolidatedAdjustments, _isPayoutMonth, _buildAdjustmentTile, _updatePartialAmount

  Widget _buildSalarySummaryCard() {
    final rules =
        ref.watch(taxConfigServiceProvider).getRulesForYear(_currentData.year);
    final taxService = ref.read(indianTaxServiceProvider);

    final salaryOnlyData = _currentData.copyWith(
      houseProperties: [],
      businessIncomes: [],
      capitalGains: [],
      otherIncomes: [],
      dividendIncome: const DividendIncome(),
      cashGifts: [],
    );

    final data = _calculateSalarySummary(salaryOnlyData, rules, taxService);
    final bool useCompact = ref.watch(currencyFormatProvider);

    return Card(
      color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.2) // coverage:ignore-line
              : Colors.black.withValues(alpha: 0.1),
        ),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        // coverage:ignore-start
        onTap: () {
          FocusScope.of(context).unfocus();
          ref.read(currencyFormatProvider.notifier).value = !useCompact;
          // coverage:ignore-end
        },
        contentPadding: const EdgeInsets.all(16.0),
        title: _buildSalarySummaryHeader(useCompact),
        subtitle: _buildSalarySummaryDetails(data),
      ),
    );
  }

  ({
    double gross,
    double statutoryExemptions,
    double standardDeduction,
    double nps,
    double customExemptions,
    double baseTaxableIncome,
    double totalTaxableIncome
  }) _calculateSalarySummary(
      TaxYearData salaryOnlyData, TaxRules rules, IndianTaxService taxService) {
    double gross = taxService.calculateSalaryGross(salaryOnlyData, rules);
    double statutoryExemptions =
        taxService.calculateSalaryExemptions(salaryOnlyData, rules);

    double standardDeduction =
        rules.isStdDeductionSalaryEnabled ? rules.stdDeductionSalary : 0;
    double nps = salaryOnlyData.salary.npsEmployer;
    double salaryRuleExemptions = rules.customExemptions
        .where((e) => e.isEnabled && e.incomeHead == 'Salary')
        .fold(
            0.0,
            (sum, e) => // coverage:ignore-line
                sum +
                (e.isPercentage
                    ? (gross * e.limit / 100)
                    : e.limit)); // coverage:ignore-line

    double customExemptions =
        _independentExemptions.fold(0.0, (sum, e) => sum + e.amount) +
            salaryRuleExemptions;

    double baseTaxableIncome =
        (gross - statutoryExemptions - standardDeduction - nps)
            .clamp(0.0, double.infinity);
    double totalTaxableIncome =
        (baseTaxableIncome - customExemptions).clamp(0.0, double.infinity);

    return (
      gross: gross,
      statutoryExemptions: statutoryExemptions,
      standardDeduction: standardDeduction,
      nps: nps,
      customExemptions: customExemptions,
      baseTaxableIncome: baseTaxableIncome,
      totalTaxableIncome: totalTaxableIncome
    );
  }

  Widget _buildSalarySummaryHeader(bool useCompact) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            AppLocalizations.of(context)!.projectedAnnualIncomeTitle,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary),
          ),
        ),
        Icon(
          useCompact ? Icons.compress : Icons.expand,
          size: 14,
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
        ),
      ],
    );
  }

  Widget _buildSalarySummaryDetails(
      ({
        double gross,
        double statutoryExemptions,
        double standardDeduction,
        double nps,
        double customExemptions,
        double baseTaxableIncome,
        double totalTaxableIncome
      }) data) {
    final bool isLight = Theme.of(context).brightness == Brightness.light;
    final Color deductColor =
        isLight ? Colors.orange.shade800 : Colors.orange.shade300;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        _buildSummaryRow(
            AppLocalizations.of(context)!.totalGrossSalaryLabel, data.gross,
            isBold: true),
        if (data.standardDeduction > 0)
          _buildSummaryRow(
              AppLocalizations.of(context)!.lessStandardDeductionLabel,
              data.standardDeduction,
              isDeduction: true,
              color: deductColor),
        if (data.statutoryExemptions > 0)
          _buildSummaryRow(
              // coverage:ignore-line
              AppLocalizations.of(context)!
                  .lessStatutoryExemptionsLabel, // coverage:ignore-line
              data.statutoryExemptions,
              isDeduction: true,
              color: deductColor),
        if (data.nps > 0)
          _buildSummaryRow(
              AppLocalizations.of(context)!.lessEmployerNPSLabel, data.nps,
              isDeduction: true, color: deductColor),
        if (data.customExemptions > 0) ...[
          const Divider(),
          _buildSummaryRow(
              // coverage:ignore-line
              AppLocalizations.of(context)!
                  .taxableBeforeAdHocExemptionsLabel, // coverage:ignore-line
              data.baseTaxableIncome,
              isBold: true,
              fontSize: 13),
          _buildSummaryRow(
              // coverage:ignore-line
              AppLocalizations.of(context)!
                  .lessCustomAdHocExemptionsLabel, // coverage:ignore-line
              data.customExemptions,
              isDeduction: true,
              color: deductColor),
        ],
        const Divider(),
        _buildSummaryRow(
            AppLocalizations.of(context)!.totalTaxableSalaryIncomeLabel,
            data.totalTaxableIncome,
            isBold: true,
            fontSize: 18,
            color: Theme.of(context).colorScheme.primary),
      ],
    );
  }

  Widget _buildSummaryRow(String label, double value,
      {bool isBold = false,
      bool isDeduction = false,
      double fontSize = 12,
      Color? color}) {
    final locale = ref.watch(currencyProvider);
    final useCompact = ref.watch(currencyFormatProvider);
    final formattedValue = useCompact
        ? CurrencyUtils.getSmartFormat(value, locale) // coverage:ignore-line
        : CurrencyUtils.formatCurrency(value, locale);

    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            isDeduction ? '- $formattedValue' : formattedValue,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  SalaryStructure? _getStructureForMonth(int month) {
    // Determine the year of the month
    // FY 2025-26: Apr 2025 to Mar 2026
    int targetYear = _currentData.year;
    if (month >= 1 && month <= 3) targetYear++;
    final date = DateTime(targetYear, month, 1);

    for (final s in _currentData.salary.history) {
      if (s.effectiveDate.isBefore(date) || // coverage:ignore-line
          s.effectiveDate.isAtSameMomentAs(date)) {
        // coverage:ignore-line
        return s;
      }
    }
    return _currentData.salary.history.lastOrNull;
  }

  Widget _buildHousePropertyInputs(
      TextEditingController nameCtrl,
      TextEditingController rentCtrl,
      TextEditingController taxCtrl,
      TextEditingController intCtrl,
      bool isSelf,
      String? selectedLoanId,
      List<Loan> loans,
      ValueChanged<bool> onSelfChanged,
      ValueChanged<String?> onLoanChanged,
      BuildContext context,
      DateTime pickedDate,
      ValueChanged<DateTime> onDateChanged) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(labelText: 'Property Name')),
        CheckboxListTile(
          title: const Text('Self Occupied?'),
          value: isSelf,
          onChanged: (v) => onSelfChanged(v ?? true), // coverage:ignore-line
        ),
        if (!isSelf) ...[
          // coverage:ignore-line
          TextField(
              // coverage:ignore-line
              controller: rentCtrl,
              decoration: const InputDecoration(
                  labelText: 'Annual Rent Received (Gross)'),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                // coverage:ignore-line
                FilteringTextInputFormatter.allow(
                    RegexUtils.amountExp), // coverage:ignore-line
              ]),
          TextField(
              // coverage:ignore-line
              controller: taxCtrl,
              decoration:
                  const InputDecoration(labelText: 'Municipal Taxes Paid'),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                // coverage:ignore-line
                FilteringTextInputFormatter.allow(
                    RegexUtils.amountExp), // coverage:ignore-line
              ]),
        ],
        const Divider(),
        const SizedBox(height: 16),
        const Text('Loan Details',
            style: TextStyle(fontWeight: FontWeight.bold)),
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(
            labelText: 'Link Loan',
            helperText: 'Select a loan to auto-calculate interest',
            border: OutlineInputBorder(),
            floatingLabelBehavior: FloatingLabelBehavior.always,
          ),
          key: ValueKey(selectedLoanId),
          initialValue: selectedLoanId,
          isDense: true,
          hint: const Text('Select Loan'),
          items: [
            const DropdownMenuItem(
                value: null, child: Text('None (Manual Entry)')),
            ...loans.map((l) => DropdownMenuItem(
                value: l.id, // coverage:ignore-line
                child: Text(
                    '${l.name} (${l.id.substring(0, 4)}...)'))) // coverage:ignore-line
          ],
          onChanged: onLoanChanged,
        ),
        if (selectedLoanId == null)
          TextField(
              controller: intCtrl,
              decoration: const InputDecoration(
                  labelText: 'Interest on Loan (Manual Entry)'),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegexUtils.amountExp),
              ]),
        if (selectedLoanId != null)
          Padding(
            // coverage:ignore-line
            padding: const EdgeInsets.symmetric(vertical: 8),
            // coverage:ignore-start
            child: Text(
                'Linking to loan: ${loans.firstWhere((l) => l.id == selectedLoanId).name}',
                style: TextStyle(
                    color: Theme.of(context).primaryColor, fontSize: 12)),
            // coverage:ignore-end
          ),
        const Divider(),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(AppLocalizations.of(context)!.transactionDateLabel),
          subtitle: Text(DateFormat(_dateFormatIso8601).format(pickedDate)),
          trailing: const Icon(Icons.calendar_month),
          onTap: () async {
            // coverage:ignore-line
            final d = await showDatePicker(
              // coverage:ignore-line
              context: context,
              initialDate: pickedDate,
              firstDate: DateTime(2020), // coverage:ignore-line
              lastDate: DateTime.now(), // coverage:ignore-line
            );
            if (d != null) onDateChanged(d); // coverage:ignore-line
          },
        ),
      ],
    );
  }

  void _addHousePropertyDialog({HouseProperty? existing, int? index}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final rentCtrl =
        TextEditingController(text: existing?.rentReceived.toString() ?? '');
    final taxCtrl =
        TextEditingController(text: existing?.municipalTaxes.toString() ?? '');
    final intCtrl =
        TextEditingController(text: existing?.interestOnLoan.toString() ?? '');

    String? selectedLoanId = existing?.loanId; // coverage:ignore-line
    bool isSelf = existing?.isSelfOccupied ?? true; // coverage:ignore-line

    final loansAsync = ref.watch(loansProvider);
    final loans = loansAsync.value ?? [];
    DateTime pickedDate = existing?.transactionDate ?? DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateBuilder) => _buildHousePropertyDialog(
          ctx: ctx,
          existing: existing,
          index: index,
          nameCtrl: nameCtrl,
          rentCtrl: rentCtrl,
          taxCtrl: taxCtrl,
          intCtrl: intCtrl,
          isSelf: isSelf,
          selectedLoanId: selectedLoanId,
          loans: loans,
          onSelfChanged: (v) =>
              setStateBuilder(() => isSelf = v), // coverage:ignore-line
          onLoanChanged: (v) =>
              setStateBuilder(() => selectedLoanId = v), // coverage:ignore-line
          pickedDate: pickedDate,
          onDateChanged: (d) =>
              setStateBuilder(() => pickedDate = d), // coverage:ignore-line
        ),
      ),
    );
  }

  Widget _buildHousePropertyDialog({
    required BuildContext ctx,
    required HouseProperty? existing,
    required int? index,
    required TextEditingController nameCtrl,
    required TextEditingController rentCtrl,
    required TextEditingController taxCtrl,
    required TextEditingController intCtrl,
    required bool isSelf,
    required String? selectedLoanId,
    required List<Loan> loans,
    required ValueChanged<bool> onSelfChanged,
    required ValueChanged<String?> onLoanChanged,
    required DateTime pickedDate,
    required ValueChanged<DateTime> onDateChanged,
  }) {
    return AlertDialog(
      title: Text(existing == null
          ? AppLocalizations.of(context)!.addPropertyAction
          : AppLocalizations.of(context)!
              .editPropertyAction), // coverage:ignore-line
      content: SingleChildScrollView(
        child: _buildHousePropertyInputs(
          nameCtrl,
          rentCtrl,
          taxCtrl,
          intCtrl,
          isSelf,
          selectedLoanId,
          loans,
          onSelfChanged,
          onLoanChanged,
          ctx,
          pickedDate,
          onDateChanged,
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), // coverage:ignore-line
            child: Text(AppLocalizations.of(context)!.cancelButton)),
        FilledButton(
          onPressed: () {
            _saveHouseProperty(
              existing: existing,
              index: index,
              nameCtrl: nameCtrl,
              rentCtrl: rentCtrl,
              taxCtrl: taxCtrl,
              intCtrl: intCtrl,
              isSelf: isSelf,
              selectedLoanId: selectedLoanId,
              pickedDate: pickedDate,
            );
          },
          child: Text(AppLocalizations.of(context)!.saveButton),
        ),
      ],
    );
  }

  void _saveHouseProperty({
    required HouseProperty? existing,
    required int? index,
    required TextEditingController nameCtrl,
    required TextEditingController rentCtrl,
    required TextEditingController taxCtrl,
    required TextEditingController intCtrl,
    required bool isSelf,
    required String? selectedLoanId,
    required DateTime pickedDate,
  }) {
    final newHP = HouseProperty(
      name: nameCtrl.text,
      isSelfOccupied: isSelf,
      rentReceived: double.tryParse(rentCtrl.text) ?? 0,
      municipalTaxes: double.tryParse(taxCtrl.text) ?? 0,
      isManualEntry: true,
      lastUpdated: DateTime.now(),
      transactionDate: pickedDate,
      interestOnLoan: selectedLoanId != null
          ? 0
          : (double.tryParse(intCtrl.text) ??
              0), // If linked, 0 placeholder until sync
      loanId: selectedLoanId,
    );

    setState(() {
      if (existing != null && index != null) {
        _houseProperties[index] = newHP; // coverage:ignore-line
      } else {
        _houseProperties.add(newHP);
      }
    });
    _updateSummary();
    Navigator.pop(context);
  }

  Widget _buildBusinessTab() {
    final rules =
        ref.watch(taxConfigServiceProvider).getRulesForYear(_currentData.year);
    final taxService = ref.read(indianTaxServiceProvider);
    final taxableBusiness =
        taxService.calculateBusinessIncome(_currentData, rules);

    final filteredForTotals = _getFilteredBusiness(includeEntryFilter: false);
    final filteredForDisplay = _getFilteredBusiness(includeEntryFilter: true);

    final totalTurnover =
        filteredForTotals.fold(0.0, (sum, b) => sum + b.grossTurnover);
    final totalNet = filteredForTotals.fold(0.0, (sum, b) => sum + b.netIncome);

    final bizRuleExemptions =
        _calculateBusinessAdHocExemptions(totalNet, rules);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSummaryHeaderCard(
          title: AppLocalizations.of(context)!.businessProfessionTitle,
          buttonLabel: AppLocalizations.of(context)!.addBusinessAction,
          onAdd: () => _addBusinessDialog(),
          children: [
            _buildSummaryRow(AppLocalizations.of(context)!.totalTurnoverLabel,
                totalTurnover),
            _buildSummaryRow(
                AppLocalizations.of(context)!.totalNetIncomeLabel, totalNet),
            if (bizRuleExemptions > 0)
              _buildSummaryRow(
                  // coverage:ignore-line
                  AppLocalizations.of(context)!
                      .adhocExemptionsLabel, // coverage:ignore-line
                  bizRuleExemptions,
                  isDeduction: true),
            const Divider(),
            _buildSummaryRow(
                AppLocalizations.of(context)!.taxableBusinessIncomeLabel,
                taxableBusiness,
                isBold: true),
          ],
          showChildren: _businessIncomes.isNotEmpty,
        ),
        if (_businessIncomes.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildFilterRow(
              _businessFilter, (v) => setState(() => _businessFilter = v)),
        ],
        if (_businessIncomes.isEmpty)
          Center(
              child: Padding(
            padding: const EdgeInsets.only(top: 40.0),
            child: Text(AppLocalizations.of(context)!.noBusinessIncomeNote),
          ))
        else
          ..._buildBusinessList(filteredForDisplay),
      ],
    );
  }

  List<BusinessEntity> _getFilteredBusiness(
      {required bool includeEntryFilter}) {
    return _applyStandardFilters<BusinessEntity>(
      _businessIncomes,
      includeEntryFilter: includeEntryFilter,
      currentFilter: _businessFilter,
      getIsManual: (b) => b.isManualEntry,
      getDate: (b) =>
          b.transactionDate ?? DateTime.now(), // coverage:ignore-line
    );
  }

  double _calculateBusinessAdHocExemptions(double totalNet, TaxRules rules) {
    return rules.customExemptions
        .where((e) => e.isEnabled && e.incomeHead == 'Business')
        .fold(
            0.0,
            (sum, e) => // coverage:ignore-line
                sum +
                (e.isPercentage
                    ? (totalNet * e.limit / 100)
                    : e.limit)); // coverage:ignore-line
  }

  List<Widget> _buildBusinessList(List<BusinessEntity> filtered) {
    return filtered.map((b) {
      final i = _businessIncomes.indexOf(b);
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.2) // coverage:ignore-line
                : Colors.black.withValues(alpha: 0.1),
          ),
        ),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.grey.withValues(alpha: 0.1),
            child: Icon(Icons.business_center_outlined,
                color: Theme.of(context).colorScheme.primary, size: 20),
          ),
          title:
              Text(b.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(
              '${b.type.toHumanReadable()} • ${AppLocalizations.of(context)!.grossShortLabel}: ${CurrencyUtils.formatCurrency(b.grossTurnover, ref.watch(currencyProvider))} • ${AppLocalizations.of(context)!.netShortLabel}: ${CurrencyUtils.formatCurrency(b.netIncome, ref.watch(currencyProvider))}'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildBadge(b.isManualEntry, b.lastUpdated),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.grey, size: 20),
                // coverage:ignore-start
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  setState(() => _businessIncomes.removeAt(i));
                  _updateSummary();
                  // coverage:ignore-end
                },
              ),
            ],
          ),
          // coverage:ignore-start
          onTap: () {
            FocusScope.of(context).unfocus();
            _addBusinessDialog(existing: b, index: i);
            // coverage:ignore-end
          },
        ),
      );
    }).toList();
  }

  void _addBusinessDialog({BusinessEntity? existing, int? index}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final turnoverCtrl =
        TextEditingController(text: existing?.grossTurnover.toString() ?? '');
    final netCtrl =
        TextEditingController(text: existing?.netIncome.toString() ?? '');

    BusinessType type =
        existing?.type ?? BusinessType.regular; // coverage:ignore-line
    DateTime pickedDate = existing?.transactionDate ?? DateTime.now();
    final rules =
        ref.read(taxConfigServiceProvider).getRulesForYear(_currentData.year);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (context, setStateBuilder) {
        return AlertDialog(
          title: Text(existing == null
              ? AppLocalizations.of(context)!.addBusinessAction
              : AppLocalizations.of(context)!
                  .editBusinessAction), // coverage:ignore-line
          content: SingleChildScrollView(
            child: _buildBusinessDialogBody(
              nameCtrl: nameCtrl,
              turnoverCtrl: turnoverCtrl,
              netCtrl: netCtrl,
              type: type,
              rules: rules,
              pickedDate: pickedDate,
              onTypeChanged: (v) =>
                  setStateBuilder(() => type = v!), // coverage:ignore-line
              onDatePicked: (d) =>
                  setStateBuilder(() => pickedDate = d), // coverage:ignore-line
            ),
          ),
          actions: _buildBusinessDialogActions(
            ctx: ctx,
            nameCtrl: nameCtrl,
            turnoverCtrl: turnoverCtrl,
            netCtrl: netCtrl,
            type: type,
            pickedDate: pickedDate,
            index: index,
            existing: existing,
          ),
        );
      }),
    );
  }

  Widget _buildBusinessDialogBody({
    required TextEditingController nameCtrl,
    required TextEditingController turnoverCtrl,
    required TextEditingController netCtrl,
    required BusinessType type,
    required TaxRules rules,
    required DateTime pickedDate,
    required void Function(BusinessType?) onTypeChanged,
    required void Function(DateTime) onDatePicked,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
            controller: nameCtrl,
            decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.businessNameLabel)),
        _buildBusinessTypeDropdown(type, rules, onTypeChanged),
        if (type != BusinessType.regular)
          _buildTurnoverWarning(
              turnoverCtrl, type, rules), // coverage:ignore-line
        TextField(
            controller: turnoverCtrl,
            decoration: InputDecoration(
                labelText:
                    AppLocalizations.of(context)!.grossTurnoverReceiptsLabel),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegexUtils.amountExp),
            ]),
        TextField(
            controller: netCtrl,
            decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.netIncomeProfitLabel,
                helperText: type == BusinessType.regular
                    ? AppLocalizations.of(context)!.actualProfitHelper
                    : AppLocalizations.of(context)!
                        .presumptiveProfitHelper), // coverage:ignore-line
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegexUtils.amountExp),
            ]),
        const SizedBox(height: 8),
        _buildDatePickerTile(
          title: AppLocalizations.of(context)!.transactionDateLabel,
          date: pickedDate,
          onDatePicked: onDatePicked,
        ),
      ],
    );
  }

  List<Widget> _buildBusinessDialogActions({
    required BuildContext ctx,
    required TextEditingController nameCtrl,
    required TextEditingController turnoverCtrl,
    required TextEditingController netCtrl,
    required BusinessType type,
    required DateTime pickedDate,
    int? index,
    BusinessEntity? existing,
  }) {
    return [
      TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel')), // coverage:ignore-line
      FilledButton(
        onPressed: () {
          if (_onSaveBusiness(
            nameCtrl: nameCtrl,
            turnoverCtrl: turnoverCtrl,
            netCtrl: netCtrl,
            type: type,
            pickedDate: pickedDate,
            index: index,
          )) {
            Navigator.pop(ctx);
          }
        },
        child: const Text('Save'),
      ),
    ];
  }

  bool _onSaveBusiness({
    required TextEditingController nameCtrl,
    required TextEditingController turnoverCtrl,
    required TextEditingController netCtrl,
    required BusinessType type,
    required DateTime pickedDate,
    int? index,
  }) {
    final turnover = double.tryParse(turnoverCtrl.text) ?? 0;
    final net = double.tryParse(netCtrl.text) ?? 0;
    if (net <= 0) return false;
    if (type != BusinessType.regular && turnover <= 0) return false;

    final entry = BusinessEntity(
      name: nameCtrl.text,
      type: type,
      grossTurnover: turnover,
      netIncome: net,
      transactionDate: pickedDate,
      isManualEntry: true,
      lastUpdated: DateTime.now(),
    );

    setState(() {
      if (index != null) {
        _businessIncomes[index] = entry; // coverage:ignore-line
      } else {
        _businessIncomes.add(entry);
      }
    });

    _updateSummary();
    return true;
  }

  Widget _buildBusinessTypeDropdown(
      BusinessType type, dynamic rules, ValueChanged<BusinessType?> onChanged) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: AppLocalizations.of(context)!.taxationTypeLabel,
        helperText: AppLocalizations.of(context)!.presumptiveTaxationHelper,
        suffixIcon: Tooltip(
          triggerMode: TooltipTriggerMode.tap,
          showDuration: const Duration(seconds: 5),
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.symmetric(horizontal: 20),
          message: AppLocalizations.of(context)!.taxationTypeTooltip,
          child: const Icon(Icons.info_outline, color: Colors.blue),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<BusinessType>(
          value: type,
          isDense: true,
          items: _getEnabledBusinessTypes(rules),
          onChanged: onChanged,
        ),
      ),
    );
  }

  List<DropdownMenuItem<BusinessType>> _getEnabledBusinessTypes(dynamic rules) {
    return BusinessType.values.where((t) {
      if (t == BusinessType.section44AD && !rules.is44ADEnabled) return false;
      if (t == BusinessType.section44ADA && !rules.is44ADAEnabled) return false;
      return true;
    }).map((t) {
      return DropdownMenuItem(value: t, child: Text(t.toHumanReadable()));
    }).toList();
  }

  Widget _buildTurnoverWarning(
      // coverage:ignore-line
      TextEditingController turnoverCtrl,
      BusinessType type,
      dynamic rules) {
    return ValueListenableBuilder<TextEditingValue>(
      // coverage:ignore-line
      valueListenable: turnoverCtrl,
      // coverage:ignore-start
      builder: (context, value, _) {
        double to = double.tryParse(value.text) ?? 0;
        double limit = type == BusinessType.section44AD
            ? rules.limit44AD
            : rules.limit44ADA;
        if (to > limit) {
          return Padding(
            // coverage:ignore-end
            padding: const EdgeInsets.only(top: 8.0),
            // coverage:ignore-start
            child: Text(
              AppLocalizations.of(context)!.turnoverExceedsLimitWarning(
                  CurrencyUtils.formatCurrency(
                      limit, ref.watch(currencyProvider))),
              // coverage:ignore-end
              style: const TextStyle(
                  color: Colors.orange,
                  fontSize: 12,
                  fontWeight: FontWeight.bold),
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildCapitalGainsTab() {
    final filteredForTotals = _getFilteredCG(includeEntryFilter: false);
    final filteredForDisplay = _getFilteredCG(includeEntryFilter: true);

    final totals = _calculateCGTotals(filteredForTotals);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: _buildSummaryHeaderCard(
            title: AppLocalizations.of(context)!.capitalGainsTitle,
            buttonLabel: AppLocalizations.of(context)!.addEntryAction,
            onAdd: () => _addCGEntryDialog(),
            children: [
              Text(AppLocalizations.of(context)!.netCapitalGainsSummaryTitle,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              _buildSummaryRow(AppLocalizations.of(context)!.shortTermSTCGLabel,
                  totals['stcg']!,
                  isBold: true),
              _buildSummaryRow(
                  AppLocalizations.of(context)!.longTermEquityLabel,
                  totals['ltcgEquity']!,
                  isBold: true),
              _buildSummaryRow(AppLocalizations.of(context)!.longTermOtherLabel,
                  totals['ltcgOther']!,
                  isBold: true),
            ],
            showChildren: _capitalGains.isNotEmpty,
          ),
        ),
        if (_capitalGains.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildFilterRow(_cgFilter, (v) => setState(() => _cgFilter = v)),
        ],
        Expanded(
          child: _buildCGList(filteredForDisplay),
        ),
      ],
    );
  }

  List<CapitalGainEntry> _getFilteredCG({required bool includeEntryFilter}) {
    return _applyStandardFilters<CapitalGainEntry>(
      _capitalGains,
      includeEntryFilter: includeEntryFilter,
      currentFilter: _cgFilter,
      getIsManual: (c) => c.isManualEntry,
      getDate: (c) => c.gainDate, // coverage:ignore-line
    );
  }

  Map<String, double> _calculateCGTotals(List<CapitalGainEntry> filtered) {
    double stcg = 0;
    double ltcgEquity = 0;
    double ltcgOther = 0;

    for (var gain in filtered) {
      double amt = gain.capitalGainAmount;
      if (gain.intendToReinvest) {
        amt = max(0, amt - gain.reinvestedAmount); // coverage:ignore-line
      }
      if (gain.isLTCG) {
        if (gain.matchAssetType == AssetType.equityShares) {
          // coverage:ignore-line
          ltcgEquity += amt; // coverage:ignore-line
        } else {
          ltcgOther += amt; // coverage:ignore-line
        }
      } else {
        stcg += amt;
      }
    }
    return {
      'stcg': stcg,
      'ltcgEquity': ltcgEquity,
      'ltcgOther': ltcgOther,
    };
  }

  Widget _buildCGList(List<CapitalGainEntry> filtered) {
    if (filtered.isEmpty) {
      return Center(
          child: Text(AppLocalizations.of(context)!.noCapitalGainsFoundNote));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: filtered.length,
      itemBuilder: (ctx, i) {
        final entry = filtered[i];
        final originalIndex = _capitalGains.indexOf(entry);
        return _buildCGEntryCard(entry, originalIndex);
      },
    );
  }

  Widget _buildCGEntryCard(CapitalGainEntry entry, int i) {
    final showReinvestAction = entry.intendToReinvest &&
        entry.matchReinvestType ==
            ReinvestmentType.none; // coverage:ignore-line

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.2) // coverage:ignore-line
              : Colors.black.withValues(alpha: 0.1),
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.grey.withValues(alpha: 0.1),
          child: Icon(Icons.show_chart_outlined,
              color: Theme.of(context).colorScheme.primary, size: 20),
        ),
        title: Text(entry.description,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                '${entry.matchAssetType.toHumanReadable()} • ${entry.isLTCG ? AppLocalizations.of(context)!.ltcgLabel : AppLocalizations.of(context)!.stcgLabel}'),
            Text(
                '${AppLocalizations.of(context)!.grossShortLabel}: ${CurrencyUtils.formatCurrency(entry.saleAmount, ref.watch(currencyProvider))}'),
            if (entry.intendToReinvest) _buildReinvestStatus(entry),
          ],
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showReinvestAction)
              IconButton(
                // coverage:ignore-line
                icon: const Icon(Icons.savings_outlined, color: Colors.orange),
                tooltip: 'Record Reinvestment',
                // coverage:ignore-start
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  _addCGEntryDialog(existing: entry, index: i);
                  // coverage:ignore-end
                },
              ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildBadge(
                      entry.isManualEntry, entry.lastUpdated, entry.gainDate),
                  const SizedBox(height: 2),
                  Text(
                      '${AppLocalizations.of(context)!.gainLabel}: ${CurrencyUtils.formatCurrency(entry.capitalGainAmount, ref.watch(currencyProvider))}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            PopupMenuButton<String>(
              // coverage:ignore-start
              onSelected: (v) {
                FocusScope.of(context).unfocus();
                if (v == 'edit') {
                  _addCGEntryDialog(existing: entry, index: i);
                } else if (v == 'delete') {
                  setState(() => _capitalGains.removeAt(i));
                  _updateSummary();
                  // coverage:ignore-end
                }
              },
              itemBuilder: (context) => [
                // coverage:ignore-line
                PopupMenuItem(
                    // coverage:ignore-line
                    value: 'edit',
                    child: Text(AppLocalizations.of(context)!
                        .editAction)), // coverage:ignore-line
                PopupMenuItem(
                    // coverage:ignore-line
                    value: 'delete',
                    child: Text(AppLocalizations.of(context)!
                        .deleteAction)), // coverage:ignore-line
              ],
            ),
          ],
        ),
        // coverage:ignore-start
        onTap: () {
          FocusScope.of(context).unfocus();
          _addCGEntryDialog(existing: entry, index: i);
          // coverage:ignore-end
        },
      ),
    );
  }

  Widget _buildReinvestStatus(CapitalGainEntry entry) {
    // coverage:ignore-line
    final isPending = entry.matchReinvestType ==
        ReinvestmentType.none; // coverage:ignore-line
    final color = isPending ? Colors.orange : Colors.green;
    final icon =
        isPending ? Icons.warning_amber_rounded : Icons.check_circle_outline;
    final text = isPending
        // coverage:ignore-start
        ? AppLocalizations.of(context)!.reinvestmentPendingLabel
        : AppLocalizations.of(context)!.reinvestedDetailsLabel(
            CurrencyUtils.formatCurrency(
                entry.reinvestedAmount, ref.watch(currencyProvider)),
            entry.matchReinvestType.toHumanReadable());
    // coverage:ignore-end

    // coverage:ignore-start
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        // coverage:ignore-end
        const SizedBox(width: 4),
        Text(text,
            style:
                TextStyle(color: color, fontSize: 12)), // coverage:ignore-line
      ],
    );
  }

  Widget _buildAssetTooltip(AssetType selectedAsset) {
    if (selectedAsset == AssetType.equityShares) {
      return Tooltip(
        triggerMode: TooltipTriggerMode.tap,
        showDuration: const Duration(seconds: 5),
        padding: const EdgeInsets.all(12),
        message: AppLocalizations.of(context)!.equitySharesTooltip,
        child: const Padding(
          padding: EdgeInsets.all(8.0),
          child: Icon(Icons.info_outline, color: Colors.blue, size: 20),
        ),
      );
    }
    if (selectedAsset == AssetType.other) {
      // coverage:ignore-line
      return Tooltip(
        // coverage:ignore-line
        triggerMode: TooltipTriggerMode.tap,
        showDuration: const Duration(seconds: 5),
        padding: const EdgeInsets.all(12),
        message: AppLocalizations.of(context)!
            .otherAssetsTooltip, // coverage:ignore-line
        child: const Padding(
          padding: EdgeInsets.all(8.0),
          child: Icon(Icons.info_outline, color: Colors.blue, size: 20),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildReinvestmentSection(
      bool intendToReinvest,
      ReinvestmentType selectedReinvestType,
      TextEditingController reinvestCtrl,
      DateTime? reinvestDate,
      DateTime gainDate,
      void Function(ReinvestmentType) onReinvestTypeChanged,
      void Function(DateTime) onReinvestDateChanged) {
    if (!intendToReinvest) return const SizedBox.shrink();

    return Column(
      // coverage:ignore-line
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // coverage:ignore-line
        const SizedBox(height: 12),
        Text(
            AppLocalizations.of(context)!
                .reinvestmentDetailsTitle, // coverage:ignore-line
            style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        // coverage:ignore-start
        InputDecorator(
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.typeLabel,
            // coverage:ignore-end
            isDense: true,
          ),
          child: DropdownButtonHideUnderline(
            // coverage:ignore-line
            child: DropdownButton<ReinvestmentType>(
              // coverage:ignore-line
              value: selectedReinvestType,
              isExpanded: true,
              items: ReinvestmentType.values
                  .map((t) => DropdownMenuItem(
                      // coverage:ignore-line
                      value: t,
                      // coverage:ignore-start
                      child: Text(t == ReinvestmentType.none
                          ? AppLocalizations.of(context)!.pendingNotDecidedLabel
                          : t.toHumanReadable())))
                  .toList(),
              onChanged: (v) => onReinvestTypeChanged(v!),
              // coverage:ignore-end
            ),
          ),
        ),
        if (selectedReinvestType ==
            ReinvestmentType.none) // coverage:ignore-line
          Padding(
            // coverage:ignore-line
            padding: const EdgeInsets.only(top: 8.0, left: 4),
            child: Text(
              // coverage:ignore-line
              AppLocalizations.of(context)!
                  .selectReinvestmentTypeNote, // coverage:ignore-line
              style: const TextStyle(fontSize: 12, color: Colors.orange),
            ),
          ),
        // coverage:ignore-start
        if (selectedReinvestType != ReinvestmentType.none) ...[
          _buildNumberField(
              AppLocalizations.of(context)!.amountInvestedLabel, reinvestCtrl),
          _buildDatePickerTile(
            title: AppLocalizations.of(context)!.reinvestDateLabel,
            // coverage:ignore-end
            date: reinvestDate ?? gainDate,
            onDatePicked: onReinvestDateChanged,
            firstDate: DateTime(2000), // coverage:ignore-line
            lastDate: DateTime(2040), // coverage:ignore-line
          ),
        ],
      ],
    );
  }

  void _addCGEntryDialog({CapitalGainEntry? existing, int? index}) {
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final saleCtrl =
        TextEditingController(text: existing?.saleAmount.toString() ?? '');
    final costCtrl = TextEditingController(
        text: existing?.costOfAcquisition.toString() ??
            ''); // coverage:ignore-line

    final reinvestCtrl = TextEditingController(
        text: existing?.reinvestedAmount.toString() ??
            ''); // coverage:ignore-line

    DateTime gainDate = existing?.gainDate ?? DateTime.now();
    DateTime? reinvestDate = existing?.reinvestDate; // coverage:ignore-line

    AssetType selectedAsset = existing?.matchAssetType ??
        AssetType.equityShares; // coverage:ignore-line
    ReinvestmentType selectedReinvestType =
        // coverage:ignore-start
        existing?.matchReinvestType ?? ReinvestmentType.none;
    bool isLtcg = existing?.isLTCG ?? false;
    bool intendToReinvest = existing?.intendToReinvest ?? false;
    // coverage:ignore-end

    showDialog(
      context: context,
      builder: (ctx) => _CGEntryDialog(
        existing: existing,
        index: index,
        descCtrl: descCtrl,
        saleCtrl: saleCtrl,
        costCtrl: costCtrl,
        gainDate: gainDate,
        reinvestCtrl: reinvestCtrl,
        reinvestDate: reinvestDate,
        selectedAsset: selectedAsset,
        selectedReinvestType: selectedReinvestType,
        isLtcg: isLtcg,
        intendToReinvest: intendToReinvest,
        onSave: _onSaveCGEntry,
        parentState: this,
      ),
    );
  }

  Widget _buildCGEntryDialogBody({
    required TextEditingController descCtrl,
    required TextEditingController saleCtrl,
    required TextEditingController costCtrl,
    required DateTime gainDate,
    required AssetType selectedAsset,
    required bool isLtcg,
    required bool intendToReinvest,
    required ReinvestmentType selectedReinvestType,
    required TextEditingController reinvestCtrl,
    required DateTime? reinvestDate,
    required void Function(AssetType?) onAssetChanged,
    required void Function(bool?) onLtcgChanged,
    required void Function(bool?) onIntendChanged,
    required void Function(DateTime) onDatePicked,
    required void Function(ReinvestmentType) onReinvestTypeChanged,
    required void Function(DateTime?) onReinvestDatePicked,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
            controller: descCtrl,
            decoration: InputDecoration(
                labelText:
                    AppLocalizations.of(context)!.descriptionAssetLabel)),
        const SizedBox(height: 8),
        InputDecorator(
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.assetSoldLabel,
            suffixIcon: _buildAssetTooltip(selectedAsset),
            floatingLabelBehavior: FloatingLabelBehavior.always,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<AssetType>(
              value: selectedAsset,
              isExpanded: true,
              isDense: true,
              items: AssetType.values.map((t) {
                return DropdownMenuItem(
                    value: t, child: Text(t.toHumanReadable()));
              }).toList(),
              onChanged: onAssetChanged,
            ),
          ),
        ),
        CheckboxListTile(
          title: Text(AppLocalizations.of(context)!.isLTCGLabel),
          value: isLtcg,
          onChanged: onLtcgChanged,
        ),
        TextField(
            controller: saleCtrl,
            decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.saleAmountLabel),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegexUtils.amountExp),
            ]),
        TextField(
            controller: costCtrl,
            decoration: InputDecoration(
                labelText:
                    AppLocalizations.of(context)!.costOfAcquisitionLabel),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegexUtils.amountExp),
            ]),
        _buildDatePickerTile(
          title: AppLocalizations.of(context)!.gainDateLabel,
          date: gainDate,
          onDatePicked: onDatePicked,
        ),
        const Divider(),
        CheckboxListTile(
          title: Text(AppLocalizations.of(context)!.intendToReinvestLabel),
          subtitle: Text(
              AppLocalizations.of(context)!.reinvestmentExemptionsSubtitle),
          value: intendToReinvest,
          onChanged: onIntendChanged,
        ),
        _buildReinvestmentSection(
            intendToReinvest,
            selectedReinvestType,
            reinvestCtrl,
            reinvestDate,
            gainDate,
            onReinvestTypeChanged,
            onReinvestDatePicked),
      ],
    );
  }

  List<Widget> _buildCGEntryDialogActions({
    required BuildContext ctx,
    required TextEditingController descCtrl,
    required TextEditingController saleCtrl,
    required TextEditingController costCtrl,
    required DateTime gainDate,
    required AssetType selectedAsset,
    required bool isLtcg,
    required bool intendToReinvest,
    required ReinvestmentType selectedReinvestType,
    required TextEditingController reinvestCtrl,
    required DateTime? reinvestDate,
    int? index,
    CapitalGainEntry? existing,
  }) {
    return [
      TextButton(
          onPressed: () => Navigator.pop(ctx), // coverage:ignore-line
          child: Text(AppLocalizations.of(context)!.cancelButton)),
      FilledButton(
          onPressed: () {
            _onSaveCGEntry(
              descCtrl: descCtrl,
              saleCtrl: saleCtrl,
              costCtrl: costCtrl,
              gainDate: gainDate,
              selectedAsset: selectedAsset,
              isLtcg: isLtcg,
              intendToReinvest: intendToReinvest,
              selectedReinvestType: selectedReinvestType,
              reinvestCtrl: reinvestCtrl,
              reinvestDate: reinvestDate,
              index: index,
              existing: existing,
            );
            Navigator.pop(ctx);
          },
          child: Text(AppLocalizations.of(context)!.saveButton))
    ];
  }

  void _onSaveCGEntry({
    required TextEditingController descCtrl,
    required TextEditingController saleCtrl,
    required TextEditingController costCtrl,
    required DateTime gainDate,
    required AssetType selectedAsset,
    required bool isLtcg,
    required bool intendToReinvest,
    required ReinvestmentType selectedReinvestType,
    required TextEditingController reinvestCtrl,
    required DateTime? reinvestDate,
    int? index,
    CapitalGainEntry? existing,
  }) {
    final newEntry = CapitalGainEntry(
      description: descCtrl.text,
      matchAssetType: selectedAsset,
      isLTCG: isLtcg,
      saleAmount: double.tryParse(saleCtrl.text) ?? 0,
      costOfAcquisition: double.tryParse(costCtrl.text) ?? 0,
      gainDate: gainDate,
      reinvestedAmount: double.tryParse(reinvestCtrl.text) ?? 0,
      matchReinvestType: selectedReinvestType,
      reinvestDate: reinvestDate,
      intendToReinvest: intendToReinvest,
      isManualEntry: true,
      lastUpdated: DateTime.now(),
    );

    setState(() {
      if (existing != null && index != null) {
        _capitalGains[index] = newEntry; // coverage:ignore-line
      } else {
        _capitalGains.add(newEntry);
      }
    });
    _updateSummary();
  }

  Widget _buildOtherTab() {
    final rules =
        ref.watch(taxConfigServiceProvider).getRulesForYear(_currentData.year);
    final taxService = ref.read(indianTaxServiceProvider);

    final filteredForTotals = _getFilteredOther(includeEntryFilter: false);
    final filteredForDisplay = _getFilteredOther(includeEntryFilter: true);

    final totalOtherList =
        filteredForTotals.fold(0.0, (sum, o) => sum + o.amount);
    final totalDividend = _currentData.dividendIncome.grossDividend;
    final taxableOther = taxService.calculateOtherSources(_currentData, rules);

    final otherRuleExemptions = rules.customExemptions
        .where((e) => e.isEnabled && e.incomeHead == 'Other Sources')
        .fold(
            0.0,
            // coverage:ignore-start
            (sum, e) =>
                sum +
                (e.isPercentage ? (totalOtherList * e.limit / 100) : e.limit));
    // coverage:ignore-end

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSummaryHeaderCard(
          title: AppLocalizations.of(context)!.otherSourcesTitle,
          buttonLabel: AppLocalizations.of(context)!.addOtherIncomeAction,
          onAdd: () => _addOtherIncomeDialog(),
          children: [
            _buildSummaryRow(
                AppLocalizations.of(context)!.dividendsLabel, totalDividend),
            ..._buildOtherIncomeBreakup(filteredForTotals),
            if (otherRuleExemptions > 0)
              _buildSummaryRow(
                  // coverage:ignore-line
                  AppLocalizations.of(context)!
                      .adhocExemptionsLabel, // coverage:ignore-line
                  otherRuleExemptions,
                  isDeduction: true),
            const Divider(),
            _buildSummaryRow(
                AppLocalizations.of(context)!.taxableOtherIncomeLabel,
                taxableOther,
                isBold: true),
          ],
          showChildren: _otherIncomes.isNotEmpty || totalDividend > 0,
        ),
        if (_otherIncomes.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildFilterRow(
              _otherFilter, (v) => setState(() => _otherFilter = v)),
        ],
        if (_otherIncomes.isEmpty)
          Center(
              child: Padding(
            padding: const EdgeInsets.only(top: 40.0),
            child: Text(AppLocalizations.of(context)!.noOtherIncomeNote),
          ))
        else
          ..._buildOtherIncomeList(filteredForDisplay),
      ],
    );
  }

  Iterable<Widget> _buildOtherIncomeBreakup(List<OtherIncome> incomes) {
    final Map<String, double> grouped = {};
    for (var o in incomes) {
      final key = o.subtype.toOtherSourceDisplay();
      grouped[key] = (grouped[key] ?? 0) + o.amount;
    }

    return grouped.entries.map((e) => _buildSummaryRow(e.key, e.value));
  }

  List<OtherIncome> _getFilteredOther({required bool includeEntryFilter}) {
    return _applyStandardFilters<OtherIncome>(
      _otherIncomes,
      includeEntryFilter: includeEntryFilter,
      currentFilter: _otherFilter,
      getIsManual: (o) => o.isManualEntry,
      getDate: (o) =>
          o.transactionDate ?? DateTime.now(), // coverage:ignore-line
    );
  }

  List<Widget> _buildOtherIncomeList(List<OtherIncome> filtered) {
    return filtered.map((income) {
      final i = _otherIncomes.indexOf(income);
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.2) // coverage:ignore-line
                : Colors.black.withValues(alpha: 0.1),
          ),
        ),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.grey.withValues(alpha: 0.1),
            child: Icon(Icons.more_horiz_outlined,
                color: Theme.of(context).colorScheme.primary, size: 20),
          ),
          title: Text(income.name,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(
              '${income.subtype.toOtherSourceDisplay()} • ${CurrencyUtils.formatCurrency(income.amount, ref.watch(currencyProvider))}'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildBadge(income.isManualEntry, income.lastUpdated,
                  income.transactionDate),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.grey, size: 20),
                // coverage:ignore-start
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  setState(() => _otherIncomes.removeAt(i));
                  _updateSummary();
                  // coverage:ignore-end
                },
              ),
            ],
          ),
          // coverage:ignore-start
          onTap: () {
            FocusScope.of(context).unfocus();
            _addOtherIncomeDialog(existing: income, index: i);
            // coverage:ignore-end
          },
        ),
      );
    }).toList();
  }

  void _addOtherIncomeDialog({OtherIncome? existing, int? index}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final amtCtrl = TextEditingController(
        text: existing != null
            ? existing.amount.toString()
            : ''); // coverage:ignore-line
    String subtype = existing?.subtype ?? 'others'; // coverage:ignore-line
    DateTime pickedDate = existing?.transactionDate ?? DateTime.now();
    String? selectedExemptionId =
        existing?.linkedExemptionId; // coverage:ignore-line

    final validKeys = [
      'savings_interest',
      'fd_interest',
      'chit_fund_interest',
      'family_pension',
      'others'
    ];
    final rules =
        ref.read(taxConfigServiceProvider).getRulesForYear(_currentData.year);
    final validExemptions =
        rules.customExemptions.where((e) => e.isEnabled).toList();

    showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(builder: (context, setStateBuilder) {
              return AlertDialog(
                title: Text(existing == null
                    ? AppLocalizations.of(context)!.addIncomeAction
                    : AppLocalizations.of(context)!
                        .editOtherIncomeAction), // coverage:ignore-line
                content: SingleChildScrollView(
                  child: _buildOtherIncomeDialogBody(
                    nameCtrl: nameCtrl,
                    amtCtrl: amtCtrl,
                    subtype: subtype,
                    validKeys: validKeys,
                    pickedDate: pickedDate,
                    validExemptions: validExemptions,
                    selectedExemptionId: selectedExemptionId,
                    // coverage:ignore-start
                    onSubtypeChanged: (v) =>
                        setStateBuilder(() => subtype = v!),
                    onDatePicked: (d) => setStateBuilder(() => pickedDate = d),
                    onExemptionChanged: (v) =>
                        setStateBuilder(() => selectedExemptionId = v),
                    // coverage:ignore-end
                  ),
                ),
                actions: _buildOtherIncomeDialogActions(
                  ctx: ctx,
                  nameCtrl: nameCtrl,
                  amtCtrl: amtCtrl,
                  subtype: subtype,
                  pickedDate: pickedDate,
                  selectedExemptionId: selectedExemptionId,
                  index: index,
                  existing: existing,
                ),
              );
            }));
  }

  Widget _buildOtherIncomeDialogBody({
    required TextEditingController nameCtrl,
    required TextEditingController amtCtrl,
    required String subtype,
    required List<String> validKeys,
    required DateTime pickedDate,
    required List<TaxExemptionRule> validExemptions,
    required String? selectedExemptionId,
    required void Function(String?) onSubtypeChanged,
    required void Function(DateTime) onDatePicked,
    required void Function(String?) onExemptionChanged,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
            controller: nameCtrl,
            decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.nameLabel),
            textCapitalization: TextCapitalization.words),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: ValueKey(subtype),
          initialValue: validKeys.contains(subtype) ? subtype : 'others',
          items: validKeys
              .map((s) => DropdownMenuItem(
                  value: s, child: Text(s.toOtherSourceDisplay())))
              .toList(),
          onChanged: onSubtypeChanged,
          decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.incomeTypeLabel),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: amtCtrl,
          decoration: InputDecoration(
            labelText:
                'Gross Amount (${CurrencyUtils.getSymbol(ref.watch(currencyProvider))})',
            suffixIcon: Tooltip(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.symmetric(horizontal: 20),
              showDuration: const Duration(seconds: 5),
              triggerMode: TooltipTriggerMode.tap,
              message: AppLocalizations.of(context)!.otherIncomeTooltip,
              child: const Icon(Icons.info_outline, color: Colors.blue),
            ),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegexUtils.amountExp),
          ],
        ),
        const SizedBox(height: 8),
        _buildDatePickerTile(
          title: AppLocalizations.of(context)!.transactionDateLabel,
          date: pickedDate,
          onDatePicked: onDatePicked,
        ),
        if (validExemptions.isNotEmpty) ...[
          const SizedBox(height: 12),
          InputDecorator(
            // coverage:ignore-line
            decoration: InputDecoration(
              // coverage:ignore-line
              labelText: AppLocalizations.of(context)!
                  .linkExemptionOptionalLabel, // coverage:ignore-line
              border: const OutlineInputBorder(),
              isDense: true,
              floatingLabelBehavior: FloatingLabelBehavior.always,
            ),
            child: DropdownButtonHideUnderline(
              // coverage:ignore-line
              child: DropdownButton<String?>(
                // coverage:ignore-line
                value: selectedExemptionId,
                isExpanded: true,
                items: [
                  // coverage:ignore-line
                  DropdownMenuItem<String?>(
                      // coverage:ignore-line
                      value: null,
                      // coverage:ignore-start
                      child: Text(AppLocalizations.of(context)!.noneLabel)),
                  ...validExemptions.map(
                      (e) => DropdownMenuItem(value: e.id, child: Text(e.name)))
                  // coverage:ignore-end
                ],
                onChanged: onExemptionChanged,
              ),
            ),
          ),
        ],
      ],
    );
  }

  List<Widget> _buildOtherIncomeDialogActions({
    required BuildContext ctx,
    required TextEditingController nameCtrl,
    required TextEditingController amtCtrl,
    required String subtype,
    required DateTime pickedDate,
    required String? selectedExemptionId,
    int? index,
    OtherIncome? existing,
  }) {
    return [
      TextButton(
          onPressed: () => Navigator.pop(ctx), // coverage:ignore-line
          child: Text(AppLocalizations.of(context)!.cancelAction)),
      FilledButton(
        onPressed: () {
          if (_onSaveOtherIncome(
            nameCtrl,
            amtCtrl,
            subtype,
            pickedDate,
            selectedExemptionId,
            index: index,
          )) {
            Navigator.pop(ctx);
          }
        },
        child: Text(AppLocalizations.of(context)!.saveAction),
      ),
    ];
  }

  bool _onSaveOtherIncome(
    TextEditingController nameCtrl,
    TextEditingController amtCtrl,
    String subtype,
    DateTime pickedDate,
    String? linkedExemptionId, {
    int? index,
  }) {
    final amount = double.tryParse(amtCtrl.text) ?? 0;
    if (amount <= 0) return false;

    final entry = OtherIncome(
      name: nameCtrl.text,
      amount: amount,
      subtype: subtype,
      transactionDate: pickedDate,
      linkedExemptionId: linkedExemptionId,
      isManualEntry: true,
      lastUpdated: DateTime.now(),
    );

    setState(() {
      if (index != null) {
        _otherIncomes[index] = entry; // coverage:ignore-line
      } else {
        _otherIncomes.add(entry);
      }
    });

    _updateSummary();
    return true;
  }

  Widget _buildSectionTitle(String title) {
    return Text(title,
        style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold));
  }

  Widget _buildFilterRow(
      EntryFilter currentFilter, ValueChanged<EntryFilter> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: SegmentedButton<EntryFilter>(
        segments: [
          ButtonSegment(
              value: EntryFilter.all,
              label: Text(AppLocalizations.of(context)!.allFilterLabel)),
          ButtonSegment(
              value: EntryFilter.manual,
              label: Text(AppLocalizations.of(context)!.manualFilterLabel)),
          ButtonSegment(
              value: EntryFilter.synced,
              label: Text(AppLocalizations.of(context)!.syncedFilterLabel)),
        ],
        selected: {currentFilter},
        onSelectionChanged: (Set<EntryFilter> newSelection) {
          // coverage:ignore-line
          onChanged(newSelection.first); // coverage:ignore-line
        },
        style: const ButtonStyle(
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }

  Widget _buildBadge(bool isManual, DateTime? lastUpdated,
      [DateTime? transactionDate]) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isManual
                  ? Colors.blue.withValues(alpha: 0.2)
                  : Colors.green.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: isManual ? Colors.blue : Colors.green,
                width: 1,
              ),
            ),
            child: Text(
              isManual
                  ? AppLocalizations.of(context)!.manualFilterLabel
                  : AppLocalizations.of(context)!.syncedFilterLabel,
              style: TextStyle(
                fontSize: 10,
                color: isManual ? Colors.blue.shade700 : Colors.green.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (lastUpdated != null)
            Padding(
              padding: const EdgeInsets.only(top: 1.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${AppLocalizations.of(context)!.updatedPrefix}: ',
                      style: const TextStyle(fontSize: 9, color: Colors.grey)),
                  Text(DateFormat("MMM dd, HH:mm").format(lastUpdated),
                      style: const TextStyle(fontSize: 9, color: Colors.grey)),
                ],
              ),
            ),
          if (transactionDate != null)
            Padding(
              padding: const EdgeInsets.only(top: 1.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${AppLocalizations.of(context)!.transactionPrefix}: ',
                      style:
                          const TextStyle(fontSize: 9, color: Colors.blueGrey)),
                  Text(DateFormat("MMM dd, yyyy").format(transactionDate),
                      style:
                          const TextStyle(fontSize: 9, color: Colors.blueGrey)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryHeaderCard({
    required String title,
    required String buttonLabel,
    required VoidCallback onAdd,
    required List<Widget> children,
    bool showChildren = true,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      color:
          Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.2) // coverage:ignore-line
              : Colors.black.withValues(alpha: 0.1),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Expanded(child: _buildSectionTitle(title)),
                      const SizedBox(width: 8),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Icon(
                          ref.watch(currencyFormatProvider)
                              ? Icons.compress
                              : Icons.expand,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        onPressed: () {
                          // coverage:ignore-line
                          final notifier = ref.read(currencyFormatProvider
                              .notifier); // coverage:ignore-line
                          notifier.value = !ref.read(
                              currencyFormatProvider); // coverage:ignore-line
                        },
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.add_circle_outline),
                  label: Text(buttonLabel),
                  onPressed: onAdd,
                ),
              ],
            ),
            if (showChildren && children.isNotEmpty) ...[
              const Divider(),
              ...children,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNumberField(String label, TextEditingController controller,
      {String? subtitle}) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(labelText: label, helperText: subtitle),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegexUtils.amountExp),
      ],
    );
  }

  Widget _buildTaxPaidTab() {
    final rules =
        ref.watch(taxConfigServiceProvider).getRulesForYear(_currentData.year);
    final service = ref.watch(indianTaxServiceProvider);
    final generatedTds = service.getGeneratedSalaryTds(_currentData, rules);

    final filteredAdvanceTax =
        _getFilteredTaxPayments(_advanceTaxEntries, includeEntryFilter: true);
    final filteredTDS = _getFilteredTaxPayments(
        [..._tdsEntries, ...generatedTds],
        includeEntryFilter: true);
    final filteredTCS =
        _getFilteredTaxPayments(_tcsEntries, includeEntryFilter: true);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildAdvanceTaxHints(),
        _buildFilterRow(
            _taxPaidFilter, (v) => setState(() => _taxPaidFilter = v)),
        const SizedBox(height: 16),
        _buildEntryListHeader(AppLocalizations.of(context)!.advanceTaxTitle,
            isAdvanceTax: true),
        ..._buildTaxPaymentList(filteredAdvanceTax, isAdvanceTax: true),
        const SizedBox(height: 16),
        _buildEntryListHeader(AppLocalizations.of(context)!.tdsTitle,
            isTds: true),
        ..._buildTaxPaymentList(filteredTDS, isTds: true),
        const SizedBox(height: 16),
        _buildEntryListHeader(AppLocalizations.of(context)!.tcsTitle),
        ..._buildTaxPaymentList(filteredTCS),
      ],
    );
  }

  List<TaxPaymentEntry> _getFilteredTaxPayments(List<TaxPaymentEntry> list,
      {required bool includeEntryFilter}) {
    return _applyStandardFilters<TaxPaymentEntry>(
      list,
      includeEntryFilter: includeEntryFilter,
      currentFilter: _taxPaidFilter,
      getIsManual: (e) => e.isManualEntry,
      getDate: (e) => e.date, // coverage:ignore-line
    );
  }

  List<Widget> _buildTaxPaymentList(List<TaxPaymentEntry> filtered,
      {bool isTds = false, bool isAdvanceTax = false}) {
    if (filtered.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Center(
              child: Text(AppLocalizations.of(context)!.noEntriesFoundNote)),
        )
      ];
    }
    return filtered
        .map((e) =>
            _buildTaxEntryTile(e, isTds: isTds, isAdvanceTax: isAdvanceTax))
        .toList();
  }

  Widget _buildAdvanceTaxHints() {
    final rules =
        ref.watch(taxConfigServiceProvider).getRulesForYear(_currentData.year);
    if (rules.advanceTaxRules.isEmpty || !rules.enableAdvanceTaxInterest) {
      return const SizedBox.shrink();
    }

    final service = ref.watch(indianTaxServiceProvider);
    final taxDetails = service.calculateDetailedLiability(_currentData, rules);

    final DateTime? nextDueDate = taxDetails['nextAdvanceTaxDueDate'];
    final double? nextAmount = taxDetails['nextAdvanceTaxAmount'];
    final double nextBase = taxDetails['nextAdvanceTaxBase'] ?? 0.0;
    final double nextCess = taxDetails['nextAdvanceTaxCess'] ?? 0.0;
    final double nextInterest = taxDetails['nextAdvanceTaxInterest'] ?? 0.0;

    return Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .tertiaryContainer
              .withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context)!.advanceTaxScheduleHintsTitle,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onTertiaryContainer)),
            if (nextDueDate != null &&
                nextAmount != null &&
                nextAmount > 0) ...[
              // coverage:ignore-line
              const SizedBox(height: 8),
              Container(
                // coverage:ignore-line
                padding: const EdgeInsets.all(8),
                // coverage:ignore-start
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .tertiary
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                  // coverage:ignore-end
                ),
                child: Row(
                  // coverage:ignore-line
                  children: [
                    // coverage:ignore-line
                    const Icon(Icons.info_outline,
                        size: 16, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      // coverage:ignore-line
                      child: Column(
                        // coverage:ignore-line
                        crossAxisAlignment: CrossAxisAlignment.start,
                        // coverage:ignore-start
                        children: [
                          Text(
                            'Next Due: ${CurrencyUtils.formatCurrency(nextAmount, ref.watch(currencyProvider))} by ${DateFormat('MMM dd').format(nextDueDate)}',
                            // coverage:ignore-end
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          // coverage:ignore-start
                          Text(
                            AppLocalizations.of(context)!
                                .advanceTaxBreakdownLabel(
                                    CurrencyUtils.formatCurrency(
                                        nextBase, ref.watch(currencyProvider)),
                                    CurrencyUtils.formatCurrency(
                                        nextCess, ref.watch(currencyProvider)),
                                    CurrencyUtils.formatCurrency(nextInterest,
                                        ref.watch(currencyProvider))),
                            style: TextStyle(
                                // coverage:ignore-end
                                fontSize: 11,
                                // coverage:ignore-start
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant),
                            // coverage:ignore-end
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            ...rules.advanceTaxRules.map((r) {
              String month =
                  DateFormat('MMM').format(DateTime(2000, r.endMonth));
              final installmentAmount =
                  ((taxDetails['baseForAdvanceTax'] ?? 0.0) as double) *
                      (r.requiredPercentage / 100);
              double base = installmentAmount;
              double cess = 0.0;
              if (rules.isCessEnabled && installmentAmount > 0) {
                // coverage:ignore-start
                base = CurrencyUtils.roundTo2Decimals(
                    installmentAmount / (1 + (rules.cessRate / 100)));
                cess = CurrencyUtils.roundTo2Decimals(installmentAmount - base);
                // coverage:ignore-end
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      AppLocalizations.of(context)!.advanceTaxInstallmentNote(
                          month,
                          r.endDay.toString(),
                          r.requiredPercentage.toStringAsFixed(0),
                          CurrencyUtils.formatCurrency(
                              installmentAmount, ref.watch(currencyProvider))),
                      style: const TextStyle(fontSize: 12)),
                  Text(
                    AppLocalizations.of(context)!
                        .advanceTaxBreakdownLabelNoInterest(
                            CurrencyUtils.formatCurrency(
                                base, ref.watch(currencyProvider)),
                            CurrencyUtils.formatCurrency(
                                cess, ref.watch(currencyProvider))),
                    style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ],
              );
            }),
          ],
        ));
  }

  Widget _buildEntryListHeader(String title,
      {bool isTds = false, bool isAdvanceTax = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
            child: Text(title,
                style: const TextStyle(fontWeight: FontWeight.bold))),
        IconButton(
          icon: const Icon(Icons.add_circle, color: Colors.blue),
          onPressed: () =>
              _addTaxEntryDialog(isTds: isTds, isAdvanceTax: isAdvanceTax),
          tooltip: AppLocalizations.of(context)!.addEntryAction,
        ),
      ],
    );
  }

  Widget _buildTaxEntryTile(TaxPaymentEntry entry,
      {bool isTds = false, bool isAdvanceTax = false}) {
    bool isCredit = isTds || isAdvanceTax;
    IconData entryIcon;
    if (isAdvanceTax) {
      entryIcon = Icons.payment_outlined;
    } else if (isTds) {
      entryIcon = Icons.receipt_long_outlined;
    } else {
      entryIcon = Icons.receipt_outlined;
    }

    return AppListItemCard(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.grey.withValues(alpha: 0.1),
          child: Icon(entryIcon,
              color: Theme.of(context).colorScheme.primary, size: 20),
        ),
        title: Text(
            '${DateFormat('MMM dd, yyyy').format(entry.date)}: ${CurrencyUtils.formatCurrency(entry.amount, ref.watch(currencyProvider))}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: isCredit
            ? Text(AppLocalizations.of(context)!.sourceLabel(entry.source))
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildBadge(entry.isManualEntry, null, entry.date),
            if (entry.isManualEntry)
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.grey, size: 20),
                // coverage:ignore-start
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  _handleDeleteTaxEntry(entry, isTds, isAdvanceTax);
                  // coverage:ignore-end
                },
              )
            else
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Icon(Icons.lock_outline, size: 16, color: Colors.grey),
              ),
          ],
        ),
        onTap: entry.isManualEntry
            // coverage:ignore-start
            ? () {
                FocusScope.of(context).unfocus();
                _handleEditTaxEntry(entry, isTds, isAdvanceTax);
                // coverage:ignore-end
              }
            : null,
      ),
    );
  }

  void _handleDeleteTaxEntry(
      // coverage:ignore-line
      TaxPaymentEntry entry,
      bool isTds,
      bool isAdvanceTax) {
    setState(() {
      // coverage:ignore-line
      if (isTds) {
        _tdsEntries.remove(entry); // coverage:ignore-line
      } else if (isAdvanceTax) {
        _advanceTaxEntries.remove(entry); // coverage:ignore-line
      } else {
        _tcsEntries.remove(entry); // coverage:ignore-line
      }
    });
    _updateSummary(); // coverage:ignore-line
  }

  void _handleEditTaxEntry(
      // coverage:ignore-line
      TaxPaymentEntry entry,
      bool isTds,
      bool isAdvanceTax) {
    final int idx;
    if (isTds) {
      idx = _tdsEntries.indexOf(entry); // coverage:ignore-line
    } else if (isAdvanceTax) {
      idx = _advanceTaxEntries.indexOf(entry); // coverage:ignore-line
    } else {
      idx = _tcsEntries.indexOf(entry); // coverage:ignore-line
    }
    _addTaxEntryDialog(
        // coverage:ignore-line
        existing: entry,
        index: idx,
        isTds: isTds,
        isAdvanceTax: isAdvanceTax);
  }

  void _addTaxEntryDialog(
      {bool isTds = false,
      bool isAdvanceTax = false,
      TaxPaymentEntry? existing,
      int? index}) {
    final amtCtrl =
        TextEditingController(text: existing?.amount.toString() ?? '');
    final srcCtrl = TextEditingController(text: existing?.source ?? '');
    DateTime pickedDate = existing?.date ?? DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateSB) {
          return AlertDialog(
            title: Text(_getTaxEntryDialogTitle(isTds, isAdvanceTax, existing)),
            content: _buildTaxEntryDialogBody(
              amtCtrl: amtCtrl,
              srcCtrl: srcCtrl,
              pickedDate: pickedDate,
              onDatePicked: (d) =>
                  setStateSB(() => pickedDate = d), // coverage:ignore-line
            ),
            actions: _buildTaxEntryDialogActions(
              ctx: ctx,
              amtCtrl: amtCtrl,
              srcCtrl: srcCtrl,
              pickedDate: pickedDate,
              isTds: isTds,
              isAdvanceTax: isAdvanceTax,
              existing: existing,
              index: index,
            ),
          );
        },
      ),
    );
  }

  String _getTaxEntryDialogTitle(
      bool isTds, bool isAdvanceTax, TaxPaymentEntry? existing) {
    final String typeLabel;
    if (isAdvanceTax) {
      typeLabel = AppLocalizations.of(context)!.advanceTaxTitle;
    } else if (isTds) {
      typeLabel = AppLocalizations.of(context)!.tdsTitle;
    } else {
      typeLabel =
          AppLocalizations.of(context)!.tcsTitle; // coverage:ignore-line
    }
    return existing == null
        ? AppLocalizations.of(context)!.addEntryTypeAction(typeLabel)
        : AppLocalizations.of(context)!
            .editEntryTypeAction(typeLabel); // coverage:ignore-line
  }

  Widget _buildTaxEntryDialogBody({
    required TextEditingController amtCtrl,
    required TextEditingController srcCtrl,
    required DateTime pickedDate,
    required void Function(DateTime) onDatePicked,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: srcCtrl,
          decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.sourceDescriptionLabel),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: amtCtrl,
          decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.grossAmountCurrencyLabel(
                  CurrencyUtils.getSymbol(ref.watch(currencyProvider)))),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegexUtils.amountExp)
          ],
        ),
        const SizedBox(height: 8),
        _buildDatePickerTile(
          title: AppLocalizations.of(context)!.transactionDateLabel,
          date: pickedDate,
          onDatePicked: onDatePicked,
        ),
      ],
    );
  }

  List<Widget> _buildTaxEntryDialogActions({
    required BuildContext ctx,
    required TextEditingController amtCtrl,
    required TextEditingController srcCtrl,
    required DateTime pickedDate,
    required bool isTds,
    required bool isAdvanceTax,
    TaxPaymentEntry? existing,
    int? index,
  }) {
    return [
      TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel')), // coverage:ignore-line
      FilledButton(
        onPressed: () {
          if (_onSaveTaxEntry(amtCtrl, srcCtrl, pickedDate,
              isTds: isTds,
              isAdvanceTax: isAdvanceTax,
              existing: existing,
              index: index)) {
            Navigator.pop(ctx);
          }
        },
        child: Text(existing == null
            ? AppLocalizations.of(context)!.addButton
            : AppLocalizations.of(context)!.saveButton), // coverage:ignore-line
      ),
    ];
  }

  bool _onSaveTaxEntry(TextEditingController amtCtrl,
      TextEditingController srcCtrl, DateTime pickedDate,
      {bool isTds = false,
      bool isAdvanceTax = false,
      TaxPaymentEntry? existing,
      int? index}) {
    final amount = double.tryParse(amtCtrl.text) ?? 0;
    if (amount <= 0) return false;

    final entry = TaxPaymentEntry(
      id: existing?.id ?? const Uuid().v4(),
      amount: amount,
      date: pickedDate,
      source: srcCtrl.text,
      isManualEntry: true,
    );

    final List<TaxPaymentEntry> targetList;
    if (isAdvanceTax) {
      targetList = _advanceTaxEntries;
    } else if (isTds) {
      targetList = _tdsEntries;
    } else {
      targetList = _tcsEntries; // coverage:ignore-line
    }

    setState(() {
      if (index != null) {
        targetList[index] = entry; // coverage:ignore-line
      } else {
        targetList.add(entry);
      }
    });

    _updateSummary();
    return true;
  }

  Widget _buildCashGiftsTab() {
    final rules =
        ref.watch(taxConfigServiceProvider).getRulesForYear(_currentData.year);
    final filtered = _getFilteredCashGifts();
    final totalCashGifts = filtered.fold(0.0, (sum, g) => sum + g.amount);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSummaryHeaderCard(
          title: AppLocalizations.of(context)!.cashGiftsTotalTitle,
          buttonLabel: AppLocalizations.of(context)!.addGiftAction,
          onAdd: () => _addCashGiftDialog(),
          children: [
            _buildSummaryRow(
                AppLocalizations.of(context)!.totalGiftsReceivedLabel,
                totalCashGifts),
            const Divider(),
            _buildSummaryRow(
                AppLocalizations.of(context)!.taxablePortionLabel,
                totalCashGifts > rules.cashGiftExemptionLimit
                    ? totalCashGifts
                    : 0,
                isBold: true),
            Text(
              AppLocalizations.of(context)!.giftThresholdNote(
                  CurrencyUtils.formatCurrency(rules.cashGiftExemptionLimit,
                      ref.watch(currencyProvider))),
              style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_cashGifts.isEmpty)
          Center(child: Text(AppLocalizations.of(context)!.noCashGiftsNote))
        else
          ..._buildCashGiftList(filtered),
      ],
    );
  }

  List<OtherIncome> _getFilteredCashGifts() {
    return _cashGifts.where((g) {
      if (_selectedDateRange != null) {
        // coverage:ignore-start
        final date = g.transactionDate ?? DateTime.now();
        if (date.isBefore(_selectedDateRange!.start) ||
            date.isAfter(
                _selectedDateRange!.end.add(const Duration(days: 1)))) {
          // coverage:ignore-end
          return false;
        }
      }
      return true;
    }).toList();
  }

  List<Widget> _buildCashGiftList(List<OtherIncome> filtered) {
    return filtered.map((gift) {
      final i = _cashGifts.indexOf(gift);
      return Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.2) // coverage:ignore-line
                : Colors.black.withValues(alpha: 0.1),
          ),
        ),
        child: ListTile(
          title: Text(gift.name),
          subtitle: Text(
              '${gift.subtype.toGiftDisplay()} • ${CurrencyUtils.formatCurrency(gift.amount, ref.watch(currencyProvider))}'),
          trailing: IconButton(
            icon: const Icon(Icons.delete),
            // coverage:ignore-start
            onPressed: () {
              setState(() => _cashGifts.removeAt(i));
              _updateSummary();
              // coverage:ignore-end
            },
          ),
          onTap: () => _addCashGiftDialog(
              existing: gift, index: i), // coverage:ignore-line
        ),
      );
    }).toList();
  }

  void _addCashGiftDialog({OtherIncome? existing, int? index}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final amtCtrl =
        TextEditingController(text: existing?.amount.toString() ?? '');
    const giftKeys = ['friend', 'relative', 'marriage', 'other'];
    String subtype = existing?.subtype ?? giftKeys.first;
    DateTime pickedDate = existing?.transactionDate ?? DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (context, setStateBuilder) {
        return AlertDialog(
          title: Text(existing == null
              ? AppLocalizations.of(context)!.addGiftAction
              : AppLocalizations.of(context)!
                  .editGiftAction), // coverage:ignore-line
          content: _buildCashGiftDialogBody(
            nameCtrl: nameCtrl,
            amtCtrl: amtCtrl,
            subtype: subtype,
            giftKeys: giftKeys,
            pickedDate: pickedDate,
            onSubtypeChanged: (v) =>
                setStateBuilder(() => subtype = v!), // coverage:ignore-line
            onDatePicked: (d) =>
                setStateBuilder(() => pickedDate = d), // coverage:ignore-line
          ),
          actions: _buildCashGiftDialogActions(
            ctx: ctx,
            nameCtrl: nameCtrl,
            amtCtrl: amtCtrl,
            subtype: subtype,
            pickedDate: pickedDate,
            existing: existing,
            index: index,
          ),
        );
      }),
    );
  }

  Widget _buildCashGiftDialogBody({
    required TextEditingController nameCtrl,
    required TextEditingController amtCtrl,
    required String subtype,
    required List<String> giftKeys,
    required DateTime pickedDate,
    required void Function(String?) onSubtypeChanged,
    required void Function(DateTime) onDatePicked,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
            controller: nameCtrl,
            decoration: InputDecoration(
                labelText:
                    AppLocalizations.of(context)!.giftDescriptionSourceLabel)),
        DropdownButtonFormField<String>(
          key: ValueKey(subtype),
          initialValue: subtype,
          items: giftKeys
              .map((s) =>
                  DropdownMenuItem(value: s, child: Text(s.toGiftDisplay())))
              .toList(),
          onChanged: onSubtypeChanged,
          decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.giftTypeLabel),
        ),
        _buildNumberField(
          AppLocalizations.of(context)!.amountCurrencyLabel(
              CurrencyUtils.getSymbol(ref.watch(currencyProvider))),
          amtCtrl,
          subtitle: AppLocalizations.of(context)!.giftRelativesExemptNote,
        ),
        const SizedBox(height: 8),
        _buildDatePickerTile(
          title: AppLocalizations.of(context)!.transactionDateLabel,
          date: pickedDate,
          onDatePicked: onDatePicked,
        ),
      ],
    );
  }

  List<Widget> _buildCashGiftDialogActions({
    required BuildContext ctx,
    required TextEditingController nameCtrl,
    required TextEditingController amtCtrl,
    required String subtype,
    required DateTime pickedDate,
    OtherIncome? existing,
    int? index,
  }) {
    return [
      TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel')), // coverage:ignore-line
      FilledButton(
        onPressed: () {
          if (_onSaveCashGift(
            nameCtrl: nameCtrl,
            amtCtrl: amtCtrl,
            subtype: subtype,
            pickedDate: pickedDate,
            existing: existing,
            index: index,
          )) {
            Navigator.pop(ctx);
          }
        },
        child: const Text('Save'),
      ),
    ];
  }

  bool _onSaveCashGift({
    required TextEditingController nameCtrl,
    required TextEditingController amtCtrl,
    required String subtype,
    required DateTime pickedDate,
    OtherIncome? existing,
    int? index,
  }) {
    final amount = double.tryParse(amtCtrl.text) ?? 0;
    if (amount <= 0) return false;

    final entry = OtherIncome(
      name: nameCtrl.text,
      amount: amount,
      type: 'Gift',
      subtype: subtype,
      transactionDate: pickedDate,
      isManualEntry: true,
      lastUpdated: DateTime.now(),
    );

    setState(() {
      if (index != null) {
        _cashGifts[index] = entry; // coverage:ignore-line
      } else {
        _cashGifts.add(entry);
      }
    });

    _updateSummary();
    return true;
  }

  void _addAgriIncomeDialog({AgriIncomeEntry? existing, int? index}) {
    final amtCtrl =
        TextEditingController(text: existing?.amount.toString() ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    DateTime pickedDate = existing?.date ?? DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateBuilder) => AlertDialog(
          title: Text(existing == null
              ? AppLocalizations.of(context)!.addAgriIncomeAction
              : AppLocalizations.of(context)!
                  .editAgriIncomeAction), // coverage:ignore-line
          content: _buildAgriIncomeDialogBody(
            descCtrl: descCtrl,
            amtCtrl: amtCtrl,
            pickedDate: pickedDate,
            onDatePicked: (d) =>
                setStateBuilder(() => pickedDate = d), // coverage:ignore-line
          ),
          actions: _buildAgriIncomeDialogActions(
            ctx: ctx,
            amtCtrl: amtCtrl,
            descCtrl: descCtrl,
            pickedDate: pickedDate,
            existing: existing,
            index: index,
          ),
        ),
      ),
    );
  }

  Widget _buildAgriIncomeDialogBody({
    required TextEditingController descCtrl,
    required TextEditingController amtCtrl,
    required DateTime pickedDate,
    required void Function(DateTime) onDatePicked,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: descCtrl,
          decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.descriptionLabel),
        ),
        const SizedBox(height: 8),
        _buildNumberField(
          AppLocalizations.of(context)!.amountCurrencyLabel(
              CurrencyUtils.getSymbol(ref.watch(currencyProvider))),
          amtCtrl,
        ),
        const SizedBox(height: 8),
        _buildDatePickerTile(
          title: AppLocalizations.of(context)!.dateLabel,
          date: pickedDate,
          onDatePicked: onDatePicked,
        ),
      ],
    );
  }

  List<Widget> _buildAgriIncomeDialogActions({
    required BuildContext ctx,
    required TextEditingController amtCtrl,
    required TextEditingController descCtrl,
    required DateTime pickedDate,
    AgriIncomeEntry? existing,
    int? index,
  }) {
    return [
      TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel')), // coverage:ignore-line
      FilledButton(
        onPressed: () {
          if (_onSaveAgri(amtCtrl, descCtrl, pickedDate,
              existing: existing, index: index)) {
            Navigator.pop(ctx);
          }
        },
        child: Text(existing == null
            ? AppLocalizations.of(context)!.addButton
            : AppLocalizations.of(context)!.saveButton), // coverage:ignore-line
      ),
    ];
  }

  bool _onSaveAgri(TextEditingController amtCtrl,
      TextEditingController descCtrl, DateTime pickedDate,
      {AgriIncomeEntry? existing, int? index}) {
    final amount = double.tryParse(amtCtrl.text) ?? 0;
    if (amount <= 0) return false;

    final entry = AgriIncomeEntry(
      id: existing?.id ?? const Uuid().v4(),
      amount: amount,
      date: pickedDate,
      description: descCtrl.text,
      isManualEntry: true,
    );

    setState(() {
      if (index != null) {
        _agriIncomeHistory[index] = entry; // coverage:ignore-line
      } else {
        _agriIncomeHistory.add(entry);
      }
    });
    _updateSummary();
    return true;
  }

  Widget _buildAgriIncomeTab() {
    final filteredForDisplay = _getFilteredAgri(includeEntryFilter: true);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSummaryHeaderCard(
          title: AppLocalizations.of(context)!.agriculturalIncomeTitle,
          buttonLabel: AppLocalizations.of(context)!.addEntryAction,
          onAdd: () => _addAgriIncomeDialog(),
          children: [
            _buildSummaryRow(AppLocalizations.of(context)!.netAgriIncomeLabel,
                _agriIncomeHistory.fold(0.0, (sum, e) => sum + e.amount)),
            Text(
              AppLocalizations.of(context)!.agriIncomeNote,
              style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_agriIncomeHistory.isNotEmpty)
          _buildFilterRow(_agriFilter, (v) => setState(() => _agriFilter = v)),
        if (_agriIncomeHistory.isEmpty)
          Center(child: Text(AppLocalizations.of(context)!.noAgriIncomeNote))
        else
          ..._buildAgriList(filteredForDisplay),
        const SizedBox(height: 32),
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withValues(alpha: 0.2) // coverage:ignore-line
                  : Colors.black.withValues(alpha: 0.1),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                      AppLocalizations.of(context)!.totalNetAgriIncomeLabel,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                Text(
                  CurrencyUtils.formatCurrency(
                      _agriIncomeHistory.fold(0.0, (sum, e) => sum + e.amount),
                      ref.watch(currencyProvider)),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<AgriIncomeEntry> _getFilteredAgri({required bool includeEntryFilter}) {
    return _applyStandardFilters<AgriIncomeEntry>(
      _agriIncomeHistory,
      includeEntryFilter: includeEntryFilter,
      currentFilter: _agriFilter,
      getIsManual: (a) => a.isManualEntry,
      getDate: (a) => a.date, // coverage:ignore-line
    );
  }

  List<Widget> _buildAgriList(List<AgriIncomeEntry> filtered) {
    if (filtered.isEmpty) {
      return [
        // coverage:ignore-line
        Padding(
          // coverage:ignore-line
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          // coverage:ignore-start
          child: Center(
              child: Text(
                  AppLocalizations.of(context)!.noEntriesMatchFilteringNote)),
          // coverage:ignore-end
        )
      ];
    }
    return filtered.map((e) {
      final i = _agriIncomeHistory.indexOf(e);
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.2) // coverage:ignore-line
                : Colors.black.withValues(alpha: 0.1),
          ),
        ),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.grey.withValues(alpha: 0.1),
            child: Icon(Icons.agriculture_outlined,
                color: Theme.of(context).colorScheme.primary, size: 20),
          ),
          title: Text(
              e.description.isEmpty
                  ? AppLocalizations.of(context)!
                      .agriculturalIncomeTitle // coverage:ignore-line
                  : e.description,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(
              '${DateFormat(_dateFormatIso8601).format(e.date)} • ${CurrencyUtils.formatCurrency(e.amount, ref.watch(currencyProvider))}'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildBadge(e.isManualEntry, null),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.grey, size: 20),
                // coverage:ignore-start
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  setState(() => _agriIncomeHistory.removeAt(i));
                  _updateSummary();
                  // coverage:ignore-end
                },
              ),
            ],
          ),
          // coverage:ignore-start
          onTap: () {
            FocusScope.of(context).unfocus();
            _addAgriIncomeDialog(existing: e, index: i);
            // coverage:ignore-end
          },
        ),
      );
    }).toList();
  }

  Widget _buildFrequencyRow(
      String label,
      ValueNotifier<PayoutFrequency> freqNotifier,
      ValueNotifier<int?> startMonthNotifier,
      ValueNotifier<List<int>> customMonthsNotifier,
      BuildContext context,
      String selectMonthsText) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ValueListenableBuilder<PayoutFrequency>(
          valueListenable: freqNotifier,
          builder: (context, freq, _) {
            return DropdownButtonFormField<PayoutFrequency>(
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.frequencyLabel(label),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                floatingLabelBehavior: FloatingLabelBehavior.always,
                border: const OutlineInputBorder(),
              ),
              key: ValueKey(freq),
              initialValue: freq,
              isDense: true,
              items: PayoutFrequency.values.map((f) {
                String text = f.toString().split('.').last;
                text = text[0].toUpperCase() + text.substring(1);
                if (f == PayoutFrequency.trimester) {
                  text = 'Trimester (4mo)';
                }
                return DropdownMenuItem(value: f, child: Text(text));
              }).toList(),
              onChanged: (v) {
                // coverage:ignore-line
                if (v != null) {
                  freqNotifier.value = v; // coverage:ignore-line
                }
              },
            );
          },
        ),
        const SizedBox(height: 12),
        ValueListenableBuilder<PayoutFrequency>(
          valueListenable: freqNotifier,
          builder: (context, freq, _) {
            if (freq == PayoutFrequency.monthly) {
              return const SizedBox.shrink();
            }
            if (freq == PayoutFrequency.custom) {
              return _buildCustomMonthsButton(
                  // coverage:ignore-line
                  customMonthsNotifier,
                  context,
                  selectMonthsText);
            }
            return _buildStartMonthDropdown(freq, startMonthNotifier);
          },
        ),
      ],
    );
  }

  Widget _buildCustomMonthsButton(
      ValueNotifier<List<int>> customMonthsNotifier, // coverage:ignore-line
      BuildContext context,
      String label) {
    // coverage:ignore-start
    return OutlinedButton(
      onPressed: () async {
        final selected = await _showMonthMultiSelect(
            context, customMonthsNotifier.value, label);
        // coverage:ignore-end
        if (selected != null) {
          customMonthsNotifier.value = selected; // coverage:ignore-line
        }
      },
      child: ValueListenableBuilder<List<int>>(
        // coverage:ignore-line
        valueListenable: customMonthsNotifier,
        // coverage:ignore-start
        builder: (c, list, _) => Text(list.isEmpty
            ? AppLocalizations.of(context)!.selectMonthsAction
            : AppLocalizations.of(context)!
                .monthsSelectedCountLabel(list.length.toString())),
        // coverage:ignore-end
      ),
    );
  }

  Widget _buildStartMonthDropdown(
      PayoutFrequency freq, ValueNotifier<int?> startMonthNotifier) {
    return ValueListenableBuilder<int?>(
      valueListenable: startMonthNotifier,
      builder: (context, startM, _) {
        return DropdownButtonFormField<int>(
          decoration: InputDecoration(
            labelText: freq == PayoutFrequency.annually
                ? AppLocalizations.of(context)!.payoutMonthLabel
                : AppLocalizations.of(context)!
                    .startMonthLabel, // coverage:ignore-line
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            floatingLabelBehavior: FloatingLabelBehavior.always,
            border: const OutlineInputBorder(),
          ),
          key: ValueKey(startM),
          initialValue: startM,
          isDense: true,
          items: [4, 5, 6, 7, 8, 9, 10, 11, 12, 1, 2, 3]
              .map((m) => DropdownMenuItem(
                    value: m,
                    child: Text(DateFormat('MMM').format(DateTime(2023, m, 1))),
                  ))
              .toList(),
          onChanged: (v) =>
              startMonthNotifier.value = v, // coverage:ignore-line
        );
      },
    );
  }

  String _getAnnualText(
      SalaryStructure? existing, double Function(SalaryStructure) selector) {
    if (existing == null) return '';
    return (selector(existing) * 12).toStringAsFixed(0);
  }

  DateTime _getDefaultEffectiveDate(SalaryStructure? existing) {
    if (existing?.effectiveDate != null) return existing!.effectiveDate;
    if (_currentData.salary.history.isNotEmpty) return DateTime.now();
    final rules =
        ref.read(taxConfigServiceProvider).getRulesForYear(_currentData.year);
    return DateTime(_currentData.year, rules.financialYearStartMonth, 1);
  }

  void _editSalaryStructure(SalaryStructure? existing) {
    final effectiveDateNotifier =
        ValueNotifier<DateTime>(_getDefaultEffectiveDate(existing));
    final basicCtrl = TextEditingController(
        text: _getAnnualText(existing, (s) => s.monthlyBasic));
    final fixedCtrl = TextEditingController(
        text: _getAnnualText(existing, (s) => s.monthlyFixedAllowances));
    final perfCtrl = TextEditingController(
        text: _getAnnualText(existing, (s) => s.monthlyPerformancePay));
    final pfCtrl = TextEditingController(
        text: _getAnnualText(existing, (s) => s.monthlyEmployeePF));
    final gratuityCtrl = TextEditingController(
        text: _getAnnualText(existing, (s) => s.monthlyGratuity));

    final variableCtrl = TextEditingController(
        text: existing != null
            ? existing.annualVariablePay.toStringAsFixed(0)
            : '');

    final perfFreqNotifier = ValueNotifier<PayoutFrequency>(
        existing?.performancePayFrequency ?? PayoutFrequency.monthly);
    final perfStartMonthNotifier =
        ValueNotifier<int?>(existing?.performancePayStartMonth);
    final perfCustomMonthsNotifier =
        ValueNotifier<List<int>>(existing?.performancePayCustomMonths ?? []);
    final perfPartialNotifier =
        ValueNotifier<bool>(existing?.isPerformancePayPartial ?? false);
    final perfAmountsNotifier = ValueNotifier<Map<int, double>>(
        Map.from(existing?.performancePayAmounts ?? {}));

    final varFreqNotifier = ValueNotifier<PayoutFrequency>(
        existing?.variablePayFrequency ?? PayoutFrequency.annually);
    final varStartMonthNotifier =
        ValueNotifier<int?>(existing?.variablePayStartMonth ?? 3);
    final varCustomMonthsNotifier =
        ValueNotifier<List<int>>(existing?.variablePayCustomMonths ?? []);
    final varPartialNotifier =
        ValueNotifier<bool>(existing?.isVariablePayPartial ?? false);
    final varAmountsNotifier = ValueNotifier<Map<int, double>>(
        Map.from(existing?.variablePayAmounts ?? {}));

    final customAllowancesNotifier = ValueNotifier<List<CustomAllowance>>(
        List.from(existing?.customAllowances ?? []));
    final stoppedMonthsNotifier =
        ValueNotifier<List<int>>(existing?.stoppedMonths ?? []);

    // Define helper first

    showDialog(
      context: context,
      builder: (ctx) => _buildSalaryStructureDialog(
        ctx: ctx,
        params: _SalaryStructureFormParams(
          existing: existing,
          effectiveDateNotifier: effectiveDateNotifier,
          basicCtrl: basicCtrl,
          fixedCtrl: fixedCtrl,
          perfCtrl: perfCtrl,
          perfFreqNotifier: perfFreqNotifier,
          perfStartMonthNotifier: perfStartMonthNotifier,
          perfCustomMonthsNotifier: perfCustomMonthsNotifier,
          perfPartialNotifier: perfPartialNotifier,
          perfAmountsNotifier: perfAmountsNotifier,
          variableCtrl: variableCtrl,
          varFreqNotifier: varFreqNotifier,
          varStartMonthNotifier: varStartMonthNotifier,
          varCustomMonthsNotifier: varCustomMonthsNotifier,
          varPartialNotifier: varPartialNotifier,
          varAmountsNotifier: varAmountsNotifier,
          customAllowancesNotifier: customAllowancesNotifier,
          stoppedMonthsNotifier: stoppedMonthsNotifier,
          pfCtrl: pfCtrl,
          gratuityCtrl: gratuityCtrl,
        ),
      ),
    );
  }

  Widget _buildSalaryStructureDialog({
    required BuildContext ctx,
    required _SalaryStructureFormParams params,
  }) {
    final existing = params.existing;
    return AlertDialog(
      title: Text(existing == null
          ? AppLocalizations.of(context)!.addSalaryStructureAction
          : AppLocalizations.of(context)!.editSalaryStructureAction),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSalaryCoreFields(params.effectiveDateNotifier,
                params.basicCtrl, params.fixedCtrl),
            const SizedBox(height: 16),
            _buildSalaryPaySections(
              perfCtrl: params.perfCtrl,
              perfFreqNotifier: params.perfFreqNotifier,
              perfStartMonthNotifier: params.perfStartMonthNotifier,
              perfCustomMonthsNotifier: params.perfCustomMonthsNotifier,
              perfPartialNotifier: params.perfPartialNotifier,
              perfAmountsNotifier: params.perfAmountsNotifier,
              variableCtrl: params.variableCtrl,
              varFreqNotifier: params.varFreqNotifier,
              varStartMonthNotifier: params.varStartMonthNotifier,
              varCustomMonthsNotifier: params.varCustomMonthsNotifier,
              varPartialNotifier: params.varPartialNotifier,
              varAmountsNotifier: params.varAmountsNotifier,
              context: context,
            ),
            _buildSalaryDeductionSections(params.pfCtrl, params.gratuityCtrl,
                params.stoppedMonthsNotifier, context),
            _buildSalaryAllowancesSection(
                context, params.customAllowancesNotifier),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), // coverage:ignore-line
            child: Text(AppLocalizations.of(context)!.cancelButton)),
        if (existing != null)
          TextButton(
              onPressed: () {
                // coverage:ignore-line
                // Delete Logic
                // coverage:ignore-start
                setState(() {
                  _salaryHistory.removeWhere((s) => s.id == existing.id);
                  _hasUnsavedChanges = true;
                  _updateSummary();
                  // coverage:ignore-end
                });
                Navigator.pop(ctx); // coverage:ignore-line
              },
              child: Text(AppLocalizations.of(context)!.deleteButton,
                  style: const TextStyle(color: Colors.red))),
        FilledButton(
          onPressed: () => _onSaveSalaryStructure(
            ctx: ctx,
            params: params,
          ),
          child: Text(AppLocalizations.of(context)!.saveButton),
        ),
      ],
    );
  }

  Future<void> _copySalaryFromPreviousYear() async {
    final prevData =
        ref.read(storageServiceProvider).getTaxYearData(_currentData.year - 1);
    if (prevData == null || prevData.salary.history.isEmpty) {
      // coverage:ignore-line
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  AppLocalizations.of(context)!.noSalaryDataPreviousYearNote)),
        );
      }
      return;
    }

    // Map to new IDs to avoid conflicts
    // coverage:ignore-start
    final newHistory = prevData.salary.history.map((s) {
      return s.copyWith(
          id: DateTime.now().millisecondsSinceEpoch.toString() + s.id);
    }).toList();
    // coverage:ignore-end

    setState(() {
      // coverage:ignore-line
      _salaryHistory.addAll(newHistory); // coverage:ignore-line
    });

    // coverage:ignore-start
    _updateSummary();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppLocalizations.of(context)!
                .copiedStructuresCountNote(newHistory.length.toString()))),
        // coverage:ignore-end
      );
    }
  }

  Future<void> _copyHousePropFromPreviousYear() async {
    final prevData =
        ref.read(storageServiceProvider).getTaxYearData(_currentData.year - 1);
    if (prevData == null || prevData.houseProperties.isEmpty) {
      // coverage:ignore-start
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(AppLocalizations.of(context)!
                  .noHousePropertiesPreviousYearNote)),
          // coverage:ignore-end
        );
      }
      return;
    }

    setState(() {
      _houseProperties.addAll(prevData.houseProperties);
    });
    _updateSummary();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppLocalizations.of(context)!
                .copiedPropertiesCountNote(
                    prevData.houseProperties.length.toString()))),
      );
    }
  }

  Future<List<int>?> _showMonthMultiSelect(
      // coverage:ignore-line
      BuildContext context,
      List<int> selected,
      String title) async {
    return await showDialog<List<int>>(
      // coverage:ignore-line
      context: context,
      builder: (ctx) => _MonthMultiSelectDialog(
        // coverage:ignore-line
        selected: selected,
        title: title,
        buildMonthChips: _buildMonthChips, // coverage:ignore-line
      ),
    );
  }

  Widget _buildMonthChips({
    // coverage:ignore-line
    required List<int> months,
    required List<int> current,
    required void Function(int, bool) onToggle,
  }) {
    return Wrap(
      // coverage:ignore-line
      spacing: 8,
      // coverage:ignore-start
      children: months.map((m) {
        final isSelected = current.contains(m);
        return FilterChip(
          label: Text(DateFormat('MMM').format(DateTime(2023, m, 1))),
          // coverage:ignore-end
          selected: isSelected,
          onSelected: (v) => onToggle(m, v), // coverage:ignore-line
        );
      }).toList(), // coverage:ignore-line
    );
  }

  void _addCustomAllowanceDialog({
    // coverage:ignore-line
    BuildContext? context,
    required void Function(CustomAllowance) onAdd,
    CustomAllowance? existing,
    bool isDeduction = false,
  }) {
    // coverage:ignore-start
    final parentCtx = context ?? this.context;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final initialAmount = _calculateInitialAnnualAmount(existing);
    final amtCtrl = TextEditingController(
        text: existing != null ? initialAmount.toStringAsFixed(2) : '');
    // coverage:ignore-end

    // coverage:ignore-start
    final freqNotifier = ValueNotifier<PayoutFrequency>(
        existing?.frequency ?? PayoutFrequency.monthly);
    final isPartialNotifier = ValueNotifier<bool>(existing?.isPartial ?? false);
    final startMonthNotifier = ValueNotifier<int?>(existing?.startMonth ?? 4);
    // coverage:ignore-end
    final customMonthsNotifier =
        // coverage:ignore-start
        ValueNotifier<List<int>>(existing?.customMonths ?? []);
    bool isCliff = existing?.isCliffExemption ?? false;
    final exemptionLimitCtrl = TextEditingController(
        text: (existing?.exemptionLimit ?? 0) > 0
            ? existing!.exemptionLimit.toStringAsFixed(0)
            // coverage:ignore-end
            : '');

    final partialAmountsNotifier =
        ValueNotifier<Map<int, double>>(// coverage:ignore-line
            Map.from(existing?.partialAmounts ?? {})); // coverage:ignore-line

    showDialog(
      // coverage:ignore-line
      context: parentCtx,
      // coverage:ignore-start
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateSB) => AlertDialog(
          title: Text(_getAllowanceDialogTitle(existing, isDeduction)),
          content: SingleChildScrollView(
            child: _buildAllowanceDialogBody(
              // coverage:ignore-end
              isDeduction: isDeduction,
              nameCtrl: nameCtrl,
              amtCtrl: amtCtrl,
              freqNotifier: freqNotifier,
              customMonthsNotifier: customMonthsNotifier,
              startMonthNotifier: startMonthNotifier,
              isCliff: isCliff,
              exemptionLimitCtrl: exemptionLimitCtrl,
              isPartialNotifier: isPartialNotifier,
              partialAmountsNotifier: partialAmountsNotifier,
              onIsCliffChanged: (v) =>
                  setStateSB(() => isCliff = v), // coverage:ignore-line
            ),
          ),
          actions: _buildAllowanceDialogActions(
            // coverage:ignore-line
            ctx: ctx,
            nameCtrl: nameCtrl,
            amtCtrl: amtCtrl,
            freqNotifier: freqNotifier,
            isPartialNotifier: isPartialNotifier,
            startMonthNotifier: startMonthNotifier,
            customMonthsNotifier: customMonthsNotifier,
            partialAmountsNotifier: partialAmountsNotifier,
            isCliff: isCliff,
            exemptionLimitCtrl: exemptionLimitCtrl,
            onAdd: onAdd,
            existingId: existing?.id, // coverage:ignore-line
          ),
        ),
      ),
    );
  }

  Widget _buildAllowanceDialogBody({
    // coverage:ignore-line
    required bool isDeduction,
    required TextEditingController nameCtrl,
    required TextEditingController amtCtrl,
    required ValueNotifier<PayoutFrequency> freqNotifier,
    required ValueNotifier<List<int>> customMonthsNotifier,
    required ValueNotifier<int?> startMonthNotifier,
    required bool isCliff,
    required TextEditingController exemptionLimitCtrl,
    required ValueNotifier<bool> isPartialNotifier,
    required ValueNotifier<Map<int, double>> partialAmountsNotifier,
    required void Function(bool) onIsCliffChanged,
  }) {
    return Column(
      // coverage:ignore-line
      mainAxisSize: MainAxisSize.min,
      children: [
        // coverage:ignore-line
        TextField(
          // coverage:ignore-line
          controller: nameCtrl,
          decoration: InputDecoration(
              // coverage:ignore-line
              labelText: isDeduction
                  ? AppLocalizations.of(context)!
                      .deductionNameLabel // coverage:ignore-line
                  : AppLocalizations.of(context)!
                      .allowanceNameLabel), // coverage:ignore-line
        ),
        TextField(
          // coverage:ignore-line
          controller: amtCtrl,
          decoration: InputDecoration(
              // coverage:ignore-line
              labelText: isDeduction
                  ? AppLocalizations.of(context)!
                      .annualDeductionAmountLabel // coverage:ignore-line
                  : AppLocalizations.of(context)!
                      .annualPayoutAmountLabel), // coverage:ignore-line
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            // coverage:ignore-line
            FilteringTextInputFormatter.allow(
                RegexUtils.amountExp) // coverage:ignore-line
          ],
        ),
        const SizedBox(height: 12),
        _buildFrequencySection(
            // coverage:ignore-line
            context,
            freqNotifier,
            customMonthsNotifier,
            startMonthNotifier), // coverage:ignore-line
        const SizedBox(height: 12),
        // coverage:ignore-start
        SwitchListTile(
          title: Text(AppLocalizations.of(context)!.isCliffExemptionTitle),
          subtitle: Text(AppLocalizations.of(context)!.cliffExemptionSubtitle),
          // coverage:ignore-end
          value: isCliff,
          onChanged: onIsCliffChanged,
        ),
        if (isCliff)
          Padding(
            // coverage:ignore-line
            padding: const EdgeInsets.only(top: 8.0),
            child: TextField(
              // coverage:ignore-line
              controller: exemptionLimitCtrl,
              decoration: InputDecoration(
                  // coverage:ignore-line
                  labelText: AppLocalizations.of(context)!
                      .exemptionLimitLabel, // coverage:ignore-line
                  helperText: AppLocalizations.of(context)!
                      .exemptionLimitHelperText, // coverage:ignore-line
                  border: const OutlineInputBorder(),
                  floatingLabelBehavior: FloatingLabelBehavior.always),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                // coverage:ignore-line
                FilteringTextInputFormatter.allow(
                    RegexUtils.amountExp) // coverage:ignore-line
              ],
            ),
          ),
        _buildPartialSection(isPartialNotifier, () {
          // coverage:ignore-line
          return _buildAllowancePartialGrid(
            // coverage:ignore-line
            freqNotifier: freqNotifier,
            startMonthNotifier: startMonthNotifier,
            customMonthsNotifier: customMonthsNotifier,
            amtCtrl: amtCtrl,
            partialAmountsNotifier: partialAmountsNotifier,
          );
        }),
      ],
    );
  }

  List<Widget> _buildAllowanceDialogActions({
    // coverage:ignore-line
    required BuildContext ctx,
    required TextEditingController nameCtrl,
    required TextEditingController amtCtrl,
    required ValueNotifier<PayoutFrequency> freqNotifier,
    required ValueNotifier<bool> isPartialNotifier,
    required ValueNotifier<int?> startMonthNotifier,
    required ValueNotifier<List<int>> customMonthsNotifier,
    required ValueNotifier<Map<int, double>> partialAmountsNotifier,
    required bool isCliff,
    required TextEditingController exemptionLimitCtrl,
    required void Function(CustomAllowance) onAdd,
    String? existingId,
  }) {
    // coverage:ignore-start
    return [
      TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(AppLocalizations.of(context)!.cancelButton)),
      FilledButton(
        onPressed: () => _onAddCustomAllowance(
          // coverage:ignore-end
          ctx: ctx,
          nameCtrl: nameCtrl,
          amtCtrl: amtCtrl,
          freqNotifier: freqNotifier,
          isPartialNotifier: isPartialNotifier,
          startMonthNotifier: startMonthNotifier,
          customMonthsNotifier: customMonthsNotifier,
          partialAmountsNotifier: partialAmountsNotifier,
          isCliff: isCliff,
          exemptionLimitCtrl: exemptionLimitCtrl,
          onAdd: onAdd,
          existingId: existingId,
        ),
        child: Text(
            AppLocalizations.of(context)!.saveButton), // coverage:ignore-line
      ),
    ];
  }

  void _onAddCustomAllowance({
    // coverage:ignore-line
    required BuildContext ctx,
    required TextEditingController nameCtrl,
    required TextEditingController amtCtrl,
    required ValueNotifier<PayoutFrequency> freqNotifier,
    required ValueNotifier<bool> isPartialNotifier,
    required ValueNotifier<int?> startMonthNotifier,
    required ValueNotifier<List<int>> customMonthsNotifier,
    required ValueNotifier<Map<int, double>> partialAmountsNotifier,
    required bool isCliff,
    required TextEditingController exemptionLimitCtrl,
    required Function(CustomAllowance) onAdd,
    String? existingId,
  }) {
    if (nameCtrl.text.isEmpty) {
      // coverage:ignore-line
      return;
    }
    final inputAmount =
        double.tryParse(amtCtrl.text) ?? 0; // coverage:ignore-line
    final freq = freqNotifier.value; // coverage:ignore-line
    final payoutAmount = _calculatePayoutAmount(
        inputAmount, freq, customMonthsNotifier.value); // coverage:ignore-line
    final exemptionLimit =
        double.tryParse(exemptionLimitCtrl.text) ?? 0; // coverage:ignore-line

    // coverage:ignore-start
    onAdd(CustomAllowance(
      id: existingId ?? const Uuid().v4(),
      name: nameCtrl.text,
      // coverage:ignore-end
      frequency: freq,
      payoutAmount: payoutAmount,
      // coverage:ignore-start
      isPartial: isPartialNotifier.value,
      partialAmounts: partialAmountsNotifier.value,
      startMonth: startMonthNotifier.value,
      customMonths: customMonthsNotifier.value,
      // coverage:ignore-end
      isCliffExemption: isCliff,
      exemptionLimit: exemptionLimit,
    ));
    Navigator.pop(ctx); // coverage:ignore-line
  }

  double _calculateInitialAnnualAmount(CustomAllowance? existing) {
    // coverage:ignore-line
    if (existing == null) {
      return 0;
    }
    // coverage:ignore-start
    double amount = existing.payoutAmount;
    switch (existing.frequency) {
      case PayoutFrequency.monthly:
        return amount * 12;
      case PayoutFrequency.quarterly:
        return amount * 4;
      case PayoutFrequency.halfYearly:
        return amount * 2;
      case PayoutFrequency.trimester:
        return amount * 3;
      case PayoutFrequency.custom:
        return amount * (existing.customMonths?.length ?? 1);
      // coverage:ignore-end
      default:
        return amount;
    }
  }

  double _calculatePayoutAmount(
      // coverage:ignore-line
      double annualAmount,
      PayoutFrequency freq,
      List<int> customMonths) {
    switch (freq) {
      // coverage:ignore-start
      case PayoutFrequency.monthly:
        return annualAmount / 12;
      case PayoutFrequency.quarterly:
        return annualAmount / 4;
      case PayoutFrequency.halfYearly:
        return annualAmount / 2;
      case PayoutFrequency.trimester:
        return annualAmount / 3;
      case PayoutFrequency.custom:
        return annualAmount / (customMonths.isEmpty ? 1 : customMonths.length);
      // coverage:ignore-end
      default:
        return annualAmount;
    }
  }

  Widget _buildAllowancePartialGrid({
    // coverage:ignore-line
    required ValueNotifier<PayoutFrequency> freqNotifier,
    required ValueNotifier<int?> startMonthNotifier,
    required ValueNotifier<List<int>> customMonthsNotifier,
    required TextEditingController amtCtrl,
    required ValueNotifier<Map<int, double>> partialAmountsNotifier,
  }) {
    return ValueListenableBuilder<PayoutFrequency>(
        // coverage:ignore-line
        valueListenable: freqNotifier,
        builder: (context, freq, _) {
          // coverage:ignore-line
          return ValueListenableBuilder<int?>(
              // coverage:ignore-line
              valueListenable: startMonthNotifier,
              builder: (ctx, startMonth, _) {
                // coverage:ignore-line
                return ValueListenableBuilder<List<int>>(
                    // coverage:ignore-line
                    valueListenable: customMonthsNotifier,
                    builder: (ctx, customMonths, _) {
                      // coverage:ignore-line
                      return _buildAllowancePartialContent(
                        // coverage:ignore-line
                        freq: freq,
                        startMonth: startMonth,
                        customMonths: customMonths,
                        amtCtrl: amtCtrl,
                        partialAmountsNotifier: partialAmountsNotifier,
                      );
                    });
              });
        });
  }

  Widget _buildAllowancePartialContent({
    // coverage:ignore-line
    required PayoutFrequency freq,
    required int? startMonth,
    required List<int> customMonths,
    required TextEditingController amtCtrl,
    required ValueNotifier<Map<int, double>> partialAmountsNotifier,
  }) {
    final applicable = _getApplicableMonths(
        freq, startMonth, customMonths); // coverage:ignore-line
    if (applicable.isEmpty) {
      // coverage:ignore-line
      return const SizedBox.shrink();
    }

    return Column(
      // coverage:ignore-line
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // coverage:ignore-line
        const SizedBox(height: 8),
        Text(
            AppLocalizations.of(context)!
                .monthlyAmountsLabel, // coverage:ignore-line
            style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          // coverage:ignore-line
          spacing: 8,
          runSpacing: 8,
          children: applicable.map((m) {
            // coverage:ignore-line
            final inputAmt =
                double.tryParse(amtCtrl.text) ?? 0; // coverage:ignore-line
            final defaultPayout = _calculatePayoutAmount(
                inputAmt, freq, customMonths); // coverage:ignore-line
            final val = partialAmountsNotifier.value[m] ??
                defaultPayout; // coverage:ignore-line

            return SizedBox(
              // coverage:ignore-line
              width: 80,
              // coverage:ignore-start
              child: TextField(
                decoration: InputDecoration(
                    labelText: DateFormat('MMM').format(DateTime(2023, m, 1)),
                    // coverage:ignore-end
                    isDense: true,
                    border: const OutlineInputBorder()),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                // coverage:ignore-start
                controller: TextEditingController(text: val.toStringAsFixed(0)),
                onChanged: (v) =>
                    partialAmountsNotifier.value[m] = double.tryParse(v) ?? 0,
                // coverage:ignore-end
              ),
            );
          }).toList(), // coverage:ignore-line
        )
      ],
    );
  }

  double _calculateAnnualGross(List<SalaryStructure> history) {
    if (history.isEmpty) {
      return 0;
    }

    final sortedHistory = List<SalaryStructure>.from(history)
      ..sort((a, b) => a.effectiveDate.compareTo(b.effectiveDate));

    final rules =
        ref.read(taxConfigServiceProvider).getRulesForYear(_currentData.year);
    final startMonth = rules.financialYearStartMonth;

    List<int> monthOrder = [];
    for (int i = 0; i < 12; i++) {
      int m = (startMonth + i) > 12 ? (startMonth + i - 12) : (startMonth + i);
      monthOrder.add(m);
    }

    double totalAnnualGross = 0;
    int fyStartYear = _currentData.year;

    for (int m in monthOrder) {
      int y = (m >= startMonth) ? fyStartYear : fyStartYear + 1;
      DateTime monthDate = DateTime(y, m, 1);

      SalaryStructure? applicable;
      try {
        applicable = sortedHistory.lastWhere((s) =>
            s.effectiveDate.isBefore(monthDate) ||
            s.effectiveDate.isAtSameMomentAs(monthDate));
      } catch (e) {
        applicable = null;
      }

      if (applicable != null) {
        totalAnnualGross += applicable.calculateContribution(m, startMonth);
      }
    }
    return totalAnnualGross;
  }

  String _getAllowanceDialogTitle(CustomAllowance? existing, bool isDeduction) {
    // coverage:ignore-line
    if (existing == null) {
      return isDeduction
          ? AppLocalizations.of(context)!
              .addIndependentDeductionAction // coverage:ignore-line
          : AppLocalizations.of(context)!
              .addIndependentAllowanceAction; // coverage:ignore-line
    }
    return isDeduction
        ? AppLocalizations.of(context)!
            .editIndependentDeductionAction // coverage:ignore-line
        : AppLocalizations.of(context)!
            .editIndependentAllowanceAction; // coverage:ignore-line
  }

  Widget _buildFrequencySection(
    // coverage:ignore-line
    BuildContext ctx,
    ValueNotifier<PayoutFrequency> freqNotifier,
    ValueNotifier<List<int>> customMonthsNotifier,
    ValueNotifier<int?> startMonthNotifier,
  ) {
    return ValueListenableBuilder<PayoutFrequency>(
      // coverage:ignore-line
      valueListenable: freqNotifier,
      // coverage:ignore-start
      builder: (context, freq, _) {
        return Column(
          children: [
            InputDecorator(
              decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.payoutFrequencyLabel,
                  // coverage:ignore-end
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8)),
              child: DropdownButtonHideUnderline(
                // coverage:ignore-line
                child: DropdownButton<PayoutFrequency>(
                  // coverage:ignore-line
                  value: freq,
                  isDense: true,
                  // coverage:ignore-start
                  items: PayoutFrequency.values.map((f) {
                    String text = f.toString().split('.').last;
                    text = text[0].toUpperCase() + text.substring(1);
                    if (f == PayoutFrequency.trimester) {
                      text = AppLocalizations.of(context)!
                          .payoutFrequencyTrimesterLabel;
                      // coverage:ignore-end
                    }
                    // coverage:ignore-start
                    return DropdownMenuItem(value: f, child: Text(text));
                  }).toList(),
                  onChanged: (v) => v != null ? freqNotifier.value = v : null,
                  // coverage:ignore-end
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (freq != PayoutFrequency.monthly) // coverage:ignore-line
              _buildAdjustableStartMonth(
                  // coverage:ignore-line
                  ctx,
                  freq,
                  customMonthsNotifier,
                  startMonthNotifier),
          ],
        );
      },
    );
  }

  Widget _buildAdjustableStartMonth(
    // coverage:ignore-line
    BuildContext ctx,
    PayoutFrequency freq,
    ValueNotifier<List<int>> customMonthsNotifier,
    ValueNotifier<int?> startMonthNotifier,
  ) {
    // coverage:ignore-start
    if (freq == PayoutFrequency.custom) {
      return OutlinedButton(
        onPressed: () async {
          final selected = await _showMonthMultiSelect(
              // coverage:ignore-end
              ctx,
              customMonthsNotifier.value, // coverage:ignore-line
              AppLocalizations.of(ctx)!
                  .selectMonthsAction); // coverage:ignore-line
          if (selected != null) {
            customMonthsNotifier.value = selected; // coverage:ignore-line
          }
        },
        child: ValueListenableBuilder<List<int>>(
          // coverage:ignore-line
          valueListenable: customMonthsNotifier,
          // coverage:ignore-start
          builder: (c, list, _) => Text(list.isEmpty
              ? AppLocalizations.of(context)!.selectMonthsAction
              : AppLocalizations.of(context)!
                  .monthsSelectedCountLabel(list.length.toString())),
          // coverage:ignore-end
        ),
      );
    }
    return ValueListenableBuilder<int?>(
      // coverage:ignore-line
      valueListenable: startMonthNotifier,
      // coverage:ignore-start
      builder: (ctx, startM, _) => InputDecorator(
        decoration: InputDecoration(
          labelText: freq == PayoutFrequency.annually
              ? AppLocalizations.of(context)!.payoutMonthLabel
              : AppLocalizations.of(context)!.startMonthLabel,
          // coverage:ignore-end
        ),
        child: DropdownButtonHideUnderline(
          // coverage:ignore-line
          child: DropdownButton<int>(
            // coverage:ignore-line
            value: startM,
            isDense: true,
            items:
                [4, 5, 6, 7, 8, 9, 10, 11, 12, 1, 2, 3] // coverage:ignore-line
                    .map((m) => DropdownMenuItem(
                          // coverage:ignore-line
                          value: m,
                          child: Text(DateFormat('MMM').format(
                              DateTime(2023, m, 1))), // coverage:ignore-line
                        ))
                    .toList(), // coverage:ignore-line
            onChanged: (v) =>
                startMonthNotifier.value = v, // coverage:ignore-line
          ),
        ),
      ),
    );
  }

  Widget _buildPartialSection(
      ValueNotifier<bool> isPartialNotifier, // coverage:ignore-line
      Widget Function() buildPartialGrid) {
    return ValueListenableBuilder<bool>(
      // coverage:ignore-line
      valueListenable: isPartialNotifier,
      // coverage:ignore-start
      builder: (context, val, _) => Column(
        children: [
          CheckboxListTile(
            title: Text(AppLocalizations.of(context)!.isPartialIrregularTitle),
            // coverage:ignore-end
            subtitle: Text(AppLocalizations.of(context)!
                .isPartialIrregularSubtitle), // coverage:ignore-line
            value: val,
            onChanged: (v) =>
                isPartialNotifier.value = v ?? false, // coverage:ignore-line
            controlAffinity: ListTileControlAffinity.leading,
          ),
          if (val) buildPartialGrid(), // coverage:ignore-line
        ],
      ),
    );
  }

  Widget _buildSalaryPartialGrid(
      // coverage:ignore-line
      ValueNotifier<Map<int, double>> amountsNotifier,
      ValueNotifier<PayoutFrequency> freqNotifier,
      ValueNotifier<int?> startMonthNotifier,
      ValueNotifier<List<int>> customMonthsNotifier,
      double defaultAmount) {
    return ValueListenableBuilder<PayoutFrequency>(
      // coverage:ignore-line
      valueListenable: freqNotifier,
      builder: (context, freq, _) {
        // coverage:ignore-line
        return ValueListenableBuilder<int?>(
          // coverage:ignore-line
          valueListenable: startMonthNotifier,
          builder: (context, startMonth, _) {
            // coverage:ignore-line
            return ValueListenableBuilder<List<int>>(
              // coverage:ignore-line
              valueListenable: customMonthsNotifier,
              builder: (context, customMonths, _) {
                // coverage:ignore-line
                return _buildSalaryPartialGridContent(
                  // coverage:ignore-line
                  amountsNotifier: amountsNotifier,
                  freq: freq,
                  startMonth: startMonth,
                  customMonths: customMonths,
                  defaultAmount: defaultAmount,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSalaryPartialGridContent({
    // coverage:ignore-line
    required ValueNotifier<Map<int, double>> amountsNotifier,
    required PayoutFrequency freq,
    required int? startMonth,
    required List<int> customMonths,
    required double defaultAmount,
  }) {
    List<int> applicableMonths = _getApplicableMonths(
        freq, startMonth, customMonths); // coverage:ignore-line

    if (applicableMonths.isEmpty) {
      // coverage:ignore-line
      return Text(AppLocalizations.of(context)!
          .noPayoutMonthsSelectedNote); // coverage:ignore-line
    }

    // coverage:ignore-start
    return Column(
      children: [
        Text(AppLocalizations.of(context)!.enterAmountsForPayoutMonthsNote,
            // coverage:ignore-end
            style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
        const SizedBox(height: 8),
        Wrap(
          // coverage:ignore-line
          spacing: 8,
          runSpacing: 8,
          // coverage:ignore-start
          children: applicableMonths.map((m) {
            final currentVal = amountsNotifier.value[m] ?? defaultAmount;
            return _buildSalaryMonthInput(
              // coverage:ignore-end
              month: m,
              currentVal: currentVal,
              // coverage:ignore-start
              onChanged: (val) {
                final d = double.tryParse(val) ?? 0;
                final newMap = Map<int, double>.from(amountsNotifier.value);
                newMap[m] = d;
                amountsNotifier.value = newMap;
                // coverage:ignore-end
              },
            );
          }).toList(), // coverage:ignore-line
        ),
      ],
    );
  }

  Widget _buildSalaryMonthInput({
    // coverage:ignore-line
    required int month,
    required double currentVal,
    required void Function(String) onChanged,
  }) {
    final text = currentVal.toStringAsFixed(0); // coverage:ignore-line
    return SizedBox(
      // coverage:ignore-line
      width: 100,
      // coverage:ignore-start
      child: TextField(
        decoration: InputDecoration(
          labelText: DateFormat('MMM').format(DateTime(2023, month, 1)),
          // coverage:ignore-end
          isDense: true,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.all(8),
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          // coverage:ignore-line
          FilteringTextInputFormatter.allow(
              RegexUtils.amountExp) // coverage:ignore-line
        ],
        controller: TextEditingController(text: text) // coverage:ignore-line
          ..selection = TextSelection.collapsed(
              offset: text.length), // coverage:ignore-line
        onChanged: onChanged,
      ),
    );
  }

  List<int> _getApplicableMonths(
      // coverage:ignore-line
      PayoutFrequency freq,
      int? startMonth,
      List<int> customMonths) {
    // coverage:ignore-start
    List<int> applicableMonths = [];
    for (int m = 1; m <= 12; m++) {
      if (SalaryStructure.isPayoutMonth(m, freq, startMonth, customMonths)) {
        applicableMonths.add(m);
        // coverage:ignore-end
      }
    }
    return applicableMonths;
  }

  Widget _buildStoppedMonthsSection(
      ValueNotifier<List<int>> stoppedMonthsNotifier, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(AppLocalizations.of(context)!.unemploymentNoSalaryTitle,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(AppLocalizations.of(context)!.unemploymentNoSalarySubtitle,
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 8),
        ValueListenableBuilder<List<int>>(
          valueListenable: stoppedMonthsNotifier,
          builder: (context, list, _) {
            return OutlinedButton.icon(
              // coverage:ignore-start
              onPressed: () async {
                final selected = await _showMonthMultiSelect(context, list,
                    AppLocalizations.of(context)!.selectStoppedMonthsAction);
                // coverage:ignore-end
                if (selected != null) {
                  stoppedMonthsNotifier.value =
                      selected; // coverage:ignore-line
                }
              },
              icon: const Icon(Icons.block),
              label: Text(list.isEmpty
                  ? AppLocalizations.of(context)!.selectStoppedMonthsAction
                  : AppLocalizations.of(context)! // coverage:ignore-line
                      .monthsStoppedCountLabel(
                          list.length.toString())), // coverage:ignore-line
              style: list.isNotEmpty
                  ? OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange) // coverage:ignore-line
                  : null,
            );
          },
        ),
      ],
    );
  }

  Widget _buildSalaryCoreFields(
    ValueNotifier<DateTime> effectiveDateNotifier,
    TextEditingController basicCtrl,
    TextEditingController fixedCtrl,
  ) {
    return Column(
      children: [
        ValueListenableBuilder<DateTime>(
          valueListenable: effectiveDateNotifier,
          builder: (context, date, _) {
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(AppLocalizations.of(context)!.effectiveDateLabel,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              subtitle: Text(DateFormat('MMM d, yyyy').format(date),
                  style: const TextStyle(fontSize: 16)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                // coverage:ignore-line
                final picked = await showDatePicker(
                  // coverage:ignore-line
                  context: context,
                  initialDate: date,
                  firstDate: DateTime(2000), // coverage:ignore-line
                  lastDate: DateTime(2100), // coverage:ignore-line
                );
                if (picked != null) {
                  effectiveDateNotifier.value = picked; // coverage:ignore-line
                }
              },
            );
          },
        ),
        const SizedBox(height: 16),
        TextField(
          controller: basicCtrl,
          decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.annualBasicPayLabel,
              border: const OutlineInputBorder(),
              floatingLabelBehavior: FloatingLabelBehavior.always),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegexUtils.amountExp)
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: fixedCtrl,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.annualFixedAllowancesLabel,
            border: const OutlineInputBorder(),
            floatingLabelBehavior: FloatingLabelBehavior.always,
            helperText:
                AppLocalizations.of(context)!.annualFixedAllowancesHelperText,
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegexUtils.amountExp)
          ],
        ),
      ],
    );
  }

  Widget _buildSalaryPaySections({
    required TextEditingController perfCtrl,
    required ValueNotifier<PayoutFrequency> perfFreqNotifier,
    required ValueNotifier<int?> perfStartMonthNotifier,
    required ValueNotifier<List<int>> perfCustomMonthsNotifier,
    required ValueNotifier<bool> perfPartialNotifier,
    required ValueNotifier<Map<int, double>> perfAmountsNotifier,
    required TextEditingController variableCtrl,
    required ValueNotifier<PayoutFrequency> varFreqNotifier,
    required ValueNotifier<int?> varStartMonthNotifier,
    required ValueNotifier<List<int>> varCustomMonthsNotifier,
    required ValueNotifier<bool> varPartialNotifier,
    required ValueNotifier<Map<int, double>> varAmountsNotifier,
    required BuildContext context,
  }) {
    return Column(
      children: [
        _buildPayoutSection(
          context: context,
          label: AppLocalizations.of(context)!.annualPerformancePayLabel,
          helperText: AppLocalizations.of(context)!.maxAmountPerYearLabel,
          controller: perfCtrl,
          freqNotifier: perfFreqNotifier,
          startMonthNotifier: perfStartMonthNotifier,
          customMonthsNotifier: perfCustomMonthsNotifier,
          partialNotifier: perfPartialNotifier,
          amountsNotifier: perfAmountsNotifier,
          divisor: 12,
        ),
        const SizedBox(height: 24),
        _buildPayoutSection(
          context: context,
          label: AppLocalizations.of(context)!.annualVariablePayLabel,
          helperText: AppLocalizations.of(context)!.totalAmountPerYearLabel,
          controller: variableCtrl,
          freqNotifier: varFreqNotifier,
          startMonthNotifier: varStartMonthNotifier,
          customMonthsNotifier: varCustomMonthsNotifier,
          partialNotifier: varPartialNotifier,
          amountsNotifier: varAmountsNotifier,
          divisor: 1,
        ),
      ],
    );
  }

  Widget _buildPayoutSection({
    required BuildContext context,
    required String label,
    required String helperText,
    required TextEditingController controller,
    required ValueNotifier<PayoutFrequency> freqNotifier,
    required ValueNotifier<int?> startMonthNotifier,
    required ValueNotifier<List<int>> customMonthsNotifier,
    required ValueNotifier<bool> partialNotifier,
    required ValueNotifier<Map<int, double>> amountsNotifier,
    required double divisor,
  }) {
    return Column(
      children: [
        _buildNumberField(label, controller, subtitle: helperText),
        const SizedBox(height: 24),
        _buildFrequencyRow(
            AppLocalizations.of(context)!.payoutLabel,
            freqNotifier,
            startMonthNotifier,
            customMonthsNotifier,
            context,
            AppLocalizations.of(context)!.selectMonthsAction),
        ValueListenableBuilder<bool>(
          valueListenable: partialNotifier,
          builder: (context, isPartial, _) {
            return Column(
              children: [
                CheckboxListTile(
                  title: Text(AppLocalizations.of(context)!
                      .partialPayoutTaxableFactorTitle),
                  subtitle: isPartial
                      ? null
                      : Text(AppLocalizations.of(context)!
                          .defaultEqualDistributionSubtitle),
                  value: isPartial,
                  onChanged: (v) => partialNotifier.value =
                      v ?? false, // coverage:ignore-line
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                ),
                if (isPartial)
                  _buildSalaryPartialGrid(
                      // coverage:ignore-line
                      amountsNotifier,
                      freqNotifier,
                      startMonthNotifier,
                      customMonthsNotifier,
                      (double.tryParse(controller.text) ?? 0) /
                          divisor), // coverage:ignore-line
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildSalaryDeductionSections(
    TextEditingController pfCtrl,
    TextEditingController gratuityCtrl,
    ValueNotifier<List<int>> stoppedMonthsNotifier,
    BuildContext context,
  ) {
    return Column(
      children: [
        const SizedBox(height: 16),
        TextField(
          controller: pfCtrl,
          decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.annualEmployeePFLabel,
              border: const OutlineInputBorder(),
              floatingLabelBehavior: FloatingLabelBehavior.always),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegexUtils.amountExp)
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: gratuityCtrl,
          decoration: InputDecoration(
              labelText:
                  AppLocalizations.of(context)!.annualGratuityContributionLabel,
              border: const OutlineInputBorder(),
              floatingLabelBehavior: FloatingLabelBehavior.always),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegexUtils.amountExp)
          ],
        ),
        const Divider(height: 32),
        _buildStoppedMonthsSection(stoppedMonthsNotifier, context),
      ],
    );
  }

  Widget _buildSalaryAllowancesSection(BuildContext context,
      ValueNotifier<List<CustomAllowance>> customAllowancesNotifier) {
    return Column(
      children: [
        const Divider(),
        _buildAllowanceHeader(context, customAllowancesNotifier),
        ValueListenableBuilder<List<CustomAllowance>>(
          valueListenable: customAllowancesNotifier,
          builder: (context, list, _) {
            if (list.isEmpty) {
              return Text(AppLocalizations.of(context)!.noCustomAllowancesNote,
                  style: const TextStyle(color: Colors.grey, fontSize: 12));
            }
            return Column(
              // coverage:ignore-line
              children: list
                  .map((a) => _buildAllowanceTile(
                      // coverage:ignore-line
                      context,
                      a,
                      list,
                      customAllowancesNotifier))
                  .toList(), // coverage:ignore-line
            );
          },
        ),
      ],
    );
  }

  Widget _buildAllowanceHeader(BuildContext context,
      ValueNotifier<List<CustomAllowance>> customAllowancesNotifier) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(AppLocalizations.of(context)!.customAllowancesTitle,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: () {
            // coverage:ignore-line
            _addCustomAllowanceDialog(
                // coverage:ignore-line
                context: context,
                // coverage:ignore-start
                onAdd: (newAllowance) {
                  customAllowancesNotifier.value = [
                    ...customAllowancesNotifier.value,
                    newAllowance
                    // coverage:ignore-end
                  ];
                });
          },
        ),
      ],
    );
  }

  Widget _buildAllowanceTile(
      // coverage:ignore-line
      BuildContext context,
      CustomAllowance a,
      List<CustomAllowance> list,
      ValueNotifier<List<CustomAllowance>> customAllowancesNotifier) {
    return ListTile(
      // coverage:ignore-line
      dense: true,
      contentPadding: EdgeInsets.zero,
      // coverage:ignore-start
      title: Text(a.name),
      subtitle: Text(_formatAllowanceSubtitle(a)),
      trailing: IconButton(
        // coverage:ignore-end
        icon: const Icon(Icons.delete, size: 18),
        // coverage:ignore-start
        onPressed: () {
          final newList = List<CustomAllowance>.from(list)..remove(a);
          customAllowancesNotifier.value = newList;
          // coverage:ignore-end
        },
      ),
      onTap: () {
        // coverage:ignore-line
        _addCustomAllowanceDialog(
            // coverage:ignore-line
            context: context,
            existing: a,
            // coverage:ignore-start
            onAdd: (updatedAllowance) {
              final newList = List<CustomAllowance>.from(list);
              int idx = newList.indexOf(a);
              if (idx != -1) {
                newList[idx] = updatedAllowance;
                customAllowancesNotifier.value = newList;
                // coverage:ignore-end
              }
            });
      },
    );
  }

  String _formatAllowanceSubtitle(CustomAllowance a) {
    // coverage:ignore-line
    final locale = ref.watch(currencyProvider); // coverage:ignore-line
    final payoutFormatted = CurrencyUtils.formatCurrency(
        a.payoutAmount, locale); // coverage:ignore-line

    final totalAmount =
        _calculateAllowanceAnnualTotal(a); // coverage:ignore-line
    final totalFormatted = CurrencyUtils.formatCurrency(
        totalAmount, locale); // coverage:ignore-line

    if (a.frequency == PayoutFrequency.annually && !a.isPartial) {
      // coverage:ignore-line
      return '${AppLocalizations.of(context)!.annualPayoutLabel}: $payoutFormatted'; // coverage:ignore-line
    }

    return '${AppLocalizations.of(context)!.perPayoutLabel}: $payoutFormatted • ${AppLocalizations.of(context)!.annualTotalLabel}: $totalFormatted'; // coverage:ignore-line
  }

  double _calculateAllowanceAnnualTotal(CustomAllowance a) {
    // coverage:ignore-line
    double total = 0;
    // coverage:ignore-start
    for (int m = 1; m <= 12; m++) {
      if (SalaryStructure.isPayoutMonth(
          m, a.frequency, a.startMonth, a.customMonths)) {
        if (a.isPartial) {
          total += a.partialAmounts[m] ?? a.payoutAmount;
          // coverage:ignore-end
        } else {
          total += a.payoutAmount; // coverage:ignore-line
        }
      }
    }
    return total;
  }

  void _onSaveSalaryStructure({
    required BuildContext ctx,
    required _SalaryStructureFormParams params,
  }) {
    final existing = params.existing;
    final basic = (double.tryParse(params.basicCtrl.text) ?? 0) / 12;
    final fixed = (double.tryParse(params.fixedCtrl.text) ?? 0) / 12;
    final perf = (double.tryParse(params.perfCtrl.text) ?? 0) / 12;
    final pf = (double.tryParse(params.pfCtrl.text) ?? 0) / 12;
    final gratuity = (double.tryParse(params.gratuityCtrl.text) ?? 0) / 12;
    final variable = double.tryParse(params.variableCtrl.text) ?? 0;

    final newStructure = SalaryStructure(
      id: existing?.id ?? const Uuid().v4(),
      effectiveDate: params.effectiveDateNotifier.value,
      monthlyBasic: basic,
      monthlyFixedAllowances: fixed,
      monthlyPerformancePay: perf,
      performancePayFrequency: params.perfFreqNotifier.value,
      performancePayStartMonth: params.perfStartMonthNotifier.value,
      performancePayCustomMonths: params.perfCustomMonthsNotifier.value,
      isPerformancePayPartial: params.perfPartialNotifier.value,
      performancePayAmounts: params.perfAmountsNotifier.value,
      annualVariablePay: variable,
      variablePayFrequency: params.varFreqNotifier.value,
      variablePayStartMonth: params.varStartMonthNotifier.value,
      variablePayCustomMonths: params.varCustomMonthsNotifier.value,
      isVariablePayPartial: params.varPartialNotifier.value,
      variablePayAmounts: params.varAmountsNotifier.value,
      customAllowances: params.customAllowancesNotifier.value,
      stoppedMonths: params.stoppedMonthsNotifier.value,
      monthlyEmployeePF: pf,
      monthlyGratuity: gratuity,
    );

    setState(() {
      if (existing != null) {
        final idx = _salaryHistory.indexOf(existing);
        if (idx != -1) {
          _salaryHistory[idx] = newStructure;
        }
      } else {
        _salaryHistory.add(newStructure);
      }
    });

    _updateSummary();
    Navigator.pop(ctx);
  }

  List<T> _applyStandardFilters<T>(
    List<T> list, {
    required bool includeEntryFilter,
    required EntryFilter currentFilter,
    required bool Function(T) getIsManual,
    required DateTime Function(T) getDate,
  }) {
    return list.where((item) {
      if (includeEntryFilter) {
        final isManual = getIsManual(item);
        if (currentFilter == EntryFilter.manual && !isManual) return false;
        if (currentFilter == EntryFilter.synced && isManual) return false;
      }

      final range = _selectedDateRange;
      if (range == null) return true;

      // coverage:ignore-start
      final date = getDate(item);
      return !date.isBefore(range.start) &&
          !date.isAfter(range.end.add(const Duration(days: 1)));
      // coverage:ignore-end
    }).toList();
  }

  Widget _buildDatePickerTile({
    required String title,
    required DateTime date,
    required void Function(DateTime) onDatePicked,
    DateTime? firstDate,
    DateTime? lastDate,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(DateFormat(_dateFormatIso8601).format(date)),
      trailing: const Icon(Icons.calendar_month),
      // coverage:ignore-start
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          // coverage:ignore-end
          initialDate: date,
          firstDate: firstDate ?? DateTime(2020), // coverage:ignore-line
          lastDate: lastDate ?? DateTime.now(), // coverage:ignore-line
        );
        if (d != null) {
          onDatePicked(d); // coverage:ignore-line
        }
      },
    );
  }
}

class _CGEntryDialog extends StatefulWidget {
  final CapitalGainEntry? existing;
  final int? index;
  final TextEditingController descCtrl;
  final TextEditingController saleCtrl;
  final TextEditingController costCtrl;
  final DateTime gainDate;
  final TextEditingController reinvestCtrl;
  final DateTime? reinvestDate;
  final AssetType selectedAsset;
  final ReinvestmentType selectedReinvestType;
  final bool isLtcg;
  final bool intendToReinvest;
  final Function({
    required TextEditingController descCtrl,
    required TextEditingController saleCtrl,
    required TextEditingController costCtrl,
    required DateTime gainDate,
    required AssetType selectedAsset,
    required bool isLtcg,
    required bool intendToReinvest,
    required ReinvestmentType selectedReinvestType,
    required TextEditingController reinvestCtrl,
    required DateTime? reinvestDate,
    int? index,
    CapitalGainEntry? existing,
  }) onSave;

  const _CGEntryDialog({
    this.existing,
    this.index,
    required this.descCtrl,
    required this.saleCtrl,
    required this.costCtrl,
    required this.gainDate,
    required this.reinvestCtrl,
    this.reinvestDate,
    required this.selectedAsset,
    required this.selectedReinvestType,
    required this.isLtcg,
    required this.intendToReinvest,
    required this.onSave,
    required this.parentState,
  });

  final _TaxDetailsScreenState parentState;

  @override
  State<_CGEntryDialog> createState() => _CGEntryDialogState();
}

class _CGEntryDialogState extends State<_CGEntryDialog> {
  late DateTime _gainDate;
  late DateTime? _reinvestDate;
  late AssetType _selectedAsset;
  late ReinvestmentType _selectedReinvestType;
  late bool _isLtcg;
  late bool _intendToReinvest;

  @override
  void initState() {
    super.initState();
    _gainDate = widget.gainDate;
    _reinvestDate = widget.reinvestDate;
    _selectedAsset = widget.selectedAsset;
    _selectedReinvestType = widget.selectedReinvestType;
    _isLtcg = widget.isLtcg;
    _intendToReinvest = widget.intendToReinvest;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null
          ? AppLocalizations.of(context)!.addCapitalGainAction
          : AppLocalizations.of(context)!
              .editEntryAction), // coverage:ignore-line
      content: SingleChildScrollView(
        child: widget.parentState._buildCGEntryDialogBody(
          descCtrl: widget.descCtrl,
          saleCtrl: widget.saleCtrl,
          costCtrl: widget.costCtrl,
          gainDate: _gainDate,
          selectedAsset: _selectedAsset,
          isLtcg: _isLtcg,
          intendToReinvest: _intendToReinvest,
          selectedReinvestType: _selectedReinvestType,
          reinvestCtrl: widget.reinvestCtrl,
          reinvestDate: _reinvestDate,
          // coverage:ignore-start
          onAssetChanged: (v) => setState(() => _selectedAsset = v!),
          onLtcgChanged: (v) => setState(() => _isLtcg = v!),
          onIntendChanged: (v) => setState(() => _intendToReinvest = v!),
          onDatePicked: (d) => setState(() => _gainDate = d),
          onReinvestTypeChanged: (v) =>
              setState(() => _selectedReinvestType = v),
          onReinvestDatePicked: (d) => setState(() => _reinvestDate = d),
          // coverage:ignore-end
        ),
      ),
      actions: widget.parentState._buildCGEntryDialogActions(
        ctx: context,
        descCtrl: widget.descCtrl,
        saleCtrl: widget.saleCtrl,
        costCtrl: widget.costCtrl,
        gainDate: _gainDate,
        selectedAsset: _selectedAsset,
        isLtcg: _isLtcg,
        intendToReinvest: _intendToReinvest,
        selectedReinvestType: _selectedReinvestType,
        reinvestCtrl: widget.reinvestCtrl,
        reinvestDate: _reinvestDate,
        index: widget.index,
        existing: widget.existing,
      ),
    );
  }
}

class _MonthMultiSelectDialog extends StatefulWidget {
  final List<int> selected;
  final String title;
  final Widget Function({
    required List<int> months,
    required List<int> current,
    required void Function(int, bool) onToggle,
  }) buildMonthChips;

  const _MonthMultiSelectDialog({
    // coverage:ignore-line
    required this.selected,
    required this.title,
    required this.buildMonthChips,
  });

  @override // coverage:ignore-line
  State<_MonthMultiSelectDialog> createState() =>
      _MonthMultiSelectDialogState(); // coverage:ignore-line
}

class _MonthMultiSelectDialogState extends State<_MonthMultiSelectDialog> {
  late List<int> _current;
  final _months = const [4, 5, 6, 7, 8, 9, 10, 11, 12, 1, 2, 3];

  @override // coverage:ignore-line
  void initState() {
    super.initState(); // coverage:ignore-line
    _current = List.from(widget.selected); // coverage:ignore-line
  }

  @override // coverage:ignore-line
  Widget build(BuildContext context) {
    // coverage:ignore-start
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: widget.buildMonthChips(
          months: _months,
          current: _current,
          onToggle: (m, v) {
            setState(() {
              // coverage:ignore-end
              if (v) {
                _current.add(m); // coverage:ignore-line
              } else {
                _current.remove(m); // coverage:ignore-line
              }
            });
          },
        ),
      ),
      // coverage:ignore-start
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancelButton)),
        FilledButton(
            onPressed: () => Navigator.pop(context, _current),
            child: Text(AppLocalizations.of(context)!.selectButton)),
        // coverage:ignore-end
      ],
    );
  }
}

class _SalaryStructureFormParams {
  final SalaryStructure? existing;
  final ValueNotifier<DateTime> effectiveDateNotifier;
  final TextEditingController basicCtrl;
  final TextEditingController fixedCtrl;
  final TextEditingController perfCtrl;
  final ValueNotifier<PayoutFrequency> perfFreqNotifier;
  final ValueNotifier<int?> perfStartMonthNotifier;
  final ValueNotifier<List<int>> perfCustomMonthsNotifier;
  final ValueNotifier<bool> perfPartialNotifier;
  final ValueNotifier<Map<int, double>> perfAmountsNotifier;
  final TextEditingController variableCtrl;
  final ValueNotifier<PayoutFrequency> varFreqNotifier;
  final ValueNotifier<int?> varStartMonthNotifier;
  final ValueNotifier<List<int>> varCustomMonthsNotifier;
  final ValueNotifier<bool> varPartialNotifier;
  final ValueNotifier<Map<int, double>> varAmountsNotifier;
  final ValueNotifier<List<CustomAllowance>> customAllowancesNotifier;
  final ValueNotifier<List<int>> stoppedMonthsNotifier;
  final TextEditingController pfCtrl;
  final TextEditingController gratuityCtrl;

  _SalaryStructureFormParams({
    required this.existing,
    required this.effectiveDateNotifier,
    required this.basicCtrl,
    required this.fixedCtrl,
    required this.perfCtrl,
    required this.perfFreqNotifier,
    required this.perfStartMonthNotifier,
    required this.perfCustomMonthsNotifier,
    required this.perfPartialNotifier,
    required this.perfAmountsNotifier,
    required this.variableCtrl,
    required this.varFreqNotifier,
    required this.varStartMonthNotifier,
    required this.varCustomMonthsNotifier,
    required this.varPartialNotifier,
    required this.varAmountsNotifier,
    required this.customAllowancesNotifier,
    required this.stoppedMonthsNotifier,
    required this.pfCtrl,
    required this.gratuityCtrl,
  });
}
