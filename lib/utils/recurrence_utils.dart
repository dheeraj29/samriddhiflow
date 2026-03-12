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
    if (adjustForHolidays) {
      bool moveForward = true;
      if ([
        ScheduleType.lastDayOfMonth,
        ScheduleType.lastWorkingDay,
        ScheduleType.lastWeekend
      ].contains(scheduleType)) {
        moveForward = false;
      } else if (scheduleType == ScheduleType.fixedDate && candidate.day > 1) {
        // Move backward for interior fixed dates to stay in month and match legacy behavior
        moveForward = false;
      }
      candidate =
          adjustDateForHolidays(candidate, holidays, moveForward: moveForward);
    }

    return candidate;
  }

  static DateTime adjustDateForHolidays(DateTime date, List<DateTime> holidays,
      {bool moveForward = false}) {
    DateTime adjusted = date;
    int safeGuard = 0;
    // Recursively move if lands on Weekend OR Holiday
    while (_isHolidayOrWeekend(adjusted, holidays) && safeGuard < 30) {
      if (moveForward) {
        adjusted = adjusted.add(const Duration(days: 1));
      } else {
        adjusted = adjusted.subtract(const Duration(days: 1));
      }
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
    if (frequency == Frequency.weekly) {
      return _matchesWeekly(date, type, weekday); // coverage:ignore-line
    }
    if (frequency == Frequency.monthly) {
      return _matchesMonthly(date, type, weekday, holidays);
    }
    return true;
  }

  // coverage:ignore-start
  static bool _matchesWeekly(DateTime date, ScheduleType type, int? weekday) {
    if (type == ScheduleType.specificWeekday && weekday != null) {
      return date.weekday == weekday;
      // coverage:ignore-end
    }
    return true;
  }

  static bool _matchesMonthly(
      DateTime date, ScheduleType type, int? weekday, List<DateTime> holidays) {
    return switch (type) {
      ScheduleType.fixedDate => true,
      ScheduleType.lastDayOfMonth => date.add(const Duration(days: 1)).month !=
          date.month, // coverage:ignore-line
      ScheduleType.lastWorkingDay => _isLastWorkingDay(date, holidays),
      ScheduleType.everyWeekend => date.weekday == 6 || date.weekday == 7,
      ScheduleType.lastWeekend => _matchesLastWeekend(date),
      ScheduleType.specificWeekday =>
        weekday != null ? date.weekday == weekday : true,
      ScheduleType.firstWorkingDay => _isFirstWorkingDay(date, holidays),
    };
  }

  static bool _matchesLastWeekend(DateTime date) {
    if (date.weekday != 6 && date.weekday != 7) return false;
    final nextWeek = date.add(const Duration(days: 7));
    return nextWeek.month != date.month;
  }

  static bool _isLastWorkingDay(DateTime date, List<DateTime> holidays) {
    if (_isHolidayOrWeekend(date, holidays)) return false;
    DateTime temp = date.add(const Duration(days: 1));
    while (temp.month == date.month) {
      if (!_isHolidayOrWeekend(temp, holidays)) return false;
      temp = temp.add(const Duration(days: 1));
    }
    return true;
  }

  static bool _isFirstWorkingDay(DateTime date, List<DateTime> holidays) {
    if (_isHolidayOrWeekend(date, holidays)) return false;
    DateTime temp = date.subtract(const Duration(days: 1));
    while (temp.month == date.month) {
      if (!_isHolidayOrWeekend(temp, holidays)) return false;
      temp = temp.subtract(const Duration(days: 1));
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
    // 1. Basic increment based on frequency
    DateTime next = _incrementByFrequency(
        lastDate, frequency, interval, scheduleType, startDate);

    // 2. Apply Schedule Type constraints
    next = _applyScheduleType(next, scheduleType, selectedWeekday, holidays);

    // 3. Apply Holiday Adjustments
    if (adjustForHolidays) {
      bool moveForward = true;
      if ([
        ScheduleType.lastDayOfMonth,
        ScheduleType.lastWorkingDay,
        ScheduleType.lastWeekend
      ].contains(scheduleType)) {
        moveForward = false;
      } else if (scheduleType == ScheduleType.fixedDate && next.day > 1) {
        // Stay in month by moving backward
        moveForward = false;
      }
      next = adjustDateForHolidays(next, holidays, moveForward: moveForward);
    }

    return next;
  }

  static DateTime _incrementByFrequency(DateTime lastDate, Frequency frequency,
      int interval, ScheduleType scheduleType, DateTime? startDate) {
    if (frequency == Frequency.daily) {
      return lastDate.add(Duration(days: interval));
    } else if (frequency == Frequency.weekly) {
      return lastDate.add(Duration(days: 7 * interval));
    } else if (frequency == Frequency.yearly) {
      return DateTime(lastDate.year + interval, lastDate.month, lastDate.day);
    }

    // Monthly
    int nextMonth = lastDate.month + interval;
    int nextYear = lastDate.year;
    while (nextMonth > 12) {
      nextMonth -= 12;
      nextYear++;
    }

    if (scheduleType == ScheduleType.fixedDate) {
      int targetDay = startDate?.day ?? lastDate.day;
      int maxDays = DateTime(nextYear, nextMonth + 1, 0).day;
      return DateTime(
          nextYear, nextMonth, targetDay > maxDays ? maxDays : targetDay);
    }
    // For other types, start at the 1st of the target month and let logic below snap it.
    return DateTime(nextYear, nextMonth, 1);
  }

  static DateTime _applyScheduleType(DateTime next, ScheduleType scheduleType,
      int? selectedWeekday, List<DateTime> holidays) {
    switch (scheduleType) {
      case ScheduleType.lastDayOfMonth:
        return DateTime(next.year, next.month + 1, 0);
      case ScheduleType.lastWorkingDay:
        next = DateTime(next.year, next.month + 1, 0);
        while (_isHolidayOrWeekend(next, holidays)) {
          next = next.subtract(const Duration(days: 1));
        }
        return next;
      case ScheduleType.specificWeekday:
        if (selectedWeekday != null) {
          while (next.weekday != selectedWeekday) {
            // coverage:ignore-line
            next = next.add(const Duration(days: 1)); // coverage:ignore-line
          }
        }
        return next;
      case ScheduleType.firstWorkingDay:
        next = DateTime(next.year, next.month, 1);
        while (_isHolidayOrWeekend(next, holidays)) {
          next = next.add(const Duration(days: 1));
        }
        return next;
      default:
        return next;
    }
  }

  /// Calculates the "Ideal" date for a recurring transaction, ignoring holidays.
  /// This attempts to "snap back" to the original schedule if holidays forced a shift.
  static DateTime findIdealDate(
      RecurringTransaction rt, List<DateTime> holidays) {
    if (rt.frequency == Frequency.monthly &&
        rt.scheduleType == ScheduleType.fixedDate) {
      return _findIdealFixedDate(rt);
    }
    if (rt.frequency == Frequency.weekly) {
      return _findIdealWeekly(rt); // coverage:ignore-line
    }
    if (rt.scheduleType == ScheduleType.lastWorkingDay) {
      return _findLastWorkingDayInMonth(rt, holidays);
    }
    if (rt.scheduleType == ScheduleType.firstWorkingDay) {
      return _findFirstWorkingDayInMonth(rt, holidays); // coverage:ignore-line
    }
    return rt.nextExecutionDate;
  }

  static DateTime _findIdealFixedDate(RecurringTransaction rt) {
    int targetDay = rt.byMonthDay ?? rt.nextExecutionDate.day;
    final yr = rt.nextExecutionDate.year;
    final mo = rt.nextExecutionDate.month;

    DateTime c1 = _getSafeDate(yr, mo, targetDay);
    DateTime c2 = _getSafeDate(yr, mo + 1, targetDay);

    return (c1.difference(rt.nextExecutionDate).abs()) <
            (c2.difference(rt.nextExecutionDate).abs())
        ? c1
        : c2;
  }

  // coverage:ignore-start
  static DateTime _findIdealWeekly(RecurringTransaction rt) {
    int targetWeekday = rt.byWeekDay ?? rt.selectedWeekday ?? 0;
    if (targetWeekday > 0 && rt.nextExecutionDate.weekday != targetWeekday) {
      for (int i = 0; i < 7; i++) {
        final forward = rt.nextExecutionDate.add(Duration(days: i));
        final backward = rt.nextExecutionDate.subtract(Duration(days: i));
        if (forward.weekday == targetWeekday) return forward;
        if (backward.weekday == targetWeekday) return backward;
        // coverage:ignore-end
      }
    }
    return rt.nextExecutionDate; // coverage:ignore-line
  }

  static DateTime _findLastWorkingDayInMonth(
      RecurringTransaction rt, List<DateTime> holidays) {
    DateTime base =
        DateTime(rt.nextExecutionDate.year, rt.nextExecutionDate.month + 1, 0);
    DateTime cursor = base;
    while (_isHolidayOrWeekend(cursor, holidays)) {
      cursor = cursor.subtract(const Duration(days: 1)); // coverage:ignore-line
    }
    return cursor;
  }

  static DateTime _findFirstWorkingDayInMonth(
      // coverage:ignore-line
      RecurringTransaction rt,
      List<DateTime> holidays) {
    DateTime base = DateTime(rt.nextExecutionDate.year,
        rt.nextExecutionDate.month, 1); // coverage:ignore-line
    DateTime cursor = base;
    while (_isHolidayOrWeekend(cursor, holidays)) {
      // coverage:ignore-line
      cursor = cursor.add(const Duration(days: 1)); // coverage:ignore-line
    }
    return cursor;
  }

  static DateTime _getSafeDate(int year, int month, int day) {
    int safeDay = day;
    int daysInMonth = DateTime(year, month + 1, 0).day;
    if (safeDay > daysInMonth) safeDay = daysInMonth;
    return DateTime(year, month, safeDay);
  }
}
