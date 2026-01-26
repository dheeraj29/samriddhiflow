import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samriddhi_flow/screens/add_transaction_screen.dart';
import 'package:samriddhi_flow/models/account.dart';
import 'package:samriddhi_flow/models/transaction.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_mocks.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Add Transaction Screen - Validation',
      (WidgetTester tester) async {
    // Set typical phone size to avoid overflow
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountsProvider.overrideWith((ref) => Stream.value([
                Account(
                    id: 'a1',
                    name: 'Cash',
                    type: AccountType.wallet,
                    balance: 100)
              ])),
          storageServiceProvider.overrideWith((ref) => MockStorageService()),
          storageInitializerProvider.overrideWith((ref) => Future.value()),
          categoriesProvider.overrideWith(MockCategoriesNotifier.new),
          monthlyBudgetProvider.overrideWith(MockBudgetNotifier.new),
          transactionsProvider.overrideWith((ref) => Stream.value([])),
          recurringTransactionsProvider.overrideWith((ref) => Stream.value([])),
          activeProfileIdProvider.overrideWith(MockProfileNotifier.new),
        ],
        child: const MaterialApp(
          home: AddTransactionScreen(initialType: TransactionType.expense),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Initial state: Title empty, Amount empty.

    // Scroll to button
    final saveButton = find.text('Save Transaction');
    // Use Drag instead of scrollUntilVisible for reliability in simple lists
    await tester.dragUntilVisible(
        saveButton, find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();

    // Try to tap Save.
    await tester.tap(saveButton);
    await tester.pump();

    // Verify error or that it stayed on screen.
    expect(find.text('Required'), findsOneWidget);
  });

  testWidgets('Add Transaction Screen - Income Switch',
      (WidgetTester tester) async {
    // Set typical phone size to avoid overflow
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountsProvider.overrideWith((ref) => Stream.value([
                Account(
                    id: 'a1',
                    name: 'Cash',
                    type: AccountType.wallet,
                    balance: 100)
              ])),
          storageServiceProvider.overrideWith((ref) => MockStorageService()),
          storageInitializerProvider.overrideWith((ref) => Future.value()),
          categoriesProvider.overrideWith(MockCategoriesNotifier.new),
          monthlyBudgetProvider.overrideWith(MockBudgetNotifier.new),
          transactionsProvider.overrideWith((ref) => Stream.value([])),
          recurringTransactionsProvider.overrideWith((ref) => Stream.value([])),
          activeProfileIdProvider.overrideWith(MockProfileNotifier.new),
        ],
        child: const MaterialApp(
          home: AddTransactionScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Default is Expense usually. Tap Income.
    await tester.tap(find.text('Income'));
    await tester.pumpAndSettle();

    // MockCategories defines Salary as Income.
    expect(find.text('Salary'), findsOneWidget);
  });
}
