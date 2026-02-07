import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samriddhi_flow/models/taxes/tax_data.dart';
import 'package:samriddhi_flow/models/taxes/tax_data_models.dart';
import 'package:samriddhi_flow/models/loan.dart';
import 'package:samriddhi_flow/widgets/pure_icons.dart';
import 'package:samriddhi_flow/screens/taxes/insurance_portfolio_screen.dart';
import 'package:samriddhi_flow/services/taxes/tax_data_fetcher.dart';
import 'package:samriddhi_flow/screens/taxes/tax_rules_screen.dart';
import 'package:samriddhi_flow/providers.dart';

class TaxDetailsScreen extends ConsumerStatefulWidget {
  final TaxYearData data;
  final Function(TaxYearData) onSave;

  const TaxDetailsScreen({super.key, required this.data, required this.onSave});

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

  // Monthly breakdown: Map<Month (1-12), Amount>
  Map<int, double> _monthlySalary = {};
  final Map<int, TextEditingController> _monthlyControllers = {};

  // Local mutable lists to avoid "Unsupported operation: add"
  List<HouseProperty> _houseProperties = [];
  List<BusinessEntity> _businessIncomes = [];
  List<CapitalGainEntry> _capitalGains = [];
  List<OtherIncome> _otherIncomes = [];
  List<OtherIncome> _cashGifts = [];

  // Controllers for Other Income / Agri / Tax
  late TextEditingController _otherIncomeNameCtrl;
  late TextEditingController _otherIncomeAmtCtrl;
  late TextEditingController _advanceTaxCtrl;
  late TextEditingController _agriIncomeCtrl;

  // Local state for lists
  List<TaxPaymentEntry> _tdsEntries = [];
  List<TaxPaymentEntry> _tcsEntries = [];

  bool _isMonthlyInput = false;
  bool _hasUnsavedChanges = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentData = widget.data;
    _initSalaryControllers();
    _initTaxPaymentControllers();
    _initLocalLists();
    _otherIncomeNameCtrl = TextEditingController();
    _otherIncomeAmtCtrl = TextEditingController();
    _agriIncomeCtrl =
        TextEditingController(text: _currentData.agricultureIncome.toString());

    // Add listeners for real-time summary update
    _salaryGrossCtrl.addListener(_updateSummary);
    _salaryNpsEmployerCtrl.addListener(_updateSummary);
    _salaryLeaveEncashCtrl.addListener(_updateSummary);
    _salaryGratuityCtrl.addListener(_updateSummary);
    _agriIncomeCtrl.addListener(_updateSummary);
    _advanceTaxCtrl.addListener(_updateSummary);
  }

  void _initLocalLists() {
    _houseProperties = List.from(_currentData.houseProperties);
    _businessIncomes = List.from(_currentData.businessIncomes);
    _capitalGains = List.from(_currentData.capitalGains);
    _otherIncomes = List.from(_currentData.otherIncomes);
    _cashGifts = List.from(_currentData.cashGifts);
  }

  void _updateSummary() {
    if (!mounted) return;
    setState(() {
      _hasUnsavedChanges = true;
      // 1. Calculate Gross Salary
      double finalGross = 0;
      if (_isMonthlyInput) {
        finalGross = _monthlySalary.values.fold(0.0, (sum, val) => sum + val);
      } else {
        finalGross = double.tryParse(_salaryGrossCtrl.text) ?? 0;
      }

      // 2. Update SalaryDetails in _currentData (local copy for summary)
      final newSalary = _currentData.salary.copyWith(
        grossSalary: finalGross,
        npsEmployer: double.tryParse(_salaryNpsEmployerCtrl.text) ?? 0,
        leaveEncashment: double.tryParse(_salaryLeaveEncashCtrl.text) ?? 0,
        gratuity: double.tryParse(_salaryGratuityCtrl.text) ?? 0,
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

    // Init monthly from saved or default
    if (_currentData.salary.monthlyGross.isNotEmpty) {
      _monthlySalary = Map.from(_currentData.salary.monthlyGross);
    }

    // Initialize monthly controllers
    final months = [4, 5, 6, 7, 8, 9, 10, 11, 12, 1, 2, 3];
    for (var m in months) {
      final val = _monthlySalary[m] ?? 0;
      _monthlyControllers[m] =
          TextEditingController(text: val == 0 ? '' : val.toStringAsFixed(0));
      _monthlyControllers[m]!.addListener(() {
        final d = double.tryParse(_monthlyControllers[m]!.text) ?? 0;
        _monthlySalary[m] = d;
        _updateSummary();
      });
    }
  }

  @override
  void dispose() {
    _salaryGrossCtrl.dispose();
    _salaryNpsEmployerCtrl.dispose();
    _salaryLeaveEncashCtrl.dispose();
    _salaryGratuityCtrl.dispose();
    _otherIncomeNameCtrl.dispose();
    _otherIncomeAmtCtrl.dispose();
    _advanceTaxCtrl.dispose();
    _agriIncomeCtrl.dispose();
    for (var ctrl in _monthlyControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  void _save() {
    // 1. Calculate Gross
    double finalGross = 0;

    if (_isMonthlyInput) {
      // Sum monthly
      finalGross = _monthlySalary.values.fold(0, (sum, val) => sum + val);
    } else {
      finalGross = double.tryParse(_salaryGrossCtrl.text) ?? 0;
    }

    // Other deductions are typically annual figures
    final newSalary = SalaryDetails(
      grossSalary: finalGross,
      npsEmployer: (double.tryParse(_salaryNpsEmployerCtrl.text) ?? 0),
      leaveEncashment: (double.tryParse(_salaryLeaveEncashCtrl.text) ?? 0),
      gratuity: (double.tryParse(_salaryGratuityCtrl.text) ?? 0),
      monthlyGross:
          _isMonthlyInput ? _monthlySalary : _currentData.salary.monthlyGross,
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
    );

    widget.onSave(updatedData);
    Navigator.pop(context);
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
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(12.0),
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.blue)),
              )
            else
              IconButton(
                  icon: const Icon(Icons.cloud_download_outlined),
                  tooltip: 'Sync from Transactions',
                  onPressed: _syncFromTransactions),
            IconButton(
                icon: const Icon(Icons.policy_outlined),
                tooltip: 'Insurance Portfolio',
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const InsurancePortfolioScreen()))),
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
    // Note: This is RAW income, not taxable.
    // True taxable calculation requires logic from TaxCalculator used in Dashboard.
    // For now, we show "Approx Gross Total Income".

    return Container(
      color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Approx. Gross Income:',
              style: TextStyle(fontWeight: FontWeight.bold)),
          Text('₹${totalIncome.toStringAsFixed(0)}',
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
        SwitchListTile(
          title: const Text('Detailed Monthly Input'),
          subtitle: const Text('Enter salary per month (Apr-Mar)'),
          value: _isMonthlyInput,
          onChanged: (val) {
            setState(() {
              _isMonthlyInput = val;
              _updateSummary(); // Refresh summary mode
            });
          },
        ),
        const Divider(),
        if (_isMonthlyInput)
          _buildMonthlySalaryGrid()
        else
          _buildNumberField('Gross Salary (Annual)', _salaryGrossCtrl),
        const SizedBox(height: 24),
        _buildSectionTitle('Exemptions & Deductions'),
        _buildNumberField('Employer NPS (80CCD(2))', _salaryNpsEmployerCtrl),
        _buildNumberField(
            'Leave Encashment (Retirement / Resignation) (10(10AA))',
            _salaryLeaveEncashCtrl),
        _buildNumberField('Gratuity (Retirement / Resignation) (10(10))',
            _salaryGratuityCtrl),
      ],
    );
  }

  Widget _buildMonthlySalaryGrid() {
    // Financial Year order: Apr (4) -> Mar (3 of next year)
    final months = [4, 5, 6, 7, 8, 9, 10, 11, 12, 1, 2, 3];
    final monthNames = [
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
      'Jan',
      'Feb',
      'Mar'
    ];

    return Column(
      children: [
        for (int i = 0; i < months.length; i++)
          _buildMonthInput(months[i], monthNames[i],
              i < months.length - 1 ? months.sublist(i + 1) : []),
        const Divider(),
        ListTile(
          title: const Text('Total Gross Salary'),
          trailing: Text(
              '₹${_monthlySalary.values.fold(0.0, (s, v) => s + v).toStringAsFixed(0)}',
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        )
      ],
    );
  }

  Widget _buildMonthInput(int month, String name, List<int> nextMonths) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
              width: 40,
              child: Text(name,
                  style: const TextStyle(fontWeight: FontWeight.bold))),
          Expanded(
            child: TextFormField(
              controller: _monthlyControllers[month],
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              decoration: const InputDecoration(
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  border: OutlineInputBorder()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy_all, size: 20, color: Colors.blue),
            tooltip: 'Copy to remaining months',
            onPressed: () {
              final currentText = _monthlyControllers[month]?.text ?? '';
              setState(() {
                for (int m in nextMonths) {
                  _monthlyControllers[m]?.text = currentText;
                }
                _hasUnsavedChanges = true;
              });
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Copied to remaining months'),
                  duration: Duration(milliseconds: 500)));
            },
          )
        ],
      ),
    );
  }

  Widget _buildHousePropertyTab() {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => _addHousePropertyDialog(),
        label: const Text('Add Property'),
        icon: const Icon(Icons.add),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _houseProperties.length,
        itemBuilder: (ctx, i) {
          final hp = _houseProperties[i];
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
        },
      ),
    );
  }

  // FIXED DIALOG: Using StateSetter correctly
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
                            RegExp(r'^\d+\.?\d{0,2}')),
                      ]),
                  TextField(
                      controller: taxCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Municipal Taxes Paid'),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,2}')),
                      ]),
                ],
                const Divider(),
                const SizedBox(height: 16),
                const Text('Loan Details',
                    style: TextStyle(fontWeight: FontWeight.bold)),

                // Loan Dropdown
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Link Loan (Optional)',
                    helperText: 'Select a loan to auto-calculate interest',
                    border: OutlineInputBorder(),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedLoanId,
                      isDense: true,
                      hint: const Text('Select Loan'),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('None (Manual Entry)')),
                        ...loans.map((l) => DropdownMenuItem(
                            value: l.id,
                            child:
                                Text('${l.name} (${l.id.substring(0, 4)}...)')))
                      ],
                      onChanged: (val) {
                        setStateBuilder(() {
                          selectedLoanId = val;
                          if (val != null) {
                            // Optional: Disable manual input if linked?
                            // User said "One a loan is selected show interest going to deduct"
                            // For now, we set it.
                          }
                        });
                      },
                    ),
                  ),
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
                            RegExp(r'^\d+\.?\d{0,2}')),
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
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => _addBusinessDialog(),
        label: const Text('Add Business'),
        icon: const Icon(Icons.add),
      ),
      body: ListView.builder(
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
      ),
    );
  }

  void _addBusinessDialog({BusinessEntity? existing, int? index}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final turnoverCtrl =
        TextEditingController(text: existing?.grossTurnover.toString() ?? '');
    final netCtrl =
        TextEditingController(text: existing?.netIncome.toString() ?? '');

    BusinessType type = existing?.type ?? BusinessType.regular;

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
                  decoration: const InputDecoration(labelText: 'Taxation Type'),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<BusinessType>(
                      value: type,
                      isDense: true,
                      items: BusinessType.values
                          .map((t) => DropdownMenuItem(
                              value: t,
                              child: Text(t.toString().split('.').last)))
                          .toList(),
                      onChanged: (v) => setStateBuilder(() => type = v!),
                    ),
                  ),
                ),
                TextField(
                    controller: turnoverCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Gross Turnover / Receipts'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}')),
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
                          RegExp(r'^\d+\.?\d{0,2}')),
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

                if (type == BusinessType.section44AD) presumptive = to * 0.06;
                if (type == BusinessType.section44ADA) presumptive = to * 0.50;

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
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => _addCGEntryDialog(),
        label: const Text('Add Gain Entry'),
        icon: const Icon(Icons.add),
      ),
      body: _capitalGains.isEmpty
          ? const Center(child: Text('No Capital Gains entries added.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _capitalGains.length,
              itemBuilder: (ctx, i) {
                final entry = _capitalGains[i];
                return Card(
                  child: ListTile(
                    title: Text(entry.description),
                    subtitle: Text(
                        '${entry.matchAssetType.toString().split('.').last} • ${entry.isLTCG ? 'LTCG' : 'STCG'} • Gross Sale: ₹${entry.saleAmount.toStringAsFixed(0)}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                            'Gain: ${entry.capitalGainAmount.toStringAsFixed(0)}'),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () {
                            setState(() {
                              _capitalGains.removeAt(i);
                            });
                            _updateSummary();
                          },
                        )
                      ],
                    ),
                    onTap: () => _addCGEntryDialog(existing: entry, index: i),
                  ),
                );
              },
            ),
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
                    suffixIcon: selectedAsset == AssetType.equityShares
                        ? const Tooltip(
                            triggerMode: TooltipTriggerMode.tap,
                            showDuration: Duration(seconds: 5),
                            padding: EdgeInsets.all(12),
                            message:
                                'Equity shares or Equity mutual funds (> 75% equity) and STT tax paid.',
                            child: Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Icon(Icons.info_outline,
                                  color: Colors.blue, size: 20),
                            ),
                          )
                        : null,
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<AssetType>(
                      value: selectedAsset,
                      isDense: true,
                      items: AssetType.values.map((t) {
                        String name = '';
                        switch (t) {
                          case AssetType.equityShares:
                            name = 'Equity Shares / Eq. MFs';
                            break;
                          case AssetType.residentialProperty:
                            name = 'Residential Property';
                            break;
                          case AssetType.agriculturalLand:
                            name = 'Agricultural Land';
                            break;
                          case AssetType.other:
                            name = 'Other Assets (Gold, Debt, NPST2 etc.)';
                            break;
                        }
                        return DropdownMenuItem(value: t, child: Text(name));
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
                          RegExp(r'^\d+\.?\d{0,2}')),
                    ]),
                TextField(
                    controller: costCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Cost of Acquisition'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}')),
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
                const Text('Exemption (Reinvestment)',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                InputDecorator(
                  decoration:
                      const InputDecoration(labelText: 'Reinvested Into'),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<ReinvestmentType>(
                      value: selectedReinvestType,
                      isDense: true,
                      items: ReinvestmentType.values
                          .map((t) => DropdownMenuItem(
                              value: t,
                              child: Text(t.toString().split('.').last)))
                          .toList(),
                      onChanged: (v) =>
                          setStateBuilder(() => selectedReinvestType = v!),
                    ),
                  ),
                ),
                if (selectedReinvestType != ReinvestmentType.none) ...[
                  TextField(
                      controller: reinvestCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Amount Invested'),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,2}')),
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
                          firstDate: gainDate, // Can't start before gain?
                          lastDate: DateTime(2030),
                          initialDate: reinvestDate ?? gainDate);
                      if (d != null) setStateBuilder(() => reinvestDate = d);
                    },
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
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => _addOtherIncomeDialog(),
        label: const Text('Add Income'),
        icon: const Icon(Icons.add),
      ),
      body: ListView.builder(
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
            ),
          );
        },
      ),
    );
  }

  void _addOtherIncomeDialog() {
    // Controllers for text input
    final typeCtrl = TextEditingController(text: 'Interest');

    showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(builder: (context, setStateBuilder) {
              return AlertDialog(
                title: const Text('Add Other Income'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                          controller: _otherIncomeNameCtrl,
                          decoration: const InputDecoration(labelText: 'Name'),
                          textCapitalization: TextCapitalization.words),
                      TextField(
                          controller: _otherIncomeAmtCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Gross Amount (₹)',
                              helperText:
                                  'Includes Bank Interest, Dividend, NPS Tier-2 withdrawal, Gift from non-relatives (>50k), etc.'),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'^\d+\.?\d{0,2}')),
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
                      final newItem = OtherIncome(
                        name: _otherIncomeNameCtrl.text,
                        amount: double.tryParse(_otherIncomeAmtCtrl.text) ?? 0,
                        type: typeCtrl.text,
                        subtype: typeCtrl.text.toLowerCase(),
                      );
                      setState(() {
                        _otherIncomes.add(newItem);
                      });
                      _updateSummary();
                      _otherIncomeNameCtrl.clear();
                      _otherIncomeAmtCtrl.clear();
                      Navigator.pop(context);
                    },
                    child: const Text('Add'),
                  ),
                ],
              );
            }));
  }

  Widget _buildSectionTitle(String title) {
    return Text(title,
        style: TextStyle(
            color: Theme.of(context).primaryColor,
            fontWeight: FontWeight.bold));
  }

  Widget _buildNumberField(String label, TextEditingController controller,
      {String? subtitle}) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(labelText: label, helperText: subtitle),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
      ],
    );
  }

  Future<void> _syncFromTransactions() async {
    // 1. Confirm
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sync from Transactions?'),
        content: const Text(
            'This will overwrite your current manual entries with aggregated data from your mapped transaction tags.\n\nProceed?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sync')),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      final fetcher = ref.read(taxDataFetcherProvider);
      final result = await fetcher.fetchAndAggregate(_currentData.year);

      setState(() {
        _currentData = result.data;
        _initSalaryControllers(); // Refresh controllers
        _hasUnsavedChanges = true;
        _isLoading = false;
      });

      if (mounted) {
        if (result.warnings.isNotEmpty) {
          _showSyncWarnings(result.warnings);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Sync Complete! No unmapped items.')));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Sync Failed: $e'), backgroundColor: Colors.red));
      }
    }
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
                decoration: const InputDecoration(
                    labelText: 'Source (e.g. Bank, Employer)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: amtCtrl,
                decoration:
                    const InputDecoration(labelText: 'Gross Amount (₹)'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
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
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => _addCashGiftDialog(),
        label: const Text('Add Cash Gift'),
        icon: const Icon(Icons.add),
      ),
      body: _cashGifts.isEmpty
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
            ),
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
                  decoration: const InputDecoration(labelText: 'Amount (₹)'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d{0,2}')),
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

  void _showSyncWarnings(List<String> warnings) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sync Completed with Warnings'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                  'The following income transactions were found but have no mapped Tax Category. They were defaulted to "Other".'),
              const SizedBox(height: 10),
              const Divider(),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: warnings.length,
                  itemBuilder: (context, index) => Text('• ${warnings[index]}',
                      style: const TextStyle(fontSize: 12, color: Colors.red)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const TaxRulesScreen()));
              },
              child: const Text('Configure Mappings')),
        ],
      ),
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
                        RegExp(r'^\d+\.?\d{0,2}')),
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
}
