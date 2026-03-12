import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/services/storage_service.dart';
import 'package:samriddhi_flow/models/category.dart';

class MockStorageService extends Mock implements StorageService {}

class MockProfileNotifier extends ProfileNotifier {
  final String _id;
  MockProfileNotifier([this._id = 'p1']);
  @override
  String build() => _id;
}

void main() {
  late MockStorageService mockStorageService;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue(Category(
        id: '',
        name: '',
        usage: CategoryUsage.expense,
        iconCode: 0,
        profileId: ''));
    registerFallbackValue(CategoryUsage.expense);
    registerFallbackValue(CategoryTag.none);
  });

  setUp(() {
    mockStorageService = MockStorageService();
    // Common stubs
    when(() => mockStorageService.getMonthlyBudget()).thenReturn(1000.0);
    when(() => mockStorageService.getCategories()).thenReturn([]);
    when(() => mockStorageService.getBackupThreshold()).thenReturn(20);
    when(() => mockStorageService.getTxnsSinceBackup()).thenReturn(5);
    when(() => mockStorageService.getHolidays()).thenReturn([]);
    when(() => mockStorageService.getActiveProfileId()).thenReturn('p1');
    when(() => mockStorageService.getAuthFlag()).thenReturn(false);

    container = ProviderContainer(
      overrides: [
        storageServiceProvider.overrideWithValue(mockStorageService),
        storageInitializerProvider.overrideWith((ref) => const AsyncData(null)),
        activeProfileIdProvider.overrideWith(() => MockProfileNotifier('p1')),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('IsLoggedInNotifier', () {
    test('setLoggedIn updates state and storage', () async {
      when(() => mockStorageService.setAuthFlag(true)).thenAnswer((_) async {});
      await container.read(isLoggedInProvider.notifier).setLoggedIn(true);
      expect(container.read(isLoggedInProvider), true);
      verify(() => mockStorageService.setAuthFlag(true)).called(1);
    });
  });

  group('BudgetNotifier', () {
    test('setBudget updates state and storage', () async {
      when(() => mockStorageService.setMonthlyBudget(2000.0))
          .thenAnswer((_) async {});
      await container.read(monthlyBudgetProvider.notifier).setBudget(2000.0);
      expect(container.read(monthlyBudgetProvider), 2000.0);
      verify(() => mockStorageService.setMonthlyBudget(2000.0)).called(1);
    });
  });

  group('CategoriesNotifier', () {
    test('CRUD operations', () async {
      final cat = Category(
          id: 'c1',
          name: 'Sales',
          usage: CategoryUsage.income,
          iconCode: 0,
          profileId: 'p1');
      when(() => mockStorageService.getCategories()).thenReturn([cat]);

      final notifier = container.read(categoriesProvider.notifier);

      when(() => mockStorageService.addCategory(any()))
          .thenAnswer((_) async {});
      await notifier.addCategory(cat);
      expect(container.read(categoriesProvider), [cat]);

      when(() => mockStorageService.updateCategory(any(),
          name: any(named: 'name'),
          usage: any(named: 'usage'),
          tag: any(named: 'tag'),
          iconCode: any(named: 'iconCode'),
          isRestore: any(named: 'isRestore'))).thenAnswer((_) async {});

      await notifier.updateCategory('c1',
          name: 'New',
          usage: CategoryUsage.expense,
          tag: CategoryTag.none,
          iconCode: 1);
      verify(() => mockStorageService.updateCategory('c1',
          name: 'New',
          usage: CategoryUsage.expense,
          tag: CategoryTag.none,
          iconCode: 1,
          isRestore: any(named: 'isRestore'))).called(1);

      when(() => mockStorageService.removeCategory(any()))
          .thenAnswer((_) async {});
      await notifier.removeCategory('c1');
      verify(() => mockStorageService.removeCategory('c1')).called(1);

      await notifier.refresh();
      verify(() => mockStorageService.getCategories())
          .called(5); // build, add, update, remove, refresh
    });
  });

  group('Backup & Holiday Notifiers', () {
    test('BackupThresholdNotifier setThreshold', () async {
      when(() => mockStorageService.setBackupThreshold(50))
          .thenAnswer((_) async {});
      await container.read(backupThresholdProvider.notifier).setThreshold(50);
      expect(container.read(backupThresholdProvider), 50);
    });

    test('TxnsSinceBackupNotifier reset and refresh', () async {
      when(() => mockStorageService.resetTxnsSinceBackup())
          .thenAnswer((_) async {});
      await container.read(txnsSinceBackupProvider.notifier).reset();
      expect(container.read(txnsSinceBackupProvider), 0);

      when(() => mockStorageService.getTxnsSinceBackup()).thenReturn(10);
      container.read(txnsSinceBackupProvider.notifier).refresh();
      expect(container.read(txnsSinceBackupProvider), 10);
    });

    test('HolidaysNotifier add and remove', () async {
      final date = DateTime(2024, 1, 1);
      when(() => mockStorageService.addHoliday(date)).thenAnswer((_) async {});
      when(() => mockStorageService.removeHoliday(date))
          .thenAnswer((_) async {});
      when(() => mockStorageService.getHolidays()).thenReturn([date]);

      await container.read(holidaysProvider.notifier).addHoliday(date);
      expect(container.read(holidaysProvider), [date]);

      when(() => mockStorageService.getHolidays()).thenReturn([]);
      await container.read(holidaysProvider.notifier).removeHoliday(date);
      expect(container.read(holidaysProvider), isEmpty);
    });
  });

  group('Profile & UI Notifiers', () {
    test('ProfileNotifier setProfile', () async {
      when(() => mockStorageService.setActiveProfileId('p2'))
          .thenAnswer((_) async {});
      await container.read(activeProfileIdProvider.notifier).setProfile('p2');
      expect(container.read(activeProfileIdProvider), 'p2');
    });

    test('AppLockIntentNotifier lock and reset', () {
      final notifier = container.read(appLockIntentProvider.notifier);
      notifier.lock();
      expect(container.read(appLockIntentProvider), true);
      notifier.reset();
      expect(container.read(appLockIntentProvider), false);
    });
  });
}
