import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/account.dart';
import '../theme/app_theme.dart';
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
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    iconWidget,
                    if (account.type == AccountType.creditCard)
                      PureIcons.contactless(color: Colors.white54, size: 20),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  account.name,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                // Balance Display
                if (account.type == AccountType.creditCard) ...[
                  Text(
                    CurrencyUtils.getFormatter(account.currency)
                        .format(account.balance + unbilledAmount),
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _buildMiniInfo(
                          'Billed', account.balance, account.currency),
                      _buildMiniInfo(
                          'Unbilled', unbilledAmount, account.currency),
                    ],
                  ),
                ] else
                  Text(
                    CurrencyUtils.getFormatter(account.currency)
                        .format(account.balance),
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20),
                  ),

                if (account.type == AccountType.creditCard &&
                    account.creditLimit != null) ...[
                  const SizedBox(height: 8),
                  _buildCreditUtilization(account),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCreditUtilization(Account account) {
    double limit = account.creditLimit!;
    double used = account.balance;
    double percent = (limit == 0) ? 0.0 : (used / limit).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 4),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 8,
          runSpacing: 2,
          children: [
            Text('Used ${((percent * 100).toInt())}%',
                style: const TextStyle(color: Colors.white70, fontSize: 10)),
            Text(
              'Limit: ${NumberFormat.compact().format(limit)}',
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: percent,
            minHeight: 4,
            backgroundColor: Colors.white24,
            color: percent > 0.9 ? Colors.redAccent : Colors.blueAccent,
          ),
        ),
      ],
    );
  }

  Widget _buildMiniInfo(String label, double val, String currency) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4)),
      child: Text(
        '$label: ${CurrencyUtils.getFormatter(currency).format(val)}',
        style: const TextStyle(color: Colors.white70, fontSize: 9),
      ),
    );
  }
}
