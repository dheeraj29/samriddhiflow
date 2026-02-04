import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/screens/app_lock_screen.dart';

import 'package:samriddhi_flow/widgets/lock_wrapper.dart';

import '../test_mocks.dart';

void main() {
  testWidgets('AppLockScreen builds and handles input', (tester) async {
    // Ensure screen is tall enough to avoid overflow
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    final mockStorage = MockStorageService();
    // Use manual setters
    mockStorage.setLocked(true);
    mockStorage.setPin('1111');

    await tester.pumpWidget(ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(mockStorage),
      ],
      child: MaterialApp(
        home: AppLockScreen(
          onUnlocked: () {},
          onFallback: () {},
        ),
      ),
    ));

    // Verify UI elements
    expect(find.text('Enter PIN'), findsOneWidget);

    // Enter correct PIN
    await tester.tap(find.text('1'));
    await tester.tap(find.text('1'));
    await tester.tap(find.text('1'));
    await tester.tap(find.text('1'));
    await tester.pumpAndSettle();

    // Verify submit button is enabled and tap it
    // The submit button is an Icon (check_circle)
    await tester.tap(find.byIcon(Icons.check_circle));
    await tester.pumpAndSettle();

    // Verification would require checking if onUnlocked was called
  });

  testWidgets('AppLockScreen handles incorrect PIN and fallback',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    bool unlocked = false;
    bool fallback = false;

    final mockStorage = MockStorageService();
    mockStorage.setPin('1234');

    await tester.pumpWidget(ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(mockStorage),
      ],
      child: MaterialApp(
        home: AppLockScreen(
          onUnlocked: () => unlocked = true,
          onFallback: () => fallback = true,
        ),
      ),
    ));

    // Enter incorrect PIN
    await tester.tap(find.text('1'));
    await tester.tap(find.text('1'));
    await tester.tap(find.text('1'));
    await tester.tap(find.text('1'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.check_circle));
    await tester.pumpAndSettle();

    expect(find.text('Incorrect PIN'), findsOneWidget);
    expect(unlocked, isFalse);

    // Fallback
    await tester.tap(find.text('Forgot PIN? / Use Password'));
    await tester.pumpAndSettle();
    expect(fallback, isTrue);
  });

  testWidgets('LockWrapper builds child when unlocked (smoke)', (tester) async {
    final mockStorage = MockStorageService();
    // Simulate unlocked state
    mockStorage.setLocked(false);
    final mockAuth = MockAuthService();

    await tester.pumpWidget(ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(mockStorage),
        storageInitializerProvider
            .overrideWith((ref) => Future.value()), // Ready
        authServiceProvider.overrideWithValue(mockAuth),
        firebaseInitializerProvider.overrideWith((ref) => Future.value()),
      ],
      child: const MaterialApp(
        home: LockWrapper(
          child: Scaffold(body: Text('Child Content')),
        ),
      ),
    ));

    await tester.pump();
    await tester.pump();
    await tester.pump();

    // Verify
    expect(find.text('Child Content'), findsOneWidget);
  });
}
