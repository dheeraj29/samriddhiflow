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
    // If today is the cycle day, the CURRENT cycle is closing/billed today.
    // The next (unbilled) cycle starts tomorrow.
    final currentCycleStart = (now.day == cycleDay)
        ? DateTime(now.year, now.month, now.day + 1)
        : getCycleStart(now, cycleDay);

    final txnDateOnly = DateTime(txnDate.year, txnDate.month, txnDate.day);
    return !txnDateOnly.isBefore(currentCycleStart);
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

    double unbilled = 0;
    // Filter relevant transactions first
    final relevantTxnsQuery = allTxns.where((t) =>
        !t.isDeleted &&
        (t.accountId == acc.id || t.toAccountId == acc.id) &&
        BillingHelper.isUnbilled(t.date, now, acc.billingCycleDay!));

    for (var t in relevantTxnsQuery) {
      // Expense or Transfer Out -> Adds to Unbilled
      if (t.type == TransactionType.expense && t.accountId == acc.id) {
        unbilled += t.amount;
      }
      if (t.type == TransactionType.income && t.accountId == acc.id) {
        unbilled -= t.amount;
      }
      if (t.type == TransactionType.transfer && t.accountId == acc.id) {
        unbilled += t.amount;
      }
      // Payments (Transfer In) are EXCLUDED from unbilled, as they pay off the Billed Balance.
      // (Or strictly speaking, the user wants them skipped entirely until rollover).
    }
    return unbilled;
  }
}
