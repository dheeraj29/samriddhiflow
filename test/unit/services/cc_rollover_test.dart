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
    when(() => mockSettingsBox.get(any(), defaultValue: null)).thenReturn(null);

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
          billingCycleDay: 20);
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
          category: 'Test');

      await storageService.saveTransaction(payment);
      expect(acc.balance, -1000.0);
    });

    test('Spends are UNBILLED (Balance unchanged)', () async {
      // Setup Account
      final acc = Account(
          id: 'c1',
          name: 'Card',
          type: AccountType.creditCard,
          balance: 0,
          billingCycleDay: 20);
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
          category: 'General');

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
          billingCycleDay: 20);

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
          category: 'General');
      final payment = Transaction(
          id: 'p1',
          title: 'Pay',
          amount: 200,
          date: DateTime(2025, 1, 15),
          type: TransactionType.transfer,
          toAccountId: 'c1',
          accountId: 'bank',
          category: 'General');

      // Setup Box with Map<dynamic, Transaction>
      final txns = {'s1': spend, 'p1': payment};
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
      // Payment: 200. (Ignored by rollover loop).
      // New Balance = -1000 + 500 = -500.

      final capturedAcc = verify(() => mockAccountBox.put('c1', captureAny()))
          .captured
          .first as Account;
      expect(capturedAcc.balance, -500.0);
    });
  });
}
