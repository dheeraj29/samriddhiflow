import '../models/recurring_transaction.dart';

class RecurrenceUtils {
  /// Finds the first valid execution date starting from [baseDate]
  /// based on the frequency and schedule type.
  static DateTime findFirstOccurrence({
    required DateTime baseDate,
    required Frequency frequency,
    required ScheduleType scheduleType,
    int? selectedWeekday,
  }) {
    DateTime candidate = DateTime(baseDate.year, baseDate.month, baseDate.day);

    // If the base date matches the criteria, return it.
    if (_matchesCriteria(candidate, frequency, scheduleType, selectedWeekday)) {
      return candidate;
    }

    // Otherwise, find the next matching date.
    // We can use a loop or smarter calculation.
    // For simplicity and correctness with "Last Day" logic, we can iterate forward slightly
    // or jump to next month if needed.

    // Safety break
    int attempts = 0;
    while (!_matchesCriteria(
            candidate, frequency, scheduleType, selectedWeekday) &&
        attempts < 366) {
      candidate = candidate.add(const Duration(days: 1));
      attempts++;
    }

    return candidate;
  }

  static bool _matchesCriteria(
      DateTime date, Frequency frequency, ScheduleType type, int? weekday) {
    if (frequency == Frequency.weekly) {
      // For specific weekday type
      if (type == ScheduleType.specificWeekday && weekday != null) {
        return date.weekday == weekday;
      }
      // If fixedDate (default for weekly?), we assume any date is fine if it matches the start day?
      // But typically weekly means "Every X day".
      return true;
    }

    if (frequency == Frequency.monthly) {
      switch (type) {
        case ScheduleType.fixedDate:
          // Matches if the day of month is the same.
          // But here we are finding the *first* occurrence.
          // If the user picked "Fixed Date" and a date, that date IS the fixed date.
          return true;

        case ScheduleType.lastDayOfMonth:
          final nextDay = date.add(const Duration(days: 1));
          return nextDay.month != date.month;

        case ScheduleType.lastWorkingDay:
          // Last day that is not Sat/Sun
          if (date.weekday == 6 || date.weekday == 7) return false;

          // Check if any remaining days in month are working days
          DateTime temp = date.add(const Duration(days: 1));
          while (temp.month == date.month) {
            if (temp.weekday != 6 && temp.weekday != 7)
              return false; // Found a later working day
            temp = temp.add(const Duration(days: 1));
          }
          return true;

        case ScheduleType.everyWeekend:
          // Is Sat or Sun
          return date.weekday == 6 || date.weekday == 7;

        case ScheduleType.lastWeekend:
          // Is Sat or Sun AND is globally the last occurrence of that day in the month?
          // Or "Last Weekend" usually means the last Sat/Sun set?
          // Let's assume "Last Saturday OR Last Sunday"
          if (date.weekday != 6 && date.weekday != 7) return false;
          final nextWeek = date.add(const Duration(days: 7));
          return nextWeek.month != date.month;

        case ScheduleType.specificWeekday:
          // e.g. "First Monday"? No, specificWeekday usually implies "Every Monday" which is weekly.
          // But if Monthly + Specific Weekday... that's ambiguous without "First/Second/Last".
          // Assuming "Specific Weekday" in Monthly context might mean "Day X of every month" which is FixedDate.
          // Wait, looking at AddTxnScreen logic:
          /*
               else if (_frequency == Frequency.monthly) {
                  _scheduleType = ScheduleType.fixedDate; // Default
               }
             */
          // Specific Weekday is valid for ScheduleType.
          if (weekday != null) return date.weekday == weekday;
          return true;
      }
    }

    // Daily/Yearly
    return true;
  }
}
