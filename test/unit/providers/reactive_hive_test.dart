import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samriddhi_flow/providers.dart';
import 'dart:io';
import 'package:hive_ce/hive.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('hive_reactive_test');
    Hive.init(tempDir.path);
    await Hive.openBox('settings');
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('isLoggedInHiveStreamProvider', () {
    test('provides and updates value from Hive box', () async {
      final box = Hive.box('settings');
      await box.put('isLoggedIn', true);

      final container = ProviderContainer(
        overrides: [
          storageInitializerProvider.overrideWith((ref) async {}),
        ],
      );

      bool? result;
      final sub = container.listen(isLoggedInHiveStreamProvider, (prev, next) {
        next.whenData((val) => result = val);
      }, fireImmediately: true);

      // Wait for initial value
      await Future.delayed(const Duration(milliseconds: 50));
      expect(result, true);

      // Test update
      await box.put('isLoggedIn', false);
      // Hive .watch() might take a microtask or two
      await Future.delayed(const Duration(milliseconds: 100));
      expect(result, false);

      sub.close();
      container.dispose();
    });
  });

  group('activeProfileIdHiveStreamProvider', () {
    test('provides and updates profile ID from Hive box', () async {
      final box = Hive.box('settings');
      await box.put('activeProfileId', 'p1');

      final container = ProviderContainer(
        overrides: [
          storageInitializerProvider.overrideWith((ref) async {}),
        ],
      );

      String? result;
      final sub =
          container.listen(activeProfileIdHiveStreamProvider, (prev, next) {
        next.whenData((val) => result = val);
      }, fireImmediately: true);

      await Future.delayed(const Duration(milliseconds: 50));
      expect(result, 'p1');

      await box.put('activeProfileId', 'p2');
      await Future.delayed(const Duration(milliseconds: 100));
      expect(result, 'p2');

      sub.close();
      container.dispose();
    });
  });
}
