import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
import 'loan_details_screen.dart';
import 'add_loan_screen.dart';
import '../widgets/pure_icons.dart';
import '../widgets/smart_currency_text.dart';

class LoansScreen extends ConsumerWidget {
  const LoansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loansAsync = ref.watch(loansProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Loans')),
      body: loansAsync.when(
        data: (loans) {
          if (loans.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  PureIcons.bank(size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No active loans.'),
                  TextButton(
                    onPressed: () => Navigator.push(
                        // coverage:ignore-line
                        context,
                        MaterialPageRoute(
                            // coverage:ignore-line
                            builder: (_) =>
                                const AddLoanScreen())), // coverage:ignore-line
                    child: const Text('Add Loan'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: loans.length,
            itemBuilder: (context, index) {
              final loan = loans[index];
              final currencyLocale = ref.watch(currencyProvider);
              final tenure =
                  ref.watch(loanServiceProvider).calculateRemainingTenure(loan);
              final remainingMonths = tenure.months.ceil();

              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                            .withValues(alpha: 0.2) // coverage:ignore-line
                        : Colors.black.withValues(alpha: 0.1),
                  ),
                ),
                child: ListTile(
                  title: Text(loan.name,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    '${loan.type.name.toUpperCase()} • ${loan.interestRate}% Int. • ${remainingMonths}m Left',
                  ),
                  trailing: SmartCurrencyText(
                    value: loan.remainingPrincipal,
                    locale: currencyLocale,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  onTap: () {
                    FocusScope.of(context).unfocus();
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => LoanDetailsScreen(loan: loan)));
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) =>
            Center(child: Text('Error: $e')), // coverage:ignore-line
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
}
