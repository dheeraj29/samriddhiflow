import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/services/storage_service.dart';

class MockStorageService extends Mock implements StorageService {}

void main() {
  late MockStorageService mockStorageService;
  late ProviderContainer container;

  setUp(() {
    mockStorageService = MockStorageService();
    // Default stubs
    when(() => mockStorageService.getMonthlyBudget()).thenReturn(500.0);
    when(() => mockStorageService.getCurrencyLocale()).thenReturn('en_US');
    when(() => mockStorageService.getBackupThreshold()).thenReturn(20);
    when(() => mockStorageService.getHolidays()).thenReturn([]);

    // storageInitializerProvider usually returns true/initialized
    container = ProviderContainer(
      overrides: [
        storageServiceProvider.overrideWithValue(mockStorageService),
        // Mock initializer to be ready
        storageInitializerProvider.overrideWith((ref) => const AsyncData(true)),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('BudgetNotifier', () {
    test('initializes with value from storage', () {
      final budget = container.read(monthlyBudgetProvider);
      expect(budget, 500.0);
      verify(() => mockStorageService.getMonthlyBudget()).called(1);
    });

    test('updates state and persists to storage', () async {
      when(() => mockStorageService.setMonthlyBudget(1000.0))
          .thenAnswer((_) async {});

      await container.read(monthlyBudgetProvider.notifier).setBudget(1000.0);

      expect(container.read(monthlyBudgetProvider), 1000.0);
      verify(() => mockStorageService.setMonthlyBudget(1000.0)).called(1);
    });
  });

  group('CurrencyNotifier', () {
    test('initializes with value from storage', () {
      final currency = container.read(currencyProvider);
      expect(currency, 'en_US');
    });

    test('updates state and persists to storage', () async {
      when(() => mockStorageService.setCurrencyLocale('en_IN'))
          .thenAnswer((_) async {});

      await container.read(currencyProvider.notifier).setCurrency('en_IN');

      expect(container.read(currencyProvider), 'en_IN');
      verify(() => mockStorageService.setCurrencyLocale('en_IN')).called(1);
    });
  });

  group('HolidaysNotifier', () {
    test('initializes with empty list', () {
      final holidays = container.read(holidaysProvider);
      expect(holidays, isEmpty);
    });

    test('adds holiday and refreshes state', () async {
      final date = DateTime(2025, 1, 1);
      when(() => mockStorageService.addHoliday(date)).thenAnswer((_) async {});
      when(() => mockStorageService.getHolidays()).thenReturn([date]);

      await container.read(holidaysProvider.notifier).addHoliday(date);

      expect(container.read(holidaysProvider), contains(date));
      verify(() => mockStorageService.addHoliday(date)).called(1);
    });

    test('removes holiday and refreshes state', () async {
      final date = DateTime(2025, 1, 1);
      when(() => mockStorageService.removeHoliday(date))
          .thenAnswer((_) async {});
      when(() => mockStorageService.getHolidays()).thenReturn([]);

      await container.read(holidaysProvider.notifier).removeHoliday(date);

      expect(container.read(holidaysProvider), isEmpty);
      verify(() => mockStorageService.removeHoliday(date)).called(1);
    });
  });
}
