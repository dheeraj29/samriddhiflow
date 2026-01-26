import 'package:flutter_test/flutter_test.dart';
import 'package:samriddhi_flow/models/recurring_transaction.dart';
// Note: You might need to expose the helper logic for next date calculation to be testable,
// or test it via the RecurringTransaction model if it contains the logic.
// Assuming logic is in a utility or static method. If it's private in the UI, we might need to refactor or test the model if the model does the calc.

// For this plan, assuming RecurrenceUtils or similar exists, or we test RecurringTransaction.getNextDate() if structured that way.
// If logic is inside AddTransactionScreen, we should ideally extract it.
// Let's assume we extract it to `lib/utils/recurrence_utils.dart` OR it exists in `RecurringTransaction` model.
// Checking `RecurringTransaction` model...

void main() {
  // Placeholder pending check of where logic resides.
  // If logic is embedded in UI, we should extract it to be unit testable.
  // For now, writing basic model test.

  group('RecurringTransaction Tests', () {
    test('Daily Recurrence', () {
      final txn = _createTxn(Frequency.daily, ScheduleType.fixedDate);
      final next = txn.calculateNextOccurrence(DateTime(2025, 1, 1));
      expect(next, DateTime(2025, 1, 2));
    });

    test('Weekly Recurrence (Simple)', () {
      final txn = _createTxn(Frequency.weekly, ScheduleType.fixedDate);
      final next = txn.calculateNextOccurrence(DateTime(2025, 1, 1)); // Wed
      expect(next, DateTime(2025, 1, 8)); // Next Wed
    });

    test('Monthly Recurrence (Fixed Date)', () {
      final txn = _createTxn(Frequency.monthly, ScheduleType.fixedDate);
      final next = txn.calculateNextOccurrence(DateTime(2025, 1, 15));
      expect(next, DateTime(2025, 2, 15));
    });

    test('Monthly Recurrence (Last Day of Month)', () {
      final txn = _createTxn(Frequency.monthly, ScheduleType.lastDayOfMonth);

      // From Jan 15 -> Feb 28 (non-leap)
      var next = txn.calculateNextOccurrence(DateTime(2025, 1, 15));
      expect(next, DateTime(2025, 2, 28));

      // From Feb 28 -> Mar 31
      next = txn.calculateNextOccurrence(DateTime(2025, 2, 28));
      expect(next, DateTime(2025, 3, 31));
    });

    test('Monthly Recurrence (Specific Weekday)', () {
      // Logic: find next occurrence that matches this weekday?
      // Note: Current implementation in model says:
      //   if (frequency == Frequency.monthly) next = +1 month
      //   then if (specificWeekday) while(next.weekday != target) next += 1 day
      // This implies it finds the *first* matching weekday *after* the 1 month mark.
      // Let's verify this behavior.

      final txn = RecurringTransaction.create(
        title: 'Test',
        amount: 100,
        category: 'Test',
        frequency: Frequency.monthly,
        startDate: DateTime(2025, 1, 1),
        scheduleType: ScheduleType.specificWeekday,
        selectedWeekday: 1, // Monday
      );

      // Start: Jan 1. +1 Month -> Feb 1 (Saturday).
      // Logic adds days until Monday -> Feb 3 (Monday).
      final next = txn.calculateNextOccurrence(DateTime(2025, 1, 1));
      expect(next, DateTime(2025, 2, 3));
    });

    test('Yearly Recurrence', () {
      final txn = _createTxn(Frequency.yearly, ScheduleType.fixedDate);
      final next = txn.calculateNextOccurrence(DateTime(2025, 1, 1));
      expect(next, DateTime(2026, 1, 1));
    });
  });
}

RecurringTransaction _createTxn(Frequency f, ScheduleType s) {
  return RecurringTransaction.create(
    title: 'Test',
    amount: 100,
    category: 'Test',
    frequency: f,
    startDate: DateTime(2025, 1, 1),
    scheduleType: s,
  );
}
