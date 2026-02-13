import 'package:flutter_test/flutter_test.dart';
import 'package:samriddhi_flow/models/account.dart';
import 'package:samriddhi_flow/utils/billing_helper.dart';

void main() {
  group('BillingHelper Tests', () {
    test('getCycleStart - Date after cycle day', () {
      final date = DateTime(2024, 1, 20);
      final cycleDay = 15;
      final result = BillingHelper.getCycleStart(date, cycleDay);
      expect(result, DateTime(2024, 1, 16));
    });

    test('getCycleStart - Date before cycle day', () {
      final date = DateTime(2024, 1, 10);
      final cycleDay = 15;
      final result = BillingHelper.getCycleStart(date, cycleDay);
      expect(result, DateTime(2023, 12, 16));
    });

    test('getCycleStart - Date exactly on cycle day', () {
      final date = DateTime(2024, 1, 15);
      final cycleDay = 15;
      final result = BillingHelper.getCycleStart(date, cycleDay);
      expect(result, DateTime(2023, 12, 16));
    });

    test('getNextCycleStart', () {
      final start = DateTime(2023, 12, 16);
      final next = BillingHelper.getNextCycleStart(start);
      expect(next, DateTime(2024, 1, 16));
    });

    test('getNextCycleStart - Year boundary', () {
      final start = DateTime(2023, 12, 16);
      final next = BillingHelper.getNextCycleStart(start);
      expect(next, DateTime(2024, 1, 16)); // December + 1 -> January
    });
  });

  group('Account Model Logic', () {
    test('calculateBilledAmount - Standard Account returns balance', () {
      final account = Account(
        id: '1',
        name: 'Savings',
        type: AccountType.savings,
        balance: 1000.50,
      );
      expect(account.calculateBilledAmount([]), 1000.50);
    });

    test('calculateBilledAmount - Credit Card with balance returns balance',
        () {
      final account = Account(
        id: '1',
        name: 'CC',
        type: AccountType.creditCard,
        balance: 500.0,
        billingCycleDay: 15,
      );
      expect(account.calculateBilledAmount([]), 500.0);
    });

    test('calculateBilledAmount - Negative balance on CC returns 0', () {
      final account = Account(
        id: '1',
        name: 'CC',
        type: AccountType.creditCard,
        balance: -100.0, // Overpaid
        billingCycleDay: 15,
      );
      expect(account.calculateBilledAmount([]), 0.0);
    });
  });
}
