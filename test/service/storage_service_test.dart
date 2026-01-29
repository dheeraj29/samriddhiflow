import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/models/account.dart';
import 'package:samriddhi_flow/models/transaction.dart';
import 'package:samriddhi_flow/services/storage_service.dart';

class MockHiveInterface extends Mock implements HiveInterface {}

class MockBox<T> extends Mock implements Box<T> {}

void main() {
  late MockHiveInterface mockHive;
  late MockBox<Account> mockAccountBox;
  late MockBox<Transaction> mockTransactionBox;
  late MockBox<dynamic> mockSettingsBox;
  late StorageService storageService;

  setUpAll(() {
    registerFallbackValue(Account.create(
        name: 'fallback', type: AccountType.savings, initialBalance: 0));
    registerFallbackValue(Transaction.create(
        title: 'fallback',
        amount: 0,
        type: TransactionType.expense,
        category: 'fallback',
        accountId: 'id',
        date: DateTime.now()));
  });

  setUp(() {
    mockHive = MockHiveInterface();
    mockAccountBox = MockBox<Account>();
    mockTransactionBox = MockBox<Transaction>();
    mockSettingsBox = MockBox<dynamic>();

    when(() => mockHive.box<Account>(StorageService.boxAccounts))
        .thenReturn(mockAccountBox);
    when(() => mockHive.box<Transaction>(StorageService.boxTransactions))
        .thenReturn(mockTransactionBox);
    when(() => mockHive.box(StorageService.boxSettings))
        .thenReturn(mockSettingsBox);

    // Default Stubs
    when(() => mockSettingsBox.get('activeProfileId',
        defaultValue: any(named: 'defaultValue'))).thenReturn('default');
    when(() => mockSettingsBox.get('txnsSinceBackup',
        defaultValue: any(named: 'defaultValue'))).thenReturn(0);
    when(() => mockSettingsBox.put(any(), any())).thenAnswer((_) async {});

    when(() => mockAccountBox.put(any(), any())).thenAnswer((_) async {});
    when(() => mockTransactionBox.put(any(), any())).thenAnswer((_) async {});

    storageService = StorageService(mockHive);
  });

  test('saveTransaction updates account balance (Expense)', () async {
    final account = Account.create(
        name: 'Bank',
        type: AccountType.savings,
        initialBalance: 1000,
        profileId: 'default');

    final txn = Transaction.create(
        title: 'Food',
        amount: 200,
        type: TransactionType.expense,
        category: 'Food',
        accountId: account.id,
        date: DateTime.now(),
        profileId: 'default');

    when(() => mockTransactionBox.get(txn.id)).thenReturn(null); // New txn
    when(() => mockAccountBox.get(account.id)).thenReturn(account);

    await storageService.saveTransaction(txn);

    // Verify Account Balance Reduced (1000 - 200 = 800)
    verify(() => mockAccountBox.put(
        account.id,
        any(
            that: isA<Account>()
                .having((a) => a.balance, 'balance', 800.0)))).called(1);
    verify(() => mockTransactionBox.put(txn.id, txn)).called(1);
  });

  test('saveTransaction updates account balance (Income)', () async {
    final account = Account.create(
        name: 'Bank', type: AccountType.savings, initialBalance: 1000);
    final txn = Transaction.create(
        title: 'Salary',
        amount: 500,
        type: TransactionType.income,
        category: 'Job',
        accountId: account.id,
        date: DateTime.now());

    when(() => mockTransactionBox.get(txn.id)).thenReturn(null);
    when(() => mockAccountBox.get(account.id)).thenReturn(account);

    await storageService.saveTransaction(txn);

    verify(() => mockAccountBox.put(
        account.id,
        any(
            that: isA<Account>()
                .having((a) => a.balance, 'balance', 1500.0)))).called(1);
  });
}
