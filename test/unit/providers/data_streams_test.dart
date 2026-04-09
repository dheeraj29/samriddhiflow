import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/models/account.dart';
import 'package:samriddhi_flow/models/loan.dart';
import 'package:samriddhi_flow/models/recurring_transaction.dart';
import 'package:samriddhi_flow/models/taxes/tax_data_models.dart';
import 'package:samriddhi_flow/models/transaction.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/services/storage_service.dart';

class MockStorageService extends Mock implements StorageService {}

class TestProfileNotifier extends ProfileNotifier {
  final String _id;
  TestProfileNotifier(this._id);

  @override
  String build() => _id;
}

void main() {
  late MockStorageService mockStorageService;
  late Directory tempDir;

  setUpAll(() async {
    tempDir = Directory.systemTemp.createTempSync('data_streams_test');
    Hive.init(tempDir.path);

    void registerIfNot<T>(TypeAdapter<T> adapter) {
      if (!Hive.isAdapterRegistered(adapter.typeId)) {
        Hive.registerAdapter<T>(adapter);
      }
    }

    registerIfNot<Account>(AccountAdapter());
    registerIfNot<AccountType>(AccountTypeAdapter());
    registerIfNot<Transaction>(TransactionAdapter());
    registerIfNot<TransactionType>(TransactionTypeAdapter());
    registerIfNot<Loan>(LoanAdapter());
    registerIfNot<LoanType>(LoanTypeAdapter());
    registerIfNot<ReinvestmentType>(ReinvestmentTypeAdapter());
    registerIfNot<RecurringTransaction>(RecurringTransactionAdapter());
    registerIfNot<Frequency>(FrequencyAdapter());
    registerIfNot<ScheduleType>(ScheduleTypeAdapter());
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  setUp(() async {
    mockStorageService = MockStorageService();
    when(() => mockStorageService.checkCreditCardRollovers())
        .thenAnswer((_) async {});
    when(() => mockStorageService.setActiveProfileId(any()))
        .thenAnswer((_) async {});
  });

  group('accountsProvider', () {
    test('yields initial accounts and reacts to box changes', () async {
      final accounts = [
        Account(
            id: 'a1',
            name: 'Acc 1',
            type: AccountType.savings,
            balance: 100,
            profileId: 'p1'),
      ];
      when(() => mockStorageService.getAccounts()).thenReturn(accounts);

      final container = ProviderContainer(
        overrides: [
          storageServiceProvider.overrideWithValue(mockStorageService),
          storageInitializerProvider.overrideWith((ref) async {}),
          activeProfileIdProvider.overrideWith(() => TestProfileNotifier('p1')),
        ],
      );

      if (!Hive.isBoxOpen('accounts')) await Hive.openBox<Account>('accounts');
      final box = Hive.box<Account>('accounts');
      await box.clear();

      List<Account>? result;
      final subscription = container.listen(accountsProvider, (prev, next) {
        next.whenData((val) => result = val);
      }, fireImmediately: true);

      await Future.delayed(const Duration(milliseconds: 50));
      expect(result, accounts);

      final newAccount = Account(
          id: 'a2',
          name: 'Acc 2',
          type: AccountType.savings,
          balance: 200,
          profileId: 'p1');
      final newAccounts = [...accounts, newAccount];
      when(() => mockStorageService.getAccounts()).thenReturn(newAccounts);

      await box.add(newAccount);
      await Future.delayed(const Duration(milliseconds: 100));
      expect(result, newAccounts);

      subscription.close();
      container.dispose();
    });

    test('refreshes accounts when active profile changes', () async {
      final profileOneAccounts = [
        Account(
            id: 'p1-a1',
            name: 'Profile 1 Acc',
            type: AccountType.savings,
            balance: 100,
            profileId: 'p1'),
      ];
      final profileTwoAccounts = [
        Account(
            id: 'p2-a1',
            name: 'Profile 2 Acc',
            type: AccountType.savings,
            balance: 200,
            profileId: 'p2'),
      ];

      when(() => mockStorageService.getAccounts())
          .thenReturn(profileOneAccounts);

      final container = ProviderContainer(
        overrides: [
          storageServiceProvider.overrideWithValue(mockStorageService),
          storageInitializerProvider.overrideWith((ref) async {}),
          activeProfileIdProvider.overrideWith(() => TestProfileNotifier('p1')),
        ],
      );

      List<Account>? result;
      final subscription = container.listen(accountsProvider, (prev, next) {
        next.whenData((val) => result = val);
      }, fireImmediately: true);

      await Future.delayed(const Duration(milliseconds: 50));
      expect(result?.single.profileId, 'p1');

      when(() => mockStorageService.getAccounts())
          .thenReturn(profileTwoAccounts);
      await container.read(activeProfileIdProvider.notifier).setProfile('p2');

      await Future.delayed(const Duration(milliseconds: 50));
      expect(result?.single.profileId, 'p2');
      verify(() => mockStorageService.setActiveProfileId('p2')).called(1);

      subscription.close();
      container.dispose();
    });
  });

  group('transactionsProvider', () {
    test('yields initial transactions and reacts to box changes', () async {
      final txns = [
        Transaction(
            id: 't1',
            title: 'T1',
            amount: 50,
            date: DateTime.now(),
            type: TransactionType.expense,
            category: 'c1',
            accountId: 'a1',
            profileId: 'p1'),
      ];
      when(() => mockStorageService.getTransactions()).thenReturn(txns);

      final container = ProviderContainer(
        overrides: [
          storageServiceProvider.overrideWithValue(mockStorageService),
          storageInitializerProvider.overrideWith((ref) async {}),
          activeProfileIdProvider.overrideWith(() => TestProfileNotifier('p1')),
        ],
      );

      if (!Hive.isBoxOpen('transactions')) {
        await Hive.openBox<Transaction>('transactions');
      }
      final box = Hive.box<Transaction>('transactions');
      await box.clear();

      List<Transaction>? result;
      final subscription = container.listen(transactionsProvider, (prev, next) {
        next.whenData((val) => result = val);
      }, fireImmediately: true);

      await Future.delayed(const Duration(milliseconds: 50));
      expect(result, txns);

      final newTxn = Transaction(
          id: 't2',
          title: 'T2',
          amount: 100,
          date: DateTime.now(),
          type: TransactionType.expense,
          category: 'c1',
          accountId: 'a1',
          profileId: 'p1');
      final newTxns = [...txns, newTxn];
      when(() => mockStorageService.getTransactions()).thenReturn(newTxns);

      await box.add(newTxn);
      await Future.delayed(const Duration(milliseconds: 100));
      expect(result, newTxns);

      subscription.close();
      container.dispose();
    });
  });

  group('loansProvider', () {
    test('yields initial loans and reacts to box changes', () async {
      final startDate = DateTime.now();
      final loans = [
        Loan(
            id: 'l1',
            name: 'Loan 1',
            totalPrincipal: 1000,
            remainingPrincipal: 1000,
            interestRate: 10,
            tenureMonths: 12,
            startDate: startDate,
            emiAmount: 100,
            firstEmiDate: startDate,
            profileId: 'p1'),
      ];
      when(() => mockStorageService.getLoans()).thenReturn(loans);

      final container = ProviderContainer(
        overrides: [
          storageServiceProvider.overrideWithValue(mockStorageService),
          storageInitializerProvider.overrideWith((ref) async {}),
          activeProfileIdProvider.overrideWith(() => TestProfileNotifier('p1')),
        ],
      );

      if (!Hive.isBoxOpen('loans')) await Hive.openBox<Loan>('loans');
      final box = Hive.box<Loan>('loans');
      await box.clear();

      List<Loan>? result;
      final subscription = container.listen(loansProvider, (prev, next) {
        next.whenData((val) => result = val);
      }, fireImmediately: true);

      await Future.delayed(const Duration(milliseconds: 50));
      expect(result, loans);

      final newLoan = Loan(
          id: 'l2',
          name: 'Loan 2',
          totalPrincipal: 2000,
          remainingPrincipal: 2000,
          interestRate: 12,
          tenureMonths: 24,
          startDate: startDate,
          emiAmount: 200,
          firstEmiDate: startDate,
          profileId: 'p1');
      final newLoans = [...loans, newLoan];
      when(() => mockStorageService.getLoans()).thenReturn(newLoans);

      await box.add(newLoan);
      await Future.delayed(const Duration(milliseconds: 100));
      expect(result, newLoans);

      subscription.close();
      container.dispose();
    });
  });

  group('recurringTransactionsProvider', () {
    test('yields initial recurring and reacts to box changes', () async {
      final recurring = [
        RecurringTransaction(
            id: 'r1',
            title: 'R1',
            amount: 50,
            category: 'c1',
            frequency: Frequency.monthly,
            nextExecutionDate: DateTime.now(),
            profileId: 'p1',
            type: TransactionType.expense),
      ];
      when(() => mockStorageService.getRecurring()).thenReturn(recurring);

      final container = ProviderContainer(
        overrides: [
          storageServiceProvider.overrideWithValue(mockStorageService),
          storageInitializerProvider.overrideWith((ref) async {}),
          activeProfileIdProvider.overrideWith(() => TestProfileNotifier('p1')),
        ],
      );

      if (!Hive.isBoxOpen('recurring')) {
        await Hive.openBox<RecurringTransaction>('recurring');
      }
      final box = Hive.box<RecurringTransaction>('recurring');
      await box.clear();

      List<RecurringTransaction>? result;
      final subscription =
          container.listen(recurringTransactionsProvider, (prev, next) {
        next.whenData((val) => result = val);
      }, fireImmediately: true);

      await Future.delayed(const Duration(milliseconds: 50));
      expect(result, recurring);

      final newRec = RecurringTransaction(
          id: 'r2',
          title: 'R2',
          amount: 100,
          category: 'c1',
          frequency: Frequency.monthly,
          nextExecutionDate: DateTime.now(),
          profileId: 'p1',
          type: TransactionType.expense);
      final newRecurring = [...recurring, newRec];
      when(() => mockStorageService.getRecurring()).thenReturn(newRecurring);

      await box.add(newRec);
      await Future.delayed(const Duration(milliseconds: 100));
      expect(result, newRecurring);

      subscription.close();
      container.dispose();
    });
  });
}
