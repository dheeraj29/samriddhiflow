import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:samriddhi_flow/l10n/app_localizations.dart';
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
    final currencyLocale = ref.watch(currencyProvider);
    final isGoldLoan = loan.type == LoanType.gold;

    return Card(
      color: isGoldLoan ? Colors.amber[900] : AppTheme.primary,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildHeader(context, isGoldLoan, currencyLocale),
            const SizedBox(height: 16),
            if (isGoldLoan)
              _buildGoldLoanSpecs(context, ref, currencyLocale)
            else
              _buildStandardLoanSpecs(context, ref, currencyLocale),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
      BuildContext context, bool isGoldLoan, String currencyLocale) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(AppLocalizations.of(context)!.outstandingPrincipalLabel,
                style: const TextStyle(color: Colors.white70)),
            if (!isGoldLoan) ...[
              const SizedBox(width: 8),
              _buildBulkPayBadge(context),
            ]
          ],
        ),
        SmartCurrencyText(
          value: loan.remainingPrincipal,
          locale: currencyLocale,
          style: const TextStyle(
              color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildBulkPayBadge(BuildContext context) {
    return InkWell(
      onTap: onBulkPay,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            const Icon(Icons.library_add_check_outlined,
                size: 14, color: Colors.white),
            const SizedBox(width: 4),
            Text(
              AppLocalizations.of(context)!.bulkPayAction,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoldLoanSpecs(
      BuildContext context, WidgetRef ref, String currencyLocale) {
    final lastPaymentDate = loan.transactions.isEmpty
        ? loan.startDate
        // coverage:ignore-start
        : loan.transactions
            .map((t) => t.date)
            .reduce((a, b) => a.isAfter(b) ? a : b);
    // coverage:ignore-end
    final daysElapsed = DateTime.now().difference(lastPaymentDate).inDays;
    final accruedInterest = loan.calculateAccruedInterest();

    return Column(
      children: [
        const Divider(color: Colors.white24),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStat(AppLocalizations.of(context)!.interestRateLabel,
                '${loan.currentRate}%'),
            _buildStat(AppLocalizations.of(context)!.daysAccruedLabel,
                AppLocalizations.of(context)!.daysCount(daysElapsed)),
          ],
        ),
        const SizedBox(height: 16),
        Text(AppLocalizations.of(context)!.estAccruedInterestLabel,
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
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
        _buildMaturityRow(context, ref),
      ],
    );
  }

  Widget _buildMaturityRow(BuildContext context, WidgetRef ref) {
    final maturityDate =
        loan.startDate.add(Duration(days: loan.tenureMonths * 30));
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
            AppLocalizations.of(context)!
                .maturityLabel(DateFormat('MMM dd, yyyy').format(maturityDate)),
            style: const TextStyle(
                color: Colors.white60, fontStyle: FontStyle.italic)),
        IconButton(
          icon: PureIcons.calendarMonth(color: Colors.white60, size: 20),
          tooltip: AppLocalizations.of(context)!.addToSystemCalendarTooltip,
          // coverage:ignore-start
          onPressed: () {
            ref.read(calendarServiceProvider).downloadExvent(
                  title: AppLocalizations.of(context)!
                      .loanMaturityEventTitle(loan.name),
                  description: AppLocalizations.of(context)!
                      .loanMaturityEventDescription(loan.name),
                  // coverage:ignore-end
                  startTime: maturityDate,
                  endTime: maturityDate
                      .add(const Duration(hours: 1)), // coverage:ignore-line
                );
          },
        )
      ],
    );
  }

  Widget _buildStandardLoanSpecs(
      BuildContext context, WidgetRef ref, String currencyLocale) {
    final loanService = ref.watch(loanServiceProvider);
    final remainingTenure = loanService.calculateRemainingTenure(loan);
    final remainingMonths = remainingTenure.months.ceil();
    final remainingDays = remainingTenure.days;
    final progress = loan.totalPrincipal > 0
        ? (loan.totalPrincipal - loan.remainingPrincipal) / loan.totalPrincipal
        : 0.0;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildEmiInfo(context, currencyLocale),
            _buildRateInfo(context),
            _buildStat(
                AppLocalizations.of(context)!.paidLabel,
                AppLocalizations.of(context)!.monthsShort(loan.transactions
                    .where((t) => t.type == LoanTransactionType.emi)
                    .length)),
            _buildStat(AppLocalizations.of(context)!.leftLabel,
                '${AppLocalizations.of(context)!.monthsShort(remainingMonths)} ${AppLocalizations.of(context)!.daysShort(remainingDays)}'),
          ],
        ),
        const SizedBox(height: 16),
        _buildProgressIndicator(context, progress),
      ],
    );
  }

  Widget _buildEmiInfo(BuildContext context, String currencyLocale) {
    return InkWell(
      onTap: () {
        // coverage:ignore-line
        showDialog(
            // coverage:ignore-line
            context: context,
            builder: (_) =>
                LoanRecalculateDialog(loan: loan)); // coverage:ignore-line
      },
      child: Row(
        children: [
          Column(
            children: [
              Text(AppLocalizations.of(context)!.emiLabel,
                  style: const TextStyle(color: Colors.white60)),
              SmartCurrencyText(
                value: loan.emiAmount,
                locale: currencyLocale,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(width: 4),
          PureIcons.edit(size: 14, color: Colors.white70),
        ],
      ),
    );
  }

  Widget _buildRateInfo(BuildContext context) {
    return InkWell(
      // coverage:ignore-start
      onTap: () {
        showDialog(
            context: context, builder: (_) => LoanUpdateRateDialog(loan: loan));
        // coverage:ignore-end
      },
      child: Row(
        children: [
          _buildStat(
              AppLocalizations.of(context)!.rateLabel, '${loan.interestRate}%'),
          const SizedBox(width: 4),
          PureIcons.edit(size: 14, color: Colors.white70),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(BuildContext context, double progress) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
                AppLocalizations.of(context)!
                    .percentPaidLabel((progress * 100).toStringAsFixed(1)),
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
            Text(AppLocalizations.of(context)!.closureProgressLabel,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.black12,
          valueColor: const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
          borderRadius: BorderRadius.circular(4),
        ),
      ],
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
