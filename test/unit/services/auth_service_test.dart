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

abstract class RefInterface {
  T read<T>(dynamic provider);
}

class MockRef extends Mock implements RefInterface {}

class MockLogoutRequestedNotifier extends Mock
    implements LogoutRequestedNotifier {}

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

    authService = AuthService(mockAuth, mockStorage, true);

    registerFallbackValue(false);
    when(() => mockRef.read(logoutRequestedProvider)).thenReturn(false);
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

      final mockNotifier = MockLogoutRequestedNotifier();
      when(() => mockRef.read(logoutRequestedProvider.notifier))
          .thenReturn(mockNotifier);

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

  test('reloadUser calls firebase reload', () async {
    when(() => mockAuth.currentUser).thenReturn(mockUser);
    when(() => mockUser.reload()).thenAnswer((_) async {});

    await authService.reloadUser(mockRef);

    verify(() => mockUser.reload()).called(1);
  });

  test('reloadUser skips if signOutInProgress', () async {
    when(() => mockAuth.currentUser).thenReturn(mockUser);
    authService.isSignOutInProgress = true;
    await authService.reloadUser(mockRef);
    verifyNever(() => mockUser.reload());
  });

  testWidgets('signInWithGoogle returns error if firebase auth is null',
      (WidgetTester tester) async {
    final authServiceNull = AuthService(null, mockStorage);
    // This will hit the Lazy Initializing branch since _auth is null
    final response = await authServiceNull.signInWithGoogle(null);
    expect(response.status, AuthStatus.error);
    // The exact message depend on whether Lazy Init fails (it will in tests)
    expect(response.message, contains('Connection failed'));
  });

  group('handleRedirectResult', () {
    test('returns early if signOutInProgress', () async {
      authService.isSignOutInProgress = true;
      await authService.handleRedirectResult();
      verifyNever(() => mockAuth.getRedirectResult());
    });

    test('recovers session if redirect user is found', () async {
      final mockCredential = MockUserCredential();
      when(() => mockAuth.getRedirectResult())
          .thenAnswer((_) async => mockCredential);
      when(() => mockCredential.user).thenReturn(mockUser);
      when(() => mockStorage.setAuthFlag(true)).thenAnswer((_) async {});

      final result = await authService.handleRedirectResult();

      verify(() => mockStorage.setAuthFlag(true)).called(1);
      expect(result, mockUser);
    });

    test('recovers session if currentUser is already restored (fallback)',
        () async {
      final mockCredential = MockUserCredential();
      when(() => mockAuth.getRedirectResult())
          .thenAnswer((_) async => mockCredential);
      when(() => mockCredential.user).thenReturn(null);
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockStorage.setAuthFlag(true)).thenAnswer((_) async {});

      final result = await authService.handleRedirectResult();

      verify(() => mockStorage.setAuthFlag(true)).called(1);
      expect(result, mockUser);
    });

    test('handles redirect errors gracefully', () async {
      when(() => mockAuth.getRedirectResult()).thenThrow(Exception('Fail'));
      await authService.handleRedirectResult();
      // Completes without throwing
    });
  });

  test('signOut handles exceptions during firebase signOut', () async {
    final mockNotifier = MockLogoutRequestedNotifier();
    when(() => mockRef.read(logoutRequestedProvider.notifier))
        .thenReturn(mockNotifier);
    when(() => mockAuth.signOut()).thenThrow(Exception('Signout failed'));
    when(() => mockStorage.setAuthFlag(any())).thenAnswer((_) async {});

    await authService.signOut(mockRef);
    verify(() => mockStorage.setAuthFlag(false)).called(1);
  });

  test('deleteAccount calls user delete', () async {
    when(() => mockAuth.currentUser).thenReturn(mockUser);
    when(() => mockUser.delete()).thenAnswer((_) async {});

    await authService.deleteAccount();

    verify(() => mockUser.delete()).called(1);
  });

  test('authStateChanges returns null stream if _auth is null', () {
    final authServiceNull = AuthService(null, mockStorage);
    expect(authServiceNull.authStateChanges, emits(null));
  });
}
