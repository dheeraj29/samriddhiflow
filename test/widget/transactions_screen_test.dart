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
  });
}
