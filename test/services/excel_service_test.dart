import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/models/account.dart';
import 'package:samriddhi_flow/models/category.dart';
import 'package:samriddhi_flow/models/loan.dart';
import 'package:samriddhi_flow/models/profile.dart';
import 'package:samriddhi_flow/models/transaction.dart';
import 'package:samriddhi_flow/services/excel_service.dart';
import 'package:samriddhi_flow/services/file_service.dart';
import 'package:samriddhi_flow/services/storage_service.dart';

class MockStorageService extends Mock implements StorageService {}

class MockFileService extends Mock implements FileService {}

// Fake Models
class FakeAccount extends Fake implements Account {}

class FakeProfile extends Fake implements Profile {}

class FakeTransaction extends Fake implements Transaction {}

class FakeCategory extends Fake implements Category {}

class FakeLoan extends Fake implements Loan {}

void main() {
  late MockStorageService mockStorage;
  late MockFileService mockFileService;
  late ExcelService excelService;

  setUpAll(() {
    registerFallbackValue(Account.create(
        name: 'Fake', type: AccountType.savings, profileId: 'default'));
    registerFallbackValue(Profile(id: 'fake', name: 'Fake'));
    registerFallbackValue(Transaction.create(
        title: 'Fake',
        amount: 0,
        date: DateTime.now(),
        type: TransactionType.expense,
        accountId: 'fake',
        profileId: 'default',
        category: 'fake'));
    registerFallbackValue(Category.create(
        name: 'Fake', usage: CategoryUsage.expense, profileId: 'default'));
    registerFallbackValue(Loan.create(
        name: 'Fake',
        principal: 0,
        rate: 0,
        tenureMonths: 0,
        startDate: DateTime.now(),
        emiAmount: 0,
        emiDay: 1,
        firstEmiDate: DateTime.now(),
        profileId: 'default'));
  });

  setUp(() {
    mockStorage = MockStorageService();
    mockFileService = MockFileService();
    excelService = ExcelService(mockStorage, mockFileService);

    // Default Stubs
    when(() => mockStorage.getProfiles()).thenReturn([]);
    when(() => mockStorage.getAccounts()).thenReturn([]);
    when(() => mockStorage.getLoans()).thenReturn([]);
    when(() => mockStorage.getCategories()).thenReturn([]);
    when(() => mockStorage.getTransactions()).thenReturn([]);
    when(() => mockStorage.getAllAccounts()).thenReturn([]);
    when(() => mockStorage.getAllCategories()).thenReturn([]);
    when(() => mockStorage.getAllLoans()).thenReturn([]);
    when(() => mockStorage.getAllTransactions()).thenReturn([]);
    when(() => mockStorage.getActiveProfileId()).thenReturn('default');

    when(() => mockStorage.saveAccount(any())).thenAnswer((_) async {});
    when(() => mockStorage.saveTransaction(any())).thenAnswer((_) async {});
    when(() => mockStorage.saveTransactions(any(),
        applyImpact: any(named: 'applyImpact'))).thenAnswer((_) async {});
    when(() => mockStorage.saveLoan(any())).thenAnswer((_) async => {});
    when(() => mockStorage.addCategory(any())).thenAnswer((_) async => {});
    when(() => mockStorage.saveProfile(any())).thenAnswer((_) async => {});
    when(() => mockFileService.pickFile(
            allowedExtensions: any(named: 'allowedExtensions')))
        .thenAnswer((_) async => null);
  });

  group('ExcelService Tests', () {
    test('Export Data - Generates Valid Excel', () async {
      when(() => mockStorage.getProfiles())
          .thenReturn([Profile(id: 'p1', name: 'Test Profile')]);
      when(() => mockStorage.getAccounts()).thenReturn([
        Account(
            id: 'a1',
            name: 'Bank',
            type: AccountType.savings,
            balance: 1000,
            profileId: 'p1')
      ]);

      final bytes = await excelService.exportData(allProfiles: false);

      expect(bytes, isNotEmpty);
      final excel = Excel.decodeBytes(bytes);
      expect(excel.tables.keys, contains('Accounts'));
      expect(excel.tables['Accounts']!.rows.length,
          greaterThan(1)); // Header + 1 Row
    });

    test('Import Data - Auto-Creates Account', () async {
      final excel = Excel.createExcel();
      final sheet = excel['Transactions'];
      sheet.appendRow([
        TextCellValue('Title'),
        TextCellValue('Amount'),
        TextCellValue('Date'),
        TextCellValue('Account Name')
      ]);
      sheet.appendRow([
        TextCellValue('Salary'),
        const IntCellValue(50000),
        TextCellValue('2024-01-01'),
        TextCellValue('New Bank') // Should trigger account creation
      ]);
      final bytes = excel.save();

      when(() => mockFileService.pickFile(
              allowedExtensions: any(named: 'allowedExtensions')))
          .thenAnswer(
              (_) async => bytes != null ? Uint8List.fromList(bytes) : null);

      await excelService.importData(fileBytes: bytes);

      verify(() => mockStorage.saveAccount(any(
              that: isA<Account>().having((a) => a.name, 'name', 'New Bank'))))
          .called(1);
    });

    test('Import Data - Skips Self Transfer', () async {
      when(() => mockStorage.getAccounts()).thenReturn([
        Account(
            id: 'a1',
            name: 'Bank',
            type: AccountType.savings,
            profileId: 'default')
      ]);
      when(() => mockStorage.getAllAccounts()).thenReturn([
        Account(
            id: 'a1',
            name: 'Bank',
            type: AccountType.savings,
            profileId: 'default')
      ]);

      final excel = Excel.createExcel();
      final sheet = excel['Transactions'];
      sheet.appendRow([
        TextCellValue('Title'),
        TextCellValue('Amount'),
        TextCellValue('Type'),
        TextCellValue('Account ID'),
        TextCellValue('To Account ID')
      ]);
      sheet.appendRow([
        TextCellValue('Self Xfer'),
        const IntCellValue(100),
        TextCellValue('transfer'),
        TextCellValue('a1'),
        TextCellValue('a1')
      ]);
      final bytes = excel.save();

      final result = await excelService.importData(fileBytes: bytes);

      expect(result['skipped_selftransfer'], 1);
      // verify no transaction saved?
      // saveTransactions is called with list. List should be empty.
      verify(() => mockStorage.saveTransactions(any(that: isEmpty),
          applyImpact: any(named: 'applyImpact'))).called(1);
    });

    test('Import Data - Handles Invalid File', () async {
      // Pass random bytes
      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      final result = await excelService.importData(fileBytes: bytes);
      expect(result['status'], -4);
    });
  });
}
