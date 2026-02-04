import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart'; // Added for Uuid

import '../providers.dart';
import '../models/loan.dart';
import '../models/transaction.dart';

import 'loan_payment_dialog.dart';
import '../services/loan_service.dart';
import '../widgets/pure_icons.dart';

// Extracted Components
import 'loan/loan_topup_dialog.dart';
import 'loan/loan_part_payment_dialog.dart';
import 'loan/loan_update_rate_dialog.dart';

import 'loan/loan_rename_dialog.dart';
import 'loan/loan_header_card.dart';
import 'loan/loan_ledger_view.dart';
import 'loan/loan_gold_dialogs.dart';

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

        // --- Gold Loan Accrual Calculation for Actions ---
        final lastPaymentDate = currentLoan.transactions.isEmpty
            ? currentLoan.startDate
            : currentLoan.transactions
                .where((t) =>
                    t.type == LoanTransactionType.emi ||
                    t.type == LoanTransactionType.prepayment)
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

        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          appBar: AppBar(
            title: Text(currentLoan.name),
            actions: [
              if (!isGoldLoan)
                IconButton(
                  icon: PureIcons.addCircle(),
                  tooltip: 'Top-up Loan',
                  onPressed: () => showDialog(
                      context: context,
                      builder: (_) => LoanTopupDialog(loan: currentLoan)),
                ),
              IconButton(
                icon: PureIcons.editOutlined(),
                tooltip: 'Rename Loan',
                onPressed: () => showDialog(
                    context: context,
                    builder: (_) => LoanRenameDialog(loan: currentLoan)),
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
                LoanHeaderCard(
                  loan: currentLoan,
                  onBulkPay: () => _showBulkPaymentDialog(currentLoan),
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
                          onPressed: () => showDialog(
                            context: context,
                            builder: (_) => GoldLoanInterestPaymentDialog(
                                loan: currentLoan,
                                accruedInterest: accruedInterest),
                          ),
                          icon: Icons.refresh,
                          label: 'Renew',
                          color: Colors.blue[800]!,
                        ),
                        _buildGoldAction(
                          onPressed: () => showDialog(
                              context: context,
                              builder: (_) =>
                                  LoanPartPaymentDialog(loan: currentLoan)),
                          icon: Icons.show_chart,
                          label: 'Part Pay',
                          color: Colors.orange[800]!,
                        ),
                        _buildGoldAction(
                          onPressed: () => showDialog(
                              context: context,
                              builder: (_) =>
                                  LoanUpdateRateDialog(loan: currentLoan)),
                          icon: Icons.percent,
                          label: 'Rate',
                          color: Colors.purple[800]!,
                        ),
                        _buildGoldAction(
                          onPressed: () => showDialog(
                            context: context,
                            builder: (_) => GoldLoanCloseDialog(
                                loan: currentLoan,
                                accruedInterest: accruedInterest),
                          ),
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
                  LoanLedgerView(loan: currentLoan),
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

  // --- Navigation & Helper Widgets ---

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
                borderRadius: BorderRadius.circular(8))
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PureIcons.icon(icon,
                color: isSelected ? theme.colorScheme.primary : Colors.grey),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? theme.colorScheme.primary : Colors.grey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
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
      width: 85,
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
        RadioGroup<bool>(
          groupValue: _reduceTenure,
          onChanged: (v) {
            if (v != null) setState(() => _reduceTenure = v);
          },
          child: const Row(
            children: [
              Expanded(
                child: RadioListTile<bool>.adaptive(
                  title: Text('Reduce Tenure'),
                  value: true,
                ),
              ),
              Expanded(
                child: RadioListTile<bool>.adaptive(
                  title: Text('Reduce EMI'),
                  value: false,
                ),
              ),
            ],
          ),
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
      ref.invalidate(loansProvider);
      ref.invalidate(transactionsProvider);
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }
}
