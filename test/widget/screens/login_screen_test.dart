import 'package:samriddhi_flow/l10n/app_localizations.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mocktail/mocktail.dart';

import 'package:samriddhi_flow/providers.dart';

import 'package:samriddhi_flow/feature_providers.dart';

import 'package:samriddhi_flow/services/auth_service.dart';

import 'package:samriddhi_flow/services/cloud_sync_service.dart';

import 'package:samriddhi_flow/services/storage_service.dart';

import 'package:samriddhi_flow/services/notification_service.dart';

import 'package:samriddhi_flow/services/taxes/tax_config_service.dart';

import 'package:samriddhi_flow/widgets/auth_wrapper.dart';
import 'package:samriddhi_flow/core/cloud_config.dart';

import 'package:samriddhi_flow/models/profile.dart';

import 'package:samriddhi_flow/models/taxes/tax_rules.dart';

import 'package:samriddhi_flow/models/category.dart';

import 'package:samriddhi_flow/models/dashboard_config.dart';

import 'package:firebase_auth/firebase_auth.dart';

// Mocks

class MockAuthService extends Mock implements AuthService {}

class MockStorageService extends Mock implements StorageService {}

class MockCloudSyncService extends Mock implements CloudSyncService {}

class MockNotificationService extends Mock implements NotificationService {}

class MockTaxConfigService extends Mock implements TaxConfigService {}

class MockUser extends Mock implements User {}

class MockIsLoggedInNotifier extends IsLoggedInNotifier {
  bool _state = false;

  @override
  bool get state => _state;

  @override
  set state(bool v) => _state = v;

  @override
  Future<void> setLoggedIn(bool v) async => state = v;

  @override
  bool build() => _state;
}

class MockLocalModeNotifier extends LocalModeNotifier {
  @override
  bool build() => false;
}

class MockIsOfflineNotifier extends IsOfflineNotifier {
  @override
  bool build() => false;

  @override
  void setOffline(bool v) => state = v;
}

class MockSmartCalculatorEnabledNotifier
    extends SmartCalculatorEnabledNotifier {
  @override
  bool build() => true;
}

class MockThemeModeNotifier extends ThemeModeNotifier {
  @override
  ThemeMode build() => ThemeMode.light;
}

class MockCurrencyNotifier extends CurrencyNotifier {
  @override
  String build() => 'en_IN';
}

class MockBackupThresholdNotifier extends BackupThresholdNotifier {
  @override
  int build() => 20;
}

class MockTxnsSinceBackupNotifier extends TxnsSinceBackupNotifier {
  @override
  int build() => 0;
}

class MockLocaleNotifier extends LocaleNotifier {
  @override
  Locale? build() => null;

  @override
  Future<void> setLocale(String? localeCode) async {
    state = localeCode != null ? Locale(localeCode) : null;
  }
}

class MockCategoriesNotifier extends CategoriesNotifier {
  @override
  List<Category> build() => [];
}

class MockDashboardConfigNotifier extends DashboardConfigNotifier {
  @override
  DashboardVisibilityConfig build() => const DashboardVisibilityConfig();
}

class MockBudgetNotifier extends BudgetNotifier {
  @override
  double build() => 0.0;
}

class MockHolidaysNotifier extends HolidaysNotifier {
  @override
  List<DateTime> build() => [];
}

void main() {
  late MockAuthService mockAuthService;

  late MockStorageService mockStorageService;

  late MockCloudSyncService mockCloudSyncService;

  late MockNotificationService mockNotificationService;

  late MockTaxConfigService mockTaxConfigService;

  late MockIsLoggedInNotifier mockIsLoggedInNotifier;

  setUpAll(() {
    registerFallbackValue(MockUser());

    registerFallbackValue(DateTime.now());
  });

  setUp(() {
    mockAuthService = MockAuthService();

    mockStorageService = MockStorageService();

    mockCloudSyncService = MockCloudSyncService();

    mockNotificationService = MockNotificationService();

    mockTaxConfigService = MockTaxConfigService();

    mockIsLoggedInNotifier = MockIsLoggedInNotifier();

    // Default Stubs

    when(() => mockAuthService.authStateChanges)
        .thenAnswer((_) => Stream.value(null));

    when(() => mockAuthService.isSignOutInProgress).thenReturn(false);

    when(() => mockAuthService.signInWithGoogle(any()))
        .thenAnswer((_) async => AuthResponse(status: AuthStatus.success));

    when(() => mockStorageService.getAllAccounts()).thenReturn([]);

    when(() => mockStorageService.getAllTransactions()).thenReturn([]);

    when(() => mockStorageService.getLastLogin()).thenReturn(null);

    when(() => mockStorageService.getAccounts()).thenReturn([]);

    when(() => mockStorageService.getProfiles()).thenReturn([]);

    when(() => mockStorageService.getActiveProfileId()).thenReturn('default');

    when(() => mockStorageService.getAuthFlag()).thenReturn(true);

    when(() => mockStorageService.setAuthFlag(any())).thenAnswer((_) async {});

    when(() => mockStorageService.resetTxnsSinceBackup())
        .thenAnswer((_) async {});

    when(() => mockStorageService.isAppLockEnabled()).thenReturn(false);

    when(() => mockStorageService.getAppPin()).thenReturn(null);

    when(() => mockStorageService.setLastLogin(any())).thenAnswer((_) async {});

    when(() => mockNotificationService.init()).thenAnswer((_) async {});

    when(() => mockNotificationService.checkNudges())
        .thenAnswer((_) async => <String>[]);

    when(() => mockTaxConfigService.getCurrentFinancialYear()).thenReturn(2025);

    when(() => mockTaxConfigService.getRulesForYear(any()))
        .thenReturn(TaxRules(profileId: 'default'));

    when(() => mockStorageService.getCloudDatabaseRegion())
        .thenReturn(CloudDatabaseRegion.india);
  });

  Widget buildTestWidget() {
    final testProfile = Profile(id: 'default', name: 'Test Profile');

    return ProviderScope(
      overrides: [
        authServiceProvider.overrideWithValue(mockAuthService),

        storageServiceProvider.overrideWithValue(mockStorageService),

        cloudSyncServiceProvider.overrideWithValue(mockCloudSyncService),

        notificationServiceProvider.overrideWithValue(mockNotificationService),

        taxConfigServiceProvider.overrideWithValue(mockTaxConfigService),

        localModeProvider.overrideWith(MockLocalModeNotifier.new),

        isLoggedInProvider.overrideWith(() => mockIsLoggedInNotifier),

        isOfflineProvider.overrideWith(MockIsOfflineNotifier.new),

        firebaseInitializerProvider
            .overrideWith((ref) => const AsyncValue.data(null)),

        storageInitializerProvider
            .overrideWith((ref) => const AsyncValue.data(null)),

        connectivityCheckProvider.overrideWithValue(() async => false),

        activeProfileProvider.overrideWithValue(testProfile),

        accountsProvider.overrideWith((ref) => Stream.value([])),

        transactionsProvider.overrideWith((ref) => Stream.value([])),

        loansProvider.overrideWith((ref) => Stream.value([])),

        recurringTransactionsProvider.overrideWith((ref) => Stream.value([])),

        // Dashboard Crash Prevention Overrides

        pendingRemindersProvider.overrideWithValue(0),

        smartCalculatorEnabledProvider
            .overrideWith(MockSmartCalculatorEnabledNotifier.new),

        themeModeProvider.overrideWith(MockThemeModeNotifier.new),

        appLockStatusProvider.overrideWithValue(false),

        currencyProvider.overrideWith(MockCurrencyNotifier.new),

        backupThresholdProvider.overrideWith(MockBackupThresholdNotifier.new),

        txnsSinceBackupProvider.overrideWith(MockTxnsSinceBackupNotifier.new),

        categoriesProvider.overrideWith(MockCategoriesNotifier.new),

        dashboardConfigProvider.overrideWith(MockDashboardConfigNotifier.new),

        monthlyBudgetProvider.overrideWith(MockBudgetNotifier.new),

        holidaysProvider.overrideWith(MockHolidaysNotifier.new),

        localeProvider.overrideWith(MockLocaleNotifier.new),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AuthWrapper(),
        ),
      ),
    );
  }

  testWidgets(
      'LoginScreen autoRestore shows passcode prompt on encrypted backup',
      (tester) async {
    final mockUser = MockUser();

    final streamController = StreamController<User?>(sync: true);

    when(() => mockAuthService.authStateChanges)
        .thenAnswer((_) => streamController.stream);

    streamController.add(null);

    when(() => mockAuthService.currentUser).thenReturn(mockUser);

    // Use more explicit stubs for passcode scenarios

    when(() => mockCloudSyncService.restoreFromCloud(passcode: null))
        .thenAnswer((_) async => throw Exception("Passcode required"));

    when(() => mockCloudSyncService.restoreFromCloud(passcode: '1234'))
        .thenAnswer((_) async => Future.value());

    await tester.pumpWidget(buildTestWidget());

    await tester.pumpAndSettle();

    // Tap sign in

    await tester.tap(find.text('Continue with Google'));

    await tester.pumpAndSettle();

    // Bypass boot grace period

    await tester.pump(const Duration(seconds: 6));

    // Trigger auto-restore via stream

    await tester.runAsync(() async {
      streamController.add(mockUser);

      // Wait for async listener and the initial restore attempt

      await Future.delayed(const Duration(seconds: 1));
    });

    // Pump frames to render the dialog

    for (int i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    await tester.pumpAndSettle();

    // Verify dialog appears

    expect(find.text('Encrypted Backup Found', skipOffstage: false),
        findsOneWidget);

    // Enter passcode and submit

    await tester.enterText(find.byType(TextField), '1234');

    await tester.tap(find.text('RESTORE'));

    await tester.runAsync(() async {
      // Wait for the second restore attempt

      await Future.delayed(const Duration(milliseconds: 500));
    });

    await tester.pumpAndSettle();

    verify(() => mockCloudSyncService.restoreFromCloud(passcode: '1234'))
        .called(1);

    streamController.close();
  });

  testWidgets('LoginScreen allows changing language', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    final languageIcon = find.byIcon(Icons.language);
    expect(languageIcon, findsOneWidget);

    await tester.tap(languageIcon);
    await tester.pumpAndSettle();

    expect(find.text('English'), findsOneWidget);
    expect(find.text('System Default'), findsOneWidget);

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    // Verify UI updated to English (appTitle would be "Samriddhi Flow")
    expect(find.text('Samriddhi Flow'), findsOneWidget);
  });
}
