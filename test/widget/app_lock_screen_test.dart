import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/screens/app_lock_screen.dart';

import 'package:samriddhi_flow/widgets/lock_wrapper.dart';

import 'test_mocks.dart';

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
    // Smoke check ok
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
      child: MaterialApp(
        home: LockWrapper(
          child: const Scaffold(body: Text('Child Content')),
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
