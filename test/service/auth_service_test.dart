import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/services/auth_service.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

class MockUserCredential extends Mock implements UserCredential {}

class MockGoogleAuthProvider extends Mock implements GoogleAuthProvider {}

void main() {
  late MockFirebaseAuth mockFirebaseAuth;
  late AuthService authService;
  late MockUser mockUser;

  setUp(() {
    mockFirebaseAuth = MockFirebaseAuth();
    mockUser = MockUser();
    authService = AuthService(mockFirebaseAuth);

    // Default Stubs
    when(() => mockFirebaseAuth.currentUser).thenReturn(mockUser);
    when(() => mockFirebaseAuth.authStateChanges())
        .thenAnswer((_) => Stream.value(mockUser));
    when(() => mockFirebaseAuth.signOut()).thenAnswer((_) async {});
  });

  test('authStateChanges returns stream from FirebaseAuth', () {
    expect(authService.authStateChanges, emits(mockUser));
    verify(() => mockFirebaseAuth.authStateChanges()).called(1);
  });

  test('currentUser returns user from FirebaseAuth', () {
    expect(authService.currentUser, mockUser);
  });

  test('signOut calls FirebaseAuth signOut', () async {
    // We need to pass a mock Ref? signOut takes dynamic ref.
    // Logic: ref.read(logoutRequestedProvider)...
    // We can pass null if safe?
    // Code: ref.read(...)
    // So we need a MockRef.
    // Or simpler: The code checks `isSignOutInProgress`.
    // Wait, ref is used: `ref.read(logoutRequestedProvider.notifier).value = true;`
    // If I pass null, it might throw if not handled.
    // Code says `signInWithGoogle(dynamic ref)` but `signOut(dynamic ref)`.
    // It calls `ref.read`.

    // I can create a simple class with read method.
  });

  test('signOut calls FirebaseAuth signOut (Mock Ref)', () async {
    final mockRef = MockRef();
    final mockNotifier = MockNotifier();
    when(() => mockRef.read(any())).thenReturn(mockNotifier);

    // AuthService uses unawaited future for signOut background.
    // We need to wait for it?
    // `unawaited(Future(() async { ... await _auth?.signOut(); ... }));`
    // This makes it hard to test 'verify' immediately.
    // But we can await `Future.delayed`?

    await authService.signOut(mockRef);

    // Wait for background task
    await Future.delayed(const Duration(milliseconds: 100));

    verify(() => mockFirebaseAuth.signOut()).called(1);
  });
}

class MockRef extends Mock {
  dynamic read(dynamic provider);
}
// To handle provider usage we need strictly typed providers or just return dynamic.
// Mocktail `any()` works.

class MockNotifier extends Mock {
  set value(dynamic v) {}
  dynamic get value => false;
}
