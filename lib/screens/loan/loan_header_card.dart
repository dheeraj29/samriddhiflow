import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/loan.dart';

import '../../providers.dart';
import '../../feature_providers.dart'; // Added for calendarServiceProvider
import '../../theme/app_theme.dart';
import '../../widgets/pure_icons.dart';
import '../../widgets/smart_currency_text.dart';
import 'loan_recalculate_dialog.dart';
import 'loan_update_rate_dialog.dart';

class LoanHeaderCard extends ConsumerWidget {
  final Loan loan;
  final VoidCallback onBulkPay;

  const LoanHeaderCard(
      {super.key, required this.loan, required this.onBulkPay});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loanService = ref.watch(loanServiceProvider);
    final currencyLocale = ref.watch(currencyProvider);
    final isGoldLoan = loan.type == LoanType.gold;

    // --- Calculations ---
    final lastPaymentDate = loan.transactions.isEmpty
        ? loan.startDate
        : loan.transactions
            .map((t) => t.date)
            .reduce((a, b) => a.isAfter(b) ? a : b);
    final daysElapsed = DateTime.now().difference(lastPaymentDate).inDays;

    final currentRate = loan.transactions
            .where((t) => t.type == LoanTransactionType.rateChange)
            .isEmpty
        ? loan.interestRate
        : loan.transactions
            .where((t) => t.type == LoanTransactionType.rateChange)
            .reduce((a, b) => a.date.isAfter(b.date) ? a : b)
            .amount;

    final accruedInterest =
        (loan.remainingPrincipal * currentRate * daysElapsed) / (365.0 * 100.0);

    final progress = loan.totalPrincipal > 0
        ? (loan.totalPrincipal - loan.remainingPrincipal) / loan.totalPrincipal
        : 0.0;

    final remainingTenure = loanService.calculateRemainingTenure(loan);
    final remainingMonths = remainingTenure.months.ceil();
    final remainingDays = remainingTenure.days;

    return Card(
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
                    onTap: onBulkPay, // Callback to main screen
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
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
              value: loan.remainingPrincipal,
              locale: currencyLocale,
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
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 4),
              SmartCurrencyText(
                value: accruedInterest,
                locale: currencyLocale,
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
                      'Maturity: ${DateFormat('MMM dd, yyyy').format(loan.startDate.add(Duration(days: loan.tenureMonths * 30)))}',
                      style: const TextStyle(
                          color: Colors.white60, fontStyle: FontStyle.italic)),
                  IconButton(
                    icon: PureIcons.calendarMonth(
                        color: Colors.white60, size: 20),
                    tooltip: 'Add to System Calendar',
                    onPressed: () {
                      final maturityDate = loan.startDate
                          .add(Duration(days: loan.tenureMonths * 30));
                      ref.read(calendarServiceProvider).downloadExvent(
                            title: 'Loan Maturity: ${loan.name}',
                            description:
                                'Maturity date for Gold Loan: ${loan.name}. Principal and Interest due.',
                            startTime: maturityDate,
                            endTime: maturityDate.add(const Duration(hours: 1)),
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
                    onTap: () {
                      showDialog(
                          context: context,
                          builder: (_) => LoanRecalculateDialog(loan: loan));
                    },
                    child: Row(
                      children: [
                        Column(
                          children: [
                            const Text('EMI',
                                style: TextStyle(color: Colors.white60)),
                            SmartCurrencyText(
                              value: loan.emiAmount,
                              locale: currencyLocale,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(width: 4),
                        PureIcons.edit(size: 14, color: Colors.white70),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      showDialog(
                          context: context,
                          builder: (_) => LoanUpdateRateDialog(loan: loan));
                    },
                    child: Row(
                      children: [
                        _buildStat('Rate', '${loan.interestRate}%'),
                        const SizedBox(width: 4),
                        PureIcons.edit(size: 14, color: Colors.white70),
                      ],
                    ),
                  ),
                  _buildStat('Paid',
                      '${loan.transactions.where((t) => t.type == LoanTransactionType.emi).length}m'),
                  _buildStat('Left', '${remainingMonths}m ${remainingDays}d'),
                ],
              ),
              const SizedBox(height: 16),
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${(progress * 100).toStringAsFixed(1)}% Paid',
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
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              )
            ]
          ],
        ),
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
}
