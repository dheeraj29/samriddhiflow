import '../models/recurring_transaction.dart';

class RecurrenceUtils {
  /// Finds the first valid execution date starting from [baseDate]
  /// based on the frequency, schedule type, and holiday adjustments.
  static DateTime findFirstOccurrence({
    required DateTime baseDate,
    required Frequency frequency,
    required ScheduleType scheduleType,
    int? selectedWeekday,
    bool adjustForHolidays = false,
    List<DateTime> holidays = const [],
  }) {
    DateTime candidate = DateTime(baseDate.year, baseDate.month, baseDate.day);

    // 1. Find the base candidate date that matches the recurrence rule
    // Safety break
    int attempts = 0;
    while (!_matchesCriteria(
            candidate, frequency, scheduleType, selectedWeekday, holidays) &&
        attempts < 366) {
      candidate = candidate.add(const Duration(days: 1));
      attempts++;
    }

    // 2. Apply Holiday Adjustment (only if required)
    // "Schedule a day earlier if it lands on a holiday/weekend"
    if (adjustForHolidays) {
      candidate = adjustDateForHolidays(candidate, holidays);
    }

    return candidate;
  }

  static DateTime adjustDateForHolidays(
      DateTime date, List<DateTime> holidays) {
    DateTime adjusted = date;
    int safeGuard = 0;
    // Recursively move back if lands on Weekend OR Holiday
    while (_isHolidayOrWeekend(adjusted, holidays) && safeGuard < 30) {
      adjusted = adjusted.subtract(const Duration(days: 1));
      safeGuard++;
    }
    return adjusted;
  }

  static bool _isHolidayOrWeekend(DateTime date, List<DateTime> holidays) {
    if (date.weekday == 6 || date.weekday == 7) return true;
    for (var h in holidays) {
      if (h.year == date.year && h.month == date.month && h.day == date.day) {
        return true;
      }
    }
    return false;
  }

  static bool _matchesCriteria(DateTime date, Frequency frequency,
      ScheduleType type, int? weekday, List<DateTime> holidays) {
    // Note: This logic finds the abstract "Schedule Date" (e.g. 25th of month).
    // Holiday adjustment works relative to this found date.

    if (frequency == Frequency.weekly) {
      if (type == ScheduleType.specificWeekday && weekday != null) {
        return date.weekday == weekday;
      }
      return true;
    }

    if (frequency == Frequency.monthly) {
      switch (type) {
        case ScheduleType.fixedDate:
          return true;

        case ScheduleType.lastDayOfMonth:
          final nextDay = date.add(const Duration(days: 1));
          return nextDay.month != date.month;

        case ScheduleType.lastWorkingDay:
          // Checks if 'date' is the last working day of the month.
          // "Working Day" here implies Not Weekend AND Not Holiday.
          if (_isHolidayOrWeekend(date, holidays)) return false;

          // Check if any *future* days in the month are working days
          DateTime temp = date.add(const Duration(days: 1));
          while (temp.month == date.month) {
            if (!_isHolidayOrWeekend(temp, holidays))
              return false; // Found a later working day
            temp = temp.add(const Duration(days: 1));
          }
          return true;

        case ScheduleType.everyWeekend:
          // Is Sat or Sun
          return date.weekday == 6 || date.weekday == 7;

        case ScheduleType.lastWeekend:
          if (date.weekday != 6 && date.weekday != 7) return false;
          final nextWeek = date.add(const Duration(days: 7));
          return nextWeek.month != date.month;

        case ScheduleType.specificWeekday:
          if (weekday != null) return date.weekday == weekday;
          return true;
      }
    }

    return true;
  }

  static DateTime calculateNextOccurrence({
    required DateTime lastDate,
    DateTime? startDate, // OPTIONAL: To prevent drift
    required Frequency frequency,
    required int interval,
    required ScheduleType scheduleType,
    int? selectedWeekday,
    bool adjustForHolidays = false,
    List<DateTime> holidays = const [],
  }) {
    DateTime next = lastDate;

    // 1. Basic increment based on frequency
    if (frequency == Frequency.daily) {
      next = lastDate.add(Duration(days: interval));
    } else if (frequency == Frequency.weekly) {
      next = lastDate.add(Duration(days: 7 * interval));
    } else if (frequency == Frequency.monthly) {
      // Use startDate.day to prevent drift if lastDate was adjusted
      int targetDay = startDate?.day ?? lastDate.day;
      if (scheduleType == ScheduleType.fixedDate) {
        // Create next month candidate using targetDay
        // Handle month overflow (e.g. Jan 31 -> Feb 28)
        int nextMonth = lastDate.month + interval;
        int nextYear = lastDate.year;
        // Normalize month/year
        while (nextMonth > 12) {
          nextMonth -= 12;
          nextYear++;
        }

        int maxDays = DateTime(nextYear, nextMonth + 1, 0).day;
        next = DateTime(
            nextYear, nextMonth, targetDay > maxDays ? maxDays : targetDay);
      } else {
        next = DateTime(lastDate.year, lastDate.month + interval, lastDate.day);
      }
    } else if (frequency == Frequency.yearly) {
      next = DateTime(lastDate.year + interval, lastDate.month, lastDate.day);
    }

    // 2. Apply Schedule Type constraints
    if (scheduleType == ScheduleType.lastDayOfMonth) {
      next = DateTime(next.year, next.month + 1, 0);
    } else if (scheduleType == ScheduleType.lastWorkingDay) {
      // Find last day, then backtrack if holiday/weekend
      next = DateTime(next.year, next.month + 1, 0);
      while (_isHolidayOrWeekend(next, holidays)) {
        next = next.subtract(const Duration(days: 1));
      }
    } else if (scheduleType == ScheduleType.specificWeekday &&
        selectedWeekday != null) {
      // Find the specific weekday in the new month/week
      // Note: This logic is tricky. "Specific Weekday" usually means "Next Same Weekday".
      // If we just added 7 days (weekly), we are fine.
      // If Monthly, and we just jumped a month, we might be off.
      // Assuming "Same weekday of the week" logic?
      // Or "First Friday"? The model doesn't support "First/Second/Third" yet, just "selectedWeekday".
      // Existing model logic:
      /*
      while (next.weekday != selectedWeekday) {
        next = next.add(const Duration(days: 1));
      }
      */
      while (next.weekday != selectedWeekday) {
        next = next.add(const Duration(days: 1));
      }
    }

    // 3. Apply Holiday Adjustments
    if (adjustForHolidays) {
      next = adjustDateForHolidays(next, holidays);
    }

    return next;
  }

  /// Calculates the "Ideal" date for a recurring transaction, ignoring holidays.
  /// This attempts to "snap back" to the original schedule if holidays forced a shift.
  static DateTime findIdealDate(
      RecurringTransaction rt, List<DateTime> holidays) {
    if (rt.frequency == Frequency.monthly &&
        rt.scheduleType == ScheduleType.fixedDate) {
      // Monthly Fixed Date Logic
      int targetDay = rt.byMonthDay ?? rt.nextExecutionDate.day;
      DateTime currentMonthAndYear =
          DateTime(rt.nextExecutionDate.year, rt.nextExecutionDate.month, 1);

      DateTime c1 = _getSafeDate(
          currentMonthAndYear.year, currentMonthAndYear.month, targetDay);
      DateTime c2 = _getSafeDate(
          currentMonthAndYear.year, currentMonthAndYear.month + 1, targetDay);

      if ((c1.difference(rt.nextExecutionDate).abs()) <
          (c2.difference(rt.nextExecutionDate).abs())) {
        return c1;
      } else {
        return c2;
      }
    } else if (rt.frequency == Frequency.weekly) {
      // Weekly Logic
      int targetWeekday = rt.byWeekDay ?? rt.selectedWeekday ?? 0;
      if (targetWeekday > 0 && rt.nextExecutionDate.weekday != targetWeekday) {
        for (int i = 0; i < 7; i++) {
          final forward = rt.nextExecutionDate.add(Duration(days: i));
          final backward = rt.nextExecutionDate.subtract(Duration(days: i));
          if (forward.weekday == targetWeekday) return forward;
          if (backward.weekday == targetWeekday) return backward;
        }
      }
    } else if (rt.scheduleType == ScheduleType.lastWorkingDay) {
      // Recalculate Last Working Day
      DateTime base = DateTime(
          rt.nextExecutionDate.year, rt.nextExecutionDate.month + 1, 0);
      DateTime cursor = base;
      // Use local check to break dependency on external list if needed,
      // but here we simply use the helper
      while (_isHolidayOrWeekend(cursor, holidays)) {
        cursor = cursor.subtract(const Duration(days: 1));
      }
      return cursor;
    }

    return rt.nextExecutionDate;
  }

  static DateTime _getSafeDate(int year, int month, int day) {
    int safeDay = day;
    int daysInMonth = DateTime(year, month + 1, 0).day;
    if (safeDay > daysInMonth) safeDay = daysInMonth;
    return DateTime(year, month, safeDay);
  }
}
