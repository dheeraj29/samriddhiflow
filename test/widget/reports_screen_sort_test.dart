import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samriddhi_flow/models/account.dart';
import 'package:samriddhi_flow/models/category.dart';
import 'package:samriddhi_flow/models/transaction.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/screens/reports_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_mocks.dart';

class TestCategoriesNotifier extends CategoriesNotifier {
  final List<Category> _initial;
  TestCategoriesNotifier(this._initial);
  @override
  List<Category> build() => _initial;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Report Filter sorts categories by amount descending',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;

    // Data Setup
    final catSmall = Category(
        id: 'c1',
        name: 'Apple',
        usage: CategoryUsage.expense,
        iconCode: 57564,
        tag: CategoryTag.none);
    final catBig = Category(
        id: 'c2',
        name: 'Zebra',
        usage: CategoryUsage.expense,
        iconCode: 57565,
        tag: CategoryTag.none);

    final List<Transaction> transactions = [
      Transaction(
          id: 't1',
          title: 'T1',
          amount: 100,
          type: TransactionType.expense,
          category: 'Apple',
          date: DateTime.now(),
          accountId: 'a1'),
      Transaction(
          id: 't2',
          title: 'T2',
          amount: 5000,
          type: TransactionType.expense,
          category: 'Zebra',
          date: DateTime.now(),
          accountId: 'a1'),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountsProvider.overrideWith((ref) => Stream.value([
                Account(
                    id: 'a1',
                    name: 'Cash',
                    type: AccountType.wallet,
                    balance: 10000)
              ])),
          storageServiceProvider.overrideWith((ref) => MockStorageService()),
          storageInitializerProvider.overrideWith((ref) => Future.value()),
          firebaseInitializerProvider.overrideWith((ref) => Future.value()),
          categoriesProvider
              .overrideWith(() => TestCategoriesNotifier([catSmall, catBig])),
          activeProfileIdProvider.overrideWith(() => MockProfileNotifier()),
          transactionsProvider
              .overrideWith((ref) => Stream.value(transactions)),
          loansProvider.overrideWith((ref) => Stream.value([])),
          currencyProvider.overrideWith(() => CurrencyNotifier()),
        ],
        child: const MaterialApp(
          home: ReportsScreen(),
        ),
      ),
    );

    // Initial pump
    await tester.pump();
    // Allow providers to settle (StreamProviders)
    await tester.pump();
    await tester.pump();

    // 1. Open Filter Dialog
    // Find ActionChip by checking for Icon inside it
    await tester.tap(find.byIcon(Icons.filter_list));
    await tester.pumpAndSettle();

    // 2. Verify Dialog is open
    expect(
        find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('Filter Categories')),
        findsOneWidget);

    // 3. Check Order
    // We expect "Zebra" (5000) to be FIRST (higher), "Apple" (100) to be SECOND (lower).
    // Current (failing) state: Apple is first (Alphabetical).

    // Use specific finders to key into the Dialog
    final appleFinder = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('Apple'),
    );
    final zebraFinder = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('Zebra'),
    );

    final applePos = tester.getCenter(appleFinder);
    final zebraPos = tester.getCenter(zebraFinder);

    // Verify Zebra is above Apple (smaller Y value)
    expect(zebraPos.dy, lessThan(applePos.dy),
        reason: "Zebra (5000) should be above Apple (100)");
  });
}
