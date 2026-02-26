import 'package:samriddhi_flow/utils/regex_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samriddhi_flow/models/taxes/tax_data.dart';
import 'package:samriddhi_flow/models/taxes/tax_data_models.dart';
import 'package:samriddhi_flow/models/loan.dart';
import 'package:samriddhi_flow/widgets/pure_icons.dart';
import 'dart:math';

import 'package:samriddhi_flow/services/taxes/tax_config_service.dart';
import 'package:samriddhi_flow/services/taxes/indian_tax_service.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:samriddhi_flow/utils/currency_utils.dart';

const employerPaidText = 'Employer Paid';
const selectMonthsText = 'Select Months';

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
  List<CustomExemption> _independentExemptions = [];
  List<CustomAllowance> _independentDeductions = [];

  // Controllers for Other Income / Agri / Tax
  late TextEditingController _otherIncomeNameCtrl;
  late TextEditingController _otherIncomeAmtCtrl;
  late TextEditingController _advanceTaxCtrl;
  late TextEditingController _agriIncomeCtrl;

  // Local state for lists
  List<TaxPaymentEntry> _tdsEntries = [];
  List<TaxPaymentEntry> _tcsEntries = [];

  bool _hasUnsavedChanges = false;
  bool _useCompactNumberFormat = true;
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
    _independentExemptions =
        List.from(_currentData.salary.independentExemptions);
    _independentDeductions =
        List.from(_currentData.salary.independentDeductions);
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
        independentExemptions: _independentExemptions,
        independentDeductions: _independentDeductions,
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
    final newSalary = _currentData.salary.copyWith(
      grossSalary: finalGross,
      npsEmployer: (double.tryParse(_salaryNpsEmployerCtrl.text) ?? 0),
      leaveEncashment: (double.tryParse(_salaryLeaveEncashCtrl.text) ?? 0),
      gratuity: (double.tryParse(_salaryGratuityCtrl.text) ?? 0),
      giftsFromEmployer: (double.tryParse(_salaryEmployerGiftsCtrl.text) ?? 0),
      monthlyGross: const {}, // No longer projecting monthly
      independentAllowances: _independentAllowances,
      independentExemptions: _independentExemptions,
      independentDeductions: _independentDeductions,
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

  Future<void> _clearTaxData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Clear FY ${_currentData.year} Data?'),
        content: const Text(
            'This will permanently delete all tax details for this financial year.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      widget.onDelete?.call();
      if (mounted) {
        setState(() => _hasUnsavedChanges = false);
        Navigator.pop(context);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Tax data cleared.')));
      }
    }
  }

  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
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
          actions: _buildAppBarActions(context),
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

  List<Widget> _buildAppBarActions(BuildContext context) {
    return [
      ..._buildAddAction(),
      ..._buildCopyAction(),
      if (widget.onDelete != null)
        IconButton(
          icon: PureIcons.delete(),
          tooltip: 'Clear Data for FY',
          onPressed: _clearTaxData,
        ),
      IconButton(
          icon: PureIcons.save(), onPressed: _save, tooltip: 'Save Changes'),
    ];
  }

  List<Widget> _buildAddAction() {
    switch (_selectedIndex) {
      case 0:
        return [
          IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'Add Salary Structure',
              onPressed: () => _editSalaryStructure(null))
        ];
      case 1:
        return [
          IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'Add Property',
              onPressed: () => _addHousePropertyDialog())
        ];
      case 2:
        return [
          IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'Add Business',
              onPressed: () => _addBusinessDialog())
        ];
      case 3:
        return [
          IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'Add Capital Gain',
              onPressed: () => _addCGEntryDialog())
        ];
      case 5:
        return [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Add Tax Entry',
            onPressed: () => _showTaxEntryBottomSheet(context),
          )
        ];
      case 6:
        return [
          IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'Add Cash Gift',
              onPressed: () => _addCashGiftDialog())
        ];
      case 8:
        return [
          IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'Add Other Income',
              onPressed: () => _addOtherIncomeDialog())
        ];
      default:
        return [];
    }
  }

  List<Widget> _buildCopyAction() {
    if (_selectedIndex == 0 && _currentData.salary.history.isEmpty) {
      return [
        IconButton(
          icon: const Icon(Icons.copy),
          tooltip: 'Copy Previous Year Data',
          onPressed: _copySalaryFromPreviousYear,
        )
      ];
    }
    if (_selectedIndex == 1 && _houseProperties.isEmpty) {
      return [
        IconButton(
          icon: const Icon(Icons.copy),
          tooltip: 'Copy Previous Year Data',
          onPressed: _copyHousePropFromPreviousYear,
        )
      ];
    }
    return [];
  }

  void _showTaxEntryBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.remove_circle, color: Colors.red),
            title: const Text('Add TDS Entry'),
            onTap: () {
              Navigator.pop(ctx);
              _addTaxEntryDialog(true);
            },
          ),
          ListTile(
            leading: const Icon(Icons.add_circle, color: Colors.green),
            title: const Text('Add TCS Entry'),
            onTap: () {
              Navigator.pop(ctx);
              _addTaxEntryDialog(false);
            },
          ),
        ],
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
        _buildSectionTitle('Custom Ad-hoc Exemptions'),
        _buildIndependentExemptions(),
        const SizedBox(height: 16),
        _buildSalarySummaryCard(),
        const SizedBox(height: 16),
        _buildSectionTitle('TDS / Taxes Already Paid'),
        _buildTdsSummarySection(),
        const SizedBox(height: 16),
        _buildSectionTitle('Independent Deductions'),
        _buildIndependentDeductions(),
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
                onTap: () => _addCustomAllowanceDialog(context, (updated) {
                  setState(() {
                    int idx = _independentAllowances.indexOf(a);
                    _independentAllowances[idx] = updated;
                  });
                  _updateSummary();
                }, existing: a),
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

  Widget _buildIndependentDeductions() {
    return Column(
      children: [
        if (_independentDeductions.isEmpty)
          const Text('No independent deductions',
              style: TextStyle(color: Colors.grey, fontSize: 12))
        else
          ..._independentDeductions.map((a) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(a.name),
                subtitle: Text(
                    '₹${a.payoutAmount.toStringAsFixed(0)} (${a.frequency.name})'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, size: 20),
                  onPressed: () {
                    setState(() => _independentDeductions.remove(a));
                    _updateSummary();
                  },
                ),
                onTap: () => _addCustomAllowanceDialog(context, (updated) {
                  setState(() {
                    int idx = _independentDeductions.indexOf(a);
                    _independentDeductions[idx] = updated;
                  });
                  _updateSummary();
                }, existing: a, isDeduction: true),
              )),
        TextButton.icon(
          onPressed: () => _addCustomAllowanceDialog(context, (a) {
            setState(() => _independentDeductions.add(a));
            _updateSummary();
          }, isDeduction: true),
          icon: const Icon(Icons.add),
          label: const Text('Add Independent Deduction'),
        ),
      ],
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
      agricultureIncome: 0,
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

    final totalTds = _tdsEntries.fold(0.0, (sum, e) => sum + e.amount);

    double refundForecast = 0;
    if (totalTds > newTaxAfterAdhocExemptions &&
        _independentExemptions.isNotEmpty) {
      refundForecast = totalTds - newTaxAfterAdhocExemptions;
    }

    return Column(
      children: [
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text('Total TDS tracked'),
          trailing: Text('₹${totalTds.toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        if (refundForecast > 0)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text('Tax Refund Forecast',
                style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.light
                        ? Colors.green.shade700
                        : Colors.green.shade400)),
            trailing: Text('₹${refundForecast.toStringAsFixed(0)}',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).brightness == Brightness.light
                        ? Colors.green.shade700
                        : Colors.green.shade400)),
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
    double estimatedTax = taxService.calculateSalaryOnlyLiability(_currentData);

    final now = DateTime.now();
    final newEntry = TaxPaymentEntry(
      amount: estimatedTax,
      date: now,
      source: employerPaidText,
      description: 'Auto-sync from salary/tax estimation',
    );

    setState(() {
      _tdsEntries.removeWhere((e) => e.source == employerPaidText);
      _tdsEntries.add(newEntry.copyWith(source: employerPaidText));
    });
    _updateSummary();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Estimated tax liability copied to TDS!')),
    );
  }

  void _addCustomExemptionDialog(
      {CustomExemption? existing, required Function(CustomExemption) onAdd}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');

    final amtCtrl = TextEditingController(
        text: existing != null ? existing.amount.toStringAsFixed(2) : '');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (context, setStateBuilder) {
        return AlertDialog(
          title: Text(existing == null
              ? 'Add Custom Exemption'
              : 'Edit Custom Exemption'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: nameCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Exemption Name')),
                TextField(
                  controller: amtCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Annual Amount',
                      helperText: 'Total yearly amount.'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegexUtils.amountExp)
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (nameCtrl.text.isEmpty) return;
                final amountText = amtCtrl.text.replaceAll(',', '');
                final amount = double.tryParse(amountText) ?? 0;

                final ex = CustomExemption(
                  name: nameCtrl.text,
                  amount: amount,
                );
                onAdd(ex);
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        );
      }),
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
        TextButton.icon(
          onPressed: () {
            setState(() {});
          },
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Refresh Breakdown'),
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

  // Removed _buildConsolidatedAdjustments, _isPayoutMonth, _buildAdjustmentTile, _updatePartialAmount

  Widget _buildSalarySummaryCard() {
    final rules =
        ref.watch(taxConfigServiceProvider).getRulesForYear(_currentData.year);
    final taxService = ref.read(indianTaxServiceProvider);

    // Create a salary-only data object to avoid blending business/HP incomes
    final salaryOnlyData = _currentData.copyWith(
      houseProperties: [],
      businessIncomes: [],
      capitalGains: [],
      otherIncomes: [],
      dividendIncome: const DividendIncome(),
      cashGifts: [],
      agricultureIncome: 0,
    );

    double gross = taxService.calculateSalaryGross(salaryOnlyData, rules);
    double statutoryExemptions =
        taxService.calculateSalaryExemptions(salaryOnlyData, rules);

    double standardDeduction =
        rules.isStdDeductionSalaryEnabled ? rules.stdDeductionSalary : 0;
    double nps = salaryOnlyData.salary.npsEmployer;
    double customExemptions =
        _independentExemptions.fold(0.0, (sum, e) => sum + e.amount);

    double baseTaxableIncome =
        (gross - statutoryExemptions - standardDeduction - nps)
            .clamp(0.0, double.infinity);
    double totalTaxableIncome =
        (baseTaxableIncome - customExemptions).clamp(0.0, double.infinity);

    final bool isLight = Theme.of(context).brightness == Brightness.light;
    final Color deductColor =
        isLight ? Colors.orange.shade800 : Colors.orange.shade300;

    return Card(
      color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
      child: InkWell(
        onTap: () =>
            setState(() => _useCompactNumberFormat = !_useCompactNumberFormat),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Projected Annual Income',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary),
                  ),
                  Icon(
                    _useCompactNumberFormat ? Icons.compress : Icons.expand,
                    size: 14,
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.5),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildSummaryRow('Total Gross Salary:', gross, isBold: true),
              if (standardDeduction > 0)
                _buildSummaryRow('Less: Standard Deduction:', standardDeduction,
                    isDeduction: true, color: deductColor),
              if (statutoryExemptions > 0)
                _buildSummaryRow(
                    'Less: Statutory Exemptions:', statutoryExemptions,
                    isDeduction: true, color: deductColor),
              if (nps > 0)
                _buildSummaryRow('Less: Employer NPS (80CCD(2)):', nps,
                    isDeduction: true, color: deductColor),
              if (customExemptions > 0) ...[
                const Divider(),
                _buildSummaryRow(
                    'Taxable Before Ad-hoc Exemptions:', baseTaxableIncome,
                    isBold: true, fontSize: 13),
                _buildSummaryRow(
                    'Less: Custom Ad-hoc Exemptions:', customExemptions,
                    isDeduction: true, color: deductColor),
              ],
              const Divider(),
              _buildSummaryRow(
                  'Total Taxable Salary Income:', totalTaxableIncome,
                  isBold: true,
                  fontSize: 18,
                  color: Theme.of(context).colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, double value,
      {bool isBold = false,
      bool isDeduction = false,
      double fontSize = 12,
      Color? color}) {
    final locale = ref.read(currencyProvider);
    final formattedValue = _useCompactNumberFormat
        ? CurrencyUtils.getSmartFormat(value, locale)
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
      if (s.effectiveDate.isBefore(date) ||
          s.effectiveDate.isAtSameMomentAs(date)) {
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
      BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(labelText: 'Property Name')),
        CheckboxListTile(
          title: const Text('Self Occupied?'),
          value: isSelf,
          onChanged: (v) => onSelfChanged(v ?? true),
        ),
        if (!isSelf) ...[
          TextField(
              controller: rentCtrl,
              decoration: const InputDecoration(
                  labelText: 'Annual Rent Received (Gross)'),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegexUtils.amountExp),
              ]),
          TextField(
              controller: taxCtrl,
              decoration:
                  const InputDecoration(labelText: 'Municipal Taxes Paid'),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegexUtils.amountExp),
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
            padding: const EdgeInsets.only(top: 8.0),
            child: Text('Interest will be calculated from selected loan.',
                style: TextStyle(
                    color: Theme.of(context).primaryColor, fontSize: 12)),
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

    String? selectedLoanId = existing?.loanId;
    bool isSelf = existing?.isSelfOccupied ?? true;

    final loansAsync = ref.watch(loansProvider);
    final loans = loansAsync.value ?? [];

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
          onSelfChanged: (v) => setStateBuilder(() => isSelf = v),
          onLoanChanged: (v) => setStateBuilder(() => selectedLoanId = v),
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
  }) {
    return AlertDialog(
      title: Text(existing == null ? 'Add Property' : 'Edit Property'),
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
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
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
            );
          },
          child: const Text('Save'),
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
  }) {
    final newHP = HouseProperty(
      name: nameCtrl.text,
      isSelfOccupied: isSelf,
      rentReceived: double.tryParse(rentCtrl.text) ?? 0,
      municipalTaxes: double.tryParse(taxCtrl.text) ?? 0,
      interestOnLoan: selectedLoanId != null
          ? 0
          : (double.tryParse(intCtrl.text) ??
              0), // If linked, 0 placeholder until sync
      loanId: selectedLoanId,
    );

    setState(() {
      if (existing != null && index != null) {
        _houseProperties[index] = newHP;
      } else {
        _houseProperties.add(newHP);
      }
    });
    _updateSummary();
    Navigator.pop(context);
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
                _buildBusinessTypeDropdown(
                    type, rules, (v) => setStateBuilder(() => type = v!)),
                if (type != BusinessType.regular)
                  _buildTurnoverWarning(turnoverCtrl, type, rules),
                TextField(
                    controller: turnoverCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Gross Turnover / Receipts'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegexUtils.amountExp),
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
                      FilteringTextInputFormatter.allow(RegexUtils.amountExp),
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
                _handleBusinessSave(nameCtrl, turnoverCtrl, netCtrl, type,
                    rules, existing, index);
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildBusinessTypeDropdown(
      BusinessType type, dynamic rules, ValueChanged<BusinessType?> onChanged) {
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Taxation Type',
        helperText: 'Using Section 44AD/ADA for presumptive taxation',
        suffixIcon: Tooltip(
          triggerMode: TooltipTriggerMode.tap,
          showDuration: Duration(seconds: 5),
          padding: EdgeInsets.all(12),
          margin: EdgeInsets.symmetric(horizontal: 20),
          message:
              '• Section 44AD: For Business (6% of Turnover).  • Section 44ADA: For Professionals (50% of Receipts).  • Regular: Actual Profit (Audit required if < limit).',
          child: Icon(Icons.info_outline, color: Colors.blue),
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
      TextEditingController turnoverCtrl, BusinessType type, dynamic rules) {
    return ValueListenableBuilder<TextEditingValue>(
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
    );
  }

  void _handleBusinessSave(
      TextEditingController nameCtrl,
      TextEditingController turnoverCtrl,
      TextEditingController netCtrl,
      BusinessType type,
      dynamic rules,
      BusinessEntity? existing,
      int? index) {
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
  }

  Widget _buildCapitalGainsTab() {
    double stcg = 0;
    double ltcgEquity = 0;
    double ltcgOther = 0;

    for (var gain in _capitalGains) {
      double amt = gain.capitalGainAmount;
      // Determine net gain if reinvested
      if (gain.intendToReinvest) {
        amt = max(0, amt - gain.reinvestedAmount);
      }
      if (gain.isLTCG) {
        if (gain.matchAssetType == AssetType.equityShares) {
          ltcgEquity += amt;
        } else {
          ltcgOther += amt;
        }
      } else {
        stcg += amt;
      }
    }

    return Column(
      children: [
        if (_capitalGains.isNotEmpty)
          Card(
            margin: const EdgeInsets.all(16),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Net Capital Gains Summary',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  _buildSummaryRow('Short Term (STCG)', stcg, isBold: true),
                  _buildSummaryRow('Long Term (Equity)', ltcgEquity,
                      isBold: true),
                  _buildSummaryRow('Long Term (Other)', ltcgOther,
                      isBold: true),
                ],
              ),
            ),
          ),
        Expanded(
          child: _capitalGains.isEmpty
              ? const Center(child: Text('No Capital Gains entries added.'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _capitalGains.length,
                  itemBuilder: (ctx, i) {
                    return _buildCGEntryCard(_capitalGains[i], i);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCGEntryCard(CapitalGainEntry entry, int i) {
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
            Text('Gross: ₹${entry.saleAmount.toStringAsFixed(0)}'),
            if (entry.intendToReinvest) _buildReinvestStatus(entry),
          ],
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showReinvestAction)
              IconButton(
                icon: const Icon(Icons.savings_outlined, color: Colors.orange),
                tooltip: 'Record Reinvestment',
                onPressed: () => _addCGEntryDialog(existing: entry, index: i),
              ),
            Text('Gain: ₹${entry.capitalGainAmount.toStringAsFixed(0)}',
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'edit') {
                  _addCGEntryDialog(existing: entry, index: i);
                } else if (v == 'delete') {
                  setState(() => _capitalGains.removeAt(i));
                  _updateSummary();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
        onTap: () => _addCGEntryDialog(existing: entry, index: i),
      ),
    );
  }

  Widget _buildReinvestStatus(CapitalGainEntry entry) {
    final isPending = entry.matchReinvestType == ReinvestmentType.none;
    final color = isPending ? Colors.orange : Colors.green;
    final icon =
        isPending ? Icons.warning_amber_rounded : Icons.check_circle_outline;
    final text = isPending
        ? 'Reinvestment Pending'
        : 'Reinvested: ₹${entry.reinvestedAmount.toStringAsFixed(0)} to ${entry.matchReinvestType.toHumanReadable()}';

    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(color: color, fontSize: 12)),
      ],
    );
  }

  Widget _buildAssetTooltip(AssetType selectedAsset) {
    if (selectedAsset == AssetType.equityShares) {
      return const Tooltip(
        triggerMode: TooltipTriggerMode.tap,
        showDuration: Duration(seconds: 5),
        padding: EdgeInsets.all(12),
        message:
            'Equity shares or Equity mutual funds (> 65% equity) and STT tax paid.',
        child: Padding(
          padding: EdgeInsets.all(8.0),
          child: Icon(Icons.info_outline, color: Colors.blue, size: 20),
        ),
      );
    }
    if (selectedAsset == AssetType.other) {
      return const Tooltip(
        triggerMode: TooltipTriggerMode.tap,
        showDuration: Duration(seconds: 5),
        padding: EdgeInsets.all(12),
        message:
            'Gold, Debt Funds, International Funds, NPS (Tier-2), Bonds, etc.',
        child: Padding(
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
      StateSetter setStateBuilder,
      ValueChanged<ReinvestmentType> onReinvestTypeChanged,
      ValueChanged<DateTime> onReinvestDateChanged) {
    if (!intendToReinvest) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              onChanged: (v) => onReinvestTypeChanged(v!),
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
              decoration: const InputDecoration(labelText: 'Amount Invested'),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegexUtils.amountExp),
              ]),
          ListTile(
            title: const Text('Reinvest Date'),
            subtitle: Text(reinvestDate == null
                ? 'Select Date'
                : '${reinvestDate.day}/${reinvestDate.month}/${reinvestDate.year}'),
            trailing: const Icon(Icons.calendar_month),
            onTap: () async {
              final d = await showDatePicker(
                  context: context,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2040),
                  initialDate: reinvestDate ?? gainDate);
              if (d != null) onReinvestDateChanged(d);
            },
          ),
        ],
      ],
    );
  }

  void _handleCGSave({
    required TextEditingController descCtrl,
    required AssetType selectedAsset,
    required bool isLtcg,
    required TextEditingController saleCtrl,
    required TextEditingController costCtrl,
    required DateTime gainDate,
    required TextEditingController reinvestCtrl,
    required ReinvestmentType selectedReinvestType,
    required DateTime? reinvestDate,
    required bool intendToReinvest,
    CapitalGainEntry? existing,
    int? index,
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
    );

    setState(() {
      if (existing != null && index != null) {
        _capitalGains[index] = newEntry;
      } else {
        _capitalGains.add(newEntry);
      }
    });
    _updateSummary();
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
                    suffixIcon: _buildAssetTooltip(selectedAsset),
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
                      FilteringTextInputFormatter.allow(RegexUtils.amountExp),
                    ]),
                TextField(
                    controller: costCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Cost of Acquisition'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegexUtils.amountExp),
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
                _buildReinvestmentSection(
                    intendToReinvest,
                    selectedReinvestType,
                    reinvestCtrl,
                    reinvestDate,
                    gainDate,
                    setStateBuilder,
                    (v) => setStateBuilder(() => selectedReinvestType = v),
                    (d) => setStateBuilder(() => reinvestDate = d)),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () {
                  _handleCGSave(
                    descCtrl: descCtrl,
                    selectedAsset: selectedAsset,
                    isLtcg: isLtcg,
                    saleCtrl: saleCtrl,
                    costCtrl: costCtrl,
                    gainDate: gainDate,
                    reinvestCtrl: reinvestCtrl,
                    selectedReinvestType: selectedReinvestType,
                    reinvestDate: reinvestDate,
                    intendToReinvest: intendToReinvest,
                    existing: existing,
                    index: index,
                  );
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
                              RegexUtils.amountExp),
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
        FilteringTextInputFormatter.allow(RegexUtils.amountExp),
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
      title: Text(() {
        if (entry.source.isNotEmpty) return entry.source;
        return isTds ? 'TDS Entry' : 'TCS Entry';
      }()),
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
                  FilteringTextInputFormatter.allow(RegexUtils.amountExp),
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
                _handleTaxEntrySave(amtCtrl, srcCtrl, pickedDate, isTds);
                Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _handleTaxEntrySave(TextEditingController amtCtrl,
      TextEditingController srcCtrl, DateTime pickedDate, bool isTds) {
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
                    FilteringTextInputFormatter.allow(RegexUtils.amountExp),
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
                    FilteringTextInputFormatter.allow(RegexUtils.amountExp),
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
                text = text[0].toUpperCase() + text.substring(1);
                if (f == PayoutFrequency.trimester) text = 'Trimester (4mo)';
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
              return _buildCustomMonthsButton(
                  customMonthsNotifier, context, selectMonthsText);
            }
            return _buildStartMonthDropdown(freq, startMonthNotifier);
          },
        ),
      ],
    );
  }

  Widget _buildCustomMonthsButton(ValueNotifier<List<int>> customMonthsNotifier,
      BuildContext context, String selectMonthsText) {
    return OutlinedButton(
      onPressed: () async {
        final selected =
            await _showMonthMultiSelect(context, customMonthsNotifier.value);
        if (selected != null) customMonthsNotifier.value = selected;
      },
      child: ValueListenableBuilder<List<int>>(
        valueListenable: customMonthsNotifier,
        builder: (c, list, _) => Text(
            list.isEmpty ? selectMonthsText : '${list.length} Months Selected'),
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
                ? 'Payout Month'
                : 'Start Month',
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
          onChanged: (v) => startMonthNotifier.value = v,
        );
      },
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

    // Define helper first

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
              _buildSalaryCoreFields(
                  effectiveDateNotifier, basicCtrl, fixedCtrl),
              const SizedBox(height: 16),
              _buildSalaryPaySections(
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
                context: context,
              ),
              _buildSalaryDeductionSections(
                  pfCtrl, gratuityCtrl, stoppedMonthsNotifier, context),
              _buildStoppedMonthsSection(stoppedMonthsNotifier, context),
              _buildSalaryAllowancesSection(context, customAllowancesNotifier),
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
            onPressed: () => _onSaveSalaryStructure(
              ctx: ctx,
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
          title: const Text(selectMonthsText),
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
      BuildContext parentCtx, Function(CustomAllowance) onAdd,
      {CustomAllowance? existing, bool isDeduction = false}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');

    double initialAmount = _calculateInitialAnnualAmount(existing);

    final amtCtrl = TextEditingController(
        text: existing != null ? initialAmount.toStringAsFixed(2) : '');
    // Note: Input field says "Annual Payout Amount".
    // If Monthly, logic divides by 12.
    // If existing, we should probably reverse logic or just show existing amount?
    // Let's assume stored amount is what we show.
    final isPartialNotifier = ValueNotifier<bool>(existing?.isPartial ?? false);
    final freqNotifier = ValueNotifier<PayoutFrequency>(
        existing?.frequency ?? PayoutFrequency.monthly);
    final startMonthNotifier = ValueNotifier<int?>(existing?.startMonth ?? 4);
    final customMonthsNotifier =
        ValueNotifier<List<int>>(existing?.customMonths ?? []);

    // PARTIAL PAY Helpers
    final partialAmountsNotifier = ValueNotifier<Map<int, double>>(
        Map.from(existing?.partialAmounts ?? {}));

    Widget buildPartialGrid() => _buildAllowancePartialGrid(
          freqNotifier: freqNotifier,
          startMonthNotifier: startMonthNotifier,
          customMonthsNotifier: customMonthsNotifier,
          amtCtrl: amtCtrl,
          partialAmountsNotifier: partialAmountsNotifier,
        );

    showDialog(
      context: parentCtx,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateSB) => AlertDialog(
          title: Text(_getAllowanceDialogTitle(existing, isDeduction)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                      labelText:
                          isDeduction ? 'Deduction Name' : 'Allowance Name'),
                ),
                TextField(
                  controller: amtCtrl,
                  decoration: InputDecoration(
                      labelText: isDeduction
                          ? 'Annual Deduction Amount'
                          : 'Annual Payout Amount'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegexUtils.amountExp)
                  ],
                ),
                const SizedBox(height: 12),
                _buildFrequencySection(ctx, freqNotifier, customMonthsNotifier,
                    startMonthNotifier),
                const SizedBox(height: 12),
                _buildPartialSection(isPartialNotifier, buildPartialGrid),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () => _onAddCustomAllowance(
                ctx: ctx,
                nameCtrl: nameCtrl,
                amtCtrl: amtCtrl,
                freqNotifier: freqNotifier,
                isPartialNotifier: isPartialNotifier,
                startMonthNotifier: startMonthNotifier,
                customMonthsNotifier: customMonthsNotifier,
                partialAmountsNotifier: partialAmountsNotifier,
                onAdd: onAdd,
              ),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _onAddCustomAllowance({
    required BuildContext ctx,
    required TextEditingController nameCtrl,
    required TextEditingController amtCtrl,
    required ValueNotifier<PayoutFrequency> freqNotifier,
    required ValueNotifier<bool> isPartialNotifier,
    required ValueNotifier<int?> startMonthNotifier,
    required ValueNotifier<List<int>> customMonthsNotifier,
    required ValueNotifier<Map<int, double>> partialAmountsNotifier,
    required Function(CustomAllowance) onAdd,
  }) {
    if (nameCtrl.text.isEmpty) return;
    final inputAmount = double.tryParse(amtCtrl.text) ?? 0;
    final freq = freqNotifier.value;
    final payoutAmount =
        _calculatePayoutAmount(inputAmount, freq, customMonthsNotifier.value);

    onAdd(CustomAllowance(
      name: nameCtrl.text,
      payoutAmount: payoutAmount,
      isPartial: isPartialNotifier.value,
      frequency: freq,
      startMonth: startMonthNotifier.value,
      customMonths: customMonthsNotifier.value,
      partialAmounts: partialAmountsNotifier.value,
    ));
    Navigator.pop(ctx);
  }

  double _calculateInitialAnnualAmount(CustomAllowance? existing) {
    if (existing == null) return 0;
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
      default:
        return amount;
    }
  }

  double _calculatePayoutAmount(
      double annualAmount, PayoutFrequency freq, List<int> customMonths) {
    switch (freq) {
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
      default:
        return annualAmount;
    }
  }

  Widget _buildAllowancePartialGrid({
    required ValueNotifier<PayoutFrequency> freqNotifier,
    required ValueNotifier<int?> startMonthNotifier,
    required ValueNotifier<List<int>> customMonthsNotifier,
    required TextEditingController amtCtrl,
    required ValueNotifier<Map<int, double>> partialAmountsNotifier,
  }) {
    return ValueListenableBuilder<PayoutFrequency>(
        valueListenable: freqNotifier,
        builder: (context, freq, _) {
          return ValueListenableBuilder<int?>(
              valueListenable: startMonthNotifier,
              builder: (ctx, startMonth, _) {
                return ValueListenableBuilder<List<int>>(
                    valueListenable: customMonthsNotifier,
                    builder: (ctx, customMonths, _) {
                      final applicable =
                          _getApplicableMonths(freq, startMonth, customMonths);
                      if (applicable.isEmpty) return const SizedBox.shrink();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          const Text('Monthly Amounts (₹):',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: applicable.map((m) {
                              final inputAmt =
                                  double.tryParse(amtCtrl.text) ?? 0;
                              final defaultPayout = _calculatePayoutAmount(
                                  inputAmt, freq, customMonths);
                              final val = partialAmountsNotifier.value[m] ??
                                  defaultPayout;

                              return SizedBox(
                                width: 80,
                                child: TextField(
                                  decoration: InputDecoration(
                                      labelText: DateFormat('MMM')
                                          .format(DateTime(2023, m, 1)),
                                      isDense: true,
                                      border: const OutlineInputBorder()),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  controller: TextEditingController(
                                      text: val.toStringAsFixed(0)),
                                  onChanged: (v) => partialAmountsNotifier
                                      .value[m] = double.tryParse(v) ?? 0,
                                ),
                              );
                            }).toList(),
                          )
                        ],
                      );
                    });
              });
        });
  }

  List<int> _getApplicableMonths(
      PayoutFrequency freq, int? startMonth, List<int> customMonths) {
    List<int> months = [];
    for (int m = 1; m <= 12; m++) {
      if (SalaryStructure.isPayoutMonth(m, freq, startMonth, customMonths)) {
        months.add(m);
      }
    }
    return months;
  }

  double _calculateAnnualGross(List<SalaryStructure> history) {
    if (history.isEmpty) return 0;

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
    if (existing == null) {
      return isDeduction
          ? 'Add Independent Deduction'
          : 'Add Independent Allowance';
    }
    return isDeduction
        ? 'Edit Independent Deduction'
        : 'Edit Independent Allowance';
  }

  Widget _buildFrequencySection(
    BuildContext ctx,
    ValueNotifier<PayoutFrequency> freqNotifier,
    ValueNotifier<List<int>> customMonthsNotifier,
    ValueNotifier<int?> startMonthNotifier,
  ) {
    return ValueListenableBuilder<PayoutFrequency>(
      valueListenable: freqNotifier,
      builder: (context, freq, _) {
        return Column(
          children: [
            InputDecorator(
              decoration: const InputDecoration(
                  labelText: 'Payout Frequency',
                  contentPadding: EdgeInsets.symmetric(horizontal: 8)),
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
                    return DropdownMenuItem(value: f, child: Text(text));
                  }).toList(),
                  onChanged: (v) => v != null ? freqNotifier.value = v : null,
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (freq != PayoutFrequency.monthly)
              _buildAdjustableStartMonth(
                  ctx, freq, customMonthsNotifier, startMonthNotifier),
          ],
        );
      },
    );
  }

  Widget _buildAdjustableStartMonth(
    BuildContext ctx,
    PayoutFrequency freq,
    ValueNotifier<List<int>> customMonthsNotifier,
    ValueNotifier<int?> startMonthNotifier,
  ) {
    if (freq == PayoutFrequency.custom) {
      return OutlinedButton(
        onPressed: () async {
          final selected =
              await _showMonthMultiSelect(ctx, customMonthsNotifier.value);
          if (selected != null) customMonthsNotifier.value = selected;
        },
        child: ValueListenableBuilder<List<int>>(
          valueListenable: customMonthsNotifier,
          builder: (c, list, _) => Text(list.isEmpty
              ? selectMonthsText
              : '${list.length} Months Selected'),
        ),
      );
    }
    return ValueListenableBuilder<int?>(
      valueListenable: startMonthNotifier,
      builder: (ctx, startM, _) => InputDecorator(
        decoration: InputDecoration(
          labelText:
              freq == PayoutFrequency.annually ? 'Payout Month' : 'Start Month',
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            value: startM,
            isDense: true,
            items: [4, 5, 6, 7, 8, 9, 10, 11, 12, 1, 2, 3]
                .map((m) => DropdownMenuItem(
                      value: m,
                      child:
                          Text(DateFormat('MMM').format(DateTime(2023, m, 1))),
                    ))
                .toList(),
            onChanged: (v) => startMonthNotifier.value = v,
          ),
        ),
      ),
    );
  }

  Widget _buildPartialSection(ValueNotifier<bool> isPartialNotifier,
      Widget Function() buildPartialGrid) {
    return ValueListenableBuilder<bool>(
      valueListenable: isPartialNotifier,
      builder: (context, val, _) => Column(
        children: [
          CheckboxListTile(
            title: const Text('Is Partial / Irregular?'),
            subtitle: const Text('View/Edit specific monthly amounts'),
            value: val,
            onChanged: (v) => isPartialNotifier.value = v ?? false,
            controlAffinity: ListTileControlAffinity.leading,
          ),
          if (val) buildPartialGrid(),
        ],
      ),
    );
  }

  Widget _buildSalaryPartialGrid(
      ValueNotifier<Map<int, double>> amountsNotifier,
      ValueNotifier<PayoutFrequency> freqNotifier,
      ValueNotifier<int?> startMonthNotifier,
      ValueNotifier<List<int>> customMonthsNotifier,
      double defaultAmount) {
    return ValueListenableBuilder<PayoutFrequency>(
      valueListenable: freqNotifier,
      builder: (context, freq, _) {
        return ValueListenableBuilder<int?>(
          valueListenable: startMonthNotifier,
          builder: (context, startMonth, _) {
            return ValueListenableBuilder<List<int>>(
              valueListenable: customMonthsNotifier,
              builder: (context, customMonths, _) {
                List<int> applicableMonths = [];
                for (int m = 1; m <= 12; m++) {
                  if (SalaryStructure.isPayoutMonth(
                      m, freq, startMonth, customMonths)) {
                    applicableMonths.add(m);
                  }
                }

                if (applicableMonths.isEmpty) {
                  return const Text(
                      'No payout months selected based on frequency.');
                }

                return Column(
                  children: [
                    const Text(
                        'Enter amounts for each payout month (overrides default):',
                        style: TextStyle(
                            fontSize: 12, fontStyle: FontStyle.italic)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: applicableMonths.map((m) {
                        final currentVal =
                            amountsNotifier.value[m] ?? defaultAmount;
                        return SizedBox(
                          width: 100,
                          child: TextField(
                            decoration: InputDecoration(
                              labelText: DateFormat('MMM')
                                  .format(DateTime(2023, m, 1)),
                              isDense: true,
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.all(8),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegexUtils.amountExp)
                            ],
                            controller: TextEditingController(
                                text: currentVal.toStringAsFixed(0))
                              ..selection = TextSelection.collapsed(
                                  offset: currentVal.toStringAsFixed(0).length),
                            onChanged: (val) {
                              final d = double.tryParse(val) ?? 0;
                              final newMap =
                                  Map<int, double>.from(amountsNotifier.value);
                              newMap[m] = d;
                              amountsNotifier.value = newMap;
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildStoppedMonthsSection(
      ValueNotifier<List<int>> stoppedMonthsNotifier, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                final selected = await _showMonthMultiSelect(context, list);
                if (selected != null) {
                  stoppedMonthsNotifier.value = selected;
                }
              },
              icon: const Icon(Icons.block),
              label: Text(list.isEmpty
                  ? 'Select Stopped Months'
                  : '${list.length} Months Stopped'),
              style: list.isNotEmpty
                  ? OutlinedButton.styleFrom(foregroundColor: Colors.orange)
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
                if (picked != null) effectiveDateNotifier.value = picked;
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
              floatingLabelBehavior: FloatingLabelBehavior.always),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegexUtils.amountExp)
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
        InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Annual Performance Pay',
            helperText: 'Max amount per year',
            border: OutlineInputBorder(),
            floatingLabelBehavior: FloatingLabelBehavior.always,
          ),
          child: TextField(
            controller: perfCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegexUtils.amountExp)
            ],
            decoration:
                const InputDecoration(isDense: true, border: InputBorder.none),
          ),
        ),
        const SizedBox(height: 24),
        _buildFrequencyRow('Payout', perfFreqNotifier, perfStartMonthNotifier,
            perfCustomMonthsNotifier, context, selectMonthsText),
        ValueListenableBuilder<bool>(
          valueListenable: perfPartialNotifier,
          builder: (context, isPartial, _) {
            return Column(
              children: [
                CheckboxListTile(
                  title: const Text('Partial Payout / Taxable Factor?'),
                  subtitle: isPartial
                      ? null
                      : const Text('Default: Equal distribution'),
                  value: isPartial,
                  onChanged: (v) => perfPartialNotifier.value = v ?? false,
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                ),
                if (isPartial)
                  _buildSalaryPartialGrid(
                      perfAmountsNotifier,
                      perfFreqNotifier,
                      perfStartMonthNotifier,
                      perfCustomMonthsNotifier,
                      (double.tryParse(perfCtrl.text) ?? 0) / 12),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        _buildNumberField('Annual Variable Pay', variableCtrl,
            subtitle: 'Total amount per year'),
        const SizedBox(height: 24),
        _buildFrequencyRow('Payout', varFreqNotifier, varStartMonthNotifier,
            varCustomMonthsNotifier, context, selectMonthsText),
        ValueListenableBuilder<bool>(
          valueListenable: varPartialNotifier,
          builder: (context, isPartial, _) {
            return Column(
              children: [
                CheckboxListTile(
                  title: const Text('Partial Payout / Taxable Factor?'),
                  subtitle: isPartial
                      ? null
                      : const Text('Default: Equal distribution'),
                  value: isPartial,
                  onChanged: (v) => varPartialNotifier.value = v ?? false,
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                ),
                if (isPartial)
                  _buildSalaryPartialGrid(
                      varAmountsNotifier,
                      varFreqNotifier,
                      varStartMonthNotifier,
                      varCustomMonthsNotifier,
                      (double.tryParse(variableCtrl.text) ?? 0)),
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
          decoration: const InputDecoration(
              labelText: 'Annual Employee PF',
              border: OutlineInputBorder(),
              floatingLabelBehavior: FloatingLabelBehavior.always),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegexUtils.amountExp)
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: gratuityCtrl,
          decoration: const InputDecoration(
              labelText: 'Annual Gratuity Contribution',
              border: OutlineInputBorder(),
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Custom Allowances',
                style: TextStyle(fontWeight: FontWeight.bold)),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () {
                _addCustomAllowanceDialog(context, (newAllowance) {
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
                  subtitle: Text(_formatAllowanceSubtitle(a)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, size: 18),
                    onPressed: () {
                      customAllowancesNotifier.value =
                          list.where((item) => item != a).toList();
                    },
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  String _formatAllowanceSubtitle(CustomAllowance a) {
    int multiplier = 1;
    if (a.frequency == PayoutFrequency.monthly) {
      multiplier = 12;
    } else if (a.frequency == PayoutFrequency.quarterly) {
      multiplier = 4;
    } else if (a.frequency == PayoutFrequency.halfYearly) {
      multiplier = 2;
    }

    final payoutFormatted = a.payoutAmount.toStringAsFixed(0);
    final totalFormatted = (a.payoutAmount *
            (a.isPartial ? (a.partialAmounts.values.length) : multiplier))
        .toStringAsFixed(0);
    return 'Payout: ₹$payoutFormatted • Total: ₹$totalFormatted';
  }

  void _onSaveSalaryStructure({
    required BuildContext ctx,
    required SalaryStructure? existing,
    required ValueNotifier<DateTime> effectiveDateNotifier,
    required TextEditingController basicCtrl,
    required TextEditingController fixedCtrl,
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
    required ValueNotifier<List<CustomAllowance>> customAllowancesNotifier,
    required ValueNotifier<List<int>> stoppedMonthsNotifier,
    required TextEditingController pfCtrl,
    required TextEditingController gratuityCtrl,
  }) {
    final basic = (double.tryParse(basicCtrl.text) ?? 0) / 12;
    final fixed = (double.tryParse(fixedCtrl.text) ?? 0) / 12;
    final perf = (double.tryParse(perfCtrl.text) ?? 0) / 12;
    final pf = (double.tryParse(pfCtrl.text) ?? 0) / 12;
    final gratuity = (double.tryParse(gratuityCtrl.text) ?? 0) / 12;
    final variable = double.tryParse(variableCtrl.text) ?? 0;

    final newStructure = SalaryStructure(
      id: existing?.id ?? const Uuid().v4(),
      effectiveDate: effectiveDateNotifier.value,
      monthlyBasic: basic,
      monthlyFixedAllowances: fixed,
      monthlyPerformancePay: perf,
      performancePayFrequency: perfFreqNotifier.value,
      performancePayStartMonth: perfStartMonthNotifier.value,
      performancePayCustomMonths: perfCustomMonthsNotifier.value,
      isPerformancePayPartial: perfPartialNotifier.value,
      performancePayAmounts: perfAmountsNotifier.value,
      annualVariablePay: variable,
      variablePayFrequency: varFreqNotifier.value,
      variablePayStartMonth: varStartMonthNotifier.value,
      variablePayCustomMonths: varCustomMonthsNotifier.value,
      isVariablePayPartial: varPartialNotifier.value,
      variablePayAmounts: varAmountsNotifier.value,
      customAllowances: customAllowancesNotifier.value,
      stoppedMonths: stoppedMonthsNotifier.value,
      monthlyEmployeePF: pf,
      monthlyGratuity: gratuity,
    );

    setState(() {
      if (existing != null) {
        final idx = _currentData.salary.history.indexOf(existing);
        if (idx != -1) _currentData.salary.history[idx] = newStructure;
      } else {
        _currentData.salary.history.add(newStructure);
      }
    });

    _updateSummary();
    Navigator.pop(ctx);
  }
}
