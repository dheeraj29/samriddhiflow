import 'dart:io';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/services/storage_service.dart';
import 'package:samriddhi_flow/services/auth_service.dart';
import 'package:samriddhi_flow/models/profile.dart';
import 'package:samriddhi_flow/utils/network_utils.dart';
import 'package:flutter/services.dart';

class MockStorageService extends Mock implements StorageService {}

class MockAuthService extends Mock implements AuthService {}

class MockIsOfflineNotifier extends IsOfflineNotifier {
  @override
  bool build() => false;
  @override
  void setOffline(bool val) {
    state = val;
  }
}

class TrueIsOfflineNotifier extends IsOfflineNotifier {
  @override
  bool build() => true;
  @override
  void setOffline(bool val) {
    state = val;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late MockStorageService mockStorageService;
  late MockAuthService mockAuthService;

  const MethodChannel pathChannel =
      MethodChannel('plugins.flutter.io/path_provider');
  const MethodChannel connectivityChannel =
      MethodChannel('dev.fluttercommunity.plus/connectivity');

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('infra_test');
    Hive.init(tempDir.path);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (MethodCall methodCall) async {
      return tempDir.path;
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(connectivityChannel,
            (MethodCall methodCall) async {
      if (methodCall.method == 'check') return ['none'];
      return null;
    });

    // Globally mock static NetworkUtils to prevent leaks from any un-overriden providers
    NetworkUtils.mockIsOffline = () => Future.value(false);
  });

  tearDownAll(() async {
    NetworkUtils.mockIsOffline = null;
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  setUp(() {
    mockStorageService = MockStorageService();
    mockAuthService = MockAuthService();

    when(() => mockStorageService.init()).thenAnswer((_) async {});
    when(() => mockStorageService.recalculateCCBalances())
        .thenAnswer((_) async => 0);
    when(() => mockStorageService.getAuthFlag()).thenReturn(false);
    when(() => mockStorageService.getActiveProfileId()).thenReturn('default');
    when(() => mockStorageService.getProfiles()).thenReturn([]);
    when(() => mockStorageService.isAppLockEnabled()).thenReturn(false);
    when(() => mockStorageService.getAppPin()).thenReturn(null);
    when(() => mockStorageService.getBackupThreshold()).thenReturn(0);
    when(() => mockStorageService.getTxnsSinceBackup()).thenReturn(0);
    when(() => mockStorageService.getHolidays()).thenReturn([]);
    when(() => mockStorageService.setActiveProfileId(any()))
        .thenAnswer((_) async {});

    when(() => mockAuthService.authStateChanges)
        .thenAnswer((_) => Stream.value(null));
  });

  ProviderContainer createContainer({
    List overrides = const [],
    bool mockFirebase = true,
    bool mockStorageInit = true,
    bool mockIsLoggedInStream = true,
    bool mockActiveProfileStream = true,
    bool mockIsOffline = true,
  }) {
    final container = ProviderContainer(
      overrides: [
        storageServiceProvider.overrideWithValue(mockStorageService),
        authServiceProvider.overrideWithValue(mockAuthService),
        if (mockIsOffline)
          isOfflineProvider.overrideWith(MockIsOfflineNotifier.new),
        connectivityStreamProvider.overrideWith((ref) => const Stream.empty()),
        if (mockFirebase)
          firebaseInitializerProvider
              .overrideWith((ref) => const AsyncData(null)),
        if (mockStorageInit)
          storageInitializerProvider
              .overrideWith((ref) => const AsyncData(null)),
        if (mockActiveProfileStream)
          activeProfileIdHiveStreamProvider
              .overrideWith((ref) => const Stream.empty()),
        if (mockIsLoggedInStream)
          isLoggedInHiveStreamProvider
              .overrideWith((ref) => const Stream.empty()),
        ...overrides,
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('Infrastructure Providers', () {
    test('storageInitializerProvider initial state', () async {
      final container = createContainer(mockStorageInit: false);
      expect(container.read(storageInitializerProvider),
          const AsyncLoading<void>());
    });

    test('profilesProvider and activeProfileProvider', () async {
      final container = createContainer();
      final profile = Profile(id: 'p1', name: 'User 1');
      when(() => mockStorageService.getProfiles()).thenReturn([profile]);
      when(() => mockStorageService.getActiveProfileId()).thenReturn('p1');

      final profiles = await container.read(profilesProvider.future);
      expect(profiles, [profile]);

      final activeProfile = container.read(activeProfileProvider);
      expect(activeProfile?.id, 'p1');
    });

    test('appLockStatusProvider reflects storage state', () async {
      final container = createContainer();
      when(() => mockStorageService.isAppLockEnabled()).thenReturn(true);
      when(() => mockStorageService.getAppPin()).thenReturn('1234');
      expect(container.read(appLockStatusProvider), true);

      when(() => mockStorageService.isAppLockEnabled()).thenReturn(false);
      container.invalidate(appLockStatusProvider);
      expect(container.read(appLockStatusProvider), false);
    });

    test('isOfflineProvider updates state', () {
      final container = createContainer();
      final notifier = container.read(isOfflineProvider.notifier);
      notifier.setOffline(true);
      expect(container.read(isOfflineProvider), true);
    });

    test('connectivity providers function correctly', () async {
      final container = createContainer();
      final check = container.read(connectivityCheckProvider);
      await check();
      container.read(connectivityStreamProvider);
    });

    test('activeProfileProvider fallback hit', () async {
      final profile = Profile(id: 'p1', name: 'User 1');
      when(() => mockStorageService.getProfiles()).thenReturn([profile]);
      when(() => mockStorageService.getActiveProfileId()).thenReturn('default');

      final container = createContainer(
        mockActiveProfileStream: false,
        overrides: [
          activeProfileIdProvider.overrideWith(ProfileNotifier.new),
          profilesProvider.overrideWith((ref) => [profile]),
        ],
      );

      await container.read(profilesProvider.future);
      await container.read(activeProfileIdProvider.notifier).setProfile('p2');

      // Let any internal notifies propagate
      await Future.delayed(const Duration(milliseconds: 10));

      final activeProfile = container.read(activeProfileProvider);
      expect(activeProfile?.id, 'p1');
    });

    test('isLoggedInProvider value hit', () async {
      when(() => mockStorageService.getAuthFlag()).thenReturn(true);
      final container = createContainer(
        mockIsLoggedInStream: false,
        overrides: [
          isLoggedInHiveStreamProvider
              .overrideWith((ref) => Stream.value(true)),
        ],
      );
      await Future.delayed(const Duration(milliseconds: 10));
      expect(container.read(isLoggedInProvider), true);
    });

    test('ProfileNotifier orElse branch hit', () {
      when(() => mockStorageService.getActiveProfileId()).thenReturn('p1');
      final container = createContainer(
        mockActiveProfileStream: false,
        overrides: [
          activeProfileIdHiveStreamProvider
              .overrideWith((ref) => StreamController<String>().stream),
        ],
      );
      expect(container.read(activeProfileIdProvider), 'p1');
    });

    test('IsLoggedInNotifier orElse branch hit', () {
      when(() => mockStorageService.getAuthFlag()).thenReturn(true);
      final container = createContainer(
        mockIsLoggedInStream: false,
        overrides: [
          isLoggedInHiveStreamProvider
              .overrideWith((ref) => StreamController<bool>().stream),
        ],
      );
      expect(container.read(isLoggedInProvider), true);
    });

    test('firebaseInitializerProvider offline hit', () async {
      final container = createContainer(
        mockFirebase: false,
        mockIsOffline: false,
        overrides: [
          isOfflineProvider.overrideWith(TrueIsOfflineNotifier.new),
        ],
      );

      // Force provider evaluation
      final _ = container.read(firebaseInitializerProvider);

      // Allow microtasks to complete for AsyncValue transition
      await Future.delayed(Duration.zero);

      final state = container.read(firebaseInitializerProvider);
      expect(state.hasError, true);
      expect(state.error.toString(), contains('offline mode'));
    });
  });
}
