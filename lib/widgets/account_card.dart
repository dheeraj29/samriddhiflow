import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/account.dart';
import '../theme/app_theme.dart';
import 'smart_currency_text.dart';
import '../utils/currency_utils.dart';
import 'pure_icons.dart';

class AccountCard extends ConsumerWidget {
  final Account account;
  final VoidCallback? onTap;
  final double unbilledAmount;

  const AccountCard({
    super.key,
    required this.account,
    this.onTap,
    this.unbilledAmount = 0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    // Determine Color and Icon based on Type
    Color cardColor;
    Widget iconWidget;
    switch (account.type) {
      case AccountType.creditCard:
        cardColor = const Color(0xFF1A1A2E); // Dark Blue/Black
        iconWidget = PureIcons.card(color: Colors.white, size: 28);
        break;
      case AccountType.savings:
        cardColor = AppTheme.secondary; // Teal
        iconWidget = PureIcons.bank(color: Colors.white, size: 28);
        break;
      case AccountType.wallet:
        cardColor = Colors.orangeAccent;
        iconWidget = PureIcons.wallet(color: Colors.white, size: 28);
        break;
    }

    return Card(
      color: cardColor,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  iconWidget,
                  if (account.type == AccountType.creditCard)
                    PureIcons.contactless(color: Colors.white54, size: 20),
                ],
              ),
              const Spacer(),
              Text(
                account.name,
                style: theme.textTheme.titleMedium
                    ?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 4),
              // Balance Display
              if (account.type == AccountType.creditCard) ...[
                // For CC: Show Total Outstanding as Main, Billed/Unbilled as sub
                SmartCurrencyText(
                  value: account.balance + unbilledAmount,
                  locale: account.currency,
                  style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      _buildMiniInfo(
                          'Billed', account.balance, account.currency),
                      const SizedBox(width: 8),
                      _buildMiniInfo(
                          'Unbilled', unbilledAmount, account.currency),
                    ],
                  ),
                ),
              ] else
                SmartCurrencyText(
                  value: account.balance,
                  locale: account.currency,
                  style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),

              if (account.type == AccountType.creditCard &&
                  account.creditLimit != null) ...[
                const SizedBox(height: 12),
                _buildCreditUtilization(account),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreditUtilization(Account account) {
    double limit = account.creditLimit!;
    double used = account.balance;
    // Safety check for NaN (limit = 0)
    double percent = (limit == 0) ? 0.0 : (used / limit).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Used ${((percent * 100).toInt())}%',
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
            Text(
              'Limit: ${NumberFormat.compact().format(limit)}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: percent,
          backgroundColor: Colors.white24,
          color: percent > 0.9 ? Colors.redAccent : Colors.blueAccent,
        ),
      ],
    );
  }

  Widget _buildMiniInfo(String label, double val, String currency) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4)),
      child: Text(
        '$label: ${CurrencyUtils.getFormatter(currency).format(val)}',
        style: const TextStyle(color: Colors.white70, fontSize: 9),
      ),
    );
  }
}
