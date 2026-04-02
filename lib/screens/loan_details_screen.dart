import 'package:samriddhi_flow/utils/regex_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'package:samriddhi_flow/l10n/app_localizations.dart';

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
      data: (loans) => _buildLoadedState(
        loans,
        theme,
        currencyProviderValue,
        currency,
        loanService,
      ),
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(
          body: Center(child: Text('Error: $err'))), // coverage:ignore-line
    );
  }

  Widget _buildLoadedState(
    List<Loan> loans,
    ThemeData theme,
    String currencyProviderValue,
    NumberFormat currency,
    dynamic loanService,
  ) {
    final currentLoan = loans.firstWhere((l) => l.id == widget.loan.id,
        orElse: () => widget.loan); // coverage:ignore-line
    final isGoldLoan = currentLoan.type == LoanType.gold;

    final schedule = !isGoldLoan
        ? loanService.calculateAmortizationSchedule(currentLoan)
        : [];

    final progress = currentLoan.totalPrincipal > 0
        ? (currentLoan.totalPrincipal - currentLoan.remainingPrincipal) /
            currentLoan.totalPrincipal
        : 0.0;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: _buildAppBar(currentLoan, isGoldLoan),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 16),
            child: Column(
              children: [
                LoanHeaderCard(
                  loan: currentLoan,
                  onBulkPay: () => _showBulkPaymentDialog(
                      currentLoan), // coverage:ignore-line
                ),
                const SizedBox(height: 16),
                if (!isGoldLoan)
                  _buildStandardControls(theme, currentLoan)
                else
                  _buildGoldLoanControls(currentLoan),
                const Divider(),
                const SizedBox(height: 8),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Builder(
                builder: (context) {
                  if (isGoldLoan || _currentView == LoanDetailView.ledger) {
                    return LoanLedgerView(loan: currentLoan);
                  } else if (!isGoldLoan &&
                      _currentView == LoanDetailView.amortization) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _buildAmortizationView(theme,
                          schedule.cast<Map<String, dynamic>>(), currentLoan),
                    );
                  } else if (!isGoldLoan &&
                      _currentView == LoanDetailView.simulator) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _buildSimulatorView(theme, currentLoan, progress,
                          currencyProviderValue, currency, loanService),
                    );
                  }
                  return const SizedBox();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar(Loan currentLoan, bool isGoldLoan) {
    return AppBar(
      title: Text(currentLoan.name),
      actions: [
        if (!isGoldLoan)
          IconButton(
            icon: PureIcons.addCircle(),
            tooltip: AppLocalizations.of(context)!.topUpLoanTooltip,
            onPressed: () {
              FocusScope.of(context).unfocus();
              showDialog(
                  context: context,
                  builder: (_) => LoanTopupDialog(loan: currentLoan));
            },
          ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          tooltip: AppLocalizations.of(context)!.moreOptionsTooltip,
          onSelected: (value) {
            if (value == 'rename') {
              // coverage:ignore-start
              showDialog(
                  context: context,
                  builder: (_) => LoanRenameDialog(loan: currentLoan));
              // coverage:ignore-end
            } else if (value == 'delete') {
              _showDeleteLoanDialog(currentLoan);
            }
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            PopupMenuItem<String>(
              value: 'rename',
              child: Text(AppLocalizations.of(context)!.renameLoanAction),
            ),
            PopupMenuItem<String>(
              value: 'delete',
              child: Text(AppLocalizations.of(context)!.deleteLoanAction),
            ),
          ],
        )
      ],
    );
  }

  Widget _buildStandardControls(ThemeData theme, Loan currentLoan) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavIcon(
              Icons.show_chart,
              AppLocalizations.of(context)!.amortizationTab,
              LoanDetailView.amortization,
              theme),
          _buildNavIcon(
              Icons.calculate_outlined,
              AppLocalizations.of(context)!.simulatorTab,
              LoanDetailView.simulator,
              theme),
          _buildNavIcon(Icons.list_alt, AppLocalizations.of(context)!.ledgerTab,
              LoanDetailView.ledger, theme),
          _buildPayButton(currentLoan),
        ],
      ),
    );
  }

  Widget _buildPayButton(Loan currentLoan) {
    return InkWell(
      onTap: () {
        FocusScope.of(context).unfocus();
        showDialog(
            context: context,
            builder: (_) => RecordLoanPaymentDialog(loan: currentLoan));
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PureIcons.payment(color: Colors.green),
            const SizedBox(height: 4),
            Text(AppLocalizations.of(context)!.payAction,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.green)),
          ],
        ),
      ),
    );
  }

  Widget _buildGoldLoanControls(Loan currentLoan) {
    final accruedInterest = _calculateAccruedInterest(currentLoan);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          _buildGoldAction(
            // coverage:ignore-start
            onPressed: () => showDialog(
              context: context,
              builder: (_) => GoldLoanInterestPaymentDialog(
                  // coverage:ignore-end
                  loan: currentLoan,
                  accruedInterest: accruedInterest),
            ),
            icon: Icons.refresh,
            label: AppLocalizations.of(context)!.renewAction,
            color: Colors.blue[800]!,
          ),
          _buildGoldAction(
            // coverage:ignore-start
            onPressed: () => showDialog(
                context: context,
                builder: (_) => LoanPartPaymentDialog(loan: currentLoan)),
            // coverage:ignore-end
            icon: Icons.show_chart,
            label: AppLocalizations.of(context)!.partPayAction,
            color: Colors.orange[800]!,
          ),
          _buildGoldAction(
            onPressed: () => showDialog(
                context: context,
                builder: (_) => LoanUpdateRateDialog(loan: currentLoan)),
            icon: Icons.percent,
            label: AppLocalizations.of(context)!.rateAction,
            color: Colors.purple[800]!,
          ),
          _buildGoldAction(
            // coverage:ignore-start
            onPressed: () => showDialog(
              context: context,
              builder: (_) => GoldLoanCloseDialog(
                  // coverage:ignore-end
                  loan: currentLoan,
                  accruedInterest: accruedInterest),
            ),
            icon: Icons.check_circle_outline,
            label: AppLocalizations.of(context)!.closeAction,
            color: Colors.green[800]!,
          ),
        ],
      ),
    );
  }

  double _calculateAccruedInterest(Loan loan) {
    return loan.calculateAccruedInterest();
  }

  // --- Navigation & Helper Widgets ---

  Widget _buildNavIcon(
      IconData icon, String label, LoanDetailView view, ThemeData theme) {
    final isSelected = _currentView == view;
    return InkResponse(
      onTap: () {
        FocusScope.of(context).unfocus();
        setState(() => _currentView = view);
      },
      radius: 32,
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
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
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
            onPressed: () {
              FocusScope.of(context).unfocus();
              onPressed();
            },
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

  // Annual Data Calculation
  Map<int, Map<String, double>> _calculateYearlyAmortizationData(
      List<Map<String, dynamic>> schedule, Loan currentLoan) {
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
        yearlyData[year] = {'principal': 0.0, 'interest': 0.0};
      }
      yearlyData[year]!['principal'] =
          yearlyData[year]!['principal']! + principalPaid;
      yearlyData[year]!['interest'] =
          yearlyData[year]!['interest']! + interestPaid;

      prevBal = bal;
    }
    return yearlyData;
  }

  Widget _buildAmortizationView(
      ThemeData theme, List<Map<String, dynamic>> schedule, Loan currentLoan) {
    final yearlyData = _calculateYearlyAmortizationData(schedule, currentLoan);

    final years = yearlyData.keys.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(AppLocalizations.of(context)!.amortizationCurveTitle,
            style: theme.textTheme.titleMedium),
        const SizedBox(height: 16),
        SizedBox(
          height: 250,
          child: BarChart(
            BarChartData(
              gridData: const FlGridData(show: false),
              barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                      // coverage:ignore-start
                      getTooltipColor: (_) => Colors.blueGrey,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final year = years[group.x.toInt()];
                        final p = yearlyData[year]!['principal']!;
                        final i = yearlyData[year]!['interest']!;
                        return BarTooltipItem(
                            '$year  ',
                            // coverage:ignore-end
                            const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                            children: [
                              // coverage:ignore-line
                              TextSpan(
                                  // coverage:ignore-line
                                  text:
                                      '${AppLocalizations.of(context)!.principalShort}: ${NumberFormat.compact().format(p)} | ', // coverage:ignore-line
                                  style: const TextStyle(
                                      color: Colors.greenAccent, fontSize: 12)),
                              TextSpan(
                                  // coverage:ignore-line
                                  text:
                                      '${AppLocalizations.of(context)!.interestShort}: ${NumberFormat.compact().format(i)}', // coverage:ignore-line
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
        _buildSimulatorHeader(currencyLocale, currentLoan),
        const SizedBox(height: 16),
        _buildPrepaymentInput(currencyLocale),
        const SizedBox(height: 16),
        _buildTenureEmiToggle(),
        if (_isSimulating && _prepaymentAmount > 0) ...[
          const Divider(),
          _buildSimulatorImpact(currentLoan, loanService, currency),
        ]
      ],
    );
  }

  Widget _buildSimulatorHeader(String currencyLocale, Loan currentLoan) {
    final l10n = AppLocalizations.of(context)!;
    final totalInterest = currentLoan.emiAmount * currentLoan.tenureMonths -
        currentLoan.totalPrincipal;
    final yearlyInterest =
        currentLoan.totalPrincipal * currentLoan.interestRate / 100;
    final currency = NumberFormat.simpleCurrency(locale: currencyLocale);

    return Container(
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
              '${l10n.totalInterestPayableLabel(currency.format(totalInterest))}'
              '${l10n.estimatedYearlyInterestLabel(currency.format(yearlyInterest))}',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrepaymentInput(String currencyLocale) {
    return TextFormField(
      decoration: InputDecoration(
        labelText: AppLocalizations.of(context)!.extraPaymentAmountLabel,
        prefixText:
            '${NumberFormat.simpleCurrency(locale: currencyLocale).currencySymbol} ',
        border: const OutlineInputBorder(),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
            RegexUtils.amountWithOptionalDecimalsExp),
      ],
      onChanged: (v) {
        setState(() {
          _prepaymentAmount = double.tryParse(v) ?? 0;
          _isSimulating = true;
        });
      },
    );
  }

  Widget _buildTenureEmiToggle() {
    return RadioGroup<bool>(
      groupValue: _reduceTenure,
      onChanged: (v) {
        // coverage:ignore-line
        if (v != null) {
          setState(() => _reduceTenure = v); // coverage:ignore-line
        }
      },
      child: Row(
        children: [
          Expanded(
            child: RadioListTile<bool>.adaptive(
              title: Text(AppLocalizations.of(context)!.reduceTenureLabel),
              value: true,
            ),
          ),
          Expanded(
            child: RadioListTile<bool>.adaptive(
              title: Text(AppLocalizations.of(context)!.reduceEmiLabel),
              value: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimulatorImpact(
      Loan currentLoan, LoanService loanService, NumberFormat currency) {
    final impact = loanService.calculatePrepaymentImpact(
        loan: currentLoan,
        prepaymentAmount: _prepaymentAmount,
        reduceTenure: _reduceTenure);

    return Column(
      children: [
        ListTile(
          title: Text(_reduceTenure
              ? AppLocalizations.of(context)!.newTenureLabel
              : AppLocalizations.of(context)!
                  .newEmiLabel), // coverage:ignore-line
          trailing: Text(
            _reduceTenure
                ? AppLocalizations.of(context)!.monthsCount(impact['newTenure'])
                : currency.format(impact['newEMI']), // coverage:ignore-line
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.green),
          ),
        ),
        ListTile(
          title: Text(AppLocalizations.of(context)!.interestSavedLabel),
          trailing: Text(
            currency.format(impact['interestSaved']),
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.green),
          ),
        ),
        if (_reduceTenure && (impact['tenureSaved'] ?? 0) > 0)
          ListTile(
            title: Text(AppLocalizations.of(context)!.tenureReducedLabel),
            trailing: Text(
              AppLocalizations.of(context)!.monthsCount(impact['tenureSaved']),
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.green),
            ),
          ),
      ],
    );
  }

  // coverage:ignore-start
  void _showBulkPaymentDialog(Loan currentLoan) {
    showDialog(
      context: context,
      builder: (context) => _BulkPaymentDialog(
        // coverage:ignore-end
        currentLoan: currentLoan,
        onProcessed: (startDate, endDate) => _handleBulkPayment(
          // coverage:ignore-line
          currentLoan: currentLoan,
          startDate: startDate,
          endDate: endDate,
        ),
      ),
    );
  }

  Future<void> _handleBulkPayment({
    // coverage:ignore-line
    required Loan currentLoan,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final storage = ref.read(storageServiceProvider); // coverage:ignore-line
    var loan = currentLoan;

    DateTime current =
        DateTime(startDate.year, startDate.month, 1); // coverage:ignore-line
    final end =
        DateTime(endDate.year, endDate.month, 1); // coverage:ignore-line

    int count = 0;
    List<Transaction> newTxns = []; // coverage:ignore-line
    List<LoanTransaction> newLoanTxns = []; // coverage:ignore-line

    // coverage:ignore-start
    while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
      final emiDate = DateTime(current.year, current.month, loan.emiDay);
      final exists = loan.transactions.any((t) =>
          t.type == LoanTransactionType.emi &&
          t.date.year == emiDate.year &&
          t.date.month == emiDate.month);
      // coverage:ignore-end

      if (!exists && emiDate.isAfter(loan.startDate)) {
        // coverage:ignore-line
        final interest = (loan.remainingPrincipal * loan.interestRate / 12) /
            100; // coverage:ignore-line
        final principalComp = loan.emiAmount - interest; // coverage:ignore-line

        final loanTxn = LoanTransaction(
          // coverage:ignore-line
          id: const Uuid().v4(), // coverage:ignore-line
          date: emiDate,
          amount: loan.emiAmount, // coverage:ignore-line
          type: LoanTransactionType.emi,
          principalComponent: principalComp,
          interestComponent: interest,
          resultantPrincipal:
              loan.remainingPrincipal - principalComp, // coverage:ignore-line
        );

        loan.remainingPrincipal -= principalComp; // coverage:ignore-line
        newLoanTxns.add(loanTxn); // coverage:ignore-line

        if (loan.accountId != null) {
          // coverage:ignore-line
          final expTxn = Transaction.create(
            // coverage:ignore-line
            title:
                '${AppLocalizations.of(context)!.loanEmiTitle}: ${loan.name}', // coverage:ignore-line
            amount: loan.emiAmount, // coverage:ignore-line
            type: TransactionType.expense,
            category: AppLocalizations.of(context)!
                .bankLoanCategory, // coverage:ignore-line
            accountId: loan.accountId!, // coverage:ignore-line
            date: emiDate,
            loanId: loan.id, // coverage:ignore-line
          );
          newTxns.add(expTxn); // coverage:ignore-line
        }
        count++; // coverage:ignore-line
      }
      current =
          DateTime(current.year, current.month + 1, 1); // coverage:ignore-line
    }

    loan.transactions = [
      ...loan.transactions,
      ...newLoanTxns
    ]; // coverage:ignore-line
    loan.transactions
        .sort((a, b) => a.date.compareTo(b.date)); // coverage:ignore-line

    // coverage:ignore-start
    await storage.saveLoan(loan);
    for (final t in newTxns) {
      await storage.saveTransaction(t);
      // coverage:ignore-end
    }

    // coverage:ignore-start
    ref.invalidate(loansProvider);
    ref.invalidate(transactionsProvider);
    ref.invalidate(accountsProvider);
    // coverage:ignore-end

    // coverage:ignore-start
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              AppLocalizations.of(context)!.recordedPaymentsSuccess(count))));
      // coverage:ignore-end
    }
  }

  Future<void> _showDeleteLoanDialog(Loan currentLoan) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.deleteLoanConfirmTitle),
        content: Text(AppLocalizations.of(context)!.deleteLoanConfirmMessage),
        actions: [
          TextButton(
              onPressed: () =>
                  Navigator.pop(ctx, false), // coverage:ignore-line
              child: Text(AppLocalizations.of(context)!.cancelButton)),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(AppLocalizations.of(context)!.deleteAction,
                  style: const TextStyle(color: Colors.red))),
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

  // Removed unreferenced methods which were out of scope.
}

class _BulkPaymentDialog extends StatefulWidget {
  final Loan currentLoan;
  final Future<void> Function(DateTime startDate, DateTime endDate) onProcessed;

  const _BulkPaymentDialog({
    // coverage:ignore-line
    required this.currentLoan,
    required this.onProcessed,
  });

  @override // coverage:ignore-line
  State<_BulkPaymentDialog> createState() =>
      _BulkPaymentDialogState(); // coverage:ignore-line
}

class _BulkPaymentDialogState extends State<_BulkPaymentDialog> {
  late DateTime _startDate;
  late DateTime _endDate;
  bool _isProcessing = false;

  @override // coverage:ignore-line
  void initState() {
    // coverage:ignore-start
    super.initState();
    _startDate = DateTime(DateTime.now().year, 1, 1);
    _endDate = DateTime.now();
    // coverage:ignore-end
  }

  @override // coverage:ignore-line
  Widget build(BuildContext context) {
    // coverage:ignore-start
    return AlertDialog(
      title: Text(AppLocalizations.of(context)!.bulkRecordPaymentsTitle),
      content: Column(
        // coverage:ignore-end
        mainAxisSize: MainAxisSize.min,
        children: [
          // coverage:ignore-line
          Text(AppLocalizations.of(context)!
              .bulkRecordDesc), // coverage:ignore-line
          const SizedBox(height: 16),
          // coverage:ignore-start
          _buildBulkDateTile(
            AppLocalizations.of(context)!.startDateLabel,
            _startDate,
            (d) => setState(() => _startDate = d),
            // coverage:ignore-end
          ),
          // coverage:ignore-start
          _buildBulkDateTile(
            AppLocalizations.of(context)!.endDateLabel,
            _endDate,
            (d) => setState(() => _endDate = d),
            // coverage:ignore-end
          ),
          if (_isProcessing)
            const LinearProgressIndicator(), // coverage:ignore-line
        ],
      ),
      // coverage:ignore-start
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancelButton)),
        ElevatedButton(
          onPressed: _isProcessing
              // coverage:ignore-end
              ? null
              // coverage:ignore-start
              : () async {
                  setState(() => _isProcessing = true);
                  await widget.onProcessed(_startDate, _endDate);
                  if (context.mounted) {
                    Navigator.pop(context);
                    // coverage:ignore-end
                  }
                },
          child: Text(AppLocalizations.of(context)!
              .recordPaymentsAction), // coverage:ignore-line
        ),
      ],
    );
  }

  ListTile _buildBulkDateTile(
      // coverage:ignore-line
      String title,
      DateTime date,
      ValueChanged<DateTime> onSelect) {
    // coverage:ignore-start
    return ListTile(
      title: Text(title),
      subtitle: Text(DateFormat('yyyy-MM-dd').format(date)),
      // coverage:ignore-end
      trailing: const Icon(Icons.calendar_today),
      // coverage:ignore-start
      onTap: () async {
        final d = await showDatePicker(
            context: context,
            // coverage:ignore-end
            initialDate: date,
            // coverage:ignore-start
            firstDate: DateTime(2010),
            lastDate: DateTime.now());
        if (d != null) onSelect(d);
        // coverage:ignore-end
      },
    );
  }
}
