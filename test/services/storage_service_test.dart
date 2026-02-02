import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:hive_ce/hive.dart';
import 'package:samriddhi_flow/services/storage_service.dart';
import 'package:samriddhi_flow/models/account.dart';
import 'package:samriddhi_flow/models/profile.dart';
import 'package:samriddhi_flow/models/transaction.dart';
import 'package:samriddhi_flow/models/loan.dart';
import 'package:samriddhi_flow/models/recurring_transaction.dart';
import 'package:samriddhi_flow/models/category.dart';

import 'package:flutter/services.dart';

class MockHiveInterface extends Mock implements HiveInterface {}

class MockBox<T> extends Mock implements Box<T> {}

class MockAssetBundle extends Mock implements AssetBundle {}

class AccountFake extends Fake implements Account {}

class ProfileFake extends Fake implements Profile {}

class TransactionFake extends Fake implements Transaction {}

class LoanFake extends Fake implements Loan {}

class RecurringTransactionFake extends Fake implements RecurringTransaction {}

class CategoryFake extends Fake implements Category {}

void main() {
  setUpAll(() {
    registerFallbackValue(AccountFake());
    registerFallbackValue(ProfileFake());
    registerFallbackValue(TransactionFake());
    registerFallbackValue(LoanFake());
    registerFallbackValue(RecurringTransactionFake());
    registerFallbackValue(CategoryFake());
  });

  late StorageService storageService;
  late MockHiveInterface mockHive;
  late MockAssetBundle mockBundle;
  late MockBox<Account> mockAccountBox;
  late MockBox<Profile> mockProfileBox;
  late MockBox<Transaction> mockTransactionBox;
  late MockBox<Loan> mockLoanBox;
  late MockBox<RecurringTransaction> mockRecurringBox;
  late MockBox<Category> mockCategoryBox;
  late MockBox<dynamic> mockSettingsBox;

  setUp(() {
    mockHive = MockHiveInterface();
    mockBundle = MockAssetBundle();
    mockAccountBox = MockBox<Account>();
    mockProfileBox = MockBox<Profile>();
    mockTransactionBox = MockBox<Transaction>();
    mockLoanBox = MockBox<Loan>();
    mockRecurringBox = MockBox<RecurringTransaction>();
    mockCategoryBox = MockBox<Category>();
    mockSettingsBox = MockBox<dynamic>();

    // Mock bundle response with minimal valid JSON
    when(() => mockBundle.loadString(any())).thenAnswer((_) async => '''
      [
        {
          "name": "Salary",
          "usage": "income",
          "tag": "directTax",
          "iconCode": 60271
        }
      ]
    ''');

    storageService = StorageService(mockHive, mockBundle);

    // Default behavior for boxes
    // Explicit behavior for each mock box to avoid generic type issues in loops
    when(() => mockAccountBox.put(any(), any())).thenAnswer((_) async => {});
    when(() => mockAccountBox.delete(any())).thenAnswer((_) async => {});

    when(() => mockProfileBox.put(any(), any())).thenAnswer((_) async => {});
    when(() => mockProfileBox.delete(any())).thenAnswer((_) async => {});

    when(() => mockTransactionBox.put(any(), any()))
        .thenAnswer((_) async => {});
    when(() => mockTransactionBox.delete(any())).thenAnswer((_) async => {});

    when(() => mockLoanBox.put(any(), any())).thenAnswer((_) async => {});
    when(() => mockLoanBox.delete(any())).thenAnswer((_) async => {});

    when(() => mockRecurringBox.put(any(), any())).thenAnswer((_) async => {});
    when(() => mockRecurringBox.delete(any())).thenAnswer((_) async => {});

    when(() => mockCategoryBox.put(any(), any())).thenAnswer((_) async => {});
    when(() => mockCategoryBox.delete(any())).thenAnswer((_) async => {});

    when(() => mockSettingsBox.put(any(), any())).thenAnswer((_) async => {});
    when(() => mockSettingsBox.delete(any())).thenAnswer((_) async => {});

    when(() => mockHive.box<Account>(any())).thenReturn(mockAccountBox);
    when(() => mockHive.box<Profile>(any())).thenReturn(mockProfileBox);
    when(() => mockHive.box<Transaction>(any())).thenReturn(mockTransactionBox);
    when(() => mockHive.box<Loan>(any())).thenReturn(mockLoanBox);
    when(() => mockHive.box<RecurringTransaction>(any()))
        .thenReturn(mockRecurringBox);
    when(() => mockHive.box<Category>(any())).thenReturn(mockCategoryBox);
    when(() => mockHive.box(StorageService.boxSettings))
        .thenReturn(mockSettingsBox);

    // Default active profile
    when(() => mockSettingsBox.get('activeProfileId',
        defaultValue: any(named: 'defaultValue'))).thenReturn('default');
    when(() => mockSettingsBox.get('holidays',
        defaultValue: any(named: 'defaultValue'))).thenReturn([]);
  });

  group('StorageService - Initialization', () {
    test('init opens all required boxes', () async {
      when(() => mockHive.isBoxOpen(any())).thenReturn(false);
      when(() => mockHive.openBox<Account>(any()))
          .thenAnswer((_) async => mockAccountBox);
      when(() => mockHive.openBox<Transaction>(any()))
          .thenAnswer((_) async => mockTransactionBox);
      when(() => mockHive.openBox<Loan>(any()))
          .thenAnswer((_) async => mockLoanBox);
      when(() => mockHive.openBox<RecurringTransaction>(any()))
          .thenAnswer((_) async => mockRecurringBox);
      when(() => mockHive.openBox(StorageService.boxSettings))
          .thenAnswer((_) async => mockSettingsBox);
      when(() => mockHive.openBox<Profile>(any()))
          .thenAnswer((_) async => mockProfileBox);
      when(() => mockHive.openBox<Category>(any()))
          .thenAnswer((_) async => mockCategoryBox);

      when(() => mockProfileBox.isEmpty).thenReturn(true);
      when(() => mockProfileBox.put(any(), any())).thenAnswer((_) async => {});
      when(() => mockCategoryBox.isEmpty).thenReturn(true);
      when(() => mockSettingsBox.get('categories_v2')).thenReturn(null);
      when(() => mockCategoryBox.put(any(), any())).thenAnswer((_) async => {});

      await storageService.init();

      verify(() => mockHive.openBox<Account>(StorageService.boxAccounts))
          .called(1);
      verify(() =>
              mockHive.openBox<Transaction>(StorageService.boxTransactions))
          .called(1);
      verify(() => mockHive.openBox<Loan>(StorageService.boxLoans)).called(1);
      verify(() => mockHive.openBox<RecurringTransaction>(
          StorageService.boxRecurring)).called(1);
      verify(() => mockHive.openBox(StorageService.boxSettings)).called(1);
      verify(() => mockHive.openBox<Profile>(StorageService.boxProfiles))
          .called(1);
      verify(() => mockHive.openBox<Category>(StorageService.boxCategories))
          .called(1);
    });
  });

  group('StorageService - Profile Operations', () {
    test('getActiveProfileId returns correct value', () {
      when(() =>
              mockSettingsBox.get('activeProfileId', defaultValue: 'default'))
          .thenReturn('user123');
      expect(storageService.getActiveProfileId(), 'user123');
    });

    test('setActiveProfileId saves to settings box', () async {
      when(() => mockSettingsBox.put(any(), any())).thenAnswer((_) async => {});
      await storageService.setActiveProfileId('new-profile');
      verify(() => mockSettingsBox.put('activeProfileId', 'new-profile'))
          .called(1);
    });

    test('getProfiles returns list of profiles', () {
      final profiles = [
        Profile(id: '1', name: 'P1'),
        Profile(id: '2', name: 'P2')
      ];
      when(() => mockProfileBox.values).thenReturn(profiles);

      final result = storageService.getProfiles();
      expect(result.length, 2);
      expect(result[0].id, '1');
    });
  });

  group('StorageService - Account Operations', () {
    test('getAccounts returns only accounts for active profile', () {
      final accounts = [
        Account(
            id: 'a1',
            name: 'Acc1',
            profileId: 'default',
            type: AccountType.wallet),
        Account(
            id: 'a2',
            name: 'Acc2',
            profileId: 'other',
            type: AccountType.wallet),
      ];
      when(() => mockAccountBox.values).thenReturn(accounts);

      final result = storageService.getAccounts();
      expect(result.length, 1);
      expect(result[0].id, 'a1');
    });

    test('saveAccount puts account into box', () async {
      final account = Account(
          id: 'a1',
          name: 'Acc1',
          profileId: 'default',
          type: AccountType.wallet);
      when(() => mockAccountBox.put(any(), any())).thenAnswer((_) async => {});

      await storageService.saveAccount(account);
      verify(() => mockAccountBox.put('a1', account)).called(1);
    });
  });

  group('StorageService - Transaction Operations', () {
    test('saveTransaction updates source account balance', () async {
      final account = Account(
          id: 'acc1',
          name: 'Bank',
          balance: 1000.0,
          profileId: 'default',
          type: AccountType.wallet);
      final transaction = Transaction(
        id: 'txn1',
        title: 'Lunch',
        amount: 200.0,
        date: DateTime.now(),
        type: TransactionType.expense,
        accountId: 'acc1',
        profileId: 'default',
        category: 'Food',
      );

      when(() => mockTransactionBox.get('txn1')).thenReturn(null);
      when(() => mockAccountBox.get('acc1')).thenReturn(account);
      when(() => mockTransactionBox.put(any(), any()))
          .thenAnswer((_) async => {});
      when(() => mockSettingsBox.get('txnsSinceBackup', defaultValue: 0))
          .thenReturn(0);
      when(() => mockSettingsBox.put(any(), any())).thenAnswer((_) async => {});

      await storageService.saveTransaction(transaction);

      expect(account.balance, 800.0);
      verify(() => mockTransactionBox.put('txn1', transaction)).called(1);
    });

    test('deleteTransaction reverses account impact', () async {
      final account = Account(
          id: 'acc1',
          name: 'Bank',
          balance: 800.0,
          profileId: 'default',
          type: AccountType.wallet);
      final transaction = Transaction(
        id: 'txn1',
        title: 'Lunch',
        amount: 200.0,
        date: DateTime.now(),
        type: TransactionType.expense,
        accountId: 'acc1',
        profileId: 'default',
        category: 'Food',
      );

      when(() => mockTransactionBox.get('txn1')).thenReturn(transaction);
      when(() => mockAccountBox.get('acc1')).thenReturn(account);
      when(() => mockTransactionBox.put(any(), any()))
          .thenAnswer((_) async => {});

      await storageService.deleteTransaction('txn1');

      expect(transaction.isDeleted, true);
      expect(account.balance, 1000.0);
    });

    test('saveTransactions batch updates balances', () async {
      final account = Account(
          id: 'acc1',
          name: 'Bank',
          balance: 1000.0,
          profileId: 'default',
          type: AccountType.wallet);
      final t1 = Transaction(
        id: 't1',
        title: 'T1',
        amount: 100.0,
        date: DateTime.now(),
        type: TransactionType.expense,
        accountId: 'acc1',
        profileId: 'default',
        category: 'C1',
      );
      final t2 = Transaction(
        id: 't2',
        title: 'T2',
        amount: 50.0,
        date: DateTime.now(),
        type: TransactionType.income,
        accountId: 'acc1',
        profileId: 'default',
        category: 'C1',
      );

      when(() => mockTransactionBox.get(any())).thenReturn(null);
      when(() => mockAccountBox.get('acc1')).thenReturn(account);
      when(() => mockTransactionBox.putAll(any())).thenAnswer((_) async => {});
      when(() => mockSettingsBox.get('txnsSinceBackup', defaultValue: 0))
          .thenReturn(0);

      await storageService.saveTransactions([t1, t2]);

      expect(account.balance, 950.0);
      verify(() => mockTransactionBox.putAll(any())).called(1);
    });
  });

  group('StorageService - Cascade Operations', () {
    test('deleteAccount cleans up associated transactions and metadata',
        () async {
      final account = Account(
          id: 'acc1',
          name: 'Bank',
          profileId: 'default',
          type: AccountType.wallet);
      final t1 = Transaction(
        id: 't1',
        title: 'T1',
        amount: 100,
        date: DateTime.now(),
        type: TransactionType.expense,
        accountId: 'acc1',
        profileId: 'default',
        category: 'C1',
      );

      when(() => mockAccountBox.get('acc1')).thenReturn(account);
      when(() => mockTransactionBox.values).thenReturn([t1]);
      when(() => mockAccountBox.delete(any())).thenAnswer((_) async => {});
      when(() => mockTransactionBox.delete(any())).thenAnswer((_) async => {});

      await storageService.deleteAccount('acc1');

      verify(() => mockTransactionBox.delete('t1')).called(1);
      verify(() => mockAccountBox.delete('acc1')).called(1);
      verify(() => mockSettingsBox.delete('last_rollover_acc1')).called(1);
    });

    test('deleteProfile cleans up all profile-linked data', () async {
      final pId = 'p1';
      final acc = Account(
          id: 'a1', name: 'A1', profileId: pId, type: AccountType.wallet);
      final txn = Transaction(
          id: 't1',
          title: 'T1',
          amount: 10,
          date: DateTime.now(),
          type: TransactionType.expense,
          profileId: pId,
          category: 'C');
      final loan = Loan(
          id: 'l1',
          name: 'L1',
          totalPrincipal: 100,
          remainingPrincipal: 100,
          interestRate: 10,
          tenureMonths: 12,
          startDate: DateTime.now(),
          firstEmiDate: DateTime.now(),
          emiAmount: 10,
          profileId: pId);
      final rt = RecurringTransaction(
          id: 'r1',
          title: 'R1',
          amount: 10,
          category: 'C',
          accountId: 'a1',
          frequency: Frequency.monthly,
          interval: 1,
          nextExecutionDate: DateTime.now(),
          profileId: pId);
      final cat = Category(
          id: 'c1', name: 'C1', usage: CategoryUsage.expense, profileId: pId);

      when(() => mockProfileBox.delete(any())).thenAnswer((_) async => {});
      when(() => mockAccountBox.values).thenReturn([acc]);
      when(() => mockTransactionBox.values).thenReturn([txn]);
      when(() => mockLoanBox.values).thenReturn([loan]);
      when(() => mockRecurringBox.values).thenReturn([rt]);
      when(() => mockCategoryBox.values).thenReturn([cat]);

      when(() => mockProfileBox.values)
          .thenReturn([Profile(id: 'default', name: 'Default')]);

      await storageService.deleteProfile(pId);

      verify(() => mockProfileBox.delete(pId)).called(1);
      verify(() => mockAccountBox.delete('a1')).called(1);
      verify(() => mockTransactionBox.delete('t1')).called(1);
      verify(() => mockLoanBox.delete('l1')).called(1);
      verify(() => mockRecurringBox.delete('r1')).called(1);
      verify(() => mockCategoryBox.delete('c1')).called(1);
      verify(() => mockSettingsBox.delete('last_rollover_a1')).called(1);
    });
  });

  group('StorageService - Bulk/Utility Operations', () {
    test('bulkUpdateCategory updates matching transactions', () async {
      final txns = [
        Transaction(
            id: '1',
            title: 'Coffee',
            amount: 5,
            date: DateTime.now(),
            type: TransactionType.expense,
            profileId: 'default',
            category: 'Old'),
        Transaction(
            id: '2',
            title: 'Coffee',
            amount: 3,
            date: DateTime.now(),
            type: TransactionType.expense,
            profileId: 'default',
            category: 'Old'),
        Transaction(
            id: '3',
            title: 'Tea',
            amount: 2,
            date: DateTime.now(),
            type: TransactionType.expense,
            profileId: 'default',
            category: 'Old'),
      ];
      when(() => mockTransactionBox.values).thenReturn(txns);

      await storageService.bulkUpdateCategory('Coffee', 'Old', 'New');

      expect(txns[0].category, 'New');
      expect(txns[1].category, 'New');
      expect(txns[2].category, 'Old');
      verify(() => mockTransactionBox.put(any(), any())).called(2);
    });

    test('copyCategories copies from source to target if not exists', () async {
      final sCat = Category(
          id: 's1',
          name: 'Source',
          usage: CategoryUsage.expense,
          profileId: 'from');
      final tCat = Category(
          id: 't1',
          name: 'Target',
          usage: CategoryUsage.expense,
          profileId: 'to');

      when(() => mockCategoryBox.values).thenReturn([sCat, tCat]);

      await storageService.copyCategories('from', 'to');

      verify(() => mockCategoryBox.put(any(), any())).called(1);
    });
  });

  group('StorageService - Category Operations', () {
    test('getCategories creates defaults if empty', () async {
      // Setup for init() to skip opening boxes (assumed open) but load JSON
      when(() => mockHive.isBoxOpen(any())).thenReturn(true);
      // Ensure specific boxes queried in init are returned
      when(() => mockHive.box<Profile>(StorageService.boxProfiles))
          .thenReturn(mockProfileBox);
      when(() => mockHive.box<Category>(StorageService.boxCategories))
          .thenReturn(mockCategoryBox);
      when(() => mockHive.box(StorageService.boxSettings))
          .thenReturn(mockSettingsBox);

      // Mocks for Init logic
      when(() => mockProfileBox.isEmpty)
          .thenReturn(false); // Skip profile creation
      when(() => mockCategoryBox.isEmpty).thenReturn(
          false); // Skip category creation in init (we want getCategories to do it)
      // Actually if we set it false, init skips.
      // But getCategories checks _getByProfile which calls box.values
      // We set values to [] below, so _getByProfile returns [].

      await storageService.init();

      when(() => mockCategoryBox.values).thenReturn([]);

      final result = storageService.getCategories();

      expect(result.isNotEmpty, true);
      verify(() => mockCategoryBox.put(any(), any())).called(greaterThan(0));
    });

    test('addCategory saves to box', () async {
      final category = Category.create(
          name: 'New',
          usage: CategoryUsage.expense,
          iconCode: 0,
          profileId: 'default');
      await storageService.addCategory(category);
      verify(() => mockCategoryBox.put(category.id, category)).called(1);
    });
  });

  group('StorageService - Recurring Operations', () {
    test('saveRecurringTransaction saves to box', () async {
      final rt = RecurringTransaction(
        id: 'r1',
        title: 'Rent',
        amount: 1000,
        category: 'Home',
        accountId: 'a1',
        frequency: Frequency.monthly,
        interval: 1,
        nextExecutionDate: DateTime.now(),
        profileId: 'default',
      );

      await storageService.saveRecurringTransaction(rt);
      verify(() => mockRecurringBox.put('r1', rt)).called(1);
    });

    test('advanceRecurringTransactionDate updates date', () async {
      final rt = RecurringTransaction(
        id: 'r1',
        title: 'Rent',
        amount: 1000,
        category: 'Home',
        accountId: 'a1',
        frequency: Frequency.monthly,
        interval: 1,
        nextExecutionDate: DateTime(2024, 1, 1),
        profileId: 'default',
      );

      when(() => mockRecurringBox.get('r1')).thenReturn(rt);

      await storageService.advanceRecurringTransactionDate('r1');

      expect(rt.nextExecutionDate.month, 2);
      verify(() => mockRecurringBox.put('r1', rt)).called(1);
    });
  });

  group('StorageService - Billing & Rollover', () {
    test('checkCreditCardRollovers triggers rollover and updates balance',
        () async {
      final acc = Account(
        id: 'cc1',
        name: 'CC',
        type: AccountType.creditCard,
        billingCycleDay: 1,
        balance: 1000.0,
        profileId: 'default',
      );

      // Setup: Last rollover was Jan 1, 2024
      final lastRollover = DateTime(2024, 1, 1);
      final now = DateTime(2024, 2, 5); // Current date is Feb 5 (Cycle Feb 1)

      // Transactions in the billing period (Jan 1 - Feb 1)
      final txn = Transaction(
        id: 't1',
        title: 'Expense',
        amount: 500.0,
        date: DateTime(2024, 1, 15),
        type: TransactionType.expense,
        accountId: 'cc1',
        profileId: 'default',
        category: 'Food',
      );

      when(() => mockAccountBox.values).thenReturn([acc]);
      when(() => mockSettingsBox.get('last_rollover_cc1'))
          .thenReturn(lastRollover.millisecondsSinceEpoch);
      when(() => mockTransactionBox.values).thenReturn([txn]);

      // Allow saving updated account and settings
      when(() => mockAccountBox.put(any(), any())).thenAnswer((_) async {});
      when(() => mockSettingsBox.put(any(), any())).thenAnswer((_) async {});

      await storageService.checkCreditCardRollovers(nowOverride: now);

      // Verify Balance Updated (1000 + 500 = 1500)
      expect(acc.balance, 1500.0);

      // Verify Settings Updated (New cycle start: Feb 1)
      final expectedCycleStart = DateTime(2024, 2, 1);
      verify(() => mockSettingsBox.put(
              'last_rollover_cc1', expectedCycleStart.millisecondsSinceEpoch))
          .called(1);
    });
  });

  group('StorageService - Holiday Operations', () {
    test('addHoliday adds unique holiday and revalidates recurring', () async {
      when(() => mockSettingsBox.get('holidays', defaultValue: []))
          .thenReturn(<DateTime>[]);
      when(() => mockSettingsBox.put(any(), any())).thenAnswer((_) async {});
      when(() => mockRecurringBox.values)
          .thenReturn([]); // No recurring to validate

      final date = DateTime(2024, 1, 1);
      await storageService.addHoliday(date);

      verify(() => mockSettingsBox.put('holidays', [date])).called(1);
    });

    test('removeHoliday removes holiday', () async {
      final date = DateTime(2024, 1, 1);
      // Use a mutable list for mocks to allow removeWhere if logic uses the same reference,
      // but usually service gets a fresh copy or modifies the one returned.
      // StorageService: getHolidays() -> returns mapped list.
      // Then modifies it and puts it back.

      when(() => mockSettingsBox.get('holidays', defaultValue: [])).thenReturn(
          [date]); // Return dynamic list usually, but here DateTime list
      when(() => mockSettingsBox.put(any(), any())).thenAnswer((_) async {});
      when(() => mockRecurringBox.values).thenReturn([]);

      await storageService.removeHoliday(date);

      // Verify put checks: empty list
      verify(() => mockSettingsBox.put(any(), []));
    });
  });

  group('StorageService - Data Cleanup', () {
    test('clearAllData deletes everything for active profile', () async {
      // Setup mocked data
      when(() => mockAccountBox.values).thenReturn([
        Account(
            id: 'a1', name: 'A', profileId: 'default', type: AccountType.wallet)
      ]);
      when(() => mockTransactionBox.values).thenReturn([]);
      when(() => mockLoanBox.values).thenReturn([]);
      when(() => mockRecurringBox.values).thenReturn([]);
      when(() => mockCategoryBox.values).thenReturn([]);
      when(() => mockSettingsBox.put(any(), any())).thenAnswer((_) async {});

      await storageService.clearAllData();

      verify(() => mockAccountBox.delete('a1')).called(1);
      verify(() => mockSettingsBox.put('txnsSinceBackup', 0)).called(1);
    });
  });
}
