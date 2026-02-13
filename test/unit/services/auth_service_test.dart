import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/services/auth_service.dart';
import 'package:samriddhi_flow/services/storage_service.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

class MockUserCredential extends Mock implements UserCredential {}

class MockStorageService extends Mock implements StorageService {}

class MockLogoutRequestedNotifier extends Mock
    implements LogoutRequestedNotifier {}

abstract class RefInterface {
  T read<T>(dynamic provider);
}

class MockRef extends Mock implements RefInterface {}

void main() {
  late AuthService authService;
  late MockFirebaseAuth mockAuth;
  late MockStorageService mockStorage;
  late MockUser mockUser;
  late MockRef mockRef;

  setUp(() {
    mockAuth = MockFirebaseAuth();
    mockStorage = MockStorageService();
    mockUser = MockUser();
    mockRef = MockRef();

    authService = AuthService(mockAuth, mockStorage);

    registerFallbackValue(false);
  });

  test('currentUser returns mocked user', () {
    when(() => mockAuth.currentUser).thenReturn(mockUser);
    expect(authService.currentUser, mockUser);
  });

  test('authStateChanges returns stream', () {
    when(() => mockAuth.authStateChanges())
        .thenAnswer((_) => Stream.value(mockUser));
    expect(authService.authStateChanges, emits(mockUser));
  });

  group('signInWithGoogle', () {
    test('returns success if user is already logged in and valid', () async {
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.reload()).thenAnswer((_) async {});

      final response = await authService.signInWithGoogle(mockRef);

      expect(response.status, AuthStatus.success);
      verify(() => mockUser.reload()).called(1);
    });

    test('returns error and signs out if session is invalid (user-disabled)',
        () async {
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.reload())
          .thenThrow(FirebaseAuthException(code: 'user-disabled'));
      when(() => mockAuth.signOut()).thenAnswer((_) async {});
      when(() => mockStorage.setAuthFlag(any())).thenAnswer((_) async {});
      when(() => mockRef.read(logoutRequestedProvider.notifier))
          .thenReturn(MockLogoutRequestedNotifier());

      final response = await authService.signInWithGoogle(mockRef);

      expect(response.status, AuthStatus.error);
      expect(response.message, contains('Session expired'));

      await untilCalled(() => mockAuth.signOut());
      verify(() => mockAuth.signOut()).called(1);
    });

    test('returns success if offline during session validation', () async {
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.reload())
          .thenThrow(FirebaseAuthException(code: 'network-request-failed'));

      final response = await authService.signInWithGoogle(mockRef);

      expect(response.status, AuthStatus.success);
    });
  });

  test('signOut calls firebase signOut and clears storage', () async {
    when(() => mockAuth.signOut()).thenAnswer((_) async {});
    when(() => mockStorage.setAuthFlag(any())).thenAnswer((_) async {});

    final mockLogoutNotifier = MockLogoutRequestedNotifier();
    when(() => mockRef.read(logoutRequestedProvider.notifier))
        .thenReturn(mockLogoutNotifier);

    await authService.signOut(mockRef);

    await untilCalled(() => mockAuth.signOut());
    verify(() => mockAuth.signOut()).called(1);
    verify(() => mockStorage.setAuthFlag(false)).called(1);
    verify(() => mockRef.read(logoutRequestedProvider.notifier)).called(1);
  });
}
