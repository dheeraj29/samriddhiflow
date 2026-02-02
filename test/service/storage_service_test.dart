import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:samriddhi_flow/models/account.dart';
import 'package:samriddhi_flow/models/transaction.dart';
import 'package:samriddhi_flow/models/profile.dart';
import 'package:samriddhi_flow/models/loan.dart';
import 'package:samriddhi_flow/models/recurring_transaction.dart';
import 'package:samriddhi_flow/models/category.dart';
import 'package:samriddhi_flow/services/storage_service.dart';

class MockHiveInterface extends Mock implements HiveInterface {}

class MockBox<T> extends Mock implements Box<T> {}

void main() {
  late MockHiveInterface mockHive;
  late MockBox<Account> mockAccountBox;
  late MockBox<Transaction> mockTransactionBox;
  late MockBox<dynamic> mockSettingsBox;
  late MockBox<Profile> mockProfileBox;
  late MockBox<Loan> mockLoanBox;
  late MockBox<RecurringTransaction> mockRecurringBox;
  late MockBox<Category> mockCategoryBox;
  late StorageService storageService;

  setUpAll(() {
    registerFallbackValue(Transaction.create(
      title: '',
      amount: 0,
      date: DateTime.now(),
      type: TransactionType.expense,
      category: '',
    ));
    registerFallbackValue(
        Account(id: 'dummy', name: '', type: AccountType.savings));
  });

  setUp(() {
    mockHive = MockHiveInterface();
    mockAccountBox = MockBox<Account>();
    mockTransactionBox = MockBox<Transaction>();
    mockSettingsBox = MockBox<dynamic>();
    mockProfileBox = MockBox<Profile>();
    mockLoanBox = MockBox<Loan>();
    mockRecurringBox = MockBox<RecurringTransaction>();
    mockCategoryBox = MockBox<Category>();

    // Mock all box variants with specific types and names
    when(() => mockHive.box<Account>(any())).thenReturn(mockAccountBox);
    when(() => mockHive.box<Transaction>(any())).thenReturn(mockTransactionBox);
    when(() => mockHive.box(any())).thenReturn(mockSettingsBox);
    when(() => mockHive.box<Profile>(any())).thenReturn(mockProfileBox);
    when(() => mockHive.box<Loan>(any())).thenReturn(mockLoanBox);
    when(() => mockHive.box<RecurringTransaction>(any()))
        .thenReturn(mockRecurringBox);
    when(() => mockHive.box<Category>(any())).thenReturn(mockCategoryBox);
    when(() => mockHive.box<dynamic>(any())).thenReturn(mockSettingsBox);

    // Default Stubs
    when(() => mockSettingsBox.get(any(),
        defaultValue: any(named: 'defaultValue'))).thenReturn(null);
    when(() => mockSettingsBox.get('activeProfileId',
        defaultValue: any(named: 'defaultValue'))).thenReturn('default');
    when(() => mockSettingsBox.get('txnsSinceBackup',
        defaultValue: any(named: 'defaultValue'))).thenReturn(0);
    when(() => mockSettingsBox.put(any(), any())).thenAnswer((_) async {});
    when(() => mockSettingsBox.delete(any())).thenAnswer((_) async {});

    when(() => mockAccountBox.get(any())).thenReturn(null);
    when(() => mockAccountBox.put(any(), any())).thenAnswer((_) async {});
    when(() => mockAccountBox.delete(any())).thenAnswer((_) async {});
    when(() => mockAccountBox.values).thenReturn([]);

    when(() => mockTransactionBox.get(any())).thenReturn(null);
    when(() => mockTransactionBox.put(any(), any())).thenAnswer((_) async {});
    when(() => mockTransactionBox.delete(any())).thenAnswer((_) async {});
    when(() => mockTransactionBox.values).thenReturn([]);

    when(() => mockLoanBox.values).thenReturn([]);
    when(() => mockLoanBox.delete(any())).thenAnswer((_) async {});

    when(() => mockRecurringBox.values).thenReturn([]);
    when(() => mockRecurringBox.delete(any())).thenAnswer((_) async {});

    when(() => mockCategoryBox.values).thenReturn([]);
    when(() => mockCategoryBox.delete(any())).thenAnswer((_) async {});

    when(() => mockProfileBox.delete(any())).thenAnswer((_) async {});

    storageService = StorageService(mockHive);
  });

  group('StorageService', () {
    test('deleteAccount removes rollover settings', () async {
      final accountId = 'acc123';
      await storageService.deleteAccount(accountId);

      verify(() => mockAccountBox.delete(accountId)).called(1);
      verify(() => mockSettingsBox.delete('last_rollover_$accountId'))
          .called(1);
    });

    test('deleteProfile removes all associated account settings', () async {
      final profileId = 'prof1';
      final account1 = Account(
          id: 'a1',
          name: 'A1',
          type: AccountType.savings,
          profileId: profileId);
      final account2 = Account(
          id: 'a2',
          name: 'A2',
          type: AccountType.creditCard,
          profileId: profileId);

      when(() => mockAccountBox.values).thenReturn([account1, account2]);

      await storageService.deleteProfile(profileId);

      verify(() => mockProfileBox.delete(profileId)).called(1);
      verify(() => mockSettingsBox.delete('last_rollover_${account1.id}'))
          .called(1);
      verify(() => mockSettingsBox.delete('last_rollover_${account2.id}'))
          .called(1);
    });

    test('Credit Card Unbilled impact ignores balance update', () async {
      final cc = Account(
        id: 'cc1',
        name: 'Credit Card',
        type: AccountType.creditCard,
        balance: 0,
        billingCycleDay: 15,
      );
      final now = DateTime(2024, 11, 20);
      final txn = Transaction.create(
        title: 'Shop',
        amount: 100,
        type: TransactionType.expense,
        category: 'Shop',
        accountId: cc.id,
        date: DateTime(2024, 11, 16),
      );

      when(() => mockAccountBox.get(cc.id)).thenReturn(cc);

      await storageService.saveTransaction(txn, now: now);

      // Verify balance was NOT modified (should still be 0.0)
      expect(cc.balance, 0.0);

      // Also verify that the transaction was put into the box
      verify(() => mockTransactionBox.put(txn.id, txn)).called(1);
    });
  });
}
