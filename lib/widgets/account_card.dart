import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/account.dart';
import '../theme/app_theme.dart';
import '../utils/billing_helper.dart';
import '../utils/currency_utils.dart';
import 'pure_icons.dart';

class AccountCard extends ConsumerWidget {
  final Account account;
  final VoidCallback? onTap;
  final double unbilledAmount;
  final double billedAmount;
  final double totalPaymentsSinceRollover;
  final bool compactView;

  const AccountCard({
    super.key,
    required this.account,
    this.onTap,
    this.unbilledAmount = 0,
    this.billedAmount = 0,
    this.totalPaymentsSinceRollover = 0,
    this.compactView = true,
  });

  String _format(double value) {
    if (compactView) {
      return CurrencyUtils.getSmartFormat(value, account.currency);
    }
    return CurrencyUtils.getFormatter(account.currency).format(value);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (cardColor, iconWidget) = _getCardStyle();
    final (displayBalance, displayBilled, displayUnbilled) =
        _getAdjustedCCData();

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
                _buildHeader(iconWidget),
                const SizedBox(height: 8),
                _buildAccountName(),
                const SizedBox(height: 2),
                _buildBalanceDisplay(
                    displayBalance, displayBilled, displayUnbilled),
                _buildExtraInfo(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  (Color, Widget) _getCardStyle() {
    switch (account.type) {
      case AccountType.creditCard:
        return (
          const Color(0xFF1A1A2E),
          PureIcons.card(color: Colors.white, size: 28)
        );
      case AccountType.savings:
        return (
          AppTheme.secondary,
          PureIcons.bank(color: Colors.white, size: 28)
        );
      case AccountType.wallet:
        return (
          Colors.orangeAccent,
          PureIcons.wallet(color: Colors.white, size: 28)
        );
    }
  }

  (double, double, double) _getAdjustedCCData() {
    if (account.type != AccountType.creditCard) {
      return (account.balance, 0, 0);
    }

    return BillingHelper.getAdjustedCCData(
      accountBalance: account.balance,
      billedAmount: billedAmount,
      unbilledAmount: unbilledAmount,
      totalPaymentsSinceRollover: totalPaymentsSinceRollover,
    );
  }

  Widget _buildHeader(Widget iconWidget) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        iconWidget,
        if (account.type == AccountType.creditCard)
          PureIcons.contactless(color: Colors.white54, size: 20),
      ],
    );
  }

  Widget _buildAccountName() {
    return Text(
      account.name,
      style: const TextStyle(color: Colors.white70, fontSize: 14),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildBalanceDisplay(
      double displayBalance, double displayBilled, double displayUnbilled) {
    if (account.type == AccountType.creditCard) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _format(displayBalance + displayBilled + displayUnbilled),
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              if (displayBilled > 0)
                _buildMiniInfo('Billed', displayBilled, account.currency),
              if (displayUnbilled > 0)
                _buildMiniInfo('Unbilled', displayUnbilled, account.currency),
              if (displayBalance != 0)
                _buildMiniInfo('Balance', displayBalance, account.currency),
            ],
          ),
        ],
      );
    } else {
      return Text(
        _format(account.balance),
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
      );
    }
  }

  Widget _buildExtraInfo() {
    if (account.type == AccountType.creditCard && account.creditLimit != null) {
      return Column(
        children: [
          const SizedBox(height: 8),
          _buildCreditUtilization(account),
        ],
      );
    }
    return const SizedBox.shrink();
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
              'Limit: ${compactView ? NumberFormat.compact().format(limit) : CurrencyUtils.getFormatter(account.currency).format(limit)}',
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
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4)),
      child: Text(
        '$label: ${_format(val)}',
        style: const TextStyle(color: Colors.white70, fontSize: 9),
      ),
    );
  }
}
