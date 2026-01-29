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
}
