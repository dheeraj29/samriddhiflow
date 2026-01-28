import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/services/auth_service.dart';

// Mocks
class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

class FakeNotifier {
  bool value = false;
}

class FakeRef {
  final notifier = FakeNotifier();
  dynamic read(dynamic provider) {
    return notifier;
  }
}

void main() {
  late AuthService authService;
  late MockFirebaseAuth mockAuth;

  setUp(() {
    mockAuth = MockFirebaseAuth();
    authService = AuthService(mockAuth);
  });

  group('AuthService', () {
    test('currentUser returns initial user', () {
      final mockUser = MockUser();
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      expect(authService.currentUser, mockUser);
    });

    test('authStateChanges returns stream', () {
      final stream = Stream<User?>.value(MockUser());
      when(() => mockAuth.authStateChanges()).thenAnswer((_) => stream);
      expect(authService.authStateChanges, stream);
    });

    test('signOut calls auth.signOut', () async {
      when(() => mockAuth.signOut()).thenAnswer((_) async {});

      final fakeRef = FakeRef();

      await authService.signOut(fakeRef);

      // Wait for background future to complete
      await Future.delayed(const Duration(milliseconds: 100));

      verify(() => mockAuth.signOut()).called(1);

      // Verify optimistic update happened
      expect(fakeRef.notifier.value, true);
    });
  });
}
