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
                        context,
                        MaterialPageRoute(
                            builder: (_) => const AddLoanScreen())),
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
              final schedule = ref
                  .watch(loanServiceProvider)
                  .calculateAmortizationSchedule(loan);
              final remainingMonths = schedule.length;

              return Card(
                child: ListTile(
                  title: Text(loan.name,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    '${loan.interestRate}% Int. • ${remainingMonths}m Left',
                  ),
                  trailing: SmartCurrencyText(
                    value: loan.remainingPrincipal,
                    locale: currencyLocale,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  onTap: () {
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
        error: (e, s) => Center(child: Text('Error: $e')),
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
