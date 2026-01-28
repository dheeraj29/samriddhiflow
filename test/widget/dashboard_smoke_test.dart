import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
// Keep for Service ref
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/feature_providers.dart';
import 'package:samriddhi_flow/screens/dashboard_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'test_mocks.dart';

// Mock overrides if needed or use container.
// For smoke test, we can use empty providers or initial state.

void main() {
  testWidgets('Dashboard Renders with Empty State',
      (WidgetTester tester) async {
    // Mock basics if strictly needed, but riverpod handles defaults well often.
    SharedPreferences.setMockInitialValues({}); // Ensure no persisted state

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountsProvider.overrideWith((ref) => Stream.value([])),
          transactionsProvider.overrideWith((ref) => Stream.value([])),
          loansProvider.overrideWith((ref) => Stream.value([])),
          // Also override initializer to be "done"
          storageInitializerProvider.overrideWith((ref) => Future.value()),
          firebaseInitializerProvider.overrideWith((ref) => Future.value()),
          // Mock offline status
          isOfflineProvider.overrideWith(MockIsOfflineNotifier.new),
          // Mock budget
          monthlyBudgetProvider.overrideWith(MockBudgetNotifier.new),
          // Mock Storage Service
          storageServiceProvider.overrideWith((ref) => MockStorageService()),
          // Mock Auth Stream (User is logged in)
          authStreamProvider.overrideWith((ref) => Stream.value(null)),
          // Mock Notification Service
          notificationServiceProvider
              .overrideWith((ref) => MockNotificationService()),
          // Note: Dashboard usually requires a User? No, it handles null user (offline mode).
          // But verify if it needs a Profile.
        ],
        child: const MaterialApp(
          home: DashboardScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(seconds: 2)); // Wait for basic animations

    // Debug: Print all text widgets
    final textWidgets = find.byType(Text);
    print('Found ${textWidgets.evaluate().length} Text widgets');
    for (final w in textWidgets.evaluate()) {
      print((w.widget as Text).data);
    }

    // Verify Title (If found, good, else manually verify from log)
    expect(find.text('My Samriddh'), findsOneWidget);

    // Verify Tabs/Sections (assuming text presence)
    // "Net Worth" might be present.
    expect(find.textContaining('Net Worth'),
        findsWidgets); // Might be multiple if in tab + card
  });
}
