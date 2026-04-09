import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/services/storage_service.dart';
import 'package:samriddhi_flow/models/dashboard_config.dart';
import 'package:samriddhi_flow/models/category.dart';
import 'dart:io';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class MockStorageService extends Mock implements StorageService {}

class MockProfileNotifier extends ProfileNotifier {
  @override
  String build() => 'default';
}

void main() {
  late MockStorageService mockStorageService;
  late ProviderContainer container;
  late Directory tempDir;

  setUpAll(() async {
    registerFallbackValue(Category(
      id: '',
      name: '',
      usage: CategoryUsage.expense,
      iconCode: 0,
      profileId: '',
    ));
    registerFallbackValue(CategoryTag.none);
    registerFallbackValue(const DashboardVisibilityConfig());
    registerFallbackValue(ConnectivityResult.none);

    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('dev.fluttercommunity.plus/connectivity'),
            (MethodCall methodCall) async {
      if (methodCall.method == 'check') {
        return ['wifi'];
      }
      return null;
    });

    tempDir = Directory.systemTemp.createTempSync('hive_test_detailed');
    Hive.init(tempDir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  setUp(() async {
    if (!Hive.isBoxOpen('settings')) {
      await Hive.openBox('settings');
    } else {
      await Hive.box('settings').clear();
    }

    mockStorageService = MockStorageService();

    // Default stubs for common storage calls
    when(() => mockStorageService.getMonthlyBudget()).thenReturn(0.0);
    when(() => mockStorageService.getCurrencyLocale()).thenReturn('en_IN');
    when(() => mockStorageService.getBackupThreshold()).thenReturn(20);
    when(() => mockStorageService.getTxnsSinceBackup()).thenReturn(0);
    when(() => mockStorageService.getHolidays()).thenReturn([]);
    when(() => mockStorageService.getDashboardConfig())
        .thenReturn(const DashboardVisibilityConfig());
    when(() => mockStorageService.init()).thenAnswer((_) async {});
    when(() => mockStorageService.recalculateCCBalances())
        .thenAnswer((_) async => 0);
    when(() => mockStorageService.getAuthFlag()).thenReturn(false);

    container = ProviderContainer(
      overrides: [
        storageServiceProvider.overrideWithValue(mockStorageService),
        storageInitializerProvider.overrideWith((ref) => const AsyncData(null)),
        activeProfileIdProvider.overrideWith(MockProfileNotifier.new),
        // Stable overrides for streams to avoid Hive race conditions
        isLoggedInHiveStreamProvider
            .overrideWith((ref) => const Stream.empty()),
        activeProfileIdHiveStreamProvider
            .overrideWith((ref) => const Stream.empty()),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('IsLoggedInNotifier', () {
    test('initializes from Hive if box is open', () {
      final isLoggedIn = container.read(isLoggedInProvider);
      expect(isLoggedIn, false);
    });

    test('setLoggedIn updates state and persists to storage', () async {
      when(() => mockStorageService.setAuthFlag(true)).thenAnswer((_) async {});
      await container.read(isLoggedInProvider.notifier).setLoggedIn(true);
      expect(container.read(isLoggedInProvider), true);
      verify(() => mockStorageService.setAuthFlag(true)).called(1);
    });
  });

  group('ProfileNotifier', () {
    test('setProfile updates state and persists', () async {
      when(() => mockStorageService.setActiveProfileId('new_p'))
          .thenAnswer((_) async {});
      await container
          .read(activeProfileIdProvider.notifier)
          .setProfile('new_p');
      verify(() => mockStorageService.setActiveProfileId('new_p')).called(1);
    });
  });

  group('LogoutRequestedNotifier', () {
    test('initial state is false', () {
      expect(container.read(logoutRequestedProvider), false);
    });
    test('updates state', () {
      container.read(logoutRequestedProvider.notifier).value = true;
      expect(container.read(logoutRequestedProvider), true);
    });
  });

  group('DashboardConfigNotifier', () {
    test('initializes from storage', () {
      final config = container.read(dashboardConfigProvider);
      expect(config.showIncomeExpense, true);
      verify(() => mockStorageService.getDashboardConfig()).called(1);
    });
    test('updateConfig updates state and persists', () async {
      when(() => mockStorageService.saveDashboardConfig(any()))
          .thenAnswer((_) async {});
      await container
          .read(dashboardConfigProvider.notifier)
          .updateConfig(showIncomeExpense: false);
      expect(container.read(dashboardConfigProvider).showIncomeExpense, false);
      verify(() => mockStorageService.saveDashboardConfig(any())).called(1);
    });
  });

  group('BackupThresholdNotifier', () {
    test('initializes from storage', () {
      expect(container.read(backupThresholdProvider), 20);
      verify(() => mockStorageService.getBackupThreshold()).called(1);
    });
    test('setThreshold updates state and persists', () async {
      when(() => mockStorageService.setBackupThreshold(50))
          .thenAnswer((_) async {});
      await container.read(backupThresholdProvider.notifier).setThreshold(50);
      expect(container.read(backupThresholdProvider), 50);
      verify(() => mockStorageService.setBackupThreshold(50)).called(1);
    });
  });

  group('TxnsSinceBackupNotifier', () {
    test('initializes from storage', () {
      expect(container.read(txnsSinceBackupProvider), 0);
      verify(() => mockStorageService.getTxnsSinceBackup()).called(1);
    });
    test('refresh updates state from storage', () {
      when(() => mockStorageService.getTxnsSinceBackup()).thenReturn(5);
      container.read(txnsSinceBackupProvider.notifier).refresh();
      expect(container.read(txnsSinceBackupProvider), 5);
    });
    test('reset updates state and persists', () async {
      when(() => mockStorageService.resetTxnsSinceBackup())
          .thenAnswer((_) async {});
      await container.read(txnsSinceBackupProvider.notifier).reset();
      expect(container.read(txnsSinceBackupProvider), 0);
      verify(() => mockStorageService.resetTxnsSinceBackup()).called(1);
    });
  });

  group('HolidaysNotifier', () {
    test('initializes from storage', () {
      expect(container.read(holidaysProvider), isEmpty);
      verify(() => mockStorageService.getHolidays()).called(1);
    });
    test('addHoliday updates state and persists', () async {
      final date = DateTime(2025, 12, 25);
      when(() => mockStorageService.addHoliday(date)).thenAnswer((_) async {});
      when(() => mockStorageService.getHolidays()).thenReturn([date]);
      await container.read(holidaysProvider.notifier).addHoliday(date);
      expect(container.read(holidaysProvider), [date]);
      verify(() => mockStorageService.addHoliday(date)).called(1);
    });
    test('removeHoliday updates state and persists', () async {
      final date = DateTime(2025, 12, 25);
      when(() => mockStorageService.removeHoliday(date))
          .thenAnswer((_) async {});
      when(() => mockStorageService.getHolidays()).thenReturn([]);
      await container.read(holidaysProvider.notifier).removeHoliday(date);
      expect(container.read(holidaysProvider), isEmpty);
      verify(() => mockStorageService.removeHoliday(date)).called(1);
    });
  });

  group('CategoriesNotifier', () {
    test('initializes from storage', () {
      when(() => mockStorageService.getCategories()).thenReturn([]);
      final categories = container.read(categoriesProvider);
      expect(categories, isEmpty);
      verify(() => mockStorageService.getCategories()).called(1);
    });
    test('addCategory updates state and persists', () async {
      final category = Category(
          id: 'cat1',
          name: 'Cat 1',
          usage: CategoryUsage.expense,
          iconCode: 123,
          profileId: 'default');
      when(() => mockStorageService.addCategory(any()))
          .thenAnswer((_) async {});
      when(() => mockStorageService.getCategories()).thenReturn([category]);
      await container.read(categoriesProvider.notifier).addCategory(category);
      expect(container.read(categoriesProvider), [category]);
      verify(() => mockStorageService.addCategory(category)).called(1);
    });
    test('removeCategory updates state and persists', () async {
      when(() => mockStorageService.removeCategory('cat1'))
          .thenAnswer((_) async {});
      when(() => mockStorageService.getCategories()).thenReturn([]);
      await container.read(categoriesProvider.notifier).removeCategory('cat1');
      expect(container.read(categoriesProvider), isEmpty);
      verify(() => mockStorageService.removeCategory('cat1')).called(1);
    });
    test('updateCategory updates state and persists', () async {
      final category = Category(
          id: 'cat1',
          name: 'Updated Cat',
          usage: CategoryUsage.expense,
          iconCode: 456,
          profileId: 'default');
      when(() => mockStorageService.updateCategory('cat1',
          name: 'Updated Cat',
          usage: CategoryUsage.expense,
          tag: any(named: 'tag'),
          iconCode: 456)).thenAnswer((_) async {});
      when(() => mockStorageService.getCategories()).thenReturn([category]);
      await container.read(categoriesProvider.notifier).updateCategory('cat1',
          name: 'Updated Cat',
          usage: CategoryUsage.expense,
          tag: CategoryTag.none,
          iconCode: 456);
      expect(container.read(categoriesProvider).first.name, 'Updated Cat');
      verify(() => mockStorageService.updateCategory('cat1',
          name: 'Updated Cat',
          usage: CategoryUsage.expense,
          tag: CategoryTag.none,
          iconCode: 456)).called(1);
    });
  });

  group('CurrencyNotifier', () {
    test('initializes from storage', () {
      when(() => mockStorageService.getCurrencyLocale()).thenReturn('hi_IN');
      final currency = container.read(currencyProvider);
      expect(currency, 'hi_IN');
      verify(() => mockStorageService.getCurrencyLocale()).called(1);
    });
    test('setCurrency updates state and persists', () async {
      when(() => mockStorageService.setCurrencyLocale('en_US'))
          .thenAnswer((_) async {});
      await container.read(currencyProvider.notifier).setCurrency('en_US');
      expect(container.read(currencyProvider), 'en_US');
      verify(() => mockStorageService.setCurrencyLocale('en_US')).called(1);
    });
  });

  group('BudgetNotifier', () {
    test('initializes from storage', () {
      when(() => mockStorageService.getMonthlyBudget()).thenReturn(1500.0);
      final budget = container.read(monthlyBudgetProvider);
      expect(budget, 1500.0);
      verify(() => mockStorageService.getMonthlyBudget()).called(1);
    });
    test('setBudget updates state and persists', () async {
      when(() => mockStorageService.setMonthlyBudget(2000.0))
          .thenAnswer((_) async {});
      await container.read(monthlyBudgetProvider.notifier).setBudget(2000.0);
      expect(container.read(monthlyBudgetProvider), 2000.0);
      verify(() => mockStorageService.setMonthlyBudget(2000.0)).called(1);
    });
  });

  group('CurrencyFormatNotifier', () {
    test('initial state is true', () {
      expect(container.read(currencyFormatProvider), true);
    });
    test('updates state', () {
      container.read(currencyFormatProvider.notifier).value = false;
      expect(container.read(currencyFormatProvider), false);
    });
  });

  group('AppLockIntentNotifier', () {
    test('initial state is false', () {
      expect(container.read(appLockIntentProvider), false);
    });
    test('lock sets state to true', () {
      container.read(appLockIntentProvider.notifier).lock();
      expect(container.read(appLockIntentProvider), true);
    });
    test('reset sets state to false', () {
      container.read(appLockIntentProvider.notifier).lock();
      container.read(appLockIntentProvider.notifier).reset();
      expect(container.read(appLockIntentProvider), false);
    });
  });

  group('IsOfflineNotifier', () {
    test('initializes as offline by default', () async {
      final isOffline = container.read(isOfflineProvider);
      expect(isOffline, true);
    });
    test('updates state when setOffline is called', () {
      container.read(isOfflineProvider.notifier).setOffline(false);
      expect(container.read(isOfflineProvider), false);
      container.read(isOfflineProvider.notifier).setOffline(true);
      expect(container.read(isOfflineProvider), true);
    });
  });
}
