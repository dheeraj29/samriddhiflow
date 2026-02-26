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
      filtered = _filterByAccount(filtered, accountId);
    }

    // 4. Loan Filter
    if (loanId != null) {
      filtered = filtered.where((t) => t.loanId == loanId).toList();
    }

    // 5. Time Filter
    if (range != null) {
      filtered = _filterByTimeRange(filtered, range, customRange);
    }
    if (periodMode != null) {
      filtered = _filterByPeriodMode(
          filtered, periodMode, selectedMonth, selectedYear);
    }

    return filtered;
  }

  static List<Transaction> _filterByAccount(
      List<Transaction> filtered, String accountId) {
    if (accountId == 'none') {
      return filtered.where((t) => t.accountId == null).toList();
    }
    return filtered
        .where((t) => t.accountId == accountId || t.toAccountId == accountId)
        .toList();
  }

  static List<Transaction> _filterByTimeRange(
      List<Transaction> filtered, TimeRange range, DateTimeRange? customRange) {
    final now = DateTime.now();
    switch (range) {
      case TimeRange.last30Days:
        final start = now.subtract(const Duration(days: 30));
        return filtered.where((t) => t.date.isAfter(start)).toList();
      case TimeRange.thisMonth:
        final start = DateTime(now.year, now.month, 1);
        return filtered
            .where(
                (t) => t.date.isAfter(start) || t.date.isAtSameMomentAs(start))
            .toList();
      case TimeRange.lastMonth:
        final start =
            DateTime(now.year, now.month - 1, 1); // coverage:ignore-line
        final end = DateTime(now.year, now.month, 0); // coverage:ignore-line
        return filtered
            // coverage:ignore-start
            .where((t) =>
                t.date.isAfter(start) &&
                t.date.isBefore(end))
            .toList();
            // coverage:ignore-end
      case TimeRange.custom:
        if (customRange == null) return filtered;
        final start = customRange.start;
        final end = customRange.end
            .add(const Duration(days: 1))
            .subtract(const Duration(milliseconds: 1));
        return filtered
            .where((t) => t.date.isAfter(start) && t.date.isBefore(end))
            .toList();
      default:
        return filtered;
    }
  }

  static List<Transaction> _filterByPeriodMode(List<Transaction> filtered,
      String periodMode, DateTime? selectedMonth, int? selectedYear) {
    final now = DateTime.now();
    switch (periodMode) {
      case '30':
        return filtered
            .where(
                (t) => t.date.isAfter(now.subtract(const Duration(days: 30))))
            .toList();
      case '90':
        return filtered
            .where(
                (t) => t.date.isAfter(now.subtract(const Duration(days: 90))))
            .toList();
      case '365':
        return filtered
            .where(
                (t) => t.date.isAfter(now.subtract(const Duration(days: 365))))
            .toList();
      case 'month':
        if (selectedMonth == null) return filtered;
        return filtered
            .where((t) =>
                t.date.year == selectedMonth.year &&
                t.date.month == selectedMonth.month)
            .toList();
      case 'year':
        if (selectedYear == null) return filtered;
        return filtered.where((t) => t.date.year == selectedYear).toList();
      default:
        return filtered;
    }
  }
}
