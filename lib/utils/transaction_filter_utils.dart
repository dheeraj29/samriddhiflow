import 'package:flutter/material.dart' show DateTimeRange;
import '../models/transaction.dart';
import '../widgets/transaction_filter.dart';

class TransactionFilterUtils {
  static List<Transaction> filter({
    required List<Transaction> transactions,
    TransactionType? type,
    String? category,
    String? accountId,
    String? loanId,
    TimeRange? range,
    DateTimeRange? customRange, // From transactions_screen
    String?
        periodMode, // '30', '90', '365', 'month', 'year' from reports_screen
    DateTime? selectedMonth,
    int? selectedYear,
    List<String>? excludedCategories,
  }) {
    var filtered = transactions.where((t) => !t.isDeleted).toList();

    // 0. Exclusion Filter
    if (excludedCategories != null && excludedCategories.isNotEmpty) {
      filtered = filtered
          .where((t) => !excludedCategories.contains(t.category))
          .toList();
    }

    // 1. Type Filter
    if (type != null) {
      filtered = filtered.where((t) => t.type == type).toList();
    }

    // 2. Category Filter
    if (category != null) {
      filtered = filtered.where((t) => t.category == category).toList();
    }

    // 3. Account Filter
    if (accountId != null) {
      if (accountId == 'none') {
        filtered = filtered.where((t) => t.accountId == null).toList();
      } else {
        // Special Case: In TransactionsScreen, we also check toAccountId for transfers
        // In ReportsScreen, we only check accountId.
        // We can make this behavior consistent or configurable.
        // Let's make it check both for better visibility.
        filtered = filtered
            .where(
                (t) => t.accountId == accountId || t.toAccountId == accountId)
            .toList();
      }
    }

    // 4. Loan Filter
    if (loanId != null) {
      filtered = filtered.where((t) => t.loanId == loanId).toList();
    }

    // 5. Time Filter
    final now = DateTime.now();

    // Handle TimeRange Enum (from TransactionsScreen)
    if (range != null) {
      if (range == TimeRange.last30Days) {
        final start = now.subtract(const Duration(days: 30));
        filtered = filtered.where((t) => t.date.isAfter(start)).toList();
      } else if (range == TimeRange.thisMonth) {
        final start = DateTime(now.year, now.month, 1);
        filtered = filtered
            .where(
                (t) => t.date.isAfter(start) || t.date.isAtSameMomentAs(start))
            .toList();
      } else if (range == TimeRange.lastMonth) {
        final start = DateTime(now.year, now.month - 1, 1);
        final end = DateTime(now.year, now.month, 0);
        filtered = filtered
            .where((t) => t.date.isAfter(start) && t.date.isBefore(end))
            .toList();
      } else if (range == TimeRange.custom && customRange != null) {
        final start = customRange.start;
        final end = customRange.end
            .add(const Duration(days: 1))
            .subtract(const Duration(milliseconds: 1));
        filtered = filtered
            .where((t) => t.date.isAfter(start) && t.date.isBefore(end))
            .toList();
      }
    }

    // Handle periodMode String (from ReportsScreen)
    if (periodMode != null) {
      if (periodMode == '30') {
        final start = now.subtract(const Duration(days: 30));
        filtered = filtered.where((t) => t.date.isAfter(start)).toList();
      } else if (periodMode == '90') {
        final start = now.subtract(const Duration(days: 90));
        filtered = filtered.where((t) => t.date.isAfter(start)).toList();
      } else if (periodMode == '365') {
        final start = now.subtract(const Duration(days: 365));
        filtered = filtered.where((t) => t.date.isAfter(start)).toList();
      } else if (periodMode == 'month' && selectedMonth != null) {
        filtered = filtered
            .where((t) =>
                t.date.year == selectedMonth.year &&
                t.date.month == selectedMonth.month)
            .toList();
      } else if (periodMode == 'year' && selectedYear != null) {
        filtered = filtered.where((t) => t.date.year == selectedYear).toList();
      }
    }

    return filtered;
  }
}
