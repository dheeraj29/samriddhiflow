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

  group('LocalModeNotifier', () {
    test('sets and updates state', () {
      expect(container.read(localModeProvider), false);

      container.read(localModeProvider.notifier).value = true;

      expect(container.read(localModeProvider), true);
    });
  });
}
