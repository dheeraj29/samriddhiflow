import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/providers.dart';

import 'package:samriddhi_flow/feature_providers.dart';
import 'package:samriddhi_flow/screens/settings_screen.dart';
import 'package:samriddhi_flow/services/cloud_sync_service.dart';
import 'package:samriddhi_flow/services/repair_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../test_mocks.dart';

class FakeRoute extends Fake implements Route<dynamic> {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeRoute());
  });

  late MockStorageService mockStorage;
  late MockCloudSyncService mockCloudSyncService;
  late MockAuthService mockAuthService;
  late MockRepairService mockRepairService;
  late MockExcelService mockExcelService;
  late MockUser mockUser;

  setUp(() {
    mockStorage = MockStorageService();
    setupStorageDefaults(mockStorage);
    mockCloudSyncService = MockCloudSyncService();
    mockAuthService = MockAuthService();
    mockRepairService = MockRepairService();
    mockExcelService = MockExcelService();
    mockUser = MockUser();

    when(() => mockAuthService.currentUser).thenReturn(mockUser);
    when(() => mockStorage.setSmartCalculatorEnabled(any()))
        .thenAnswer((_) async {});
  });

  Widget createWidgetUnderTest({User? user}) {
    return ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(mockStorage),
        cloudSyncServiceProvider.overrideWithValue(mockCloudSyncService),
        authServiceProvider.overrideWithValue(mockAuthService),
        repairServiceProvider.overrideWithValue(mockRepairService),
        excelServiceProvider.overrideWithValue(mockExcelService),
        storageInitializerProvider.overrideWith((ref) => Future.value()),
        authStreamProvider.overrideWith((ref) => Stream.value(user)),
        activeProfileIdProvider
            .overrideWith(() => MockProfileNotifier('default')),
        smartCalculatorEnabledProvider
            .overrideWith(() => MockSmartCalcNotifier(true)),
        isOfflineProvider.overrideWith(() => MockIsOfflineNotifier(false)),
        profilesProvider.overrideWith((ref) => Future.value([])),
        monthlyBudgetProvider.overrideWith(() => MockBudgetNotifier(50000)),
        backupThresholdProvider
            .overrideWith(() => MockBackupThresholdNotifier(20)),
        currencyProvider.overrideWith(() => MockCurrencyNotifier('en_IN')),
      ],
      child: const MaterialApp(
        home: SettingsScreen(),
      ),
    );
  }

  group('SettingsScreen - Danger Zone and Advanced Actions', () {
    testWidgets('Advanced - Update App Check', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(user: mockUser));
      await tester.pumpAndSettle();

      final updateTile = find.text('Update Application');
      await tester.dragUntilVisible(
          updateTile, find.byType(ListView), const Offset(0, -1000));
      await tester.pumpAndSettle();

      await tester.tap(updateTile);
      await tester.pumpAndSettle();

      expect(find.text('Up to Date'), findsOneWidget);
    });
  });

  testWidgets('SettingsScreen - Navigation to Sub-screens', (tester) async {
    final mockObserver = MockNavigatorObserver();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(mockStorage),
          authStreamProvider.overrideWith((ref) => Stream.value(mockUser)),
          // ... other basic overrides if needed from createWidgetUnderTest logic
          authServiceProvider.overrideWithValue(mockAuthService),
          storageInitializerProvider.overrideWith((ref) => Future.value()),
          activeProfileIdProvider
              .overrideWith(() => MockProfileNotifier('default')),
          smartCalculatorEnabledProvider
              .overrideWith(() => MockSmartCalcNotifier(true)),
          isOfflineProvider.overrideWith(() => MockIsOfflineNotifier(false)),
          monthlyBudgetProvider.overrideWith(() => MockBudgetNotifier(50000)),
          backupThresholdProvider
              .overrideWith(() => MockBackupThresholdNotifier(20)),
          currencyProvider.overrideWith(() => MockCurrencyNotifier('en_IN')),
          profilesProvider.overrideWith((ref) async => []), // Mock profiles
          repairServiceProvider.overrideWithValue(mockRepairService),
          excelServiceProvider.overrideWithValue(mockExcelService),
        ],
        child: MaterialApp(
          home: const SettingsScreen(),
          navigatorObservers: [mockObserver],
          onGenerateRoute: (settings) {
            // Basic route generation to allow pushes
            return MaterialPageRoute(builder: (_) => Container());
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Scroll to Feature Management
    final featureHeader = find.text('Feature Management');
    await tester.dragUntilVisible(
        featureHeader, find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();

    // 1. Recurring Payments
    // We can't easily check actual Push without more complex setup, but we can check if it tries to find the widget or key
    // For simplicity, we assume tap works if no crash. verify logic is better with detailed mocking.
    // Let's just tap and see if it opens a new route (pushes).

    // Actually, finding by text and tapping is good.
    await tester.tap(find.text('Manage Recurring Payments'));
    await tester.pump(const Duration(seconds: 1));
    verify(() => mockObserver.didPush(any(), any())).called(greaterThan(0));
  });
}

class MockNavigatorObserver extends Mock implements NavigatorObserver {}

class MockCloudSyncService extends Mock implements CloudSyncService {}

class MockRepairService extends Mock implements RepairService {}
