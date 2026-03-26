import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/screens/add_transaction_screen.dart';
import 'package:samriddhi_flow/models/transaction.dart';
import 'package:samriddhi_flow/models/recurring_transaction.dart';
import 'package:samriddhi_flow/models/category.dart';
import 'package:samriddhi_flow/models/account.dart';
import 'package:samriddhi_flow/services/storage_service.dart';

class MockStorageService extends Mock implements StorageService {}

class MockCurrencyNotifier extends CurrencyNotifier {
  @override
  String build() => 'en_US';
}

class MockProfileNotifier extends ProfileNotifier {
  @override
  String build() => 'default';
}

class MockTxnsSinceBackupNotifier extends TxnsSinceBackupNotifier {
  @override
  int build() => 0;
  @override
  void refresh() {}
}

class MockHolidaysNotifier extends HolidaysNotifier {
  @override
  List<DateTime> build() => [];
}

class MockCategoriesNotifier extends CategoriesNotifier {
  final List<Category> _initial;
  MockCategoriesNotifier(this._initial);
  @override
  List<Category> build() => _initial;
}

void main() {
  late MockStorageService mockStorageService;

  setUpAll(() {
    registerFallbackValue(Transaction.create(
        title: 't',
        amount: 1,
        date: DateTime.now(),
        type: TransactionType.expense,
        category: 'General'));
    registerFallbackValue(RecurringTransaction.create(
        title: 'r',
        amount: 1,
        category: 'General',
        frequency: Frequency.monthly,
        startDate: DateTime.now(),
        scheduleType: ScheduleType.fixedDate,
        type: TransactionType.expense));
  });

  setUp(() {
    mockStorageService = MockStorageService();
    when(() => mockStorageService.getAccounts()).thenReturn([]);
    when(() => mockStorageService.getCategories()).thenReturn([]);
    when(() => mockStorageService.saveTransaction(any()))
        .thenAnswer((_) async {});
    when(() => mockStorageService.saveRecurringTransaction(any()))
        .thenAnswer((_) async {});
    when(() =>
            mockStorageService.getSimilarTransactionCount(any(), any(), any()))
        .thenAnswer((_) async => 0);
    when(() => mockStorageService.bulkUpdateCategory(any(), any(), any()))
        .thenAnswer((_) async {});
    when(() => mockStorageService.advanceRecurringTransactionDate(any()))
        .thenAnswer((_) async {});
  });

  Widget createWidgetUnderTest({
    Transaction? transactionToEdit,
    TransactionType initialType = TransactionType.expense,
    List<Account>? accounts,
    List<Category>? categories,
    List<Transaction>? existingTransactions,
  }) {
    return ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(mockStorageService),
        currencyProvider.overrideWith(MockCurrencyNotifier.new),
        activeProfileIdProvider.overrideWith(MockProfileNotifier.new),
        txnsSinceBackupProvider.overrideWith(MockTxnsSinceBackupNotifier.new),
        holidaysProvider.overrideWith(MockHolidaysNotifier.new),
        accountsProvider.overrideWith((ref) => Stream.value(accounts ?? [])),
        transactionsProvider
            .overrideWith((ref) => Stream.value(existingTransactions ?? [])),
        if (categories != null)
          categoriesProvider
              .overrideWith(() => MockCategoriesNotifier(categories)),
      ],
      child: MaterialApp(
        home: AddTransactionScreen(
          initialType: initialType,
          transactionToEdit: transactionToEdit,
        ),
      ),
    );
  }

  group('AddTransactionScreen Tests', () {
    Future<void> tapSave(WidgetTester tester,
        {String text = 'Save Transaction'}) async {
      final btn = find.text(text);
      await tester.dragUntilVisible(
          btn, find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      await tester.tap(btn);
      await tester.pumpAndSettle();
    }

    testWidgets('Validates required fields', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await tapSave(tester);

      expect(find.text('Required'), findsOneWidget);
      expect(find.text('Invalid Amount'), findsOneWidget);
    });

    testWidgets('Saves Expense Transaction', (tester) async {
      final cats = [Category(id: '1', name: 'Food', usage: CategoryUsage.both)];
      when(() => mockStorageService.getCategories()).thenReturn(cats);

      await tester.pumpWidget(createWidgetUnderTest(categories: cats));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.ancestor(
              of: find.text('Description'),
              matching: find.byType(TextFormField)),
          'Lunch');
      await tester.enterText(
          find.ancestor(
              of: find.text('Amount'), matching: find.byType(TextFormField)),
          '150');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      await tapSave(tester);

      verify(() => mockStorageService.saveTransaction(any(
          that: isA<Transaction>()
              .having((t) => t.amount, 'amount', 150.0)))).called(1);
    });

    testWidgets('Transfer Transaction Flow', (tester) async {
      final accounts = [
        Account(
            id: '1', name: 'Bank', type: AccountType.savings, profileId: 'p'),
        Account(
            id: '2', name: 'Wallet', type: AccountType.wallet, profileId: 'p'),
      ];
      when(() => mockStorageService.getAccounts()).thenReturn(accounts);

      await tester.pumpWidget(createWidgetUnderTest(
          initialType: TransactionType.transfer, accounts: accounts));
      await tester.pumpAndSettle();

      // Setup Source
      final fromDropdown =
          find.widgetWithText(DropdownButtonFormField<String?>, 'From Account');
      await tester.tap(fromDropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Bank').last);
      await tester.pumpAndSettle();

      // Setup Target
      final toDropdown =
          find.widgetWithText(DropdownButtonFormField<String?>, 'To Account');
      await tester.tap(toDropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Wallet').last);
      await tester.pumpAndSettle();

      await tester.enterText(
          find.ancestor(
              of: find.text('Description'),
              matching: find.byType(TextFormField)),
          'Transfer Test');
      await tester.enterText(
          find.ancestor(
              of: find.text('Amount'), matching: find.byType(TextFormField)),
          '500');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      await tapSave(tester);

      verify(() => mockStorageService.saveTransaction(any(
          that: isA<Transaction>()
              .having((t) => t.type, 'type', TransactionType.transfer)
              .having((t) => t.accountId, 'from', '1')
              .having((t) => t.toAccountId, 'to', '2')))).called(1);
    });

    testWidgets('Edit Transaction Pre-fills Data', (tester) async {
      final txn = Transaction.create(
        title: 'Old Title',
        amount: 500,
        type: TransactionType.expense,
        category: 'Food',
        date: DateTime.now(),
      );

      final cats = [Category(id: '1', name: 'Food', usage: CategoryUsage.both)];
      when(() => mockStorageService.getCategories()).thenReturn(cats);

      await tester.pumpWidget(
          createWidgetUnderTest(transactionToEdit: txn, categories: cats));
      await tester.pumpAndSettle();

      expect(find.text('Old Title'), findsOneWidget);
      expect(find.text('500.00'), findsOneWidget);
      expect(find.text('Update Transaction'), findsOneWidget);

      await tester.enterText(
          find.ancestor(
              of: find.text('Description'),
              matching: find.byType(TextFormField)),
          'New Title');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      await tapSave(tester, text: 'Update Transaction');

      verify(() => mockStorageService.saveTransaction(any(
          that: isA<Transaction>()
              .having((t) => t.id, 'id', txn.id)
              .having((t) => t.title, 'title', 'New Title')))).called(1);
    });

    testWidgets('Capital Gain Fields Logic', (tester) async {
      final cats = [
        Category(
            id: '1',
            name: 'Stocks',
            usage: CategoryUsage.both,
            tag: CategoryTag.capitalGain)
      ];
      when(() => mockStorageService.getCategories()).thenReturn(cats);

      await tester.pumpWidget(createWidgetUnderTest(categories: cats));
      await tester.pumpAndSettle();

      expect(find.text('Gain / Profit Amount'), findsOneWidget);

      await tester.enterText(
          find.ancestor(
              of: find.text('Gain / Profit Amount'),
              matching: find.byType(TextFormField)),
          '200');
      await tester.enterText(
          find.ancestor(
              of: find.text('Description'),
              matching: find.byType(TextFormField)),
          'Stock Sale');
      await tester.enterText(
          find.ancestor(
              of: find.text('Amount'), matching: find.byType(TextFormField)),
          '1000');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      await tapSave(tester);

      verify(() => mockStorageService.saveTransaction(any(
          that: isA<Transaction>()
              .having((t) => t.gainAmount, 'gain', 200.0)))).called(1);
    });

    testWidgets('Update Similar Category Dialog', (tester) async {
      final txn = Transaction.create(
          title: 'Coffee',
          amount: 100,
          category: 'Food',
          type: TransactionType.expense,
          date: DateTime.now());
      final cats = [
        Category(id: '1', name: 'Food', usage: CategoryUsage.expense),
        Category(id: '2', name: 'Drinks', usage: CategoryUsage.expense)
      ];
      when(() => mockStorageService.getCategories()).thenReturn(cats);
      when(() => mockStorageService.getSimilarTransactionCount(
          any(), any(), any())).thenAnswer((_) async => 5);

      await tester.pumpWidget(
          createWidgetUnderTest(transactionToEdit: txn, categories: cats));
      await tester.pumpAndSettle();

      // Change Category to Drinks
      final catDropdown =
          find.widgetWithText(DropdownButtonFormField<String?>, 'Category');
      await tester.tap(catDropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Drinks').last);
      await tester.pumpAndSettle();

      await tapSave(tester, text: 'Update Transaction');

      expect(find.text('Update Similar Transactions?'), findsOneWidget);
      await tester.tap(find.text('YES, Update All'));
      await tester.pumpAndSettle();

      verify(() =>
              mockStorageService.bulkUpdateCategory(any(), 'Food', 'Drinks'))
          .called(1);
    });

    testWidgets('Toggle Recurrence Fields', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final repeatSwitch =
          find.widgetWithText(SwitchListTile, 'Make Recurring');
      await tester.dragUntilVisible(
          repeatSwitch, find.byType(ListView), const Offset(0, -500));
      await tester.tap(repeatSwitch);
      await tester.pumpAndSettle();

      expect(find.text('Frequency'), findsOneWidget);
    });

    testWidgets('supports category and recurring frequency dropdown flows',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);

      final accounts = [
        Account(
          id: 'acc1',
          name: 'Cash',
          type: AccountType.wallet,
          balance: 1000,
          profileId: 'default',
        ),
      ];
      final categories = [
        Category(
          id: 'exp-1',
          name: 'Food',
          usage: CategoryUsage.expense,
          profileId: 'default',
        ),
        Category(
          id: 'inc-1',
          name: 'Salary',
          usage: CategoryUsage.income,
          profileId: 'default',
        ),
      ];

      when(() => mockStorageService.getAccounts()).thenReturn(accounts);
      when(() => mockStorageService.getCategories()).thenReturn(categories);

      await tester.pumpWidget(createWidgetUnderTest(
        accounts: accounts,
        categories: categories,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Add Transaction'), findsOneWidget);

      await tester.tap(find
          .byKey(const ValueKey('category_dropdown_TransactionType.expense')));
      await tester.pumpAndSettle();
      expect(find.text('Food').last, findsOneWidget);
      await tester.tap(find.text('Food').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Income'));
      await tester.pumpAndSettle();

      await tester.tap(find
          .byKey(const ValueKey('category_dropdown_TransactionType.income')));
      await tester.pumpAndSettle();
      expect(find.text('Salary').last, findsOneWidget);
      await tester.tap(find.text('Salary').last);
      await tester.pumpAndSettle();

      final recurringSwitch = find.text('Make Recurring');
      await tester.dragUntilVisible(
        recurringSwitch,
        find.byType(ListView),
        const Offset(0, -500),
      );
      await tester.tap(recurringSwitch);
      await tester.pumpAndSettle();

      expect(find.text('MONTHLY'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('MONTHLY'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('MONTHLY').last);
      await tester.pumpAndSettle();

      expect(find.text('WEEKLY').last, findsOneWidget);
      expect(find.text('DAILY').last, findsOneWidget);
      await tester.tap(find.text('WEEKLY').last);
      await tester.pumpAndSettle();
    });
  });
}
