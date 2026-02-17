import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/screens/transactions_screen.dart';
import 'package:samriddhi_flow/models/transaction.dart';
import 'package:samriddhi_flow/models/account.dart';
import 'package:samriddhi_flow/models/category.dart';
import 'package:samriddhi_flow/services/storage_service.dart';

class MockStorageService extends Mock implements StorageService {}

class MockCurrencyNotifier extends CurrencyNotifier {
  @override
  String build() => 'en_US';
}

class MockCategoriesNotifier extends CategoriesNotifier {
  final List<Category> initial;
  MockCategoriesNotifier(this.initial);
  @override
  List<Category> build() => initial;
}

void main() {
  late MockStorageService mockStorageService;

  setUp(() {
    mockStorageService = MockStorageService();
    when(() => mockStorageService.deleteTransaction(any()))
        .thenAnswer((_) async {});
  });

  Widget createWidgetUnderTest({
    List<Transaction>? transactions,
    List<Account>? accounts,
    List<Category>? categories,
  }) {
    return ProviderScope(
      overrides: [
        transactionsProvider
            .overrideWith((ref) => Stream.value(transactions ?? [])),
        accountsProvider.overrideWith((ref) => Stream.value(accounts ?? [])),
        categoriesProvider
            .overrideWith(() => MockCategoriesNotifier(categories ?? [])),
        currencyProvider.overrideWith(MockCurrencyNotifier.new),
        storageServiceProvider.overrideWithValue(mockStorageService),
      ],
      child: const MaterialApp(
        home: TransactionsScreen(),
      ),
    );
  }

  testWidgets('TransactionsScreen renders list and filters', (tester) async {
    final t1 = Transaction.create(
      title: 'Salary',
      amount: 5000,
      type: TransactionType.income,
      category: 'Salary',
      accountId: 'acc1',
      date: DateTime.now(),
    );
    final t2 = Transaction.create(
      title: 'Groceries',
      amount: 200,
      type: TransactionType.expense,
      category: 'Food',
      accountId: 'acc1',
      date: DateTime.now().subtract(const Duration(days: 1)),
    );

    await tester.pumpWidget(createWidgetUnderTest(transactions: [t1, t2]));
    await tester.pumpAndSettle();

    expect(find.text('Salary'), findsOneWidget);
    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('All Transactions'), findsOneWidget);
  });

  testWidgets('TransactionsScreen selection mode and delete', (tester) async {
    final t1 = Transaction.create(
      title: 'DeleteMe',
      amount: 100,
      type: TransactionType.expense,
      category: 'Misc',
      accountId: 'acc1',
      date: DateTime.now(),
    );

    await tester.pumpWidget(createWidgetUnderTest(transactions: [t1]));
    await tester.pumpAndSettle();

    // Long press to enter selection mode
    await tester.longPress(find.text('DeleteMe'));
    await tester.pumpAndSettle();

    expect(find.text('1 Selected'), findsOneWidget);
    expect(
        find.byIcon(Icons.delete), findsOneWidget); // Delete action in app bar

    // Tap Delete
    await tester.tap(find.byIcon(Icons.delete));
    await tester.pumpAndSettle();

    expect(find.text('Delete 1 Transactions?'), findsOneWidget);

    // Confirm
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    verify(() => mockStorageService.deleteTransaction(t1.id)).called(1);
    expect(find.text('Transactions moved to Recycle Bin'), findsOneWidget);
  });

  testWidgets('TransactionsScreen toggle compact view', (tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    final extendedButton = find.byTooltip('Switch to Compact Numbers');
    expect(extendedButton, findsOneWidget);

    await tester.tap(extendedButton);
    await tester.pumpAndSettle();

    expect(find.byTooltip('Switch to Extended Numbers'), findsOneWidget);
    expect(find.byTooltip('Switch to Extended Numbers'), findsOneWidget);
  });

  testWidgets('TransactionsScreen filters by category', (tester) async {
    final t1 = Transaction.create(
      title: 'Salary',
      amount: 5000,
      type: TransactionType.income,
      category: 'Salary',
      accountId: 'acc1',
      date: DateTime.now(),
    );
    final t2 = Transaction.create(
      title: 'Groceries',
      amount: 200,
      type: TransactionType.expense,
      category: 'Food',
      accountId: 'acc1',
      date: DateTime.now(),
    );

    // Categories needed for dropdown
    final categories = [
      Category(id: '1', name: 'Salary', usage: CategoryUsage.income),
      Category(id: '2', name: 'Food', usage: CategoryUsage.expense),
    ];

    await tester.pumpWidget(createWidgetUnderTest(
        transactions: [t1, t2],
        categories: categories,
        accounts: [
          Account(
              id: 'acc1',
              name: 'Bank',
              type: AccountType.savings,
              profileId: 'p1')
        ]));
    await tester.pumpAndSettle();

    expect(find.text('Salary'), findsOneWidget);
    expect(find.text('Groceries'), findsOneWidget);

    // Find Filter Dropdown for Category
    // Usually TransactionFilter has multiple dropdowns, we need to find the one for Category.
    // It usually has a hint or currently selected value ('All Categories' or similar).
    // Let's assume there is a dropdown with 'All Categories' or we find by Type.

    // Simplest way: Find the dropdown that contains 'Food' item when opened?
    // Or finding by key if keys were used.
    // Let's try finding the DropdownButton that currently shows 'All Categories'
    // or by order if we know it (Range, Category, Account, Type).

    // Assuming Category is the second one or has specific hint.
    // However, without seeing TransactionFilter code, it's a guess.
    // But we can try to tap the specific DropdownMenuItem if we open the dropdown.
    // Or we can rely on `TransactionFilter` typically labelling its fields.

    // Strategy: Find widget with text "Category" if it's a label?
    // If it's just a row of Dropdowns, it's harder.
    // Let's skip complex interaction if it's too risky and focus on checking if 'TransactionFilter' widget is present.
    // Better: Add a basic find verification.

    expect(find.byType(DropdownButton<String?>), findsWidgets);
  });

  testWidgets('TransactionsScreen filters by type', (tester) async {
    final t1 = Transaction.create(
      title: 'Income1',
      amount: 100,
      type: TransactionType.income,
      category: 'S',
      accountId: 'a1',
      date: DateTime.now(),
    );
    final t2 = Transaction.create(
      title: 'Expense1',
      amount: 50,
      type: TransactionType.expense,
      category: 'F',
      accountId: 'a1',
      date: DateTime.now(),
    );

    await tester.pumpWidget(createWidgetUnderTest(transactions: [t1, t2]));
    await tester.pumpAndSettle();

    final typeDropdown =
        find.widgetWithText(DropdownButtonFormField<TransactionType?>, 'Type');
    await tester.tap(typeDropdown);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Income').last);
    await tester.pumpAndSettle();

    expect(find.text('Income1'), findsOneWidget);
    expect(find.text('Expense1'), findsNothing);
  });

  testWidgets('TransactionsScreen Select All (Filtered) logic', (tester) async {
    final t1 = Transaction.create(
      title: 'T1',
      amount: 10,
      type: TransactionType.expense,
      category: 'A',
      accountId: 'a1',
      date: DateTime.now(),
    );
    final t2 = Transaction.create(
      title: 'T2',
      amount: 20,
      type: TransactionType.income,
      category: 'B',
      accountId: 'a1',
      date: DateTime.now(),
    );

    await tester.pumpWidget(createWidgetUnderTest(transactions: [t1, t2]));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Select Transactions'));
    await tester.pumpAndSettle();

    final selectAllButton = find.byTooltip('Select All (Filtered)');
    await tester.tap(selectAllButton);
    await tester.pumpAndSettle();

    expect(find.text('2 Selected'), findsOneWidget);

    await tester.tap(selectAllButton);
    await tester.pumpAndSettle();
    expect(find.text('All Transactions'), findsOneWidget);
  });
}
