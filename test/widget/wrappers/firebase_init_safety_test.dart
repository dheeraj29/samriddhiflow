import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/services/auth_service.dart';
import 'package:samriddhi_flow/services/storage_service.dart';

class MockStorageService extends Mock implements StorageService {}

class MockAuthService extends Mock implements AuthService {}

void main() {
  late MockStorageService mockStorage;

  setUp(() {
    mockStorage = MockStorageService();
    when(() => mockStorage.init()).thenAnswer((_) async {});
  });

  testWidgets(
      'authServiceProvider handles pending Firebase initialization without throwing',
      (tester) async {
    // This test verifies that we can watch authServiceProvider even if firebaseInitializerProvider is loading
    final container = ProviderContainer(
      overrides: [
        storageServiceProvider.overrideWithValue(mockStorage),
        firebaseInitializerProvider
            .overrideWith((ref) => Completer<void>().future),
      ],
    );

    // Should NOT throw TypeError or ProviderException
    final authService = container.read(authServiceProvider);
    expect(authService, isA<AuthService>());

    container.dispose();
  });

  testWidgets(
      'authServiceProvider is safe even if Firebase initialization fails',
      (tester) async {
    final container = ProviderContainer(
      overrides: [
        storageServiceProvider.overrideWithValue(mockStorage),
        firebaseInitializerProvider
            .overrideWith((ref) => Future.error('Initialization Failed')),
      ],
    );

    // Accessing authServiceProvider should still be safe
    final authService = container.read(authServiceProvider);
    expect(authService, isA<AuthService>());

    container.dispose();
  });
}
