import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:samriddhi_flow/screens/settings_screen.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/feature_providers.dart';
import 'package:samriddhi_flow/services/storage_service.dart';
import 'package:samriddhi_flow/models/profile.dart';
import 'package:samriddhi_flow/models/dashboard_config.dart';
import 'package:samriddhi_flow/services/repair_service.dart';
import 'package:samriddhi_flow/services/auth_service.dart';
import 'package:samriddhi_flow/services/cloud_sync_service.dart';
import 'package:samriddhi_flow/services/json_data_service.dart';
import 'package:samriddhi_flow/services/file_service.dart';

class MockStorageService extends Mock implements StorageService {}

class MockUser extends Mock implements User {}

class MockRepairService extends Mock implements RepairService {}

class MockRepairJob extends Mock implements RepairJob {}

class FakeRefReader extends Fake implements RefReader {}

class MockCloudSyncService extends Mock implements CloudSyncService {}

class MockAuthService extends Mock implements AuthService {}

class MockJsonDataService extends Mock implements JsonDataService {}

class MockFileService extends Mock implements FileService {}

void main() {
  late MockStorageService mockStorage;
  late MockCloudSyncService mockCloudSync;
  late MockAuthService mockAuth;
  late MockJsonDataService mockJsonData;
  late MockFileService mockFileService;
  late MockRepairService mockRepair;

  setUpAll(() {
    registerFallbackValue(const DashboardVisibilityConfig());
    registerFallbackValue(Profile(id: 'fake', name: 'fake'));
    registerFallbackValue(FakeRefReader());
    registerFallbackValue(AuthResponse(status: AuthStatus.success));
    registerFallbackValue(const AsyncValue<bool>.data(true));
  });

  setUp(() {
    mockStorage = MockStorageService();
    mockCloudSync = MockCloudSyncService();
    mockAuth = MockAuthService();
    mockJsonData = MockJsonDataService();
    mockFileService = MockFileService();
    mockRepair = MockRepairService();

    // Default stubs for StorageService
    when(() => mockStorage.isAppLockEnabled()).thenReturn(false);
    when(() => mockStorage.getThemeMode()).thenReturn('system');
    when(() => mockStorage.getDashboardConfig())
        .thenReturn(const DashboardVisibilityConfig());
    when(() => mockStorage.isSmartCalculatorEnabled()).thenReturn(true);
    when(() => mockStorage.getCurrencyLocale()).thenReturn('en_IN');
    when(() => mockStorage.getMonthlyBudget()).thenReturn(50000.0);
    when(() => mockStorage.getBackupThreshold()).thenReturn(20);
    when(() => mockStorage.getActiveProfileId()).thenReturn('p1');
    when(() => mockStorage.getAuthFlag()).thenReturn(false);
    when(() => mockStorage.getAppPin()).thenReturn(null);

    when(() => mockStorage.setThemeMode(any())).thenAnswer((_) async {});
    when(() => mockStorage.saveDashboardConfig(any())).thenAnswer((_) async {});
    when(() => mockStorage.setMonthlyBudget(any())).thenAnswer((_) async {});
    when(() => mockStorage.setActiveProfileId(any())).thenAnswer((_) async {});
    when(() => mockStorage.setCurrencyLocale(any())).thenAnswer((_) async {});
    when(() => mockStorage.setBackupThreshold(any())).thenAnswer((_) async {});
    when(() => mockStorage.saveProfile(any())).thenAnswer((_) async {});
    when(() => mockStorage.setAppPin(any())).thenAnswer((_) async {});
    when(() => mockStorage.setAppLockEnabled(any())).thenAnswer((_) async {});
    when(() => mockStorage.recalculateBilledAmount(any()))
        .thenAnswer((_) async {});
    when(() => mockStorage.repairAccountCurrencies(any()))
        .thenAnswer((_) async => 0);
    when(() => mockRepair.jobs).thenReturn([]);
  });

  Widget createSettingsScreen({User? user}) {
    return ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(mockStorage),
        authStreamProvider.overrideWith((ref) => Stream.value(user)),
        storageInitializerProvider
            .overrideWith((ref) => const AsyncValue.data(true)),
        profilesProvider.overrideWith((ref) => Future.value([
              Profile(id: 'p1', name: 'Profile 1'),
              Profile(id: 'p2', name: 'Profile 2'),
            ])),
        repairServiceProvider.overrideWithValue(mockRepair),
        cloudSyncServiceProvider.overrideWithValue(mockCloudSync),
        authServiceProvider.overrideWithValue(mockAuth),
        jsonDataServiceProvider.overrideWithValue(mockJsonData),
        fileServiceProvider.overrideWithValue(mockFileService),
        themeModeProvider.overrideWith(ThemeModeNotifier.new),
        dashboardConfigProvider.overrideWith(DashboardConfigNotifier.new),
        smartCalculatorEnabledProvider
            .overrideWith(SmartCalculatorEnabledNotifier.new),
        currencyProvider.overrideWith(CurrencyNotifier.new),
        monthlyBudgetProvider.overrideWith(BudgetNotifier.new),
        backupThresholdProvider.overrideWith(BackupThresholdNotifier.new),
        activeProfileIdProvider.overrideWith(ProfileNotifier.new),
        isOfflineProvider.overrideWith(IsOfflineNotifier.new),
      ],
      child: const MaterialApp(
        home: SettingsScreen(),
      ),
    );
  }

  testWidgets('SettingsScreen renders all major sections',
      (WidgetTester tester) async {
    await tester.pumpWidget(createSettingsScreen());
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Dashboard Customization'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Data Management'), 200);
    expect(find.text('Data Management'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Feature Management'), 200);
    expect(find.text('Feature Management'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Profile Management'), 200);
    expect(find.text('Profile Management'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Preferences'), 200);
    expect(find.text('Preferences'), findsOneWidget);
  });

  testWidgets('Theme mode can be changed', (WidgetTester tester) async {
    await tester.pumpWidget(createSettingsScreen());
    await tester.pumpAndSettle();

    final dropdown = find.byType(DropdownButton<ThemeMode>);
    await tester.tap(dropdown);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dark').last);
    await tester.pumpAndSettle();

    verify(() => mockStorage.setThemeMode('dark')).called(1);
  });

  testWidgets('Dashboard customization switches work',
      (WidgetTester tester) async {
    await tester.pumpWidget(createSettingsScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Show Income & Expense'));
    await tester.pumpAndSettle();

    verify(() => mockStorage.saveDashboardConfig(any())).called(1);
  });

  testWidgets('Monthly budget can be updated', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    await tester.pumpWidget(createSettingsScreen());
    await tester.pumpAndSettle();

    final budgetTile = find.text('Monthly Budget');
    await tester.scrollUntilVisible(budgetTile, 500);
    await tester.tap(budgetTile);
    await tester.pumpAndSettle();

    final textField = find.byType(TextField);
    await tester.enterText(textField, '75000');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    verify(() => mockStorage.setMonthlyBudget(75000.0)).called(1);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('Profile switching works', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    await tester.pumpWidget(createSettingsScreen());
    await tester.pumpAndSettle();

    final profile2Tile = find.text('Profile 2');
    await tester.scrollUntilVisible(profile2Tile, 500);
    await tester.tap(profile2Tile);
    await tester.pumpAndSettle();

    verify(() => mockStorage.setActiveProfileId('p2')).called(1);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('Currency can be changed', (WidgetTester tester) async {
    await tester.pumpWidget(createSettingsScreen());
    await tester.pumpAndSettle();

    final currencyTile = find.text('Currency');
    await tester.scrollUntilVisible(currencyTile, 500);
    await tester.tap(currencyTile);
    await tester.pumpAndSettle();

    expect(find.text('Select Currency'), findsOneWidget);
    await tester.tap(find.text(r'US Dollar ($)'));
    await tester.pumpAndSettle();

    verify(() => mockStorage.setCurrencyLocale('en_US')).called(1);
  });

  testWidgets('Backup threshold can be updated', (WidgetTester tester) async {
    await tester.pumpWidget(createSettingsScreen());
    await tester.pumpAndSettle();

    final backupTile = find.text('Backup Reminder');
    await tester.scrollUntilVisible(backupTile, 500);
    await tester.tap(backupTile);
    await tester.pumpAndSettle();

    final textField = find.byType(TextField);
    await tester.enterText(textField, '50');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    verify(() => mockStorage.setBackupThreshold(50)).called(1);
  });

  testWidgets('Add New Profile works', (WidgetTester tester) async {
    await tester.pumpWidget(createSettingsScreen());
    await tester.pumpAndSettle();

    final addProfileTile = find.text('Add New Profile');
    await tester.scrollUntilVisible(addProfileTile, 500);
    await tester.tap(addProfileTile);
    await tester.pumpAndSettle();

    final textField = find.byType(TextField);
    await tester.enterText(textField, 'New Test Profile');
    await tester.tap(find.text('CREATE'));
    await tester.pumpAndSettle();

    verify(() => mockStorage.saveProfile(any())).called(1);
  });

  testWidgets('Logout confirmation dialog shows', (WidgetTester tester) async {
    final mockUser = MockUser();
    when(() => mockUser.email).thenReturn('test@example.com');

    await tester.pumpWidget(createSettingsScreen(user: mockUser));
    await tester.pumpAndSettle();

    final logoutTile = find.widgetWithText(ListTile, 'Logout');
    await tester.scrollUntilVisible(logoutTile, 500);
    await tester.tap(logoutTile);
    await tester.pumpAndSettle();

    expect(find.text('Are you sure you want to logout?'), findsOneWidget);
  });

  testWidgets('Repair Data dialog shows and can run a job',
      (WidgetTester tester) async {
    final job = MockRepairJob();
    when(() => job.id).thenReturn('test_job');
    when(() => job.name).thenReturn('Test Job');
    when(() => job.description).thenReturn('Test Desc');
    when(() => job.showInSettings).thenReturn(true);
    when(() => job.run(any(), args: any(named: 'args')))
        .thenAnswer((_) async => 5);

    when(() => mockRepair.jobs).thenReturn([job]);

    await tester.pumpWidget(createSettingsScreen());
    await tester.pumpAndSettle();

    final repairTile = find.text('Repair Data');
    await tester.scrollUntilVisible(repairTile, 500);
    await tester.tap(repairTile);
    await tester.pumpAndSettle();

    expect(find.text('Data Repair'), findsOneWidget);
    expect(find.text('Test Job'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pumpAndSettle();

    verify(() => job.run(any())).called(1);
  });

  testWidgets('App Lock PIN flow', (WidgetTester tester) async {
    await tester.pumpWidget(createSettingsScreen());
    await tester.pumpAndSettle();

    final appLockTile = find.text('App Lock (PIN)');
    await tester.scrollUntilVisible(appLockTile, 500);
    await tester.tap(appLockTile);
    await tester.pumpAndSettle();

    expect(find.text('Set App PIN'), findsOneWidget);

    final textField = find.byType(TextField);
    await tester.enterText(textField, '1234');
    await tester.tap(find.text('SAVE & ENABLE'));
    await tester.pumpAndSettle();

    verify(() => mockStorage.setAppPin('1234')).called(1);
    verify(() => mockStorage.setAppLockEnabled(true)).called(1);
  });

  testWidgets('Clear Cloud Data flow', (WidgetTester tester) async {
    final mockUser = MockUser();
    when(() => mockUser.email).thenReturn('test@example.com');
    when(() => mockAuth.signInWithGoogle(any()))
        .thenAnswer((_) async => AuthResponse(status: AuthStatus.success));
    when(() => mockCloudSync.deleteCloudData()).thenAnswer((_) async {});

    await tester.pumpWidget(createSettingsScreen(user: mockUser));
    await tester.pumpAndSettle();

    final clearTile = find.textContaining('Clear Cloud Data (Keep Account)');
    await tester.scrollUntilVisible(clearTile, 500);
    await tester.tap(clearTile);
    await tester.pumpAndSettle();

    expect(find.text('⚠️ Clear Cloud Data?'), findsOneWidget);
    await tester.tap(find.text('CLEAR CLOUD DATA'));
    await tester.pumpAndSettle();

    verify(() => mockCloudSync.deleteCloudData()).called(1);
  });

  testWidgets('Deactivate Account flow', (WidgetTester tester) async {
    final mockUser = MockUser();
    when(() => mockUser.email).thenReturn('test@example.com');
    when(() => mockAuth.signInWithGoogle(any()))
        .thenAnswer((_) async => AuthResponse(status: AuthStatus.success));
    when(() => mockCloudSync.deleteCloudData()).thenAnswer((_) async {});
    when(() => mockAuth.deleteAccount()).thenAnswer((_) async {});

    await tester.pumpWidget(createSettingsScreen(user: mockUser));
    await tester.pumpAndSettle();

    final deactivateTile = find.textContaining('Deactivate & Wipe Cloud Data');
    await tester.scrollUntilVisible(deactivateTile, 500);
    await tester.tap(deactivateTile);
    await tester.pumpAndSettle();

    expect(find.text('⚠️ Deactivate Cloud Account?'), findsOneWidget);
    await tester.tap(find.text('WIPE & DEACTIVATE'));
    await tester.pumpAndSettle();

    verify(() => mockCloudSync.deleteCloudData()).called(1);
    verify(() => mockAuth.deleteAccount()).called(1);
  });

  testWidgets('Backup Data (ZIP) flow', (WidgetTester tester) async {
    when(() => mockJsonData.createBackupPackage())
        .thenAnswer((_) async => [1, 2, 3]);
    when(() => mockFileService.saveFile(any(), any()))
        .thenAnswer((_) async => 'Saved to fake_path.zip');

    await tester.pumpWidget(createSettingsScreen());
    await tester.pumpAndSettle();

    final backupTile = find.text('Backup Data (ZIP)');
    await tester.scrollUntilVisible(backupTile, 500);
    await tester.tap(backupTile);
    await tester.pumpAndSettle();

    verify(() => mockJsonData.createBackupPackage()).called(1);
    verify(() => mockFileService.saveFile(any(), any())).called(1);
    expect(find.text('Saved to fake_path.zip'), findsOneWidget);
  });

  testWidgets('Restore Data (ZIP) flow', (WidgetTester tester) async {
    when(() => mockFileService.pickFile(
            allowedExtensions: any(named: 'allowedExtensions')))
        .thenAnswer((_) async => Uint8List.fromList([1, 2, 3]));
    when(() => mockJsonData.restoreFromPackage(any()))
        .thenAnswer((_) async => {'profiles': 1});

    await tester.pumpWidget(createSettingsScreen());
    await tester.pumpAndSettle();

    final restoreTile = find.text('Restore Data (ZIP)');
    await tester.scrollUntilVisible(restoreTile, 500);
    await tester.tap(restoreTile);
    await tester.pumpAndSettle();

    // 1. Safety Dialog
    expect(find.text('⚠️ Restoring from ZIP'), findsOneWidget);
    await tester.tap(find.text('Yes, Restore'));
    // Use pump instead of pumpAndSettle because a progress spinner might be animating
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 1));

    // 2. Summary Dialog
    expect(find.text('Restore Complete'), findsOneWidget);
    expect(find.textContaining('profiles: 1'), findsOneWidget);

    verify(() => mockJsonData.restoreFromPackage(any())).called(1);
    // Note: We avoid tapping 'OK, Reload' here because it navigates to DashboardScreen,
    // which requires many more provider mocks than are relevant for this SettingsScreen test.
  });
}
