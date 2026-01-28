import 'package:flutter_test/flutter_test.dart';
import 'package:samriddhi_flow/utils/billing_helper.dart';

void main() {
  group('BillingHelper', () {
    test('getCycleStart - Date after cycle day', () {
      final date = DateTime(2024, 5, 20);
      final cycleDay = 15;
      final start = BillingHelper.getCycleStart(date, cycleDay);
      expect(start, DateTime(2024, 5, 15));
    });

    test('getCycleStart - Date before cycle day', () {
      final date = DateTime(2024, 5, 10);
      final cycleDay = 15;
      final start = BillingHelper.getCycleStart(date, cycleDay);
      // Should be previous month
      expect(start, DateTime(2024, 4, 15));
    });

    test('getCycleStart - Year boundary (Jan)', () {
      final date = DateTime(2024, 1, 10);
      final cycleDay = 15;
      final start = BillingHelper.getCycleStart(date, cycleDay);
      // Dec 2023
      expect(start, DateTime(2023, 12, 15));
    });

    test('getNextCycleStart', () {
      final currentStart = DateTime(2024, 5, 15);
      final next = BillingHelper.getNextCycleStart(currentStart);
      expect(next, DateTime(2024, 6, 15));
    });

    test('getNextCycleStart - Year boundary', () {
      final currentStart = DateTime(2023, 12, 15);
      final next = BillingHelper.getNextCycleStart(currentStart);
      expect(next, DateTime(2024, 1, 15));
    });
  });
}
