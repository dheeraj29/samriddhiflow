import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:samriddhi_flow/l10n/app_localizations.dart';
import '../../models/account.dart';
import '../../models/loan.dart';
import '../../models/transaction.dart';
import '../../providers.dart';
import '../../widgets/form_utils.dart';

class LoanTopupDialog extends ConsumerStatefulWidget {
  final Loan loan;

  const LoanTopupDialog({super.key, required this.loan});

  @override
  ConsumerState<LoanTopupDialog> createState() => _LoanTopupDialogState();
}

class _LoanTopupDialogState extends ConsumerState<LoanTopupDialog> {
  final _amountController = TextEditingController();
  bool _updateTenure = false; // false = Adjust EMI, true = Adjust Tenure
  String? _selectedAccountId;

  @override
  void initState() {
    super.initState();
    _selectedAccountId = widget.loan.accountId;
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppLocalizations.of(context)!.loanTopUpDialogTitle),
      content: _buildDialogContent(),
      actions: _buildActions(),
    );
  }

  Widget _buildDialogContent() {
    final currency = ref.watch(currencyProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(AppLocalizations.of(context)!.borrowMoreDescription),
        const SizedBox(height: 16),
        FormUtils.buildAmountField(
          controller: _amountController,
          currency: currency,
          label: AppLocalizations.of(context)!.topUpAmountLabel,
          autofocus: true,
        ),
        const SizedBox(height: 16),
        _buildAccountSelector(),
        const SizedBox(height: 16),
        Text(AppLocalizations.of(context)!.recalculationModeLabel,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        _buildRecalculationMode(),
      ],
    );
  }

  Widget _buildAccountSelector() {
    return ref.watch(accountsProvider).when(
          data: (accounts) => FormUtils.buildAccountSelector(
            value: _selectedAccountId ?? 'manual',
            accounts: accounts,
            onChanged: (v) =>
                setState(() => _selectedAccountId = v), // coverage:ignore-line
            label: AppLocalizations.of(context)!.creditToAccountLabel,
            allowManual: true,
          ),
          loading: () => const LinearProgressIndicator(),
          error: (_, __) => const SizedBox(), // coverage:ignore-line
        );
  }

  Widget _buildRecalculationMode() {
    return RadioGroup<bool>(
      groupValue: _updateTenure,
      onChanged: (v) {
        // coverage:ignore-line
        if (v != null) {
          setState(() => _updateTenure = v); // coverage:ignore-line
        }
      },
      child: Column(
        children: [
          RadioListTile<bool>.adaptive(
            title: Text(AppLocalizations.of(context)!.adjustEmiOption),
            subtitle: Text(AppLocalizations.of(context)!.adjustEmiSubtitle),
            value: false,
          ),
          RadioListTile<bool>.adaptive(
            title: Text(AppLocalizations.of(context)!.adjustTenureOption),
            subtitle: Text(AppLocalizations.of(context)!.adjustTenureSubtitle),
            value: true,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildActions() {
    return [
      TextButton(
          onPressed: () => Navigator.pop(context), // coverage:ignore-line
          child: Text(AppLocalizations.of(context)!.cancelButton)),
      ElevatedButton(
        onPressed: _onBorrowPressed,
        child: Text(AppLocalizations.of(context)!.borrowAction),
      ),
    ];
  }

  void _onBorrowPressed() async {
    final topupAmount = double.tryParse(_amountController.text);
    if (topupAmount != null && topupAmount > 0) {
      await _handleLoanTopup(
        loan: widget.loan,
        topupAmount: topupAmount,
        selectedAccountId:
            _selectedAccountId == 'manual' ? null : _selectedAccountId,
        updateTenure: _updateTenure,
        accounts: ref.read(accountsProvider).value ?? [],
      );
      if (mounted) Navigator.pop(context);
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

    final lastDate = loan.transactions.isNotEmpty
        // coverage:ignore-start
        ? loan.transactions
            .map((t) => t.date)
            .reduce((a, b) => a.isAfter(b) ? a : b)
        // coverage:ignore-end
        : loan.startDate;

    final accruedInterest = loanService.calculateAccruedInterest(
      principal: loan.remainingPrincipal,
      annualRate: loan.interestRate,
      fromDate: lastDate,
      toDate: topupDate,
    );

    loan.totalPrincipal += topupAmount;
    loan.remainingPrincipal += topupAmount;

    loan.transactions = [
      ...loan.transactions,
      LoanTransaction(
        id: const Uuid().v4(),
        date: topupDate,
        amount: topupAmount,
        type: LoanTransactionType.topup,
        principalComponent: topupAmount,
        interestComponent: accruedInterest,
        resultantPrincipal: loan.remainingPrincipal,
      )
    ];

    _recalibrateLoan(loan, loanService, updateTenure, topupDate);

    if (selectedAccountId != null) {
      await _recordTopupIncome(
          selectedAccountId, topupAmount, accounts, storage);
    }

    await storage.saveLoan(loan);
    ref.invalidate(loansProvider);
    ref.invalidate(transactionsProvider);
    ref.invalidate(accountsProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(AppLocalizations.of(context)!.loanTopUpSuccessMessage)));
    }
  }

  void _recalibrateLoan(
      Loan loan, dynamic loanService, bool updateTenure, DateTime topupDate) {
    if (!updateTenure) {
      final monthsPassed = topupDate.difference(loan.startDate).inDays ~/ 30;
      final remainingMonths = (loan.tenureMonths - monthsPassed).clamp(1, 600);
      loan.emiAmount = loanService.calculateEMI(
        principal: loan.remainingPrincipal,
        annualRate: loan.interestRate,
        tenureMonths: remainingMonths,
      );
    } else {
      // coverage:ignore-start
      loan.tenureMonths = loanService.calculateTenureForEMI(
        principal: loan.remainingPrincipal,
        annualRate: loan.interestRate,
        emi: loan.emiAmount,
        // coverage:ignore-end
      );
    }
  }

  Future<void> _recordTopupIncome(String selectedAccountId, double topupAmount,
      List<Account> accounts, dynamic storage) async {
    final acc = accounts.firstWhere((a) => a.id == selectedAccountId);
    final financeTxn = Transaction.create(
      title: AppLocalizations.of(ref.context)!.loanTopUpTitle,
      amount: topupAmount,
      type: TransactionType.income,
      category: AppLocalizations.of(ref.context)!.loanTopUpCategory,
      accountId: selectedAccountId,
      date: DateTime.now(),
      loanId: widget.loan.id,
    );
    acc.balance += topupAmount;
    await storage.saveAccount(acc);
    await storage.saveTransaction(financeTxn);
  }
}
