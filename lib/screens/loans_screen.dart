import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
import 'loan_details_screen.dart';
import 'add_loan_screen.dart';
import '../widgets/pure_icons.dart';
import '../widgets/smart_currency_text.dart';
import '../models/loan.dart';
import 'package:samriddhi_flow/l10n/app_localizations.dart';

class LoansScreen extends ConsumerWidget {
  const LoansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loansAsync = ref.watch(loansProvider);

    return Scaffold(
      appBar:
          AppBar(title: Text(AppLocalizations.of(context)!.loansScreenTitle)),
      body: loansAsync.when(
        data: (loans) => loans.isEmpty
            ? _buildEmptyState(context)
            : _buildLoanList(context, ref, loans),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(
            // coverage:ignore-line
            child: Text(
                '${AppLocalizations.of(context)!.errorLabel}: $e')), // coverage:ignore-line
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const AddLoanScreen()));
        },
        child: PureIcons.add(),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PureIcons.bank(size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(AppLocalizations.of(context)!.noActiveLoans),
          TextButton(
            onPressed: () => Navigator.push(
                context, // coverage:ignore-line
                MaterialPageRoute(
                    builder: (_) =>
                        const AddLoanScreen())), // coverage:ignore-line
            child: Text(AppLocalizations.of(context)!.addLoanTitle),
          ),
        ],
      ),
    );
  }

  Widget _buildLoanList(BuildContext context, WidgetRef ref, List<Loan> loans) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: loans.length,
      itemBuilder: (context, index) =>
          _buildLoanItem(context, ref, loans[index]),
    );
  }

  Widget _buildLoanItem(BuildContext context, WidgetRef ref, Loan loan) {
    final currencyLocale = ref.watch(currencyProvider);
    final tenure =
        ref.watch(loanServiceProvider).calculateRemainingTenure(loan);
    final remainingMonths = tenure.months.ceil();

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
        title: Text(loan.name,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          '${_getLoanTypeLabel(context, loan.type).toUpperCase()} • ${AppLocalizations.of(context)!.interestRateShort(loan.interestRate.toString())} • ${AppLocalizations.of(context)!.monthsLeft(remainingMonths)}',
        ),
        trailing: SmartCurrencyText(
          value: loan.remainingPrincipal,
          locale: currencyLocale,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        onTap: () {
          FocusScope.of(context).unfocus();
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => LoanDetailsScreen(loan: loan)));
        },
      ),
    );
  }

  String _getLoanTypeLabel(BuildContext context, LoanType type) {
    final l10n = AppLocalizations.of(context)!;
    switch (type) {
      case LoanType.personal:
        return l10n.personalLoan;
      // coverage:ignore-start
      case LoanType.home:
        return l10n.homeLoan;
      case LoanType.car:
        return l10n.carLoan;
      case LoanType.education:
        return l10n.educationLoan;
      case LoanType.business:
        return l10n.businessLoan;
      case LoanType.gold:
        return l10n.goldLoan;
      case LoanType.other:
        return l10n.otherLoan;
      // coverage:ignore-end
    }
  }
}
