import '../models/account.dart';
import '../models/transaction.dart';

class BillingHelper {
  /// Returns the Start Date of the billing cycle that surrounds the given [date].
  /// [cycleDay]: The day of the month when the bill is generated (new cycle starts).
  static DateTime getCycleStart(DateTime date, int cycleDay) {
    if (date.day >= cycleDay) {
      return DateTime(date.year, date.month, cycleDay);
    } else {
      return DateTime(date.year, date.month - 1, cycleDay);
    }
  }

  /// Returns true if the [txnDate] is in the "Unbilled" (current) cycle for the given [now].
  /// The current cycle starts AFTER the billing day.
  static bool isUnbilled(DateTime txnDate, DateTime now, int cycleDay) {
    final currentCycleStart = getCycleStart(now, cycleDay);
    final txnDateOnly = DateTime(txnDate.year, txnDate.month, txnDate.day);
    return txnDateOnly.isAfter(currentCycleStart);
  }

  /// Returns the End Date of the cycle starting at [currentCycleStart].
  static DateTime getNextCycleStart(DateTime currentCycleStart) {
    return DateTime(currentCycleStart.year, currentCycleStart.month + 1,
        currentCycleStart.day);
  }

  /// Calculates the unbilled amount for a Credit Card account.
  static double calculateUnbilledAmount(
      Account acc, List<Transaction> allTxns, DateTime now) {
    if (acc.type != AccountType.creditCard || acc.billingCycleDay == null) {
      return 0;
    }

    final cycleStart = getCycleStart(now, acc.billingCycleDay!);
    final relevantTxns = allTxns.where((t) =>
        !t.isDeleted &&
        t.accountId == acc.id &&
        DateTime(t.date.year, t.date.month, t.date.day).isAfter(cycleStart));

    double unbilled = 0;
    for (var t in relevantTxns) {
      if (t.type == TransactionType.expense) unbilled += t.amount;
      if (t.type == TransactionType.income) unbilled -= t.amount;
      if (t.type == TransactionType.transfer && t.accountId == acc.id) {
        unbilled += t.amount;
      }
    }
    return unbilled;
  }
}
