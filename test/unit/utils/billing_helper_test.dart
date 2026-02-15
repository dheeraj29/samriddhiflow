import 'package:flutter_test/flutter_test.dart';
import 'package:samriddhi_flow/utils/billing_helper.dart';

void main() {
  group('BillingHelper', () {
    const cycleDay28 = 28;
    const cycleDay5 = 5;

    group('getCycleStart', () {
      test('Date after cycle day (28)', () {
        final date = DateTime(2024, 5, 29);
        final start = BillingHelper.getCycleStart(date, cycleDay28);
        expect(start, DateTime(2024, 5, 29));
      });

      test('Date before cycle day (28)', () {
        final date = DateTime(2024, 5, 27);
        final start = BillingHelper.getCycleStart(date, cycleDay28);
        expect(start, DateTime(2024, 4, 29));
      });

      test('Date after cycle day (5)', () {
        final date = DateTime(2024, 5, 6);
        final start = BillingHelper.getCycleStart(date, cycleDay5);
        expect(start, DateTime(2024, 5, 6));
      });

      test('Date before cycle day (5)', () {
        final date = DateTime(2024, 5, 4);
        final start = BillingHelper.getCycleStart(date, cycleDay5);
        expect(start, DateTime(2024, 4, 6));
      });
    });

    group('isUnbilled (Dynamic)', () {
      test('Cycle Day 28: Date ON bill day IS unbilled (wait for rollover)',
          () {
        final now = DateTime(2024, 5, 28);
        final date = DateTime(2024, 5, 28);
        expect(BillingHelper.isUnbilled(date, now, 28), true);
      });

      test('Cycle Day 28: Date after bill day IS unbilled', () {
        final now = DateTime(2024, 5, 28);
        final date = DateTime(2024, 5, 29);
        expect(BillingHelper.isUnbilled(date, now, 28), true);
      });

      test('Cycle Day 5: Date ON bill day IS unbilled (wait for rollover)', () {
        final now = DateTime(2024, 5, 5);
        final date = DateTime(2024, 5, 5);
        expect(BillingHelper.isUnbilled(date, now, 5), true);
      });

      test('Cycle Day 5: Date after bill day IS unbilled', () {
        final now = DateTime(2024, 5, 5);
        final date = DateTime(2024, 5, 6);
        expect(BillingHelper.isUnbilled(date, now, 5), true);
      });

      test('Handling late opening (next day)', () {
        // App opened on the 29th for a Cycle-Day-28 card
        final now = DateTime(2024, 5, 29);
        final dateOn28 = DateTime(2024, 5, 28);
        // The 28th should still be considered "Billed" (of the cycle that just concluded)
        expect(BillingHelper.isUnbilled(dateOn28, now, 28), false);
      });
    });
  });
}
