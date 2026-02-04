import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/widgets/lock_wrapper.dart';
import 'package:samriddhi_flow/services/storage_service.dart';
import 'package:samriddhi_flow/services/auth_service.dart';
import 'package:samriddhi_flow/screens/app_lock_screen.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;

class MockStorageService extends Mock implements StorageService {}

class MockAuthService extends Mock implements AuthService {}

class MockUser extends Mock implements auth.User {}

void main() {
  late MockStorageService mockStorageService;
  late MockAuthService mockAuthService;

  setUp(() {
    mockStorageService = MockStorageService();
    mockAuthService = MockAuthService();

    // Default Stubs
    when(() => mockStorageService.isAppLockEnabled()).thenReturn(false);
    when(() => mockStorageService.getAppPin()).thenReturn(null);
    when(() => mockStorageService.getPinResetRequested()).thenReturn(false);
    when(() => mockAuthService.currentUser).thenReturn(MockUser());
  });

  Widget createWidgetUnderTest() {
    return ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(mockStorageService),
        authServiceProvider.overrideWithValue(mockAuthService),
        storageInitializerProvider.overrideWith((ref) async {}),
        authStreamProvider.overrideWith((ref) => Stream.value(MockUser())),
      ],
      child: const MaterialApp(
        home: LockWrapper(
          child: Scaffold(body: Text('Protected Content')),
        ),
      ),
    );
  }

  testWidgets('LockWrapper shows content when lock is disabled',
      (tester) async {
    when(() => mockStorageService.isAppLockEnabled()).thenReturn(false);

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(find.text('Protected Content'), findsOneWidget);
    expect(find.byType(AppLockScreen), findsNothing);
  });

  testWidgets('LockWrapper shows AppLockScreen when locked', (tester) async {
    // Increase screen size to prevent rendering overflow in AppLockScreen
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;

    when(() => mockStorageService.isAppLockEnabled()).thenReturn(true);
    when(() => mockStorageService.getAppPin()).thenReturn('1234');

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(find.text('Protected Content'), findsNothing);
    expect(find.byType(AppLockScreen), findsOneWidget);

    addTearDown(() => tester.view.resetPhysicalSize());
  });

  testWidgets('LockWrapper locks after 1 minute in background', (tester) async {
    // Initially, the app lock is disabled by default in setUp, so content should be visible.
    when(() => mockStorageService.getAppPin()).thenReturn('1234');

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Initial state: Unlocked (mock it so checkInitialLock sets it to false first)
    expect(find.text('Protected Content'), findsOneWidget);

    // Now enable lock in storage
    when(() => mockStorageService.isAppLockEnabled()).thenReturn(true);
    when(() => mockStorageService.getAppPin()).thenReturn('1234');

    // Simulate Background
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1)); // Timestamp T+1

    // Advance total significantly (Total 121s)
    await tester.pump(const Duration(seconds: 120));

    // Simulate Resume
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(); // Handle resume logic
    await tester.pumpAndSettle();

    expect(find.byType(AppLockScreen), findsOneWidget);
    expect(find.text('Protected Content'), findsNothing);
  });

  testWidgets('LockWrapper handles Forgot PIN fallback', (tester) async {
    when(() => mockStorageService.isAppLockEnabled()).thenReturn(true);
    when(() => mockStorageService.getAppPin()).thenReturn('1234');
    when(() => mockStorageService.setPinResetRequested(true))
        .thenAnswer((_) async {});
    when(() => mockAuthService.signOut(any())).thenAnswer((_) async {});

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(find.byType(AppLockScreen), findsOneWidget);

    // Tap the fallback button
    await tester.tap(find.text('Forgot PIN? / Use Password'));
    await tester.pumpAndSettle();

    // Flag set to true and logout triggered
    verify(() => mockStorageService.setPinResetRequested(true)).called(1);
    verify(() => mockAuthService.signOut(any())).called(1);
  });

  testWidgets('LockWrapper unlocks on PIN reset request at startup',
      (tester) async {
    when(() => mockStorageService.isAppLockEnabled()).thenReturn(true);
    when(() => mockStorageService.getAppPin()).thenReturn('1234');
    when(() => mockStorageService.getPinResetRequested()).thenReturn(true);
    when(() => mockStorageService.setPinResetRequested(false))
        .thenAnswer((_) async {});

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    verify(() => mockStorageService.setPinResetRequested(false)).called(1);
    expect(find.text('App Unlocked. Please Reset your PIN in Settings.'),
        findsOneWidget);
  });

  testWidgets('LockWrapper handles storage init failure gracefully',
      (tester) async {
    // Simulate storage throwing on access
    when(() => mockStorageService.isAppLockEnabled())
        .thenThrow(Exception('Fail'));

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Should default to unlocked
    expect(find.text('Protected Content'), findsOneWidget);
  });
}
