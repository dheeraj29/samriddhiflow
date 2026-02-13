import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
// Keep for Service ref
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/models/category.dart';
import 'package:samriddhi_flow/services/notification_service.dart';
import 'package:samriddhi_flow/feature_providers.dart';
import 'package:samriddhi_flow/screens/dashboard_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../test_mocks.dart';

// Mock overrides if needed or use container.
// For smoke test, we can use empty providers or initial state.

import 'package:samriddhi_flow/models/dashboard_config.dart';

// Mocks
class MockCurrencyNotifier extends CurrencyNotifier {
  @override
  String build() => 'en_US';
}

class MockCategoriesNotifier extends CategoriesNotifier {
  @override
  List<Category> build() => [];
}

class MockBackupThresholdNotifier extends BackupThresholdNotifier {
  @override
  int build() => 10;
}

class MockTxnsSinceBackupNotifier extends TxnsSinceBackupNotifier {
  @override
  int build() => 0;
}

class MockSmartCalculatorEnabledNotifier
    extends SmartCalculatorEnabledNotifier {
  @override
  bool build() => false;
}

class MockCalculatorVisibleNotifier extends CalculatorVisibleNotifier {
  @override
  bool build() => false;
}

class MockHolidaysNotifier extends HolidaysNotifier {
  @override
  List<DateTime> build() => [];
}

class MockDashboardConfigNotifier extends DashboardConfigNotifier {
  @override
  DashboardVisibilityConfig build() => const DashboardVisibilityConfig();
}

class MockAppLockIntentNotifier extends AppLockIntentNotifier {
  @override
  bool build() => false;
}

class MockActiveProfileIdNotifier extends ProfileNotifier {
  @override
  String build() => 'default';
}

class MockNotificationService extends Mock implements NotificationService {
  @override
  Future<void> init() async {}
  @override
  Future<List<String>> checkNudges() async => [];
}

void main() {
  testWidgets('Dashboard Renders with Empty State',
      (WidgetTester tester) async {
    // Mock basics if strictly needed, but riverpod handles defaults well often.
    SharedPreferences.setMockInitialValues({}); // Ensure no persisted state

    final mockStorage = MockStorageService();
    setupStorageDefaults(mockStorage);

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
          storageServiceProvider.overrideWithValue(mockStorage),
          // Mock Auth Stream (User is logged in)
          authStreamProvider.overrideWith((ref) => Stream.value(null)),
          // Mock Notification Service
          notificationServiceProvider
              .overrideWith((ref) => MockNotificationService()),
          // Note: Dashboard usually requires a User? No, it handles null user (offline mode).
          // But verify if it needs a Profile.
          // Mock Profile
          activeProfileProvider.overrideWith((ref) => null),
          profilesProvider.overrideWith((ref) => Future.value([])),
          activeProfileIdProvider.overrideWith(MockActiveProfileIdNotifier.new),
          currencyProvider.overrideWith(MockCurrencyNotifier.new),
          categoriesProvider.overrideWith(MockCategoriesNotifier.new),
          recurringTransactionsProvider.overrideWith((ref) => Stream.value([])),
          backupThresholdProvider.overrideWith(MockBackupThresholdNotifier.new),
          txnsSinceBackupProvider.overrideWith(MockTxnsSinceBackupNotifier.new),
          smartCalculatorEnabledProvider
              .overrideWith(MockSmartCalculatorEnabledNotifier.new),
          calculatorVisibleProvider
              .overrideWith(MockCalculatorVisibleNotifier.new),
          holidaysProvider.overrideWith(MockHolidaysNotifier.new),
          dashboardConfigProvider.overrideWith(MockDashboardConfigNotifier.new),
          appLockStatusProvider.overrideWith((ref) => false),
          appLockIntentProvider.overrideWith(MockAppLockIntentNotifier.new),
        ],
        child: const MaterialApp(
          home: DashboardScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(seconds: 2)); // Wait for basic animations

    // Debug: Print all text widgets
    // final textWidgets = find.byType(Text);
    // print('Found ${textWidgets.evaluate().length} Text widgets');
    // for (final w in textWidgets.evaluate()) {
    //   print((w.widget as Text).data);
    // }

    // Verify Title (If found, good, else manually verify from log)
    expect(find.text('My Samriddh'), findsOneWidget);

    // Verify Tabs/Sections (assuming text presence)
    // "Net Worth" might be present.
    expect(find.textContaining('Net Worth'),
        findsWidgets); // Might be multiple if in tab + card
  });
}
