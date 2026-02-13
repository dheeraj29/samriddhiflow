import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/feature_providers.dart';
import '../widget/test_mocks.dart';

void main() {
  group('Providers Initialization Tests', () {
    test('standard and feature providers initialize without crash', () {
      final mockAuth = MockAuthService();
      final mockStorage = MockStorageService();
      final mockCloudSync = MockCloudSyncService();
      setupStorageDefaults(mockStorage);

      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(mockAuth),
          storageServiceProvider.overrideWithValue(mockStorage),
          cloudSyncServiceProvider.overrideWithValue(mockCloudSync),
          storageInitializerProvider.overrideWith((ref) => Future.value()),
        ],
      );
      addTearDown(container.dispose);

      // Core Notifiers
      container.read(logoutRequestedProvider);
      container.read(currencyProvider);
      container.read(monthlyBudgetProvider);
      container.read(holidaysProvider);
      container.read(isLoggedInProvider);

      // Feature Notifiers
      container.read(themeModeProvider);
      container.read(calculatorVisibleProvider);
      container.read(smartCalculatorEnabledProvider);

      // Service Providers
      container.read(storageServiceProvider);
      container.read(loanServiceProvider);
      container.read(authServiceProvider);
      container.read(fileServiceProvider);

      // Feature Services
      container.read(cloudSyncServiceProvider);
      container.read(excelServiceProvider);
      container.read(calendarServiceProvider);
      container.read(notificationServiceProvider);

      // Service Providers
      container.read(storageServiceProvider);
      container.read(loanServiceProvider);
      container.read(authServiceProvider);
      container.read(fileServiceProvider);

      // Feature Services
      container.read(cloudSyncServiceProvider);
      container.read(excelServiceProvider);
      container.read(calendarServiceProvider);
      container.read(notificationServiceProvider);
    });

    test('LogoutRequestedNotifier toggles value', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(logoutRequestedProvider.notifier).state = true;
      expect(container.read(logoutRequestedProvider), true);
    });
  });
}
