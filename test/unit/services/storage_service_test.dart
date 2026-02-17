import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:samriddhi_flow/services/storage_service.dart';
import 'package:samriddhi_flow/models/account.dart';
import 'package:samriddhi_flow/models/profile.dart';
import 'package:samriddhi_flow/models/transaction.dart';
import 'package:samriddhi_flow/models/loan.dart';
import 'package:samriddhi_flow/models/recurring_transaction.dart';
import 'package:samriddhi_flow/models/category.dart';
import 'package:samriddhi_flow/models/lending_record.dart';
import 'package:samriddhi_flow/models/taxes/insurance_policy.dart';
import 'package:samriddhi_flow/models/taxes/tax_data.dart';

class MockHive extends Mock implements HiveInterface {}

class MockBox<T> extends Mock implements Box<T> {}

class MockAccountBox extends Mock implements Box<Account> {}

class MockTransactionBox extends Mock implements Box<Transaction> {}

class MockProfileBox extends Mock implements Box<Profile> {}

class ProfileFake extends Fake implements Profile {}

void main() {
  late StorageService storageService;
  late MockHive mockHive;
  late MockBox<dynamic> mockSettingsBox;
  late MockProfileBox mockProfileBox;
  late MockAccountBox mockAccountBox;
  late MockTransactionBox mockTransactionBox;
  late MockBox<Loan> mockLoanBox;
  late MockBox<RecurringTransaction> mockRecurringBox;
  late MockBox<Category> mockCategoryBox;
  late MockBox<InsurancePolicy> mockInsuranceBox;
  late MockBox<TaxYearData> mockTaxBox;
  late MockBox<LendingRecord> mockLendingBox;

  setUpAll(() {
    registerFallbackValue(ProfileFake());
    registerFallbackValue(
        Account(id: 'f', name: 'f', type: AccountType.savings, balance: 0));
    registerFallbackValue(Transaction(
        id: 'f',
        title: 'f',
        amount: 0,
        date: DateTime.now(),
        type: TransactionType.expense,
        category: 'c'));
  });

  setUp(() {
    mockHive = MockHive();
    mockSettingsBox = MockBox<dynamic>();
    mockProfileBox = MockProfileBox();
    mockAccountBox = MockAccountBox();
    mockTransactionBox = MockTransactionBox();
    mockLoanBox = MockBox<Loan>();
    mockRecurringBox = MockBox<RecurringTransaction>();
    mockCategoryBox = MockBox<Category>();
    mockInsuranceBox = MockBox<InsurancePolicy>();
    mockTaxBox = MockBox<TaxYearData>();
    mockLendingBox = MockBox<LendingRecord>();

    when(() => mockHive.box<Profile>(StorageService.boxProfiles))
        .thenReturn(mockProfileBox);
    when(() => mockHive.box(StorageService.boxSettings))
        .thenReturn(mockSettingsBox);
    when(() => mockHive.box<Account>(StorageService.boxAccounts))
        .thenReturn(mockAccountBox);
    when(() => mockHive.box<Transaction>(StorageService.boxTransactions))
        .thenReturn(mockTransactionBox);
    when(() => mockHive.box<Loan>(StorageService.boxLoans))
        .thenReturn(mockLoanBox);
    when(() => mockHive.box<RecurringTransaction>(StorageService.boxRecurring))
        .thenReturn(mockRecurringBox);
    when(() => mockHive.box<Category>(StorageService.boxCategories))
        .thenReturn(mockCategoryBox);
    when(() =>
            mockHive.box<InsurancePolicy>(StorageService.boxInsurancePolicies))
        .thenReturn(mockInsuranceBox);
    when(() => mockHive.box<TaxYearData>(StorageService.boxTaxData))
        .thenReturn(mockTaxBox);
    when(() => mockHive.box<LendingRecord>(StorageService.boxLendingRecords))
        .thenReturn(mockLendingBox);

    when(() => mockHive.isBoxOpen(any())).thenReturn(true);

    storageService = StorageService(mockHive);

    // Default mock for profile ID
    when(() => mockSettingsBox.get('activeProfileId',
        defaultValue: any(named: 'defaultValue'))).thenReturn('default');
  });

  group('StorageService - Profile Operations', () {
    test('getActiveProfileId returns value from hive', () {
      when(() => mockSettingsBox.get('activeProfileId',
          defaultValue: any(named: 'defaultValue'))).thenReturn('p1');
      expect(storageService.getActiveProfileId(), 'p1');
    });

    test('setActiveProfileId sets value in Hive', () async {
      when(() => mockSettingsBox.put('activeProfileId', 'p1'))
          .thenAnswer((_) async {});
      await storageService.setActiveProfileId('p1');
      verify(() => mockSettingsBox.put('activeProfileId', 'p1')).called(1);
    });

    test('deleteProfile deletes profile and associated data', () async {
      final profileId = 'p1';
      when(() => mockProfileBox.delete(profileId)).thenAnswer((_) async {});

      when(() => mockAccountBox.toMap()).thenReturn({});
      when(() => mockTransactionBox.toMap()).thenReturn({});
      when(() => mockLoanBox.toMap()).thenReturn({});
      when(() => mockRecurringBox.toMap()).thenReturn({});
      when(() => mockCategoryBox.toMap()).thenReturn({});
      when(() => mockProfileBox.toMap()).thenReturn({});

      await storageService.deleteProfile(profileId);

      verify(() => mockProfileBox.delete(profileId)).called(1);
    });
  });

  group('StorageService - Account Operations', () {
    test('saveAccount handles credit card rollover reset', () async {
      final acc = Account(
        id: 'cc1',
        name: 'Credit Card',
        type: AccountType.creditCard,
        balance: 1000,
        billingCycleDay: 15,
      );

      when(() => mockAccountBox.get('cc1')).thenReturn(null);
      when(() => mockAccountBox.put('cc1', any())).thenAnswer((_) async {});
      when(() => mockSettingsBox.put(any(), any())).thenAnswer((_) async {});

      await storageService.saveAccount(acc);

      verify(() => mockAccountBox.put('cc1', any())).called(1);
      verify(() => mockSettingsBox.put(startsWith('last_rollover_cc1'), any()))
          .called(1);
    });
  });

  group('StorageService - Transaction Impact', () {
    test('saveTransaction updates savings account balance', () async {
      final acc = Account(
          id: 'acc1',
          name: 'Savings',
          type: AccountType.savings,
          balance: 1000);
      final txn = Transaction(
        id: 't1',
        title: 'Food',
        amount: 200,
        date: DateTime.now(),
        type: TransactionType.expense,
        category: 'Food',
        accountId: 'acc1',
      );

      when(() => mockAccountBox.get('acc1')).thenReturn(acc);
      when(() => mockTransactionBox.get('t1')).thenReturn(null);
      when(() => mockTransactionBox.put('t1', any())).thenAnswer((_) async {});
      when(() => mockAccountBox.put('acc1', any())).thenAnswer((_) async {});
      when(() => mockSettingsBox.get('txnsSinceBackup', defaultValue: 0))
          .thenReturn(0);
      when(() => mockSettingsBox.put('txnsSinceBackup', any()))
          .thenAnswer((_) async {});

      await storageService.saveTransaction(txn);

      expect(acc.balance, 800);
      verify(() => mockAccountBox.put('acc1', any())).called(1);
    });

    test('saveTransaction updates credit card balance (debt increase)',
        () async {
      final acc = Account(
          id: 'cc1', name: 'CC', type: AccountType.creditCard, balance: 1000);
      final txn = Transaction(
          id: 't1',
          title: 'Buy',
          amount: 500,
          date: DateTime.now().subtract(const Duration(days: 45)),
          type: TransactionType.expense,
          category: 'Shop',
          accountId: 'cc1');

      when(() => mockAccountBox.get('cc1')).thenReturn(acc);
      when(() => mockTransactionBox.get('t1')).thenReturn(null);
      when(() => mockTransactionBox.put('t1', any())).thenAnswer((_) async {});
      when(() => mockAccountBox.put('cc1', any())).thenAnswer((_) async {});
      when(() => mockSettingsBox.get(any(),
          defaultValue: any(named: 'defaultValue'))).thenReturn(0);
      when(() => mockSettingsBox.put(any(), any())).thenAnswer((_) async {});
      when(() => mockSettingsBox.get(startsWith('last_rollover_cc1')))
          .thenReturn(null);

      await storageService.saveTransaction(txn);

      expect(acc.balance, 1500);
    });
  });

  group('StorageService - Deletion', () {
    test('deleteTransaction performs soft delete and reverses impact',
        () async {
      final acc = Account(
          id: 'acc1', name: 'Savings', type: AccountType.savings, balance: 800);
      final txn = Transaction(
          id: 't1',
          title: 'Food',
          amount: 200,
          date: DateTime.now(),
          type: TransactionType.expense,
          category: 'Food',
          accountId: 'acc1');

      when(() => mockTransactionBox.get('t1')).thenReturn(txn);
      when(() => mockAccountBox.get('acc1')).thenReturn(acc);
      when(() => mockTransactionBox.put('t1', any())).thenAnswer((_) async {});
      when(() => mockAccountBox.put('acc1', any())).thenAnswer((_) async {});

      await storageService.deleteTransaction('t1');

      expect(txn.isDeleted, true);
      expect(acc.balance, 1000);
    });
  });

  group('StorageService - Settings', () {
    test('getCurrencyLocale returns profile value', () {
      final p =
          Profile(id: 'default', name: 'Default', currencyLocale: 'en_US');
      when(() => mockProfileBox.get('default')).thenReturn(p);
      expect(storageService.getCurrencyLocale(), 'en_US');
    });

    test('setCurrencyLocale updates profile in Hive', () async {
      final p = Profile(id: 'default', name: 'Default');
      when(() => mockProfileBox.get('default')).thenReturn(p);
      when(() => mockProfileBox.put('default', any())).thenAnswer((_) async {});

      await storageService.setCurrencyLocale('hi_IN');
      verify(() => mockProfileBox.put('default', any())).called(1);
    });
  });
}
