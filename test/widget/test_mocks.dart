import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/models/account.dart';
import 'package:samriddhi_flow/models/category.dart';
import 'package:samriddhi_flow/models/loan.dart';
import 'package:samriddhi_flow/models/profile.dart';
import 'package:samriddhi_flow/models/transaction.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/services/auth_service.dart';
import 'package:samriddhi_flow/services/excel_service.dart';
import 'package:samriddhi_flow/services/file_service.dart';
import 'package:samriddhi_flow/services/notification_service.dart';
import 'package:samriddhi_flow/services/storage_service.dart';
import 'package:samriddhi_flow/services/calendar_service.dart';
import 'package:samriddhi_flow/services/cloud_sync_service.dart';
import 'package:samriddhi_flow/services/repair_service.dart';
import 'package:samriddhi_flow/utils/file_picker_wrapper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:samriddhi_flow/feature_providers.dart';

// --- Service Mocks (Mocktail) ---
class MockFileService extends Mock implements FileService {}

class MockFilePickerWrapper extends Mock implements FilePickerWrapper {}

class MockCalendarService extends Mock implements CalendarService {}

class MockCloudSyncService extends Mock implements CloudSyncService {}

class MockRepairService extends Mock implements RepairService {}

class MockExcelService extends Mock implements ExcelService {
  @override
  Future<List<int>> exportData({bool allProfiles = false}) async => [];
}

class MockAuthService extends Mock implements AuthService {}

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {
  @override
  String? get email => 'test@example.com';
  @override
  String get uid => 'test-uid';
  @override
  String? get displayName => 'Test User';
}

class MockNotificationService extends Mock implements NotificationService {
  @override
  Future<void> init() async {}

  @override
  Future<List<String>> checkNudges() async => [];
}

// --- Manual Mock Storage ---
class MockStorageService extends Mock implements StorageService {
  void setLocked(bool val) => when(() => isAppLockEnabled()).thenReturn(val);
  void setPin(String? val) => when(() => getAppPin()).thenReturn(val);
}

void setupStorageDefaults(MockStorageService mock) {
  registerFallbackValues();

  when(() => mock.isAppLockEnabled()).thenReturn(false);
  when(() => mock.getAppPin()).thenReturn('1111');
  when(() => mock.getActiveProfileId()).thenReturn('default');
  when(() => mock.getCurrencyLocale()).thenReturn('en_IN');
  when(() => mock.getMonthlyBudget()).thenReturn(50000);
  when(() => mock.getBackupThreshold()).thenReturn(20);
  when(() => mock.getTxnsSinceBackup()).thenReturn(0);
  when(() => mock.getHolidays()).thenReturn([]);
  when(() => mock.getCategories()).thenReturn([
    Category(
        id: 'cat1',
        name: 'Food',
        usage: CategoryUsage.expense,
        iconCode: 57564,
        tag: CategoryTag.none),
    Category(
        id: 'cat2',
        name: 'Salary',
        usage: CategoryUsage.income,
        iconCode: 57565,
        tag: CategoryTag.none),
  ]);
  when(() => mock.getProfiles())
      .thenReturn([Profile(id: 'default', name: 'User')]);
  when(() => mock.getAccounts()).thenReturn([
    Account(id: 'acc1', name: 'Cash', type: AccountType.wallet, balance: 1000),
  ]);
  when(() => mock.getTransactions()).thenReturn([]);
  when(() => mock.getDeletedTransactions()).thenReturn([]);
  when(() => mock.restoreTransaction(any())).thenAnswer((_) async {});
  when(() => mock.permanentlyDeleteTransaction(any())).thenAnswer((_) async {});
  when(() => mock.saveLoan(any())).thenAnswer((_) async {});
  when(() => mock.addCategory(any())).thenAnswer((_) async {});
  when(() => mock.removeCategory(any())).thenAnswer((_) async {});
  when(() => mock.updateCategory(any(),
      name: any(named: 'name'),
      usage: any(named: 'usage'),
      tag: any(named: 'tag'),
      iconCode: any(named: 'iconCode'))).thenAnswer((_) async {});
  when(() => mock.getLoans()).thenReturn([]);
  when(() => mock.getRecurring()).thenReturn([]);
  when(() => mock.getAuthFlag()).thenReturn(true);
  when(() => mock.init()).thenAnswer((_) async {});
  when(() => mock.isSmartCalculatorEnabled()).thenReturn(true);
  when(() => mock.getThemeMode()).thenReturn('system');
  when(() => mock.resetTxnsSinceBackup()).thenAnswer((_) async {});
  when(() => mock.getLastLogin()).thenReturn(null);
  when(() => mock.setLastLogin(any())).thenAnswer((_) async {});
  when(() => mock.getInactivityThresholdDays()).thenReturn(30);
  when(() => mock.getMaturityWarningDays()).thenReturn(7);
  when(() =>
          mock.checkCreditCardRollovers(nowOverride: any(named: 'nowOverride')))
      .thenAnswer((_) async {});
  when(() => mock.saveAccount(any())).thenAnswer((_) async {});
  when(() => mock.saveProfile(any())).thenAnswer((_) async {});
}

// --- Notifier Mocks ---
class MockIsOfflineNotifier extends IsOfflineNotifier {
  final bool initialValue;
  MockIsOfflineNotifier([this.initialValue = false]);
  @override
  bool build() => initialValue;
}

class MockBudgetNotifier extends BudgetNotifier {
  final double initialValue;
  MockBudgetNotifier([this.initialValue = 50000]);
  @override
  double build() => initialValue;
  @override
  Future<void> setBudget(double amount) async {
    final storage = ref.read(storageServiceProvider);
    await storage.setMonthlyBudget(amount);
    state = amount;
  }
}

class MockCategoriesNotifier extends CategoriesNotifier {
  final List<Category>? initialValue;
  MockCategoriesNotifier([this.initialValue]);

  @override
  List<Category> build() =>
      initialValue ??
      [
        Category(
            id: 'cat1',
            name: 'Food',
            usage: CategoryUsage.expense,
            iconCode: 57564,
            tag: CategoryTag.none),
        Category(
            id: 'cat2',
            name: 'Salary',
            usage: CategoryUsage.income,
            iconCode: 57565,
            tag: CategoryTag.none),
      ];

  @override
  Future<void> addCategory(Category c) async {
    final storage = ref.read(storageServiceProvider);
    await storage.addCategory(c);
    state = [...state, c];
  }

  @override
  Future<void> removeCategory(String id) async {
    final storage = ref.read(storageServiceProvider);
    await storage.removeCategory(id);
    state = state.where((c) => c.id != id).toList();
  }

  @override
  Future<void> updateCategory(String id,
      {required String name,
      required CategoryUsage usage,
      required CategoryTag tag,
      required int iconCode}) async {
    final storage = ref.read(storageServiceProvider);
    await storage.updateCategory(id,
        name: name, usage: usage, tag: tag, iconCode: iconCode);
    state = [
      for (final c in state)
        if (c.id == id)
          Category(
              id: id,
              name: name,
              usage: usage,
              tag: tag,
              iconCode: iconCode,
              profileId: c.profileId)
        else
          c
    ];
  }
}

class MockProfileNotifier extends ProfileNotifier {
  final String? initialValue;
  MockProfileNotifier([this.initialValue]);

  @override
  String build() => initialValue ?? 'default';

  @override
  Future<void> setProfile(String id) async {
    state = id;
  }
}

class MockCurrencyNotifier extends CurrencyNotifier {
  final String initialValue;
  MockCurrencyNotifier([this.initialValue = 'en_IN']);
  @override
  String build() => initialValue;
}

class MockSmartCalcNotifier extends SmartCalculatorEnabledNotifier {
  final bool initialValue;
  MockSmartCalcNotifier([this.initialValue = true]);
  @override
  bool build() => initialValue;
}

class MockBackupThresholdNotifier extends BackupThresholdNotifier {
  final int initialValue;
  MockBackupThresholdNotifier([this.initialValue = 20]);
  @override
  int build() => initialValue;
}

class MockHolidaysNotifier extends HolidaysNotifier {
  final List<DateTime> initialValue;
  MockHolidaysNotifier([this.initialValue = const []]);
  @override
  List<DateTime> build() => initialValue;

  @override
  Future<void> addHoliday(DateTime date) async {
    state = [...state, date];
  }

  @override
  Future<void> removeHoliday(DateTime date) async {
    state = state.where((d) => d != date).toList();
  }
}

void registerFallbackValues() {
  registerFallbackValue(Category(
      id: 'fallback',
      name: 'fallback',
      usage: CategoryUsage.expense,
      iconCode: 0,
      tag: CategoryTag.none));
  registerFallbackValue(Loan(
    id: 'f',
    name: 'f',
    totalPrincipal: 0,
    remainingPrincipal: 0,
    interestRate: 0,
    tenureMonths: 0,
    startDate: DateTime(2000),
    emiAmount: 0,
    firstEmiDate: DateTime(2000),
  ));
  registerFallbackValue(Account(
    id: 'f',
    name: 'f',
    type: AccountType.wallet,
    balance: 0,
  ));
  registerFallbackValue(Transaction(
    id: 'f',
    title: 'f',
    amount: 0,
    category: 'f',
    date: DateTime(2000),
    type: TransactionType.expense,
  ));
  registerFallbackValue(CategoryUsage.expense);
  registerFallbackValue(CategoryTag.none);
  registerFallbackValue(Profile(id: 'fallback', name: 'fallback'));
}

class MockActiveProfileIdNotifier extends ProfileNotifier {
  final String initialValue;
  MockActiveProfileIdNotifier([this.initialValue = 'default']);
  @override
  String build() => initialValue;
  @override
  Future<void> setProfile(String id) async {
    state = id;
  }
}
