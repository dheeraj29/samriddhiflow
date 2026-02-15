import '../models/account.dart';
import '../models/transaction.dart';

class BillingHelper {
  /// Returns the Start Date of the billing cycle that surrounds the given [date].
  /// [cycleDay]: The day of the month when the bill is generated (new cycle starts).
  static DateTime getCycleStart(DateTime date, int cycleDay) {
    if (date.day > cycleDay) {
      return DateTime(date.year, date.month, cycleDay + 1);
    } else {
      return DateTime(date.year, date.month - 1, cycleDay + 1);
    }
  }

  /// Returns true if the [txnDate] is in the "Unbilled" (current) cycle for the given [now].
  /// The current cycle starts AFTER the billing day.
  static bool isUnbilled(DateTime txnDate, DateTime now, int cycleDay) {
    // The current cycle starts AFTER the billing day of the previous month.
    final currentCycleStart = getCycleStart(now, cycleDay);

    final txnDateOnly = DateTime(txnDate.year, txnDate.month, txnDate.day);
    return !txnDateOnly.isBefore(currentCycleStart);
  }

  /// Returns the End Date of the cycle starting at [currentCycleStart].
  static DateTime getNextCycleStart(DateTime currentCycleStart) {
    return DateTime(currentCycleStart.year, currentCycleStart.month + 1,
        currentCycleStart.day);
  }

  /// Calculates the "Unbilled" amount (Spent in current cycle).
  /// Range: (Current Cycle Start, Now].
  static double calculateUnbilledAmount(
      Account acc, List<Transaction> allTxns, DateTime now) {
    if (acc.type != AccountType.creditCard || acc.billingCycleDay == null) {
      return 0;
    }
    final currentCycleStart = getCycleStart(now, acc.billingCycleDay!);
    return _calculatePeriodSpend(acc, allTxns, currentCycleStart, now);
  }

  /// Calculates the "Billed" amount (Generated Statement) that hasn't been added to Balance yet.
  /// Range: (Last Rollover Date, Current Cycle Start].
  static double calculateBilledAmount(Account acc, List<Transaction> allTxns,
      DateTime now, int? lastRolloverMillis) {
    if (acc.type != AccountType.creditCard ||
        acc.billingCycleDay == null ||
        lastRolloverMillis == null) {
      return 0;
    }

    final lastRollover =
        DateTime.fromMillisecondsSinceEpoch(lastRolloverMillis);
    final currentCycleStart = getCycleStart(now, acc.billingCycleDay!);

    // If fully caught up, return 0
    if (!lastRollover.isBefore(currentCycleStart)) {
      return 0;
    }

    return _calculatePeriodSpend(acc, allTxns, lastRollover, currentCycleStart);
  }

  /// Shared logic to calculate Net Spend (Expenses + Outgoing Transfers) in a date range.
  /// Range: (Start, End] (Start exclusive, End inclusive/inclusive-ish depending on logic)
  static double _calculatePeriodSpend(
      Account acc, List<Transaction> allTxns, DateTime start, DateTime end) {
    // Range: (start, end]
    final relevantTxns = allTxns.where((t) =>
        !t.isDeleted &&
        (t.accountId == acc.id || t.toAccountId == acc.id) &&
        t.date.isAfter(start) &&
        (t.date.isBefore(end) || t.date.isAtSameMomentAs(end)));

    double spend = 0;
    for (var t in relevantTxns) {
      if (t.type == TransactionType.expense && t.accountId == acc.id) {
        spend += t.amount;
      }
      if (t.type == TransactionType.income && t.accountId == acc.id) {
        spend -= t.amount;
      }
      if (t.type == TransactionType.transfer) {
        if (t.accountId == acc.id) spend += t.amount; // Outgoing = Spend
        // Payment (Incoming Transfer) is IGNORED here because:
        // 1. StorageService applies payments immediately to Account.balance.
        // 2. We are calculating "Pending Bill", which is the sum of Spends.
        // 3. Net Debt = Balance (lowered by payment) + Pending Bill (Spends).
      }
    }
    return spend;
  }
}
