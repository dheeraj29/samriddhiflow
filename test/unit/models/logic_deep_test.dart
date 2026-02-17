import 'package:flutter_test/flutter_test.dart';
import 'package:samriddhi_flow/models/loan.dart';
import 'package:samriddhi_flow/models/recurring_transaction.dart';
import 'package:samriddhi_flow/utils/recurrence_utils.dart';

void main() {
  group('Loan Logic Tests', () {
    test('Correct EMI calculation for standard loan', () {
      final loan = Loan(
        id: 'l1',
        name: 'Test Loan',
        totalPrincipal: 100000,
        remainingPrincipal: 100000,
        interestRate: 12,
        tenureMonths: 12,
        startDate: DateTime(2024, 1, 1),
        emiAmount: 8885,
        firstEmiDate: DateTime(2024, 2, 1),
      );

      expect(loan.emiAmount, 8885);
    });

    test('Loan balance reflects transactions', () {
      final loan = Loan(
        id: 'l1',
        name: 'Test Loan',
        totalPrincipal: 100000,
        remainingPrincipal: 100000,
        interestRate: 12,
        tenureMonths: 12,
        startDate: DateTime(2024, 1, 1),
        emiAmount: 8885,
        firstEmiDate: DateTime(2024, 2, 1),
      );

      final tx = LoanTransaction(
        id: 'lt1',
        amount: 8885,
        date: DateTime(2024, 2, 1),
        type: LoanTransactionType.emi,
        principalComponent: 7885,
        interestComponent: 1000,
        resultantPrincipal: 92115,
      );

      loan.transactions = [tx];
      loan.remainingPrincipal = tx.resultantPrincipal;

      expect(loan.remainingPrincipal, 92115);
    });
  });

  group('RecurringTransaction Logic Tests', () {
    test('Weekly interval calculation', () {
      final nextDate = RecurrenceUtils.calculateNextOccurrence(
        lastDate: DateTime(2024, 1, 1),
        frequency: Frequency.weekly,
        interval: 1,
        scheduleType: ScheduleType.fixedDate,
      );
      expect(nextDate, DateTime(2024, 1, 8));
    });

    test('Monthly (Fixed Date) interval calculation', () {
      final nextDate = RecurrenceUtils.calculateNextOccurrence(
        lastDate: DateTime(2024, 1, 15),
        frequency: Frequency.monthly,
        interval: 1,
        scheduleType: ScheduleType.fixedDate,
      );
      expect(nextDate, DateTime(2024, 2, 15));
    });

    test('Monthly (Last Day) logic crossing Feb', () {
      final nextDate = RecurrenceUtils.calculateNextOccurrence(
        lastDate: DateTime(2024, 1, 31),
        frequency: Frequency.monthly,
        interval: 1,
        scheduleType: ScheduleType.lastDayOfMonth,
      );
      expect(nextDate, DateTime(2024, 2, 29)); // Leap year 2024
    });

    test('Yearly interval calculation', () {
      final nextDate = RecurrenceUtils.calculateNextOccurrence(
        lastDate: DateTime(2024, 3, 15),
        frequency: Frequency.yearly,
        interval: 1,
        scheduleType: ScheduleType.fixedDate,
      );
      expect(nextDate, DateTime(2025, 3, 15));
    });
  });
}
