import 'package:flutter_test/flutter_test.dart';
import 'package:samriddhi_flow/utils/billing_helper.dart';
import 'package:samriddhi_flow/models/account.dart';
import 'package:samriddhi_flow/models/transaction.dart';

void main() {
  group('BillingHelper - Credit Card Logic', () {
    final ccAccount = Account(
      id: 'cc1',
      name: 'Credit Card',
      type: AccountType.creditCard,
      balance: -5000.0,
      billingCycleDay: 20,
    );

    test(
        'calculateUnbilledAmount should include expenses but ignore payments (Spends Only)',
        () {
      final now = DateTime(2024, 1, 25); // Cycle started on 21st
      final txns = <Transaction>[
        Transaction(
          id: 't1',
          title: 'Food',
          amount: 100.0,
          date: DateTime(2024, 1, 22),
          type: TransactionType.expense,
          accountId: 'cc1',
          category: 'Food',
        ),
        Transaction(
          id: 't2',
          title: 'Payment',
          amount: 50.0,
          date: DateTime(2024, 1, 23),
          type: TransactionType.transfer,
          toAccountId: 'cc1',
          accountId: 'bank1',
          category: 'Payment',
        ),
      ];

      final unbilled =
          BillingHelper.calculateUnbilledAmount(ccAccount, txns, now);

      // Spends Only: 100.0
      expect(unbilled, 100.0);
    });

    group('getAdjustedCCData Simple Sum Logic', () {
      test('Scen 1: Simple Positive Debt', () {
        // Balance: 1000 (Old Debt)
        // Billed: 2000
        // Unbilled: 500
        // Expected Total: 3500
        final result = BillingHelper.getAdjustedCCData(
          accountBalance: 1000.0,
          billedAmount: 2000.0,
          unbilledAmount: 500.0,
          paymentsSinceRollover: 0.0,
        );

        expect(result.$1, 3500.0); // Total
        expect(result.$2, 2000.0); // Billed
        expect(result.$3, 1000.0); // Balance
        expect(result.$4, 500.0); // Unbilled
      });

      test('Scen 2: Balance includes Payments (Real-time Model)', () {
        // Start: 1000 Debt.
        // Payment of 3000 -> Balance becomes -2000.
        // Billed: 2000
        // Unbilled: 500
        // Total = -2000 + 2000 + 500 = 500
        final result = BillingHelper.getAdjustedCCData(
          accountBalance: -2000.0,
          billedAmount: 2000.0,
          unbilledAmount: 500.0,
          paymentsSinceRollover: 3000.0,
        );

        expect(result.$1, 500.0); // Total
        expect(result.$2, 0.0); // Billed (2000 - 3000, surplus 1000)
        expect(result.$3, 0.0); // Balance (1000 - 1000, surplus 0)
        expect(result.$4, 500.0); // Unbilled
      });

      test('Scen 3: Overpayment (Credit Balance)', () {
        // Balance: -3000
        // Billed: 2000
        // Unbilled: 0
        // Total = -1000
        final result = BillingHelper.getAdjustedCCData(
          accountBalance: -3000.0,
          billedAmount: 2000.0,
          unbilledAmount: 0.0,
          paymentsSinceRollover: 3000.0, // Assuming 3000 payment was made
        );

        expect(result.$1, -1000.0); // Total Net Credit
        expect(result.$2, 0.0); // Billed
        expect(result.$3, -1000.0); // Balance (Excess credit goes here)
        expect(result.$4, 0.0); // Unbilled
      });
    });

    group('Billing Cycle Freeze Logic', () {
      final now = DateTime(
          2024, 7, 25); // Cycle started Jul 21. Prev cycle: Jun 21 - Jul 20.

      test('calculateUnbilledAmount strictly respects freezeDate when frozen',
          () {
        final frozenAccount = Account(
          id: 'cc_frozen',
          name: 'Frozen CC',
          type: AccountType.creditCard,
          balance: 0.0,
          billingCycleDay: 20,
          isFrozen: true,
          isFrozenCalculated: false,
          freezeDate: DateTime(2024, 7, 23), // Freeze started after cycle start
        );

        final txns = [
          Transaction(
              id: '1',
              title: 'Before Freeze',
              amount: 100.0,
              date: DateTime(2024, 7, 22),
              type: TransactionType.expense,
              accountId: 'cc_frozen',
              category: 'General'),
          Transaction(
              id: '2',
              title: 'After Freeze',
              amount: 50.0,
              date: DateTime(2024, 7, 24),
              type: TransactionType.expense,
              accountId: 'cc_frozen',
              category: 'General'),
        ];

        final unbilled =
            BillingHelper.calculateUnbilledAmount(frozenAccount, txns, now);

        // Should only count 'After Freeze' (50.0) as the start bound is shifted to freezeDate.
        expect(unbilled, 50.0);
      });

      test(
          'calculateBilledAmount explicitly starts from freezeDate on transition bill',
          () {
        final transitionAccount = Account(
          id: 'cc_transition',
          name: 'Transitioning CC',
          type: AccountType.creditCard,
          balance: 0.0,
          billingCycleDay: 20,
          isFrozen: true,
          isFrozenCalculated: true, // It is the second stage!
          freezeDate: DateTime(2024, 6, 25), // Freeze was set last month
        );

        // Previous cycle normal bounds: Jun 21 - Jul 20
        // Because of freezeDate, bounds should be strictly: Jun 25 - Jul 20!
        final txns = [
          Transaction(
              id: '1',
              title: 'Before Freeze',
              amount: 100.0,
              date: DateTime(2024, 6, 23),
              type: TransactionType.expense,
              accountId: 'cc_transition',
              category: 'General'),
          Transaction(
              id: '2',
              title: 'After Freeze',
              amount: 50.0,
              date: DateTime(2024, 6, 26),
              type: TransactionType.expense,
              accountId: 'cc_transition',
              category: 'General'),
        ];

        // We mock the lastRolloverMillis. Let's say last rollover was way before (e.g. Jun 20).
        final lastRollover = DateTime(2024, 6, 20).millisecondsSinceEpoch;

        final billed = BillingHelper.calculateBilledAmount(
            transitionAccount, txns, now, lastRollover);

        // Should only count 'After Freeze' (50.0).
        expect(billed, 50.0);
      });
    });
  });
}
