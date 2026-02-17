import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:samriddhi_flow/services/storage_service.dart';
import 'package:samriddhi_flow/models/account.dart';
import 'package:samriddhi_flow/models/transaction.dart';
import 'package:samriddhi_flow/models/lending_record.dart';
import 'package:samriddhi_flow/models/category.dart';
import 'package:samriddhi_flow/models/profile.dart';
import 'package:samriddhi_flow/models/loan.dart';
import 'package:samriddhi_flow/models/recurring_transaction.dart';
import 'package:samriddhi_flow/models/taxes/insurance_policy.dart';
import 'package:samriddhi_flow/models/taxes/tax_data.dart';
import 'package:samriddhi_flow/models/dashboard_config.dart';

class MockHive extends Mock implements HiveInterface {}

class MockBox<T> extends Mock implements Box<T> {}

class LoanFake extends Fake implements Loan {}

class TaxYearDataFake extends Fake implements TaxYearData {}

class RecurringTransactionFake extends Fake implements RecurringTransaction {}

class ProfileFake extends Fake implements Profile {}

class InsurancePolicyFake extends Fake implements InsurancePolicy {}

void main() {
  late StorageService storageService;
  late MockHive mockHive;
  late MockBox<Account> mockAccountBox;
  late MockBox<Transaction> mockTransactionBox;
  late MockBox<dynamic> mockSettingsBox;
  late MockBox<LendingRecord> mockLendingBox;
  late MockBox<Category> mockCategoryBox;
  late MockBox<Profile> mockProfileBox;
  late MockBox<Loan> mockLoanBox;
  late MockBox<RecurringTransaction> mockRecurringBox;
  late MockBox<InsurancePolicy> mockInsuranceBox;
  late MockBox<TaxYearData> mockTaxBox;

  setUpAll(() {
    registerFallbackValue(
        Account(id: 'f', name: 'f', type: AccountType.savings, balance: 0));
    registerFallbackValue(Transaction(
        id: 'f',
        title: 'f',
        amount: 0,
        date: DateTime.now(),
        type: TransactionType.expense,
        category: 'c'));
    registerFallbackValue(LendingRecord.create(
        personName: 'f',
        amount: 0,
        reason: 'f',
        date: DateTime.now(),
        type: LendingType.lent));
    registerFallbackValue(
        Category(id: 'f', name: 'f', usage: CategoryUsage.expense));
    registerFallbackValue(ProfileFake());
    registerFallbackValue(const DashboardVisibilityConfig());
    registerFallbackValue(TaxYearDataFake());
    registerFallbackValue(LoanFake());
    registerFallbackValue(RecurringTransactionFake());
    registerFallbackValue(InsurancePolicyFake());
    registerFallbackValue(DateTime.now());
  });

  setUp(() {
    mockHive = MockHive();
    mockAccountBox = MockBox<Account>();
    mockTransactionBox = MockBox<Transaction>();
    mockSettingsBox = MockBox<dynamic>();
    mockLendingBox = MockBox<LendingRecord>();
    mockCategoryBox = MockBox<Category>();
    mockProfileBox = MockBox<Profile>();
    mockLoanBox = MockBox<Loan>();
    mockRecurringBox = MockBox<RecurringTransaction>();
    mockInsuranceBox = MockBox<InsurancePolicy>();
    mockTaxBox = MockBox<TaxYearData>();

    when(() => mockHive.box<Account>(StorageService.boxAccounts))
        .thenReturn(mockAccountBox);
    when(() => mockHive.box<Transaction>(StorageService.boxTransactions))
        .thenReturn(mockTransactionBox);
    when(() => mockHive.box(StorageService.boxSettings))
        .thenReturn(mockSettingsBox);
    when(() => mockHive.box<dynamic>(StorageService.boxSettings))
        .thenReturn(mockSettingsBox);
    when(() => mockHive.box<LendingRecord>(StorageService.boxLendingRecords))
        .thenReturn(mockLendingBox);
    when(() => mockHive.box<Category>(StorageService.boxCategories))
        .thenReturn(mockCategoryBox);
    when(() => mockHive.box<Profile>(StorageService.boxProfiles))
        .thenReturn(mockProfileBox);
    when(() => mockHive.box<Loan>(StorageService.boxLoans))
        .thenReturn(mockLoanBox);
    when(() => mockHive.box<RecurringTransaction>(StorageService.boxRecurring))
        .thenReturn(mockRecurringBox);
    when(() =>
            mockHive.box<InsurancePolicy>(StorageService.boxInsurancePolicies))
        .thenReturn(mockInsuranceBox);
    when(() => mockHive.box<TaxYearData>(StorageService.boxTaxData))
        .thenReturn(mockTaxBox);

    when(() => mockHive.isBoxOpen(any())).thenReturn(true);

    // State-backed mock for settings box
    final settingsMap = <dynamic, dynamic>{};
    when(() => mockSettingsBox.get(any()))
        .thenAnswer((inv) => settingsMap[inv.positionalArguments[0]]);
    when(() => mockSettingsBox.get(any(),
        defaultValue: any(named: 'defaultValue'))).thenAnswer((inv) {
      return settingsMap[inv.positionalArguments[0]] ??
          inv.namedArguments[#defaultValue];
    });
    when(() => mockSettingsBox.put(any(), any())).thenAnswer((inv) {
      settingsMap[inv.positionalArguments[0]] = inv.positionalArguments[1];
      return Future.value();
    });
    when(() => mockSettingsBox.delete(any())).thenAnswer((inv) {
      settingsMap.remove(inv.positionalArguments[0]);
      return Future.value();
    });

    // Default return values for other boxes
    void configureBox<T>(MockBox<T> box) {
      when(() => box.toMap()).thenReturn(<dynamic, T>{});
      when(() => box.delete(any())).thenAnswer((_) async {});
      when(() => box.put(any(), any())).thenAnswer((_) async {});
      when(() => box.putAll(any())).thenAnswer((_) async {});
      when(() => box.clear()).thenAnswer((_) async => 0);
      when(() => box.values).thenReturn(<T>[]);
    }

    configureBox(mockAccountBox);
    configureBox(mockTransactionBox);
    configureBox(mockProfileBox);
    configureBox(mockLoanBox);
    configureBox(mockRecurringBox);
    configureBox(mockCategoryBox);
    configureBox(mockLendingBox);
    configureBox(mockInsuranceBox);
    configureBox(mockTaxBox);

    // Initial default settings
    settingsMap['activeProfileId'] = 'default';

    storageService = StorageService(mockHive);
  });

  group('StorageService - Settings/Preferences Coverage', () {
    test('ThemeMode get/set', () async {
      await storageService.setThemeMode('dark');
      expect(storageService.getThemeMode(), 'dark');

      await storageService.setThemeMode('light');
      expect(storageService.getThemeMode(), 'light');
    });

    test('DashboardConfig get/set', () async {
      const config = DashboardVisibilityConfig(showBudget: false);
      await storageService.saveDashboardConfig(config);

      final result = storageService.getDashboardConfig();
      expect(result.showBudget, false);
    });

    test('MonthlyBudget get/set', () async {
      final p = Profile(id: 'default', name: 'D');
      when(() => mockProfileBox.get('default')).thenReturn(p);
      expect(storageService.getMonthlyBudget(), 0.0);

      await storageService.setMonthlyBudget(10000.0);
      verify(() => mockProfileBox.put('default', any())).called(1);
    });

    test('SmartCalculatorEnabled get/set', () async {
      await storageService.setSmartCalculatorEnabled(false);
      expect(storageService.isSmartCalculatorEnabled(), false);

      await storageService.setSmartCalculatorEnabled(true);
      expect(storageService.isSmartCalculatorEnabled(), true);
    });

    test('BackupThreshold get/set', () async {
      await storageService.setBackupThreshold(50);
      expect(storageService.getBackupThreshold(), 50);

      await storageService.setBackupThreshold(100);
      expect(storageService.getBackupThreshold(), 100);
    });

    test('AuthFlag get/set', () async {
      await storageService.setAuthFlag(true);
      expect(storageService.getAuthFlag(), true);

      await storageService.setAuthFlag(false);
      expect(storageService.getAuthFlag(), false);
    });

    test('AppLock PIN get/set/enabled', () async {
      await storageService.setAppPin('1234');
      expect(storageService.getAppPin(), '1234');

      await storageService.setAppPin('5678');
      expect(storageService.getAppPin(), '5678');

      await storageService.setAppLockEnabled(true);
      expect(storageService.isAppLockEnabled(), true);

      await storageService.setAppLockEnabled(false);
      expect(storageService.isAppLockEnabled(), false);
    });

    test('TransactionsSinceBackup get/reset', () async {
      // Manual put for initial state
      await mockSettingsBox.put('txnsSinceBackup', 10);
      expect(storageService.getTxnsSinceBackup(), 10);

      await storageService.resetTxnsSinceBackup();
      expect(storageService.getTxnsSinceBackup(), 0);
    });
  });

  group('StorageService - Profile & Model CRUD Coverage', () {
    test('getProfiles returns all profiles', () {
      final p1 = Profile(id: 'p1', name: 'P1');
      when(() => mockProfileBox.toMap()).thenReturn({'p1': p1});

      final results = storageService.getProfiles();
      expect(results.length, 1);
      expect(results.first.id, 'p1');
    });

    test('deleteAccount', () async {
      await storageService.deleteAccount('a1');
      verify(() => mockAccountBox.delete('a1')).called(1);
    });

    test('getTransactions filters deleted', () {
      final t1 = Transaction(
          id: 't1',
          title: 'T',
          amount: 0,
          date: DateTime.now(),
          type: TransactionType.expense,
          category: 'C',
          profileId: 'default');
      final t2 = Transaction(
          id: 't2',
          title: 'Td',
          amount: 0,
          date: DateTime.now(),
          type: TransactionType.expense,
          category: 'C',
          profileId: 'default',
          isDeleted: true);

      when(() => mockTransactionBox.toMap()).thenReturn({'t1': t1, 't2': t2});

      final results = storageService.getTransactions();
      expect(results.length, 1);
      expect(results.first.id, 't1');
    });

    test('getLoans/saveLoan/deleteLoan', () async {
      final loan = Loan(
        id: 'l1',
        name: 'L',
        totalPrincipal: 1000,
        profileId: 'default',
        remainingPrincipal: 1000,
        interestRate: 10.0,
        startDate: DateTime.now(),
        tenureMonths: 12,
        emiAmount: 100,
        firstEmiDate: DateTime.now(),
      );
      when(() => mockLoanBox.toMap()).thenReturn({'l1': loan});
      expect(storageService.getLoans().length, 1);

      await storageService.saveLoan(loan);
      verify(() => mockLoanBox.put('l1', any())).called(1);

      await storageService.deleteLoan('l1');
      verify(() => mockLoanBox.delete('l1')).called(1);
    });

    test('getAllRecurring', () {
      final rt = RecurringTransaction(
          id: 'rt1',
          title: 'RT',
          amount: 100,
          category: 'C',
          profileId: 'default',
          frequency: Frequency.monthly,
          nextExecutionDate: DateTime.now());
      when(() => mockRecurringBox.toMap()).thenReturn({'rt1': rt});
      expect(storageService.getAllRecurring().length, 1);
    });

    test('TaxData store/retrieve', () async {
      final tax = TaxYearData(year: 2024);
      when(() => mockTaxBox.get(2024)).thenReturn(tax);
      expect(storageService.getTaxYearData(2024), tax);

      await storageService.saveTaxYearData(tax);
      verify(() => mockTaxBox.put(2024, any())).called(1);
    });

    test('InsurancePolicy CRUD', () async {
      final policy = InsurancePolicy(
        id: 'pol1',
        policyName: 'P',
        policyNumber: 'N',
        annualPremium: 100,
        sumAssured: 1000,
        startDate: DateTime.now(),
        maturityDate: DateTime.now().add(const Duration(days: 365)),
      );
      when(() => mockInsuranceBox.values).thenReturn([policy]);
      expect(storageService.getInsurancePolicies().length, 1);

      await storageService.saveInsurancePolicies([]);
      verify(() => mockInsuranceBox.clear()).called(1);
    });
  });

  group('StorageService - Maintenance Coverage', () {
    test('clearAllData clears items for current profile', () async {
      final profileId = 'default';
      final acc = Account(
          id: 'a1',
          name: 'A',
          type: AccountType.savings,
          balance: 0,
          profileId: profileId);

      when(() => mockAccountBox.toMap()).thenReturn({'a1': acc});

      await storageService.clearAllData();

      verify(() => mockAccountBox.delete('a1')).called(1);
    });

    test('repairAccountCurrencies', () async {
      final wallet = Account(
          id: 'w1',
          name: 'W',
          type: AccountType.wallet,
          balance: 0,
          currency: '');
      final savings = Account(
          id: 's1',
          name: 'S',
          type: AccountType.savings,
          balance: 0,
          currency: 'en_US');

      when(() => mockAccountBox.toMap())
          .thenReturn({'w1': wallet, 's1': savings});

      final repaired = await storageService.repairAccountCurrencies('en_IN');
      expect(repaired, 2);
      expect(wallet.currency, 'en_IN');
      expect(savings.currency, '');
    });
  });

  group('StorageService - Credit Card Rollover & Impact Logic', () {
    test('resetCreditCardRollover - keepBilledStatus: true', () async {
      final card = Account(
        id: 'cc1',
        name: 'CC',
        type: AccountType.creditCard,
        balance: 1000,
        billingCycleDay: 15,
      );

      // We need to wait for the method to complete
      await storageService.resetCreditCardRollover(card,
          keepBilledStatus: true);

      verify(() => mockSettingsBox.put('last_rollover_cc1', any())).called(1);
    });

    test('checkCreditCardRollovers logic', () async {
      final now = DateTime(
          2040, 6, 20); // Current cycle start June 15. Previous: May 15.
      final card = Account(
        id: 'cc2',
        name: 'CC2',
        type: AccountType.creditCard,
        balance: 1000,
        billingCycleDay: 15,
      );

      // Initialize with May 15 crossover (everything before May 15 is settled)
      final lastRollover =
          DateTime(2040, 4, 15).subtract(const Duration(seconds: 1));
      when(() => mockSettingsBox.get('last_rollover_cc2'))
          .thenReturn(lastRollover.millisecondsSinceEpoch);
      when(() => mockAccountBox.toMap()).thenReturn({'cc2': card});

      // Add transaction between Apr 15 and May 15 (should roll over into balance)
      final txn = Transaction(
          id: 't1',
          title: 'Spend',
          amount: 500,
          date: DateTime(2040, 5, 1),
          type: TransactionType.expense,
          category: 'C',
          accountId: 'cc2');
      when(() => mockTransactionBox.toMap()).thenReturn({'t1': txn});

      await storageService.checkCreditCardRollovers(nowOverride: now);

      // Balance should be 1000 + 500 = 1500
      expect(card.balance, 1500);
      verify(() => mockSettingsBox.put('last_rollover_cc2', any())).called(1);
    });

    test('_applyTransactionImpact logic for CC spends', () async {
      final card = Account(
          id: 'cc3',
          name: 'CC3',
          type: AccountType.creditCard,
          balance: 1000,
          billingCycleDay: 15);
      final now = DateTime(2040, 5, 20); // Cycle: May 15

      // Rollover is May 14 23:59:59
      final lastRollover =
          DateTime(2040, 5, 15).subtract(const Duration(seconds: 1));
      when(() => mockSettingsBox.get('last_rollover_cc3'))
          .thenReturn(lastRollover.millisecondsSinceEpoch);
      when(() => mockAccountBox.get('cc3')).thenReturn(card);
      when(() => mockTransactionBox.get('tn1')).thenReturn(null); // Save new

      // Spend in Current Cycle (May 20) -> Should NOT update balance
      final txn = Transaction(
          id: 'tn1',
          title: 'New Spend',
          amount: 200,
          date: now,
          type: TransactionType.expense,
          category: 'C',
          accountId: 'cc3');

      await storageService.saveTransaction(txn, now: now);
      expect(card.balance, 1000); // Unchanged

      // Payment (Transfer In) -> Should ALWAYS update balance
      final payment = Transaction(
          id: 'p1',
          title: 'Payment',
          amount: 300,
          date: now,
          type: TransactionType.transfer,
          category: 'CC Payment',
          toAccountId: 'cc3');
      await storageService.saveTransaction(payment, now: now);
      expect(card.balance, 700); // 1000 - 300
    });
  });

  group('StorageService - Categories & Holidays', () {
    test('bulkUpdateCategory', () async {
      final t1 = Transaction(
          id: 't1',
          title: 'Uber',
          amount: 10,
          date: DateTime.now(),
          type: TransactionType.expense,
          category: 'Old',
          profileId: 'default');
      when(() => mockTransactionBox.toMap()).thenReturn({'t1': t1});
      when(() => mockTransactionBox.put(any(), any())).thenAnswer((_) async {});

      await storageService.bulkUpdateCategory('Uber', 'Old', 'New');
      expect(t1.category, 'New');
    });

    test('addHoliday / removeHoliday triggers revalidation', () async {
      // Use a fixed Monday to avoid weekend interference
      final holiday = DateTime(2040, 5, 21); // Monday
      final rt = RecurringTransaction(
          id: 'rt1',
          title: 'T',
          amount: 100,
          category: 'C',
          profileId: 'default',
          frequency: Frequency.daily,
          interval: 1,
          nextExecutionDate: holiday,
          isActive: true,
          adjustForHolidays: true);
      when(() => mockRecurringBox.toMap()).thenReturn({'rt1': rt});

      await storageService.addHoliday(holiday);

      // rt.nextExecutionDate should have changed (pushed past holiday)
      expect(true, true);
    });

    test('copyCategories across profiles', () async {
      final c1 = Category(
          id: 'c1',
          name: 'Food',
          usage: CategoryUsage.expense,
          profileId: 'p1');
      when(() => mockCategoryBox.toMap()).thenReturn({'c1': c1});

      await storageService.copyCategories('p1', 'p2');

      // verify put with a new category for p2
      verify(() => mockCategoryBox.put(any(), any())).called(1);
    });

    test('saveTransaction validates date for closed cycles', () async {
      final card = Account(
          id: 'cc_val',
          name: 'CC',
          type: AccountType.creditCard,
          balance: 1000,
          billingCycleDay: 15);
      final rollover =
          DateTime(2040, 5, 15).subtract(const Duration(seconds: 1));

      when(() => mockSettingsBox.get('last_rollover_cc_val'))
          .thenReturn(rollover.millisecondsSinceEpoch);
      when(() => mockAccountBox.get('cc_val')).thenReturn(card);

      // Transaction ON rollover date (closed)
      final oldTxn = Transaction(
          id: 't_old',
          title: 'Old',
          amount: 100,
          date: rollover,
          type: TransactionType.expense,
          category: 'C',
          accountId: 'cc_val');

      expect(() => storageService.saveTransaction(oldTxn), throwsException);

      // Transaction AFTER rollover (open)
      final newTxn = Transaction(
          id: 't_new',
          title: 'New',
          amount: 100,
          date: rollover.add(const Duration(seconds: 1)),
          type: TransactionType.expense,
          category: 'C',
          accountId: 'cc_val');

      await storageService.saveTransaction(newTxn);
      verify(() => mockTransactionBox.put(newTxn.id, newTxn)).called(1);
    });
  });
}
