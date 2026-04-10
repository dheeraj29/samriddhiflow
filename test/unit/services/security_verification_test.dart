import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:samriddhi_flow/services/storage_service.dart';

class MockHive extends Mock implements HiveInterface {}

class MockBox<T> extends Mock implements Box<T> {}

void main() {
  late StorageService storageService;
  late MockHive mockHive;
  late MockBox<dynamic> mockSettingsBox;
  late Map<String, dynamic> settingsStore;

  setUp(() {
    mockHive = MockHive();
    mockSettingsBox = MockBox<dynamic>();
    settingsStore = {};

    when(() => mockHive.box(StorageService.boxSettings))
        .thenReturn(mockSettingsBox);
    when(() => mockHive.isBoxOpen(any())).thenReturn(true);

    when(() => mockSettingsBox.get(any(),
        defaultValue: any(named: 'defaultValue'))).thenAnswer((invocation) {
      final key = invocation.positionalArguments[0] as String;
      final defaultValue = invocation.namedArguments[#defaultValue];
      if (settingsStore.containsKey(key)) {
        return settingsStore[key];
      }
      return defaultValue;
    });
    when(() => mockSettingsBox.get(any())).thenAnswer((invocation) {
      final key = invocation.positionalArguments[0] as String;
      return settingsStore[key];
    });
    when(() => mockSettingsBox.put(any(), any()))
        .thenAnswer((invocation) async {
      final key = invocation.positionalArguments[0] as String;
      final value = invocation.positionalArguments[1];
      settingsStore[key] = value;
    });
    when(() => mockSettingsBox.delete(any())).thenAnswer((invocation) async {
      final key = invocation.positionalArguments[0] as String;
      settingsStore.remove(key);
    });

    storageService = StorageService(mockHive);
  });

  group('Security Verification - PIN Hashing', () {
    test('setAppPin correctly hashes with a salt', () async {
      const plaintext = '1234';

      await storageService.setAppPin(plaintext);

      final stored = settingsStore['appPin'] as String;
      expect(stored.contains(':'), isTrue);
      expect(stored.split(':').length, 2);
    });

    test('saveSettings hashes appPin (Restore Simulation)', () async {
      const plaintext = '5678';

      await storageService
          .saveSettings({'appPin': plaintext, 'other': 'value'});

      final stored = settingsStore['appPin'] as String;
      expect(stored.contains(':'), isTrue);
      verify(() => mockSettingsBox.put('other', 'value')).called(1);
    });

    test('saveSettings re-hashes existing values during restore', () async {
      const someValue = 'something';

      await storageService.saveSettings({'appPin': someValue});

      expect(settingsStore['appPin'], isA<String>());
      expect(settingsStore['appPin'], contains(':'));
    });
  });

  group('Security Verification - PIN Lockout', () {
    test('locks after 3 failed attempts and persists attempts', () async {
      await storageService.setAppPin('1111');

      expect(storageService.verifyAppPin('0000'), isFalse);
      expect(storageService.getFailedPinAttempts(), 1);
      expect(storageService.isPinLocked(), isFalse);

      expect(storageService.verifyAppPin('0000'), isFalse);
      expect(storageService.getFailedPinAttempts(), 2);
      expect(storageService.isPinLocked(), isFalse);

      expect(storageService.verifyAppPin('0000'), isFalse);
      expect(storageService.getFailedPinAttempts(), 3);
      expect(storageService.isPinLocked(), isTrue);

      // New instance should read persisted attempts
      final storageService2 = StorageService(mockHive);
      expect(storageService2.getFailedPinAttempts(), 3);
      expect(storageService2.isPinLocked(), isTrue);
    });

    test('resetFailedPinAttempts clears lockout', () async {
      await storageService.setAppPin('1111');
      storageService.verifyAppPin('0000');
      storageService.verifyAppPin('0000');
      storageService.verifyAppPin('0000');

      expect(storageService.isPinLocked(), isTrue);

      storageService.resetFailedPinAttempts();
      expect(storageService.getFailedPinAttempts(), 0);
      expect(storageService.isPinLocked(), isFalse);
    });
  });
}
