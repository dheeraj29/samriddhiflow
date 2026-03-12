import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/models/dashboard_config.dart';
import 'package:samriddhi_flow/services/storage_service.dart';

class MockStorageService extends Mock implements StorageService {}

class FakeDashboardVisibilityConfig extends Fake
    implements DashboardVisibilityConfig {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeDashboardVisibilityConfig());
  });

  group('Providers Notifiers Tests', () {
    test('LocalModeNotifier sets and updates state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(localModeProvider.notifier);
      expect(container.read(localModeProvider), false);

      notifier.value = true;
      expect(container.read(localModeProvider), true);
    });

    test('DashboardConfigNotifier sets and updates state', () async {
      final mockStorage = MockStorageService();
      when(() => mockStorage.getDashboardConfig()).thenReturn(
          const DashboardVisibilityConfig(
              showIncomeExpense: true, showBudget: true));
      when(() => mockStorage.saveDashboardConfig(any()))
          .thenAnswer((_) async {});

      final container = ProviderContainer(overrides: [
        storageServiceProvider.overrideWithValue(mockStorage),
        storageInitializerProvider.overrideWith((ref) => Future.value()),
      ]);
      addTearDown(container.dispose);

      final notifier = container.read(dashboardConfigProvider.notifier);

      expect(container.read(dashboardConfigProvider).showIncomeExpense, true);

      await notifier.updateConfig(showIncomeExpense: false);
      expect(container.read(dashboardConfigProvider).showIncomeExpense, false);
      expect(container.read(dashboardConfigProvider).showBudget, true);

      verify(() => mockStorage.saveDashboardConfig(any())).called(1);
    });

    test('BudgetNotifier sets and updates state', () async {
      final mockStorage = MockStorageService();
      when(() => mockStorage.getMonthlyBudget()).thenReturn(50000.0);
      when(() => mockStorage.setMonthlyBudget(any())).thenAnswer((_) async {});

      final container = ProviderContainer(overrides: [
        storageServiceProvider.overrideWithValue(mockStorage),
        storageInitializerProvider.overrideWith((ref) => Future.value()),
      ]);
      addTearDown(container.dispose);
      await container.read(storageInitializerProvider.future);

      final notifier = container.read(monthlyBudgetProvider.notifier);

      expect(container.read(monthlyBudgetProvider), 50000.0);

      await notifier.setBudget(60000.0);
      expect(container.read(monthlyBudgetProvider), 60000.0);

      verify(() => mockStorage.setMonthlyBudget(60000.0)).called(1);
    });

    test('TxnsSinceBackupNotifier sets and updates state', () async {
      final mockStorage = MockStorageService();
      when(() => mockStorage.getTxnsSinceBackup()).thenReturn(15);
      when(() => mockStorage.resetTxnsSinceBackup()).thenAnswer((_) async {});

      final container = ProviderContainer(overrides: [
        storageServiceProvider.overrideWithValue(mockStorage),
        storageInitializerProvider.overrideWith((ref) => Future.value()),
      ]);
      addTearDown(container.dispose);
      await container.read(storageInitializerProvider.future);

      final notifier = container.read(txnsSinceBackupProvider.notifier);

      expect(container.read(txnsSinceBackupProvider), 15);

      await notifier.reset();
      expect(container.read(txnsSinceBackupProvider), 0);

      verify(() => mockStorage.resetTxnsSinceBackup()).called(1);
    });

    test('HolidaysNotifier sets and updates state', () async {
      final mockStorage = MockStorageService();
      final dt = DateTime(2025, 1, 1);
      final dt2 = DateTime(2025, 1, 26);

      when(() => mockStorage.getHolidays()).thenReturn([dt]);
      when(() => mockStorage.addHoliday(any())).thenAnswer((_) async {});
      when(() => mockStorage.removeHoliday(any())).thenAnswer((_) async {});

      final container = ProviderContainer(overrides: [
        storageServiceProvider.overrideWithValue(mockStorage),
        storageInitializerProvider.overrideWith((ref) => Future.value()),
      ]);
      addTearDown(container.dispose);
      await container.read(storageInitializerProvider.future);

      final notifier = container.read(holidaysProvider.notifier);

      expect(container.read(holidaysProvider), [dt]);

      when(() => mockStorage.getHolidays()).thenReturn([dt, dt2]);
      await notifier.addHoliday(dt2);
      expect(container.read(holidaysProvider), [dt, dt2]);

      when(() => mockStorage.getHolidays()).thenReturn([dt]);
      await notifier.removeHoliday(dt2);
      expect(container.read(holidaysProvider), [dt]);
    });
  });
}
