import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/providers/sum_tracker_provider.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp();
    Hive.init(tempDir.path);
    await Hive.openBox('sum_tracker');
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await tempDir.delete(recursive: true);
  });

  ProviderContainer createContainer() {
    final container = ProviderContainer(
      overrides: [
        // storageInitializerProvider needs to be "ready" (AsyncData)
        // so SumTrackerNotifier initializes _box.
        storageInitializerProvider
            .overrideWithValue(const AsyncValue.data(null)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('SumTrackerNotifier', () {
    test('initializes with generic default profile if empty', () async {
      final container = createContainer();
      // Read provider to trigger build
      final state = container.read(sumTrackerProvider);

      expect(state.profiles.length, 1);
      expect(state.profiles.first.name, 'Default');
      expect(state.activeProfileId, isNotNull);
    });

    test('addProfile adds a new profile and activates it', () async {
      final container = createContainer();
      final notifier = container.read(sumTrackerProvider.notifier);

      // We need to wait for build? No, sync read works if provider is sync.
      // But SumTrackerNotifier build is sync logic relying on AsyncValue.

      await notifier.addProfile('Vacation');

      final state = container.read(sumTrackerProvider);

      expect(state.profiles.length, 2); // Default + Vacation
      expect(state.activeProfile!.name, 'Vacation');
      expect(state.activeProfileId, state.profiles.last.id);
    });

    test('addValue adds entry to active profile', () async {
      final container = createContainer();
      final notifier = container.read(sumTrackerProvider.notifier);

      // Force creation of default
      container.read(sumTrackerProvider);

      // Add Value 50
      await notifier.addValue(50, name: 'Food');

      var state = container.read(sumTrackerProvider);
      expect(state.activeProfile!.entries.length, 1);
      expect(state.activeProfile!.entries.first.value, 50);
      expect(state.activeProfile!.total, 50.0);

      // Add Value *2
      await notifier.addValue(2, operation: '*');
      state = container.read(sumTrackerProvider);
      expect(state.activeProfile!.total, 100.0);
    });

    test('calculateTotal handles operations correctly', () {
      final entries = [
        SumEntry(id: '1', value: 100, operation: '+'),
        SumEntry(id: '2', value: 20, operation: '-'), // 80
        SumEntry(id: '3', value: 2, operation: '*'), // 160
        SumEntry(id: '4', value: 4, operation: '/'), // 40
      ];
      final profile = SumProfile(id: '1', name: 'Test', entries: entries);
      expect(profile.total, 40.0);
    });

    test('deleteProfile removes profile and resets active', () async {
      final container = createContainer();
      final notifier = container.read(sumTrackerProvider.notifier);

      // Ensure initialized
      container.read(sumTrackerProvider);

      final defaultId = container.read(sumTrackerProvider).activeProfileId!;
      await notifier.addProfile('To Delete');

      // Verify addition
      expect(container.read(sumTrackerProvider).profiles.length, 2);
      final deleteId = container.read(sumTrackerProvider).activeProfileId!;
      expect(deleteId, isNot(equals(defaultId)));

      await notifier.deleteProfile(deleteId);

      final state = container.read(sumTrackerProvider);
      expect(state.profiles.length, 1);
      expect(state.profiles.first.id, defaultId);
      expect(state.activeProfileId, defaultId);
    });

    test('clearValues removes all entries from active profile', () async {
      final container = createContainer();
      final notifier = container.read(sumTrackerProvider.notifier);

      container.read(sumTrackerProvider); // init default

      await notifier.addValue(100);
      expect(
          container.read(sumTrackerProvider).activeProfile!.entries.isNotEmpty,
          true);

      await notifier.clearValues();
      expect(container.read(sumTrackerProvider).activeProfile!.entries.isEmpty,
          true);
    });
  });
}
