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
    registerFallbackValue(
        Category(id: 'c', name: 'c', usage: CategoryUsage.expense));
    registerFallbackValue(const TaxYearData(year: 2025));
    registerFallbackValue(LendingRecord(
      id: 'f',
      personName: 'f',
      amount: 0,
      reason: 'f',
      date: DateTime.now(),
      type: LendingType.lent,
    ));
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
          .thenAnswer((_) => Future<void>.value());
      await storageService.setActiveProfileId('p1');
      verify(() => mockSettingsBox.put('activeProfileId', 'p1')).called(1);
    });

    test('deleteProfile deletes profile and associated data recursively',
        () async {
      const profileId = 'p1';
      final acc = Account(
          id: 'acc1',
          name: 'A',
          type: AccountType.savings,
          profileId: profileId);
      final txn = Transaction(
          id: 't1',
          title: 'T',
          amount: 10,
          date: DateTime.now(),
          type: TransactionType.expense,
          category: 'Food',
          profileId: profileId);

      when(() => mockAccountBox.toMap()).thenReturn({'acc1': acc});
      when(() => mockTransactionBox.toMap()).thenReturn({'t1': txn});
      when(() => mockLoanBox.toMap()).thenReturn({});
      when(() => mockRecurringBox.toMap()).thenReturn({});
      when(() => mockCategoryBox.toMap()).thenReturn({});
      when(() => mockLendingBox.toMap()).thenReturn({});
      when(() => mockProfileBox.toMap()).thenReturn({});
      when(() => mockInsuranceBox.toMap()).thenReturn({});
      when(() => mockTaxBox.toMap()).thenReturn({});

      when(() => mockAccountBox.delete(any())).thenAnswer((_) async {});
      when(() => mockTransactionBox.delete(any())).thenAnswer((_) async {});
      when(() => mockProfileBox.delete(profileId)).thenAnswer((_) async {});
      when(() => mockSettingsBox.delete(any())).thenAnswer((_) async {});

      await storageService.deleteProfile(profileId);

      verify(() => mockAccountBox.delete('acc1')).called(1);
      verify(() => mockTransactionBox.delete('t1')).called(1);
      verify(() => mockProfileBox.delete(profileId)).called(1);
    });
  });

  group('StorageService - Account Operations', () {
    test('saveAccount handles credit card rollover reset (New Account)',
        () async {
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

    test('saveAccount handles credit card rollover reset (Cycle Changed)',
        () async {
      final oldAcc = Account(
          id: 'cc1',
          name: 'CC',
          type: AccountType.creditCard,
          billingCycleDay: 10,
          balance: 0);
      final newAcc = Account(
          id: 'cc1',
          name: 'CC',
          type: AccountType.creditCard,
          billingCycleDay: 15,
          balance: 0);

      when(() => mockAccountBox.get('cc1')).thenReturn(oldAcc);
      when(() => mockAccountBox.put('cc1', any())).thenAnswer((_) async {});
      when(() => mockSettingsBox.put(any(), any())).thenAnswer((_) async {});

      await storageService.saveAccount(newAcc);
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

  group('StorageService - Category Operations', () {
    test('addCategory uses active profileId if null or empty', () async {
      final cat = Category(
        id: 'cat1',
        name: 'Test Category',
        usage: CategoryUsage.expense,
        profileId: null,
      );

      when(() => mockCategoryBox.put('cat1', any())).thenAnswer((_) async {});
      when(() => mockSettingsBox.get('activeProfileId',
          defaultValue: any(named: 'defaultValue'))).thenReturn('p2');

      await storageService.addCategory(cat);

      expect(cat.profileId, 'p2');
      verify(() => mockCategoryBox.put('cat1', cat)).called(1);
    });

    test('addCategory throws on reserved Bank loan name', () async {
      final cat = Category(
        id: 'cat2',
        name: 'Bank loan',
        usage: CategoryUsage.expense,
      );

      expect(
        () => storageService.addCategory(cat),
        throwsException,
      );
    });

    test('addCategory allows Bank loan name on restore', () async {
      final cat = Category(
        id: 'cat3',
        name: 'Bank loan',
        usage: CategoryUsage.expense,
        profileId: 'default',
      );

      when(() => mockCategoryBox.put('cat3', any())).thenAnswer((_) async {});

      await storageService.addCategory(cat, isRestore: true);
      verify(() => mockCategoryBox.put('cat3', any())).called(1);
    });

    test('removeCategory throws on reserved Bank loan', () async {
      final cat = Category(
        id: 'cat4',
        name: 'Bank loan',
        usage: CategoryUsage.expense,
      );
      when(() => mockCategoryBox.get('cat4')).thenReturn(cat);

      expect(
        () => storageService.removeCategory('cat4'),
        throwsException,
      );
    });

    test('removeCategory deletes normal categories', () async {
      final cat = Category(
        id: 'cat5',
        name: 'Food',
        usage: CategoryUsage.expense,
      );
      when(() => mockCategoryBox.get('cat5')).thenReturn(cat);
      when(() => mockCategoryBox.delete('cat5')).thenAnswer((_) async {});

      await storageService.removeCategory('cat5');
      verify(() => mockCategoryBox.delete('cat5')).called(1);
    });
  });

  group('StorageService - Loan Operations', () {
    test('getAllLoans returns all loans', () {
      final loan = Loan(
        id: 'l1',
        name: 'Home Loan',
        totalPrincipal: 1000000,
        remainingPrincipal: 900000,
        interestRate: 8.0,
        tenureMonths: 240,
        startDate: DateTime(2024, 1, 1),
        emiAmount: 8500,
        firstEmiDate: DateTime(2024, 2, 1),
      );
      when(() => mockLoanBox.toMap()).thenReturn({'l1': loan});

      final loans = storageService.getAllLoans();
      expect(loans.length, 1);
      expect(loans.first.name, 'Home Loan');
    });
  });

  group('StorageService - Recurring Operations', () {
    test('getAllRecurring returns all recurring transactions', () {
      final rt = RecurringTransaction(
        id: 'rt1',
        title: 'Rent',
        amount: 15000,
        category: 'Housing',
        frequency: Frequency.monthly,
        nextExecutionDate: DateTime(2024, 2, 1),
      );
      when(() => mockRecurringBox.toMap()).thenReturn({'rt1': rt});

      final recurring = storageService.getAllRecurring();
      expect(recurring.length, 1);
      expect(recurring.first.title, 'Rent');
    });
  });

  group('StorageService - Extended Settings', () {
    test('getAuthFlag returns bool from settings', () {
      when(() => mockSettingsBox.get('isLoggedIn', defaultValue: false))
          .thenReturn(true);
      expect(storageService.getAuthFlag(), true);
    });

    test('setAuthFlag writes to settings', () async {
      when(() => mockSettingsBox.put('isLoggedIn', true))
          .thenAnswer((_) async {});
      await storageService.setAuthFlag(true);
      verify(() => mockSettingsBox.put('isLoggedIn', true)).called(1);
    });

    test('isSmartCalculatorEnabled returns bool from settings', () {
      when(() => mockSettingsBox.get('smartCalculatorEnabled',
          defaultValue: false)).thenReturn(true);
      expect(storageService.isSmartCalculatorEnabled(), true);
    });

    test('setSmartCalculatorEnabled writes to settings', () async {
      when(() => mockSettingsBox.put('smartCalculatorEnabled', false))
          .thenAnswer((_) async {});
      await storageService.setSmartCalculatorEnabled(false);
      verify(() => mockSettingsBox.put('smartCalculatorEnabled', false))
          .called(1);
    });

    test('getLastLogin parses stored DateTime', () {
      when(() => mockSettingsBox.get('lastLogin'))
          .thenReturn(DateTime(2024, 6, 1));
      expect(storageService.getLastLogin(), DateTime(2024, 6, 1));
    });

    test('getLastLogin parses stored string', () {
      when(() => mockSettingsBox.get('lastLogin'))
          .thenReturn('2024-06-01T00:00:00.000');
      final result = storageService.getLastLogin();
      expect(result?.year, 2024);
      expect(result?.month, 6);
    });

    test('setLastLogin writes DateTime', () async {
      final date = DateTime(2024, 6, 15);
      when(() => mockSettingsBox.put('lastLogin', date))
          .thenAnswer((_) async {});
      await storageService.setLastLogin(date);
      verify(() => mockSettingsBox.put('lastLogin', date)).called(1);
    });

    test('getInactivityThresholdDays returns from settings', () {
      when(() =>
              mockSettingsBox.get('inactivityThresholdDays', defaultValue: 7))
          .thenReturn(14);
      expect(storageService.getInactivityThresholdDays(), 14);
    });

    test('setInactivityThresholdDays writes to settings', () async {
      when(() => mockSettingsBox.put('inactivityThresholdDays', 14))
          .thenAnswer((_) async {});
      await storageService.setInactivityThresholdDays(14);
      verify(() => mockSettingsBox.put('inactivityThresholdDays', 14))
          .called(1);
    });

    test('getMaturityWarningDays returns from settings', () {
      when(() => mockSettingsBox.get('maturityWarningDays', defaultValue: 5))
          .thenReturn(10);
      expect(storageService.getMaturityWarningDays(), 10);
    });

    test('setMaturityWarningDays writes to settings', () async {
      when(() => mockSettingsBox.put('maturityWarningDays', 10))
          .thenAnswer((_) async {});
      await storageService.setMaturityWarningDays(10);
      verify(() => mockSettingsBox.put('maturityWarningDays', 10)).called(1);
    });

    test('getPinResetRequested returns from settings', () {
      when(() => mockSettingsBox.get('pinResetRequested', defaultValue: false))
          .thenReturn(true);
      expect(storageService.getPinResetRequested(), true);
    });

    test('setPinResetRequested writes to settings', () async {
      when(() => mockSettingsBox.put('pinResetRequested', true))
          .thenAnswer((_) async {});
      await storageService.setPinResetRequested(true);
      verify(() => mockSettingsBox.put('pinResetRequested', true)).called(1);
    });

    test('getTxnsSinceBackup returns counter value', () {
      when(() => mockSettingsBox.get('txnsSinceBackup', defaultValue: 0))
          .thenReturn(5);
      expect(storageService.getTxnsSinceBackup(), 5);
    });

    test('resetTxnsSinceBackup resets the counter', () async {
      when(() => mockSettingsBox.put('txnsSinceBackup', 0))
          .thenAnswer((_) async {});
      await storageService.resetTxnsSinceBackup();
      verify(() => mockSettingsBox.put('txnsSinceBackup', 0)).called(1);
    });

    test('getBackupThreshold returns from settings', () {
      when(() => mockSettingsBox.get('backupThreshold', defaultValue: 5))
          .thenReturn(10);
      expect(storageService.getBackupThreshold(), 10);
    });

    test('setBackupThreshold writes to settings', () async {
      when(() => mockSettingsBox.put('backupThreshold', 10))
          .thenAnswer((_) async {});
      await storageService.setBackupThreshold(10);
      verify(() => mockSettingsBox.put('backupThreshold', 10)).called(1);
    });

    test('getMonthlyBudget returns profile budget', () {
      final p = Profile(id: 'default', name: 'Default', monthlyBudget: 50000);
      when(() => mockProfileBox.get('default')).thenReturn(p);
      expect(storageService.getMonthlyBudget(), 50000);
    });

    test('setMonthlyBudget updates profile', () async {
      final p = Profile(id: 'default', name: 'Default');
      when(() => mockProfileBox.get('default')).thenReturn(p);
      when(() => mockProfileBox.put('default', any())).thenAnswer((_) async {});

      await storageService.setMonthlyBudget(60000);
      verify(() => mockProfileBox.put('default', any())).called(1);
    });

    test('getDashboardConfig returns default when no config saved', () {
      when(() => mockSettingsBox.get('dashboardConfig')).thenReturn(null);
      final config = storageService.getDashboardConfig();
      expect(config, isNotNull);
    });

    test('saveSettings bulk-writes entries', () async {
      when(() => mockSettingsBox.put(any(), any())).thenAnswer((_) async {});

      await storageService.saveSettings({'key1': 'val1', 'key2': 42});
      verify(() => mockSettingsBox.put('key1', 'val1')).called(1);
      verify(() => mockSettingsBox.put('key2', 42)).called(1);
    });

    test('getAllSettings sanitizes DateTime and Color values', () {
      when(() => mockSettingsBox.toMap()).thenReturn({
        'theme': 'dark',
        'lastLogin': DateTime(2024, 6, 1),
        'count': 42,
      });

      final settings = storageService.getAllSettings();
      expect(settings['theme'], 'dark');
      expect(settings['lastLogin'], isA<String>()); // ISO string
      expect(settings['count'], 42);
    });
  });

  group('StorageService - Tax Year Data', () {
    test('saveTaxYearData sets profileId if different', () async {
      when(() => mockTaxBox.put(any(), any())).thenAnswer((_) async {});

      const data = TaxYearData(year: 2025, profileId: 'other');
      await storageService.saveTaxYearData(data);

      // Should be saved with active profile's key
      verify(() => mockTaxBox.put('default_2025', any())).called(1);
    });

    test('deleteTaxYearData removes correct key', () async {
      when(() => mockTaxBox.delete('default_2025')).thenAnswer((_) async {});
      await storageService.deleteTaxYearData(2025);
      verify(() => mockTaxBox.delete('default_2025')).called(1);
    });

    test('getTaxYearData returns matching year for profile', () {
      const data = TaxYearData(year: 2025, profileId: 'default');
      when(() => mockTaxBox.values).thenReturn([data]);

      final result = storageService.getTaxYearData(2025);
      expect(result?.year, 2025);
    });

    test('getTaxYearData returns null when not found', () {
      when(() => mockTaxBox.values).thenReturn([]);

      final result = storageService.getTaxYearData(2025);
      expect(result, isNull);
    });
  });

  group('StorageService - Insurance Policies', () {
    test('getInsurancePoliciesBox returns raw Hive box', () {
      final box = storageService.getInsurancePoliciesBox();
      expect(box, mockInsuranceBox);
    });
  });

  group('StorageService - Lending Records', () {
    test('saveLendingRecord sets profileId if null', () async {
      final record = LendingRecord(
        id: 'lr1',
        personName: 'John',
        amount: 5000,
        reason: 'Help',
        date: DateTime(2024, 6, 1),
        type: LendingType.lent,
        profileId: null,
      );
      when(() => mockLendingBox.put('lr1', any())).thenAnswer((_) async {});

      await storageService.saveLendingRecord(record);

      expect(record.profileId, 'default');
      verify(() => mockLendingBox.put('lr1', any())).called(1);
    });

    test('deleteLendingRecord deletes by id', () async {
      when(() => mockLendingBox.delete('lr1')).thenAnswer((_) async {});

      await storageService.deleteLendingRecord('lr1');
      verify(() => mockLendingBox.delete('lr1')).called(1);
    });
  });

  group('StorageService - Clear All Data', () {
    test('clearAllData clears all boxes for active profile', () async {
      when(() => mockAccountBox.toMap()).thenReturn({});
      when(() => mockTransactionBox.toMap()).thenReturn({});
      when(() => mockLoanBox.toMap()).thenReturn({});
      when(() => mockRecurringBox.toMap()).thenReturn({});
      when(() => mockCategoryBox.toMap()).thenReturn({});
      when(() => mockSettingsBox.put('txnsSinceBackup', 0))
          .thenAnswer((_) async {});

      await storageService.clearAllData();

      verify(() => mockSettingsBox.put('txnsSinceBackup', 0)).called(1);
    });
  });

  group('StorageService - Misc Operations', () {
    test('getLastRollover returns null for missing key', () {
      when(() => mockSettingsBox.get('last_rollover_acc1')).thenReturn(null);
      expect(storageService.getLastRollover('acc1'), isNull);
    });

    test('getLastRollover returns stored value', () {
      when(() => mockSettingsBox.get('last_rollover_acc1'))
          .thenReturn(1717200000000);
      expect(storageService.getLastRollover('acc1'), 1717200000000);
    });

    test('getThemeMode returns stored theme', () {
      when(() => mockSettingsBox.get('themeMode', defaultValue: 'system'))
          .thenReturn('dark');
      expect(storageService.getThemeMode(), 'dark');
    });

    test('setThemeMode writes to settings', () async {
      when(() => mockSettingsBox.put('themeMode', 'dark'))
          .thenAnswer((_) async {});
      await storageService.setThemeMode('dark');
      verify(() => mockSettingsBox.put('themeMode', 'dark')).called(1);
    });

    test('isAppLockEnabled returns stored value', () {
      when(() => mockSettingsBox.get('appLockEnabled', defaultValue: false))
          .thenReturn(true);
      expect(storageService.isAppLockEnabled(), true);
    });

    test('setAppLockEnabled writes to settings', () async {
      when(() => mockSettingsBox.put('appLockEnabled', true))
          .thenAnswer((_) async {});
      await storageService.setAppLockEnabled(true);
      verify(() => mockSettingsBox.put('appLockEnabled', true)).called(1);
    });

    test('getAppPin returns stored pin', () {
      when(() => mockSettingsBox.get('appPin')).thenReturn('1234');
      expect(storageService.getAppPin(), '1234');
    });

    test('setAppPin writes to settings', () async {
      const hash =
          'f8638b979b2f4f793ddb6dbd197e0ee25a7a6ea32b0ae22f5e3c5d119d839e75';
      when(() => mockSettingsBox.put(any(), any()))
          .thenAnswer((_) => Future<void>.value());
      await storageService.setAppPin('5678');
      verify(() => mockSettingsBox.put('appPin', hash)).called(1);
    });

    test('getDeletedTransactions returns deleted transactions for profile', () {
      final t1 = Transaction(
        id: 't1',
        title: 'Food',
        amount: 100,
        date: DateTime.now(),
        type: TransactionType.expense,
        category: 'Food',
        isDeleted: true,
        profileId: 'default',
      );
      when(() => mockTransactionBox.toMap()).thenReturn({'t1': t1});
      final deleted = storageService.getDeletedTransactions();
      expect(deleted.length, 1);
      expect(deleted.first.isDeleted, true);
    });
  });
}
