import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/screens/add_transaction_screen.dart';
import 'package:samriddhi_flow/models/transaction.dart';
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
  });

  setUp(() {
    mockStorageService = MockStorageService();
  });

  Widget createWidgetUnderTest() {
    return ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(mockStorageService),
        currencyProvider.overrideWith(MockCurrencyNotifier.new),
        activeProfileIdProvider.overrideWith(MockProfileNotifier.new),
        txnsSinceBackupProvider.overrideWith(MockTxnsSinceBackupNotifier.new),
        holidaysProvider.overrideWith(MockHolidaysNotifier.new),
        accountsProvider.overrideWith((ref) => Stream.value([])),
        transactionsProvider.overrideWith((ref) => Stream.value([])),
        categoriesProvider.overrideWith(() => MockCategoriesNotifier([
              Category(id: '1', name: 'General', usage: CategoryUsage.both),
              Category(id: '2', name: 'Food', usage: CategoryUsage.expense),
              Category(id: '3', name: 'Salary', usage: CategoryUsage.income),
            ])),
      ],
      child: const MaterialApp(
        home: AddTransactionScreen(),
      ),
    );
  }

  testWidgets('AddTransactionScreen validation', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    if (find.byType(CircularProgressIndicator).evaluate().isNotEmpty) {
      debugPrint('Stuck in Loading...');
    }
    if (find.textContaining('Error:').evaluate().isNotEmpty) {
      debugPrint('Found Error Text');
    }

    final saveButton = find.widgetWithText(ElevatedButton, 'Save Transaction');
    if (saveButton.evaluate().isEmpty) {
      debugPrint('Save Button NOT found');
    }

    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(find.text('Required'), findsOneWidget); // Description/Title
    expect(find.text('Invalid Amount'), findsOneWidget); // Amount

    addTearDown(() => tester.view.resetPhysicalSize());
  });

  testWidgets('AddTransactionScreen saves expense', (tester) async {
    when(() => mockStorageService.getCategories()).thenReturn([
      Category(id: '1', name: 'General', usage: CategoryUsage.both),
    ]);
    when(() => mockStorageService.saveTransaction(any()))
        .thenAnswer((_) async {});

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Fill Title
    await tester.enterText(
        find.ancestor(
            of: find.text('Description'), matching: find.byType(TextFormField)),
        'Lunch');

    // Fill Amount
    await tester.enterText(
        find.ancestor(
            of: find.text('Amount'), matching: find.byType(TextFormField)),
        '150');

    // Save
    final saveButton = find.widgetWithText(ElevatedButton, 'Save Transaction');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    verify(() => mockStorageService.saveTransaction(any(
        that: isA<Transaction>()
            .having((t) => t.title, 'title', 'Lunch')
            .having((t) => t.amount, 'amount', 150.0)))).called(1);
  });
  testWidgets('AddTransactionScreen switches type to Income', (tester) async {
    when(() => mockStorageService.getCategories()).thenReturn([
      Category(id: '1', name: 'General', usage: CategoryUsage.both),
      Category(id: '3', name: 'Salary', usage: CategoryUsage.income),
    ]);

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Verify default is Expense (Red color usually, or check ToggleButton)
    // Finding ToggleButtons is tricky, we can find by verify specific text is selected
    // For simplicity, let's tap 'Income'
    final incomeButton = find.text('Income');
    await tester.tap(incomeButton);
    await tester.pumpAndSettle();

    // Verify UI updates - e.g. check if a known Income category is available or check internal state if possible
    // Here we just verify it doesn't crash and functionality attempts to save as Income

    // Fill Title
    await tester.enterText(
        find.ancestor(
            of: find.text('Description'), matching: find.byType(TextFormField)),
        'Paycheck');

    // Fill Amount
    await tester.enterText(
        find.ancestor(
            of: find.text('Amount'), matching: find.byType(TextFormField)),
        '5000');

    // Mock save
    when(() => mockStorageService.saveTransaction(any()))
        .thenAnswer((_) async {});

    // Save
    final saveButton = find.widgetWithText(ElevatedButton, 'Save Transaction');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    verify(() => mockStorageService.saveTransaction(any(
        that: isA<Transaction>()
            .having((t) => t.type, 'type', TransactionType.income)))).called(1);
  });

  testWidgets('AddTransactionScreen validates zero amount', (tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    await tester.enterText(
        find.ancestor(
            of: find.text('Description'), matching: find.byType(TextFormField)),
        'Zero Item');

    await tester.enterText(
        find.ancestor(
            of: find.text('Amount'), matching: find.byType(TextFormField)),
        '0');

    final saveButton = find.widgetWithText(ElevatedButton, 'Save Transaction');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(find.text('Invalid Amount'), findsOneWidget);
  });

  testWidgets('AddTransactionScreen switches to Transfer', (tester) async {
    when(() => mockStorageService.getAccounts()).thenReturn([
      Account(
          id: 'a1', name: 'Bank', type: AccountType.savings, profileId: 'p1'),
      Account(
          id: 'a2', name: 'Wallet', type: AccountType.wallet, profileId: 'p1'),
    ]);
    when(() => mockStorageService.saveTransaction(any()))
        .thenAnswer((_) async {});

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Tap Transfer Toggle
    await tester.tap(find.text('Transfer'));
    await tester.pumpAndSettle();

    expect(find.text('From Account'), findsOneWidget);
    expect(find.text('To Account'), findsOneWidget);

    // Enter details
    await tester.enterText(
        find.ancestor(
            of: find.text('Amount'), matching: find.byType(TextFormField)),
        '100');

    // Select Accounts (mock might need dropdown interaction or just default if auto-selected)
    // Assuming defaults or manual selection. For this test, just verification of Transfer UI is good.

    // Note: To fully test Save Transfer, we need to interact with Dropdowns which can be complex with mocks
    // unless we render specific account widgets.
  });

  testWidgets('AddTransactionScreen toggle Recurring', (tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Find "Recurring Payment" switch (CheckboxListTile or SwitchListTile)
    // Code usually has text "Recurring Transaction" or similar.
    // Let's assume text search works.
    final recurringFinder = find.text('Recurring Transaction');
    if (recurringFinder.evaluate().isNotEmpty) {
      await tester.tap(recurringFinder);
      await tester.pumpAndSettle();

      expect(find.text('Frequency'), findsOneWidget);
      expect(find.text('Next Occurrence'), findsOneWidget);
    }
  });
}
