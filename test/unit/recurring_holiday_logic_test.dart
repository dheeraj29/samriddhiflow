import 'package:flutter_test/flutter_test.dart';
import 'package:samriddhi_flow/models/recurring_transaction.dart';
import 'package:samriddhi_flow/utils/recurrence_utils.dart';

import '../widget/test_mocks.dart';

// Mock StorageService slightly more detailed for this test
class MockStorageServiceWithHolidays extends MockStorageService {
  List<DateTime> holidays = [];

  @override
  List<DateTime> getHolidays() => holidays;

  @override
  Future<void> addHoliday(DateTime date) async {
    holidays.add(DateTime(date.year, date.month, date.day));
  }

  @override
  Future<void> removeHoliday(DateTime date) async {
    holidays.removeWhere((h) =>
        h.year == date.year && h.month == date.month && h.day == date.day);
  }
}

void main() {
  late MockStorageServiceWithHolidays mockStorage;
  late RecurringTransaction rt;

  setUp(() {
    mockStorage = MockStorageServiceWithHolidays();
    // Setup a recurring transaction: Monthly on the 2nd
    // adjustForHolidays = true
    rt = RecurringTransaction(
      id: 'rt1',
      title: 'Rent',
      amount: 1000,
      category: 'Rent',
      frequency: Frequency.monthly,
      scheduleType: ScheduleType.fixedDate,
      byMonthDay: 2, // 2nd of the month
      nextExecutionDate: DateTime(2024, 5, 2), // May 2nd, 2024 (Thursday)
      adjustForHolidays: true,
      isActive: true,
    );
  });

  test('Holiday adjust behavior verification (Reproduction)', () {
    // 1. Initial State: May 2nd is free. Next date is May 2nd.
    expect(rt.nextExecutionDate, DateTime(2024, 5, 2));

    // 2. Add Holiday on May 2nd
    final holiday = DateTime(2024, 5, 2);
    // Logic that runs inside StorageService.addHoliday usually triggers validation
    // Here we simulate the logic manually or use the Notifier if we can.

    // Simulate Logic:
    final holidays = [holiday];

    // If May 2nd is a holiday, RecurrenceUtils should shift it BACK to May 1st (Wednesday)
    final adjusted =
        RecurrenceUtils.adjustDateForHolidays(rt.nextExecutionDate, holidays);

    // May 1st is safe.
    expect(adjusted, DateTime(2024, 5, 1));

    // Update the RT
    rt.nextExecutionDate = adjusted;

    // 3. Current State: RT is now May 1st.
    // User deletes the holiday on May 2nd.
    // The system should realize that May 1st is NO LONGER the correct date if the original schedule was May 2nd.
    // But since the RT object only stores "nextExecutionDate = May 1st", how does it know to go back to May 2nd?
    // It relies on `byMonthDay` (stored as 2) or re-calculating from a base.

    // Simulate Holiday Removal
    final emptyHolidays = <DateTime>[];

    // BUG REPRODUCTION / VERIFICATION:
    // If we just run adjustDateForHolidays(May 1st, []), it stays May 1st.
    // But if we run findIdealDate first, it should return May 2nd.

    // Step A: Find Ideal
    final ideal = RecurrenceUtils.findIdealDate(rt, emptyHolidays);
    expect(ideal, DateTime(2024, 5, 2), reason: "Ideal date should be 2nd");

    // Step B: Adjust (should stay 2nd since no holidays)
    final postRemovalDate =
        RecurrenceUtils.adjustDateForHolidays(ideal, emptyHolidays);
    expect(postRemovalDate, DateTime(2024, 5, 2),
        reason: "Final adjusted date should be 2nd");
  });

  test('Last Working Day logic - Holiday on last day (Reversion)', () {
    // Scenario: Last Working Day of Month.
    // April 2024 ends on 30th (Tuesday).
    // rt initial: 2024-04-30
    final rtLastDay = RecurringTransaction(
      id: 'rt2',
      title: 'Salary',
      amount: 5000,
      category: 'Income',
      frequency: Frequency.monthly,
      scheduleType: ScheduleType.lastWorkingDay,
      nextExecutionDate: DateTime(2024, 4, 30),
      adjustForHolidays: true,
      isActive: true,
    );

    // 1. Add Holiday on April 30th
    final holidays = [DateTime(2024, 4, 30)];

    // Logic: adjustDateForHolidays should move it back to 29th (Monday)
    final adjusted = RecurrenceUtils.adjustDateForHolidays(
        rtLastDay.nextExecutionDate, holidays);
    expect(adjusted, DateTime(2024, 4, 29),
        reason: "Should move to 29th as 30th is holiday");

    // Update RT
    rtLastDay.nextExecutionDate = adjusted;

    // 2. Remove Holiday (list empty)
    final emptyHolidays = <DateTime>[];

    // Logic: findIdealDate should recalculate "Last Working Day" of April -> 30th
    final ideal = RecurrenceUtils.findIdealDate(rtLastDay, emptyHolidays);
    expect(ideal, DateTime(2024, 4, 30),
        reason: "Should revert to 30th after holiday removal");
  });
}
