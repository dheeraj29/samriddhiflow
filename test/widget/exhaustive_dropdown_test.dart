import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samriddhi_flow/models/account.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/screens/add_transaction_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_mocks.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Add Transaction Dropdowns - Verification',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWith((ref) => MockStorageService()),
          storageInitializerProvider.overrideWith((ref) => Future.value()),
          firebaseInitializerProvider.overrideWith((ref) => Future.value()),
          categoriesProvider
              .overrideWith(() => MockCategoriesNotifier()..build()),
          accountsProvider.overrideWith((ref) => Stream.value([
                Account(
                    id: 'acc1',
                    name: 'Cash',
                    type: AccountType.wallet,
                    balance: 1000)
              ])),
          transactionsProvider.overrideWith((ref) => Stream.value([])),
          currencyProvider.overrideWith(() => CurrencyNotifier()),
          activeProfileIdProvider.overrideWith(() => MockProfileNotifier()),
        ],
        child: const MaterialApp(
          home: AddTransactionScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Verify Category Dropdown
    // Key: category_dropdown
    // Tap it
    try {
      await tester.tap(find.byKey(const Key('category_dropdown')));
    } catch (_) {
      // Fallback if key not found, look for DropdownButtonFormField with generic logic?
      // Or by text. Default is often 'Food' or 'Select'.
      // MockCategories has 'Food'.
      // If default is selected, it shows 'Food'.
      await tester.tap(find.text('Food'));
    }
    await tester.pumpAndSettle();

    // Verify items exist
    // Verify items exist - Food should be here (Expense)
    expect(find.text('Food').last, findsOneWidget);

    // Select Food (to close dropdown or just verify interaction)
    await tester.tap(find.text('Food').last);
    await tester.pumpAndSettle();

    // Switch to Income to check Salary
    // ButtonSegment label is 'Income'
    await tester.tap(find.text('Income'));
    await tester.pumpAndSettle();

    // Open Category Dropdown again
    await tester.tap(find.byKey(const Key('category_dropdown')));
    await tester.pumpAndSettle();

    // Now Salary should be visible
    expect(find.text('Salary').last, findsOneWidget);
    await tester.tap(find.text('Salary').last);
    await tester.pumpAndSettle();

    // 2. Verify Recurring Frequency Dropdown
    // Enable Recurring
    final recurringSwitchFinder = find.text('Make Recurring');
    await tester.scrollUntilVisible(
      recurringSwitchFinder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(recurringSwitchFinder);
    await tester.pumpAndSettle();

    // Initial value 'MONTHLY' (Frequency labels are uppercase in AddTransactionScreen)
    expect(find.text('MONTHLY'), findsOneWidget);

    // Ensure visible before tap
    await tester.scrollUntilVisible(
      find.text('MONTHLY'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    // Tap Frequency Dropdown
    await tester.tap(find.text('MONTHLY').last);
    await tester.pumpAndSettle();

    // Verify 'WEEKLY', 'DAILY'
    expect(find.text('WEEKLY').last, findsOneWidget);
    expect(find.text('DAILY').last, findsOneWidget);

    // Tap WEEKLY
    await tester.tap(find.text('WEEKLY').last);
    await tester.pumpAndSettle();

    // Verify Schedule Type updates if logic exists (not testing logic here, just dropdowns)
  });
}
