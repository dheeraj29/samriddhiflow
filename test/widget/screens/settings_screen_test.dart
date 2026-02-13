import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/providers.dart';

import 'package:samriddhi_flow/feature_providers.dart';
import 'package:samriddhi_flow/screens/settings_screen.dart';
import 'package:samriddhi_flow/services/cloud_sync_service.dart';
import 'package:samriddhi_flow/services/repair_service.dart';
import 'package:samriddhi_flow/services/excel_service.dart';
import '../test_mocks.dart';

import 'package:samriddhi_flow/models/dashboard_config.dart';

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
  late MockNavigatorObserver mockObserver;

  setUp(() {
    mockStorage = MockStorageService();
    setupStorageDefaults(mockStorage);
    mockCloudSyncService = MockCloudSyncService();
    mockAuthService = MockAuthService();
    mockRepairService = MockRepairService();
    mockExcelService = MockExcelService();
    mockUser = MockUser();
    mockObserver = MockNavigatorObserver();

    when(() => mockAuthService.currentUser).thenReturn(mockUser);
    when(() => mockStorage.setSmartCalculatorEnabled(any()))
        .thenAnswer((_) async {});
  });

  Future<void> pumpSettingsScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(mockStorage),
          cloudSyncServiceProvider.overrideWithValue(mockCloudSyncService),
          authServiceProvider.overrideWithValue(mockAuthService),
          repairServiceProvider.overrideWithValue(mockRepairService),
          excelServiceProvider.overrideWithValue(mockExcelService),
          storageInitializerProvider.overrideWith((ref) => Future.value()),
          authStreamProvider.overrideWith((ref) => Stream.value(mockUser)),
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
          dashboardConfigProvider.overrideWith(MockDashboardConfigNotifier.new),
        ],
        child: MaterialApp(
          home: const SettingsScreen(),
          navigatorObservers: [mockObserver],
          onGenerateRoute: (settings) {
            return MaterialPageRoute(builder: (_) => Container());
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('SettingsScreen - Interactions in Order', (tester) async {
    await pumpSettingsScreen(tester);

    // 1. Appearance (Top)
    // await tester.tap(find.text('Appearance')); // Header
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Theme Mode'), findsOneWidget);

    // 2. Dashboard Customization (Visible usually)
    expect(find.text('Dashboard Customization'), findsOneWidget);

    // 3. Cloud & Sync (Visible usually or just below)
    expect(find.text('Cloud & Sync'), findsOneWidget);

    // Scroll to bottom to find Currency
    await tester.drag(find.byType(ListView), const Offset(0, -1000));
    await tester.pumpAndSettle();

    // 6. Preferences (Bottom) - Currency
    final currencyTile = find.text('Currency');
    await tester.ensureVisible(currencyTile);
    await tester.pumpAndSettle();
    expect(currencyTile, findsOneWidget);

    // Check subtitle to confirm it's the right tile
    expect(find.textContaining('Current:'), findsOneWidget);

    /*
    await tester.tap(currencyTile);
    await tester.pumpAndSettle();

    // Verify Navigation Push
    verify(() => mockObserver.didPush(any(), any())).called(greaterThan(0));

    // Dialog verification
    expect(find.text('Select Currency'), findsOneWidget);
    
    // Tap option
    await tester.tap(find.textContaining('Indian Rupee'));
    await tester.pumpAndSettle();
    
    expect(find.text('Select Currency'), findsNothing);
    */
  });
}

class MockNavigatorObserver extends Mock implements NavigatorObserver {}

class MockCloudSyncService extends Mock implements CloudSyncService {}

class MockRepairService extends Mock implements RepairService {}

class MockExcelService extends Mock implements ExcelService {}

class MockDashboardConfigNotifier extends DashboardConfigNotifier {
  @override
  DashboardVisibilityConfig build() => const DashboardVisibilityConfig();
}
