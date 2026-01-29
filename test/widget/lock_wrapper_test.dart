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
        storageInitializerProvider.overrideWith((ref) => Future.value(true)),
        authStreamProvider.overrideWith((ref) => Stream.value(MockUser())),
      ],
      child: const MaterialApp(
        home: LockWrapper(
          child: Text('Protected Content'),
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
}
