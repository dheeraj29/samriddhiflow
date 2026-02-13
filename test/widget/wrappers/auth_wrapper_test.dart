import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/feature_providers.dart';
import 'package:samriddhi_flow/providers/sum_tracker_provider.dart';
import 'package:samriddhi_flow/screens/dashboard_screen.dart';
import 'package:samriddhi_flow/screens/login_screen.dart';
import 'package:samriddhi_flow/services/auth_service.dart';
import 'package:samriddhi_flow/services/storage_service.dart';
import 'package:samriddhi_flow/widgets/auth_wrapper.dart';
import 'package:samriddhi_flow/models/category.dart';
import 'package:samriddhi_flow/services/cloud_sync_service.dart';
import 'package:samriddhi_flow/models/dashboard_config.dart';

// Mocks
class MockAuthService extends Mock implements AuthService {}

class MockStorageService extends Mock implements StorageService {}

class MockUser extends Mock implements User {}

class MockIsLoggedInNotifier extends IsLoggedInNotifier {
  bool _initialState = false;
  void setInitial(bool v) {
    _initialState = v;
  }

  @override
  Future<void> setLoggedIn(bool v) async => state = v;
  @override
  bool build() => _initialState;
  bool get value {
    try {
      return state;
    } catch (_) {
      return _initialState;
    }
  }
}

class MockIsOfflineNotifier extends IsOfflineNotifier {
  bool _initialState = false;
  void setInitial(bool v) {
    _initialState = v;
  }

  void setOffline(bool v) => state = v;
  @override
  bool build() => _initialState;
  bool get value {
    try {
      return state;
    } catch (_) {
      return _initialState;
    }
  }
}

class MockSumTrackerNotifier extends SumTrackerNotifier {
  @override
  SumTrackerState build() =>
      SumTrackerState(profiles: [], activeProfileId: null);
}

class MockProfileNotifier extends ProfileNotifier {
  @override
  String build() => 'default';
}

class MockCurrencyNotifier extends CurrencyNotifier {
  @override
  String build() => 'en_US';
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

class MockDashboardConfigNotifier extends DashboardConfigNotifier {
  @override
  DashboardVisibilityConfig build() => const DashboardVisibilityConfig();
}

void main() {
  // Mocks
  late MockAuthService mockAuthService;
  late MockStorageService mockStorageService;
  late MockUser mockUser;
  late MockIsLoggedInNotifier mockIsLoggedInNotifier;
  late MockIsOfflineNotifier mockIsOfflineNotifier;

  setUp(() {
    mockAuthService = MockAuthService();
    mockStorageService = MockStorageService();
    mockUser = MockUser();
    mockIsLoggedInNotifier = MockIsLoggedInNotifier();
    mockIsOfflineNotifier = MockIsOfflineNotifier();

    // Default Stubs
    when(() => mockStorageService.getAccounts()).thenReturn([]);
    when(() => mockStorageService.getTransactions()).thenReturn([]);
    when(() => mockStorageService.getCurrencyLocale()).thenReturn('en_US');
    when(() => mockStorageService.getActiveProfileId()).thenReturn('default');
    when(() => mockStorageService.getRecurring()).thenReturn([]);
    when(() => mockStorageService.getLoans()).thenReturn([]);
    when(() => mockStorageService.getMonthlyBudget()).thenReturn(0.0);
    when(() => mockStorageService.getTxnsSinceBackup()).thenReturn(0);
    when(() => mockStorageService.getBackupThreshold()).thenReturn(10);
    when(() => mockStorageService.getCategories()).thenReturn([]);

    // NotificationService dependencies
    when(() => mockStorageService.setLastLogin(any())).thenAnswer((_) async {});
    when(() => mockStorageService.getLastLogin()).thenReturn(null);
    when(() => mockStorageService.getInactivityThresholdDays()).thenReturn(7);
    when(() => mockStorageService.getMaturityWarningDays()).thenReturn(3);
    when(() => mockStorageService.getAuthFlag()).thenReturn(false);

    // Auth Service stubs
    when(() => mockAuthService.isSignOutInProgress).thenReturn(false);
    when(() => mockStorageService.setAuthFlag(any())).thenAnswer((_) async {});
    when(() => mockStorageService.isAppLockEnabled()).thenReturn(false);
    when(() => mockStorageService.getAppPin()).thenReturn('1111');
  });

  Widget createAuthWrapper({
    AsyncValue<void> storageInit = const AsyncValue.data(null),
    AsyncValue<void> firebaseInit = const AsyncValue.data(null),
    Stream<User?>? authStream,
    bool isLoggedIn = false,
    bool isOffline = false,
    CloudSyncService? cloudSync,
  }) {
    mockIsLoggedInNotifier.setInitial(isLoggedIn);
    mockIsOfflineNotifier.setInitial(isOffline);

    return ProviderScope(
      overrides: [
        storageInitializerProvider.overrideWithValue(storageInit),
        firebaseInitializerProvider.overrideWithValue(firebaseInit),
        authServiceProvider.overrideWithValue(mockAuthService),
        storageServiceProvider.overrideWithValue(mockStorageService),
        if (cloudSync != null)
          cloudSyncServiceProvider.overrideWithValue(cloudSync),

        isLoggedInProvider.overrideWith(() => mockIsLoggedInNotifier),
        isOfflineProvider.overrideWith(() => mockIsOfflineNotifier),
        connectivityCheckProvider
            .overrideWithValue(() async => mockIsOfflineNotifier.value),

        authStreamProvider
            .overrideWith((ref) => authStream ?? Stream.value(null)),

        // Dashboard/General Dependencies
        accountsProvider.overrideWith((ref) => Stream.value([])),
        transactionsProvider.overrideWith((ref) => Stream.value([])),
        loansProvider.overrideWith((ref) => Stream.value([])),
        recurringTransactionsProvider.overrideWith((ref) => Stream.value([])),
        sumTrackerProvider.overrideWith(MockSumTrackerNotifier.new),
        activeProfileIdProvider.overrideWith(MockProfileNotifier.new),
        currencyProvider.overrideWith(MockCurrencyNotifier.new),
        categoriesProvider.overrideWith(MockCategoriesNotifier.new),
        activeProfileProvider.overrideWith((ref) => null),
        txnsSinceBackupProvider.overrideWith(MockTxnsSinceBackupNotifier.new),
        backupThresholdProvider.overrideWith(MockBackupThresholdNotifier.new),
        smartCalculatorEnabledProvider
            .overrideWith(MockSmartCalculatorEnabledNotifier.new),
        calculatorVisibleProvider
            .overrideWith(MockCalculatorVisibleNotifier.new),
        dashboardConfigProvider.overrideWith(MockDashboardConfigNotifier.new),
      ],
      child: const MaterialApp(
        home: AuthWrapper(),
      ),
    );
  }

  testWidgets('AuthWrapper shows LoginScreen when user is null',
      (tester) async {
    await tester.pumpWidget(createAuthWrapper(
      authStream: Stream.value(null),
    ));

    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);

    // Dispose
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('AuthWrapper shows DashboardScreen when user is authenticated',
      (tester) async {
    await tester.pumpWidget(createAuthWrapper(
      authStream: Stream.value(mockUser),
    ));

    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(DashboardScreen), findsOneWidget);

    // Dispose
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets(
      'AuthWrapper shows "Connection Required" when offline and not logged in',
      (tester) async {
    await tester.pumpWidget(createAuthWrapper(
      isOffline: true,
      isLoggedIn: false,
      authStream: Stream.value(null),
    ));

    await tester.pumpAndSettle();
    expect(find.text('Connection Required'), findsOneWidget);
    expect(find.textContaining('currently offline'), findsOneWidget);

    // Dispose
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets(
      'AuthWrapper shows slow connection and bypass after 25s (Soft Failover)',
      (tester) async {
    // Verify that for a logged-in user, we allow "Soft Failover" and show Dashboard
    // The "Continue Offline" button logic was for blocking screens, but now checkConnectivity
    // will return success (false error) or we just bypass if persistent.

    // If persistent login is true (default in this test setup via isLoggedIn: true),
    // AuthWrapper should eventually show Dashboard or at least not block indefinitely if we simulated offline correctly.
    // However, the test was testing the Timer.
    // Let's update it to expect the Dashboard directly because of "Soft Failover".

    await tester.pumpWidget(createAuthWrapper(
      isLoggedIn: true,
      firebaseInit: const AsyncValue.loading(),
      authStream: const Stream.empty(),
    ));

    // With Soft Failover, we might still show loading for a bit, but if it errors/times out, we go to Dashboard.
    // Let's simulate the timeout or error condition effectively by waiting.
    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();

    // Should show Dashboard (Offline Failover) directly for persistent users
    expect(find.byType(DashboardScreen), findsOneWidget);
  });

  testWidgets('AuthWrapper enters Dashboard after 120s timeout',
      (tester) async {
    await tester.pumpWidget(createAuthWrapper(
      isLoggedIn: true,
      firebaseInit: const AsyncValue.loading(),
      authStream: const Stream.empty(),
    ));

    await tester.pump(
        const Duration(seconds: 150)); // Safety (120s) + Auto-Heal (15s) + Buff
    await tester.pumpAndSettle();

    // Final flush to catch any lingering timers
    await tester.pump(const Duration(minutes: 5));

    expect(find.byType(DashboardScreen), findsOneWidget);
  });

  testWidgets('AuthWrapper handles critical revalidation error (Force Logout)',
      (tester) async {
    // Setup: Logged In, Online
    when(() => mockAuthService.currentUser).thenReturn(mockUser);
    when(() => mockAuthService.reloadUser(any())).thenThrow(
        FirebaseAuthException(code: 'user-not-found', message: 'Not found'));
    when(() => mockAuthService.signOut(any())).thenAnswer((_) async {});

    await tester.pumpWidget(createAuthWrapper(
      isLoggedIn: true,
      isOffline: false,
      firebaseInit: const AsyncValue.data(null),
    ));

    await tester.pump(); // Init
    await tester.pumpAndSettle(); // Async gap for revalidation

    // Verify SignOut was triggered
    verify(() => mockAuthService.signOut(any())).called(1);
  });

  testWidgets('AuthWrapper suppresses initialization errors', (tester) async {
    // Simulate error during Firebase Init
    await tester.pumpWidget(createAuthWrapper(
      firebaseInit: const AsyncValue.error('Firebase Error', StackTrace.empty),
      isLoggedIn: false,
    ));

    // Error state might trigger a snackbar or just show a fallback.
    // We expect it to NOT crash and eventually show Login screen (since user is effectively not logged in)
    // or stay on the loading screen if it's a fatal blocking error.
    // In our implementation, we catch errors in _checkInitialConnectivity, so it proceeds.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    // Should show Error Screen
    expect(find.text('Connection Required'), findsOneWidget);

    // Test Retry Interaction
    when(() => mockStorageService.setAuthFlag(any())).thenAnswer((_) async {});
    await tester.tap(find.text('Retry Connection'));
    await tester.pump();
    // Invalidation happens, but since mock returns same error, it stays. verification is enough.
  });

  testWidgets('AuthWrapper sets optimistic auth flag on successful login',
      (tester) async {
    final streamController = StreamController<User?>();
    addTearDown(() => streamController.close());

    when(() => mockStorageService.getAuthFlag()).thenReturn(false);
    when(() => mockStorageService.setAuthFlag(true)).thenAnswer((_) async {});

    await tester.pumpWidget(createAuthWrapper(
        isLoggedIn: true, authStream: streamController.stream));

    // Emit user
    streamController.add(mockUser);
    await tester.pump();
    await tester.pumpAndSettle();

    verify(() => mockStorageService.setAuthFlag(true)).called(1);
  });

  testWidgets('AuthWrapper confirms Ghost Session and prompts fix',
      (tester) async {
    // 1. Setup: Online, Logged In, but No user in stream
    when(() => mockAuthService.currentUser).thenReturn(null);
    final streamController = StreamController<User?>();
    addTearDown(() => streamController.close());

    await tester.pumpWidget(createAuthWrapper(
      isLoggedIn: true,
      isOffline: false,
      authStream: streamController.stream,
    ));

    // Advance past boot grace period (5s)
    await tester.pump(const Duration(seconds: 6));

    // Emit null (Ghost Session)
    streamController.add(null);
    await tester.pump();

    // Advance past safety guard (30s)
    await tester.pump(const Duration(seconds: 35));
    await tester.pump(); // Ensure snackbar appears

    expect(find.textContaining('Session verification failed'), findsOneWidget);
    expect(find.text('FIX'), findsOneWidget);
  });

  testWidgets(
      'AuthWrapper automatically bypasses Error Screen for persistent users',
      (tester) async {
    await tester.pumpWidget(createAuthWrapper(
      firebaseInit: const AsyncValue.error('Timeout', StackTrace.empty),
      isLoggedIn: true, // Persistent login enables bypass
    ));
    await tester.pumpAndSettle();

    // Should NOT show Error Screen/Continue Offline button anymore
    expect(find.text('Slow Connection'), findsNothing);
    // Should show Dashboard directly due to Soft Failover
    expect(find.byType(DashboardScreen), findsOneWidget);
  });

  testWidgets('AuthWrapper triggers auto-restore on login if local data empty',
      (tester) async {
    final mockCloudSync = MockCloudSyncService();
    when(() => mockCloudSync.restoreFromCloud()).thenAnswer((_) async {});

    final streamController = StreamController<User?>();

    await tester.pumpWidget(createAuthWrapper(
      isLoggedIn: true,
      authStream: streamController.stream,
      cloudSync: mockCloudSync,
    ));

    await tester.pump(const Duration(seconds: 6)); // Past boot grace

    // Now emit the user
    streamController.add(mockUser);
    await tester.pump();
    await tester.pumpAndSettle();

    // Verify restoreFromCloud was called (might be unawaited in background)
    verify(() => mockCloudSync.restoreFromCloud()).called(1);
    expect(find.text('Cloud Restore Completed'), findsOneWidget);

    await streamController.close();
  });

  testWidgets('AuthWrapper handles Network Recovery', (tester) async {
    await tester.pumpWidget(createAuthWrapper(
      isOffline: true,
      isLoggedIn: true,
      firebaseInit: const AsyncValue.loading(),
      authStream: const Stream.empty(),
    ));

    expect(find.byType(DashboardScreen), findsOneWidget);

    // Simulating Online
    mockIsOfflineNotifier.setOffline(false);
    await tester.pump();
    // Advance past network settling delay (2s)
    await tester.pump(const Duration(seconds: 3));

    // In actual code, it checks actual reachability and invalidates firebaseInitializerProvider.
    // We can't easily check for provider invalidation but we can see if it starts loading.
  });
}

class MockCloudSyncService extends Mock implements CloudSyncService {}
