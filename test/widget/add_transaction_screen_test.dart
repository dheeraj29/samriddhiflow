import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/screens/add_transaction_screen.dart';
import 'package:samriddhi_flow/models/transaction.dart';
import 'package:samriddhi_flow/models/category.dart';
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
}
