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

    registerFallbackValue(Account(
        id: 'fallback', name: 'f', type: AccountType.creditCard, balance: 0));
    registerFallbackValue(Transaction(
        id: 'param',
        title: 't',
        amount: 0,
        date: DateTime.now(),
        type: TransactionType.expense,
        category: 'General'));

    when(() => mockHive.box<Account>(any())).thenReturn(mockAccountBox);
    when(() => mockHive.box<Transaction>(any())).thenReturn(mockTxnBox);
    when(() => mockHive.box(any())).thenReturn(mockSettingsBox);

    // Default settings - explicit mocks to avoid type errors
    when(() => mockSettingsBox.get('txnsSinceBackup',
        defaultValue: any(named: 'defaultValue'))).thenReturn(0);
    when(() => mockSettingsBox.get(
        any(that: startsWith('ignore_rollover_payments')),
        defaultValue: any(named: 'defaultValue'))).thenReturn(false);
    when(() => mockSettingsBox.get(any(),
            defaultValue: any(named: 'defaultValue')))
        .thenAnswer((invocation) => invocation.namedArguments[#defaultValue]);
    when(() => mockSettingsBox.get('activeProfileId',
        defaultValue: any(named: 'defaultValue'))).thenReturn('default');

    when(() => mockSettingsBox.put(any(), any())).thenAnswer((_) async {});
    when(() => mockAccountBox.put(any(), any())).thenAnswer((_) async {});
    when(() => mockTxnBox.put(any(), any())).thenAnswer((_) async {});
    // Fix: Allow validation to pass by default (no last rollover set)
    when(() => mockSettingsBox.get(any(that: startsWith('last_rollover_')),
        defaultValue: any(named: 'defaultValue'))).thenReturn(null);
    // Fix: txnsSinceBackup
    when(() => mockSettingsBox.get('txnsSinceBackup',
        defaultValue: any(named: 'defaultValue'))).thenReturn(0);

    storageService = StorageService(mockHive);
    when(() => mockHive.isBoxOpen(any())).thenReturn(true);
  });

  group('Simplified Billing Logic', () {
    test('initRolloverForImport skips history (sets to current cycle start)',
        () async {
      await storageService.initRolloverForImport('acc1', 20);

      // Current Logic: Rollover is set to (CycleStart - 1 second) to maintain inclusive start.
      final cycleStart = BillingHelper.getCycleStart(DateTime.now(), 20);
      final expectedDate = cycleStart.subtract(const Duration(seconds: 1));

      verify(() => mockSettingsBox.put(
          'last_rollover_acc1', expectedDate.millisecondsSinceEpoch)).called(1);
    });

    test('Payments are APPLIED immediately (Not Unbilled)', () async {
      // Setup Account
      final acc = Account(
          id: 'c1',
          name: 'Card',
          type: AccountType.creditCard,
          balance: 0,
          billingCycleDay: 20,
          profileId: 'default');
      when(() => mockAccountBox.get('c1')).thenReturn(acc);
      when(() => mockTxnBox.get(any())).thenReturn(null);

      // Payment Txn (Transfer IN)
      final payment = Transaction(
          id: 'p1',
          title: 'Pay',
          amount: 1000,
          date: DateTime.now(),
          type: TransactionType.transfer,
          toAccountId: 'c1', // Target is CC
          accountId: 'bank',
          category: 'Test',
          profileId: 'default');

      await storageService.saveTransaction(payment);
      // Under Waterfall model, payments ALWAYS update balance immediately.
      expect(acc.balance, -1000.0);
    });

    test('Spends are UNBILLED (Balance unchanged)', () async {
      // Setup Account
      final acc = Account(
          id: 'c1',
          name: 'Card',
          type: AccountType.creditCard,
          balance: 0,
          billingCycleDay: 20,
          profileId: 'default');
      when(() => mockAccountBox.get('c1')).thenReturn(acc);
      when(() => mockTxnBox.get(any())).thenReturn(null);

      // Spend Txn
      final spend = Transaction(
          id: 's1',
          title: 'Spend',
          amount: 500,
          date: DateTime.now(),
          type: TransactionType.expense,
          accountId: 'c1',
          category: 'General',
          profileId: 'default');

      await storageService.saveTransaction(spend);
      expect(acc.balance, 0.0);
    });

    test('Rollover aggregates Spends but IGNORES Payments (already applied)',
        () async {
      // Setup
      // Need TWO month lag for rollover to trigger under new "Lagged" logic.
      final acc = Account(
          id: 'c1',
          name: 'Card',
          type: AccountType.creditCard,
          balance: -1000.0,
          billingCycleDay: 20,
          profileId: 'default');

      // Last Rollover: Dec 21, 2024.
      final lastRollover = DateTime(2024, 12, 21);

      when(() => mockSettingsBox.get('last_rollover_c1'))
          .thenReturn(lastRollover.millisecondsSinceEpoch);
      when(() => mockAccountBox.toMap()).thenReturn({'c1': acc});

      // Transactions in (Dec 21, Jan 21]
      final spend = Transaction(
          id: 's1',
          title: 'Spend',
          amount: 500,
          date: DateTime(2025, 1, 10),
          type: TransactionType.expense,
          accountId: 'c1',
          category: 'General',
          profileId: 'default');
      final payment = Transaction(
          id: 'p1',
          title: 'Pay',
          amount: 200,
          date: DateTime(2025, 1, 15),
          type: TransactionType.transfer,
          toAccountId: 'c1',
          accountId: 'bank',
          category: 'General',
          profileId: 'default');

      final transferOut = Transaction(
          id: 't1',
          title: 'Transfer Out',
          accountId: 'c1',
          toAccountId: 'bank',
          amount: 150,
          date: DateTime(2025, 1, 15),
          type: TransactionType.transfer,
          category: 'Transfer',
          profileId: 'default');

      final income = Transaction(
          id: 'i1',
          title: 'Income',
          accountId: 'c1',
          amount: 50,
          date: DateTime(2025, 1, 16),
          type: TransactionType.income,
          category: 'Refund',
          profileId: 'default');

      // Setup Box with Map<dynamic, Transaction>
      final txns = {
        's1': spend,
        'p1': payment,
        't1': transferOut,
        'i1': income
      };
      when(() => mockTxnBox.toMap())
          .thenReturn(Map<dynamic, Transaction>.from(txns));

      // Execute Rollover Check for Feb 21, 2025
      // Current Cycle Start: Feb 21. Target: Jan 21.
      // Dec 21 < Jan 21. So Rollover happens.
      await storageService.checkCreditCardRollovers(
          nowOverride: DateTime(2025, 2, 21));

      // Verify Logic
      // Initial Balance: -1000.
      // Spend: 500. (Expense). Adds to Debt.
      // TransferOut: 150. (Outgoing Transfer). Adds to Debt.
      // Income: 50. (Income). Subtracts from Debt.
      // Payment: 200. (Ignored by rollover loop - counts as Credit in Waterfall).
      // New Balance = -1000 + (500 + 150 - 50 - 200) = -1000 + 400 = -600.

      final capturedAcc = verify(() => mockAccountBox.put('c1', captureAny()))
          .captured
          .first as Account;
      // Initial: -1000. Billed Spend (s1: 500, t1: 150) = 650.
      // Income (i1) and Payments (p1) hit balance immediately so they are NOT in billedSpend.
      // New Balance = -1000 + 650 = -350.0
      expect(capturedAcc.balance, -350.0);
    });

    test('Scenario 1: Update on March 23, Day 22 -> Day 1 triggers on April 2',
        () async {
      final freezeDate = DateTime(2026, 3, 23);
      final acc = Account(
          id: 's1',
          name: 'S1',
          type: AccountType.creditCard,
          balance: 0,
          billingCycleDay: 1,
          isFrozen: true,
          isFrozenCalculated: false,
          freezeDate: freezeDate,
          profileId: 'default');

      when(() => mockSettingsBox.get('last_rollover_s1'))
          .thenReturn(freezeDate.millisecondsSinceEpoch);
      when(() => mockAccountBox.toMap()).thenReturn({'s1': acc});
      when(() => mockTxnBox.toMap()).thenReturn({});

      // April 1st check: Should NOT trigger (now is April 1, but effectiveTarget is April 1 23:59:59)
      await storageService.checkCreditCardRollovers(
          nowOverride: DateTime(2026, 4, 1));
      verifyNever(() => mockAccountBox.put('s1', any()));

      // April 2nd check: Should trigger Phase 1
      await storageService.checkCreditCardRollovers(
          nowOverride: DateTime(2026, 4, 2));

      final phase1Acc = verify(() => mockAccountBox.put('s1', captureAny()))
          .captured
          .first as Account;
      expect(phase1Acc.isFrozenCalculated, true);
      expect(phase1Acc.isFrozen, true); // Still frozen
    });

    test(
        'Scenario 2: Update on March 15, Day 22 -> Day 1 (Old Day 22 is skipped)',
        () async {
      final freezeDate = DateTime(2026, 3, 15);
      final acc = Account(
          id: 's2',
          name: 'S2',
          type: AccountType.creditCard,
          balance: 0,
          billingCycleDay: 1,
          isFrozen: true,
          isFrozenCalculated: false,
          freezeDate: freezeDate,
          profileId: 'default');

      when(() => mockSettingsBox.get('last_rollover_s2'))
          .thenReturn(freezeDate.millisecondsSinceEpoch);
      when(() => mockAccountBox.toMap()).thenReturn({'s2': acc});
      when(() => mockTxnBox.toMap()).thenReturn({});

      // March 22 check: Should SKIP (day is now 1)
      await storageService.checkCreditCardRollovers(
          nowOverride: DateTime(2026, 3, 22));
      verifyNever(() => mockAccountBox.put('s2', any()));

      // April 2 check: Should Trigger Phase 1
      await storageService.checkCreditCardRollovers(
          nowOverride: DateTime(2026, 4, 2));
      verify(() => mockAccountBox.put('s2', any())).called(1);
    });

    test('Scenario 3: Phase 2 Realization (Unpaid Transition Gap)', () async {
      final freezeDate = DateTime(2026, 3, 23);
      // SETUP: We are already in Phase 2 state (isFrozenCalculated is true)
      // Phase 1 moved the pointer to April 1st.
      final lastRollover = DateTime(2026, 4, 1, 23, 59, 59);

      final acc = Account(
          id: 's3',
          name: 'S3',
          type: AccountType.creditCard,
          balance: 0,
          billingCycleDay: 1,
          isFrozen: true,
          isFrozenCalculated: true,
          freezeDate: freezeDate,
          profileId: 'default');

      when(() => mockSettingsBox.get('last_rollover_s3'))
          .thenReturn(lastRollover.millisecondsSinceEpoch);
      when(() => mockAccountBox.toMap()).thenReturn({'s3': acc});

      // Spends: $500 (Transition Period), $200 (April Regular Cycle)
      final txns = {
        't1': Transaction(
            id: 't1',
            title: 'Transition',
            amount: 500,
            date: DateTime(2026, 3, 25),
            type: TransactionType.expense,
            accountId: 's3',
            category: 'T',
            profileId: 'default'),
        't2': Transaction(
            id: 't2',
            title: 'April Regular',
            amount: 200,
            date: DateTime(2026, 4, 10),
            type: TransactionType.expense,
            accountId: 's3',
            category: 'T',
            profileId: 'default'),
      };
      when(() => mockTxnBox.toMap())
          .thenReturn(Map<dynamic, Transaction>.from(txns));

      // Execute Rollover on May 2nd (Should trigger Phase 2)
      await storageService.checkCreditCardRollovers(
          nowOverride: DateTime(2026, 5, 2));

      final finalAcc = verify(() => mockAccountBox.put('s3', captureAny()))
          .captured
          .first as Account;

      // ASSERT: ONLY Transition spend ($500) realized.
      // Reset flags.
      expect(finalAcc.balance, 500.0);
      expect(finalAcc.isFrozen, false);
      expect(finalAcc.freezeDate, null);

      // ASSERT: April spend ($200) is still in the "Billed" bucket
      // (Verified using BillingHelper logic)
      final billed = BillingHelper.calculateBilledAmount(
          finalAcc,
          txns.values.toList(),
          DateTime(2026, 5, 2),
          lastRollover.millisecondsSinceEpoch);
      expect(billed, 200.0);
    });

    test('Scenario 4: Phase 2 Realization (Paid Transition Gap)', () async {
      final freezeDate = DateTime(2026, 3, 23);
      final lastRollover = DateTime(2026, 4, 1, 23, 59, 59);

      // Setup Account with 500 debt, but then apply -500 payment impact
      final acc = Account(
          id: 's4',
          name: 'S4',
          type: AccountType.creditCard,
          balance: -500, // Pre-paid
          billingCycleDay: 1,
          isFrozen: true,
          isFrozenCalculated: true,
          freezeDate: freezeDate,
          profileId: 'default');

      when(() => mockSettingsBox.get('last_rollover_s4'))
          .thenReturn(lastRollover.millisecondsSinceEpoch);
      when(() => mockAccountBox.toMap()).thenReturn({'s4': acc});

      final txns = {
        't1': Transaction(
            id: 't1',
            title: 'Transition Spend',
            amount: 500,
            date: DateTime(2026, 3, 25),
            type: TransactionType.expense,
            accountId: 's4',
            category: 'T',
            profileId: 'default'),
        't2': Transaction(
            id: 't2',
            title: 'April Regular',
            amount: 300,
            date: DateTime(2026, 4, 10),
            type: TransactionType.expense,
            accountId: 's4',
            category: 'T',
            profileId: 'default'),
      };
      when(() => mockTxnBox.toMap())
          .thenReturn(Map<dynamic, Transaction>.from(txns));

      // Execute Rollover on May 2nd
      await storageService.checkCreditCardRollovers(
          nowOverride: DateTime(2026, 5, 2));

      final finalAcc = verify(() => mockAccountBox.put('s4', captureAny()))
          .captured
          .first as Account;

      // ASSERT: -500 (balance) + 500 (realized) = 0.
      expect(finalAcc.balance, 0.0);
      expect(finalAcc.isFrozen, false);
      expect(finalAcc.isFrozenCalculated, false);
      expect(finalAcc.freezeDate, null);

      // ASSERT: Next cycle spend ($300) preserved in Billed bucket
      final billed = BillingHelper.calculateBilledAmount(
          finalAcc,
          txns.values.toList(),
          DateTime(2026, 5, 2),
          lastRollover.millisecondsSinceEpoch);
      expect(billed, 300.0);
    });

    test('Scenario 5: Negative Balance Standard Rollover (Overpaid)', () async {
      // Set lastRollover to Feb 1st. On April 2nd, the system will try to roll over
      // the cycle ending Feb 28th.
      final lastRollover = DateTime(2026, 2, 1, 23, 59, 59);
      final acc = Account(
          id: 's5',
          name: 'S5',
          type: AccountType.creditCard,
          balance: -500, // Overpaid by 500
          billingCycleDay: 1,
          profileId: 'default');

      when(() => mockSettingsBox.get('last_rollover_s5'))
          .thenReturn(lastRollover.millisecondsSinceEpoch);
      when(() => mockAccountBox.toMap()).thenReturn({'s5': acc});

      final txns = {
        't1': Transaction(
            id: 't1',
            title: 'Feb Spend',
            amount: 200,
            date: DateTime(2026, 2, 10), // In the Feb cycle window
            type: TransactionType.expense,
            accountId: 's5',
            category: 'T',
            profileId: 'default'),
      };
      when(() => mockTxnBox.toMap())
          .thenReturn(Map<dynamic, Transaction>.from(txns));

      // Execute Rollover on April 2nd
      await storageService.checkCreditCardRollovers(
          nowOverride: DateTime(2026, 4, 2));

      final finalAcc = verify(() => mockAccountBox.put('s5', captureAny()))
          .captured
          .first as Account;

      // ASSERT: -500 (balance) + 200 (spend) = -300.
      expect(finalAcc.balance, -300.0);
      // Verify pointer advanced
      verify(() => mockSettingsBox.put('last_rollover_s5',
          any(that: isNot(lastRollover.millisecondsSinceEpoch)))).called(1);
    });

    test('Scenario 6: Phase 1 with 0 spends during transition window',
        () async {
      final freezeDate = DateTime(2026, 3, 23);
      final lastRollover = DateTime(2026, 3, 1, 23, 59, 59);
      final acc = Account(
          id: 's6',
          name: 'S6',
          type: AccountType.creditCard,
          balance: 0,
          billingCycleDay: 1, // Updating to 1st
          isFrozen: true,
          freezeDate: freezeDate,
          profileId: 'default');

      when(() => mockSettingsBox.get('last_rollover_s6'))
          .thenReturn(lastRollover.millisecondsSinceEpoch);
      when(() => mockAccountBox.toMap()).thenReturn({'s6': acc});

      // No transactions in the window (Mar 23 - Mar 31)
      final txns = {
        't1': Transaction(
            id: 't1',
            title: 'Old Spend',
            amount: 100,
            date: DateTime(2026, 3, 10), // Before freeze
            type: TransactionType.expense,
            accountId: 's6',
            category: 'T',
            profileId: 'default'),
      };
      when(() => mockTxnBox.toMap())
          .thenReturn(Map<dynamic, Transaction>.from(txns));

      // Execute Rollover on April 2nd (Phase 1 trigger)
      await storageService.checkCreditCardRollovers(
          nowOverride: DateTime(2026, 4, 2));

      final finalAcc = verify(() => mockAccountBox.put('s6', captureAny()))
          .captured
          .first as Account;

      // ASSERT: isFrozenCalculated set to true (Transition debt is 0, but Phase 1 must finish)
      expect(finalAcc.isFrozenCalculated, true);
      expect(finalAcc.balance, 0.0); // Balance unchanged till Phase 2
    });

    test('Scenario 7: Phase 2 with negative transition gap debt (Overpaid)',
        () async {
      final freezeDate = DateTime(2026, 3, 23);
      final lastRollover = DateTime(2026, 4, 1, 23, 59, 59);

      // Setup Account with -500 balance (reflecting the $500 payment that hit immediately)
      final acc = Account(
          id: 's7',
          name: 'S7',
          type: AccountType.creditCard,
          balance: -500, // Payment hit balance immediately upon being saved
          billingCycleDay: 1,
          isFrozen: true,
          isFrozenCalculated: true,
          freezeDate: freezeDate,
          profileId: 'default');

      when(() => mockSettingsBox.get('last_rollover_s7'))
          .thenReturn(lastRollover.millisecondsSinceEpoch);
      when(() => mockAccountBox.toMap()).thenReturn({'s7': acc});

      final txns = {
        't1': Transaction(
            id: 't1',
            title: 'Gap Payment',
            amount: 500,
            date: DateTime(2026, 3, 25),
            type: TransactionType.income, // Payment
            accountId: 's7',
            category: 'P',
            profileId: 'default'),
        't2': Transaction(
            id: 't2',
            title: 'Gap Spend',
            amount: 200,
            date: DateTime(2026, 3, 26),
            type: TransactionType.expense,
            accountId: 's7',
            category: 'S',
            profileId: 'default'),
      };
      when(() => mockTxnBox.toMap())
          .thenReturn(Map<dynamic, Transaction>.from(txns));

      // Execute Rollover on May 2nd (Phase 2 trigger)
      await storageService.checkCreditCardRollovers(
          nowOverride: DateTime(2026, 5, 2));

      final finalAcc = verify(() => mockAccountBox.put('s7', captureAny()))
          .captured
          .first as Account;

      // ASSERT: Balance starts at -500. Realization shifts 200 spends.
      // Final balance = -500 + 200 = -300.
      expect(finalAcc.balance, -300.0);
      expect(finalAcc.isFrozen, false);
      expect(finalAcc.freezeDate, null);
    });

    test(
        'Scenario 8: Phase 2 with 0 transition gap but active new cycle spends',
        () async {
      final freezeDate = DateTime(2026, 3, 23);
      final lastRollover = DateTime(2026, 4, 1, 23, 59, 59);

      final acc = Account(
          id: 's8',
          name: 'S8',
          type: AccountType.creditCard,
          balance: 100,
          billingCycleDay: 1,
          isFrozen: true,
          isFrozenCalculated: true,
          freezeDate: freezeDate,
          profileId: 'default');

      when(() => mockSettingsBox.get('last_rollover_s8'))
          .thenReturn(lastRollover.millisecondsSinceEpoch);
      when(() => mockAccountBox.toMap()).thenReturn({'s8': acc});

      final txns = {
        't1': Transaction(
            id: 't1',
            title: 'New Cycle Spend',
            amount: 300,
            date: DateTime(2026, 4, 10), // AFTER Phase 1 pointer
            type: TransactionType.expense,
            accountId: 's8',
            category: 'S',
            profileId: 'default'),
      };
      when(() => mockTxnBox.toMap())
          .thenReturn(Map<dynamic, Transaction>.from(txns));

      // Execute Rollover on May 2nd
      await storageService.checkCreditCardRollovers(
          nowOverride: DateTime(2026, 5, 2));

      final finalAcc = verify(() => mockAccountBox.put('s8', captureAny()))
          .captured
          .first as Account;

      // ASSERT: Transition debt was 0. Balance stays 100.
      expect(finalAcc.balance, 100.0);
      expect(finalAcc.isFrozen, false);

      // ASSERT: New spend (300) is in billed bucket
      final billed = BillingHelper.calculateBilledAmount(
          finalAcc,
          txns.values.toList(),
          DateTime(2026, 5, 2),
          lastRollover.millisecondsSinceEpoch);
      expect(billed, 300.0);
    });

    test(
        'Scenario 9: Phase 2 where transition debt is exactly 0 after payments',
        () async {
      final freezeDate = DateTime(2026, 3, 23);
      final lastRollover = DateTime(2026, 4, 1, 23, 59, 59);

      // Setup Account with -500 balance (reflecting the $500 payment)
      final acc = Account(
          id: 's9',
          name: 'S9',
          type: AccountType.creditCard,
          balance: -500, // Payment hit already
          billingCycleDay: 1,
          isFrozen: true,
          isFrozenCalculated: true,
          freezeDate: freezeDate,
          profileId: 'default');

      when(() => mockSettingsBox.get('last_rollover_s9'))
          .thenReturn(lastRollover.millisecondsSinceEpoch);
      when(() => mockAccountBox.toMap()).thenReturn({'s9': acc});

      final txns = {
        't1': Transaction(
            id: 't1',
            title: 'Gap Spend',
            amount: 500,
            date: DateTime(2026, 3, 25),
            type: TransactionType.expense,
            accountId: 's9',
            category: 'S',
            profileId: 'default'),
        't2': Transaction(
            id: 't2',
            title: 'Gap Payment',
            amount: 500,
            date: DateTime(2026, 3, 26),
            type: TransactionType.income,
            accountId: 's9',
            category: 'P',
            profileId: 'default'),
      };
      when(() => mockTxnBox.toMap())
          .thenReturn(Map<dynamic, Transaction>.from(txns));

      // Execute Rollover on May 2nd
      await storageService.checkCreditCardRollovers(
          nowOverride: DateTime(2026, 5, 2));

      final finalAcc = verify(() => mockAccountBox.put('s9', captureAny()))
          .captured
          .first as Account;

      // ASSERT: Balance starts at -500. Realization shifts 500 spends.
      // Final balance = -500 + 500 = 0.
      expect(finalAcc.balance, 0.0);
      expect(finalAcc.isFrozen, false);
      expect(finalAcc.freezeDate, null);
    });
  });
}
