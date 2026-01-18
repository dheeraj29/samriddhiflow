class BillingHelper {
  /// Returns the Start Date of the billing cycle that surrounds the given [date].
  /// [cycleDay]: The day of the month when the bill is generated (new cycle starts).
  static DateTime getCycleStart(DateTime date, int cycleDay) {
    // If date is before cycleDay, then it belongs to previous month's cycle start
    // e.g. Date: Jan 5, CycleDay: 15. Cycle Start was Dec 15.
    // e.g. Date: Jan 20, CycleDay: 15. Cycle Start was Jan 15.

    if (date.day >= cycleDay) {
      return DateTime(date.year, date.month, cycleDay);
    } else {
      // Handle Jan case (month 1 -> month 12 of prev year) or just subtract month
      // DateTime handles month 0 as Dec of prev year automatically
      return DateTime(date.year, date.month - 1, cycleDay);
    }
  }

  /// Returns the End Date (exclusive? no, cycle usually up to next start)
  /// Actually we usually need Cycle Start of Next Cycle.
  static DateTime getNextCycleStart(DateTime currentCycleStart) {
    return DateTime(currentCycleStart.year, currentCycleStart.month + 1,
        currentCycleStart.day);
  }
}
