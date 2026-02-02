import 'package:flutter_test/flutter_test.dart';
import 'package:excel/excel.dart';
import 'package:samriddhi_flow/models/transaction.dart';
import 'package:samriddhi_flow/services/excel_service.dart';
import 'package:samriddhi_flow/services/storage_service.dart';
import 'package:samriddhi_flow/services/file_service.dart';
import 'package:samriddhi_flow/models/account.dart';
import 'package:samriddhi_flow/models/category.dart';
import 'package:samriddhi_flow/models/profile.dart';
import 'package:samriddhi_flow/models/loan.dart';

// Simple manual mocks for unit testing to avoid Hive dependency
class LocalMockStorage extends StorageService {
  final List<Transaction> savedTransactions = [];
  final List<Account> accounts = [
    Account(id: 'acc1', name: 'Cash', type: AccountType.savings, balance: 100),
  ];
  final List<Category> categories = [];
  final List<Loan> loans = [];
  final List<Profile> profiles = [Profile(id: 'default', name: 'User')];

  @override
  List<Account> getAccounts() => accounts;
  @override
  List<Account> getAllAccounts() => accounts;
  @override
  List<Profile> getProfiles() => profiles;
  @override
  String getActiveProfileId() => 'default';

  @override
  Future<void> saveProfile(Profile profile) async {
    profiles.add(profile);
  }

  @override
  Future<void> saveAccount(Account account) async {
    accounts.add(account);
  }

  @override
  List<Loan> getLoans() => loans;
  @override
  Future<void> saveLoan(Loan loan) async {
    loans.add(loan);
  }

  @override
  List<Category> getCategories() => categories;
  @override
  Future<void> addCategory(Category category) async {
    categories.add(category);
  }

  @override
  Future<void> saveTransactions(List<Transaction> txns,
      {bool applyImpact = true, DateTime? now}) async {
    savedTransactions.addAll(txns);
  }

  // Stubs for other methods to prevent Hive access
  @override
  Future<void> init() async {}
}

class LocalMockFileService extends FileService {}

void main() {
  late ExcelService excelService;
  late LocalMockStorage mockStorage;
  late LocalMockFileService mockFileService;

  setUp(() {
    mockStorage = LocalMockStorage();
    mockFileService = LocalMockFileService();
    excelService = ExcelService(mockStorage, mockFileService);
  });

  group('ExcelService Import Tests', () {
    test('Import basic transaction row', () async {
      final excel = Excel.createExcel();
      final Sheet sheet = excel['Transactions'];

      // Header
      sheet.appendRow([
        TextCellValue('Title'),
        TextCellValue('Amount'),
        TextCellValue('Category'),
        TextCellValue('Account Name'),
        TextCellValue('Type'),
        TextCellValue('Date'),
      ]);

      // Data Row
      sheet.appendRow([
        TextCellValue('Test Item'),
        const DoubleCellValue(150.5),
        TextCellValue('Dining'),
        TextCellValue('Cash'), // Matches acc1 name
        TextCellValue('expense'),
        TextCellValue(DateTime.now().toIso8601String()),
      ]);

      final bytes = excel.encode()!;
      final result = await excelService.importData(fileBytes: bytes);

      expect(result['status'], 1);
      expect(result['transactions'], 1);
      expect(mockStorage.savedTransactions.length, 1);
      expect(mockStorage.savedTransactions.first.title, 'Test Item');
      expect(mockStorage.savedTransactions.first.amount, 150.5);
      expect(mockStorage.savedTransactions.first.accountId, 'acc1');
    });

    test('Import creates new account if name doesnt match', () async {
      final excel = Excel.createExcel();
      final Sheet sheet = excel['Transactions'];

      sheet.appendRow([
        TextCellValue('Title'),
        TextCellValue('Amount'),
        TextCellValue('Account Name'),
      ]);

      sheet.appendRow([
        TextCellValue('New Acc Item'),
        const DoubleCellValue(10.0),
        TextCellValue('New Bank'),
      ]);

      final bytes = excel.encode()!;
      final result = await excelService.importData(fileBytes: bytes);

      expect(result['transactions'], 1);
      expect(mockStorage.accounts.any((a) => a.name == 'New Bank'), true);
      final newAccId =
          mockStorage.accounts.firstWhere((a) => a.name == 'New Bank').id;
      expect(mockStorage.savedTransactions.first.accountId, newAccId);
    });
  });
}
