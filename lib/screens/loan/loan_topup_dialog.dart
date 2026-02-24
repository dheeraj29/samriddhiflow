import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
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
  Widget build(BuildContext context) {
    final currency = ref.watch(currencyProvider);

    return AlertDialog(
      title: const Text('Loan Top-up'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Borrow more money on this loan.'),
          const SizedBox(height: 16),
          FormUtils.buildAmountField(
            controller: _amountController,
            currency: currency,
            label: 'Top-up Amount',
            autofocus: true,
          ),
          const SizedBox(height: 16),
          ref.watch(accountsProvider).when(
                data: (accounts) {
                  return FormUtils.buildAccountSelector(
                    value: _selectedAccountId ?? 'manual',
                    accounts: accounts,
                    onChanged: (v) => setState(() => _selectedAccountId = v),
                    label: 'Credit to Account',
                    allowManual: true,
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const SizedBox(),
              ),
          const SizedBox(height: 16),
          const Text('Recalculation Mode:',
              style: TextStyle(fontWeight: FontWeight.bold)),
          RadioGroup<bool>(
            groupValue: _updateTenure,
            onChanged: (v) {
              if (v != null) setState(() => _updateTenure = v);
            },
            child: const Column(
              children: [
                RadioListTile<bool>.adaptive(
                  title: Text('Adjust EMI'),
                  subtitle:
                      Text('Keep Tenure constant. EMI will increase.'),
                  value: false,
                ),
                RadioListTile<bool>.adaptive(
                  title: Text('Adjust Tenure'),
                  subtitle:
                      Text('Keep EMI constant. Tenure will increase.'),
                  value: true,
                ),
              ],
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
              if (context.mounted) {
                Navigator.pop(context);
              }
            }
          },
          child: const Text('Borrow'),
        ),
      ],
    );
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
}
