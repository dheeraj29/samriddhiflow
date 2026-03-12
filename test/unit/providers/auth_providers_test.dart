import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:hive_ce/hive.dart';
import 'package:samriddhi_flow/hive_registrar.g.dart';

class MockAuthService extends Mock implements AuthService {}

class MockUser extends Mock implements User {}

class MockLogoutRequestedNotifier extends LogoutRequestedNotifier {
  final bool _val;
  MockLogoutRequestedNotifier(this._val);
  @override
  bool build() => _val;
}

void main() {
  late MockAuthService mockAuthService;

  setUpAll(() {
    try {
      Hive.registerAdapters();
    } catch (_) {}
  });

  setUp(() {
    mockAuthService = MockAuthService();
    when(() => mockAuthService.authStateChanges)
        .thenAnswer((_) => const Stream.empty());
  });

  group('authStreamProvider', () {
    test('returns null stream if logoutRequested is true', () async {
      final container = ProviderContainer(
        overrides: [
          firebaseInitializerProvider
              .overrideWith((ref) => const AsyncData(null)),
          logoutRequestedProvider
              .overrideWith(() => MockLogoutRequestedNotifier(true)),
          authServiceProvider.overrideWithValue(mockAuthService),
        ],
      );

      User? result = MockUser(); // initially non-null
      final sub = container.listen(authStreamProvider, (prev, next) {
        next.whenData((val) => result = val);
      }, fireImmediately: true);

      await Future.delayed(const Duration(milliseconds: 50));
      expect(result, isNull);

      sub.close();
      container.dispose();
    });

    test('follows authService.authStateChanges if not logging out', () async {
      final mockUser = MockUser();
      final controller = StreamController<User?>(sync: true);

      when(() => mockAuthService.authStateChanges)
          .thenAnswer((_) => controller.stream);

      final container = ProviderContainer(
        overrides: [
          firebaseInitializerProvider
              .overrideWith((ref) => const AsyncData(null)),
          logoutRequestedProvider
              .overrideWith(() => MockLogoutRequestedNotifier(false)),
          authServiceProvider.overrideWithValue(mockAuthService),
        ],
      );

      User? result;
      final sub = container.listen(authStreamProvider, (prev, next) {
        next.whenData((val) => result = val);
      }, fireImmediately: true);

      controller.add(mockUser);
      await Future.delayed(Duration.zero);
      expect(result, mockUser);

      controller.add(null);
      await Future.delayed(Duration.zero);
      expect(result, isNull);

      sub.close();
      controller.close();
      container.dispose();
    });

    test('provides empty stream while loading firebase', () {
      final container = ProviderContainer(
        overrides: [
          firebaseInitializerProvider
              .overrideWith((ref) => const AsyncLoading()),
          authServiceProvider.overrideWithValue(mockAuthService),
        ],
      );

      final state = container.read(authStreamProvider);
      expect(state, isNotNull);
      container.dispose();
    });
  });
}
