import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:samriddhi_flow/screens/settings_screen.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/feature_providers.dart';
import 'package:samriddhi_flow/core/cloud_config.dart';
import 'package:samriddhi_flow/services/storage_service.dart';
import 'package:samriddhi_flow/services/subscription_service.dart';
import 'package:samriddhi_flow/services/ad_service.dart' hide adServiceProvider;
import 'package:samriddhi_flow/models/profile.dart';
import 'package:samriddhi_flow/models/dashboard_config.dart';
import 'package:samriddhi_flow/services/repair_service.dart';
import 'package:samriddhi_flow/services/auth_service.dart';
import 'package:samriddhi_flow/services/cloud_sync_service.dart';
import 'package:samriddhi_flow/services/json_data_service.dart';
import 'package:samriddhi_flow/services/file_service.dart';
import 'package:samriddhi_flow/l10n/app_localizations.dart';

class MockStorageService extends Mock implements StorageService {}

class MockUser extends Mock implements User {}

class MockRepairService extends Mock implements RepairService {}

class MockRepairJob extends Mock implements RepairJob {}

class MockSubscriptionService extends Mock implements SubscriptionService {}

class MockAdService extends Mock implements AdService {}

class FakeRefReader extends Fake implements RefReader {}

class MockCloudSyncService extends Mock implements CloudSyncService {}

class MockAuthService extends Mock implements AuthService {}

class MockJsonDataService extends Mock implements JsonDataService {}

class MockFileService extends Mock implements FileService {}

class MockIsLoggedInNotifier extends IsLoggedInNotifier {
  bool _initialState = false;
  void setInitial(bool v) => _initialState = v;
  @override
  Future<void> setLoggedIn(bool v) async => state = v;
  @override
  bool build() => _initialState;
}

class MockIsOfflineNotifier extends IsOfflineNotifier {
  bool _initialState = false;
  void setInitial(bool v) => _initialState = v;
  @override
  void setOffline(bool v) => state = v;
  @override
  bool build() => _initialState;
}

class MockTxnsSinceBackupNotifier extends TxnsSinceBackupNotifier {
  @override
  int build() => 0;
  @override
  Future<void> reset() async => state = 0;
}

class TrackingTxnsSinceBackupNotifier extends TxnsSinceBackupNotifier {
  TrackingTxnsSinceBackupNotifier({this.initialValue = 0});

  final int initialValue;
  bool resetCalled = false;

  @override
  int build() => initialValue;

  @override
  Future<void> reset() async {
    resetCalled = true;
    await ref.read(storageServiceProvider).resetTxnsSinceBackup();
    state = 0;
  }
}

class MockProfileNotifier extends ProfileNotifier {
  @override
  String build() => 'p1';
  @override
  Future<void> setProfile(String id) async {
    state = id;
    await ref.read(storageServiceProvider).setActiveProfileId(id);
  }
}

void main() {
  late MockStorageService mockStorage;
  late MockCloudSyncService mockCloudSync;
  late MockAuthService mockAuth;
  late MockJsonDataService mockJsonData;
  late MockFileService mockFileService;
  late MockRepairService mockRepair;
  late MockSubscriptionService mockSubscription;
  late MockAdService mockAd;
  late MockUser mockUser;

  setUpAll(() {
    registerFallbackValue(const DashboardVisibilityConfig());
    registerFallbackValue(Profile(id: 'fake', name: 'fake'));
    registerFallbackValue(FakeRefReader());
    registerFallbackValue(AuthResponse(status: AuthStatus.success));
    registerFallbackValue(const AsyncValue<bool>.data(true));
    registerFallbackValue(const DashboardVisibilityConfig());
  });

  setUp(() {
    mockStorage = MockStorageService();
    mockCloudSync = MockCloudSyncService();
    mockAuth = MockAuthService();
    mockJsonData = MockJsonDataService();
    mockFileService = MockFileService();
    mockRepair = MockRepairService();
    mockSubscription = MockSubscriptionService();
    mockAd = MockAdService();
    mockUser = MockUser();

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
    when(() => mockStorage.getCloudDatabaseRegion())
        .thenReturn(CloudDatabaseRegion.india);
    when(() => mockStorage.getAppPin()).thenReturn(null);
    when(() => mockStorage.isPinLocked()).thenReturn(false);
    when(() => mockSubscription.isAdFree()).thenReturn(true);
    when(() => mockSubscription.isCloudSyncEnabled()).thenReturn(true);
    when(() => mockSubscription.getTier()).thenReturn(SubscriptionTier.premium);
    when(() => mockSubscription.getExpiryDate()).thenReturn(null);

    when(() => mockStorage.setThemeMode(any())).thenAnswer((_) async {});
    when(() => mockStorage.saveDashboardConfig(any())).thenAnswer((_) async {});
    when(() => mockStorage.setMonthlyBudget(any())).thenAnswer((_) async {});
    when(() => mockStorage.setActiveProfileId(any())).thenAnswer((_) async {});
    when(() => mockStorage.setCurrencyLocale(any())).thenAnswer((_) async {});
    when(() => mockStorage.setBackupThreshold(any())).thenAnswer((_) async {});
    when(() => mockStorage.saveProfile(any())).thenAnswer((_) async {});
    when(() => mockStorage.setAppPin(any())).thenAnswer((_) async {});
    when(() => mockStorage.setAppLockEnabled(any())).thenAnswer((_) async {});
    when(() => mockStorage.setAuthFlag(any())).thenAnswer((_) async {});
    when(() => mockStorage.setCloudDatabaseRegion(any()))
        .thenAnswer((_) async {});
    when(() => mockStorage.recalculateBilledAmount(any()))
        .thenAnswer((_) async {});
    when(() => mockStorage.resetTxnsSinceBackup()).thenAnswer((_) async {});
    when(() => mockStorage.deleteProfile(any())).thenAnswer((_) async {});
    when(() => mockStorage.copyCategories(any(), any()))
        .thenAnswer((_) async {});
    when(() => mockStorage.repairAccountCurrencies(any()))
        .thenAnswer((_) async => 0);
    when(() => mockRepair.jobs).thenReturn([]);
    when(() => mockFileService.pickFile(
            allowedExtensions: any(named: 'allowedExtensions')))
        .thenAnswer((_) async => null);
    when(() => mockStorage.getLocale()).thenReturn(null);
    when(() => mockStorage.setLocale(any())).thenAnswer((_) async {});
    when(() => mockCloudSync.syncToCloud(
        passcode: any(named: 'passcode'),
        appPin: any(named: 'appPin'))).thenAnswer((_) async {});
  });

  Widget createSettingsScreen(
      {User? user, List<dynamic> overrides = const []}) {
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
        firebaseInitializerProvider.overrideWith((ref) async {}),
        connectivityCheckProvider.overrideWith((ref) => () async => false),
        themeModeProvider.overrideWith(ThemeModeNotifier.new),
        dashboardConfigProvider.overrideWith(DashboardConfigNotifier.new),
        smartCalculatorEnabledProvider
            .overrideWith(SmartCalculatorEnabledNotifier.new),
        currencyProvider.overrideWith(CurrencyNotifier.new),
        monthlyBudgetProvider.overrideWith(BudgetNotifier.new),
        backupThresholdProvider.overrideWith(BackupThresholdNotifier.new),
        activeProfileIdProvider.overrideWith(MockProfileNotifier.new),
        isOfflineProvider.overrideWith(MockIsOfflineNotifier.new),
        isLoggedInProvider.overrideWith(MockIsLoggedInNotifier.new),
        localeProvider.overrideWith(LocaleNotifier.new),
        subscriptionServiceProvider.overrideWithValue(mockSubscription),
        adServiceProvider.overrideWithValue(mockAd),
        ...overrides,
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('en'),
        home: SettingsScreen(),
      ),
    );
  }

  testWidgets('SettingsScreen renders unified header and toggle',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 5000));
    await tester.pumpWidget(createSettingsScreen(user: mockUser));
    await tester.pumpAndSettle();

    // Verify unified header elements
    expect(find.text('Profile 1'), findsOneWidget);
    expect(find.text('PROFILE SETTINGS'), findsOneWidget);
    expect(find.byIcon(Icons.add_circle_outline), findsWidgets);

    // Verify toggle buttons
    expect(find.text('Profile Settings'), findsOneWidget);
    expect(find.text('Global Settings'), findsOneWidget);

    // Profile settings should be visible by default
    expect(find.text('Preferences'), findsOneWidget);
    expect(find.text('Data Cleanup & Recovery'), findsOneWidget);
    expect(find.text('Dashboard Customization'), findsOneWidget);
    expect(find.text('Feature Management'), findsOneWidget);

    // Global settings should NOT be visible yet
    expect(find.text('Appearance'), findsNothing);

    // Switch to Global Settings
    await tester.tap(find.text('Global Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Dashboard Customization'), findsNothing);
    expect(find.text('Feature Management'), findsNothing);
  });

  testWidgets('Theme mode can be changed', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 5000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(createSettingsScreen(user: mockUser));
    await tester.pumpAndSettle();

    // Must switch to Global for Appearance
    await tester.tap(find.text('Global Settings'));
    await tester.pumpAndSettle();

    // It's a SegmentedButton now
    final darkBtn = find.text('Dark');
    await tester.scrollUntilVisible(darkBtn, 500);
    await tester.tap(darkBtn);
    await tester.pumpAndSettle();

    verify(() => mockStorage.setThemeMode('dark')).called(1);
  });

  testWidgets('Language can be changed', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 5000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(createSettingsScreen(user: mockUser));
    await tester.pumpAndSettle();

    // Must switch to Global for Appearance/Language
    await tester.tap(find.text('Global Settings'));
    await tester.pumpAndSettle();

    // It's a SegmentedButton now
    final englishBtn = find.text('English');
    await tester.scrollUntilVisible(englishBtn, 500);
    await tester.tap(englishBtn);
    await tester.pumpAndSettle();

    verify(() => mockStorage.setLocale('en')).called(1);

    final systemBtn = find.text('System Default');
    await tester.scrollUntilVisible(systemBtn, 500);
    await tester.tap(systemBtn);
    await tester.pumpAndSettle();

    verify(() => mockStorage.setLocale(null)).called(1);
  });

  testWidgets('Dashboard customization switches work',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 5000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(createSettingsScreen(user: mockUser));
    await tester.pumpAndSettle();

    final incomeSwitch = find.text('Show Income & Expense');
    await tester.scrollUntilVisible(incomeSwitch, 500);
    await tester.tap(incomeSwitch);
    await tester.pumpAndSettle();

    verify(() => mockStorage.saveDashboardConfig(any())).called(1);
  });

  testWidgets('Monthly budget can be updated', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 5000));
    await tester.pumpWidget(createSettingsScreen(user: mockUser));
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
    await tester.binding.setSurfaceSize(const Size(800, 5000));
    await tester.pumpWidget(createSettingsScreen(user: mockUser));
    await tester.pumpAndSettle();

    // Now uses AppBar switcher
    final dropdown = find.byType(DropdownButton<String>);
    await tester.tap(dropdown);
    await tester.pumpAndSettle();

    final profile2Option = find.text('Profile 2').last;
    await tester.tap(profile2Option);
    await tester.pumpAndSettle();

    verify(() => mockStorage.setActiveProfileId('p2')).called(1);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('Currency can be changed', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 5000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(createSettingsScreen(user: mockUser));
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
    await tester.binding.setSurfaceSize(const Size(800, 5000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(createSettingsScreen(user: mockUser));
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
    await tester.binding.setSurfaceSize(const Size(800, 5000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(createSettingsScreen(user: mockUser));
    await tester.pumpAndSettle();

    final addProfileBtn = find.byIcon(Icons.add_circle_outline).first;
    await tester.tap(addProfileBtn);
    await tester.pumpAndSettle();

    final textField = find.byType(TextField);
    await tester.enterText(textField, 'New Test Profile');
    await tester.tap(find.text('CREATE'));
    await tester.pumpAndSettle();

    verify(() => mockStorage.saveProfile(any())).called(1);
  });

  testWidgets('Logout confirmation dialog shows', (WidgetTester tester) async {
    when(() => mockUser.email).thenReturn('test@example.com');

    await tester.binding.setSurfaceSize(const Size(800, 5000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(createSettingsScreen(user: mockUser));
    await tester.pumpAndSettle();

    // Switch to Global for Logout
    await tester.tap(find.text('Global Settings'));
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

    await tester.binding.setSurfaceSize(const Size(800, 5000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(createSettingsScreen(user: mockUser));
    await tester.pumpAndSettle();

    // Repair Data is now in Profile Settings, no need to switch modes.

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
    await tester.binding.setSurfaceSize(const Size(800, 5000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(createSettingsScreen(user: mockUser));
    await tester.pumpAndSettle();

    // Switch to Global for Security/App Lock
    await tester.tap(find.text('Global Settings'));
    await tester.pumpAndSettle();

    final appLockTile = find.text('App Lock PIN');
    await tester.scrollUntilVisible(appLockTile, 500);
    await tester.tap(appLockTile);
    await tester.pumpAndSettle();

    expect(find.text('Set App PIN'), findsOneWidget);

    final textField = find.byType(TextField);
    await tester.enterText(textField, '1234');
    await tester.tap(find.text('Save & Enable'));
    await tester.pumpAndSettle();

    verify(() => mockStorage.setAppPin('1234')).called(1);
    verify(() => mockStorage.setAppLockEnabled(true)).called(1);
  });

  testWidgets('App Lock PIN flow accepts 6-digit PIN',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 5000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(createSettingsScreen(user: mockUser));
    await tester.pumpAndSettle();

    // Switch to Global for Security/App Lock
    await tester.tap(find.text('Global Settings'));
    await tester.pumpAndSettle();

    final appLockTile = find.text('App Lock PIN');
    await tester.scrollUntilVisible(appLockTile, 500);
    await tester.tap(appLockTile);
    await tester.pumpAndSettle();

    expect(find.text('Set App PIN'), findsOneWidget);

    final textField = find.byType(TextField);
    await tester.enterText(textField, '123456');
    await tester.tap(find.text('Save & Enable'));
    await tester.pumpAndSettle();

    verify(() => mockStorage.setAppPin('123456')).called(1);
    verify(() => mockStorage.setAppLockEnabled(true)).called(1);
  });

  testWidgets('Clear Cloud Data flow', (WidgetTester tester) async {
    when(() => mockUser.email).thenReturn('test@example.com');
    when(() => mockAuth.signInWithGoogle(any()))
        .thenAnswer((_) async => AuthResponse(status: AuthStatus.success));
    when(() => mockCloudSync.deleteCloudData()).thenAnswer((_) async {});

    await tester.binding.setSurfaceSize(const Size(800, 5000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(createSettingsScreen(user: mockUser));
    await tester.pumpAndSettle();

    // Switch to Global for Auth/Clear Cloud
    await tester.tap(find.text('Global Settings'));
    await tester.pumpAndSettle();

    final clearTile = find.textContaining('Clear Cloud Data (Keep Account)');
    await tester.scrollUntilVisible(clearTile, 500);
    await tester.tap(clearTile);
    await tester.pumpAndSettle();

    expect(find.text('Clear Cloud Data?'), findsOneWidget);
    await tester.tap(find.text('CLEAR CLOUD DATA'));
    await tester.pumpAndSettle();

    verify(() => mockCloudSync.deleteCloudData()).called(1);
  });

  testWidgets('Deactivate Account flow', (WidgetTester tester) async {
    when(() => mockUser.email).thenReturn('test@example.com');
    when(() => mockAuth.signInWithGoogle(any()))
        .thenAnswer((_) async => AuthResponse(status: AuthStatus.success));
    when(() => mockCloudSync.deleteCloudData()).thenAnswer((_) async {});
    when(() => mockAuth.deleteAccount()).thenAnswer((_) async {});

    await tester.binding.setSurfaceSize(const Size(800, 4000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(createSettingsScreen(user: mockUser));
    await tester.pumpAndSettle();

    // Switch to Global for Auth/Deactivate
    await tester.tap(find.text('Global Settings'));
    await tester.pumpAndSettle();

    final deactivateTile = find.textContaining('Deactivate & Wipe Cloud Data');
    await tester.scrollUntilVisible(
        deactivateTile, 1500); // Increased scroll delta
    await tester.tap(deactivateTile);
    await tester.pumpAndSettle();

    expect(find.text('Deactivate Cloud Account?'), findsOneWidget);
    await tester.tap(find.text('WIPE & DEACTIVATE'));
    await tester.pumpAndSettle();

    verify(() => mockCloudSync.deleteCloudData()).called(1);
    verify(() => mockAuth.deleteAccount()).called(1);
  });

  testWidgets('Backup Data (ZIP) flow', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 4000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    when(() => mockUser.uid).thenReturn('uid123');
    when(() => mockUser.email).thenReturn('t@e.com');
    when(() => mockJsonData.createBackupPackage(appPin: any(named: 'appPin')))
        .thenAnswer((_) async => [1, 2, 3]);
    when(() => mockFileService.saveFile(any(), any()))
        .thenAnswer((_) async => 'Saved to fake_path.zip');

    await tester.pumpWidget(createSettingsScreen(user: mockUser));
    await tester.pumpAndSettle();

    // Switch to Global for GlobalData/Backup
    await tester.tap(find.text('Global Settings'));
    await tester.pumpAndSettle();

    final backupTile = find.text('Backup Data (ZIP)');
    await tester.scrollUntilVisible(backupTile, 800); // Increased scroll limit
    await tester.tap(backupTile);
    await tester.pumpAndSettle();

    verify(() => mockJsonData.createBackupPackage(appPin: any(named: 'appPin')))
        .called(1);
    verify(() => mockFileService.saveFile(any(), any())).called(1);
    expect(find.text('Saved to fake_path.zip'), findsOneWidget);
  });

  testWidgets('Restore Data (ZIP) flow', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 4000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    when(() => mockUser.uid).thenReturn('uid123');
    when(() => mockUser.email).thenReturn('t@e.com');
    when(() => mockFileService.pickFile(
            allowedExtensions: any(named: 'allowedExtensions')))
        .thenAnswer((_) async => Uint8List.fromList([1, 2, 3]));
    when(() => mockJsonData.restoreFromPackage(any()))
        .thenAnswer((_) async => {'profiles': 1});

    await tester.pumpWidget(createSettingsScreen(user: mockUser));
    await tester.pumpAndSettle();

    // Switch to Global for GlobalData/Restore
    await tester.tap(find.text('Global Settings'));
    await tester.pumpAndSettle();

    final restoreTile = find.text('Restore Data (ZIP)');
    await tester.scrollUntilVisible(restoreTile, 800); // Increased scroll limit
    await tester.tap(restoreTile);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // 1. Safety Dialog
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('Restoring from ZIP'), findsOneWidget);
    await tester.tap(find.text('Yes, Restore'));
    // Use pump instead of pumpAndSettle because a progress spinner might be animating
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 1));

    // 2. Summary Dialog
    expect(find.text('Restore Complete'), findsOneWidget);
    expect(find.textContaining('profiles: 1'), findsOneWidget);

    verify(() => mockJsonData.restoreFromPackage(any())).called(1);
    verify(() => mockStorage.resetTxnsSinceBackup()).called(1);
  });

  testWidgets('Restore Data (ZIP) triggers PIN dialog before file picker',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 4000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    when(() => mockUser.uid).thenReturn('uid123');
    when(() => mockUser.email).thenReturn('t@e.com');
    // 1. Enable App Lock
    when(() => mockStorage.isAppLockEnabled()).thenReturn(true);
    when(() => mockStorage.getAppPin()).thenReturn(
        '0ffe1abd1a08215353c233d6e009613e95eec4253832a761af28ff37ac5a150c'); // Hash of 1111
    when(() => mockStorage.verifyAppPin('1111')).thenReturn(true);
    when(() => mockFileService.pickFile(
            allowedExtensions: any(named: 'allowedExtensions')))
        .thenAnswer((_) async => Uint8List.fromList([1, 2, 3]));

    await tester.pumpWidget(createSettingsScreen(user: mockUser));
    await tester.pumpAndSettle();

    // Switch to Global for GlobalData/Restore
    await tester.tap(find.text('Global Settings'));
    await tester.pumpAndSettle();

    final restoreTile = find.text('Restore Data (ZIP)');
    await tester.scrollUntilVisible(restoreTile, 800); // Increased scroll limit
    await tester.tap(restoreTile);
    await tester.pumpAndSettle();

    // 2. Verify PIN dialog appears first
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('Verify App PIN'), findsOneWidget);

    // 3. Verify pickFile has NOT been called yet
    verifyNever(() => mockFileService.pickFile(
        allowedExtensions: any(named: 'allowedExtensions')));

    // 4. Enter PIN
    await tester.enterText(find.byType(TextField), '1111');
    await tester.tap(find.text('Verify'));
    await tester.pumpAndSettle();

    // 5. Now pickFile should be called
    verify(() => mockFileService.pickFile(
        allowedExtensions: any(named: 'allowedExtensions'))).called(1);
  });

  testWidgets('Cloud Sync Success resets backup reminder counter',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 4000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final txnsNotifier = TrackingTxnsSinceBackupNotifier(initialValue: 12);
    when(() => mockUser.email).thenReturn('test@example.com');

    // 1. Setup mock cloud sync to succeed
    when(() => mockCloudSync.syncToCloud(
        passcode: any(named: 'passcode'),
        appPin: any(named: 'appPin'))).thenAnswer((_) async {});

    await tester.binding.setSurfaceSize(const Size(800, 5000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(mockStorage),
        authStreamProvider.overrideWith((ref) => Stream.value(mockUser)),
        storageInitializerProvider
            .overrideWith((ref) => const AsyncValue.data(true)),
        profilesProvider.overrideWith((ref) => Future.value([])),
        repairServiceProvider.overrideWithValue(mockRepair),
        cloudSyncServiceProvider.overrideWithValue(mockCloudSync),
        authServiceProvider.overrideWithValue(mockAuth),
        jsonDataServiceProvider.overrideWithValue(mockJsonData),
        fileServiceProvider.overrideWithValue(mockFileService),
        firebaseInitializerProvider.overrideWith((ref) async {}),
        themeModeProvider.overrideWith(ThemeModeNotifier.new),
        dashboardConfigProvider.overrideWith(DashboardConfigNotifier.new),
        smartCalculatorEnabledProvider
            .overrideWith(SmartCalculatorEnabledNotifier.new),
        currencyProvider.overrideWith(CurrencyNotifier.new),
        monthlyBudgetProvider.overrideWith(BudgetNotifier.new),
        backupThresholdProvider.overrideWith(BackupThresholdNotifier.new),
        activeProfileIdProvider.overrideWith(MockProfileNotifier.new),
        isOfflineProvider.overrideWith(MockIsOfflineNotifier.new),
        isLoggedInProvider.overrideWith(MockIsLoggedInNotifier.new),
        subscriptionServiceProvider.overrideWithValue(mockSubscription),
        adServiceProvider.overrideWithValue(mockAd),
        txnsSinceBackupProvider.overrideWith(() => txnsNotifier),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('en'),
        home: SettingsScreen(),
      ),
    ));

    await tester.pumpAndSettle();

    // Switch to Global for Cloud/Sync
    await tester.tap(find.text('Global Settings'));
    await tester.pumpAndSettle();

    // 3. Trigger Cloud Backup
    final syncTile = find.text('Migrate/Sync Now');
    await tester.scrollUntilVisible(syncTile, 500);
    await tester.tap(syncTile);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    // 4. Handle Passcode Prompt
    expect(find.text('Cloud Backup'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '1234');
    await tester.tap(find.text('ENCRYPT & BACKUP'));
    await tester.pumpAndSettle();

    // 5. Verify sync was called and counter reset triggered
    verify(() => mockCloudSync.syncToCloud(
        passcode: '1234', appPin: any(named: 'appPin'))).called(1);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(txnsNotifier.resetCalled, isTrue);
    expect(txnsNotifier.state, 0);
    verify(() => mockStorage.resetTxnsSinceBackup()).called(1);
    expect(find.text('Cloud Sync Success!'), findsOneWidget);
  });

  testWidgets('Delete Profile confirmation dialog and execution',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 5000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(createSettingsScreen(user: mockUser));
    await tester.pumpAndSettle();

    // In the inline unified header, we need to select profile 2 first to delete it
    // Wait, the delete button only appears if profiles.length > 1 AND it's not the last profile?
    // Actually, in our new logic, the delete button appears right beside the dropdown for the ACTIVE profile!
    // But ONLY if there are multiple profiles. Wait, `if(profiles.length > 1)` then we show delete button.
    final deleteIcon = find.byIcon(Icons.delete_outline).first;
    await tester.tap(deleteIcon);
    await tester.pumpAndSettle();

    expect(find.text('Delete Profile?'), findsOneWidget);
    expect(find.textContaining("PERMANENTLY delete the profile 'Profile 1'"),
        findsOneWidget);

    await tester.tap(find.text('DELETE'));
    await tester.pumpAndSettle();

    verify(() => mockStorage.deleteProfile('p1')).called(1);
  });

  testWidgets('Copy Categories dialog shows other profiles',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 5000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(createSettingsScreen(user: mockUser));
    await tester.pumpAndSettle();

    // Now in inline header
    final copyIcon = find.byIcon(Icons.copy_all).first;
    await tester.tap(copyIcon);
    await tester.pumpAndSettle();

    expect(find.text('Copy Categories'), findsOneWidget);

    // SimpleDialog options are usually found by text directly
    // Use descendant to avoid finding the profile name in the header dropdown
    final profileOption = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('Profile 2'),
    );
    await tester.tap(profileOption);
    await tester.pumpAndSettle();

    verify(() => mockStorage.copyCategories('p2', 'p1')).called(1);
    expect(find.text('Categories copied to Profile 1'), findsOneWidget);
  });

  testWidgets('App Lock - Use Existing PIN flow', (WidgetTester tester) async {
    // Removed 1600px size
    when(() => mockStorage.getAppPin()).thenReturn('hashed_pin');

    await tester.binding.setSurfaceSize(const Size(800, 5000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(createSettingsScreen(user: mockUser));
    await tester.pumpAndSettle();

    // Switch to Global for Security/App Lock
    await tester.tap(find.text('Global Settings'));
    await tester.pumpAndSettle();

    final appLockTile = find.text('App Lock PIN');
    await tester.scrollUntilVisible(appLockTile, 500);
    await tester.tap(appLockTile);
    await tester.pumpAndSettle();

    expect(find.text('Use Existing PIN'), findsOneWidget);
    await tester.tap(find.text('Use Existing PIN'));
    await tester.pumpAndSettle();

    verify(() => mockStorage.setAppLockEnabled(true)).called(1);
    expect(find.text('App Lock Enabled'), findsOneWidget);
  });

  testWidgets('App Lock - Verify PIN with incorrect entry',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 4000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    when(() => mockStorage.isAppLockEnabled()).thenReturn(true);
    when(() => mockStorage.verifyAppPin('1111')).thenReturn(false);

    await tester.pumpWidget(createSettingsScreen(user: mockUser));
    await tester.pumpAndSettle();

    // Switch to Global for Security/App Lock
    await tester.tap(find.text('Global Settings'));
    await tester.pumpAndSettle();

    final appLockSwitch = find.byWidgetPredicate((widget) =>
        widget is SwitchListTile &&
        widget.title is Text &&
        (widget.title as Text).data!.contains('App Lock'));
    await tester.scrollUntilVisible(appLockSwitch, 500);
    await tester.tap(appLockSwitch);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '1111');
    await tester.tap(find.text('Verify'));
    await tester.pumpAndSettle();

    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('Incorrect PIN'), findsOneWidget);
  });

  testWidgets('Cloud Backup - Encryption Passcode prompt validation',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    when(() => mockUser.email).thenReturn('test@example.com');

    await tester.pumpWidget(createSettingsScreen(user: mockUser));
    await tester.pumpAndSettle();

    // Switch to Global for Cloud/Sync
    await tester.tap(find.text('Global Settings'));
    await tester.pumpAndSettle();

    final syncTile = find.text('Migrate/Sync Now');
    await tester.scrollUntilVisible(syncTile, 500);
    await tester.tap(syncTile);
    await tester.pumpAndSettle();

    // Trigger submit without entering passcode
    await tester.tap(find.text('ENCRYPT & BACKUP'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter a passcode'), findsOneWidget);

    // Toggle off encryption
    final encryptSwitch = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(SwitchListTile),
    );
    await tester.tap(encryptSwitch);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Backup Unencrypted'));
    await tester.pumpAndSettle();

    verify(() => mockCloudSync.syncToCloud(
        passcode: '', appPin: any(named: 'appPin'))).called(1);
  });

  testWidgets('Restore Data (ZIP) cancellation', (WidgetTester tester) async {
    when(() => mockUser.uid).thenReturn('uid123');
    when(() => mockUser.email).thenReturn('t@e.com');
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    when(() => mockFileService.pickFile(
            allowedExtensions: any(named: 'allowedExtensions')))
        .thenAnswer((_) async => Uint8List(0));

    await tester.pumpWidget(createSettingsScreen(user: mockUser));
    await tester.pumpAndSettle();

    // Switch to Global for Restore
    await tester.tap(find.text('Global Settings'));
    await tester.pumpAndSettle();

    final restoreTile = find.text('Restore Data (ZIP)');
    await tester.scrollUntilVisible(restoreTile, 500);
    await tester.tap(restoreTile);
    await tester.pumpAndSettle();

    expect(find.text('Restoring from ZIP'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Restoring from ZIP'), findsNothing);
  });

  testWidgets('Sections are expanded by default', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 5000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(createSettingsScreen(user: mockUser));
    await tester.pumpAndSettle();

    // Switch to Global for Appearance
    await tester.tap(find.text('Global Settings'));
    await tester.pumpAndSettle();

    // Check if 'Theme Mode' is visible (it's inside 'Appearance')
    expect(find.text('Theme Mode'), findsOneWidget);
  });

  testWidgets('Clicking a section header toggles visibility',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 5000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(createSettingsScreen(user: mockUser));
    await tester.pumpAndSettle();

    // Switch to Global for Appearance
    await tester.tap(find.text('Global Settings'));
    await tester.pumpAndSettle();

    final appearanceHeader = find.text('Appearance');
    await tester.tap(appearanceHeader);
    await tester.pumpAndSettle();

    // After collapsing, 'Theme Mode' should not be visible
    expect(find.text('Theme Mode', skipOffstage: true), findsNothing);

    await tester.tap(appearanceHeader);
    await tester.pumpAndSettle();

    // After expanding, it should be visible again
    expect(find.text('Theme Mode', skipOffstage: true), findsOneWidget);
  });

  testWidgets('Global expand/collapse button works',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 5000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(createSettingsScreen(user: mockUser));
    await tester.pumpAndSettle();

    final globalToggleButton =
        find.byIcon(Icons.unfold_less); // Initial state is all expanded
    await tester.tap(globalToggleButton);
    await tester.pumpAndSettle();

    // All should be collapsed
    expect(find.text('Currency', skipOffstage: true), findsNothing);
    expect(
        find.text('Show Income & Expense', skipOffstage: true), findsNothing);

    final expandAllButton = find.byIcon(Icons.unfold_more);
    await tester.tap(expandAllButton);
    await tester.pumpAndSettle();

    // All should be expanded
    expect(find.text('Currency', skipOffstage: true), findsOneWidget);
    expect(
        find.text('Show Income & Expense', skipOffstage: true), findsOneWidget);
  });

  testWidgets(
      'Server Region selection shows Snackbar when data is already synced',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 5000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    when(() => mockUser.uid).thenReturn('uid123');
    when(() => mockUser.email).thenReturn('t@e.com');
    when(() => mockStorage.getAllSettings())
        .thenReturn({'last_sync': DateTime.now().toIso8601String()});
    await tester.pumpWidget(createSettingsScreen(user: mockUser));
    await tester.pumpAndSettle();

    // Switch to Global for Region
    await tester.tap(find.text('Global Settings'));
    await tester.pumpAndSettle();

    // Verify Title and Subtitle
    // Consolidated duplicate keys used "Cloud Backup Region"
    expect(find.text('Cloud Backup Region'), findsOneWidget);
    expect(
        find.text('Manual selection of backup storage zone'), findsOneWidget);

    // Verify static text for region (value from notifier)
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.indiaLabel), findsOneWidget);

    // Verify it shows a Snackbar when user is logged in
    await tester.tap(find.text(l10n.indiaLabel));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('Region cannot be changed'), findsOneWidget);
  });

  testWidgets('Server Region selection dialog opens when data is NOT synced',
      (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 5000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    when(() => mockStorage.getAllSettings()).thenReturn({});
    await tester.pumpWidget(createSettingsScreen(user: mockUser));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    // Switch to Global for Region
    await tester.tap(find.text('Global Settings'));
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.indiaLabel));
    await tester.pumpAndSettle();
    expect(find.text('Select Cloud Region'), findsOneWidget);
  });

  testWidgets('Premium section shows active status',
      (WidgetTester tester) async {
    when(() => mockSubscription.isCloudSyncEnabled()).thenReturn(true);
    await tester.binding.setSurfaceSize(const Size(800, 5000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(createSettingsScreen(user: mockUser));
    await tester.pumpAndSettle();

    // Switch to Global for Premium
    await tester.tap(find.text('Global Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Premium Features'), findsOneWidget);
    expect(find.text('Premium Active'), findsOneWidget);
  });

  // Removed obsolete GeoIP restriction tests
}
