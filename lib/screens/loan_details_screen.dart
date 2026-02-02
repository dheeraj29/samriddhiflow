import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../providers.dart';
import '../feature_providers.dart';
import '../models/loan.dart';
import '../theme/app_theme.dart';
import '../models/account.dart';
import '../models/transaction.dart';
import '../widgets/smart_currency_text.dart';
import 'loan_payment_dialog.dart';
import '../services/loan_service.dart';
import '../widgets/pure_icons.dart';

enum LoanDetailView { amortization, simulator, ledger }

class LoanDetailsScreen extends ConsumerStatefulWidget {
  final Loan loan;
  const LoanDetailsScreen({super.key, required this.loan});

  @override
  ConsumerState<LoanDetailsScreen> createState() => _LoanDetailsScreenState();
}

class _LoanDetailsScreenState extends ConsumerState<LoanDetailsScreen> {
  // Simulator State
  bool _isSimulating = false;
  double _prepaymentAmount = 0;
  bool _reduceTenure = true; // vs Reduce EMI

  // Ledger Filter State
  LoanTransactionType? _filterType;
  DateTimeRange? _filterDateRange;
  bool _compactLedger = false;

  LoanDetailView _currentView = LoanDetailView.amortization;

  @override
  Widget build(BuildContext context) {
    final loanService = ref.watch(loanServiceProvider);
    final theme = Theme.of(context);
    final currencyProviderValue = ref.watch(currencyProvider);
    final currency = NumberFormat.simpleCurrency(locale: currencyProviderValue);

    final loansAsync = ref.watch(loansProvider);

    return loansAsync.when(
      data: (loans) {
        final currentLoan = loans.firstWhere((l) => l.id == widget.loan.id,
            orElse: () => widget.loan);
        final isGoldLoan = currentLoan.type == LoanType.gold;

        // --- Gold Loan Accrual Calculation ---
        // Days since last payment (or start date)
        final lastPaymentDate = currentLoan.transactions.isEmpty
            ? currentLoan.startDate
            : currentLoan.transactions
                .map((t) => t.date)
                .reduce((a, b) => a.isAfter(b) ? a : b);
        final daysElapsed = DateTime.now().difference(lastPaymentDate).inDays;

        final currentRate = currentLoan.transactions
                .where((t) => t.type == LoanTransactionType.rateChange)
                .isEmpty
            ? currentLoan.interestRate
            : currentLoan.transactions
                .where((t) => t.type == LoanTransactionType.rateChange)
                .reduce((a, b) => a.date.isAfter(b.date) ? a : b)
                .amount;

        // Simple Interest Accrual (Approximate for Header)
        final accruedInterest =
            (currentLoan.remainingPrincipal * currentRate * daysElapsed) /
                (365.0 * 100.0);

        // --- Standard Loan Calculations ---
        final schedule = !isGoldLoan
            ? loanService.calculateAmortizationSchedule(currentLoan)
            : [];
        final progress = currentLoan.totalPrincipal > 0
            ? (currentLoan.totalPrincipal - currentLoan.remainingPrincipal) /
                currentLoan.totalPrincipal
            : 0.0;

        final remainingTenure =
            loanService.calculateRemainingTenure(currentLoan);
        final remainingMonths = remainingTenure.months.ceil();
        final remainingDays = remainingTenure.days;

        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          appBar: AppBar(
            title: Text(currentLoan.name),
            actions: [
              if (!isGoldLoan)
                IconButton(
                  icon: PureIcons.addCircle(),
                  tooltip: 'Top-up Loan',
                  onPressed: () => _showTopupDialog(currentLoan),
                ),
              IconButton(
                icon: PureIcons.editOutlined(),
                tooltip: 'Rename Loan',
                onPressed: () => _showRenameDialog(currentLoan),
              ),
              IconButton(
                icon: PureIcons.deleteOutlined(),
                tooltip: 'Delete Loan',
                onPressed: () => _showDeleteLoanDialog(currentLoan),
              )
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Header Card
                Card(
                  color: isGoldLoan ? Colors.amber[900] : AppTheme.primary,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Outstanding Principal',
                                style: TextStyle(color: Colors.white70)),
                            if (!isGoldLoan) ...[
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () =>
                                    _showBulkPaymentDialog(currentLoan),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(12)),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.library_add_check_outlined,
                                          size: 14, color: Colors.white),
                                      SizedBox(width: 4),
                                      Text(
                                        'Bulk Pay',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            ]
                          ],
                        ),
                        SmartCurrencyText(
                          value: currentLoan.remainingPrincipal,
                          locale: currencyProviderValue,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),

                        // --- Gold Loan Specs ---
                        if (isGoldLoan) ...[
                          const Divider(color: Colors.white24),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStat('Interest Rate', '$currentRate%'),
                              _buildStat('Days Accrued', '$daysElapsed days'),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text('Est. Accrued Interest (To Date)',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                          const SizedBox(height: 4),
                          SmartCurrencyText(
                            value: accruedInterest,
                            locale: currencyProviderValue,
                            style: const TextStyle(
                                color: Colors.amberAccent,
                                fontSize: 24,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                  'Maturity: ${DateFormat('MMM dd, yyyy').format(currentLoan.startDate.add(Duration(days: currentLoan.tenureMonths * 30)))}',
                                  style: const TextStyle(
                                      color: Colors.white60,
                                      fontStyle: FontStyle.italic)),
                              IconButton(
                                icon: PureIcons.calendarMonth(
                                    color: Colors.white60, size: 20),
                                tooltip: 'Add to System Calendar',
                                onPressed: () {
                                  final maturityDate = currentLoan.startDate
                                      .add(Duration(
                                          days: currentLoan.tenureMonths * 30));
                                  ref
                                      .read(calendarServiceProvider)
                                      .downloadExvent(
                                        title:
                                            'Loan Maturity: ${currentLoan.name}',
                                        description:
                                            'Maturity date for Gold Loan: ${currentLoan.name}. Principal and Interest due.',
                                        startTime: maturityDate,
                                        endTime: maturityDate
                                            .add(const Duration(hours: 1)),
                                      );
                                },
                              )
                            ],
                          ),
                        ]
                        // --- Standard Loan Specs ---
                        else ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              InkWell(
                                onTap: () =>
                                    _showRecalculateLoanDialog(currentLoan),
                                child: Row(
                                  children: [
                                    Column(
                                      children: [
                                        const Text('EMI',
                                            style: TextStyle(
                                                color: Colors.white60)),
                                        SmartCurrencyText(
                                          value: currentLoan.emiAmount,
                                          locale: currencyProviderValue,
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 4),
                                    PureIcons.edit(
                                        size: 14, color: Colors.white70),
                                  ],
                                ),
                              ),
                              InkWell(
                                onTap: () => _showUpdateRateDialog(currentLoan),
                                child: Row(
                                  children: [
                                    _buildStat(
                                        'Rate', '${currentLoan.interestRate}%'),
                                    const SizedBox(width: 4),
                                    PureIcons.edit(
                                        size: 14, color: Colors.white70),
                                  ],
                                ),
                              ),
                              _buildStat('Paid',
                                  '${currentLoan.transactions.where((t) => t.type == LoanTransactionType.emi).length}m'),
                              _buildStat('Left',
                                  '${remainingMonths}m ${remainingDays}d'),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                      '${(progress * 100).toStringAsFixed(1)}% Paid',
                                      style: const TextStyle(
                                          color: Colors.white70, fontSize: 12)),
                                  const Text('Closure Progress',
                                      style: TextStyle(
                                          color: Colors.white70, fontSize: 12)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              LinearProgressIndicator(
                                value: progress,
                                backgroundColor: Colors.black12,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                    Colors.greenAccent),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ],
                          )
                        ]
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Controls
                if (!isGoldLoan)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildNavIcon(Icons.show_chart, 'Amortization',
                            LoanDetailView.amortization, theme),
                        _buildNavIcon(Icons.calculate_outlined, 'Simulator',
                            LoanDetailView.simulator, theme),
                        _buildNavIcon(Icons.list_alt, 'Ledger',
                            LoanDetailView.ledger, theme),
                        InkWell(
                          onTap: () {
                            showDialog(
                                context: context,
                                builder: (_) =>
                                    RecordLoanPaymentDialog(loan: currentLoan));
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                PureIcons.payment(color: Colors.green),
                                const SizedBox(height: 4),
                                const Text(
                                  'Pay',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  // Gold Loan Actions
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        _buildGoldAction(
                          onPressed: () => _showGoldLoanInterestPaymentDialog(
                              currentLoan, accruedInterest),
                          icon: Icons.refresh,
                          label: 'Renew',
                          color: Colors.blue[800]!,
                        ),
                        _buildGoldAction(
                          onPressed: () => _showPartPaymentDialog(currentLoan),
                          icon: Icons.show_chart,
                          label: 'Part Pay',
                          color: Colors.orange[800]!,
                        ),
                        _buildGoldAction(
                          onPressed: () => _showRateChangeDialog(currentLoan),
                          icon: Icons.percent,
                          label: 'Rate',
                          color: Colors.purple[800]!,
                        ),
                        _buildGoldAction(
                          onPressed: () => _showCloseGoldLoanDialog(
                              currentLoan, accruedInterest),
                          icon: Icons.check_circle_outline,
                          label: 'Close',
                          color: Colors.green[800]!,
                        ),
                      ],
                    ),
                  ),

                const Divider(),
                const SizedBox(height: 16),

                if (!isGoldLoan && _currentView == LoanDetailView.amortization)
                  _buildAmortizationView(theme,
                      schedule.cast<Map<String, dynamic>>(), currentLoan),
                if (!isGoldLoan && _currentView == LoanDetailView.simulator)
                  _buildSimulatorView(theme, currentLoan, progress,
                      currencyProviderValue, currency, loanService),
                if (isGoldLoan || _currentView == LoanDetailView.ledger)
                  _buildLedger(currentLoan, currencyProviderValue),
              ],
            ),
          ),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(body: Center(child: Text('Error: $err'))),
    );
  }

  // ... (keeping existing helpers)

  // --- Part Payment Dialog ---
  void _showPartPaymentDialog(Loan currentLoan) {
    final amountController = TextEditingController();
    final dateController = TextEditingController(
        text: DateFormat('yyyy-MM-dd').format(DateTime.now()));
    DateTime selectedDate = DateTime.now();
    String? selectedAccountId = currentLoan.accountId;
    final accounts = ref.read(accountsProvider).value ?? [];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Part Principal Payment'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                    'Reduce the outstanding principal. Interest on the reduced amount will decrease from the payment date.'),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(
                      labelText: 'Amount', prefixText: '₹ '),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final d = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2030));
                    if (d != null) {
                      setState(() {
                        selectedDate = d;
                        dateController.text =
                            DateFormat('yyyy-MM-dd').format(d);
                      });
                    }
                  },
                  child: TextField(
                    controller: dateController,
                    decoration: InputDecoration(
                        labelText: 'Payment Date',
                        prefixIcon: PureIcons.calendar()),
                    readOnly: true,
                    enabled: false,
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String?>(
                  initialValue: selectedAccountId,
                  decoration:
                      const InputDecoration(labelText: 'Paid From Account'),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('Manual (No account)')),
                    ...accounts.map((a) =>
                        DropdownMenuItem(value: a.id, child: Text(a.name))),
                  ],
                  onChanged: (v) => setState(() => selectedAccountId = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                child: const Text('Cancel'),
                onPressed: () => Navigator.pop(context)),
            ElevatedButton(
              child: const Text('Pay Principal'),
              onPressed: () async {
                final amount = double.tryParse(amountController.text);
                if (amount != null && amount > 0) {
                  final storage = ref.read(storageServiceProvider);
                  var loan = currentLoan;

                  // Create Prepayment Transaction
                  final loanTxn = LoanTransaction(
                    id: const Uuid().v4(),
                    date: selectedDate,
                    amount: amount,
                    type: LoanTransactionType.prepayment,
                    principalComponent: amount,
                    interestComponent: 0, // Assuming pure principal payment
                    resultantPrincipal: loan.remainingPrincipal - amount,
                  );

                  loan.transactions = [...loan.transactions, loanTxn];
                  loan.remainingPrincipal -= amount;

                  // Record Expense Transaction
                  if (selectedAccountId != null) {
                    final acc =
                        accounts.firstWhere((a) => a.id == selectedAccountId);
                    final expTxn = Transaction.create(
                      title: 'Loan Part Pay: ${loan.name}',
                      amount: amount,
                      type: TransactionType.expense,
                      category: 'Loan Principal',
                      accountId: selectedAccountId!,
                      date: selectedDate,
                      loanId: loan.id,
                    );
                    acc.balance -= amount;
                    await storage.saveAccount(acc);
                    await storage.saveTransaction(expTxn);
                  }

                  await storage.saveLoan(loan);
                  ref.invalidate(loansProvider);
                  ref.invalidate(transactionsProvider);
                  ref.invalidate(accountsProvider);
                  if (mounted) Navigator.pop(context);
                }
              },
            )
          ],
        ),
      ),
    );
  }

  Widget _buildGoldAction({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return SizedBox(
      width: 85, // Fixed width for consistent grid-like appearance in Wrap
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.zero,
              backgroundColor: color,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              minimumSize: const Size(50, 50),
            ),
            child: PureIcons.icon(icon, size: 24),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white60, fontSize: 12)),
        Text(value,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
      ],
    );
  }

  void _showUpdateRateDialog(Loan currentLoan) {
    final rateController =
        TextEditingController(text: currentLoan.interestRate.toString());
    bool updateTenure = false;
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Update Interest Rate'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Enter new annual interest rate.'),
              const SizedBox(height: 16),
              TextField(
                controller: rateController,
                decoration: const InputDecoration(
                    labelText: 'New Annual Rate (%)', suffixText: '%'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),
              const Text('Recalculation Mode:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              RadioListTile<bool>(
                title: const Text('Adjust EMI'),
                subtitle: const Text(
                    'Keep Tenure constant.\nMonthly payment will change.'),
                value: false,
                groupValue: updateTenure,
                onChanged: (v) {
                  if (v != null) setState(() => updateTenure = v);
                },
              ),
              RadioListTile<bool>(
                title: const Text('Adjust Tenure'),
                subtitle: const Text(
                    'Keep EMI constant.\nLoan duration will change.'),
                value: true,
                groupValue: updateTenure,
                onChanged: (v) {
                  if (v != null) setState(() => updateTenure = v);
                },
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                  );
                  if (d != null) {
                    setState(() => selectedDate = d);
                  }
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Effective Date',
                    border: const OutlineInputBorder(),
                    prefixIcon: PureIcons.calendar(),
                  ),
                  child: Text(
                    DateFormat('MMM dd, yyyy').format(selectedDate),
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final newRate = double.tryParse(rateController.text);
                if (newRate != null && newRate > 0) {
                  await _handleUpdateInterestRate(
                    loan: currentLoan,
                    newRate: newRate,
                    effectiveDate: selectedDate,
                    updateTenure: updateTenure,
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                }
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _showTopupDialog(Loan currentLoan) {
    final amountController = TextEditingController();
    bool updateTenure = false; // false = Adjust EMI, true = Adjust Tenure
    final accounts = ref.read(accountsProvider).value ?? [];
    String? selectedAccountId = currentLoan.accountId;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Loan Top-up'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Borrow more money on this loan.'),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                decoration: const InputDecoration(
                    labelText: 'Top-up Amount', prefixText: '₹ '),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String?>(
                initialValue: selectedAccountId,
                decoration:
                    const InputDecoration(labelText: 'Credit to Account'),
                items: [
                  const DropdownMenuItem(
                      value: null, child: Text('Manual (No account)')),
                  ...accounts.map((a) =>
                      DropdownMenuItem(value: a.id, child: Text(a.name))),
                ],
                onChanged: (v) => setState(() => selectedAccountId = v),
              ),
              const SizedBox(height: 16),
              const Text('Recalculation Mode:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              RadioListTile<bool>(
                title: const Text('Adjust EMI'),
                subtitle:
                    const Text('Keep Tenure constant. EMI will increase.'),
                value: false,
                groupValue: updateTenure,
                onChanged: (v) {
                  if (v != null) setState(() => updateTenure = v);
                },
              ),
              RadioListTile<bool>(
                title: const Text('Adjust Tenure'),
                subtitle:
                    const Text('Keep EMI constant. Tenure will increase.'),
                value: true,
                groupValue: updateTenure,
                onChanged: (v) {
                  if (v != null) setState(() => updateTenure = v);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final topupAmount = double.tryParse(amountController.text);
                if (topupAmount != null && topupAmount > 0) {
                  await _handleLoanTopup(
                    loan: currentLoan,
                    topupAmount: topupAmount,
                    selectedAccountId: selectedAccountId,
                    updateTenure: updateTenure,
                    accounts: accounts,
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                }
              },
              child: const Text('Borrow'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleUpdateInterestRate({
    required Loan loan,
    required double newRate,
    required DateTime effectiveDate,
    required bool updateTenure,
  }) async {
    final storage = ref.read(storageServiceProvider);
    final loanService = ref.read(loanServiceProvider);

    // 1. Calculate and lock-in interest at OLD rate until effective date
    final lastDate = loan.transactions.isNotEmpty
        ? loan.transactions
            .map((t) => t.date)
            .reduce((a, b) => a.isAfter(b) ? a : b)
        : loan.startDate;

    final accruedInterest = loanService.calculateAccruedInterest(
      principal: loan.remainingPrincipal,
      annualRate: loan.interestRate,
      fromDate: lastDate,
      toDate: effectiveDate,
    );

    // 2. Record Rate Change Event with Accrued Interest
    final rateTxn = LoanTransaction(
      id: const Uuid().v4(),
      date: effectiveDate,
      amount: newRate, // New rate recorded in amount
      type: LoanTransactionType.rateChange,
      principalComponent: 0,
      interestComponent: accruedInterest,
      resultantPrincipal: loan.remainingPrincipal,
    );

    loan.transactions = [...loan.transactions, rateTxn];
    loan.interestRate = newRate;

    // 3. Recalibrate (Adjust EMI or Adjust Tenure)
    if (!updateTenure) {
      // Adjust EMI (Keep Tenure)
      final monthsPassed =
          effectiveDate.difference(loan.startDate).inDays ~/ 30;
      final remainingMonths = (loan.tenureMonths - monthsPassed).clamp(1, 600);

      loan.emiAmount = loanService.calculateEMI(
        principal: loan.remainingPrincipal,
        annualRate: newRate,
        tenureMonths: remainingMonths,
      );
    } else {
      // Adjust Tenure (Keep EMI)
      loan.tenureMonths = loanService.calculateTenureForEMI(
        principal: loan.remainingPrincipal,
        annualRate: newRate,
        emi: loan.emiAmount,
      );
    }

    await storage.saveLoan(loan);
    final _ = ref.refresh(loansProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rate updated and loan recalibrated.')));
    }
  }

  Future<void> _handleLoanTopup({
    required Loan loan,
    required double topupAmount,
    required String? selectedAccountId,
    required bool updateTenure,
    required List<Account> accounts,
  }) async {
    final storage = ref.read(storageServiceProvider);
    final loanService = ref.read(loanServiceProvider);

    final topupDate = DateTime.now();

    // 1. Accrue interest on OLD balance until today
    final lastDate = loan.transactions.isNotEmpty
        ? loan.transactions
            .map((t) => t.date)
            .reduce((a, b) => a.isAfter(b) ? a : b)
        : loan.startDate;

    final accruedInterest = loanService.calculateAccruedInterest(
      principal: loan.remainingPrincipal,
      annualRate: loan.interestRate,
      fromDate: lastDate,
      toDate: topupDate,
    );

    // 2. Add Top-up principal and record transaction
    loan.totalPrincipal += topupAmount;
    loan.remainingPrincipal += topupAmount;

    final topupTxn = LoanTransaction(
      id: const Uuid().v4(),
      date: topupDate,
      amount: topupAmount,
      type: LoanTransactionType.topup,
      principalComponent: topupAmount,
      interestComponent: accruedInterest,
      resultantPrincipal: loan.remainingPrincipal,
    );

    loan.transactions = [...loan.transactions, topupTxn];

    // 3. Recalibrate (Adjust EMI or Adjust Tenure)
    if (!updateTenure) {
      // Adjust EMI (Keep Tenure)
      final monthsPassed = topupDate.difference(loan.startDate).inDays ~/ 30;
      final remainingMonths = (loan.tenureMonths - monthsPassed).clamp(1, 600);

      loan.emiAmount = loanService.calculateEMI(
        principal: loan.remainingPrincipal,
        annualRate: loan.interestRate,
        tenureMonths: remainingMonths,
      );
    } else {
      // Adjust Tenure (Keep EMI)
      loan.tenureMonths = loanService.calculateTenureForEMI(
        principal: loan.remainingPrincipal,
        annualRate: loan.interestRate,
        emi: loan.emiAmount,
      );
    }

    // Record Income Transaction
    if (selectedAccountId != null) {
      final acc = accounts.firstWhere((a) => a.id == selectedAccountId);
      final financeTxn = Transaction.create(
        title: 'Loan Top-up: ${loan.name}',
        amount: topupAmount,
        type: TransactionType.income,
        category: 'Loan Top-up',
        accountId: selectedAccountId,
        date: DateTime.now(),
        loanId: loan.id,
      );
      acc.balance += topupAmount;
      await storage.saveAccount(acc);
      await storage.saveTransaction(financeTxn);
    }

    await storage.saveLoan(loan);
    ref.invalidate(loansProvider);
    ref.invalidate(transactionsProvider);
    ref.invalidate(accountsProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Loan topped up successfully.')));
    }
  }

  Widget _buildLedger(Loan loan, String currencyLocale) {
    final currency = NumberFormat.simpleCurrency(locale: currencyLocale);
    List<LoanTransaction> filteredTxns = loan.transactions.toList();

    if (_filterType != null) {
      filteredTxns = filteredTxns.where((t) => t.type == _filterType).toList();
    }

    if (_filterDateRange != null) {
      filteredTxns = filteredTxns
          .where((t) =>
              t.date.isAfter(_filterDateRange!.start
                  .subtract(const Duration(seconds: 1))) &&
              t.date
                  .isBefore(_filterDateRange!.end.add(const Duration(days: 1))))
          .toList();
    }

    filteredTxns.sort((a, b) => b.date.compareTo(a.date));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Loan Ledger',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Row(
              children: [
                IconButton(
                  icon: PureIcons.icon(
                      _compactLedger
                          ? Icons.format_align_justify
                          : Icons.format_align_center,
                      size: 20,
                      color: Colors.grey),
                  onPressed: () =>
                      setState(() => _compactLedger = !_compactLedger),
                  tooltip: _compactLedger
                      ? 'Switch to Extended Numbers'
                      : 'Switch to Compact Numbers',
                ),
                IconButton(
                  icon: PureIcons.icon(Icons.filter_list,
                      color: _filterType != null
                          ? Theme.of(context).colorScheme.primary
                          : null),
                  onPressed: () => _showFilterTypeDialog(),
                  tooltip: 'Filter by Type',
                ),
                IconButton(
                  icon: PureIcons.icon(Icons.date_range,
                      color: _filterDateRange != null
                          ? Theme.of(context).colorScheme.primary
                          : null),
                  onPressed: () => _showFilterDateDialog(),
                  tooltip: 'Filter by Date',
                ),
                if (_filterType != null || _filterDateRange != null)
                  IconButton(
                    icon: PureIcons.close(color: Colors.red),
                    onPressed: () => setState(() {
                      _filterType = null;
                      _filterDateRange = null;
                    }),
                    tooltip: 'Clear Filters',
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (filteredTxns.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32.0),
            child: Center(
                child: Text('No transactions match the filters.',
                    style: TextStyle(color: Colors.grey))),
          ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filteredTxns.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (context, index) {
            final txn = filteredTxns[index];
            String title = '';
            IconData icon = Icons.payment;
            Color color = Colors.blue;
            String subtitle = '';

            if (txn.type == LoanTransactionType.emi) {
              title = 'EMI Payment';
              icon = Icons.event_note;
              color = Colors.green;
              subtitle =
                  'Prin: ${currency.format(txn.principalComponent)} • Int: ${currency.format(txn.interestComponent)}';
            } else if (txn.type == LoanTransactionType.prepayment) {
              title = 'Prepayment';
              icon = Icons.speed;
              color = Colors.orange;
              subtitle = 'Direct reduction of principal';
            } else if (txn.type == LoanTransactionType.rateChange) {
              title = 'Interest Rate Updated';
              icon = Icons.trending_up;
              color = Colors.purple;
              subtitle = 'New Rate: ${txn.amount}%';
            } else if (txn.type == LoanTransactionType.topup) {
              title = 'Loan Top-up';
              icon = Icons.add_circle_outline;
              color = Colors.teal;
              subtitle = 'Increased principal amount';
            }

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.1),
                child: Icon(icon, color: color, size: 20),
              ),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  if (txn.type != LoanTransactionType.rateChange)
                    SmartCurrencyText(
                        value: txn.amount,
                        locale: currencyLocale,
                        initialCompact: _compactLedger,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      '${DateFormat('MMM dd, yyyy, hh:mm a').format(txn.date)} • $subtitle',
                      style: const TextStyle(fontSize: 12)),
                  const Text('Balance: ',
                      style: TextStyle(fontSize: 11, color: Colors.grey)),
                  SmartCurrencyText(
                    value: txn.resultantPrincipal,
                    locale: currencyLocale,
                    initialCompact: _compactLedger,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'delete') {
                    final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                              title: const Text('Delete Entry?'),
                              content: const Text(
                                  'Deleting this will attempt to reverse the principal impact, but won\'t perfectly recalculate interest history.\n\nAre you sure?'),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Cancel')),
                                TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Delete',
                                        style: TextStyle(color: Colors.red))),
                              ],
                            ));

                    if (confirm == true) {
                      // Reverse Impact
                      if (txn.type == LoanTransactionType.emi ||
                          txn.type == LoanTransactionType.prepayment) {
                        loan.remainingPrincipal += txn.principalComponent;
                      } else if (txn.type == LoanTransactionType.topup) {
                        loan.remainingPrincipal -= txn.amount;
                        loan.totalPrincipal -= txn.amount;
                      }

                      // Remove
                      loan.transactions.removeWhere((t) => t.id == txn.id);

                      await ref.read(storageServiceProvider).saveLoan(loan);
                      ref.invalidate(loansProvider);
                      // Force rebuild
                      setState(() {});
                    }
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red, size: 20),
                        SizedBox(width: 8),
                        Text('Delete'),
                      ],
                    ),
                  )
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  void _showFilterTypeDialog() {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Filter by Type'),
        children: [
          SimpleDialogOption(
            onPressed: () {
              setState(() => _filterType = null);
              Navigator.pop(context);
            },
            child: const Text('All'),
          ),
          ...LoanTransactionType.values.map((type) => SimpleDialogOption(
                onPressed: () {
                  setState(() => _filterType = type);
                  Navigator.pop(context);
                },
                child: Text(type.name.toUpperCase()),
              )),
        ],
      ),
    );
  }

  void _showFilterDateDialog() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2030),
      initialDateRange: _filterDateRange,
    );
    if (range != null) {
      setState(() => _filterDateRange = range);
    }
  }

  void _showRecalculateLoanDialog(Loan loan) {
    final emiController =
        TextEditingController(text: loan.emiAmount.toStringAsFixed(2));
    final tenureController =
        TextEditingController(text: loan.tenureMonths.toString());

    bool adjustRate = false; // false = Adjust Tenure, true = Adjust Rate

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Recalculate Loan'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  'Current Outstanding: ${NumberFormat.simpleCurrency(locale: ref.watch(currencyProvider)).format(loan.remainingPrincipal)}'),
              const SizedBox(height: 16),
              TextField(
                controller: emiController,
                decoration: const InputDecoration(
                    labelText: 'New EMI Amount', border: OutlineInputBorder()),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                ],
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                title: const Text('Calculate Interest Rate?'),
                subtitle: const Text(
                    'If checked, Tenure will be used to find the new Rate. Otherwise, Tenure is recalculated.'),
                value: adjustRate,
                onChanged: (v) => setState(() => adjustRate = v!),
              ),
              if (adjustRate) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: tenureController,
                  decoration: const InputDecoration(
                      labelText: 'Target Tenure (Months)',
                      border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final newEmi = double.tryParse(emiController.text) ?? 0;
                final newTenure = int.tryParse(tenureController.text) ?? 0;

                if (newEmi > 0) {
                  final storage = ref.read(storageServiceProvider);
                  final loanService = ref.read(loanServiceProvider);

                  if (adjustRate) {
                    if (newTenure > 0) {
                      final newRate = loanService.calculateRateForEMITenure(
                        principal: loan.remainingPrincipal,
                        tenureMonths: newTenure,
                        emi: newEmi,
                      );
                      loan.interestRate = newRate;
                      loan.emiAmount = newEmi;

                      final monthsPassed =
                          DateTime.now().difference(loan.startDate).inDays ~/
                              30;
                      loan.tenureMonths = monthsPassed + newTenure;
                    }
                  } else {
                    final calcTenure = loanService.calculateTenureForEMI(
                        principal: loan.remainingPrincipal,
                        annualRate: loan.interestRate,
                        emi: newEmi);

                    loan.emiAmount = newEmi;
                    final monthsPassed =
                        DateTime.now().difference(loan.startDate).inDays ~/ 30;
                    loan.tenureMonths = monthsPassed + calcTenure;
                  }

                  await storage.saveLoan(loan);
                  final _ = ref.refresh(loansProvider);
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(Loan loan) {
    final controller = TextEditingController(text: loan.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Loan'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Loan Name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                final newName = controller.text;
                loan.name = newName;
                await ref.read(storageServiceProvider).saveLoan(loan);
                ref.invalidate(loansProvider);
                if (context.mounted) {
                  Navigator.pop(context);
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildNavIcon(
      IconData icon, String label, LoanDetailView view, ThemeData theme) {
    final isSelected = _currentView == view;
    return InkWell(
      onTap: () => setState(() => _currentView = view),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: isSelected
            ? BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PureIcons.icon(
              icon,
              color:
                  isSelected ? theme.colorScheme.primary : theme.disabledColor,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.disabledColor,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmortizationView(
      ThemeData theme, List<Map<String, dynamic>> schedule, Loan currentLoan) {
    // Annual Data Calculation
    final Map<int, Map<String, double>> yearlyData = {};
    double prevBal = currentLoan.totalPrincipal;

    for (var item in schedule) {
      final monthIdx = item['month'] as int;
      final bal = item['balance'] as double;
      // approximate date
      final date = currentLoan.startDate.add(Duration(days: 30 * monthIdx));
      final year = date.year;

      final principalPaid = (prevBal - bal).clamp(0.0, double.infinity);
      final interestPaid =
          (currentLoan.emiAmount - principalPaid).clamp(0.0, double.infinity);

      if (!yearlyData.containsKey(year)) {
        yearlyData[year] = {'principal': 0, 'interest': 0};
      }
      yearlyData[year]!['principal'] =
          yearlyData[year]!['principal']! + principalPaid;
      yearlyData[year]!['interest'] =
          yearlyData[year]!['interest']! + interestPaid;

      prevBal = bal;
    }

    final years = yearlyData.keys.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Amortization Curve (Yearly)', style: theme.textTheme.titleMedium),
        const SizedBox(height: 16),
        SizedBox(
          height: 250,
          child: BarChart(
            BarChartData(
              gridData: const FlGridData(show: false),
              barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => Colors.blueGrey,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final year = years[group.x.toInt()];
                        final p = yearlyData[year]!['principal']!;
                        final i = yearlyData[year]!['interest']!;
                        return BarTooltipItem(
                            '$year\n',
                            const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                            children: [
                              TextSpan(
                                  text:
                                      'Principal: ${NumberFormat.compact().format(p)}\n',
                                  style: const TextStyle(
                                      color: Colors.greenAccent, fontSize: 12)),
                              TextSpan(
                                  text:
                                      'Interest: ${NumberFormat.compact().format(i)}',
                                  style: const TextStyle(
                                      color: Color(0xFF64B5F6), fontSize: 12)),
                            ]);
                      })),
              titlesData: FlTitlesData(
                leftTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      if (value.toInt() >= 0 && value.toInt() < years.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(years[value.toInt()].toString(),
                              style: const TextStyle(fontSize: 10)),
                        );
                      }
                      return const SizedBox();
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              barGroups: years.asMap().entries.map((entry) {
                final index = entry.key;
                final data = entry.value;
                final p = yearlyData[data]!['principal']!;
                final i = yearlyData[data]!['interest']!;

                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: p + i,
                      color: Colors.transparent,
                      width: 16,
                      rodStackItems: [
                        BarChartRodStackItem(0, p, Colors.green),
                        BarChartRodStackItem(p, p + i, const Color(0xFF64B5F6)),
                      ],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSimulatorView(ThemeData theme, Loan currentLoan, double progress,
      String currencyLocale, NumberFormat currency, LoanService loanService) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              PureIcons.info(color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Total Interest Payable: ${NumberFormat.simpleCurrency(locale: currencyLocale).format(currentLoan.emiAmount * currentLoan.tenureMonths - currentLoan.totalPrincipal)}\n'
                  'Estimated Yearly Interest: ${NumberFormat.simpleCurrency(locale: currencyLocale).format(currentLoan.totalPrincipal * currentLoan.interestRate / 100)}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          decoration: InputDecoration(
            labelText: 'Extra Payment Amount',
            prefixText:
                '${NumberFormat.simpleCurrency(locale: currencyLocale).currencySymbol} ',
            border: const OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          onChanged: (v) {
            setState(() {
              _prepaymentAmount = double.tryParse(v) ?? 0;
              _isSimulating = true;
            });
          },
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: RadioListTile<bool>.adaptive(
                title: const Text('Reduce Tenure'),
                value: true,
                groupValue: _reduceTenure,
                onChanged: (v) {
                  if (v != null) setState(() => _reduceTenure = v);
                },
              ),
            ),
            Expanded(
              child: RadioListTile<bool>.adaptive(
                title: const Text('Reduce EMI'),
                value: false,
                groupValue: _reduceTenure,
                onChanged: (v) {
                  if (v != null) setState(() => _reduceTenure = v);
                },
              ),
            ),
          ],
        ),
        if (_isSimulating && _prepaymentAmount > 0) ...[
          const Divider(),
          Builder(builder: (context) {
            final impact = loanService.calculatePrepaymentImpact(
                loan: currentLoan,
                prepaymentAmount: _prepaymentAmount,
                reduceTenure: _reduceTenure);
            return Column(
              children: [
                ListTile(
                  title: Text(_reduceTenure ? 'New Tenure' : 'New EMI'),
                  trailing: Text(
                    _reduceTenure
                        ? '${impact['newTenure']} months'
                        : currency.format(impact['newEMI']),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                ),
                ListTile(
                  title: const Text('Interest Saved'),
                  trailing: Text(
                    currency.format(impact['interestSaved']),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                ),
                if (_reduceTenure && (impact['tenureSaved'] ?? 0) > 0)
                  ListTile(
                    title: const Text('Tenure Reduced'),
                    trailing: Text(
                      '${impact['tenureSaved']} months',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                  ),
              ],
            );
          }),
        ]
      ],
    );
  }
  // --- Gold Loan Dialogs ---

  void _showGoldLoanInterestPaymentDialog(
      Loan currentLoan, double accruedInterest) {
    final amountController =
        TextEditingController(text: accruedInterest.toStringAsFixed(2));
    final dateController = TextEditingController(
        text: DateFormat('yyyy-MM-dd').format(DateTime.now()));
    DateTime selectedDate = DateTime.now();
    String? selectedAccountId = currentLoan.accountId;
    final accounts = ref.read(accountsProvider).value ?? [];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Pay Interest & Renew'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                    'Pay the interest due to renew the loan tenure or simply clear dues. Principal will NOT be reduced.'),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(
                      labelText: 'Interest Amount', prefixText: '₹ '),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final d = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2030));
                    if (d != null) {
                      setState(() {
                        selectedDate = d;
                        dateController.text =
                            DateFormat('yyyy-MM-dd').format(d);
                      });
                    }
                  },
                  child: TextField(
                    controller: dateController,
                    decoration: InputDecoration(
                        labelText: 'Date Effective',
                        prefixIcon: PureIcons.calendar()),
                    readOnly: true,
                    enabled: false,
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String?>(
                  initialValue: selectedAccountId,
                  decoration:
                      const InputDecoration(labelText: 'Paid From Account'),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('Manual (No account)')),
                    ...accounts.map((a) =>
                        DropdownMenuItem(value: a.id, child: Text(a.name))),
                  ],
                  onChanged: (v) => setState(() => selectedAccountId = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                child: const Text('Cancel'),
                onPressed: () => Navigator.pop(context)),
            ElevatedButton(
              child: const Text('Pay & Renew'),
              onPressed: () async {
                final amount = double.tryParse(amountController.text);
                if (amount != null && amount > 0) {
                  final storage = ref.read(storageServiceProvider);
                  var loan = currentLoan;

                  // Create Loan Transaction (Interest Only)
                  // We treat this as an 'EMI' where principal component is 0.
                  final loanTxn = LoanTransaction(
                    id: const Uuid().v4(),
                    date: selectedDate,
                    amount: amount,
                    type: LoanTransactionType.emi,
                    principalComponent: 0,
                    interestComponent: amount,
                    resultantPrincipal: loan.remainingPrincipal, // Unchanged
                  );

                  loan.transactions = [...loan.transactions, loanTxn];

                  // Record Expense Transaction
                  if (selectedAccountId != null) {
                    final acc =
                        accounts.firstWhere((a) => a.id == selectedAccountId);
                    final expTxn = Transaction.create(
                      title: 'Loan Interest: ${loan.name}',
                      amount: amount,
                      type: TransactionType.expense,
                      category: 'Loan Interest',
                      accountId: selectedAccountId!,
                      date: selectedDate,
                      loanId: loan.id,
                    );
                    acc.balance -= amount;
                    await storage.saveAccount(acc);
                    await storage.saveTransaction(expTxn);
                  }

                  await storage.saveLoan(loan);
                  ref.invalidate(loansProvider);
                  ref.invalidate(transactionsProvider);
                  ref.invalidate(accountsProvider);
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                }
              },
            )
          ],
        ),
      ),
    );
  }

  void _showCloseGoldLoanDialog(Loan currentLoan, double accruedInterest) {
    final totalDue = currentLoan.remainingPrincipal + accruedInterest;
    final amountController =
        TextEditingController(text: totalDue.toStringAsFixed(2));
    String? selectedAccountId = currentLoan.accountId;
    final accounts = ref.read(accountsProvider).value ?? [];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Close Gold Loan'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                    'Pay Principal (₹${currentLoan.remainingPrincipal.toStringAsFixed(2)}) + Interest (₹${accruedInterest.toStringAsFixed(2)}) to close this loan.'),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(
                      labelText: 'Total Payment Amount', prefixText: '₹ '),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String?>(
                  initialValue: selectedAccountId,
                  decoration:
                      const InputDecoration(labelText: 'Paid From Account'),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('Manual (No account)')),
                    ...accounts.map((a) =>
                        DropdownMenuItem(value: a.id, child: Text(a.name))),
                  ],
                  onChanged: (v) => setState(() => selectedAccountId = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                child: const Text('Cancel'),
                onPressed: () => Navigator.pop(context)),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text('Close Loan'),
              onPressed: () async {
                final amount = double.tryParse(amountController.text);
                if (amount != null &&
                    amount >= currentLoan.remainingPrincipal) {
                  final storage = ref.read(storageServiceProvider);
                  var loan = currentLoan;

                  final interestPaid = amount - loan.remainingPrincipal;

                  // Create Final Transaction
                  final loanTxn = LoanTransaction(
                    id: const Uuid().v4(),
                    date: DateTime.now(),
                    amount: amount,
                    type: LoanTransactionType.prepayment, // Or 'closure'
                    principalComponent: loan.remainingPrincipal,
                    interestComponent: interestPaid,
                    resultantPrincipal: 0,
                  );

                  loan.transactions = [...loan.transactions, loanTxn];
                  loan.remainingPrincipal = 0;
                  // Usually we don't delete, just 0 balance implies closed.

                  // Record Expense Transaction
                  if (selectedAccountId != null) {
                    final acc =
                        accounts.firstWhere((a) => a.id == selectedAccountId);
                    final expTxn = Transaction.create(
                      title: 'Loan Closure: ${loan.name}',
                      amount: amount,
                      type: TransactionType.expense,
                      category: 'Loan Repayment',
                      accountId: selectedAccountId!,
                      date: DateTime.now(),
                      loanId: loan.id,
                    );
                    acc.balance -= amount;
                    await storage.saveAccount(acc);
                    await storage.saveTransaction(expTxn);
                  }

                  await storage.saveLoan(loan);
                  ref.invalidate(loansProvider);
                  ref.invalidate(transactionsProvider);
                  ref.invalidate(accountsProvider);
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                }
              },
            )
          ],
        ),
      ),
    );
  }

  void _showRateChangeDialog(Loan currentLoan) {
    final rateController = TextEditingController();
    final dateController = TextEditingController(
        text: DateFormat('yyyy-MM-dd').format(DateTime.now()));
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Update Interest Rate'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                  'Record a change in the annual interest rate. This will affect future accruals from the selected date.'),
              const SizedBox(height: 16),
              TextField(
                controller: rateController,
                decoration: const InputDecoration(
                    labelText: 'New Annual Rate (%)', suffixText: '%'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final d = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: currentLoan.startDate,
                      lastDate: DateTime(2030));
                  if (d != null) {
                    setState(() {
                      selectedDate = d;
                      dateController.text = DateFormat('yyyy-MM-dd').format(d);
                    });
                  }
                },
                child: TextField(
                  controller: dateController,
                  decoration: InputDecoration(
                      labelText: 'Date Effective',
                      prefixIcon: PureIcons.calendar()),
                  readOnly: true,
                  enabled: false,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final newRate = double.tryParse(rateController.text);
                if (newRate == null || newRate <= 0) return;

                final txn = LoanTransaction(
                  id: const Uuid().v4(),
                  date: selectedDate,
                  amount: newRate,
                  type: LoanTransactionType.rateChange,
                  principalComponent: 0,
                  interestComponent: 0,
                  resultantPrincipal: currentLoan.remainingPrincipal,
                );

                currentLoan.transactions.add(txn);
                await ref.read(storageServiceProvider).saveLoan(currentLoan);
                ref.invalidate(loansProvider);

                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text('Update Rate'),
            ),
          ],
        ),
      ),
    );
  }

  void _showBulkPaymentDialog(Loan currentLoan) {
    DateTime startDate = DateTime(DateTime.now().year, 1, 1);
    DateTime endDate = DateTime.now();
    bool isProcessing = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Bulk Record Payments'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                  'Record EMI payments for a date range automatically. Assumes paid on time.'),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Start Date'),
                subtitle: Text(DateFormat('yyyy-MM-dd').format(startDate)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final d = await showDatePicker(
                      context: context,
                      initialDate: startDate,
                      firstDate: DateTime(2010),
                      lastDate: DateTime.now());
                  if (d != null) setState(() => startDate = d);
                },
              ),
              ListTile(
                title: const Text('End Date'),
                subtitle: Text(DateFormat('yyyy-MM-dd').format(endDate)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final d = await showDatePicker(
                      context: context,
                      initialDate: endDate,
                      firstDate: DateTime(2010),
                      lastDate: DateTime.now());
                  if (d != null) setState(() => endDate = d);
                },
              ),
              if (isProcessing) const LinearProgressIndicator(),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: isProcessing
                  ? null
                  : () async {
                      setState(() => isProcessing = true);
                      await _handleBulkPayment(
                        currentLoan: currentLoan,
                        startDate: startDate,
                        endDate: endDate,
                      );
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    },
              child: const Text('Record Payments'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleBulkPayment({
    required Loan currentLoan,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final storage = ref.read(storageServiceProvider);
    var loan = currentLoan;

    DateTime current = DateTime(startDate.year, startDate.month, 1);
    final end = DateTime(endDate.year, endDate.month, 1);

    int count = 0;
    List<Transaction> newTxns = [];
    List<LoanTransaction> newLoanTxns = [];

    while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
      final emiDate = DateTime(current.year, current.month, loan.emiDay);
      final exists = loan.transactions.any((t) =>
          t.type == LoanTransactionType.emi &&
          t.date.year == emiDate.year &&
          t.date.month == emiDate.month);

      if (!exists && emiDate.isAfter(loan.startDate)) {
        final interest =
            (loan.remainingPrincipal * loan.interestRate / 12) / 100;
        final principalComp = loan.emiAmount - interest;

        final loanTxn = LoanTransaction(
          id: const Uuid().v4(),
          date: emiDate,
          amount: loan.emiAmount,
          type: LoanTransactionType.emi,
          principalComponent: principalComp,
          interestComponent: interest,
          resultantPrincipal: loan.remainingPrincipal - principalComp,
        );

        loan.remainingPrincipal -= principalComp;
        newLoanTxns.add(loanTxn);

        if (loan.accountId != null) {
          final expTxn = Transaction.create(
            title: 'Loan EMI: ${loan.name}',
            amount: loan.emiAmount,
            type: TransactionType.expense,
            category: 'Loan Repayment',
            accountId: loan.accountId!,
            date: emiDate,
            loanId: loan.id,
          );
          newTxns.add(expTxn);
        }
        count++;
      }
      current = DateTime(current.year, current.month + 1, 1);
    }

    loan.transactions = [...loan.transactions, ...newLoanTxns];
    loan.transactions.sort((a, b) => a.date.compareTo(b.date));

    await storage.saveLoan(loan);
    for (final t in newTxns) {
      await storage.saveTransaction(t);
    }

    ref.invalidate(loansProvider);
    ref.invalidate(transactionsProvider);
    ref.invalidate(accountsProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Recorded $count payments successfully.')));
    }
  }

  Future<void> _showDeleteLoanDialog(Loan currentLoan) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Loan?'),
        content: const Text(
            'This will remove the loan tracking. Existing transactions will NOT be deleted.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(storageServiceProvider).deleteLoan(currentLoan.id);
      final _ = ref.refresh(loansProvider);
      if (context.mounted) {
        Navigator.pop(context);
      }
    }
  }
}
