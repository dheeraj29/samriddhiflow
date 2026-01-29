import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/feature_providers.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/services/storage_service.dart';

class MockStorageService extends Mock implements StorageService {}

void main() {
  late MockStorageService mockStorageService;
  late ProviderContainer container;

  setUp(() {
    mockStorageService = MockStorageService();

    // Default stubs for feature providers
    when(() => mockStorageService.getThemeMode()).thenReturn('system');
    when(() => mockStorageService.isSmartCalculatorEnabled()).thenReturn(true);

    container = ProviderContainer(
      overrides: [
        storageServiceProvider.overrideWithValue(mockStorageService),
        storageInitializerProvider.overrideWith((ref) => const AsyncData(true)),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('ThemeModeNotifier', () {
    test('initializes with value from storage', () {
      final theme = container.read(themeModeProvider);
      expect(theme, ThemeMode.system);
    });

    test('updates state and persists to storage', () async {
      when(() => mockStorageService.setThemeMode('dark'))
          .thenAnswer((_) async {});

      await container
          .read(themeModeProvider.notifier)
          .setThemeMode(ThemeMode.dark);

      expect(container.read(themeModeProvider), ThemeMode.dark);
      verify(() => mockStorageService.setThemeMode('dark')).called(1);
    });
  });

  group('SmartCalculatorEnabledNotifier', () {
    test('initializes with value from storage', () {
      final enabled = container.read(smartCalculatorEnabledProvider);
      expect(enabled, isTrue);
    });

    test('toggles state and persists to storage', () async {
      when(() => mockStorageService.setSmartCalculatorEnabled(false))
          .thenAnswer((_) async {});

      await container.read(smartCalculatorEnabledProvider.notifier).toggle();

      expect(container.read(smartCalculatorEnabledProvider), isFalse);
      verify(() => mockStorageService.setSmartCalculatorEnabled(false))
          .called(1);
    });
  });

  group('CalculatorVisibleNotifier', () {
    test('initializes as false', () {
      final visible = container.read(calculatorVisibleProvider);
      expect(visible, isFalse);
    });

    test('updates value only when enabled', () {
      // It is enabled by default in setup
      container.read(calculatorVisibleProvider.notifier).value = true;
      expect(container.read(calculatorVisibleProvider), isTrue);

      // Disable it
      when(() => mockStorageService.setSmartCalculatorEnabled(false))
          .thenAnswer((_) async {});
      container.read(smartCalculatorEnabledProvider.notifier).toggle();

      // When disabled, visibility should be forced to false (logic in build of CalculatorVisibleNotifier)
      expect(container.read(calculatorVisibleProvider), isFalse);
    });
  });
}
