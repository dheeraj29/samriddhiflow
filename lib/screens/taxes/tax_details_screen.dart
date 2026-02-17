import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samriddhi_flow/models/taxes/tax_data.dart';
import 'package:samriddhi_flow/models/taxes/tax_data_models.dart';
import 'package:samriddhi_flow/models/loan.dart';
import 'package:samriddhi_flow/widgets/pure_icons.dart';

import 'package:samriddhi_flow/services/taxes/tax_config_service.dart';
import 'package:samriddhi_flow/services/taxes/indian_tax_service.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:intl/intl.dart';

class TaxDetailsScreen extends ConsumerStatefulWidget {
  final TaxYearData data;
  final Function(TaxYearData) onSave;
  final int? initialTabIndex;

  const TaxDetailsScreen({
    super.key,
    required this.data,
    required this.onSave,
    this.initialTabIndex,
  });

  @override
  ConsumerState<TaxDetailsScreen> createState() => _TaxDetailsScreenState();
}

class _TaxDetailsScreenState extends ConsumerState<TaxDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TaxYearData _currentData;

  // Controllers for Salary (Yearly)
  late TextEditingController _salaryGrossCtrl;
  late TextEditingController _salaryNpsEmployerCtrl;
  late TextEditingController _salaryLeaveEncashCtrl;
  late TextEditingController _salaryGratuityCtrl;
  late TextEditingController _salaryEmployerGiftsCtrl;

  // Local mutable lists to avoid "Unsupported operation: add"
  List<HouseProperty> _houseProperties = [];
  List<BusinessEntity> _businessIncomes = [];
  List<CapitalGainEntry> _capitalGains = [];
  List<OtherIncome> _otherIncomes = [];
  List<OtherIncome> _cashGifts = [];
  List<CustomAllowance> _independentAllowances = [];
  List<CustomDeduction> _independentDeductions = [];
  List<CustomExemption> _independentExemptions = [];

  // Controllers for Other Income / Agri / Tax
  late TextEditingController _otherIncomeNameCtrl;
  late TextEditingController _otherIncomeAmtCtrl;
  late TextEditingController _advanceTaxCtrl;
  late TextEditingController _agriIncomeCtrl;

  // Local state for lists
  List<TaxPaymentEntry> _tdsEntries = [];
  List<TaxPaymentEntry> _tcsEntries = [];

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
      _selectedIndex = widget.initialTabIndex!;
    }

    _initSalaryControllers();
    _initTaxPaymentControllers();
    _initLocalLists();
    _otherIncomeNameCtrl = TextEditingController();
    _otherIncomeAmtCtrl = TextEditingController();
    _agriIncomeCtrl =
        TextEditingController(text: _currentData.agricultureIncome.toString());

    _lockedFields.addAll(widget.data.lockedFields);

    // Add listeners for real-time summary update & locking
    void bind(TextEditingController ctrl, String id) {
      ctrl.addListener(() {
        _markAsLocked(id);
        _updateSummary();
      });
    }

    bind(_salaryGrossCtrl, 'salary.gross');
    bind(_salaryNpsEmployerCtrl, 'salary.nps');
    bind(_salaryLeaveEncashCtrl, 'salary.leave');
    bind(_salaryGratuityCtrl, 'salary.gratuity');
    bind(_salaryEmployerGiftsCtrl, 'salary.gifts');
    bind(_agriIncomeCtrl, 'agri.income');
    bind(_advanceTaxCtrl, 'tax.advance');
  }

  void _initLocalLists() {
    _houseProperties = List.from(_currentData.houseProperties);
    _businessIncomes = List.from(_currentData.businessIncomes);
    _capitalGains = List.from(_currentData.capitalGains);
    _otherIncomes = List.from(_currentData.otherIncomes);
    _cashGifts = List.from(_currentData.cashGifts);
    _independentAllowances =
        List.from(_currentData.salary.independentAllowances);
    _independentDeductions =
        List.from(_currentData.salary.independentDeductions);
    _independentExemptions =
        List.from(_currentData.salary.independentExemptions);
  }

  void _updateSummary() {
    if (!mounted) return;
    setState(() {
      _hasUnsavedChanges = true;

      // 1. Calculate Gross Salary from history
      double finalGross = _calculateAnnualGross(_currentData.salary.history);

      // 2. Update SalaryDetails in _currentData (local copy for summary)
      final newSalary = _currentData.salary.copyWith(
        grossSalary: finalGross,
        npsEmployer: double.tryParse(_salaryNpsEmployerCtrl.text) ?? 0,
        leaveEncashment: double.tryParse(_salaryLeaveEncashCtrl.text) ?? 0,
        gratuity: double.tryParse(_salaryGratuityCtrl.text) ?? 0,
        giftsFromEmployer: double.tryParse(_salaryEmployerGiftsCtrl.text) ?? 0,
        independentAllowances: _independentAllowances,
        independentDeductions: _independentDeductions,
        independentExemptions: _independentExemptions,
      );

      _currentData = _currentData.copyWith(
        salary: newSalary,
        agricultureIncome: double.tryParse(_agriIncomeCtrl.text) ?? 0,
        advanceTax: double.tryParse(_advanceTaxCtrl.text) ?? 0,
        houseProperties: _houseProperties,
        businessIncomes: _businessIncomes,
        capitalGains: _capitalGains,
        otherIncomes: _otherIncomes,
        cashGifts: _cashGifts,
        tdsEntries: _tdsEntries,
        tcsEntries: _tcsEntries,
      );
    });
  }

  void _initTaxPaymentControllers() {
    _advanceTaxCtrl =
        TextEditingController(text: _currentData.advanceTax.toString());

    // Initialize lists
    // Using List.from to create mutable copies
    _tdsEntries = List.from(_currentData.tdsEntries);
    _tcsEntries = List.from(_currentData.tcsEntries);
  }

  void _initSalaryControllers() {
    _salaryGrossCtrl =
        TextEditingController(text: _currentData.salary.grossSalary.toString());
    _salaryNpsEmployerCtrl =
        TextEditingController(text: _currentData.salary.npsEmployer.toString());
    _salaryLeaveEncashCtrl = TextEditingController(
        text: _currentData.salary.leaveEncashment.toString());
    _salaryGratuityCtrl =
        TextEditingController(text: _currentData.salary.gratuity.toString());
    _salaryEmployerGiftsCtrl = TextEditingController(
        text: _currentData.salary.giftsFromEmployer.toString());
  }

  @override
  void dispose() {
    _salaryGrossCtrl.dispose();
    _salaryNpsEmployerCtrl.dispose();
    _salaryLeaveEncashCtrl.dispose();
    _salaryGratuityCtrl.dispose();
    _salaryEmployerGiftsCtrl.dispose();
    _otherIncomeNameCtrl.dispose();
    _otherIncomeAmtCtrl.dispose();
    _advanceTaxCtrl.dispose();
    _agriIncomeCtrl.dispose();

    super.dispose();
  }

  void _save() {
    // 1. Calculate Gross from history
    double finalGross = _calculateAnnualGross(_currentData.salary.history);

    // Other deductions are typically annual figures
    final newSalary = SalaryDetails(
      grossSalary: finalGross,
      npsEmployer: (double.tryParse(_salaryNpsEmployerCtrl.text) ?? 0),
      leaveEncashment: (double.tryParse(_salaryLeaveEncashCtrl.text) ?? 0),
      gratuity: (double.tryParse(_salaryGratuityCtrl.text) ?? 0),
      giftsFromEmployer: (double.tryParse(_salaryEmployerGiftsCtrl.text) ?? 0),
      monthlyGross: const {}, // No longer projecting monthly
      customExemptions: const {},
      history: _currentData.salary.history,
      netSalaryReceived: _currentData.salary.netSalaryReceived,
      independentAllowances: _independentAllowances,
      independentDeductions: _independentDeductions,
      independentExemptions: _independentExemptions,
    );

    final updatedData = _currentData.copyWith(
      salary: newSalary,
      advanceTax: double.tryParse(_advanceTaxCtrl.text) ?? 0,
      tdsEntries: _tdsEntries,
      tcsEntries: _tcsEntries,
      agricultureIncome: double.tryParse(_agriIncomeCtrl.text) ?? 0,
      houseProperties: _houseProperties,
      businessIncomes: _businessIncomes,
      capitalGains: _capitalGains,
      otherIncomes: _otherIncomes,
      cashGifts: _cashGifts,
      lockedFields: _lockedFields.toList(),
    );

    widget.onSave(updatedData);

    // Feedback: Don't close on save, just show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tax details saved successfully!')),
    );

    setState(() {
      _hasUnsavedChanges = false;
    });
  }

  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    // Navigation Rail items
    final destinations = [
      const NavigationRailDestination(
          icon: Icon(Icons.work_outline), label: Text('Salary')),
      const NavigationRailDestination(
          icon: Icon(Icons.home_work_outlined), label: Text('House Prop')),
      const NavigationRailDestination(
          icon: Icon(Icons.storefront), label: Text('Business')),
      const NavigationRailDestination(
          icon: Icon(Icons.trending_up), label: Text('Cap Gains')),
      const NavigationRailDestination(
          icon: Icon(Icons.pie_chart_outline), label: Text('Dividend')),
      const NavigationRailDestination(
          icon: Icon(Icons.receipt_long), label: Text('Tax Paid')),
      const NavigationRailDestination(
          icon: Icon(Icons.card_giftcard), label: Text('Gifts')),
      const NavigationRailDestination(
          icon: Icon(Icons.agriculture), label: Text('Agri')),
      const NavigationRailDestination(
          icon: Icon(Icons.more_horiz), label: Text('Other')),
    ];

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
        appBar: AppBar(
          title: const Text('Edit Tax Details'),
          actions: [
            // Dynamic Add Action based on tab
            if (_selectedIndex == 0) // Salary
              IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: 'Add Salary Structure',
                  onPressed: () => _editSalaryStructure(null)),
            if (_selectedIndex == 1) // House Property
              IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: 'Add Property',
                  onPressed: () => _addHousePropertyDialog()),
            if (_selectedIndex == 2) // Business
              IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: 'Add Business',
                  onPressed: () => _addBusinessDialog()),
            if (_selectedIndex == 3) // Capital Gains
              IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: 'Add Capital Gain',
                  onPressed: () => _addCGEntryDialog()),
            if (_selectedIndex == 5) // Tax Paid
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                tooltip: 'Add Tax Entry',
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    builder: (ctx) => Wrap(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.remove_circle,
                              color: Colors.red),
                          title: const Text('Add TDS Entry'),
                          onTap: () {
                            Navigator.pop(ctx);
                            _addTaxEntryDialog(true);
                          },
                        ),
                        ListTile(
                          leading:
                              const Icon(Icons.add_circle, color: Colors.green),
                          title: const Text('Add TCS Entry'),
                          onTap: () {
                            Navigator.pop(ctx);
                            _addTaxEntryDialog(false);
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            if (_selectedIndex == 6) // Gifts
              IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: 'Add Cash Gift',
                  onPressed: () => _addCashGiftDialog()),
            if (_selectedIndex == 8) // Other
              IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: 'Add Other Income',
                  onPressed: () => _addOtherIncomeDialog()),

            // Copy Action (Salary & House Property only)
            if (_selectedIndex == 0 && _currentData.salary.history.isEmpty)
              IconButton(
                icon: const Icon(Icons.copy),
                tooltip: 'Copy Previous Year Data',
                onPressed: _copySalaryFromPreviousYear,
              ),
            if (_selectedIndex == 1 && _houseProperties.isEmpty)
              IconButton(
                icon: const Icon(Icons.copy),
                tooltip: 'Copy Previous Year Data',
                onPressed: _copyHousePropFromPreviousYear,
              ),

            IconButton(
                icon: PureIcons.save(),
                onPressed: _save,
                tooltip: 'Save Changes'),
          ],
        ),
        body: Row(
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 72),
              child: SingleChildScrollView(
                child: IntrinsicHeight(
                  child: NavigationRail(
                    selectedIndex: _selectedIndex,
                    onDestinationSelected: (int index) {
                      setState(() {
                        _selectedIndex = index;
                      });
                    },
                    labelType: NavigationRailLabelType.all,
                    destinations: destinations,
                  ),
                ),
              ),
            ),
            const VerticalDivider(thickness: 1, width: 1),
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
        bottomNavigationBar: _buildLiveSummary(),
      ),
    );
  }

  Widget _buildLiveSummary() {
    // Rough estimation similar to Dashboard
    double totalIncome = _currentData.totalSalary +
        _currentData.totalHP +
        _currentData.totalBusiness +
        _currentData.totalLTCG +
        _currentData.totalSTCG +
        _currentData.totalOther;

    // Calculate Live Tax
    final taxService = ref.read(indianTaxServiceProvider);
    double estimatedTax = taxService.calculateLiability(_currentData);

    return Container(
      color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Approx. Gross Income',
                  style: TextStyle(fontSize: 12)),
              Text('₹${totalIncome.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Est. Tax Liability', style: TextStyle(fontSize: 12)),
              Text('₹${estimatedTax.toStringAsFixed(0)}',
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
            title: const Text('Unsaved Changes'),
            content: const Text(
                'You have unsaved changes. Are you sure you want to discard them?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Keep Editing')),
              FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Discard')),
            ],
          ),
        ) ??
        false;
  }

  // --- Dividend Tab ---
  Widget _buildDividendTab() {
    final div = _currentData.dividendIncome;
    // Controllers for 5 quarters (Quarterly + Mar split)
    final q1Ctrl = TextEditingController(text: div.amountQ1.toString());
    final q2Ctrl = TextEditingController(text: div.amountQ2.toString());
    final q3Ctrl = TextEditingController(text: div.amountQ3.toString());
    final q4Ctrl = TextEditingController(text: div.amountQ4.toString());
    final q5Ctrl = TextEditingController(text: div.amountQ5.toString());

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Dividend Income (Quarterly Breakdown for Advance Tax)',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        _buildNumberField('Q1 (Apr 1 - Jun 15)', q1Ctrl),
        _buildNumberField('Q2 (Jun 16 - Sep 15)', q2Ctrl),
        _buildNumberField('Q3 (Sep 16 - Dec 15)', q3Ctrl),
        _buildNumberField('Q4 (Dec 16 - Mar 15)', q4Ctrl),
        _buildNumberField('Q5 (Mar 16 - Mar 31)', q5Ctrl),
        const Divider(),
        ListTile(
            title: const Text('Total Dividend Income'),
            trailing: Text(
                '₹${div.grossDividend.toStringAsFixed(0)}', // This updates on Save only unless we listen
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16))),
        const Padding(
          padding: EdgeInsets.all(8.0),
          child: Text(
              'Note: Detailed breakdown is required for accurate interest calculation (234C).',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
        ),
        FilledButton(
            onPressed: () {
              setState(() {
                _currentData = _currentData.copyWith(
                    dividendIncome: DividendIncome(
                  amountQ1: double.tryParse(q1Ctrl.text) ?? 0,
                  amountQ2: double.tryParse(q2Ctrl.text) ?? 0,
                  amountQ3: double.tryParse(q3Ctrl.text) ?? 0,
                  amountQ4: double.tryParse(q4Ctrl.text) ?? 0,
                  amountQ5: double.tryParse(q5Ctrl.text) ?? 0,
                ));
              });
              _updateSummary();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text(
                      'Dividend details updated internally. Click Save icon to persist.')));
            },
            child: const Text('Update Total'))
      ],
    );
  }

  Widget _buildSalaryTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionTitle('Salary Structures'),
        if (_currentData.salary.history.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
                'No salary structure defined. Add one to auto-fill monthly data.',
                style: TextStyle(color: Colors.grey)),
          )
        else
          ..._currentData.salary.history.map((s) {
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(
                    'Effective: ${DateFormat('MMM d, yyyy').format(s.effectiveDate)}'),
                subtitle: Text(
                    'Basic: ₹${s.monthlyBasic.toStringAsFixed(0)} + Allowances'),
                trailing: IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _editSalaryStructure(s),
                ),
              ),
            );
          }),
        const SizedBox(height: 16),
        _buildSalarySummaryCard(),
        const SizedBox(height: 16),
        _buildConsolidatedAdjustments(),
        const Divider(height: 32),
        _buildSectionTitle('Exemptions & Deductions'),
        _buildNumberField('Employer NPS (80CCD(2))', _salaryNpsEmployerCtrl),
        _buildNumberField(
            'Leave Encashment (Retirement / Resignation) (10(10AA))',
            _salaryLeaveEncashCtrl),
        _buildNumberField('Gratuity (Retirement / Resignation) (10(10))',
            _salaryGratuityCtrl),
        _buildNumberField('Gifts from Employer', _salaryEmployerGiftsCtrl,
            subtitle: 'Any vouchers/tokens > exemption limit'),
        const SizedBox(height: 16),
        _buildSectionTitle('Independent Allowances'),
        _buildIndependentAllowances(),
        const SizedBox(height: 16),
        _buildSectionTitle('Independent Deductions'),
        _buildIndependentDeductions(),
        const SizedBox(height: 16),
        _buildSectionTitle('Custom Ad-hoc Exemptions'),
        _buildIndependentExemptions(),
        const SizedBox(height: 16),
        _buildSectionTitle('TDS / Taxes Already Paid'),
        _buildTdsSummarySection(),
        const SizedBox(height: 16),
        _buildTakeHomeBreakdown(),
      ],
    );
  }

  Widget _buildIndependentAllowances() {
    return Column(
      children: [
        if (_independentAllowances.isEmpty)
          const Text('No independent allowances',
              style: TextStyle(color: Colors.grey, fontSize: 12))
        else
          ..._independentAllowances.map((a) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(a.name),
                subtitle: Text(
                    '₹${a.payoutAmount.toStringAsFixed(0)} (${a.frequency.name})'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, size: 20),
                  onPressed: () {
                    setState(() => _independentAllowances.remove(a));
                    _updateSummary();
                  },
                ),
              )),
        TextButton.icon(
          onPressed: () => _addCustomAllowanceDialog(context, (a) {
            setState(() => _independentAllowances.add(a));
            _updateSummary();
          }),
          icon: const Icon(Icons.add),
          label: const Text('Add Independent Allowance'),
        ),
      ],
    );
  }

  Widget _buildIndependentDeductions() {
    return Column(
      children: [
        if (_independentDeductions.isEmpty)
          const Text('No independent deductions',
              style: TextStyle(color: Colors.grey, fontSize: 12))
        else
          ..._independentDeductions.map((d) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(d.name),
                subtitle: Text(
                    '₹${d.amount.toStringAsFixed(0)} (${d.frequency.name})'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, size: 20),
                  onPressed: () {
                    setState(() => _independentDeductions.remove(d));
                    _updateSummary();
                  },
                ),
              )),
        TextButton.icon(
          onPressed: () => _addCustomDeductionDialog(onAdd: (d) {
            setState(() => _independentDeductions.add(d));
            _updateSummary();
          }),
          icon: const Icon(Icons.add),
          label: const Text('Add Independent Deduction'),
        ),
      ],
    );
  }

  Widget _buildIndependentExemptions() {
    return Column(
      children: [
        if (_independentExemptions.isEmpty)
          const Text('No ad-hoc exemptions',
              style: TextStyle(color: Colors.grey, fontSize: 12))
        else
          ..._independentExemptions.map((e) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(e.name),
                subtitle: Text('₹${e.amount.toStringAsFixed(0)}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, size: 20),
                  onPressed: () {
                    setState(() => _independentExemptions.remove(e));
                    _updateSummary();
                  },
                ),
                onTap: () => _addCustomExemptionDialog(
                    existing: e,
                    onAdd: (updated) {
                      setState(() {
                        int idx = _independentExemptions.indexOf(e);
                        _independentExemptions[idx] = updated;
                      });
                      _updateSummary();
                    }),
              )),
        TextButton.icon(
          onPressed: () => _addCustomExemptionDialog(onAdd: (e) {
            setState(() => _independentExemptions.add(e));
            _updateSummary();
          }),
          icon: const Icon(Icons.add),
          label: const Text('Add Ad-hoc Exemption'),
        ),
      ],
    );
  }

  Widget _buildTdsSummarySection() {
    final totalTds = _tdsEntries.fold(0.0, (sum, e) => sum + e.amount);
    return Column(
      children: [
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text('Total TDS tracked'),
          trailing: Text('₹${totalTds.toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(
                      () => _selectedIndex = 5); // Navigate to Tax Paid tab
                },
                icon: const Icon(Icons.edit),
                label: const Text('View/Edit All TDS'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                onPressed: _copyLiabilityToTds,
                icon: const Icon(Icons.sync),
                label: const Text('Copy Calc. Tax to TDS'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _copyLiabilityToTds() {
    final taxService = ref.read(indianTaxServiceProvider);
    double estimatedTax = taxService.calculateLiability(_currentData);

    final now = DateTime.now();
    final newEntry = TaxPaymentEntry(
      amount: estimatedTax,
      date: now,
      source: 'Calculated Liability',
      description: 'Auto-sync from tax estimation',
    );

    setState(() {
      _tdsEntries.removeWhere((e) => e.source == 'Calculated Liability');
      _tdsEntries.add(newEntry);
    });
    _updateSummary();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Estimated tax liability copied to TDS!')),
    );
  }

  void _addCustomExemptionDialog(
      {CustomExemption? existing, required Function(CustomExemption) onAdd}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final amtCtrl =
        TextEditingController(text: existing?.amount.toString() ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null
            ? 'Add Custom Exemption'
            : 'Edit Custom Exemption'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Exemption Name')),
            TextField(
              controller: amtCtrl,
              decoration: const InputDecoration(labelText: 'Amount'),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}$'))
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.isEmpty) return;
              onAdd(CustomExemption(
                  name: nameCtrl.text,
                  amount: double.tryParse(amtCtrl.text) ?? 0));
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
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

    if (breakdown.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 32),
        _buildSectionTitle('Monthly Take-Home Breakdown'),
        const Text(
          'Tax for bonuses/extras is applied in the month received.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 20,
            horizontalMargin: 0,
            columns: const [
              DataColumn(label: Text('Month')),
              DataColumn(label: Text('Gross')),
              DataColumn(label: Text('Tax')),
              DataColumn(label: Text('Deductions')),
              DataColumn(label: Text('Net In-Hand')),
            ],
            rows: [4, 5, 6, 7, 8, 9, 10, 11, 12, 1, 2, 3].map((m) {
              final data = breakdown[m] ?? {};
              final gross = data['gross'] ?? 0.0;
              final tax = data['tax'] ?? 0.0;
              final ded = data['deductions'] ?? 0.0;
              final net = data['takeHome'] ?? 0.0;
              final isStopped =
                  _getStructureForMonth(m)?.stoppedMonths.contains(m) ?? false;

              return DataRow(cells: [
                DataCell(Text(DateFormat('MMM').format(DateTime(2023, m, 1)))),
                DataCell(
                    Text(isStopped ? '-' : '₹${gross.toStringAsFixed(0)}')),
                DataCell(Text(isStopped ? '-' : '₹${tax.toStringAsFixed(0)}',
                    style: const TextStyle(color: Colors.red))),
                DataCell(Text(isStopped ? '-' : '₹${ded.toStringAsFixed(0)}',
                    style: const TextStyle(color: Colors.orange))),
                DataCell(Text(isStopped ? '-' : '₹${net.toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.green))),
              ]);
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildHousePropertyTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_houseProperties.isEmpty)
          const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('No House Properties added.'),
                SizedBox(height: 16),
              ],
            ),
          ),
        ..._houseProperties.asMap().entries.map((entry) {
          final i = entry.key;
          final hp = entry.value;
          return Card(
            child: ListTile(
              title: Text(hp.name),
              subtitle: Text(hp.isSelfOccupied
                  ? 'Self Occupied • Interest: ₹${hp.interestOnLoan.toStringAsFixed(0)}'
                  : 'Let Out • Gross Income: ₹${hp.rentReceived.toStringAsFixed(0)}'),
              trailing: IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () {
                  setState(() {
                    _houseProperties.removeAt(i);
                  });
                  _updateSummary();
                },
              ),
              onTap: () => _addHousePropertyDialog(existing: hp, index: i),
            ),
          );
        }),
      ],
    );
  }

  // FIXED DIALOG: Using StateSetter correctly
  Widget _buildConsolidatedAdjustments() {
    final history = _currentData.salary.history;
    if (history.isEmpty) return const SizedBox.shrink();

    bool hasPerformance = history.any((s) => s.isPerformancePayPartial);
    bool hasVariable = history.any((s) => s.isVariablePayPartial);
    List<String> customNames = history
        .expand((s) => s.customAllowances)
        .where((c) => c.isPartial)
        .map((c) => c.name)
        .toSet()
        .toList();

    if (!hasPerformance && !hasVariable && customNames.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Monthly Adjustments (Partial Payouts)'),
        const Text(
          'Actual amounts received for items marked as "Partial"',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        if (hasPerformance)
          _buildAdjustmentTile('Performance Pay', (month) {
            final s = _getStructureForMonth(month);
            return (s?.isPerformancePayPartial ?? false)
                ? s?.performancePayAmounts[month] ?? 0.0
                : null;
          }, (month, val) {
            _updatePartialAmount(month, 'perf', val);
          }, (month) {
            // Check if this month is a payout month for the active structure
            final s = _getStructureForMonth(month);
            if (s == null) return false;
            return _isPayoutMonth(month, s.performancePayFrequency,
                s.performancePayStartMonth, s.performancePayCustomMonths);
          }, getReferenceAmount: (month) {
            return _getStructureForMonth(month)?.monthlyPerformancePay;
          }),
        if (hasVariable)
          _buildAdjustmentTile('Variable Pay', (month) {
            final s = _getStructureForMonth(month);
            return (s?.isVariablePayPartial ?? false)
                ? s?.variablePayAmounts[month] ?? 0.0
                : null;
          }, (month, val) {
            _updatePartialAmount(month, 'var', val);
          }, (month) {
            final s = _getStructureForMonth(month);
            if (s == null) return false;
            return _isPayoutMonth(month, s.variablePayFrequency,
                s.variablePayStartMonth, s.variablePayCustomMonths);
          }, getReferenceAmount: (month) {
            // Variable pay base is Annual/12 usually for monthly comparison?
            // Or full amount if Annual?
            // "Employer Cut" implies difference from expected.
            // Let's use (Annual / 12) if monthly, or Annual otherwise.
            final s = _getStructureForMonth(month);
            if (s == null) return 0;
            if (s.variablePayFrequency == PayoutFrequency.monthly) {
              return s.annualVariablePay / 12;
            } else {
              return s.annualVariablePay;
            }
          }),
        ...customNames
            .map((name) => _buildAdjustmentTile('Custom: $name', (month) {
                  final s = _getStructureForMonth(month);
                  final allowance = s?.customAllowances
                      .where((c) => c.name == name && c.isPartial)
                      .firstOrNull;
                  return allowance?.partialAmounts[month];
                }, (month, val) {
                  _updatePartialAmount(month, 'custom:$name', val);
                }, (month) {
                  final s = _getStructureForMonth(month);
                  if (s == null) return false;
                  final allowance = s.customAllowances
                      .where((c) => c.name == name && c.isPartial)
                      .firstOrNull;
                  if (allowance == null) return false;
                  return _isPayoutMonth(month, allowance.frequency,
                      allowance.startMonth, allowance.customMonths);
                }, getReferenceAmount: (month) {
                  final s = _getStructureForMonth(month);
                  final allowance = s?.customAllowances
                      .where((c) => c.name == name && c.isPartial)
                      .firstOrNull;
                  return allowance?.payoutAmount;
                })),
      ],
    );
  }

  bool _isPayoutMonth(int month, PayoutFrequency freq, int? startMonth,
      List<int>? customMonths) {
    if (freq == PayoutFrequency.monthly) return true;
    if (freq == PayoutFrequency.custom) {
      return customMonths?.contains(month) ?? false;
    }

    if (startMonth == null) return false;

    // Calculate sequence
    // Apr=4.
    // Quarterly: 4, 7, 10, 1 (13->1)
    List<int> months = [];
    int current = startMonth;
    int step = 1;
    if (freq == PayoutFrequency.quarterly) step = 3;
    if (freq == PayoutFrequency.trimester) step = 4;
    if (freq == PayoutFrequency.halfYearly) step = 6;
    if (freq == PayoutFrequency.annually) step = 12;

    while (months.length < (12 / step).ceil()) {
      int m = current > 12 ? current - 12 : current;
      months.add(m);
      current += step;
    }

    return months.contains(month);
  }

  Widget _buildAdjustmentTile(String title, double? Function(int) getVal,
      Function(int, double) setVal, bool Function(int) isAllowedMonth,
      {double? Function(int)? getReferenceAmount}) {
    int count = 0;
    // Count ONLY configured months that are allowed
    for (int m = 1; m <= 12; m++) {
      if (isAllowedMonth(m) && (getVal(m) ?? 0) > 0) {
        count++;
      }
    }

    return Card(
      child: ListTile(
        title: Text(title),
        subtitle: Text(count == 0 ? 'Not set' : '$count months configured'),
        trailing: const Icon(Icons.edit_note),
        onTap: () async {
          // List ordered by Financial Year logic if possible, or just 1-12
          // Let's use standard FY order: Apr -> Mar
          final months = [4, 5, 6, 7, 8, 9, 10, 11, 12, 1, 2, 3];
          Map<int, double> currentMap = {};

          for (final m in months) {
            if (isAllowedMonth(m)) {
              currentMap[m] = getVal(m) ?? 0;
            }
          }

          await showDialog(
            context: context,
            builder: (ctx) => StatefulBuilder(
              builder: (context, setStateBuilder) => AlertDialog(
                title: Text('Edit Monthly Amounts: $title'),
                content: SizedBox(
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: months.length,
                    itemBuilder: (context, index) {
                      final m = months[index];
                      // If not allowed, show disabled or just date
                      if (!isAllowedMonth(m)) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 16),
                          child: Text(
                              DateFormat('MMMM').format(DateTime(2023, m, 1)),
                              style: const TextStyle(
                                  color: Colors.grey,
                                  fontStyle: FontStyle.italic)),
                        );
                      }

                      double currentVal = currentMap[m] ?? 0;
                      double? ref = getReferenceAmount?.call(m);
                      double cut = (ref != null && ref > currentVal)
                          ? ref - currentVal
                          : 0;

                      // Allowed month - show input
                      return ListTile(
                        title: Text(
                            DateFormat('MMMM').format(DateTime(2023, m, 1))),
                        subtitle: cut > 0
                            ? Text('Employer Cut: ₹${cut.toStringAsFixed(0)}',
                                style: const TextStyle(
                                    color: Colors.red, fontSize: 12))
                            : null,
                        trailing: SizedBox(
                          width: 120,
                          child: TextFormField(
                            initialValue: currentVal.toStringAsFixed(0),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              prefixText: '₹',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (v) {
                              final val = double.tryParse(v) ?? 0;
                              currentMap[m] = val;
                              setVal(m, val);
                              setStateBuilder(
                                  () {}); // Rebuild to show updated cut
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Done')),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSalarySummaryCard() {
    double historyGross = _calculateAnnualGross(_currentData.salary.history);
    double independentAllowances =
        _independentAllowances.fold(0.0, (sum, a) => sum + a.payoutAmount);
    double totalAnnualGross = historyGross + independentAllowances;

    return Card(
      color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Projected Annual Income',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('From History / Structures:'),
                Text('₹${historyGross.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Independent Allowances:'),
                Text('₹${independentAllowances.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Annual Gross:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text('₹${totalAnnualGross.toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.blue)),
              ],
            ),
          ],
        ),
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
      if (s.effectiveDate.isBefore(date) ||
          s.effectiveDate.isAtSameMomentAs(date)) {
        return s;
      }
    }
    return _currentData.salary.history.lastOrNull;
  }

  void _updatePartialAmount(int month, String key, double value) {
    final s = _getStructureForMonth(month);
    if (s == null) return;

    SalaryStructure updated;
    if (key == 'perf') {
      final newMap = Map<int, double>.from(s.performancePayAmounts);
      newMap[month] = value;
      updated = s.copyWith(performancePayAmounts: newMap);
    } else if (key == 'var') {
      final newMap = Map<int, double>.from(s.variablePayAmounts);
      newMap[month] = value;
      updated = s.copyWith(variablePayAmounts: newMap);
    } else if (key.startsWith('custom:')) {
      final name = key.substring(7);
      final newAllowances = s.customAllowances.map((c) {
        if (c.name == name) {
          final newMap = Map<int, double>.from(c.partialAmounts);
          newMap[month] = value;
          return c.copyWith(partialAmounts: newMap);
        }
        return c;
      }).toList();
      updated = s.copyWith(customAllowances: newAllowances);
    } else {
      return;
    }

    final newHistory = _currentData.salary.history.map((item) {
      if (item.id == s.id) return updated;
      return item;
    }).toList();

    _currentData = _currentData.copyWith(
      salary: _currentData.salary.copyWith(history: newHistory),
    );
    _hasUnsavedChanges = true;
    _updateSummary();
  }

  void _addHousePropertyDialog({HouseProperty? existing, int? index}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final rentCtrl =
        TextEditingController(text: existing?.rentReceived.toString() ?? '');
    final taxCtrl =
        TextEditingController(text: existing?.municipalTaxes.toString() ?? '');
    final intCtrl =
        TextEditingController(text: existing?.interestOnLoan.toString() ?? '');

    // Loan Selection
    String? selectedLoanId = existing?.loanId;

    bool isSelf = existing?.isSelfOccupied ?? true;

    // Get Loans
    final loansAsync = ref.watch(loansProvider);
    final loans = loansAsync.value ?? [];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (context, setStateBuilder) {
        // Calculate interest if loan selected
        if (selectedLoanId != null) {
          final loan = loans.firstWhere((l) => l.id == selectedLoanId,
              orElse: () => Loan(
                  id: '',
                  name: '',
                  totalPrincipal: 0,
                  remainingPrincipal: 0,
                  interestRate: 0,
                  tenureMonths: 0,
                  startDate: DateTime.now(),
                  emiAmount: 0,
                  firstEmiDate: DateTime.now())); // DUMMY
          if (loan.id.isNotEmpty) {
            // Logic to calculate interest for THIS financial year?
            // For now, simpler: Just show we grabbed it.
            // Real logic should be in service override or here.
            // User just said "show interest going to deduct".
            // I will assume the Sync Logic (already present in app) does the math.
            // Here we just pick the loan.
            // Maybe show "Linked to: Loan Name"
          }
        }

        return AlertDialog(
          title: Text(existing == null ? 'Add Property' : 'Edit Property'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: nameCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Property Name')),
                CheckboxListTile(
                  title: const Text('Self Occupied?'),
                  value: isSelf,
                  onChanged: (v) => setStateBuilder(() => isSelf = v!),
                ),
                if (!isSelf) ...[
                  TextField(
                      controller: rentCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Annual Rent Received (Gross)'),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d{0,2}$')),
                      ]),
                  TextField(
                      controller: taxCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Municipal Taxes Paid'),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d{0,2}$')),
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
                        value: l.id,
                        child: Text('${l.name} (${l.id.substring(0, 4)}...)')))
                  ],
                  onChanged: (val) {
                    setStateBuilder(() {
                      selectedLoanId = val;
                      if (val != null) {
                        // Optional: Disable manual input if linked?
                        // User said "One a loan is selected show interest going to deduct".
                        // For now, we set it.
                      }
                    });
                  },
                ),
                if (selectedLoanId == null)
                  TextField(
                      controller: intCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Interest on Loan (Manual Entry)'),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d{0,2}$')),
                      ]),
                if (selectedLoanId != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                        'Interest will be calculated from selected loan.',
                        style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontSize: 12)),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final newHP = HouseProperty(
                  name: nameCtrl.text,
                  isSelfOccupied: isSelf,
                  rentReceived: double.tryParse(rentCtrl.text) ?? 0,
                  municipalTaxes: double.tryParse(taxCtrl.text) ?? 0,
                  interestOnLoan: selectedLoanId != null
                      ? 0
                      : (double.tryParse(intCtrl.text) ??
                          0), // If linked, 0 placeholder until sync? Or keep manual?
                  // Let's keep manual as override or fallback.
                  // unique logic: If loanId is present, service should overwrite interestOnLoan during sync.
                  // For now, we save it.
                  loanId: selectedLoanId,
                );
                // Update Parent State
                setState(() {
                  if (existing != null && index != null) {
                    _houseProperties[index] = newHP;
                  } else {
                    _houseProperties.add(newHP);
                  }
                });
                _updateSummary();
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildBusinessTab() {
    return _businessIncomes.isEmpty
        ? const Center(child: Text('No Business Income added.'))
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _businessIncomes.length,
            itemBuilder: (ctx, i) {
              final b = _businessIncomes[i];
              return Card(
                child: ListTile(
                  title: Text(b.name),
                  subtitle: Text(
                      '${b.type.toString().split('.').last} • Gross: ₹${b.grossTurnover.toStringAsFixed(0)} • Net: ₹${b.netIncome.toStringAsFixed(0)}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () {
                      setState(() {
                        _businessIncomes.removeAt(i);
                      });
                      _updateSummary();
                    },
                  ),
                  onTap: () => _addBusinessDialog(existing: b, index: i),
                ),
              );
            },
          );
  }

  void _addBusinessDialog({BusinessEntity? existing, int? index}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final turnoverCtrl =
        TextEditingController(text: existing?.grossTurnover.toString() ?? '');
    final netCtrl =
        TextEditingController(text: existing?.netIncome.toString() ?? '');

    BusinessType type = existing?.type ?? BusinessType.regular;
    final rules =
        ref.read(taxConfigServiceProvider).getRulesForYear(_currentData.year);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (context, setStateBuilder) {
        return AlertDialog(
          title: Text(existing == null ? 'Add Business' : 'Edit Business'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: nameCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Business Name')),
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Taxation Type',
                    helperText:
                        'Using Section 44AD/ADA for presumptive taxation',
                    suffixIcon: Tooltip(
                      triggerMode: TooltipTriggerMode.tap,
                      showDuration: Duration(seconds: 5),
                      padding: EdgeInsets.all(12),
                      margin: EdgeInsets.symmetric(horizontal: 20),
                      message:
                          '• Section 44AD: For Business (6% of Turnover).\n• Section 44ADA: For Professionals (50% of Receipts).\n• Regular: Actual Profit (Audit required if < limit).',
                      child: Icon(Icons.info_outline, color: Colors.blue),
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<BusinessType>(
                      value: type,
                      isDense: true,
                      items: BusinessType.values.where((t) {
                        if (t == BusinessType.section44AD &&
                            !rules.is44ADEnabled) {
                          return false;
                        }
                        if (t == BusinessType.section44ADA &&
                            !rules.is44ADAEnabled) {
                          return false;
                        }
                        return true;
                      }).map((t) {
                        return DropdownMenuItem(
                            value: t, child: Text(t.toHumanReadable()));
                      }).toList(),
                      onChanged: (v) => setStateBuilder(() {
                        type = v!;
                      }),
                    ),
                  ),
                ),
                if (type != BusinessType.regular)
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: turnoverCtrl,
                    builder: (context, value, _) {
                      double to = double.tryParse(value.text) ?? 0;
                      double limit = type == BusinessType.section44AD
                          ? rules.limit44AD
                          : rules.limit44ADA;
                      if (to > limit) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            'Warning: Turnover exceeds limit (${NumberFormat.compactCurrency(locale: 'en_IN', symbol: '₹').format(limit)}). Presumptive taxation may not apply.',
                            style: const TextStyle(
                                color: Colors.orange,
                                fontSize: 12,
                                fontWeight: FontWeight.bold),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                TextField(
                    controller: turnoverCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Gross Turnover / Receipts'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}$')),
                    ]),
                TextField(
                    controller: netCtrl,
                    decoration: InputDecoration(
                        labelText: 'Net Income / Profit',
                        helperText: type == BusinessType.regular
                            ? 'Your Actual Profit'
                            : 'Min 6% (44AD) / 50% (44ADA)'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}$')),
                    ]),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                double to = double.tryParse(turnoverCtrl.text) ?? 0;
                double net = double.tryParse(netCtrl.text) ?? 0;
                double presumptive = 0;

                if (type == BusinessType.section44AD) {
                  presumptive = to * (rules.rate44AD / 100);
                }
                if (type == BusinessType.section44ADA) {
                  presumptive = to * (rules.rate44ADA / 100);
                }

                final newBus = BusinessEntity(
                  name: nameCtrl.text,
                  type: type,
                  grossTurnover: to,
                  netIncome: net,
                  presumptiveIncome: presumptive,
                );

                setState(() {
                  if (existing != null && index != null) {
                    _businessIncomes[index] = newBus;
                  } else {
                    _businessIncomes.add(newBus);
                  }
                });
                _updateSummary();
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      }),
    );
  }

  // --- Granular Capital Gains UI ---
  Widget _buildCapitalGainsTab() {
    return Column(
      children: [
        Expanded(
          child: _capitalGains.isEmpty
              ? const Center(child: Text('No Capital Gains entries added.'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _capitalGains.length,
                  itemBuilder: (ctx, i) {
                    final entry = _capitalGains[i];
                    final showReinvestAction = entry.intendToReinvest &&
                        entry.matchReinvestType == ReinvestmentType.none;

                    return Card(
                      child: ListTile(
                        title: Text(entry.description),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                '${entry.matchAssetType.toHumanReadable()} • ${entry.isLTCG ? 'LTCG' : 'STCG'}'),
                            Text(
                                'Gross: ₹${entry.saleAmount.toStringAsFixed(0)}'),
                            if (entry.intendToReinvest)
                              Row(
                                children: [
                                  Icon(
                                    entry.matchReinvestType ==
                                            ReinvestmentType.none
                                        ? Icons.warning_amber_rounded
                                        : Icons.check_circle_outline,
                                    size: 14,
                                    color: entry.matchReinvestType ==
                                            ReinvestmentType.none
                                        ? Colors.orange
                                        : Colors.green,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    entry.matchReinvestType ==
                                            ReinvestmentType.none
                                        ? 'Reinvestment Pending'
                                        : 'Reinvested: ₹${entry.reinvestedAmount.toStringAsFixed(0)} to ${entry.matchReinvestType.toHumanReadable()}',
                                    style: TextStyle(
                                      color: entry.matchReinvestType ==
                                              ReinvestmentType.none
                                          ? Colors.orange
                                          : Colors.green,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (showReinvestAction)
                              IconButton(
                                icon: const Icon(Icons.savings_outlined,
                                    color: Colors.orange),
                                tooltip: 'Record Reinvestment',
                                onPressed: () => _addCGEntryDialog(
                                    existing: entry, index: i),
                              ),
                            Text(
                                'Gain\n₹${entry.capitalGainAmount.toStringAsFixed(0)}',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            PopupMenuButton<String>(
                              onSelected: (v) {
                                if (v == 'edit') {
                                  _addCGEntryDialog(existing: entry, index: i);
                                } else if (v == 'delete') {
                                  setState(() {
                                    _capitalGains.removeAt(i);
                                  });
                                  _updateSummary();
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                    value: 'edit', child: Text('Edit')),
                                const PopupMenuItem(
                                    value: 'delete', child: Text('Delete')),
                              ],
                            ),
                          ],
                        ),
                        onTap: () =>
                            _addCGEntryDialog(existing: entry, index: i),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _addCGEntryDialog({CapitalGainEntry? existing, int? index}) {
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final saleCtrl =
        TextEditingController(text: existing?.saleAmount.toString() ?? '');
    final costCtrl = TextEditingController(
        text: existing?.costOfAcquisition.toString() ?? '');

    // Reinvestment
    final reinvestCtrl = TextEditingController(
        text: existing?.reinvestedAmount.toString() ?? '');

    DateTime gainDate = existing?.gainDate ?? DateTime.now();
    DateTime? reinvestDate = existing?.reinvestDate;

    AssetType selectedAsset =
        existing?.matchAssetType ?? AssetType.equityShares;
    ReinvestmentType selectedReinvestType =
        existing?.matchReinvestType ?? ReinvestmentType.none;
    bool isLtcg = existing?.isLTCG ?? false;
    bool intendToReinvest = existing?.intendToReinvest ?? false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (context, setStateBuilder) {
        return AlertDialog(
          title: Text(existing == null ? 'Add Capital Gain' : 'Edit Entry'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Description (e.g. Sold Reliance)')),
                const SizedBox(height: 8),
                InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Asset Sold',
                    suffixIcon: (selectedAsset == AssetType.equityShares ||
                            selectedAsset == AssetType.other)
                        ? Tooltip(
                            triggerMode: TooltipTriggerMode.tap,
                            showDuration: const Duration(seconds: 5),
                            padding: const EdgeInsets.all(12),
                            message: selectedAsset == AssetType.equityShares
                                ? 'Equity shares or Equity mutual funds (> 65% equity) and STT tax paid.'
                                : 'Gold, Debt Funds, International Funds, NPS (Tier-2), Bonds, etc.',
                            child: const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Icon(Icons.info_outline,
                                  color: Colors.blue, size: 20),
                            ),
                          )
                        : null,
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<AssetType>(
                      value: selectedAsset,
                      isDense: true,
                      items: AssetType.values.map((t) {
                        return DropdownMenuItem(
                            value: t, child: Text(t.toHumanReadable()));
                      }).toList(),
                      onChanged: (v) =>
                          setStateBuilder(() => selectedAsset = v!),
                    ),
                  ),
                ),
                CheckboxListTile(
                  title: const Text('Is Long Term (LTCG)?'),
                  value: isLtcg,
                  onChanged: (v) => setStateBuilder(() => isLtcg = v!),
                ),
                TextField(
                    controller: saleCtrl,
                    decoration: const InputDecoration(labelText: 'Sale Amount'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}$')),
                    ]),
                TextField(
                    controller: costCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Cost of Acquisition'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}$')),
                    ]),
                ListTile(
                  title: const Text('Gain Date'),
                  subtitle: Text(
                      '${gainDate.day}/${gainDate.month}/${gainDate.year}'),
                  trailing: const Icon(Icons.calendar_month),
                  onTap: () async {
                    final d = await showDatePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                        initialDate: gainDate);
                    if (d != null) setStateBuilder(() => gainDate = d);
                  },
                ),
                const Divider(),
                CheckboxListTile(
                  title: const Text('Intend to Reinvest?'),
                  subtitle: const Text('Section 54/54F/54EC exemptions'),
                  value: intendToReinvest,
                  onChanged: (v) =>
                      setStateBuilder(() => intendToReinvest = v!),
                ),
                if (intendToReinvest) ...[
                  const Text('Exemption Details',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Reinvested Into',
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<ReinvestmentType>(
                        value: selectedReinvestType,
                        isDense: true,
                        items: ReinvestmentType.values
                            .map((t) => DropdownMenuItem(
                                value: t,
                                child: Text(t == ReinvestmentType.none
                                    ? 'Pending / Not Decided'
                                    : t.toHumanReadable())))
                            .toList(),
                        onChanged: (v) =>
                            setStateBuilder(() => selectedReinvestType = v!),
                      ),
                    ),
                  ),
                  if (selectedReinvestType == ReinvestmentType.none)
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0, left: 4),
                      child: Text(
                        'Select a Reinvestment Type to enter Amount and Date.',
                        style: TextStyle(fontSize: 12, color: Colors.orange),
                      ),
                    ),
                  if (selectedReinvestType != ReinvestmentType.none) ...[
                    TextField(
                        controller: reinvestCtrl,
                        decoration:
                            const InputDecoration(labelText: 'Amount Invested'),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d{0,2}$')),
                        ]),
                    ListTile(
                      title: const Text('Reinvest Date'),
                      subtitle: Text(reinvestDate == null
                          ? 'Select Date'
                          : '${reinvestDate!.day}/${reinvestDate!.month}/${reinvestDate!.year}'),
                      trailing: const Icon(Icons.calendar_month),
                      onTap: () async {
                        final d = await showDatePicker(
                            context: context,
                            firstDate:
                                DateTime(2000), // Tax rules allow 1 year prior
                            lastDate: DateTime(2040),
                            initialDate: reinvestDate ?? gainDate);
                        if (d != null) setStateBuilder(() => reinvestDate = d);
                      },
                    ),
                  ],
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () {
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
                  );

                  setState(() {
                    if (existing != null && index != null) {
                      _capitalGains[index] = newEntry;
                    } else {
                      _capitalGains.add(newEntry);
                    }
                  });
                  _updateSummary();
                  Navigator.pop(context);
                },
                child: const Text('Save'))
          ],
        );
      }),
    );
  }

  Widget _buildOtherTab() {
    return _otherIncomes.isEmpty
        ? const Center(child: Text('No Other Income added.'))
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _otherIncomes.length,
            itemBuilder: (ctx, i) {
              final o = _otherIncomes[i];
              return Card(
                child: ListTile(
                  title: Text(o.name),
                  subtitle: Text('${o.type} • Gross Income: ₹${o.amount}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('₹${o.amount}'),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          setState(() {
                            _otherIncomes.removeAt(i);
                          });
                          _updateSummary();
                        },
                      )
                    ],
                  ),
                  onTap: () => _addOtherIncomeDialog(existing: o, index: i),
                ),
              );
            },
          );
  }

  void _addOtherIncomeDialog({OtherIncome? existing, int? index}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final amtCtrl =
        TextEditingController(text: existing?.amount.toString() ?? '');
    final typeCtrl = TextEditingController(text: existing?.type ?? 'Interest');

    // Fetch applicable exemptions
    final rules =
        ref.read(taxConfigServiceProvider).getRulesForYear(_currentData.year);
    // Feedback: Allow selecting ANY custom exemption for Other Income, don't restrict by head.
    final validExemptions =
        rules.customExemptions.where((e) => e.isEnabled).toList();

    String? selectedExemptionId = existing?.linkedExemptionId;

    showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(builder: (context, setStateBuilder) {
              return AlertDialog(
                title:
                    Text(existing == null ? 'Add Other Income' : 'Edit Income'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(labelText: 'Name'),
                          textCapitalization: TextCapitalization.words),
                      const SizedBox(height: 12),
                      TextField(
                        controller: amtCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Gross Amount (₹)',
                          suffixIcon: Tooltip(
                            padding: EdgeInsets.all(12),
                            margin: EdgeInsets.symmetric(horizontal: 20),
                            showDuration: Duration(seconds: 5),
                            triggerMode: TooltipTriggerMode.tap,
                            message:
                                'Fixed income (No loss possible) like bank interest, chit fund profit, etc. Do not include gifts here.',
                            child: Icon(Icons.info_outline, color: Colors.blue),
                          ),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d{0,2}$')),
                        ],
                      ),
                      if (validExemptions.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Link Exemption (Optional)',
                            border: OutlineInputBorder(),
                            isDense: true,
                            floatingLabelBehavior: FloatingLabelBehavior.always,
                            suffixIcon: Tooltip(
                              padding: EdgeInsets.all(12),
                              message:
                                  'Select a custom exemption rule to apply.',
                              triggerMode: TooltipTriggerMode.tap,
                              child:
                                  Icon(Icons.info_outline, color: Colors.blue),
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedExemptionId,
                              isDense: true,
                              items: [
                                const DropdownMenuItem(
                                    value: null, child: Text('None')),
                                ...validExemptions.map((e) => DropdownMenuItem(
                                      value: e.id,
                                      child: Text(e.name),
                                    ))
                              ],
                              onChanged: (v) => setStateBuilder(
                                  () => selectedExemptionId = v),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel')),
                  FilledButton(
                    onPressed: () {
                      final newItem = OtherIncome(
                        name: nameCtrl.text,
                        amount: double.tryParse(amtCtrl.text) ?? 0,
                        type: typeCtrl.text,
                        subtype: typeCtrl.text.toLowerCase(),
                        linkedExemptionId: selectedExemptionId,
                      );
                      setState(() {
                        if (existing != null && index != null) {
                          _otherIncomes[index] = newItem;
                        } else {
                          _otherIncomes.add(newItem);
                        }
                      });
                      _updateSummary();
                      Navigator.pop(context);
                    },
                    child: const Text('Save'),
                  ),
                ],
              );
            }));
  }

  Widget _buildSectionTitle(String title) {
    return Text(title,
        style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold));
  }

  Widget _buildNumberField(String label, TextEditingController controller,
      {String? subtitle}) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(labelText: label, helperText: subtitle),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}$')),
      ],
    );
  }

  Widget _buildTaxPaidTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionTitle('Taxes Already Paid'),
        const SizedBox(height: 16),
        _buildNumberField('Advance Tax Paid (Total)', _advanceTaxCtrl),
        const Divider(height: 32),
        _buildEntryListHeader('TDS Deducted (Tax Deducted at Source)', true),
        if (_tdsEntries.isEmpty)
          const Padding(
              padding: EdgeInsets.all(8),
              child: Text('No TDS entries.',
                  style: TextStyle(color: Colors.grey))),
        ..._tdsEntries.map((e) => _buildTaxEntryTile(e, true)),
        const Divider(height: 32),
        _buildEntryListHeader('TCS Collected (Tax Collected at Source)', false),
        if (_tcsEntries.isEmpty)
          const Padding(
              padding: EdgeInsets.all(8),
              child: Text('No TCS entries.',
                  style: TextStyle(color: Colors.grey))),
        ..._tcsEntries.map((e) => _buildTaxEntryTile(e, false)),
      ],
    );
  }

  Widget _buildEntryListHeader(String title, bool isTds) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
            child: Text(title,
                style: const TextStyle(fontWeight: FontWeight.bold))),
        IconButton(
          icon: const Icon(Icons.add_circle, color: Colors.blue),
          onPressed: () => _addTaxEntryDialog(isTds),
          tooltip: 'Add Entry',
        ),
      ],
    );
  }

  Widget _buildTaxEntryTile(TaxPaymentEntry entry, bool isTds) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(isTds ? Icons.remove_circle : Icons.add_circle,
          color: isTds ? Colors.red : Colors.green),
      title: Text(entry.source.isEmpty
          ? (isTds ? 'TDS Entry' : 'TCS Entry')
          : entry.source),
      subtitle: Text('Date: ${entry.date.toIso8601String().split('T').first}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('₹${entry.amount.toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.grey),
            onPressed: () {
              setState(() {
                if (isTds) {
                  _tdsEntries.remove(entry);
                } else {
                  _tcsEntries.remove(entry);
                }
              });
              _updateSummary();
            },
          ),
        ],
      ),
    );
  }

  void _addTaxEntryDialog(bool isTds) {
    final amtCtrl = TextEditingController();
    final srcCtrl = TextEditingController();
    DateTime pickedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateBuilder) => AlertDialog(
          title: Text('Add ${isTds ? 'TDS' : 'TCS'} Entry'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: srcCtrl,
                decoration: InputDecoration(
                    labelText: 'Source',
                    hintText: isTds
                        ? 'e.g. Bank, Employer'
                        : 'e.g. Car (>10L), Foreign Tour, Remittance'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: amtCtrl,
                decoration:
                    const InputDecoration(labelText: 'Gross Amount (₹)'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}$')),
                ],
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Date of Deduction/Collection'),
                subtitle: Text(
                    '${pickedDate.day}/${pickedDate.month}/${pickedDate.year}'),
                trailing: const Icon(Icons.calendar_month),
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: pickedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (d != null) {
                    setStateBuilder(() => pickedDate = d);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final amount = double.tryParse(amtCtrl.text) ?? 0;
                if (amount > 0) {
                  final entry = TaxPaymentEntry(
                    amount: amount,
                    date: pickedDate,
                    source: srcCtrl.text,
                  );
                  setState(() {
                    if (isTds) {
                      _tdsEntries.add(entry);
                    } else {
                      _tcsEntries.add(entry);
                    }
                  });
                  _updateSummary();
                }
                Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCashGiftsTab() {
    return _cashGifts.isEmpty
        ? const Center(child: Text('No Cash Gifts added.'))
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _cashGifts.length,
            itemBuilder: (ctx, i) {
              final g = _cashGifts[i];
              return Card(
                child: ListTile(
                  title: Text(g.name),
                  subtitle: Text('Type: ${g.subtype}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Gross Amount: ₹${g.amount.toStringAsFixed(0)}'),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          setState(() {
                            _cashGifts.removeAt(i);
                          });
                          _updateSummary();
                        },
                      )
                    ],
                  ),
                ),
              );
            },
          );
  }

  void _addCashGiftDialog() {
    final nameCtrl = TextEditingController();
    final amtCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (context, setStateBuilder) {
        return AlertDialog(
          title: const Text('Add Cash Gift'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Gift Description / Source')),
              TextField(
                  controller: amtCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Amount (₹)',
                    suffixIcon: Tooltip(
                      triggerMode: TooltipTriggerMode.tap,
                      showDuration: Duration(seconds: 5),
                      padding: EdgeInsets.all(12),
                      message:
                          'Gifts from relatives (marriage, inheritance) and up to ₹50k/yr from others are EXEMPT. Do not add them here unless taxable.',
                      child: Icon(Icons.info_outline, color: Colors.blue),
                    ),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}$')),
                  ]),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () {
                  final newItem = OtherIncome(
                    name: nameCtrl.text,
                    amount: double.tryParse(amtCtrl.text) ?? 0,
                    type: 'Gift',
                    subtype:
                        'Cash/Relative', // Defaulting subtype, name is enough
                  );
                  setState(() {
                    _cashGifts.add(newItem);
                  });
                  _updateSummary();
                  Navigator.pop(context);
                },
                child: const Text('Add')),
          ],
        );
      }),
    );
  }

  Widget _buildAgriIncomeTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.agriculture, size: 40, color: Colors.green),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Agriculture Income',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  const Text(
                    'Income from agricultural land in India. This is exempt from tax (Section 10(1)) BUT updated rules use "Partial Integration" to determine tax rate slab for non-agri income if Agri Income > Threshold.',
                    style: TextStyle(height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Net Agriculture Income',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                TextField(
                  controller: _agriIncomeCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}$')),
                  ],
                  decoration: const InputDecoration(
                    prefixText: '₹ ',
                    border: OutlineInputBorder(),
                    helperText: 'Enter Net Income (Gross Receipts - Expenses).',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _editSalaryStructure(SalaryStructure? existing) {
    // Default date logic: If history empty, default to FY Start.
    DateTime defaultDate = DateTime.now();
    if (existing == null && _currentData.salary.history.isEmpty) {
      final rules =
          ref.read(taxConfigServiceProvider).getRulesForYear(_currentData.year);
      defaultDate =
          DateTime(_currentData.year, rules.financialYearStartMonth, 1);
    }

    final effectiveDateNotifier =
        ValueNotifier<DateTime>(existing?.effectiveDate ?? defaultDate);
    // Initialize with Annual Values (x12 for monthly fields)
    final basicCtrl = TextEditingController(
        text: existing != null
            ? (existing.monthlyBasic * 12).toStringAsFixed(0)
            : '');
    final fixedCtrl = TextEditingController(
        text: existing != null
            ? (existing.monthlyFixedAllowances * 12).toStringAsFixed(0)
            : '');
    final perfCtrl = TextEditingController(
        text: existing != null
            ? (existing.monthlyPerformancePay * 12).toStringAsFixed(0)
            : '');
    // Variable Pay is already Annual in Model
    final variableCtrl = TextEditingController(
        text: existing?.annualVariablePay.toStringAsFixed(0) ?? '');

    // Frequency & Month Notifiers
    final perfFreqNotifier = ValueNotifier<PayoutFrequency>(
        existing?.performancePayFrequency ?? PayoutFrequency.monthly);
    final perfStartMonthNotifier =
        ValueNotifier<int?>(existing?.performancePayStartMonth);
    final perfCustomMonthsNotifier =
        ValueNotifier<List<int>>(existing?.performancePayCustomMonths ?? []);

    final varFreqNotifier = ValueNotifier<PayoutFrequency>(
        existing?.variablePayFrequency ?? PayoutFrequency.annually);
    final varStartMonthNotifier = ValueNotifier<int?>(
        existing?.variablePayStartMonth ?? 3); // Default Mar
    final varCustomMonthsNotifier =
        ValueNotifier<List<int>>(existing?.variablePayCustomMonths ?? []);

    final perfPartialNotifier =
        ValueNotifier<bool>(existing?.isPerformancePayPartial ?? false);
    final perfAmountsNotifier = ValueNotifier<Map<int, double>>(
        Map.from(existing?.performancePayAmounts ?? {}));

    final varPartialNotifier =
        ValueNotifier<bool>(existing?.isVariablePayPartial ?? false);
    final varAmountsNotifier = ValueNotifier<Map<int, double>>(
        Map.from(existing?.variablePayAmounts ?? {}));

    // Custom Allowances
    final customAllowancesNotifier = ValueNotifier<List<CustomAllowance>>(
        List.from(existing?.customAllowances ?? []));
    final stoppedMonthsNotifier =
        ValueNotifier<List<int>>(existing?.stoppedMonths ?? []);

    // Deduction fields
    final pfCtrl = TextEditingController(
        text: existing != null
            ? (existing.monthlyEmployeePF * 12).toStringAsFixed(0)
            : '');
    final gratuityCtrl = TextEditingController(
        text: existing != null
            ? (existing.monthlyGratuity * 12).toStringAsFixed(0)
            : '');
    final customDeductionsNotifier = ValueNotifier<List<CustomDeduction>>(
        List.from(existing?.customDeductions ?? []));

    // Helper to build Frequency Row
    Widget buildFrequencyRow(
        String label,
        ValueNotifier<PayoutFrequency> freqNotifier,
        ValueNotifier<int?> startMonthNotifier,
        ValueNotifier<List<int>> customMonthsNotifier) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ValueListenableBuilder<PayoutFrequency>(
            valueListenable: freqNotifier,
            builder: (context, freq, _) {
              return DropdownButtonFormField<PayoutFrequency>(
                decoration: InputDecoration(
                  labelText: '$label Frequency',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  border: const OutlineInputBorder(),
                ),
                key: ValueKey(freq),
                initialValue: freq,
                isDense: true,
                items: PayoutFrequency.values.map((f) {
                  String text = f.toString().split('.').last;
                  // Capitalize
                  text = text[0].toUpperCase() + text.substring(1);
                  if (f == PayoutFrequency.trimester) {
                    text = 'Trimester (4mo)';
                  }
                  return DropdownMenuItem(value: f, child: Text(text));
                }).toList(),
                onChanged: (v) {
                  if (v != null) freqNotifier.value = v;
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
                return OutlinedButton(
                  onPressed: () async {
                    final selected = await _showMonthMultiSelect(
                        context, customMonthsNotifier.value);
                    if (selected != null) {
                      customMonthsNotifier.value = selected;
                    }
                  },
                  child: ValueListenableBuilder<List<int>>(
                    valueListenable: customMonthsNotifier,
                    builder: (c, list, _) => Text(list.isEmpty
                        ? 'Select Months'
                        : '${list.length} Months Selected'),
                  ),
                );
              }
              // Periodic: Show Start/Payout Month
              return ValueListenableBuilder<int?>(
                valueListenable: startMonthNotifier,
                builder: (context, startM, _) {
                  return DropdownButtonFormField<int>(
                    decoration: InputDecoration(
                      labelText: freq == PayoutFrequency.annually
                          ? 'Payout Month'
                          : 'Start Month',
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12),
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      border: const OutlineInputBorder(),
                    ),
                    key: ValueKey(startM),
                    initialValue: startM,
                    isDense: true,
                    items: [4, 5, 6, 7, 8, 9, 10, 11, 12, 1, 2, 3]
                        .map((m) => DropdownMenuItem(
                              value: m,
                              child: Text(DateFormat('MMM')
                                  .format(DateTime(2023, m, 1))),
                            ))
                        .toList(),
                    onChanged: (v) => startMonthNotifier.value = v,
                  );
                },
              );
            },
          ),
        ],
      );
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null
            ? 'Add Salary Structure'
            : 'Edit Salary Structure'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Effective Date
              ValueListenableBuilder<DateTime>(
                valueListenable: effectiveDateNotifier,
                builder: (context, date, _) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Effective Date',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                    subtitle: Text(DateFormat('MMM d, yyyy').format(date),
                        style: const TextStyle(fontSize: 16)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: date,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        effectiveDateNotifier.value = picked;
                      }
                    },
                  );
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: basicCtrl,
                decoration: const InputDecoration(
                  labelText: 'Annual Basic Pay (CTC)',
                  border: OutlineInputBorder(),
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}$')),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: fixedCtrl,
                decoration: const InputDecoration(
                  labelText: 'Annual Fixed Allowances (CTC)',
                  border: OutlineInputBorder(),
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  helperText: 'HRA, Special, etc. (Fully Taxable)',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}$')),
                ],
              ),
              const SizedBox(height: 16),
              // Performance Pay
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Annual Performance Pay',
                  helperText: 'Max amount per year',
                  border: OutlineInputBorder(),
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                ),
                child: TextField(
                  controller: perfCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}$')),
                  ],
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              buildFrequencyRow('Payout', perfFreqNotifier,
                  perfStartMonthNotifier, perfCustomMonthsNotifier),
              ValueListenableBuilder<bool>(
                valueListenable: perfPartialNotifier,
                builder: (context, isPartial, _) {
                  return Column(
                    children: [
                      CheckboxListTile(
                        title: const Text('Partial Payout / Taxable Factor?'),
                        subtitle: isPartial
                            ? const Text(
                                'Currently using default distribution (Annual/12). Edit in Adjustments.')
                            : null,
                        value: isPartial,
                        onChanged: (v) =>
                            perfPartialNotifier.value = v ?? false,
                        controlAffinity: ListTileControlAffinity.leading,
                        dense: true,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              _buildNumberField('Annual Variable Pay', variableCtrl,
                  subtitle: 'Total amount per year'),
              const SizedBox(height: 24),
              buildFrequencyRow('Payout', varFreqNotifier,
                  varStartMonthNotifier, varCustomMonthsNotifier),
              ValueListenableBuilder<bool>(
                valueListenable: varPartialNotifier,
                builder: (context, isPartial, _) {
                  return Column(
                    children: [
                      CheckboxListTile(
                        title: const Text('Partial Payout / Taxable Factor?'),
                        subtitle: isPartial
                            ? const Text(
                                'Currently using default distribution (Annual/12). Edit in Adjustments.')
                            : null,
                        value: isPartial,
                        onChanged: (v) => varPartialNotifier.value = v ?? false,
                        controlAffinity: ListTileControlAffinity.leading,
                        dense: true,
                      ),
                    ],
                  );
                },
              ),
              const Divider(),
              // Custom Allowances Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Custom Allowances',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () {
                      _addCustomAllowanceDialog(ctx, (newAllowance) {
                        customAllowancesNotifier.value = [
                          ...customAllowancesNotifier.value,
                          newAllowance
                        ];
                      });
                    },
                  ),
                ],
              ),
              ValueListenableBuilder<List<CustomAllowance>>(
                valueListenable: customAllowancesNotifier,
                builder: (context, list, _) {
                  if (list.isEmpty) {
                    return const Text('No custom allowances',
                        style: TextStyle(color: Colors.grey, fontSize: 12));
                  }
                  return Column(
                    children: list.map((a) {
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(a.name),
                        subtitle: Text(
                            '₹${(a.payoutAmount * (a.frequency == PayoutFrequency.monthly ? 12 : (a.frequency == PayoutFrequency.quarterly ? 4 : (a.frequency == PayoutFrequency.halfYearly ? 2 : 1)))).toStringAsFixed(0)}/yr ${a.isPartial ? "(Partial)" : ""}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, size: 20),
                          onPressed: () {
                            customAllowancesNotifier.value =
                                list.where((x) => x != a).toList();
                          },
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 16),
              const Divider(),
              const Text('Retirement Contributions (Annual)',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _buildNumberField('Employee PF', pfCtrl),
              const SizedBox(height: 12),
              _buildNumberField('Gratuity Accrual', gratuityCtrl),
              const SizedBox(height: 24),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Custom Deductions',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () {
                      _addCustomDeductionDialog(onAdd: (newDeduction) {
                        customDeductionsNotifier.value = [
                          ...customDeductionsNotifier.value,
                          newDeduction
                        ];
                      });
                    },
                  ),
                ],
              ),
              ValueListenableBuilder<List<CustomDeduction>>(
                valueListenable: customDeductionsNotifier,
                builder: (context, list, _) {
                  if (list.isEmpty) {
                    return const Text('No custom deductions',
                        style: TextStyle(color: Colors.grey, fontSize: 12));
                  }
                  return Column(
                    children: list.map((d) {
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(d.name),
                        subtitle: Text(
                            '₹${(d.amount * (d.frequency == PayoutFrequency.monthly ? 12 : 1)).toStringAsFixed(0)}/yr ${d.isTaxable ? "(Taxable)" : "(Post-Tax)"}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, size: 20),
                          onPressed: () {
                            customDeductionsNotifier.value =
                                list.where((x) => x != d).toList();
                          },
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  _showCTCEstimator(basicCtrl, fixedCtrl);
                },
                icon: const Icon(Icons.calculate),
                label: const Text('Estimate from Target In-Hand'),
              ),
              const Divider(),
              const Text('Unemployment / No Salary',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const Text('Select months where you had no salary income.',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 8),
              ValueListenableBuilder<List<int>>(
                valueListenable: stoppedMonthsNotifier,
                builder: (context, list, _) {
                  return OutlinedButton.icon(
                    onPressed: () async {
                      final selected =
                          await _showMonthMultiSelect(context, list);
                      if (selected != null) {
                        stoppedMonthsNotifier.value = selected;
                      }
                    },
                    icon: const Icon(Icons.block),
                    label: Text(list.isEmpty
                        ? 'Select Stopped Months'
                        : '${list.length} Months Stopped'),
                    style: list.isNotEmpty
                        ? OutlinedButton.styleFrom(
                            foregroundColor: Colors.orange)
                        : null,
                  );
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          if (existing != null)
            TextButton(
                onPressed: () {
                  // Delete Logic
                  setState(() {
                    final newHistory =
                        List<SalaryStructure>.from(_currentData.salary.history);
                    newHistory.removeWhere((s) => s.id == existing.id);
                    _currentData = _currentData.copyWith(
                        salary:
                            _currentData.salary.copyWith(history: newHistory));
                    _hasUnsavedChanges = true;
                    _updateSummary();
                  });
                  Navigator.pop(ctx);
                },
                child:
                    const Text('Delete', style: TextStyle(color: Colors.red))),
          FilledButton(
            onPressed: () {
              // Convert Annual Inputs to Monthly / Computed
              final annualBasic = double.tryParse(basicCtrl.text) ?? 0;
              final annualFixed = double.tryParse(fixedCtrl.text) ?? 0;
              final annualPerf = double.tryParse(perfCtrl.text) ?? 0;
              final annualVar = double.tryParse(variableCtrl.text) ?? 0;

              final monthlyBasic = annualBasic / 12;
              final monthlyFixed = annualFixed / 12;
              final monthlyPerf = annualPerf / 12; // Base per month

              // Handle Partial Distributions (Reset to Annual/12 if empty)
              Map<int, double> perfAmounts = perfAmountsNotifier.value;
              if (perfPartialNotifier.value && perfAmounts.isEmpty) {
                // Auto-fill default distribution
                for (int m = 1; m <= 12; m++) {
                  perfAmounts[m] = monthlyPerf;
                }
              }

              Map<int, double> varAmounts = varAmountsNotifier.value;
              if (varPartialNotifier.value && varAmounts.isEmpty) {
                // Auto-fill default distribution
                for (int m = 1; m <= 12; m++) {
                  varAmounts[m] = annualVar / 12;
                }
              }

              final newStructure = SalaryStructure(
                id: existing?.id ??
                    DateTime.now().millisecondsSinceEpoch.toString(),
                effectiveDate: effectiveDateNotifier.value,
                monthlyBasic: monthlyBasic,
                monthlyFixedAllowances: monthlyFixed,
                monthlyPerformancePay: monthlyPerf,
                annualVariablePay: annualVar,
                customAllowances: customAllowancesNotifier.value,
                variablePayFrequency: varFreqNotifier.value,
                variablePayStartMonth: varStartMonthNotifier.value,
                variablePayCustomMonths: varCustomMonthsNotifier.value,
                isPerformancePayPartial: perfPartialNotifier.value,
                performancePayAmounts: perfAmounts,
                isVariablePayPartial: varPartialNotifier.value,
                variablePayAmounts: varAmounts,
                stoppedMonths: stoppedMonthsNotifier.value,
                monthlyEmployeePF: (double.tryParse(pfCtrl.text) ?? 0) / 12,
                monthlyGratuity: (double.tryParse(gratuityCtrl.text) ?? 0) / 12,
                customDeductions: customDeductionsNotifier.value,
              );

              setState(() {
                final newHistory =
                    List<SalaryStructure>.from(_currentData.salary.history);

                if (existing != null) {
                  final index =
                      newHistory.indexWhere((s) => s.id == existing.id);
                  if (index != -1) newHistory[index] = newStructure;
                } else {
                  newHistory.add(newStructure);
                }

                newHistory
                    .sort((a, b) => b.effectiveDate.compareTo(a.effectiveDate));

                _currentData = _currentData.copyWith(
                    salary: _currentData.salary.copyWith(history: newHistory));
                _hasUnsavedChanges = true;
                _updateSummary();
              });

              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _copySalaryFromPreviousYear() async {
    final prevData =
        ref.read(storageServiceProvider).getTaxYearData(_currentData.year - 1);
    if (prevData == null || prevData.salary.history.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('No salary data found in previous year')),
        );
      }
      return;
    }

    // Map to new IDs to avoid conflicts
    final newHistory = prevData.salary.history.map((s) {
      return s.copyWith(
          id: DateTime.now().millisecondsSinceEpoch.toString() + s.id);
    }).toList();

    setState(() {
      _currentData = _currentData.copyWith(
        salary: _currentData.salary.copyWith(
          history: [..._currentData.salary.history, ...newHistory],
        ),
      );
    });
    _updateSummary();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Copied ${newHistory.length} structures')),
      );
    }
  }

  Future<void> _copyHousePropFromPreviousYear() async {
    final prevData =
        ref.read(storageServiceProvider).getTaxYearData(_currentData.year - 1);
    if (prevData == null || prevData.houseProperties.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('No house properties found in previous year')),
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
            content:
                Text('Copied ${prevData.houseProperties.length} properties')),
      );
    }
  }

  Future<List<int>?> _showMonthMultiSelect(
      BuildContext context, List<int> selected) async {
    final months = [4, 5, 6, 7, 8, 9, 10, 11, 12, 1, 2, 3];
    List<int> current = List.from(selected);

    return await showDialog<List<int>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateSB) => AlertDialog(
          title: const Text('Select Months'),
          content: SingleChildScrollView(
            child: Wrap(
              spacing: 8,
              children: months.map((m) {
                final isSelected = current.contains(m);
                return FilterChip(
                  label: Text(DateFormat('MMM').format(DateTime(2023, m, 1))),
                  selected: isSelected,
                  onSelected: (v) {
                    setStateSB(() {
                      if (v) {
                        current.add(m);
                      } else {
                        current.remove(m);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, current),
                child: const Text('Done')),
          ],
        ),
      ),
    );
  }

  void _addCustomAllowanceDialog(
      BuildContext parentCtx, Function(CustomAllowance) onAdd) {
    final nameCtrl = TextEditingController();
    final amtCtrl = TextEditingController();
    final isPartialNotifier = ValueNotifier<bool>(false);

    // Frequency state
    final freqNotifier =
        ValueNotifier<PayoutFrequency>(PayoutFrequency.monthly);
    final startMonthNotifier = ValueNotifier<int?>(null);
    final customMonthsNotifier = ValueNotifier<List<int>>([]);

    showDialog(
      context: parentCtx,
      builder: (ctx) => StatefulBuilder(builder: (context, setStateSB) {
        return AlertDialog(
          title: const Text('Add Custom Allowance'),
          content: SingleChildScrollView(
              child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Allowance Name'),
              ),
              TextField(
                controller: amtCtrl,
                decoration:
                    const InputDecoration(labelText: 'Annual Payout Amount'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}$')),
                ],
              ),
              const SizedBox(height: 12),
              // Frequency UI
              ValueListenableBuilder<PayoutFrequency>(
                valueListenable: freqNotifier,
                builder: (context, freq, _) {
                  return Column(
                    children: [
                      InputDecorator(
                        decoration: const InputDecoration(
                            labelText: 'Payout Frequency',
                            contentPadding:
                                EdgeInsets.symmetric(horizontal: 8)),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<PayoutFrequency>(
                            value: freq,
                            isDense: true,
                            items: PayoutFrequency.values.map((f) {
                              String text = f.toString().split('.').last;
                              text = text[0].toUpperCase() + text.substring(1);
                              if (f == PayoutFrequency.trimester) {
                                text = 'Trimester (4mo)';
                              }
                              return DropdownMenuItem(
                                  value: f, child: Text(text));
                            }).toList(),
                            onChanged: (v) {
                              if (v != null) {
                                freqNotifier.value = v;
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (freq != PayoutFrequency.monthly) ...[
                        if (freq == PayoutFrequency.custom)
                          OutlinedButton(
                            onPressed: () async {
                              final selected = await _showMonthMultiSelect(
                                  context, customMonthsNotifier.value);
                              if (selected != null) {
                                customMonthsNotifier.value = selected;
                              }
                            },
                            child: ValueListenableBuilder<List<int>>(
                              valueListenable: customMonthsNotifier,
                              builder: (c, list, _) => Text(list.isEmpty
                                  ? 'Select Months'
                                  : '${list.length} Months Selected'),
                            ),
                          )
                        else
                          ValueListenableBuilder<int?>(
                            valueListenable: startMonthNotifier,
                            builder: (ctx, startM, _) => InputDecorator(
                              decoration: InputDecoration(
                                labelText: freq == PayoutFrequency.annually
                                    ? 'Payout Month'
                                    : 'Start Month',
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  value: startM,
                                  isDense: true,
                                  items: [4, 5, 6, 7, 8, 9, 10, 11, 12, 1, 2, 3]
                                      .map((m) => DropdownMenuItem(
                                            value: m,
                                            child: Text(DateFormat('MMM')
                                                .format(DateTime(2023, m, 1))),
                                          ))
                                      .toList(),
                                  onChanged: (v) =>
                                      startMonthNotifier.value = v,
                                ),
                              ),
                            ),
                          ),
                      ]
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              ValueListenableBuilder<bool>(
                valueListenable: isPartialNotifier,
                builder: (context, val, _) => CheckboxListTile(
                  title: const Text('Is Partial / Irregular?'),
                  subtitle: const Text('Requires monthly input on main screen'),
                  value: val,
                  onChanged: (v) => isPartialNotifier.value = v ?? false,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ),
            ],
          )),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () {
                  if (nameCtrl.text.isEmpty) return;
                  final inputAmount = double.tryParse(amtCtrl.text) ?? 0;

                  // Calculate payout amount based on frequency
                  double payoutAmount = inputAmount;
                  if (freqNotifier.value == PayoutFrequency.monthly) {
                    payoutAmount = inputAmount / 12;
                  }
                  // For other frequencies, the "Annual Amount" entered might be the payout amount?
                  // User said "accept annual payouts". Usually means "I will get X per year".
                  // If it's a bonus, Annual Amount = Payout Amount.
                  // If it's a monthly allowance, Annual Amount / 12 = Payout Amount.

                  // Auto-fill partial amounts if partial is selected
                  Map<int, double> partialAmounts = {};
                  if (isPartialNotifier.value) {
                    for (int m = 1; m <= 12; m++) {
                      partialAmounts[m] = payoutAmount;
                    }
                  }

                  onAdd(CustomAllowance(
                    name: nameCtrl.text,
                    payoutAmount: payoutAmount,
                    isPartial: isPartialNotifier.value,
                    frequency: freqNotifier.value,
                    startMonth: startMonthNotifier.value,
                    customMonths: customMonthsNotifier.value,
                    partialAmounts: partialAmounts,
                  ));
                  Navigator.pop(ctx);
                },
                child: const Text('Add')),
          ],
        );
      }),
    );
  }

  void _addCustomDeductionDialog(
      {CustomDeduction? existing, required Function(CustomDeduction) onAdd}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final amtCtrl = TextEditingController(
        text: existing != null ? existing.amount.toString() : '');
    final isTaxableNotifier = ValueNotifier<bool>(existing?.isTaxable ?? false);
    final freqNotifier = ValueNotifier<PayoutFrequency>(
        existing?.frequency ?? PayoutFrequency.monthly);
    final startMonthNotifier = ValueNotifier<int?>(existing?.startMonth ?? 4);
    final customMonthsNotifier =
        ValueNotifier<List<int>>(existing?.customMonths ?? []);
    final isPartialNotifier = ValueNotifier<bool>(existing?.isPartial ?? false);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (context, setStateBuilder) {
        return AlertDialog(
          title: Text(existing == null ? 'Add Deduction' : 'Edit Deduction'),
          content: SingleChildScrollView(
              child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: nameCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Deduction Name')),
              TextField(
                controller: amtCtrl,
                decoration: const InputDecoration(
                    labelText: 'Annual Amount',
                    helperText:
                        'For monthly, total yearly. For others, payout amt.'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}$')),
                ],
              ),
              const SizedBox(height: 16),
              ValueListenableBuilder<bool>(
                valueListenable: isTaxableNotifier,
                builder: (context, val, _) => SwitchListTile(
                  title: const Text('Taxable?'),
                  subtitle: const Text(
                      'Reduces taxable gross before tax calculation'),
                  value: val,
                  onChanged: (v) => isTaxableNotifier.value = v,
                ),
              ),
              const SizedBox(height: 12),
              ValueListenableBuilder<PayoutFrequency>(
                valueListenable: freqNotifier,
                builder: (context, val, _) => Column(
                  children: [
                    DropdownButtonFormField<PayoutFrequency>(
                      decoration: const InputDecoration(labelText: 'Frequency'),
                      initialValue: val,
                      items: PayoutFrequency.values
                          .map((f) => DropdownMenuItem(
                              value: f, child: Text(f.name.toUpperCase())))
                          .toList(),
                      onChanged: (v) => freqNotifier.value = v!,
                    ),
                    if (val == PayoutFrequency.custom) ...[
                      const SizedBox(height: 8),
                      ValueListenableBuilder<List<int>>(
                        valueListenable: customMonthsNotifier,
                        builder: (context, list, _) => InkWell(
                          onTap: () async {
                            final selected =
                                await _showMonthMultiSelect(context, list);
                            if (selected != null) {
                              customMonthsNotifier.value = selected;
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                                labelText: 'Select Months'),
                            child: Text(list.isEmpty
                                ? 'None'
                                : '${list.length} months'),
                          ),
                        ),
                      ),
                    ] else if (val != PayoutFrequency.monthly) ...[
                      const SizedBox(height: 8),
                      ValueListenableBuilder<int?>(
                        valueListenable: startMonthNotifier,
                        builder: (context, smth, _) =>
                            DropdownButtonFormField<int>(
                          decoration:
                              const InputDecoration(labelText: 'Start Month'),
                          initialValue: smth,
                          items: [4, 5, 6, 7, 8, 9, 10, 11, 12, 1, 2, 3]
                              .map((m) => DropdownMenuItem(
                                    value: m,
                                    child: Text(DateFormat('MMM')
                                        .format(DateTime(2023, m, 1))),
                                  ))
                              .toList(),
                          onChanged: (v) => startMonthNotifier.value = v,
                        ),
                      ),
                    ]
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ValueListenableBuilder<bool>(
                valueListenable: isPartialNotifier,
                builder: (context, val, _) => CheckboxListTile(
                  title: const Text('Is Partial / Irregular?'),
                  value: val,
                  onChanged: (v) => isPartialNotifier.value = v ?? false,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ),
            ],
          )),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () {
                  if (nameCtrl.text.isEmpty) return;
                  final inputAmount = double.tryParse(amtCtrl.text) ?? 0;
                  double payoutAmount = inputAmount;
                  if (freqNotifier.value == PayoutFrequency.monthly) {
                    payoutAmount = inputAmount / 12;
                  }

                  Map<int, double> partialAmounts = {};
                  if (isPartialNotifier.value) {
                    for (int m = 1; m <= 12; m++) {
                      partialAmounts[m] = payoutAmount;
                    }
                  }

                  onAdd(CustomDeduction(
                    name: nameCtrl.text,
                    amount: payoutAmount,
                    isTaxable: isTaxableNotifier.value,
                    frequency: freqNotifier.value,
                    startMonth: startMonthNotifier.value,
                    customMonths: customMonthsNotifier.value,
                    isPartial: isPartialNotifier.value,
                    partialAmounts: partialAmounts,
                  ));
                  Navigator.pop(ctx);
                },
                child: const Text('Add')),
          ],
        );
      }),
    );
  }

  void _showCTCEstimator(
      TextEditingController basicCtrl, TextEditingController fixedCtrl) {
    final targetCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Estimate Split (Annual)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'Enter expected Annual CTC / Gross. We will split it 50% Basic, 50% Fixed Allowances.'),
            const SizedBox(height: 16),
            TextField(
              controller: targetCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}$')),
              ],
              decoration: const InputDecoration(
                  labelText: 'Annual CTC', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () {
                final target = double.tryParse(targetCtrl.text) ?? 0;
                if (target > 0) {
                  // Split 50-50
                  basicCtrl.text = (target * 0.5).toStringAsFixed(0);
                  fixedCtrl.text = (target * 0.5).toStringAsFixed(0);
                }
                Navigator.pop(ctx);
              },
              child: const Text('Apply')),
        ],
      ),
    );
  }

  double _calculateAnnualGross(List<SalaryStructure> history) {
    if (history.isEmpty) return 0;

    final sortedHistory = List<SalaryStructure>.from(history)
      ..sort((a, b) => a.effectiveDate.compareTo(b.effectiveDate));

    final rules =
        ref.read(taxConfigServiceProvider).getRulesForYear(_currentData.year);
    final startMonth = rules.financialYearStartMonth;

    // Build the month sequence based on FY Start
    List<int> monthOrder = [];
    for (int i = 0; i < 12; i++) {
      int m = (startMonth + i) > 12 ? (startMonth + i - 12) : (startMonth + i);
      monthOrder.add(m);
    }

    double totalAnnualGross = 0;
    int fyStartYear = _currentData.year;
    // Removed incorrect subtraction of 1 year.
    // _currentData.year is FY Start Year (e.g. 2025 for FY 25-26).
    // if (startMonth > 1) fyStartYear -= 1;

    for (int m in monthOrder) {
      int y = (m >= startMonth) ? fyStartYear : fyStartYear + 1;
      // Handle Jan/Feb/Mar edge case if startMonth > 3
      if (startMonth > 1 &&
          m < startMonth &&
          m >= 1 &&
          m <= 3 &&
          fyStartYear == _currentData.year) {
        // This logic depends on how _currentData.year is defined (AY or FY)
        // Usually year is FY Start Year.
      }

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
}
