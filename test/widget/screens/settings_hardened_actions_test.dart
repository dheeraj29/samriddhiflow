import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/feature_providers.dart';
import 'package:samriddhi_flow/screens/settings_screen.dart';
import 'package:samriddhi_flow/services/auth_service.dart';
import 'package:samriddhi_flow/services/storage_service.dart';
import 'package:samriddhi_flow/services/cloud_sync_service.dart';
import 'package:samriddhi_flow/models/dashboard_config.dart';
import 'package:samriddhi_flow/l10n/app_localizations.dart';
import 'package:samriddhi_flow/core/cloud_config.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:samriddhi_flow/services/subscription_service.dart';

class MockAuthService extends Mock implements AuthService {}

class MockStorageService extends Mock implements StorageService {}

class MockCloudSyncService extends Mock implements CloudSyncService {}

class MockUser extends Mock implements User {}

class MockSubscriptionService extends Mock implements SubscriptionService {}

class FakeIsOfflineNotifier extends IsOfflineNotifier {
  @override
  bool build() => false;
}

void main() {
  late MockAuthService mockAuthService;
  late MockStorageService mockStorageService;
  late MockCloudSyncService mockCloudSync;
  late MockUser mockUser;
  late MockSubscriptionService mockSubscription;

  setUp(() {
    mockAuthService = MockAuthService();
    mockStorageService = MockStorageService();
    mockCloudSync = MockCloudSyncService();
    mockUser = MockUser();
    mockSubscription = MockSubscriptionService();

    when(() => mockSubscription.isCloudSyncEnabled()).thenReturn(true);
    when(() => mockSubscription.getTier()).thenReturn(SubscriptionTier.free);
    when(() => mockSubscription.getExpiryDate()).thenReturn(null);

    when(() => mockUser.uid).thenReturn('test-uid');
    when(() => mockUser.email).thenReturn('test@example.com');
    when(() => mockUser.displayName).thenReturn('Test User');

    when(() => mockStorageService.getThemeMode()).thenReturn('system');
    when(() => mockStorageService.getLocale()).thenReturn('en');
    when(() => mockStorageService.getCurrencyLocale()).thenReturn('en_IN');
    when(() => mockStorageService.getMonthlyBudget()).thenReturn(0.0);
    when(() => mockStorageService.isAppLockEnabled()).thenReturn(false);
    when(() => mockStorageService.getProfiles()).thenReturn([]);
    when(() => mockStorageService.getActiveProfileId()).thenReturn('default');
    when(() => mockStorageService.getDashboardConfig())
        .thenReturn(const DashboardVisibilityConfig());
    when(() => mockStorageService.isSmartCalculatorEnabled()).thenReturn(true);
    when(() => mockStorageService.getCloudDatabaseRegion())
        .thenReturn(CloudDatabaseRegion.india);
    when(() => mockStorageService.getAuthFlag()).thenReturn(true);
    when(() => mockStorageService.getBackupThreshold()).thenReturn(10);
    when(() => mockStorageService.getHolidays()).thenReturn([]);
    when(() => mockStorageService.getAppPin()).thenReturn(null);

    // Core data lists for providers
    when(() => mockStorageService.getInvestments()).thenReturn([]);
    when(() => mockStorageService.getAllAccounts()).thenReturn([]);
    when(() => mockStorageService.getAllTransactions()).thenReturn([]);
    when(() => mockStorageService.getAllLoans()).thenReturn([]);
    when(() => mockStorageService.getAllRecurring()).thenReturn([]);
    when(() => mockStorageService.getAllCategories()).thenReturn([]);
    when(() => mockStorageService.getLendingRecords()).thenReturn([]);
    when(() => mockStorageService.getInsurancePolicies()).thenReturn([]);
    when(() => mockStorageService.getAllTaxYearData()).thenReturn([]);

    when(() => mockAuthService.currentUser).thenReturn(mockUser);
    when(() => mockAuthService.isSignOutInProgress).thenReturn(false);
    when(() => mockAuthService.authStateChanges)
        .thenAnswer((_) => Stream.value(mockUser));
  });

  testWidgets('SettingsScreen deactivation wipes local data on session expiry',
      (tester) async {
    // 1. Setup: Throw SESSION_EXPIRED on sync/auth
    when(() => mockAuthService.signInWithGoogle(any()))
        .thenAnswer((_) async => AuthResponse(status: AuthStatus.success));
    when(() => mockStorageService.getSessionId())
        .thenReturn('existing-session');
    when(() => mockAuthService.deleteAccount())
        .thenThrow(Exception("SESSION_EXPIRED"));
    when(() => mockCloudSync.deleteCloudData())
        .thenAnswer((_) async {}); // Stub missing call!
    when(() =>
            mockStorageService.clearAllData(fullWipe: any(named: 'fullWipe')))
        .thenAnswer((_) async {});
    when(() => mockAuthService.signOut(any())).thenAnswer((_) async {});

    await tester.binding.setSurfaceSize(const Size(800, 5000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(mockStorageService),
        authServiceProvider.overrideWithValue(mockAuthService),
        cloudSyncServiceProvider.overrideWithValue(mockCloudSync),
        storageInitializerProvider
            .overrideWithValue(const AsyncValue.data(null)),
        isLoggedInHiveStreamProvider
            .overrideWithValue(const AsyncValue.data(true)),
        isOfflineProvider.overrideWith(FakeIsOfflineNotifier.new),
        connectivityStreamProvider.overrideWithValue(const AsyncValue.data([])),
        authStreamProvider.overrideWithValue(AsyncValue.data(mockUser)),
        subscriptionServiceProvider.overrideWithValue(mockSubscription),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SettingsScreen(),
      ),
    ));

    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    // Switch to global settings
    await tester.tap(find.text('Global Settings'));
    await tester.pumpAndSettle();

    // 2. Trigger the deactivation flow (we must find the list tile that triggers it)
    final deactivateTile = find.text(l10n.deactivateWipeCloudTitle);

    await tester.scrollUntilVisible(deactivateTile, 1000.0);
    await tester.tap(deactivateTile);
    await tester.pumpAndSettle(); // Show dialog

    // 3. Confirm in the dialog
    final confirmButton = find.text(l10n.wipeDeactivateAction);
    expect(confirmButton, findsOneWidget);
    await tester.tap(confirmButton);

    // We expect clearAllData to be called because SESSION_EXPIRED was thrown
    await tester.pumpAndSettle();

    verify(() => mockStorageService.clearAllData(fullWipe: true)).called(1);
    verify(() => mockAuthService.signOut(any())).called(1);
  });
}
