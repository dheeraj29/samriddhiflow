import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:samriddhi_flow/services/auth_service.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

void main() {
  late MockFirebaseAuth mockAuth;
  late AuthService authService;
  late MockUser mockUser;

  setUp(() {
    mockAuth = MockFirebaseAuth();
    mockUser = MockUser();
    authService = AuthService(mockAuth);
  });

  group('AuthService', () {
    test('currentUser returns mock user', () {
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      expect(authService.currentUser, mockUser);
    });

    test('authStateChanges returns stream from firebase auth', () {
      final stream = Stream<User?>.value(mockUser);
      when(() => mockAuth.authStateChanges()).thenAnswer((_) => stream);

      expect(authService.authStateChanges, emits(mockUser));
    });

    test('deleteAccount calls user.delete', () async {
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.delete()).thenAnswer((_) async {});

      await authService.deleteAccount();

      verify(() => mockUser.delete()).called(1);
    });
  });
}
