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

  /// Calculates total payments made since the last rollover date.
  static double calculatePaymentsSinceLastRollover(
      Account acc, List<Transaction> allTxns, int? lastRolloverMillis) {
    if (acc.type != AccountType.creditCard || lastRolloverMillis == null) {
      return 0;
    }

    final lastRollover =
        DateTime.fromMillisecondsSinceEpoch(lastRolloverMillis);

    final relevantTxns = allTxns.where((t) =>
        !t.isDeleted &&
        t.toAccountId == acc.id &&
        t.date.isAfter(lastRollover));

    return relevantTxns.fold<double>(0, (sum, t) => sum + t.amount);
  }

  /// Calculates the adjusted Billed/Balance/Unbilled amounts for UI display using the Waterfall logic.
  /// 1. Payments clear Billed first.
  /// 2. Then clear Old Balance.
  /// 3. Then clear Unbilled.
  /// 4. Excess shows as negative balance.
  static (double balance, double billed, double unbilled) getAdjustedCCData({
    required double accountBalance, // Current Net Liability
    required double billedAmount, // Raw spent in prev cycle
    required double unbilledAmount, // Raw spent in current cycle
    required double totalPaymentsSinceRollover,
  }) {
    double displayBilled = billedAmount;
    double displayUnbilled = unbilledAmount;
    double remCredit = totalPaymentsSinceRollover;
    // liability before any payments since rollover.
    double oldDebtAtRollover = accountBalance + totalPaymentsSinceRollover;

    // If pre-payment balance was already negative (Historical Excess),
    // we treat that as additional credit to Waterfall.
    if (oldDebtAtRollover < 0) {
      remCredit += -oldDebtAtRollover;
      oldDebtAtRollover = 0.0;
    }

    // 1. Offset against Billed (Previous Cycle)
    displayBilled = (displayBilled - remCredit).clamp(0.0, double.infinity);
    remCredit = (remCredit - billedAmount).clamp(0.0, double.infinity);

    // 2. Offset against Old Balance (Historical Debt)
    double displayBalance =
        (oldDebtAtRollover - remCredit).clamp(0.0, double.infinity);
    remCredit = (remCredit - oldDebtAtRollover).clamp(0.0, double.infinity);

    // 3. Offset against Unbilled (Current Cycle)
    displayUnbilled = (displayUnbilled - remCredit).clamp(0.0, double.infinity);
    double excess = (remCredit - unbilledAmount).clamp(0.0, double.infinity);

    // 4. Remaining excess shows as negative balance
    if (excess > 0) {
      displayBalance = -excess;
    }

    return (displayBalance, displayBilled, displayUnbilled);
  }

  /// Shared logic to calculate Net Spend (Expenses + Outgoing Transfers) in a date range.
  /// Range: (Start, End] (Start exclusive, End inclusive/inclusive-ish depending on logic)
  static double _calculatePeriodSpend(
      Account acc, List<Transaction> allTxns, DateTime start, DateTime end) {
    // Range: (start, end]
    final relevantTxns = allTxns.where((t) =>
        !t.isDeleted &&
        (t.accountId == acc.id || t.toAccountId == acc.id) &&
        !t.date.isBefore(start) &&
        (t.date.isBefore(end) || t.date.isAtSameMomentAs(end)));

    return relevantTxns.fold<double>(
        0, (sum, t) => sum + _getTxnSpendImpact(t, acc.id));
  }

  static double _getTxnSpendImpact(Transaction t, String accountId) {
    if (t.accountId == accountId) {
      switch (t.type) {
        case TransactionType.expense:
        case TransactionType
              .transfer: // Outgoing = Spend // coverage:ignore-line
          return t.amount;
        default:
          return 0;
      }
    }
    // Incoming transactions (Income/Incoming Transfers) are ignored here
    // because they are applied immediately to Account.balance and handled by
    // the UI Waterfall logic.
    return 0;
  }
}
