import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:excel/excel.dart';
import 'package:samriddhi_flow/services/excel_service.dart';
import 'package:samriddhi_flow/services/storage_service.dart';
import 'package:samriddhi_flow/services/file_service.dart';
import 'package:samriddhi_flow/models/account.dart';
import 'package:samriddhi_flow/models/transaction.dart';
import 'package:samriddhi_flow/models/profile.dart';
import 'package:samriddhi_flow/models/category.dart';
import 'package:samriddhi_flow/models/loan.dart';

class MockStorageService extends Mock implements StorageService {}

class MockFileService extends Mock implements FileService {}

class AccountFake extends Fake implements Account {}

class TransactionFake extends Fake implements Transaction {}

class LoanFake extends Fake implements Loan {}

class CategoryFake extends Fake implements Category {}

class ProfileFake extends Fake implements Profile {}

void main() {
  setUpAll(() {
    registerFallbackValue(AccountFake());
    registerFallbackValue(TransactionFake());
    registerFallbackValue(LoanFake());
    registerFallbackValue(CategoryFake());
    registerFallbackValue(ProfileFake());
  });

  late ExcelService excelService;
  late MockStorageService mockStorage;
  late MockFileService mockFileService;

  setUp(() {
    mockStorage = MockStorageService();
    mockFileService = MockFileService();
    excelService = ExcelService(mockStorage, mockFileService);

    when(() => mockStorage.getActiveProfileId()).thenReturn('p1');
    when(() => mockStorage.getProfiles()).thenReturn([]);
    when(() => mockStorage.getAccounts()).thenReturn([]);
    when(() => mockStorage.getLoans()).thenReturn([]);
    when(() => mockStorage.getCategories()).thenReturn([]);
    when(() => mockStorage.getTransactions()).thenReturn([]);
    when(() => mockStorage.getTxnsSinceBackup()).thenReturn(0);
    when(() => mockStorage.getAllAccounts()).thenReturn([]);
    when(() => mockStorage.getAllLoans()).thenReturn([]);
    when(() => mockStorage.getAllCategories()).thenReturn([]);
    when(() => mockStorage.getAllTransactions()).thenReturn([]);

    when(() => mockStorage.saveAccount(any())).thenAnswer((_) async {});
    when(() => mockStorage.saveTransaction(any()))
        .thenAnswer((_) async {});
    when(() => mockStorage.saveTransactions(any(),
        applyImpact: any(named: 'applyImpact'))).thenAnswer((_) async {});
    when(() => mockStorage.saveLoan(any())).thenAnswer((_) async {});
    when(() => mockStorage.addCategory(any())).thenAnswer((_) async {});
    when(() => mockStorage.saveProfile(any())).thenAnswer((_) async {});
  });

  group('ExcelService - Coverage Mastery (Final Completion)', () {
    test('exportData - Comprehensive All-Profile Export', () async {
      final p1 = Profile(id: 'p1', name: 'P1');
      final a1 = Account(
          id: 'a1',
          name: 'A1',
          type: AccountType.savings,
          balance: 500,
          profileId: 'p1',
          creditLimit: 1000,
          billingCycleDay: 1,
          paymentDueDateDay: 20);
      final l1 = Loan(
          id: 'l1',
          name: 'L1',
          totalPrincipal: 1000,
          remainingPrincipal: 900,
          interestRate: 12,
          tenureMonths: 24,
          startDate: DateTime(2024, 1, 1),
          emiAmount: 50,
          emiDay: 1,
          firstEmiDate: DateTime(2024, 2, 1),
          profileId: 'p1');
      l1.transactions = [
        LoanTransaction(
            id: 'lt1',
            date: DateTime(2024, 2, 1),
            amount: 50,
            type: LoanTransactionType.emi,
            principalComponent: 40,
            interestComponent: 10,
            resultantPrincipal: 960)
      ];
      final c1 = Category(
          id: 'c1',
          name: 'C1',
          usage: CategoryUsage.expense,
          tag: CategoryTag.none,
          iconCode: 1,
          profileId: 'p1');
      final t1 = Transaction(
          id: 't1',
          title: 'T1',
          amount: 100,
          date: DateTime(2024, 1, 1),
          type: TransactionType.expense,
          accountId: 'a1',
          profileId: 'p1',
          category: 'C1',
          toAccountId: 'a2');

      when(() => mockStorage.getProfiles()).thenReturn([p1]);
      when(() => mockStorage.getAllAccounts()).thenReturn([a1]);
      when(() => mockStorage.getAllLoans()).thenReturn([l1]);
      when(() => mockStorage.getAllCategories()).thenReturn([c1]);
      when(() => mockStorage.getAllTransactions()).thenReturn([t1]);

      final bytes = await excelService.exportData(allProfiles: true);
      expect(bytes, isNotEmpty);
    });

    test('importData - Full Spectrum Parsing & Catch Blocks', () async {
      final excel = Excel.createExcel();

      // 1. Profiles (Catching budgetIdx == -1)
      final pSheet = excel['Profiles'];
      pSheet.appendRow([TextCellValue('ID'), TextCellValue('Name')]);
      pSheet.appendRow([TextCellValue('p-new'), TextCellValue('New Profile')]);

      // 2. Accounts (Fallback to manual ID and savings type)
      final aSheet = excel['Accounts'];
      aSheet.appendRow([TextCellValue('Name'), TextCellValue('Balance')]);
      aSheet.appendRow([TextCellValue('New Account'), const DoubleCellValue(100.5)]);

      // 3. Loans (Fallback to personal type)
      final lSheet = excel['Loans'];
      lSheet.appendRow([TextCellValue('Name'), TextCellValue('Principal')]);
      lSheet.appendRow([TextCellValue('New Loan'), const DoubleCellValue(5000)]);

      // 4. Categories (Fallback to both usage)
      final cSheet = excel['Categories'];
      cSheet.appendRow([TextCellValue('Name')]);
      cSheet.appendRow([TextCellValue('New Cat')]);

      // 5. Transactions (Account Resolution and Transfer Fallbacks)
      final tSheet = excel['Transactions'];
      tSheet.appendRow([
        TextCellValue('Title'),
        TextCellValue('Amount'),
        TextCellValue('Account Name'),
        TextCellValue('Type')
      ]);

      // Case 1: Existing account name resolution
      final a1 = Account(
          id: 'a1',
          name: 'Match',
          type: AccountType.savings,
          balance: 0,
          profileId: 'p1');
      when(() => mockStorage.getAccounts()).thenReturn([a1]);
      tSheet.appendRow([
        TextCellValue('Self'),
        const DoubleCellValue(100),
        TextCellValue('Match'),
        TextCellValue('transfer')
      ]);

      // Case 2: New account creation from txn name
      tSheet.appendRow([
        TextCellValue('Auto Acc'),
        const DoubleCellValue(50),
        TextCellValue('Brand New'),
        TextCellValue('income')
      ]);

      // 6. Loan Transactions
      final ltSheet = excel['Loan Transactions'];
      ltSheet.appendRow([TextCellValue('Loan ID'), TextCellValue('Amount')]);
      ltSheet.appendRow([TextCellValue('l-new'), const DoubleCellValue(250)]);

      excel.delete('Sheet1');

      final result = await excelService.importData(fileBytes: excel.encode()!);
      expect(result['status'], 1);
    });

    test('importData - Negative / Decode Paths', () async {
      when(() => mockFileService.pickFile(
              allowedExtensions: any(named: 'allowedExtensions')))
          .thenAnswer((_) async => null);
      expect((await excelService.importData())['status'], -1);

      final emptyExcel = Excel.createExcel();
      expect(
          (await excelService.importData(
              fileBytes: emptyExcel.encode()!))['status'],
          -3);

      final badBytes = Uint8List.fromList([0x50, 0x4B, 0x07, 0x08]);
      expect(
          (await excelService.importData(fileBytes: badBytes))['status'], -4);
    });
  });
}
