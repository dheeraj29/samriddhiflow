import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/feature_providers.dart';
import 'package:samriddhi_flow/screens/login_screen.dart';
import 'package:samriddhi_flow/services/auth_service.dart';
import 'package:samriddhi_flow/services/cloud_sync_service.dart';
import 'package:samriddhi_flow/services/storage_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Mocks
class MockAuthService extends Mock implements AuthService {}

class MockStorageService extends Mock implements StorageService {}

class MockCloudSyncService extends Mock implements CloudSyncService {}

class MockUser extends Mock implements User {}

class MockLocalModeNotifier extends LocalModeNotifier {
  final bool _value = false;
  @override
  bool build() => _value;
  @override
  set value(bool v) => state = v;
}

class MockIsLoggedInNotifier extends IsLoggedInNotifier {
  bool _initialState = false;
  void setInitial(bool v) => _initialState = v;
  @override
  Future<void> setLoggedIn(bool v) async => state = v;
  @override
  bool build() => _initialState;
}

// HttpOverrides to block network calls in Image.network
class TestHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (cert, host, port) => true;
  }
}

void main() {
  late MockAuthService mockAuthService;
  late MockStorageService mockStorageService;
  late MockCloudSyncService mockCloudSyncService;
  late MockIsLoggedInNotifier mockIsLoggedInNotifier;

  setUpAll(() {
    HttpOverrides.global = null;
  });

  setUp(() {
    mockAuthService = MockAuthService();
    mockStorageService = MockStorageService();
    mockCloudSyncService = MockCloudSyncService();
    mockIsLoggedInNotifier = MockIsLoggedInNotifier();

    // Default Stubs
    when(() => mockAuthService.signInWithGoogle(any())).thenAnswer((_) async =>
        AuthResponse(status: AuthStatus.error, message: 'Cancelled'));
    when(() => mockStorageService.getAllAccounts()).thenReturn([]);
    when(() => mockStorageService.getAllTransactions()).thenReturn([]);
    when(() => mockCloudSyncService.restoreFromCloud())
        .thenAnswer((_) async {});
  });

  testWidgets('LoginScreen shows Google Sign-In button', (tester) async {
    // Set surface size to avoid overflow
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 2.0;

    await tester.pumpWidget(ProviderScope(
      overrides: [
        authServiceProvider.overrideWithValue(mockAuthService),
        storageServiceProvider.overrideWithValue(mockStorageService),
        cloudSyncServiceProvider.overrideWithValue(mockCloudSyncService),
        localModeProvider.overrideWith(MockLocalModeNotifier.new),
        isLoggedInProvider.overrideWith(() => mockIsLoggedInNotifier),
      ],
      child: const MaterialApp(home: LoginScreen()),
    ));

    await tester.pumpAndSettle();

    expect(find.text('Continue with Google'), findsOneWidget);

    // Cleanup
    await tester.pumpWidget(const SizedBox());
    addTearDown(tester.view.resetPhysicalSize);
  });

  testWidgets('LoginScreen triggers Google Sign-In on tap', (tester) async {
    when(() => mockAuthService.signInWithGoogle(any()))
        .thenAnswer((_) async => AuthResponse(status: AuthStatus.success));

    await tester.pumpWidget(ProviderScope(
      overrides: [
        authServiceProvider.overrideWithValue(mockAuthService),
        storageServiceProvider.overrideWithValue(mockStorageService),
        cloudSyncServiceProvider.overrideWithValue(mockCloudSyncService),
        localModeProvider.overrideWith(MockLocalModeNotifier.new),
        isLoggedInProvider.overrideWith(() => mockIsLoggedInNotifier),
      ],
      child: const MaterialApp(home: LoginScreen()),
    ));

    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue with Google'));
    await tester.pump(); // Start animation
    await tester.pump(); // Timer/Process

    verify(() => mockAuthService.signInWithGoogle(any())).called(1);

    // Dispose
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
