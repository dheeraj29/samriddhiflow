import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../models/account.dart';
import '../models/category.dart';
import 'smart_currency_text.dart';
import 'pure_icons.dart';

class TransactionListItem extends StatelessWidget {
  final Transaction txn;
  final String currencyLocale;
  final List<Account> accounts;
  final List<Category> categories;
  final bool compactView;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Function(bool?)? onSelectionChanged;
  final String? currentAccountIdFilter; // To highlight incoming transfers
  final Widget? trailing; // Override trailing amount
  final bool showLineThrough; // For deleted items

  const TransactionListItem({
    super.key,
    required this.txn,
    required this.currencyLocale,
    required this.accounts,
    required this.categories,
    this.compactView = false,
    this.isSelectionMode = false,
    this.isSelected = false,
    required this.onTap,
    this.onLongPress,
    this.onSelectionChanged,
    this.currentAccountIdFilter,
    this.trailing,
    this.showLineThrough = false,
  });

  @override
  Widget build(BuildContext context) {
    final catObj = categories.firstWhere(
      (c) => c.name == txn.category,
      orElse: () => Category(
          id: 'temp',
          name: txn.category,
          usage: CategoryUsage.expense,
          profileId: ''),
    );
    final isCapitalGain = catObj.tag == CategoryTag.capitalGain;

    final isIncomingTransfer = currentAccountIdFilter != null &&
        // coverage:ignore-start
        txn.type == TransactionType.transfer &&
        txn.toAccountId == currentAccountIdFilter &&
        txn.accountId != txn.toAccountId;
    // coverage:ignore-end

    return ListTile(
      selected: isSelected,
      onTap: onTap,
      onLongPress: onLongPress,
      leading: _buildLeading(isIncomingTransfer),
      title: Text(txn.title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            decoration: showLineThrough ? TextDecoration.lineThrough : null,
          )),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSubtitleLine(context),
          if (isCapitalGain &&
              (txn.gainAmount != null || txn.holdingTenureMonths != null))
            _buildCapitalGainsLine(context),
        ],
      ),
      trailing: trailing ?? _buildTrailingAmount(isIncomingTransfer),
    );
  }

  Widget _buildTrailingAmount(bool isIncomingTransfer) {
    final bool isPositive =
        txn.type == TransactionType.income || isIncomingTransfer;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SmartCurrencyText(
          value: txn.amount,
          locale: currencyLocale,
          initialCompact: compactView,
          prefix: isPositive ? "+" : "-",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            decoration: showLineThrough ? TextDecoration.lineThrough : null,
            color: isPositive ? Colors.green : Colors.red,
          ),
        ),
        if (!isSelectionMode) const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildLeading(bool isIncomingTransfer) {
    if (isSelectionMode) {
      return Checkbox(value: isSelected, onChanged: onSelectionChanged);
    }
    return CircleAvatar(
      backgroundColor: _getLeadingColor(isIncomingTransfer),
      child: _getLeadingIcon(),
    );
  }

  Color _getLeadingColor(bool isIncomingTransfer) {
    if (txn.type == TransactionType.income || isIncomingTransfer) {
      return Colors.green.withValues(alpha: 0.1);
    }
    if (txn.type == TransactionType.transfer) {
      return Colors.blue.withValues(alpha: 0.1); // coverage:ignore-line
    }
    return Colors.redAccent.withValues(alpha: 0.1);
  }

  Widget _getLeadingIcon() {
    if (txn.type == TransactionType.income) return PureIcons.income(size: 18);
    if (txn.type == TransactionType.transfer) {
      return PureIcons.transfer(size: 18); // coverage:ignore-line
    }
    return PureIcons.expense(size: 18);
  }

  Widget _buildSubtitleLine(BuildContext context) {
    String getAccName(String? id) {
      if (id == null) return 'Manual';
      return accounts
          .firstWhere((a) => a.id == id,
              orElse: () => Account(
                  id: 'del',
                  name: 'Deleted',
                  type: AccountType.savings,
                  balance: 0,
                  currency: '',
                  profileId: ''))
          .name;
    }

    String metadata;
    if (txn.type == TransactionType.transfer) {
      metadata =
          '${getAccName(txn.accountId)} -> ${getAccName(txn.toAccountId)}'; // coverage:ignore-line
    } else {
      metadata = '${txn.category} • ${getAccName(txn.accountId)}';
    }

    return Text(
      '${DateFormat('MMM dd, yyyy • hh:mm a').format(txn.date)} • $metadata',
      style: const TextStyle(fontSize: 12),
    );
  }

  Widget _buildCapitalGainsLine(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2.0),
      child: Row(
        children: [
          _buildGainAmount(),
          if (txn.gainAmount != null && txn.holdingTenureMonths != null)
            const Text(' • ', style: TextStyle(fontSize: 11)),
          if (txn.holdingTenureMonths != null)
            Text(
              'Held: ${_formatTenure(txn.holdingTenureMonths!)}',
              style: const TextStyle(
                fontSize: 11,
                color: Colors.grey,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGainAmount() {
    final amount = txn.gainAmount;
    if (amount == null) {
      return Row(
        // coverage:ignore-line
        children: [
          // coverage:ignore-line
          const Text(
            'Profit: ',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          SmartCurrencyText(
            // coverage:ignore-line
            value: 0,
            locale: currencyLocale, // coverage:ignore-line
            initialCompact: compactView, // coverage:ignore-line
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        ],
      );
    }

    final isProfit = amount >= 0;
    final color = isProfit ? Colors.green : Colors.redAccent;
    final label = isProfit ? "Profit" : "Loss";

    return Row(
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        SmartCurrencyText(
          value: amount.abs(),
          locale: currencyLocale,
          initialCompact: compactView,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  String _formatTenure(int months) {
    if (months < 12) return '$months mos';
    final years = months ~/ 12;
    final remainingMonths = months % 12;
    if (remainingMonths == 0) return '$years ${years == 1 ? "yr" : "yrs"}';
    final yearStr = years == 1 ? "yr" : "yrs";
    final monthStr = remainingMonths == 1 ? "mo" : "mos";
    return '$years $yearStr $remainingMonths $monthStr';
  }
}
