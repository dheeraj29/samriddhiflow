import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:samriddhi_flow/services/storage_service.dart';
import 'package:samriddhi_flow/models/loan.dart';
import 'package:samriddhi_flow/models/recurring_transaction.dart';
import 'package:samriddhi_flow/models/category.dart';
import 'package:samriddhi_flow/models/lending_record.dart';
import 'package:samriddhi_flow/models/taxes/insurance_policy.dart';
import 'package:samriddhi_flow/models/taxes/tax_data.dart';
import 'package:samriddhi_flow/models/profile.dart';
import 'package:samriddhi_flow/models/account.dart';
import 'package:samriddhi_flow/models/transaction.dart';

class MockHive extends Mock implements HiveInterface {}

class MockBox<T> extends Mock implements Box<T> {}

void main() {
  late StorageService storageService;
  late MockHive mockHive;
  late MockBox<dynamic> mockSettingsBox;
  late MockBox<Loan> mockLoanBox;
  late MockBox<RecurringTransaction> mockRecurringBox;
  late MockBox<Category> mockCategoryBox;
  late MockBox<InsurancePolicy> mockInsuranceBox;
  late MockBox<TaxYearData> mockTaxBox;
  late MockBox<LendingRecord> mockLendingBox;
  late MockBox<Profile> mockProfileBox;
  late MockBox<Account> mockAccountBox;
  late MockBox<Transaction> mockTransactionBox;

  setUpAll(() {
    registerFallbackValue(Loan(
        id: 'f',
        name: 'f',
        totalPrincipal: 0,
        remainingPrincipal: 0,
        interestRate: 0,
        tenureMonths: 0,
        startDate: DateTime.now(),
        emiAmount: 0,
        firstEmiDate: DateTime.now()));
    registerFallbackValue(RecurringTransaction(
        id: 'f',
        title: 'f',
        amount: 0,
        category: 'f',
        accountId: 'f',
        frequency: Frequency.monthly,
        nextExecutionDate: DateTime.now()));
    registerFallbackValue(
        Category(id: 'f', name: 'f', usage: CategoryUsage.expense));
    registerFallbackValue(InsurancePolicy(
        id: 'f',
        policyName: 'f',
        policyNumber: 'f',
        annualPremium: 0,
        sumAssured: 0,
        startDate: DateTime.now(),
        maturityDate: DateTime.now()));
    registerFallbackValue(LendingRecord(
        id: 'f',
        personName: 'f',
        amount: 0,
        reason: 'f',
        date: DateTime.now(),
        type: LendingType.lent));
    registerFallbackValue(TaxYearData(year: 2025));
    registerFallbackValue(Account(
        id: 'f',
        name: 'f',
        type: AccountType.savings,
        balance: 0,
        profileId: 'default'));
    registerFallbackValue(Transaction(
        id: 'f',
        title: 'f',
        amount: 0,
        date: DateTime.now(),
        type: TransactionType.expense,
        category: 'Food',
        profileId: 'default'));
  });

  setUp(() {
    mockHive = MockHive();
    mockSettingsBox = MockBox<dynamic>();
    mockLoanBox = MockBox<Loan>();
    mockRecurringBox = MockBox<RecurringTransaction>();
    mockCategoryBox = MockBox<Category>();
    mockInsuranceBox = MockBox<InsurancePolicy>();
    mockTaxBox = MockBox<TaxYearData>();
    mockLendingBox = MockBox<LendingRecord>();
    mockProfileBox = MockBox<Profile>();
    mockAccountBox = MockBox<Account>();
    mockTransactionBox = MockBox<Transaction>();

    when(() => mockHive.box(StorageService.boxSettings))
        .thenReturn(mockSettingsBox);
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
    when(() => mockHive.box<Profile>(StorageService.boxProfiles))
        .thenReturn(mockProfileBox);
    when(() => mockHive.box<Account>(StorageService.boxAccounts))
        .thenReturn(mockAccountBox);
    when(() => mockHive.box<Transaction>(StorageService.boxTransactions))
        .thenReturn(mockTransactionBox);

    when(() => mockHive.isBoxOpen(any())).thenReturn(true);

    // Default toMap mocks to avoid Null errors
    when(() => mockLoanBox.toMap()).thenReturn({});
    when(() => mockRecurringBox.toMap()).thenReturn({});
    when(() => mockCategoryBox.toMap()).thenReturn({});
    when(() => mockInsuranceBox.toMap()).thenReturn({});
    when(() => mockTaxBox.toMap()).thenReturn({});
    when(() => mockLendingBox.toMap()).thenReturn({});
    when(() => mockProfileBox.toMap()).thenReturn({});
    when(() => mockAccountBox.toMap()).thenReturn({});
    when(() => mockTransactionBox.toMap()).thenReturn({});

    storageService = StorageService(mockHive);

    when(() => mockSettingsBox.get('activeProfileId',
        defaultValue: any(named: 'defaultValue'))).thenReturn('default');
  });

  group('StorageService - Model CRUD Operations', () {
    test('Loan Operations', () async {
      final loan = Loan(
          id: 'l1',
          name: 'Home Loan',
          totalPrincipal: 1000000,
          remainingPrincipal: 1000000,
          interestRate: 8.5,
          tenureMonths: 120,
          startDate: DateTime.now(),
          emiAmount: 12000,
          firstEmiDate: DateTime.now(),
          profileId: 'default');
      when(() => mockLoanBox.put('l1', any())).thenAnswer((_) async {});
      when(() => mockLoanBox.toMap()).thenReturn({'l1': loan});
      when(() => mockLoanBox.delete('l1')).thenAnswer((_) async {});

      await storageService.saveLoan(loan);
      expect(storageService.getAllLoans(), contains(loan));
      await storageService.deleteLoan('l1');
      verify(() => mockLoanBox.delete('l1')).called(1);
    });

    test('Recurring Transaction Operations', () async {
      final rt = RecurringTransaction(
          id: 'rt1',
          title: 'Rent',
          amount: 20000,
          category: 'Rent',
          accountId: 'a1',
          frequency: Frequency.monthly,
          nextExecutionDate: DateTime.now(),
          profileId: 'default');
      when(() => mockRecurringBox.put('rt1', any())).thenAnswer((_) async {});
      when(() => mockRecurringBox.toMap()).thenReturn({'rt1': rt});
      when(() => mockRecurringBox.delete('rt1')).thenAnswer((_) async {});

      await storageService.saveRecurringTransaction(rt);
      expect(storageService.getAllRecurring(), contains(rt));
      await storageService.deleteRecurringTransaction('rt1');
      verify(() => mockRecurringBox.delete('rt1')).called(1);
    });

    test('Category Operations', () async {
      final cat = Category(
          id: 'c1',
          name: 'Food',
          usage: CategoryUsage.expense,
          profileId: 'default');
      when(() => mockCategoryBox.put('c1', any())).thenAnswer((_) async {});
      when(() => mockCategoryBox.toMap()).thenReturn({'c1': cat});
      when(() => mockCategoryBox.delete('c1')).thenAnswer((_) async {});

      await storageService.addCategory(cat);
      expect(storageService.getAllCategories(), contains(cat));
      await storageService.removeCategory('c1');
      verify(() => mockCategoryBox.delete('c1')).called(1);
    });

    test('Insurance Policy Operations', () async {
      final policy = InsurancePolicy(
          id: 'p1',
          policyName: 'Term',
          policyNumber: '1',
          annualPremium: 10000,
          sumAssured: 10000000,
          startDate: DateTime.now(),
          maturityDate: DateTime.now().add(const Duration(days: 365)));
      when(() => mockInsuranceBox.clear()).thenAnswer((_) async => 0);
      when(() => mockInsuranceBox.put('p1', any())).thenAnswer((_) async {});
      when(() => mockInsuranceBox.values).thenReturn([policy]);

      await storageService.saveInsurancePolicies([policy]);
      expect(storageService.getInsurancePolicies(), contains(policy));
    });

    test('Lending Record Operations', () async {
      final record = LendingRecord(
          id: 'lr1',
          personName: 'John',
          amount: 5000,
          reason: 'Rent',
          date: DateTime.now(),
          type: LendingType.lent,
          profileId: 'default');
      when(() => mockLendingBox.put('lr1', any())).thenAnswer((_) async {});
      when(() => mockLendingBox.toMap()).thenReturn({'lr1': record});
      when(() => mockLendingBox.delete('lr1')).thenAnswer((_) async {});

      await storageService.saveLendingRecord(record);
      expect(storageService.getLendingRecords(), contains(record));
      await storageService.deleteLendingRecord('lr1');
      verify(() => mockLendingBox.delete('lr1')).called(1);
    });

    test('Tax Year Data Operations', () async {
      final taxData = TaxYearData(year: 2025);
      when(() => mockTaxBox.put(2025, any())).thenAnswer((_) async {});
      when(() => mockTaxBox.get(2025)).thenReturn(taxData);

      await storageService.saveTaxYearData(taxData);
      expect(storageService.getTaxYearData(2025), taxData);
    });
  });

  group('StorageService - Transaction Impact & Rollover', () {
    test('saveTransaction applies impact to account balance', () async {
      final account = Account(
          id: 'a1',
          name: 'A1',
          type: AccountType.savings,
          balance: 1000,
          profileId: 'default');
      final txn = Transaction(
          id: 't1',
          title: 'T1',
          amount: 200,
          date: DateTime.now(),
          type: TransactionType.expense,
          category: 'Food',
          accountId: 'a1',
          profileId: 'default');

      when(() => mockAccountBox.get('a1')).thenReturn(account);
      when(() => mockAccountBox.put('a1', any())).thenAnswer((_) async {});
      when(() => mockTransactionBox.get('t1')).thenReturn(null);
      when(() => mockTransactionBox.put('t1', any())).thenAnswer((_) async {});
      when(() => mockSettingsBox.get('txnsSinceBackup', defaultValue: 0))
          .thenReturn(0);
      when(() => mockSettingsBox.put('txnsSinceBackup', any()))
          .thenAnswer((_) async {});

      await storageService.saveTransaction(txn);

      expect(account.balance, 800);
      verify(() => mockAccountBox.put('a1', account)).called(1);
    });

    test('deleteTransaction reverses impact', () async {
      final account = Account(
          id: 'a1',
          name: 'A1',
          type: AccountType.savings,
          balance: 800,
          profileId: 'default');
      final txn = Transaction(
          id: 't1',
          title: 'T1',
          amount: 200,
          date: DateTime.now(),
          type: TransactionType.expense,
          category: 'Food',
          accountId: 'a1',
          profileId: 'default');

      when(() => mockTransactionBox.get('t1')).thenReturn(txn);
      when(() => mockAccountBox.get('a1')).thenReturn(account);
      when(() => mockAccountBox.put('a1', any())).thenAnswer((_) async {});
      when(() => mockTransactionBox.put('t1', any())).thenAnswer((_) async {});

      await storageService.deleteTransaction('t1');

      expect(account.balance, 1000);
      expect(txn.isDeleted, true);
    });

    test('restoreTransaction reapplies impact', () async {
      final account = Account(
          id: 'a1',
          name: 'A1',
          type: AccountType.savings,
          balance: 1000,
          profileId: 'default');
      final txn = Transaction(
          id: 't1',
          title: 'T1',
          amount: 200,
          date: DateTime.now(),
          type: TransactionType.expense,
          category: 'Food',
          accountId: 'a1',
          profileId: 'default',
          isDeleted: true);

      when(() => mockTransactionBox.get('t1')).thenReturn(txn);
      when(() => mockAccountBox.get('a1')).thenReturn(account);
      when(() => mockAccountBox.put('a1', any())).thenAnswer((_) async {});
      when(() => mockTransactionBox.put('t1', any())).thenAnswer((_) async {});

      await storageService.restoreTransaction('t1');

      expect(account.balance, 800);
      expect(txn.isDeleted, false);
    });

    test('checkCreditCardRollovers updates balance correctly', () async {
      // Mock CC Account
      final ccAccount = Account(
          id: 'cc1',
          name: 'CC',
          type: AccountType.creditCard,
          balance: 5000,
          billingCycleDay: 15,
          profileId: 'default');

      final now = DateTime(2025, 2, 20); // After cycle day 15
      // Cycle start: Jan 15. Previous cycle end: Jan 15.
      // We want to test rollover of transactions between last rollover and target rollover.

      final lastRollover = DateTime(2025, 1, 1).millisecondsSinceEpoch;
      when(() => mockAccountBox.toMap()).thenReturn({'cc1': ccAccount});
      when(() => mockSettingsBox.get('last_rollover_cc1'))
          .thenReturn(lastRollover);
      when(() => mockSettingsBox.get('ignore_rollover_payments_cc1',
          defaultValue: false)).thenReturn(false);
      when(() => mockSettingsBox.put(any(), any())).thenAnswer((_) async {});
      when(() => mockAccountBox.put('cc1', any())).thenAnswer((_) async {});

      // Transaction in the window
      final txnInWindow = Transaction(
          id: 't_window',
          title: 'Spend',
          amount: 1000,
          date: DateTime(2025, 1, 10),
          type: TransactionType.expense,
          category: 'Food',
          accountId: 'cc1',
          profileId: 'default');

      when(() => mockTransactionBox.toMap()).thenReturn({'tw': txnInWindow});

      await storageService.checkCreditCardRollovers(nowOverride: now);

      // 5000 + 1000 = 6000
      expect(ccAccount.balance, 6000);
      verify(() => mockSettingsBox.put('last_rollover_cc1', any())).called(1);
    });
    test('recalculateAccountBalance rebuilds balance from history', () async {
      final account = Account(
          id: 'a1',
          name: 'A1',
          type: AccountType.savings,
          balance: 0,
          profileId: 'default');
      final t1 = Transaction(
          id: 't1',
          title: 'T1',
          amount: 500,
          date: DateTime(2025, 1, 1),
          type: TransactionType.income,
          category: 'Salary',
          accountId: 'a1',
          profileId: 'default');
      final t2 = Transaction(
          id: 't2',
          title: 'T2',
          amount: 200,
          date: DateTime(2025, 1, 2),
          type: TransactionType.expense,
          category: 'Food',
          accountId: 'a1',
          profileId: 'default');

      when(() => mockAccountBox.get('a1')).thenReturn(account);
      when(() => mockTransactionBox.toMap()).thenReturn({'t1': t1, 't2': t2});
      when(() => mockAccountBox.put('a1', any())).thenAnswer((_) async {});

      await storageService.recalculateAccountBalance('a1');

      // 0 + 500 - 200 = 300
      expect(account.balance, 300);
    });

    test('copyCategories correctly copies categories between profiles',
        () async {
      final c1 = Category(
          id: 'c1',
          name: 'Food',
          usage: CategoryUsage.expense,
          profileId: 'p1');
      final c2 = Category(
          id: 'c2',
          name: 'Rent',
          usage: CategoryUsage.expense,
          profileId: 'p1');

      when(() => mockCategoryBox.toMap()).thenReturn({'c1': c1, 'c2': c2});
      when(() => mockCategoryBox.put(any(), any())).thenAnswer((_) async {});

      await storageService.copyCategories('p1', 'p2');

      // Verify two categories were created for p2 (excluding existing duplicates if any)
      verify(() => mockCategoryBox.put(any(), any())).called(2);
    });

    test('advanceRecurringTransactionDate calculates next date', () async {
      final rt = RecurringTransaction(
          id: 'rt1',
          title: 'Rent',
          amount: 1000,
          category: 'Rent',
          frequency: Frequency.monthly,
          interval: 1,
          nextExecutionDate: DateTime(2025, 1, 1),
          profileId: 'default');

      when(() => mockRecurringBox.get('rt1')).thenReturn(rt);
      when(() => mockRecurringBox.put('rt1', rt)).thenAnswer((_) async {});
      when(() => mockSettingsBox.get('holidays',
          defaultValue: any(named: 'defaultValue'))).thenReturn([]);

      await storageService.advanceRecurringTransactionDate('rt1');

      expect(rt.nextExecutionDate, DateTime(2025, 2, 1));
      verify(() => mockRecurringBox.put('rt1', rt)).called(1);
    });
  });
}
