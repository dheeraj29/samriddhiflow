import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:samriddhi_flow/models/category.dart';
import 'package:samriddhi_flow/models/profile.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/feature_providers.dart';
import 'package:samriddhi_flow/screens/settings_screen.dart';
import 'package:samriddhi_flow/services/storage_service.dart';
import 'package:samriddhi_flow/services/auth_service.dart';
import 'package:samriddhi_flow/services/excel_service.dart';
import 'package:samriddhi_flow/services/file_service.dart';
import 'package:samriddhi_flow/services/cloud_sync_service.dart';

class MockStorageService extends Mock implements StorageService {}

class MockAuthService extends Mock implements AuthService {}

class MockExcelService extends Mock implements ExcelService {}

class MockFileService extends Mock implements FileService {}

class MockCloudSyncService extends Mock implements CloudSyncService {}

class MockUser extends Mock implements User {}

class FakeCurrencyNotifier extends CurrencyNotifier {
  @override
  String build() => 'en_IN';
}

class FakeProfileNotifier extends ProfileNotifier {
  @override
  String build() => 'default';
}

class FakeThemeModeNotifier extends ThemeModeNotifier {
  @override
  ThemeMode build() => ThemeMode.system;
}

class FakeCategoriesNotifier extends CategoriesNotifier {
  @override
  List<Category> build() => [
        Category(
            id: 'cat1',
            name: 'Food',
            usage: CategoryUsage.expense,
            profileId: 'default'),
      ];
}

class FakeIsOfflineNotifier extends Notifier<bool>
    implements IsOfflineNotifier {
  @override
  bool build() => false;
}

class FakeSmartCalculatorEnabledNotifier
    extends SmartCalculatorEnabledNotifier {
  @override
  bool build() => true;
}

class FakeBudgetNotifier extends BudgetNotifier {
  @override
  double build() => 1000.0;
}

class FakeBackupThresholdNotifier extends BackupThresholdNotifier {
  @override
  int build() => 20;
}

class FakeTxnsSinceBackupNotifier extends Notifier<int>
    implements TxnsSinceBackupNotifier {
  @override
  int build() => 0;
  @override
  void refresh() {}
  @override
  Future<void> reset() async {}
}

void main() {
  late MockStorageService mockStorageService;
  late MockAuthService mockAuthService;
  late MockExcelService mockExcelService;
  late MockFileService mockFileService;
  late MockCloudSyncService mockCloudSyncService;

  setUpAll(() {
    registerFallbackValue(ThemeMode.light);
    registerFallbackValue(
        Category.create(name: 'Test', usage: CategoryUsage.expense));
    registerFallbackValue(Profile(id: 'p1', name: 'Profile 1'));
    registerFallbackValue(CategoryUsage.expense);
    registerFallbackValue(CategoryTag.none);
  });

  setUp(() {
    mockStorageService = MockStorageService();
    mockAuthService = MockAuthService();
    mockExcelService = MockExcelService();
    mockFileService = MockFileService();
    mockCloudSyncService = MockCloudSyncService();

    when(() => mockStorageService.isAppLockEnabled()).thenReturn(false);
    when(() => mockStorageService.getMonthlyBudget()).thenReturn(1000.0);
    when(() => mockStorageService.getCurrencyLocale()).thenReturn('en_IN');
    when(() => mockStorageService.getBackupThreshold()).thenReturn(20);
    when(() => mockStorageService.getAppPin()).thenReturn(null);
    when(() => mockStorageService.getProfiles()).thenReturn([
      Profile(id: 'default', name: 'Default'),
    ]);
    when(() => mockStorageService.getActiveProfileId()).thenReturn('default');
    when(() => mockStorageService.getCategories()).thenReturn([]);
    when(() => mockStorageService.addCategory(any()))
        .thenAnswer((_) => Future.value());
    when(() => mockStorageService.removeCategory(any()))
        .thenAnswer((_) => Future.value());
    when(() => mockStorageService.updateCategory(any(),
        name: any(named: 'name'),
        usage: any(named: 'usage'),
        tag: any(named: 'tag'),
        iconCode: any(named: 'iconCode'))).thenAnswer((_) => Future.value());
    when(() => mockStorageService.saveProfile(any()))
        .thenAnswer((_) => Future.value());
    when(() => mockStorageService.setSmartCalculatorEnabled(any()))
        .thenAnswer((_) => Future.value());
    when(() => mockStorageService.setBackupThreshold(any()))
        .thenAnswer((_) => Future.value());
    when(() => mockStorageService.setMonthlyBudget(any()))
        .thenAnswer((_) => Future.value());
    when(() => mockStorageService.setCurrencyLocale(any()))
        .thenAnswer((_) => Future.value());
    when(() => mockStorageService.setThemeMode(any()))
        .thenAnswer((_) => Future.value());
    when(() => mockStorageService.setAppLockEnabled(any()))
        .thenAnswer((_) => Future.value());
    when(() => mockStorageService.setAppPin(any()))
        .thenAnswer((_) => Future.value());

    when(() => mockCloudSyncService.syncToCloud())
        .thenAnswer((_) => Future.value());
    when(() => mockCloudSyncService.restoreFromCloud())
        .thenAnswer((_) => Future.value());

    when(() =>
            mockExcelService.exportData(allProfiles: any(named: 'allProfiles')))
        .thenAnswer((_) async => Uint8List(0));
    when(() => mockExcelService.importData(
          fileBytes: any(named: 'fileBytes'),
          allProfiles: any(named: 'allProfiles'),
        )).thenAnswer((_) async => {
          'status': 1,
          'accounts': 5,
          'profiles': 0,
          'transactions': 0,
          'loans': 0,
          'loanTransactions': 0,
          'categories': 0,
        });
    when(() => mockFileService.saveFile(any(), any()))
        .thenAnswer((_) async => 'path/to/file');
    when(() => mockFileService.pickFile()).thenAnswer((_) async => null);
  });

  Widget createTestWidget(WidgetTester tester, {User? user}) {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    return ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(mockStorageService),
        authServiceProvider.overrideWithValue(mockAuthService),
        excelServiceProvider.overrideWithValue(mockExcelService),
        fileServiceProvider.overrideWithValue(mockFileService),
        cloudSyncServiceProvider.overrideWithValue(mockCloudSyncService),
        storageInitializerProvider.overrideWith((ref) => Future.value()),
        authStreamProvider.overrideWith((ref) => Stream.value(user)),
        currencyProvider.overrideWith(() => FakeCurrencyNotifier()),
        activeProfileIdProvider.overrideWith(() => FakeProfileNotifier()),
        themeModeProvider.overrideWith(() => FakeThemeModeNotifier()),
        categoriesProvider.overrideWith(() => FakeCategoriesNotifier()),
        profilesProvider.overrideWith(
            (ref) => Future.value([Profile(id: 'default', name: 'Default')])),
        isOfflineProvider.overrideWith(() => FakeIsOfflineNotifier()),
        smartCalculatorEnabledProvider
            .overrideWith(() => FakeSmartCalculatorEnabledNotifier()),
        monthlyBudgetProvider.overrideWith(() => FakeBudgetNotifier()),
        backupThresholdProvider
            .overrideWith(() => FakeBackupThresholdNotifier()),
        txnsSinceBackupProvider
            .overrideWith(() => FakeTxnsSinceBackupNotifier()),
        loansProvider.overrideWith((ref) => Stream.value([])),
        accountsProvider.overrideWith((ref) => Stream.value([])),
        transactionsProvider.overrideWith((ref) => Stream.value([])),
        recurringTransactionsProvider.overrideWith((ref) => Stream.value([])),
      ],
      child: MaterialApp(
        home: const SettingsScreen(),
        onGenerateRoute: (settings) {
          return MaterialPageRoute(
            builder: (context) =>
                Scaffold(body: Text('Route: ${settings.name}')),
          );
        },
      ),
    );
  }

  testWidgets('SettingsScreen appearance section works', (tester) async {
    await tester.pumpWidget(createTestWidget(tester));
    await tester.pumpAndSettle();

    expect(find.text('Appearance').first, findsOneWidget);
    expect(find.text('Theme Mode'), findsOneWidget);
  });

  testWidgets('SettingsScreen categories manager works', (tester) async {
    await tester.pumpWidget(createTestWidget(tester));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.category).first);
    await tester.pumpAndSettle();

    expect(find.text('Manage Categories').last, findsOneWidget);
    expect(find.text('Food'), findsOneWidget);

    await tester.enterText(
        find.widgetWithText(TextField, 'Category Name'), 'Salary');
    await tester.tap(find.text('Add Category').first);
    await tester.pumpAndSettle();
  });

  testWidgets('SettingsScreen profile management works', (tester) async {
    await tester.pumpWidget(createTestWidget(tester));
    await tester.pumpAndSettle();

    expect(find.text('Profile Management'), findsOneWidget);

    await tester.tap(find.text('Add New Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Create Profile'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'Business');
    await tester.tap(find.text('CREATE'));
    await tester.pumpAndSettle();

    verify(() => mockStorageService.saveProfile(any())).called(1);
  });

  testWidgets('SettingsScreen backup threshold works', (tester) async {
    await tester.pumpWidget(createTestWidget(tester));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Backup Reminder'));
    await tester.pumpAndSettle();

    expect(find.text('Backup Interval'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, '50');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Backup Interval'), findsNothing);
    verify(() => mockStorageService.setBackupThreshold(50)).called(1);
  });

  testWidgets('SettingsScreen cloud sync success', (tester) async {
    final mockUser = MockUser();
    when(() => mockUser.email).thenReturn('test@example.com');

    await tester.pumpWidget(createTestWidget(tester, user: mockUser));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Migrate/Sync Now'));
    await tester.pumpAndSettle();

    verify(() => mockCloudSyncService.syncToCloud()).called(1);
    expect(find.text('Cloud Sync Success!'), findsOneWidget);
  });

  testWidgets('SettingsScreen feature toggles work', (tester) async {
    await tester.pumpWidget(createTestWidget(tester));
    await tester.pumpAndSettle();

    expect(find.text('Smart Calculator'), findsOneWidget);

    await tester.tap(find.text('Smart Calculator'));
    await tester.pumpAndSettle();

    verify(() => mockStorageService.setSmartCalculatorEnabled(any())).called(1);
  });

  testWidgets('SettingsScreen data export/import works', (tester) async {
    await tester.pumpWidget(createTestWidget(tester));
    await tester.pumpAndSettle();

    // Export
    await tester.tap(find.text('Export Data to Excel'));
    await tester.pumpAndSettle();

    verify(() =>
            mockExcelService.exportData(allProfiles: any(named: 'allProfiles')))
        .called(1);
    verify(() => mockFileService.saveFile(any(), any())).called(1);
    expect(find.textContaining('Exported:'), findsOneWidget);

    // Clear snackbars to avoid queuing delay
    tester
        .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
        .clearSnackBars();
    await tester.pump();

    // Import
    await tester.tap(find.text('Restore Data from Excel (Local)'));
    await tester.pumpAndSettle();

    verify(() => mockExcelService.importData(
          fileBytes: any(named: 'fileBytes'),
          allProfiles: any(named: 'allProfiles'),
        )).called(1);

    expect(find.textContaining('5 accounts'), findsOneWidget);
  });

  testWidgets('SettingsScreen app lock setup works', (tester) async {
    await tester.pumpWidget(createTestWidget(tester));
    await tester.pumpAndSettle();

    await tester.tap(find.text('App Lock (PIN)'));
    await tester.pumpAndSettle();

    expect(find.text('Set App PIN'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, '1234');
    await tester.tap(find.text('SAVE & ENABLE'));
    await tester.pumpAndSettle();

    verify(() => mockStorageService.setAppPin('1234')).called(1);
    verify(() => mockStorageService.setAppLockEnabled(true)).called(1);
  });

  testWidgets('SettingsScreen currency and budget selection works',
      (tester) async {
    await tester.pumpWidget(createTestWidget(tester));
    await tester.pumpAndSettle();

    // Currency
    await tester.tap(find.text('Currency'));
    await tester.pumpAndSettle();
    expect(find.text('Select Currency'), findsOneWidget);
    await tester.tap(find.text('US Dollar (\$)'));
    await tester.pumpAndSettle();
    verify(() => mockStorageService.setCurrencyLocale('en_US')).called(1);

    // Budget
    await tester.tap(find.text('Monthly Budget'));
    await tester.pumpAndSettle();
    expect(find.text('Set Monthly Budget'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, '2000');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    verify(() => mockStorageService.setMonthlyBudget(2000.0)).called(1);
  });
}
