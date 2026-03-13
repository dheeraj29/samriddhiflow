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

      // New behavior: 100.0 (Payments are ignored in periodic sums)
      expect(unbilled, 100.0);
    });

    test(
        'calculatePaymentsSinceLastRollover should sum payments after rollover',
        () {
      final lastRollover = DateTime(2024, 1, 20).millisecondsSinceEpoch;
      final txns = <Transaction>[
        Transaction(
          id: 't1',
          title: 'Spend',
          amount: 100.0,
          date: DateTime(2024, 1, 22),
          type: TransactionType.expense,
          accountId: 'cc1',
          category: 'Food',
        ),
        Transaction(
          id: 't2',
          title: 'Payment 1',
          amount: 50.0,
          date: DateTime(2024, 1, 23),
          type: TransactionType.transfer,
          toAccountId: 'cc1',
          accountId: 'bank1',
          category: 'Payment',
        ),
        Transaction(
          id: 't3',
          title: 'Payment 2',
          amount: 75.0,
          date: DateTime(2024, 1, 24),
          type: TransactionType.transfer,
          toAccountId: 'cc1',
          accountId: 'bank1',
          category: 'Payment',
        ),
        Transaction(
          id: 't4',
          title: 'Old Payment',
          amount: 1000.0,
          date: DateTime(2024, 1, 15),
          type: TransactionType.transfer,
          toAccountId: 'cc1',
          accountId: 'bank1',
          category: 'Payment',
        ),
      ];

      final payments = BillingHelper.calculatePaymentsSinceLastRollover(
          ccAccount, txns, lastRollover);

      expect(payments, 125.0); // 50 + 75
    });

    group('getAdjustedCCData Waterfall Logic', () {
      test('Scen 1: Exact Payment (Clears Billed)', () {
        // Balance: 1000 (Old Debt)
        // Billed: 2000 (Prev Cycle Spend)
        // Payments: 2000
        // Expected: Balance 1000, Billed 0, Unbilled x
        final result = BillingHelper.getAdjustedCCData(
          accountBalance: -1000.0,
          billedAmount: 2000.0,
          unbilledAmount: 500.0,
          totalPaymentsSinceRollover: 2000.0,
        );

        expect(result.$1, 1000.0); // Balance
        expect(result.$2, 0.0); // Billed
        expect(result.$3, 500.0); // Unbilled
      });

      test('Scen 2: Full Payment (Clears Billed + Balance)', () {
        // Old Debt: 1000
        // Billed: 2000
        // Payments: 3000
        // accountBalance: 1000 - 3000 = -2000
        final result = BillingHelper.getAdjustedCCData(
          accountBalance: -2000.0,
          billedAmount: 2000.0,
          unbilledAmount: 500.0,
          totalPaymentsSinceRollover: 3000.0,
        );

        expect(result.$1, 0.0); // Balance
        expect(result.$2, 0.0); // Billed
        expect(result.$3, 500.0); // Unbilled
      });

      test('Scen 3: Overpayment (Clears All + Excess)', () {
        // Old Debt: 1000
        // Billed: 2000
        // Payments: 4000
        // accountBalance: 1000 - 4000 = -3000
        final result = BillingHelper.getAdjustedCCData(
          accountBalance: -3000.0,
          billedAmount: 2000.0,
          unbilledAmount: 500.0,
          totalPaymentsSinceRollover: 4000.0,
        );

        expect(result.$1, -500.0); // Balance (Excess Credit)
        expect(result.$2, 0.0); // Billed
        expect(result.$3, 0.0); // Unbilled
      });

      test('Scen 4: Historical Excess', () {
        // Backup restore case:
        // accountBalance: -500 (Historical credit)
        // Payments since rollover: 0
        // Billed: 2000
        // OldDebtAtRollover = -500 + 0 = -500.
        // remCredit = 0 + 500 = 500.
        final result = BillingHelper.getAdjustedCCData(
          accountBalance: -500.0,
          billedAmount: 2000.0,
          unbilledAmount: 1000.0,
          totalPaymentsSinceRollover: 0.0,
        );

        expect(result.$1, 0.0); // Balance
        expect(result.$2, 1500.0); // Billed (500 credit applied)
        expect(result.$3, 1000.0); // Unbilled
      });
    });
  });
}
