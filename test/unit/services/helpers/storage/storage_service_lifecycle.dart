import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:samriddhi_flow/services/storage_service.dart';
import 'package:samriddhi_flow/models/account.dart';
import 'package:samriddhi_flow/models/transaction.dart';
import 'package:samriddhi_flow/models/loan.dart';
import 'package:samriddhi_flow/models/recurring_transaction.dart';
import 'package:samriddhi_flow/models/profile.dart';
import 'package:samriddhi_flow/models/category.dart';
import 'package:samriddhi_flow/models/taxes/insurance_policy.dart';
import 'package:samriddhi_flow/models/taxes/tax_data.dart';
import 'package:samriddhi_flow/models/lending_record.dart';
import 'package:samriddhi_flow/models/investment.dart';

class MockHive extends Mock implements HiveInterface {}

class MockBox<T> extends Mock implements Box<T> {}

void registerStorageServiceLifecycleTests() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StorageService storageService;
  late MockHive mockHive;
  late MockBox<Account> mockAccountBox;
  late MockBox<Transaction> mockTransactionBox;
  late MockBox<dynamic> mockSettingsBox;
  late MockBox<Loan> mockLoanBox;
  late MockBox<RecurringTransaction> mockRecurringBox;
  late MockBox<Profile> mockProfileBox;
  late MockBox<Category> mockCategoryBox;
  late MockBox<InsurancePolicy> mockInsuranceBox;
  late MockBox<TaxYearData> mockTaxBox;
  late MockBox<LendingRecord> mockLendingBox;
  late MockBox<Investment> mockInvestmentBox;
  late Map<String, dynamic> settingsMap;

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
    registerFallbackValue(
        Category(id: 'f', name: 'f', usage: CategoryUsage.expense));
    registerFallbackValue(Profile(id: 'f', name: 'f'));
    registerFallbackValue(Investment(
        id: 'f',
        name: 'f',
        type: InvestmentType.stock,
        acquisitionDate: DateTime.now(),
        acquisitionPrice: 0,
        quantity: 0));
  });

  setUp(() {
    mockHive = MockHive();
    mockAccountBox = MockBox<Account>();
    mockTransactionBox = MockBox<Transaction>();
    mockSettingsBox = MockBox<dynamic>();
    mockLoanBox = MockBox<Loan>();
    mockRecurringBox = MockBox<RecurringTransaction>();
    mockProfileBox = MockBox<Profile>();
    mockCategoryBox = MockBox<Category>();
    mockInsuranceBox = MockBox<InsurancePolicy>();
    mockTaxBox = MockBox<TaxYearData>();
    mockLendingBox = MockBox<LendingRecord>();
    mockInvestmentBox = MockBox<Investment>();
    settingsMap = {};

    when(() => mockHive.box<Account>(StorageService.boxAccounts))
        .thenReturn(mockAccountBox);
    when(() => mockHive.box<Transaction>(StorageService.boxTransactions))
        .thenReturn(mockTransactionBox);
    when(() => mockHive.box(StorageService.boxSettings))
        .thenReturn(mockSettingsBox);
    when(() => mockHive.box<Loan>(StorageService.boxLoans))
        .thenReturn(mockLoanBox);
    when(() => mockHive.box<RecurringTransaction>(StorageService.boxRecurring))
        .thenReturn(mockRecurringBox);
    when(() => mockHive.box<Profile>(StorageService.boxProfiles))
        .thenReturn(mockProfileBox);
    when(() => mockHive.box<Category>(StorageService.boxCategories))
        .thenReturn(mockCategoryBox);
    when(() =>
            mockHive.box<InsurancePolicy>(StorageService.boxInsurancePolicies))
        .thenReturn(mockInsuranceBox);
    when(() => mockHive.box<TaxYearData>(StorageService.boxTaxData))
        .thenReturn(mockTaxBox);
    when(() => mockHive.box<LendingRecord>(StorageService.boxLendingRecords))
        .thenReturn(mockLendingBox);
    when(() => mockHive.box<Investment>(StorageService.boxInvestments))
        .thenReturn(mockInvestmentBox);

    when(() => mockHive.isBoxOpen(any())).thenReturn(true);
    when(() => mockHive.openBox(any()))
        .thenAnswer((_) async => mockSettingsBox);
    when(() => mockHive.openBox<Account>(any()))
        .thenAnswer((_) async => mockAccountBox);
    when(() => mockHive.openBox<Transaction>(any()))
        .thenAnswer((_) async => mockTransactionBox);
    when(() => mockHive.openBox<Loan>(any()))
        .thenAnswer((_) async => mockLoanBox);
    when(() => mockHive.openBox<RecurringTransaction>(any()))
        .thenAnswer((_) async => mockRecurringBox);
    when(() => mockHive.openBox<Profile>(any()))
        .thenAnswer((_) async => mockProfileBox);
    when(() => mockHive.openBox<Category>(any()))
        .thenAnswer((_) async => mockCategoryBox);
    when(() => mockHive.openBox<InsurancePolicy>(any()))
        .thenAnswer((_) async => mockInsuranceBox);
    when(() => mockHive.openBox<TaxYearData>(any()))
        .thenAnswer((_) async => mockTaxBox);
    when(() => mockHive.openBox<LendingRecord>(any()))
        .thenAnswer((_) async => mockLendingBox);
    when(() => mockHive.openBox<Investment>(any()))
        .thenAnswer((_) async => mockInvestmentBox);

    // Stateful settings mock
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

    // Default necessary flags
    settingsMap['activeProfileId'] = 'default';
    when(() => mockAccountBox.toMap()).thenReturn({});
    when(() => mockTransactionBox.toMap()).thenReturn({});
    when(() => mockLoanBox.toMap()).thenReturn({});
    when(() => mockRecurringBox.toMap()).thenReturn({});
    when(() => mockProfileBox.toMap()).thenReturn({});
    when(() => mockCategoryBox.toMap()).thenReturn({});
    when(() => mockInsuranceBox.toMap()).thenReturn({});
    when(() => mockTaxBox.toMap()).thenReturn({});
    when(() => mockLendingBox.toMap()).thenReturn({});
    when(() => mockInvestmentBox.toMap()).thenReturn({});
    when(() => mockRecurringBox.values).thenReturn(const []);

    storageService = StorageService(mockHive);

    // Mock category asset load
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
      'flutter/assets',
      (message) async {
        final Uint8List encoded = utf8.encoder.convert('[]');
        return encoded.buffer.asByteData();
      },
    );
  });

  group('StorageService Advanced - Initialization', () {
    test('init creates default profile if box is empty', () async {
      when(() => mockProfileBox.isEmpty).thenReturn(true);
      when(() => mockProfileBox.put(any(), any())).thenAnswer((_) async {});
      when(() => mockCategoryBox.isEmpty).thenReturn(false);

      await storageService.init();

      verify(() => mockProfileBox.put('default', any())).called(1);
    });

    test('init migrates categories from old v2 list if found', () async {
      when(() => mockProfileBox.isEmpty).thenReturn(false);
      when(() => mockCategoryBox.isEmpty).thenReturn(true);
      final oldCat =
          Category(id: 'c1', name: 'Old', usage: CategoryUsage.expense);
      when(() => mockSettingsBox.get('categories_v2')).thenReturn([oldCat]);
      when(() => mockCategoryBox.put(any(), any())).thenAnswer((_) async {});

      await storageService.init();

      verify(() => mockCategoryBox.put('c1', any())).called(1);
    });
  });

  group('StorageService Advanced - Credit Card Rollover', () {
    test(
        'checkCreditCardRollovers rolls over unbilled spends to billed balance',
        () async {
      final acc = Account(
        id: 'cc1',
        name: 'Credit Card',
        type: AccountType.creditCard,
        balance: 1000,
        billingCycleDay: 15,
        profileId: 'default',
      );

      final now = DateTime(2024, 3, 16);
      final lastRollover = DateTime(2024, 1, 15);

      final txn = Transaction(
        id: 't1',
        title: 'Feb Spend',
        amount: 500,
        date: DateTime(2024, 2, 1),
        type: TransactionType.expense,
        category: 'Food',
        accountId: 'cc1',
        profileId: 'default',
        isDeleted: false,
      );

      when(() => mockAccountBox.toMap()).thenReturn({'cc1': acc});
      settingsMap['last_rollover_cc1'] = lastRollover.millisecondsSinceEpoch;
      settingsMap['ignore_rollover_payments_cc1'] = false;
      settingsMap['activeProfileId'] = 'default';
      when(() => mockTransactionBox.toMap()).thenReturn({'t1': txn});
      when(() => mockTransactionBox.values).thenReturn([txn]);
      when(() => mockAccountBox.put('cc1', any())).thenAnswer((_) async {});
      when(() => mockSettingsBox.put(any(), any())).thenAnswer((_) async {});

      await storageService.checkCreditCardRollovers(nowOverride: now);

      expect(acc.balance, 1500);
      verify(() => mockAccountBox.put('cc1', any())).called(1);
    });
  });

  group('StorageService Advanced - Update Billing Cycle', () {
    test('updateBillingCycle throws if balance is > 0', () async {
      final acc = Account(
        id: 'cc1',
        name: 'Credit Card',
        type: AccountType.creditCard,
        balance: 500, // Non-zero balance
        billingCycleDay: 15,
      );

      when(() => mockAccountBox.get('cc1')).thenReturn(acc);

      expect(
        () => storageService.updateBillingCycle(
          accountId: 'cc1',
          newCycleDay: 20,
          freezeDate: DateTime.now(),
          firstStatementDate: DateTime.now().add(const Duration(days: 30)),
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('updateBillingCycle sets freeze state successfully on 0 balance',
        () async {
      final acc = Account(
        id: 'cc2',
        name: 'Credit Card',
        type: AccountType.creditCard,
        balance: 0, // Valid balance
        billingCycleDay: 15,
      );

      final freezeDate = DateTime(2024, 6, 1);

      when(() => mockAccountBox.get('cc2')).thenReturn(acc);
      when(() => mockAccountBox.put('cc2', any())).thenAnswer((_) async {});
      when(() => mockSettingsBox.put('last_rollover_cc2', any()))
          .thenAnswer((_) async {});

      await storageService.updateBillingCycle(
        accountId: 'cc2',
        newCycleDay: 20,
        newDueDateDay: 5,
        freezeDate: freezeDate,
        firstStatementDate: freezeDate.add(const Duration(days: 15)),
      );

      final capturedAccount =
          verify(() => mockAccountBox.put('cc2', captureAny())).captured.first
              as Account;
      expect(capturedAccount.billingCycleDay, 20);
      expect(capturedAccount.paymentDueDateDay, 5);
      expect(capturedAccount.isFrozen, true);
      expect(capturedAccount.isFrozenCalculated, false);
      expect(capturedAccount.freezeDate, freezeDate);

      verify(() => mockSettingsBox.put('last_rollover_cc2', any())).called(1);
    });
  });

  group('StorageService Advanced - Transaction Restore', () {
    test('restoreTransaction reverses isDeleted and re-applies balance impact',
        () async {
      final acc = Account(
          id: 'acc1', name: 'S', type: AccountType.savings, balance: 1000);
      final txn = Transaction(
        id: 't1',
        title: 'Refund',
        amount: 200,
        date: DateTime.now(),
        type: TransactionType.income,
        category: 'Refund',
        accountId: 'acc1',
      );
      txn.isDeleted = true;

      when(() => mockTransactionBox.get('t1')).thenReturn(txn);
      when(() => mockAccountBox.get('acc1')).thenReturn(acc);
      when(() => mockTransactionBox.put('t1', any())).thenAnswer((_) async {});
      when(() => mockAccountBox.put('acc1', any())).thenAnswer((_) async {});

      await storageService.restoreTransaction('t1');

      expect(txn.isDeleted, false);
      expect(acc.balance, 1200);
      verify(() => mockAccountBox.put('acc1', any())).called(1);
    });
  });
}
