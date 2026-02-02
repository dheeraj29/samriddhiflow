import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/services/auth_service.dart';
import 'package:hive_ce/hive.dart';

// Mocks
class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

class MockUserCredential extends Mock implements UserCredential {}

class MockBox extends Mock implements Box {}

// Create a custom interface for matching the dynamic ref usage
abstract class RefInterface {
  T read<T>(dynamic provider);
}

class MockRef extends Mock implements RefInterface {}

// Mock the Notifier (Custom class from providers.dart)
class MockLogoutNotifier extends Mock implements LogoutRequestedNotifier {}

void main() {
  late MockFirebaseAuth mockAuth;
  late MockUser mockUser;
  late AuthService authService;

  setUpAll(() {
    registerFallbackValue(MockRef());
    registerFallbackValue(true); // Fallback for bool
  });

  setUp(() {
    mockAuth = MockFirebaseAuth();
    mockUser = MockUser();

    // Inject mock auth into service
    authService = AuthService(mockAuth);

    // Default Stubs
    when(() => mockAuth.currentUser).thenReturn(null);
    when(() => mockAuth.authStateChanges())
        .thenAnswer((_) => Stream.value(null));
    when(() => mockUser.uid).thenReturn('test_uid_123');
    when(() => mockUser.email).thenReturn('test@example.com');
  });

  group('AuthService Tests', () {
    test('Initial State - No User', () {
      expect(authService.currentUser, isNull);
      expect(authService.authStateChanges, emits(null));
    });

    test('Initial State - With User', () {
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockAuth.authStateChanges())
          .thenAnswer((_) => Stream.value(mockUser));

      expect(authService.currentUser, mockUser);
      expect(authService.authStateChanges, emits(mockUser));
    });

    test('SignOut - Normal Flow', () async {
      final mockRef = MockRef();
      final mockNotifier = MockLogoutNotifier();

      // Stub the property access "notifier"
      // Wait, provider.notifier returns the Notifier/Controller.
      // ref.read(provider.notifier) returns the controller.
      // So ref.read(...) -> mockNotifier.

      // Mock ref.read to return our notifier
      when(() => mockRef.read(any())).thenReturn(mockNotifier);

      // Mock checking
      // The code uses .value = true?
      // If logoutRequestedProvider is a StateProvider, .notifier gives StateController.
      // StateController has .state. Does it have .value?
      // Code says .value. Maybe it's a ValueNotifier?
      // Let's assume the code is correct.
      // If code uses .value, mock must support .value setter.
      // Mocking a setter: when(() => mock.value = true).thenReturn(null);

      when(() => mockAuth.signOut()).thenAnswer((_) async {});

      // Execute with our custom mock ref
      await authService.signOut(mockRef);

      // Verify
      verify(() => mockAuth.signOut()).called(1);
    });

    test('Delete Account', () async {
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.delete()).thenAnswer((_) async {});

      await authService.deleteAccount();

      verify(() => mockUser.delete()).called(1);
    });

    // Note: signInWithGoogle relies heavily on GoogleAuthProvider and Web checks.
    // Testing specialized flow might be limited without abstracting GoogleSignIn.
    // But we can test the general structure if we can inject dependencies or mock statics.
    // AuthService uses `FirebaseAuth.instance` if no injection, but we injected mockAuth.
  });
}
