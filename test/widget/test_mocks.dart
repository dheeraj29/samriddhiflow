import 'package:samriddhi_flow/models/account.dart';
import 'package:samriddhi_flow/models/category.dart';
import 'package:samriddhi_flow/services/file_service.dart';
import 'package:samriddhi_flow/services/excel_service.dart';
import 'package:samriddhi_flow/models/loan.dart';
import 'package:samriddhi_flow/models/profile.dart';
import 'package:samriddhi_flow/models/recurring_transaction.dart';
import 'package:samriddhi_flow/models/transaction.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/services/notification_service.dart';
import 'package:samriddhi_flow/services/storage_service.dart';

class MockIsOfflineNotifier extends IsOfflineNotifier {
  @override
  bool build() => false;
}

class MockBudgetNotifier extends BudgetNotifier {
  @override
  double build() => 50000;
}

class MockStorageService extends StorageService {
  @override
  String getCurrencyLocale() => 'en_IN';
  @override
  double getMonthlyBudget() => 50000;
  @override
  bool isAppLockEnabled() => false;
  @override
  String? getAppPin() => null;
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
  String getActiveProfileId() => 'default';
  @override
  List<Profile> getProfiles() => [Profile(id: 'default', name: 'User')];
  @override
  List<Account> getAccounts() => [
        Account(
            id: 'acc1', name: 'Cash', type: AccountType.wallet, balance: 1000),
        Account(
            id: 'acc2',
            name: 'Bank',
            type: AccountType.savings,
            balance: 50000),
      ];
  @override
  List<Transaction> getTransactions() => [];
  @override
  List<Loan> getLoans() => [];
  @override
  List<RecurringTransaction> getRecurring() => [];
  @override
  bool getAuthFlag() => true;
  @override
  Future<List<int>> exportData() async => [];
  @override
  Future<void> init() async {}
  @override
  bool isSmartCalculatorEnabled() => true;
  @override
  String getThemeMode() => 'system';
  @override
  Future<void> resetTxnsSinceBackup() async {}
}

class MockNotificationService extends NotificationService {
  MockNotificationService() : super(MockStorageService());

  @override
  Future<void> init() async {}
  @override
  Future<List<String>> checkNudges() async => [];
}

class MockCategoriesNotifier extends CategoriesNotifier {
  @override
  List<Category> build() {
    return [
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
}

class MockProfileNotifier extends ProfileNotifier {
  @override
  String build() => 'default';
}

class MockFileService extends FileService {
  @override
  Future<String?> saveFile(String fileName, List<int> bytes) async =>
      'Mock Path';
}

class MockExcelService extends ExcelService {
  MockExcelService() : super(MockStorageService(), MockFileService());
  @override
  Future<List<int>> exportData({bool allProfiles = false}) async => [];
  @override
  Future<Map<String, int>> importData(
      {List<int>? fileBytes, bool allProfiles = false}) async {
    return {'status': 1};
  }
}
