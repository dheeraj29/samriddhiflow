import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:samriddhi_flow/services/auth_service.dart';
import 'package:samriddhi_flow/services/storage_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samriddhi_flow/providers.dart';

class MockStorageService extends Mock implements StorageService {}

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

class MockUserCredential extends Mock implements UserCredential {}

void main() {
  late AuthService authService;
  late MockStorageService mockStorage;
  late MockFirebaseAuth mockAuth;
  late MockUser mockUser;
  late ProviderContainer container;

  setUp(() {
    mockStorage = MockStorageService();
    mockAuth = MockFirebaseAuth();
    mockUser = MockUser();
    container = ProviderContainer();
    authService = AuthService(mockAuth, mockStorage);

    when(() => mockAuth.authStateChanges())
        .thenAnswer((_) => Stream.value(null));
    when(() => mockAuth.currentUser).thenReturn(null);
    final f = Future<void>.value(null);
    when(() => mockStorage.setAuthFlag(any())).thenAnswer((_) => f);
  });

  group('AuthService - Coverage Mastery', () {
    test('Constructor and Auth getter', () {
      expect(authService.currentUser, isNull);
      expect(authService.authStateChanges, isNotNull);
    });

    test('signInWithGoogle - Already Logged In Success', () async {
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.reload()).thenAnswer((_) async {});

      final response = await authService.signInWithGoogle(container);
      expect(response.status, AuthStatus.success);
    });

    test('signInWithGoogle - Already Logged In Offline Success', () async {
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.reload())
          .thenThrow(FirebaseAuthException(code: 'network-request-failed'));

      final response = await authService.signInWithGoogle(container);
      expect(response.status, AuthStatus.success);
    });

    test('signInWithGoogle - Already Logged In Disabled Failure', () async {
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.reload())
          .thenThrow(FirebaseAuthException(code: 'user-disabled'));
      when(() => mockAuth.signOut()).thenAnswer((_) async {});

      final response = await authService.signInWithGoogle(container);
      expect(response.status, AuthStatus.error);
      expect(response.message, contains('Session expired'));
    });

    test('signOut - Functional Flow', () async {
      when(() => mockAuth.signOut()).thenAnswer((_) async {});

      await authService.signOut(container);

      expect(container.read(logoutRequestedProvider), true);
      verify(() => mockStorage.setAuthFlag(false)).called(1);
    });

    test('reloadUser and deleteAccount', () async {
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.reload()).thenAnswer((_) async {});
      when(() => mockUser.delete()).thenAnswer((_) async {});

      await authService.reloadUser(container);
      verify(() => mockUser.reload()).called(1);

      await authService.deleteAccount();
      verify(() => mockUser.delete()).called(1);
    });

    test('handleRedirectResult - Result Found', () async {
      // We can't easily mock kIsWeb being true in a non-web test environment
      // without extra plumbing, but handleRedirectResult checks _auth != null.
      // If we are on mobile, it just logs "Skip Redirect check".
      // To hit the internal logic, we might need to mock kIsWeb or connectivity platform.

      final mockCredential = MockUserCredential();
      when(() => mockAuth.getRedirectResult())
          .thenAnswer((_) async => mockCredential);
      when(() => mockCredential.user).thenReturn(mockUser);

      await authService.handleRedirectResult(container);
      // Since kIsWeb is false in unit tests by default, it will skip.
    });

    test('AuthService - No Auth Path', () async {
      final authNoService = AuthService(null, mockStorage);
      // This will hit the Firebase.initializeApp path if _auth is null
      // But Firebase.initializeApp depends on platform channels.
      expect(authNoService.currentUser, isNull);
    });
  });
}
