import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/screens/app_lock_screen.dart';

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
    mockStorage.setPin(
        '0ffe1abd1a08215353c233d6e009613e95eec4253832a761af28ff37ac5a150c'); // Hash of 1111
    when(() => mockStorage.isPinLocked()).thenReturn(false);
    when(() => mockStorage.verifyAppPin('1111')).thenReturn(true);
    when(() => mockStorage.getFailedPinAttempts()).thenReturn(0);

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
    mockStorage.setPin(
        '03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f4'); // Hash of 1234
    when(() => mockStorage.isPinLocked()).thenReturn(false);
    when(() => mockStorage.verifyAppPin('1111')).thenReturn(false);
    when(() => mockStorage.getRemainingPinAttempts()).thenReturn(2);

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

    expect(find.textContaining('Incorrect PIN'), findsOneWidget);
    expect(unlocked, isFalse);

    // Fallback
    await tester.tap(find.text('Forgot PIN? / Use Password'));
    await tester.pumpAndSettle();
    expect(fallback, isTrue);
  });

  testWidgets('AppLockScreen shows lockout message when PIN is locked',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    final mockStorage = MockStorageService();
    mockStorage.setPin(
        '03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f4'); // Hash of 1234
    when(() => mockStorage.isPinLocked()).thenReturn(true);

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

    await tester.tap(find.text('1'));
    await tester.tap(find.text('1'));
    await tester.tap(find.text('1'));
    await tester.tap(find.text('1'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.check_circle));
    await tester.pumpAndSettle();

    expect(find.textContaining('Too many attempts'), findsOneWidget);
  });

  testWidgets('AppLockScreen accepts a 6-digit PIN', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    bool unlocked = false;

    final mockStorage = MockStorageService();
    mockStorage.setPin(
        'a5c8387d0b83b1d89e0ab3d6a2d1f4ff2f28ed07d10a0b9843fd4ff0c8a0b2f2'); // Hash of 123456
    when(() => mockStorage.isPinLocked()).thenReturn(false);
    when(() => mockStorage.verifyAppPin('123456')).thenReturn(true);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(mockStorage),
      ],
      child: MaterialApp(
        home: AppLockScreen(
          onUnlocked: () => unlocked = true,
          onFallback: () {},
        ),
      ),
    ));

    await tester.tap(find.text('1'));
    await tester.tap(find.text('2'));
    await tester.tap(find.text('3'));
    await tester.tap(find.text('4'));
    await tester.tap(find.text('5'));
    await tester.tap(find.text('6'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.check_circle));
    await tester.pumpAndSettle();

    expect(unlocked, isTrue);
  });

  testWidgets('AppLockScreen does not submit with less than 4 digits',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);

    final mockStorage = MockStorageService();
    mockStorage.setPin(
        '03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f4'); // Hash of 1234
    when(() => mockStorage.isPinLocked()).thenReturn(false);
    when(() => mockStorage.verifyAppPin(any())).thenReturn(false);

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

    await tester.tap(find.text('1'));
    await tester.tap(find.text('2'));
    await tester.tap(find.text('3'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.check_circle));
    await tester.pumpAndSettle();

    verifyNever(() => mockStorage.verifyAppPin(any()));
  });
}
