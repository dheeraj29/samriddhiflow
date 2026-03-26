import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samriddhi_flow/feature_providers.dart';
import 'package:samriddhi_flow/providers.dart';

import '../../widget/test_mocks.dart';

void main() {
  group('Provider Initialization', () {
    test('core and feature providers initialize without crashing', () {
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

      container.read(logoutRequestedProvider);
      container.read(currencyProvider);
      container.read(monthlyBudgetProvider);
      container.read(holidaysProvider);
      container.read(isLoggedInProvider);

      container.read(themeModeProvider);
      container.read(calculatorVisibleProvider);
      container.read(smartCalculatorEnabledProvider);

      container.read(storageServiceProvider);
      container.read(loanServiceProvider);
      container.read(authServiceProvider);
      container.read(fileServiceProvider);
      container.read(cloudSyncServiceProvider);
      container.read(calendarServiceProvider);
      container.read(notificationServiceProvider);
    });
  });
}
