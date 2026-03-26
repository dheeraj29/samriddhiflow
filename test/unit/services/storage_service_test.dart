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
import 'package:samriddhi_flow/utils/billing_helper.dart';

class MockHive extends Mock implements HiveInterface {}

class MockBox<T> extends Mock implements Box<T> {}

class MockAccountBox extends Mock implements Box<Account> {}

class MockTransactionBox extends Mock implements Box<Transaction> {}

class MockProfileBox extends Mock implements Box<Profile> {}

class ProfileFake extends Fake implements Profile {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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
    registerFallbackValue(Loan(
      id: 'f',
      name: 'f',
      totalPrincipal: 0,
      remainingPrincipal: 0,
      interestRate: 0,
      tenureMonths: 0,
      startDate: DateTime.now(),
      emiAmount: 0,
      firstEmiDate: DateTime.now(),
    ));
    registerFallbackValue(RecurringTransaction(
      id: 'f',
      title: 'f',
      amount: 0,
      category: 'c',
      frequency: Frequency.monthly,
      nextExecutionDate: DateTime.now(),
    ));
    registerFallbackValue(InsurancePolicy(
      id: 'f',
      policyName: 'f',
      policyNumber: 'f',
      annualPremium: 0,
      sumAssured: 0,
      startDate: DateTime.now(),
      maturityDate: DateTime.now(),
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

    // Default mock for profile ID and backup counter
    when(() => mockSettingsBox.get('activeProfileId',
        defaultValue: any(named: 'defaultValue'))).thenReturn('default');
    when(() => mockSettingsBox.get('txnsSinceBackup',
        defaultValue: any(named: 'defaultValue'))).thenReturn(0);

    // Global mocks for put/delete to avoid TypeErrors in async calls
    when(() => mockSettingsBox.put(any(), any())).thenAnswer((_) async {});
    when(() => mockAccountBox.put(any(), any())).thenAnswer((_) async {});
    when(() => mockTransactionBox.put(any(), any())).thenAnswer((_) async {});
    when(() => mockLoanBox.put(any(), any())).thenAnswer((_) async {});
    when(() => mockRecurringBox.put(any(), any())).thenAnswer((_) async {});
    when(() => mockCategoryBox.put(any(), any())).thenAnswer((_) async {});
    when(() => mockInsuranceBox.put(any(), any())).thenAnswer((_) async {});
    when(() => mockTaxBox.put(any(), any())).thenAnswer((_) async {});
    when(() => mockLendingBox.put(any(), any())).thenAnswer((_) async {});

    when(() => mockSettingsBox.delete(any())).thenAnswer((_) async {});
    when(() => mockAccountBox.delete(any())).thenAnswer((_) async {});
    when(() => mockTransactionBox.delete(any())).thenAnswer((_) async {});
    when(() => mockProfileBox.delete(any())).thenAnswer((_) async {});
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
      // Removed local put mocks as they are now global in setUp

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
          billingCycleDay: 5,
          balance: 0);
      final newAcc = Account(
          id: 'cc1',
          name: 'CC',
          type: AccountType.creditCard,
          billingCycleDay: 10, // Forward move (both in past relative to 14th)
          balance: 0);

      when(() => mockAccountBox.get('cc1')).thenReturn(oldAcc);
      when(() => mockTransactionBox.toMap()).thenReturn({});
      // Mock isBilledAmountPaid to return false to allow reset
      when(() => mockSettingsBox.get(startsWith('last_rollover_cc1'),
          defaultValue: any(named: 'defaultValue'))).thenReturn(null);

      await storageService.saveAccount(newAcc);
      verify(() => mockSettingsBox.put(startsWith('last_rollover_cc1'), any()))
          .called(1);
    });

    test(
        'saveAccount triggers repair if cycle changed while balance is pending',
        () async {
      final oldAcc = Account(
          id: 'cc1',
          name: 'CC',
          type: AccountType.creditCard,
          billingCycleDay: 5,
          balance: 100.0 // Pending balance
          );
      final newAcc = Account(
          id: 'cc1',
          name: 'CC',
          type: AccountType.creditCard,
          billingCycleDay: 10,
          balance: 100.0);

      when(() => mockAccountBox.get('cc1')).thenReturn(oldAcc);
      when(() => mockTransactionBox.toMap()).thenReturn({});
      // Sync check mock
      when(() => mockSettingsBox.get('last_rollover_cc1'))
          .thenReturn(null); // Force sync check to fail if needed

      await storageService.saveAccount(newAcc);

      // Should NOT throw. Should call rollover reset
      verify(() => mockSettingsBox.put(startsWith('last_rollover_cc1'), any()))
          .called(1);
    });

    test('saveAccount handles backward cycle move with repair', () async {
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
          billingCycleDay: 5, // Backward move
          balance: 0);

      when(() => mockAccountBox.get('cc1')).thenReturn(oldAcc);
      when(() => mockTransactionBox.toMap()).thenReturn({});
      when(() => mockSettingsBox.get('last_rollover_cc1')).thenReturn(null);

      await storageService.saveAccount(newAcc);
      // Should succeed and trigger reset
      verify(() => mockSettingsBox.put(startsWith('last_rollover_cc1'), any()))
          .called(1);
    });

    test('isBilledAmountPaid returns true if rollover is caught up', () {
      final acc = Account(
          id: 'cc1',
          name: 'CC',
          type: AccountType.creditCard,
          billingCycleDay: 15,
          balance: 0);
      when(() => mockAccountBox.get('cc1')).thenReturn(acc);

      final now = DateTime.now();
      final currentCycleStart = BillingHelper.getCycleStart(now, 15);
      final paidRollover =
          currentCycleStart.subtract(const Duration(seconds: 1));

      when(() => mockSettingsBox.get('last_rollover_cc1'))
          .thenReturn(paidRollover.millisecondsSinceEpoch);

      expect(storageService.isBilledAmountPaid('cc1'), true);
    });

    test('getTransactionsByAccount filters by account and profile', () {
      final t1 = Transaction(
          id: 't1',
          title: 'T1',
          amount: 100,
          date: DateTime.now(),
          type: TransactionType.expense,
          category: 'C',
          accountId: 'acc1',
          profileId: 'p1');
      final t2 = Transaction(
          id: 't2',
          title: 'T2',
          amount: 200,
          date: DateTime.now(),
          type: TransactionType.expense,
          category: 'C',
          accountId: 'acc2',
          profileId: 'p1');
      final t3 = Transaction(
          id: 't3',
          title: 'T3',
          amount: 300,
          date: DateTime.now(),
          type: TransactionType.expense,
          category: 'C',
          accountId: 'acc1',
          profileId: 'p2');

      when(() => mockTransactionBox.toMap())
          .thenReturn({'t1': t1, 't2': t2, 't3': t3});
      when(() => mockSettingsBox.get('activeProfileId',
          defaultValue: any(named: 'defaultValue'))).thenReturn('p1');

      final result = storageService.getTransactionsByAccount('acc1');
      expect(result.length, 1);
      expect(result.first.id, 't1');
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

  group('StorageService - Transfer Edit Verification', () {
    test('Scenario 1: Saving -> Saving (Edit From and To accounts)', () async {
      final acc1 = Account(
          id: 'acc1', name: 'Save1', type: AccountType.savings, balance: 1000);
      final acc2 = Account(
          id: 'acc2', name: 'Save2', type: AccountType.savings, balance: 500);
      final acc3 = Account(
          id: 'acc3', name: 'Save3', type: AccountType.savings, balance: 200);
      final acc4 = Account(
          id: 'acc4', name: 'Save4', type: AccountType.savings, balance: 2000);

      final txn = Transaction(
        id: 't1',
        title: 'Transfer',
        amount: 100,
        date: DateTime.now(),
        type: TransactionType.transfer,
        category: 'Transfer',
        accountId: 'acc1',
        toAccountId: 'acc2',
      );

      when(() => mockAccountBox.get('acc1')).thenReturn(acc1);
      when(() => mockAccountBox.get('acc2')).thenReturn(acc2);
      when(() => mockAccountBox.get('acc3')).thenReturn(acc3);
      when(() => mockAccountBox.get('acc4')).thenReturn(acc4);
      when(() => mockTransactionBox.get('t1')).thenReturn(txn);

      final editedTxn =
          txn.copyWith(accountId: 'acc3', toAccountId: 'acc4', amount: 150);
      await storageService.saveTransaction(editedTxn);

      expect(acc1.balance, 1100);
      expect(acc2.balance, 400);
      expect(acc3.balance, 50);
      expect(acc4.balance, 2150);
    });

    test('Scenario 2: Saving -> Credit Card (Debt Decrease)', () async {
      final accSave = Account(
          id: 'save1',
          name: 'Savings',
          type: AccountType.savings,
          balance: 1000);
      final accCC = Account(
          id: 'cc1', name: 'CC', type: AccountType.creditCard, balance: 500);

      final txn = Transaction(
        id: 't2',
        title: 'CC Payment',
        amount: 100,
        date: DateTime.now(),
        type: TransactionType.transfer,
        category: 'Transfer',
        accountId: 'save1',
        toAccountId: 'cc1',
      );

      when(() => mockAccountBox.get('save1')).thenReturn(accSave);
      when(() => mockAccountBox.get('cc1')).thenReturn(accCC);
      when(() => mockTransactionBox.get('t2')).thenReturn(null);

      await storageService.saveTransaction(txn);
      expect(accSave.balance, 900);
      expect(accCC.balance, 400);

      final editedTxn = txn.copyWith(amount: 200);
      when(() => mockTransactionBox.get('t2')).thenReturn(txn);
      await storageService.saveTransaction(editedTxn);

      expect(accSave.balance, 800);
      expect(accCC.balance, 300);
    });

    test('Scenario 3: Credit Card -> Saving (Cash Advance/Debt Increase)',
        () async {
      final accCC = Account(
          id: 'cc1', name: 'CC', type: AccountType.creditCard, balance: 0);
      final accSave = Account(
          id: 'save1',
          name: 'Savings',
          type: AccountType.savings,
          balance: 100);

      final txn = Transaction(
        id: 't3',
        title: 'Cash Advance',
        amount: 50,
        date: DateTime.now(),
        type: TransactionType.transfer,
        category: 'Transfer',
        accountId: 'cc1',
        toAccountId: 'save1',
      );

      when(() => mockAccountBox.get('cc1')).thenReturn(accCC);
      when(() => mockAccountBox.get('save1')).thenReturn(accSave);
      when(() => mockTransactionBox.get('t3')).thenReturn(null);

      await storageService.saveTransaction(txn);
      expect(accCC.balance, 50);
      expect(accSave.balance, 150);

      final accSave2 = Account(
          id: 'save2',
          name: 'Savings 2',
          type: AccountType.savings,
          balance: 0);
      when(() => mockAccountBox.get('save2')).thenReturn(accSave2);
      final editedTxn = txn.copyWith(toAccountId: 'save2');
      when(() => mockTransactionBox.get('t3')).thenReturn(txn);

      await storageService.saveTransaction(editedTxn);
      expect(accCC.balance, 50);
      expect(accSave.balance, 100);
      expect(accSave2.balance, 50);
    });

    test('Scenario 4: Credit Card -> Credit Card (Balance Transfer)', () async {
      final cc1 = Account(
          id: 'cc1', name: 'CC1', type: AccountType.creditCard, balance: 1000);
      final cc2 = Account(
          id: 'cc2', name: 'CC2', type: AccountType.creditCard, balance: 0);

      final txn = Transaction(
        id: 't4',
        title: 'Balance Transfer',
        amount: 200,
        date: DateTime.now(),
        type: TransactionType.transfer,
        category: 'Transfer',
        accountId: 'cc1',
        toAccountId: 'cc2',
      );

      when(() => mockAccountBox.get('cc1')).thenReturn(cc1);
      when(() => mockAccountBox.get('cc2')).thenReturn(cc2);
      when(() => mockTransactionBox.get('t4')).thenReturn(null);

      await storageService.saveTransaction(txn);
      expect(cc1.balance, 1200);
      expect(cc2.balance, -200);

      final editedTxn = txn.copyWith(amount: 300);
      when(() => mockTransactionBox.get('t4')).thenReturn(txn);
      await storageService.saveTransaction(editedTxn);

      expect(cc1.balance, 1300);
      expect(cc2.balance, -300);
    });

    test('Scenario 5: CC -> Saving swap roles to Saving -> CC', () async {
      final accCC = Account(
          id: 'cc1', name: 'CC1', type: AccountType.creditCard, balance: 0);
      final accSave = Account(
          id: 'save1', name: 'Save1', type: AccountType.savings, balance: 1000);

      final txn = Transaction(
        id: 't5',
        title: 'Initial Transfer',
        amount: 100,
        date: DateTime.now(),
        type: TransactionType.transfer,
        category: 'Transfer',
        accountId: 'cc1',
        toAccountId: 'save1',
      );

      when(() => mockAccountBox.get('cc1')).thenReturn(accCC);
      when(() => mockAccountBox.get('save1')).thenReturn(accSave);
      when(() => mockTransactionBox.get('t5')).thenReturn(null);

      // Save initial: CC debt 0->100, Save balance 1000->1100
      await storageService.saveTransaction(txn);
      expect(accCC.balance, 100);
      expect(accSave.balance, 1100);

      // Edit: Swap roles to Save -> CC
      final editedTxn = txn.copyWith(
        accountId: 'save1',
        toAccountId: 'cc1',
        amount: 100,
      );
      when(() => mockTransactionBox.get('t5')).thenReturn(txn);

      await storageService.saveTransaction(editedTxn);

      // 1. Reverse initial (CC -> Save, 100):
      //    CC source reversed (debt 100->0)
      //    Save target reversed (balance 1100->1000)
      // 2. Apply new (Save -> CC, 100):
      //    Save source applied (balance 1000->900)
      //    CC target applied (debt 0-> -100)

      expect(accCC.balance, -100);
      expect(accSave.balance, 900);
    });
  });

  group('StorageService - Transaction Type Change Verification', () {
    test('Scenario 1: Income -> Expense', () async {
      final acc = Account(
          id: 'acc1',
          name: 'Savings',
          type: AccountType.savings,
          balance: 1000);
      final oldTxn = Transaction(
        id: 'ty1',
        title: 'Refund',
        amount: 200,
        date: DateTime.now(),
        type: TransactionType.income,
        category: 'Refund',
        accountId: 'acc1',
      );

      when(() => mockAccountBox.get('acc1')).thenReturn(acc);
      when(() => mockTransactionBox.get('ty1')).thenReturn(oldTxn);

      final newTxn = oldTxn.copyWith(
          type: TransactionType.expense, amount: 100, category: 'Food');
      await storageService.saveTransaction(newTxn);

      expect(acc.balance, 700);
    });

    test('Scenario 2: Income -> Transfer', () async {
      final acc1 = Account(
          id: 'acc1',
          name: 'Savings',
          type: AccountType.savings,
          balance: 1000);
      final acc2 = Account(
          id: 'acc2', name: 'Wallet', type: AccountType.savings, balance: 500);
      final oldTxn = Transaction(
        id: 'ty2',
        title: 'Gift',
        amount: 100,
        date: DateTime.now(),
        type: TransactionType.income,
        category: 'Gift',
        accountId: 'acc1',
      );

      when(() => mockAccountBox.get('acc1')).thenReturn(acc1);
      when(() => mockAccountBox.get('acc2')).thenReturn(acc2);
      when(() => mockTransactionBox.get('ty2')).thenReturn(oldTxn);

      final newTxn = oldTxn.copyWith(
          type: TransactionType.transfer, toAccountId: 'acc2', amount: 150);
      await storageService.saveTransaction(newTxn);

      expect(acc1.balance, 750);
      expect(acc2.balance, 650);
    });

    test('Scenario 3: Expense -> Transfer', () async {
      final acc1 = Account(
          id: 'acc1',
          name: 'Savings',
          type: AccountType.savings,
          balance: 1000);
      final acc2 = Account(
          id: 'acc2',
          name: 'Credit Card',
          type: AccountType.creditCard,
          balance: 0);
      final oldTxn = Transaction(
        id: 'ty3',
        title: 'Bill Pay',
        amount: 200,
        date: DateTime.now(),
        type: TransactionType.expense,
        category: 'Bills',
        accountId: 'acc1',
      );

      when(() => mockAccountBox.get('acc1')).thenReturn(acc1);
      when(() => mockAccountBox.get('acc2')).thenReturn(acc2);
      when(() => mockTransactionBox.get('ty3')).thenReturn(oldTxn);

      final newTxn = oldTxn.copyWith(
          type: TransactionType.transfer, toAccountId: 'acc2', amount: 200);
      await storageService.saveTransaction(newTxn);

      expect(acc1.balance, 1000);
      expect(acc2.balance, -200);
    });

    test('Scenario 4: Expense -> Income', () async {
      final acc = Account(
          id: 'acc1',
          name: 'Savings',
          type: AccountType.savings,
          balance: 1000);
      final oldTxn = Transaction(
        id: 'ty4',
        title: 'Error Entry',
        amount: 50,
        date: DateTime.now(),
        type: TransactionType.expense,
        category: 'Food',
        accountId: 'acc1',
      );

      when(() => mockAccountBox.get('acc1')).thenReturn(acc);
      when(() => mockTransactionBox.get('ty4')).thenReturn(oldTxn);

      final newTxn = oldTxn.copyWith(
          type: TransactionType.income, amount: 100, category: 'Refund');
      await storageService.saveTransaction(newTxn);

      expect(acc.balance, 1150);
    });
  });

  group('StorageService - CC Billing Locks', () {
    test('recalculateBilledAmount succeeds even if cycle is paid (Reset Lock)',
        () async {
      final acc = Account(
          id: 'paid_cc',
          name: 'Paid Card',
          type: AccountType.creditCard,
          balance: 0,
          billingCycleDay: 20);
      when(() => mockAccountBox.get('paid_cc')).thenReturn(acc);
      when(() => mockTransactionBox.toMap()).thenReturn({});

      // Setup rollover as "Paid"
      final now = DateTime.now();
      final currentCycleStart = BillingHelper.getCycleStart(now, 20);
      final paidRollover =
          currentCycleStart.subtract(const Duration(seconds: 1));
      when(() => mockSettingsBox.get('last_rollover_paid_cc'))
          .thenReturn(paidRollover.millisecondsSinceEpoch);

      await storageService.recalculateBilledAmount('paid_cc');
      // Should advance pointer back (trigger reset)
      verify(() => mockSettingsBox.put('last_rollover_paid_cc', any()))
          .called(1);
    });

    test('saveTransaction throws Exception if adding to a closed/paid cycle',
        () async {
      final acc = Account(
          id: 'paid_cc',
          name: 'Paid Card',
          type: AccountType.creditCard,
          balance: 0,
          billingCycleDay: 20);
      when(() => mockAccountBox.get('paid_cc')).thenReturn(acc);

      // Cycle Start is say 21st of previous month.
      // If today is 25th, current cycle started on 21st.
      // "Billed" cycle is before 21st.
      final now = DateTime.now();
      final currentCycleStart = BillingHelper.getCycleStart(now, 20);
      final paidRollover =
          currentCycleStart.subtract(const Duration(seconds: 1));
      when(() => mockSettingsBox.get('last_rollover_paid_cc'))
          .thenReturn(paidRollover.millisecondsSinceEpoch);

      // Try to add txn to the "Billed" cycle (e.g. 5 days ago)
      final billedDate = currentCycleStart.subtract(const Duration(days: 2));
      final txn = Transaction(
          id: 't_old',
          title: 'Late Entry',
          amount: 100,
          date: billedDate,
          type: TransactionType.expense,
          category: 'Food',
          accountId: 'paid_cc');

      when(() => mockTransactionBox.get('t_old')).thenReturn(null);

      // Note: If lastRollover is caught up, it might throw "closed" or "paid".
      // Both are correct forms of the lock.
      await expectLater(
          () => storageService.saveTransaction(txn),
          throwsA(isA<Exception>().having((e) => e.toString(), 'message',
              anyOf(contains('already marked as paid'), contains('closed')))));
    });

    test(
        'saveTransaction throws Exception if blocking old bill payment (transfer to CC)',
        () async {
      final acc = Account(
          id: 'paid_cc',
          name: 'Paid Card',
          type: AccountType.creditCard,
          balance: 0,
          billingCycleDay: 20);
      when(() => mockAccountBox.get('paid_cc')).thenReturn(acc);

      final now = DateTime.now();
      final currentCycleStart = BillingHelper.getCycleStart(now, 20);
      final paidRollover =
          currentCycleStart.subtract(const Duration(seconds: 1));
      when(() => mockSettingsBox.get('last_rollover_paid_cc'))
          .thenReturn(paidRollover.millisecondsSinceEpoch);

      // Try to add a Transfer (Payment) to the "Billed" cycle
      final billedDate = currentCycleStart.subtract(const Duration(days: 2));
      final txn = Transaction(
          id: 't_pay',
          title: 'Bill Payment',
          amount: 500,
          date: billedDate,
          type: TransactionType.transfer,
          category: 'Credit Card Bill',
          toAccountId: 'paid_cc');

      when(() => mockTransactionBox.get('t_pay')).thenReturn(null);

      await expectLater(
          () => storageService.saveTransaction(txn),
          throwsA(isA<Exception>().having((e) => e.toString(), 'message',
              anyOf(contains('already marked as paid'), contains('closed')))));
    });

    test(
        'deleteTransaction throws Exception if deleting from a closed/paid cycle',
        () async {
      final acc = Account(
          id: 'paid_cc',
          name: 'Paid Card',
          type: AccountType.creditCard,
          balance: 0,
          billingCycleDay: 20);
      when(() => mockAccountBox.get('paid_cc')).thenReturn(acc);

      final now = DateTime.now();
      final currentCycleStart = BillingHelper.getCycleStart(now, 20);
      final paidRollover =
          currentCycleStart.subtract(const Duration(seconds: 1));
      when(() => mockSettingsBox.get('last_rollover_paid_cc'))
          .thenReturn(paidRollover.millisecondsSinceEpoch);

      final billedDate = currentCycleStart.subtract(const Duration(days: 2));
      final txn = Transaction(
          id: 't_to_delete',
          title: 'Old Expense',
          amount: 100,
          date: billedDate,
          type: TransactionType.expense,
          category: 'Food',
          accountId: 'paid_cc');

      when(() => mockTransactionBox.get('t_to_delete')).thenReturn(txn);

      await expectLater(
          () => storageService.deleteTransaction('t_to_delete'),
          throwsA(isA<Exception>().having((e) => e.toString(), 'message',
              anyOf(contains('already marked as paid'), contains('closed')))));
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
