import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/models/account.dart';
import 'package:samriddhi_flow/models/category.dart';
import 'package:samriddhi_flow/models/loan.dart';
import 'package:samriddhi_flow/models/profile.dart';
import 'package:samriddhi_flow/models/recurring_transaction.dart';
import 'package:samriddhi_flow/models/transaction.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/services/auth_service.dart';
import 'package:samriddhi_flow/services/excel_service.dart';
import 'package:samriddhi_flow/services/file_service.dart';
import 'package:samriddhi_flow/services/notification_service.dart';
import 'package:samriddhi_flow/services/storage_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

// --- Service Mocks (Mocktail) ---
class MockFileService extends Mock implements FileService {}

class MockExcelService extends Mock implements ExcelService {
  @override
  Future<List<int>> exportData({bool allProfiles = false}) async => [];
}

class MockAuthService extends Mock implements AuthService {}

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

class MockNotificationService extends Mock implements NotificationService {
  @override
  Future<void> init() async {}

  @override
  Future<List<String>> checkNudges() async => [];
}

// --- Manual Mock Storage ---
class MockStorageService extends StorageService implements Mock {
  bool _isLockEnabled = false;
  String? _appPin = '1111';
  final String _activeProfileId = 'default';
  bool saveAccountCalled = false;

  // Test Helpers
  void setLocked(bool val) => _isLockEnabled = val;
  void setPin(String? val) => _appPin = val;

  @override
  bool isAppLockEnabled() => _isLockEnabled;
  @override
  String? getAppPin() => _appPin;

  @override
  String getActiveProfileId() => _activeProfileId;
  @override
  String getCurrencyLocale() => 'en_IN';
  @override
  double getMonthlyBudget() => 50000;
  @override
  int getBackupThreshold() => 20;
  @override
  int getTxnsSinceBackup() => 0;
  @override
  List<DateTime> getHolidays() => [];
  @override
  List<Category> getCategories() => [
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
  List<Profile> getProfiles() => [Profile(id: 'default', name: 'User')];
  @override
  List<Account> getAccounts() => [
        Account(
            id: 'acc1', name: 'Cash', type: AccountType.wallet, balance: 1000),
      ];
  @override
  List<Transaction> getTransactions() => [];
  @override
  List<Transaction> getDeletedTransactions() => [];
  @override
  Future<void> restoreTransaction(String id) async {}
  @override
  Future<void> permanentlyDeleteTransaction(String id) async {}
  @override
  Future<void> saveLoan(Loan l) async {}

  @override
  List<Loan> getLoans() => [];
  @override
  List<RecurringTransaction> getRecurring() => [];
  @override
  bool getAuthFlag() => true;
  @override
  Future<List<int>> exportData({bool allProfiles = false}) async => [];
  @override
  Future<void> init() async {}
  @override
  bool isSmartCalculatorEnabled() => true;
  @override
  String getThemeMode() => 'system';
  @override
  Future<void> resetTxnsSinceBackup() async {}
  @override
  DateTime? getLastLogin() => null;
  @override
  Future<void> setLastLogin(DateTime date) async {}
  @override
  int getInactivityThresholdDays() => 30;
  @override
  int getMaturityWarningDays() => 7;
  @override
  Future<void> checkCreditCardRollovers({DateTime? nowOverride}) async {}
  @override
  Future<void> saveAccount(Account account) async {
    saveAccountCalled = true;
  }

  @override
  Stream<List<Account>> watchAccounts() => Stream.value(getAccounts());
  @override
  Stream<List<Transaction>> watchTransactions() => Stream.value([]);
}

// --- Notifier Mocks ---
class MockIsOfflineNotifier extends IsOfflineNotifier {
  @override
  bool build() => false;
}

class MockBudgetNotifier extends BudgetNotifier {
  @override
  double build() => 50000;
  @override
  Future<void> setBudget(double amount) async {
    state = amount;
  }
}

class MockCategoriesNotifier extends CategoriesNotifier {
  @override
  List<Category> build() => [
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
}

class MockProfileNotifier extends ProfileNotifier {
  @override
  String build() => 'default';
}

void registerFallbackValues() {
  registerFallbackValue(Category(
      id: 'fallback',
      name: 'fallback',
      usage: CategoryUsage.expense,
      iconCode: 0,
      tag: CategoryTag.none));
}
