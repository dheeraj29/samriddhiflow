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

// Mocks
class MockAuthService extends Mock implements AuthService {}

class MockStorageService extends Mock implements StorageService {}

class MockUser extends Mock implements User {}

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
  void setOffline(bool v) => state = v;
  @override
  bool build() => _initialState;
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

    // Auth Service stubs
    when(() => mockAuthService.currentUser).thenReturn(null);
    when(() => mockAuthService.isSignOutInProgress).thenReturn(false);
  });

  testWidgets('AuthWrapper shows LoginScreen when user is null',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        storageInitializerProvider
            .overrideWithValue(const AsyncValue.data(null)),
        firebaseInitializerProvider
            .overrideWithValue(const AsyncValue.data(null)),
        authServiceProvider.overrideWithValue(mockAuthService),
        storageServiceProvider.overrideWithValue(mockStorageService),

        isLoggedInProvider.overrideWith(() => mockIsLoggedInNotifier),
        isOfflineProvider.overrideWith(() => mockIsOfflineNotifier),
        connectivityCheckProvider
            .overrideWithValue(() async => false), // Online

        // Mock Auth Stream (Null User)
        authStreamProvider.overrideWith((ref) => Stream.value(null)),

        activeProfileIdProvider.overrideWith(MockProfileNotifier.new),
        // Just in case dashboard is accessed
        categoriesProvider.overrideWith(MockCategoriesNotifier.new),
        activeProfileProvider.overrideWith((ref) => null),
        txnsSinceBackupProvider.overrideWith(MockTxnsSinceBackupNotifier.new),
        backupThresholdProvider.overrideWith(MockBackupThresholdNotifier.new),
        smartCalculatorEnabledProvider
            .overrideWith(MockSmartCalculatorEnabledNotifier.new),
        calculatorVisibleProvider
            .overrideWith(MockCalculatorVisibleNotifier.new),
      ],
      child: const MaterialApp(
        home: AuthWrapper(),
      ),
    ));

    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);

    // Dispose
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('AuthWrapper shows DashboardScreen when user is authenticated',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        storageInitializerProvider
            .overrideWithValue(const AsyncValue.data(null)),
        firebaseInitializerProvider
            .overrideWithValue(const AsyncValue.data(null)),
        authServiceProvider.overrideWithValue(mockAuthService),
        storageServiceProvider.overrideWithValue(mockStorageService),

        isLoggedInProvider.overrideWith(() => mockIsLoggedInNotifier),
        connectivityCheckProvider
            .overrideWithValue(() async => false), // Online

        authStreamProvider.overrideWith((ref) => Stream.value(mockUser)),

        // Dashboard Data Dependencies
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
      ],
      child: const MaterialApp(
        home: AuthWrapper(),
      ),
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
    mockIsOfflineNotifier.setInitial(true);
    mockIsLoggedInNotifier.setInitial(false);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        storageInitializerProvider
            .overrideWithValue(const AsyncValue.data(null)),
        firebaseInitializerProvider
            .overrideWithValue(const AsyncValue.data(null)),
        authServiceProvider.overrideWithValue(mockAuthService),
        storageServiceProvider.overrideWithValue(mockStorageService),
        isLoggedInProvider.overrideWith(() => mockIsLoggedInNotifier),
        isOfflineProvider.overrideWith(() => mockIsOfflineNotifier),
        connectivityCheckProvider
            .overrideWithValue(() async => true), // Offline

        authStreamProvider.overrideWith((ref) => Stream.value(null)),

        activeProfileIdProvider.overrideWith(MockProfileNotifier.new),
      ],
      child: const MaterialApp(home: AuthWrapper()),
    ));

    await tester.pumpAndSettle();
    expect(find.text('Connection Required'), findsOneWidget);
    expect(find.textContaining('currently offline'), findsOneWidget);

    // Dispose
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
