import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samriddhi_flow/models/account.dart';
import 'package:samriddhi_flow/models/transaction.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/screens/reports_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_mocks.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Reports Screen - Smoke Test & Chart Rendering',
      (WidgetTester tester) async {
    // Set screen size for Chart rendering
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
                    balance: 1000)
              ])),
          storageServiceProvider.overrideWith((ref) => MockStorageService()),
          storageInitializerProvider.overrideWith((ref) => Future.value()),
          categoriesProvider.overrideWith(MockCategoriesNotifier.new),
          monthlyBudgetProvider.overrideWith(MockBudgetNotifier.new),
          loansProvider.overrideWith((ref) => Stream.value([])),
          // Provide some transactions to trigger Chart rendering
          transactionsProvider.overrideWith((ref) => Stream.value([
                Transaction(
                    id: 't1',
                    title: 'Lunch',
                    amount: 50,
                    date: DateTime.now(),
                    type: TransactionType.expense,
                    category: 'Food',
                    accountId: 'a1',
                    profileId: 'default'),
              ])),
        ],
        child: const MaterialApp(
          home: ReportsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Title
    expect(find.text('Financial Reports'), findsOneWidget);

    // Verify Filter Chips exist
    expect(find.text('Spending'), findsOneWidget);
    expect(find.text('Income'), findsOneWidget);
    expect(find.text('Loan'), findsOneWidget);

    // Verify PieChart is present (requires data)
    expect(find.byType(PieChart), findsOneWidget);

    // Verify Total Amount Logic (Lunch 50)
    // Finding rich text or specific text might be tricky with formatting.
    // SmartCurrencyText usually renders RichText or Text.
    // Assuming format is '₹50.00' or similar
    expect(find.textContaining('50'), findsAtLeastNWidgets(1));
  });

  testWidgets('Reports Screen - Interaction & Dropdowns',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountsProvider.overrideWith((ref) => Stream.value([])),
          storageServiceProvider.overrideWith((ref) => MockStorageService()),
          storageInitializerProvider.overrideWith((ref) => Future.value()),
          categoriesProvider.overrideWith(MockCategoriesNotifier.new),
          monthlyBudgetProvider.overrideWith(MockBudgetNotifier.new),
          loansProvider.overrideWith((ref) => Stream.value([])),
          transactionsProvider.overrideWith((ref) => Stream.value([
                Transaction(
                    id: 't1',
                    title: 'Dummy',
                    amount: 10,
                    date: DateTime.now(),
                    type: TransactionType.expense,
                    category: 'Food',
                    accountId: 'a1',
                    profileId: 'default'),
              ])),
        ],
        child: const MaterialApp(
          home: ReportsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Dropdowns
    // Period Dropdown (default '30')
    expect(find.text('30 Days'), findsOneWidget);

    // Account Dropdown (default 'All Accounts' -> null in value, label 'All Accounts')
    // Note: DropdownButtonFormField usually shows selected item text.
    // If value is null, it shows the item with value null.
    expect(find.text('All Accounts'), findsOneWidget);
  });
}
