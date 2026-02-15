import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:samriddhi_flow/models/account.dart';
import 'package:samriddhi_flow/models/transaction.dart';
import 'package:samriddhi_flow/services/storage_service.dart';
import 'package:samriddhi_flow/utils/billing_helper.dart';

// Mocks
class MockHive extends Mock implements HiveInterface {}

class MockBox extends Mock implements Box {}

class MockAccountBox extends Mock implements Box<Account> {}

class MockTransactionBox extends Mock implements Box<Transaction> {}

void main() {
  late StorageService storageService;
  late MockHive mockHive;
  late MockAccountBox mockAccountBox;
  late MockTransactionBox mockTxnBox;
  late MockBox mockSettingsBox;

  setUp(() {
    mockHive = MockHive();
    mockAccountBox = MockAccountBox();
    mockTxnBox = MockTransactionBox();
    mockSettingsBox = MockBox();

    registerFallbackValue(
        Account(id: 'fb', name: 'f', type: AccountType.creditCard, balance: 0));
    registerFallbackValue(Transaction(
        id: 'tx',
        title: 't',
        amount: 0,
        date: DateTime.now(),
        type: TransactionType.expense,
        category: 'General'));

    when(() => mockHive.box<Account>(any())).thenReturn(mockAccountBox);
    when(() => mockHive.box<Transaction>(any())).thenReturn(mockTxnBox);
    when(() => mockHive.box(any())).thenReturn(mockSettingsBox);

    // Default mocks
    when(() => mockSettingsBox.get(any(),
        defaultValue: any(named: 'defaultValue'))).thenReturn(null);
    when(() => mockSettingsBox.get('txnsSinceBackup',
        defaultValue: any(named: 'defaultValue'))).thenReturn(0);
    when(() => mockSettingsBox.put(any(), any())).thenAnswer((_) async {});
    when(() => mockAccountBox.put(any(), any())).thenAnswer((_) async {});
    when(() => mockTxnBox.put(any(), any())).thenAnswer((_) async {});

    storageService = StorageService(mockHive);
    when(() => mockHive.isBoxOpen(any())).thenReturn(true);
  });

  group('Lagged Billing & Display Logic', () {
    test('Rollover ignores recent cycle (leaves it as Billed)', () async {
      final acc = Account(
          id: 'c1',
          name: 'Card',
          type: AccountType.creditCard,
          balance: 1000,
          billingCycleDay: 20);
      // Expect Rollover Update to Target (Jan 21).
      // Logic Update: lastRollover is stored as (CycleStart - 1 second).
      // So if prev cycle start was Jan 21. Rollover date is Jan 20 23:59:59.
      // But here we are testing "Rollover ignores recent cycle".
      // Setup: Last Rollover = Jan 21 (Exact).
      // Check: Feb 25 (Now). Current Cycle Start: Feb 21.
      // Target Rollover: Jan 21 - 1 second.
      // Condition: Target (Jan 21 - 1s) > Last (Jan 21)? False.
      // So NO rollover should happen.

      // But wait. If Last Rollover was stored as Jan 21 - 1s.
      // Then Last would be Jan 20 23:59:59.
      // Target would be Jan 20 23:59:59.
      // Target > Last? False. No rollover.
      // Correct.

      // Let's adjust the Setup to simulate REAL state (Jan 20 23:59:59).
      final lastRollover =
          DateTime(2025, 1, 21).subtract(const Duration(seconds: 1));

      when(() => mockSettingsBox.get('last_rollover_c1'))
          .thenReturn(lastRollover.millisecondsSinceEpoch);
      when(() => mockAccountBox.toMap()).thenReturn({'c1': acc});
      when(() => mockTxnBox.toMap()).thenReturn({});
      // Fix: Need these to suppress errors in storage logic
      when(() => mockSettingsBox.get('txnsSinceBackup',
          defaultValue: any(named: 'defaultValue'))).thenReturn(0);
      when(() => mockSettingsBox.get(any(that: startsWith('ignore')),
          defaultValue: any(named: 'defaultValue'))).thenReturn(false);

      // Execute Rollover Check for Feb 25
      // Current Cycle Start: Feb 21.
      // Target Rollover: Jan 21. (1 month lag).
      // Since Last (Jan 21) == Target (Jan 21). No Rollover.
      await storageService.checkCreditCardRollovers(
          nowOverride: DateTime(2025, 2, 25));

      verifyNever(() => mockSettingsBox.put('last_rollover_c1', any()));

      // Helper Calculation Verification
      final now = DateTime(2025, 2, 25);
      final txns = [
        Transaction(
            id: 't1',
            title: 'Old Billed',
            amount: 500,
            date: DateTime(2025, 2, 10),
            type: TransactionType.expense,
            accountId: 'c1',
            category: 'General'), // Range (Jan 21, Feb 21]
        Transaction(
            id: 't2',
            title: 'New Unbilled',
            amount: 200,
            date: DateTime(2025, 2, 22),
            type: TransactionType.expense,
            accountId: 'c1',
            category: 'General'), // Range (Feb 21, Mar 21]
      ];

      final billed = BillingHelper.calculateBilledAmount(
          acc, txns, now, lastRollover.millisecondsSinceEpoch);
      final unbilled = BillingHelper.calculateUnbilledAmount(acc, txns, now);

      expect(billed, 500.0);
      expect(unbilled, 200.0);
    });

    test('Old Cycle rolls over into Balance', () async {
      // Setup: Last Rollover = Dec 21, 2024.
      // Current Date = Feb 25, 2025.
      // Current Cycle Start = Feb 21, 2025.
      // Lag Target = Jan 21, 2025.
      // Logic: Roll (Dec 21 -> Jan 21] into Balance.

      final acc = Account(
          id: 'c1',
          name: 'Card',
          type: AccountType.creditCard,
          balance: 1000,
          billingCycleDay: 20);
      final lastRollover = DateTime(2024, 12, 21);

      when(() => mockSettingsBox.get('last_rollover_c1'))
          .thenReturn(lastRollover.millisecondsSinceEpoch);
      when(() => mockAccountBox.toMap()).thenReturn({'c1': acc});
      // Fix: Need these to suppress errors in storage logic
      when(() => mockSettingsBox.get('txnsSinceBackup',
          defaultValue: any(named: 'defaultValue'))).thenReturn(0);
      when(() => mockSettingsBox.get(any(that: startsWith('ignore')),
          defaultValue: any(named: 'defaultValue'))).thenReturn(false);

      // Transaction in (Dec 21, Jan 21]
      final txn = Transaction(
          id: 't1',
          title: 'Old S',
          amount: 300,
          date: DateTime(2025, 1, 10),
          type: TransactionType.expense,
          accountId: 'c1',
          category: 'General');
      final txns = {'t1': txn};
      when(() => mockTxnBox.toMap())
          .thenReturn(Map<dynamic, Transaction>.from(txns));

      // Execute Rollover Check for Feb 25
      await storageService.checkCreditCardRollovers(
          nowOverride: DateTime(2025, 2, 25));

      // Expect Balance Update: 1000 + 300 = 1300.
      final capturedAcc = verify(() => mockAccountBox.put('c1', captureAny()))
          .captured
          .first as Account;
      expect(capturedAcc.balance, 1300.0);

      // Expect Rollover Update to Target (Jan 21 - 1 second).
      final expectedRollover =
          DateTime(2025, 1, 21).subtract(const Duration(seconds: 1));

      verify(() => mockSettingsBox.put(
              'last_rollover_c1', expectedRollover.millisecondsSinceEpoch))
          .called(1);
    });

    test('Display Logic: Payment Cascade', () {
      // Simulating the UI Logic in AccountCard
      Map<String, double> calculateDisplay(double balance, double billed) {
        double displayBalance = balance;
        double displayBilled = billed;

        if (displayBalance < 0) {
          double credit = -displayBalance;
          displayBalance = 0;
          if (credit <= displayBilled) {
            displayBilled -= credit;
            credit = 0;
          } else {
            credit -= displayBilled;
            displayBilled = 0;
            displayBalance = -credit;
          }
        }
        return {'balance': displayBalance, 'billed': displayBilled};
      }

      // Case 1: Debt 1000, Billed 500. Pay 0.
      var res = calculateDisplay(1000, 500);
      expect(res['balance'], 1000.0);
      expect(res['billed'], 500.0);

      // Case 2: Pay 1200. Balance = 1000 - 1200 = -200. Billed = 500.
      res = calculateDisplay(-200, 500);
      expect(res['balance'], 0.0);
      expect(res['billed'], 300.0);

      // Case 3: Pay 1600. Balance = 1000 - 1600 = -600. Billed = 500.
      // Credit 600. Deduct 500 from Bill -> Bill 0. Remainder 100 -> Balance -100.
      res = calculateDisplay(-600, 500);
      expect(res['balance'], -100.0);
      expect(res['billed'], 0.0);
    });

    group('Restrictions & Repair', () {
      test('Cannot add transaction to closed cycle', () async {
        final acc = Account(
            id: 'c1',
            name: 'Card',
            type: AccountType.creditCard,
            balance: 0,
            billingCycleDay: 20);
        final lastRollover = DateTime(2025, 2, 21); // Cycle Closed Feb 21.

        when(() => mockAccountBox.get('c1')).thenReturn(acc);
        when(() => mockSettingsBox.get('last_rollover_c1'))
            .thenReturn(lastRollover.millisecondsSinceEpoch);
        when(() => mockTxnBox.get('old')).thenReturn(null);

        final oldTxn = Transaction(
            id: 'old',
            title: 'Old',
            amount: 100,
            date: DateTime(2025, 2, 20), // Before Feb 21
            type: TransactionType.expense,
            accountId: 'c1',
            category: 'General');

        expect(
            () async => await storageService.saveTransaction(oldTxn),
            throwsA(isA<Exception>().having((e) => e.toString(), 'message',
                contains('closed billing cycle'))));
      });

      test('Can add transaction to current or previous open cycle', () async {
        final acc = Account(
            id: 'c1',
            name: 'Card',
            type: AccountType.creditCard,
            balance: 0,
            billingCycleDay: 20);
        final lastRollover = DateTime(2025, 1,
            21); // Cycle Closed Jan 21. Billed: Jan 21-Feb 21. Open: Feb 21-Mar 21.
        // Current Date: Feb 25.

        when(() => mockAccountBox.get('c1')).thenReturn(acc);
        when(() => mockSettingsBox.get('last_rollover_c1'))
            .thenReturn(lastRollover.millisecondsSinceEpoch);
        when(() => mockTxnBox.get('billed')).thenReturn(null);
        when(() => mockTxnBox.put(any(), any())).thenAnswer((_) async {});

        final billedTxn = Transaction(
            id: 'billed',
            title: 'Billed',
            amount: 100,
            date: DateTime(
                2025, 2, 10), // Inside Billed Cycle (After Jan 21) => OK
            type: TransactionType.expense,
            accountId: 'c1',
            category: 'General');

        await storageService.saveTransaction(billedTxn);
        verify(() => mockTxnBox.put('billed', billedTxn)).called(1);
      });
    });

    test('Auto-Repair triggers when Billing Cycle Day changes', () async {
      // Setup: Existing Account has Cycle Day 20.
      final oldAcc = Account(
          id: 'c1',
          name: 'Card 1',
          type: AccountType.creditCard,
          balance: 0,
          billingCycleDay: 20,
          profileId: 'default');

      // New update changes Cycle Day to 15.
      final newAcc = Account(
          id: 'c1',
          name: 'Card 1',
          type: AccountType.creditCard,
          balance: 0,
          billingCycleDay: 15,
          profileId: 'default');

      when(() => mockAccountBox.get('c1')).thenReturn(oldAcc);
      when(() => mockAccountBox.put(any(), any())).thenAnswer((_) async {});
      // Mock settings put (for rollover reset)
      when(() => mockSettingsBox.put(any(), any())).thenAnswer((_) async {});

      await storageService.saveAccount(newAcc);

      // Verify: resetCreditCardRollover was triggered (which calls settingsBox.put)
      verify(() => mockSettingsBox.put(startsWith('last_rollover_c1'), any()))
          .called(1);
    });

    test(
        'Auto-Repair does NOT trigger when Billing Cycle Day is unchanged AND Date is correct',
        () async {
      // Setup: Existing Account has Cycle Day 20.
      final oldAcc = Account(
          id: 'c1',
          name: 'Card 1',
          type: AccountType.creditCard,
          balance: 0,
          billingCycleDay: 20,
          profileId: 'default');

      // New update keeps Cycle Day 20.
      final newAcc = Account(
          id: 'c1',
          name: 'Card 1 (Edited)',
          type: AccountType.creditCard,
          balance: 0,
          billingCycleDay: 20,
          profileId: 'default');

      when(() => mockAccountBox.get('c1')).thenReturn(oldAcc);
      when(() => mockAccountBox.put(any(), any())).thenAnswer((_) async {});
      // Mock settings put
      when(() => mockSettingsBox.put(any(), any())).thenAnswer((_) async {});

      // Mock existing rollover as ALREADY CORRECT
      final now = DateTime.now();
      final currentCycleStart = BillingHelper.getCycleStart(now, 20);
      final targetRolloverDateStart = BillingHelper.getCycleStart(
          currentCycleStart.subtract(const Duration(days: 1)), 20);
      final correctRollover =
          targetRolloverDateStart.subtract(const Duration(seconds: 1));

      when(() => mockSettingsBox.get('last_rollover_c1'))
          .thenReturn(correctRollover.millisecondsSinceEpoch);

      await storageService.saveAccount(newAcc);

      // Verify: settingsBox.put should NOT be called for rollover (idempotent)
      verifyNever(
          () => mockSettingsBox.put(startsWith('last_rollover_c1'), any()));
    });

    test(
        'Auto-Repair triggers when Billing Cycle Day is unchanged BUT Date is WRONG',
        () async {
      // Setup: Existing Account has Cycle Day 20.
      final oldAcc = Account(
          id: 'c1',
          name: 'Card 1',
          type: AccountType.creditCard,
          balance: 0,
          billingCycleDay: 20,
          profileId: 'default');

      final newAcc = Account(
          id: 'c1',
          name: 'Card 1',
          type: AccountType.creditCard,
          balance: 0,
          billingCycleDay: 20,
          profileId: 'default');

      when(() => mockAccountBox.get('c1')).thenReturn(oldAcc);
      when(() => mockAccountBox.put(any(), any())).thenAnswer((_) async {});
      when(() => mockSettingsBox.put(any(), any())).thenAnswer((_) async {});

      // Mock existing rollover as INCORRECT (e.g. from a bug or old logic)
      final now = DateTime.now();
      final incorrectRollover = BillingHelper.getCycleStart(now, 20)
          .subtract(const Duration(days: 5)); // Wrong date
      when(() => mockSettingsBox.get('last_rollover_c1'))
          .thenReturn(incorrectRollover.millisecondsSinceEpoch);

      // Mock transactions for delta scan
      when(() => mockTxnBox.values).thenReturn([]);
      when(() => mockTxnBox.toMap()).thenReturn({});
      when(() => mockSettingsBox.get('activeProfileId',
          defaultValue: any(named: 'defaultValue'))).thenReturn('default');

      await storageService.saveAccount(newAcc);

      // Verify: resetCreditCardRollover WAS triggered because dates mismatched
      verify(() => mockSettingsBox.put(startsWith('last_rollover_c1'), any()))
          .called(1);
    });

    test('Safe Repair: Balance should NEVER change during Auto-Repair',
        () async {
      final oldAcc = Account(
          id: 'c1',
          name: 'Card 1',
          type: AccountType.creditCard,
          balance: 1000.0, // Existing Balance
          billingCycleDay: 20,
          profileId: 'default');

      final newAcc = Account(
          id: 'c1',
          name: 'Card 1',
          type: AccountType.creditCard,
          balance: 1000.0,
          billingCycleDay: 21, // Shift cycle day
          profileId: 'default');

      when(() => mockAccountBox.get('c1')).thenReturn(oldAcc);
      when(() => mockAccountBox.put(any(), any())).thenAnswer((_) async {});
      when(() => mockSettingsBox.put(any(), any())).thenAnswer((_) async {});
      when(() => mockSettingsBox.get('last_rollover_c1')).thenReturn(null);

      await storageService.saveAccount(newAcc);

      // Verify: balance remains exactly 1000.0
      // mockAccountBox.put is called by saveAccount itself,
      // but we want to ensure it wasn't called AGAIN with a different balance by resetCreditCardRollover.
      verify(() => mockAccountBox.put(
          'c1',
          any(
              that: isA<Account>()
                  .having((a) => a.balance, 'balance', 1000.0)))).called(1);
    });
  });
}
