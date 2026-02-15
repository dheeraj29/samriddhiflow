import 'package:flutter_test/flutter_test.dart';
import 'package:samriddhi_flow/utils/billing_helper.dart';

void main() {
  group('BillingHelper Logic Check', () {
    test('isUnbilled on Bill Day should be True (to skip balance update)', () {
      final cycleDay = 20;
      // Scenario: Today is Bill Day (Jan 20)
      final now = DateTime(2025, 1, 20, 10, 0);
      // Transaction is today
      final txnDate = DateTime(2025, 1, 20, 12, 0);

      // Current Logic: returns FALSE (Billed) because of the special check
      // We WANT: TRUE (Unbilled) so it is skipped by StorageService and picked up by Rollover next day.

      final isUnbilled = BillingHelper.isUnbilled(txnDate, now, cycleDay);

      // Expectation for CORRECT behavior (which will fail initially):
      expect(isUnbilled, true,
          reason:
              "Transactions on Bill Day should be Unbilled so they are caught by Rollover");
    });

    test('isUnbilled day before Bill Day', () {
      final cycleDay = 20;
      final now = DateTime(2025, 1, 19);
      final txnDate = DateTime(2025, 1, 19);
      expect(BillingHelper.isUnbilled(txnDate, now, cycleDay), true);
    });

    test('isUnbilled day after Bill Day', () {
      final cycleDay = 20;
      final now = DateTime(2025, 1, 21);
      final txnDate = DateTime(2025, 1, 21);
      expect(BillingHelper.isUnbilled(txnDate, now, cycleDay), true);
    });

    test('isUnbilled day after Bill Day checking PREVIOUS cycle txn', () {
      final cycleDay = 20;
      final now = DateTime(2025, 1, 21);
      final txnDate = DateTime(2025, 1, 20); // Yesterday

      // Should be FALSE (Billed) because the cycle closed yesterday.
      // If I edit it now, I want instant update (since rollover presumably happened).
      expect(BillingHelper.isUnbilled(txnDate, now, cycleDay), false);
    });
    test('Regression: Bill Day 13th, Today 14th', () {
      final cycleDay = 13;
      // Today is Feb 14
      final now = DateTime(2025, 2, 14);

      // Previous Cycle: Jan 14 to Feb 13
      // We expect Cycle Start for NOW to be...
      final cycleStart = BillingHelper.getCycleStart(now, cycleDay);
      // If today is 14th and bill day is 13th, the NEW cycle started Feb 14th ?? No.
      // Let's trace getCycleStart logic:
      // if (14 > 13) -> DateTime(2025, 2, 14) -> Wait, if cycle start is today, then previous cycle ended yesterday.

      // If Cycle Start is Feb 14, then the "Previous Cycle" to scan is Jan 14 -> Feb 13.

      final txnInCycle = DateTime(2025, 2, 10); // Should be captured
      final txnBeforeCycle = DateTime(2025, 1, 10); // Should NOT be captured

      // If cycleDay is 13, and now is 14 Feb.
      // Cycle Start = 14 Feb.
      // Previous Cycle = 14 Jan -> 13 Feb.

      // Txn on Feb 10 is inside (14 Jan - 13 Feb).
      // Txn on Jan 10 is OUTSIDE (14 Dec - 13 Jan).

      final startOfPrevCycle = DateTime(2025, 1, 14);

      expect(cycleStart, DateTime(2025, 2, 14));
      expect(txnInCycle.isAfter(startOfPrevCycle), true);
      expect(txnInCycle.isBefore(cycleStart), true);

      expect(txnBeforeCycle.isBefore(startOfPrevCycle), true);

      // Check isUnbilled for the txnInCycle (Feb 10) relative to now (Feb 14)
      // Since it belongs to the CLOSED cycle (Jan 14-Feb 13), it is NOT unbilled... wait.
      // isUnbilled is for "Skip Balance Update".
      // If it belongs to a closed cycle, it should be BILLED (so we update balance? No, billed means it's frozen).
      // Actually, storage_service logic says: "If Unbilled, SKIP update".
      // So if it's Billed (Closed Cycle), we DO update balance?
      // Yes, standard transactions update balance.
      // BUT, Rollover logic is what aggregates them.

      // Verification:
      // The user says "Recalculate happened, balance is 0".
      // This refers to `checkCreditCardRollovers`.
      // It calculates `currentCycleStart` (Feb 14).
      // It sets `lastRollover` to `currentCycleStart - 1 month` (Jan 14).
      // It sums txns between Jan 14 and Feb 14.
      // If txn is Feb 10, it SHOULD be included.

      expect(cycleStart, DateTime(2025, 2, 14));
    });
    test('Scenario: Start 0, Pay 25k (Ghost Bill), Spend 15k', () {
      // Logic Simulation
      double balance = 0;
      double payment = 25000;
      double spends = 15000;

      // Current System:
      double result = balance - payment + spends; // -10,000
      expect(result, -10000);

      // User Desired Result: 15,000

      // Solution: Remove Payment
      double resultWithoutPayment = balance + spends; // 15,000
      expect(resultWithoutPayment, 15000);

      // Verification: Does removing payment break future?
      // Next Month: Start 15k. Pay 15k. Spend 10k.
      double nextBalance = resultWithoutPayment - 15000 + 10000; // 10,000
      expect(nextBalance, 10000); // Correct.
    });
  });
}
