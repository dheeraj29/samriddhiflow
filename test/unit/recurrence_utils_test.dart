import 'package:flutter_test/flutter_test.dart';
import 'package:samriddhi_flow/models/recurring_transaction.dart';
import 'package:samriddhi_flow/utils/recurrence_utils.dart';

void main() {
  group('RecurrenceUtils', () {
    test('Last Working Day - No Conflicts', () {
      // Jan 31 2024 is Wed.
      final date = DateTime(2024, 1, 15);
      final result = RecurrenceUtils.findFirstOccurrence(
        baseDate: date,
        frequency: Frequency.monthly,
        scheduleType: ScheduleType.lastWorkingDay,
      );
      // Expect Jan 31
      expect(result, DateTime(2024, 1, 31));
    });

    test('Last Working Day - Weekend Conflict', () {
      // March 31 2024 is Sunday. March 30 is Sat. March 29 is Friday.
      final date = DateTime(2024, 3, 10);
      final result = RecurrenceUtils.findFirstOccurrence(
        baseDate: date,
        frequency: Frequency.monthly,
        scheduleType: ScheduleType.lastWorkingDay,
      );
      // Expect March 29 (Friday)
      expect(result, DateTime(2024, 3, 29));
    });

    test('Last Working Day - Holiday Conflict', () {
      // May 31 2024 is Friday.
      // Assume May 31 is a holiday. May 30 is Thursday.
      final holidays = [DateTime(2024, 5, 31)];
      final date = DateTime(2024, 5, 1);

      final result = RecurrenceUtils.findFirstOccurrence(
          baseDate: date,
          frequency: Frequency.monthly,
          scheduleType: ScheduleType.lastWorkingDay,
          holidays: holidays,
          adjustForHolidays:
              true // Technically lastWorkingDay implies adjustment, but holidays need passing
          );

      // Since lastWorkingDay logic inside _matchesCriteria checks holidays if passed, it should find May 30?
      // Wait, let's verify logic. _matchesCriteria finds the DATE that satisfies "Last Working Day".
      // If May 31 is in holidays list, it shouldn't match.
      // It should check May 30. May 30 is workday? Yes.
      // And we need to ensure *subsequent* days are NOT workdays.
      // May 31 is Holiday (Non-workday).
      // So May 30 IS the Last Working Day.

      expect(result, DateTime(2024, 5, 30));
    });

    test('Fixed Date - Adjust For Holidays', () {
      // Christmas Dec 25 2024 is Wednesday.
      final holidays = [DateTime(2024, 12, 25)];
      final date = DateTime(2024, 12, 25);

      final result = RecurrenceUtils.findFirstOccurrence(
        baseDate: date,
        frequency: Frequency.monthly,
        scheduleType: ScheduleType.fixedDate,
        holidays: holidays,
        adjustForHolidays: true,
      );

      // Should move back to Dec 24 (Tuesday)
      expect(result, DateTime(2024, 12, 24));
    });

    test('Calculate Next Occurrence - With Holiday', () {
      // Currently Jan 25. Monthly. Next is Feb 25.
      // Feb 25 2024 is Sunday.
      // So it should move back to Feb 23 (Friday).

      final lastDate = DateTime(2024, 1, 25);
      final next = RecurrenceUtils.calculateNextOccurrence(
        lastDate: lastDate,
        frequency: Frequency.monthly,
        interval: 1,
        scheduleType: ScheduleType.fixedDate,
        adjustForHolidays: true,
        holidays: [], // No specific holidays, just weekend check
      );

      expect(next, DateTime(2024, 2, 23));
    });

    test('findIdealDate - Snaps back to original day', () {
      // RT has nextExecutionDate = Feb 23 (Friday),
      // but original day was 25th (which was Sunday).
      final rt = RecurringTransaction(
        id: '1',
        title: 'Rent',
        amount: 1000,
        category: 'Housing',
        frequency: Frequency.monthly,
        scheduleType: ScheduleType.fixedDate,
        byMonthDay: 25,
        nextExecutionDate: DateTime(2024, 2, 23),
      );

      final ideal = RecurrenceUtils.findIdealDate(rt, []);
      expect(ideal.day, 25);
    });

    test('daily frequency calculation', () {
      final next = RecurrenceUtils.calculateNextOccurrence(
        lastDate: DateTime(2024, 1, 1),
        frequency: Frequency.daily,
        interval: 3,
        scheduleType: ScheduleType.fixedDate,
      );
      expect(next, DateTime(2024, 1, 4));
    });

    test('yearly frequency calculation', () {
      final next = RecurrenceUtils.calculateNextOccurrence(
        lastDate: DateTime(2024, 1, 1),
        frequency: Frequency.yearly,
        interval: 1,
        scheduleType: ScheduleType.fixedDate,
      );
      expect(next, DateTime(2025, 1, 1));
    });

    test('Specific Weekday - Monthly', () {
      // Find the first Friday of Feb 2024.
      // Feb 1 2024 is Thursday. Feb 2 is Friday.
      final start = DateTime(2024, 2, 1);
      final firstFriday = RecurrenceUtils.findFirstOccurrence(
        baseDate: start,
        frequency: Frequency.monthly,
        scheduleType: ScheduleType.specificWeekday,
        selectedWeekday: 5, // Friday
      );
      expect(firstFriday, DateTime(2024, 2, 2));
    });

    test('Last Weekend - Monthly', () {
      // March 2024. Last Weekend starts on March 30 (Sat) and 31 (Sun).
      // If we start from March 1, findFirstOccurrence with lastWeekend
      // should find March 30?
      // Actually _matchesCriteria for everyWeekend checks if it IS Sat/Sun.
      // For lastWeekend it checks if it's Sat/Sun AND next week is next month.
      final start = DateTime(2024, 3, 1);
      final lastSat = RecurrenceUtils.findFirstOccurrence(
        baseDate: start,
        frequency: Frequency.monthly,
        scheduleType: ScheduleType.lastWeekend,
      );
      expect(lastSat, DateTime(2024, 3, 30));
    });
  });
}
