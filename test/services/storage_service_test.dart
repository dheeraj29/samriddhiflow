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

class MockHiveInterface extends Mock implements HiveInterface {}

class MockBox<T> extends Mock implements Box<T> {}

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
  late MockBox<Account> mockAccountBox;
  late MockBox<Profile> mockProfileBox;
  late MockBox<Transaction> mockTransactionBox;
  late MockBox<Loan> mockLoanBox;
  late MockBox<RecurringTransaction> mockRecurringBox;
  late MockBox<Category> mockCategoryBox;
  late MockBox<dynamic> mockSettingsBox;

  setUp(() {
    mockHive = MockHiveInterface();
    mockAccountBox = MockBox<Account>();
    mockProfileBox = MockBox<Profile>();
    mockTransactionBox = MockBox<Transaction>();
    mockLoanBox = MockBox<Loan>();
    mockRecurringBox = MockBox<RecurringTransaction>();
    mockCategoryBox = MockBox<Category>();
    mockSettingsBox = MockBox<dynamic>();

    storageService = StorageService(mockHive);

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

      await storageService.deleteTransaction('txn1');

      expect(transaction.isDeleted, true);
      expect(account.balance, 1000.0);
    });
  });

  group('StorageService - Credit Card Rollover', () {
    test('checkCreditCardRollovers updates balance if cycle changed', () async {
      final cc = Account(
        id: 'cc1',
        name: 'My Card',
        balance: 0.0,
        profileId: 'default',
        type: AccountType.creditCard,
        billingCycleDay: 1,
      );

      final now = DateTime.now();
      // Last rollover was last month
      final lastMonth = DateTime(now.year, now.month - 1, 1);

      when(() => mockAccountBox.values).thenReturn([cc]);
      when(() => mockSettingsBox.get('last_rollover_cc1'))
          .thenReturn(lastMonth.millisecondsSinceEpoch);
      when(() => mockSettingsBox.put(any(), any())).thenAnswer((_) async => {});

      // An expense in the previous cycle
      final oldTxn = Transaction(
        id: 'old1',
        title: 'Old Expense',
        amount: 50.0,
        date: lastMonth.add(const Duration(days: 5)),
        type: TransactionType.expense,
        accountId: 'cc1',
        profileId: 'default',
        category: 'Other',
      );

      when(() => mockTransactionBox.values).thenReturn([oldTxn]);

      await storageService.checkCreditCardRollovers();

      // Balance should be updated by 50.0
      expect(cc.balance, 50.0);
      verify(() => mockSettingsBox.put('last_rollover_cc1', any())).called(1);
    });
  });

  group('StorageService - Category Operations', () {
    test('getCategories creates defaults if empty', () {
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
}
