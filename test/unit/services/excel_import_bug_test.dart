import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:excel/excel.dart';
import 'package:samriddhi_flow/services/excel_service.dart';
import 'package:samriddhi_flow/services/storage_service.dart';
import 'package:samriddhi_flow/services/file_service.dart';
import 'package:samriddhi_flow/models/account.dart';
import 'package:samriddhi_flow/models/transaction.dart';
import 'package:samriddhi_flow/models/profile.dart';

class MockStorageService extends Mock implements StorageService {}

class MockFileService extends Mock implements FileService {}

class AccountFake extends Fake implements Account {}

class TransactionFake extends Fake implements Transaction {}

class ProfileFake extends Fake implements Profile {}

void main() {
  setUpAll(() {
    registerFallbackValue(AccountFake());
    registerFallbackValue(TransactionFake());
    registerFallbackValue(ProfileFake());
  });

  late ExcelService excelService;
  late MockStorageService mockStorage;
  late MockFileService mockFileService;

  setUp(() {
    mockStorage = MockStorageService();
    mockFileService = MockFileService();
    excelService = ExcelService(mockStorage, mockFileService);

    when(() => mockStorage.getActiveProfileId()).thenReturn('default');
    when(() => mockStorage.getProfiles()).thenReturn([]);
    // Setup an existing account so we can prove it DOESN'T get used
    final existingAccount = Account(
        id: 'acc-1',
        name: 'Existing Savings',
        type: AccountType.savings,
        balance: 1000,
        profileId: 'default');
    when(() => mockStorage.getAccounts()).thenReturn([existingAccount]);
    when(() => mockStorage.getAllAccounts()).thenReturn([existingAccount]);

    when(() => mockStorage.saveTransactions(any(),
        applyImpact: any(named: 'applyImpact'))).thenAnswer((_) async {});
    when(() => mockStorage.saveAccount(any())).thenAnswer((_) async {});
  });

  test(
      'importData - Should preserve NULL accountId for Empty/Manual account fields',
      () async {
    final excel = Excel.createExcel();
    final sheet = excel['Transactions'];

    // Headers
    sheet.appendRow([
      TextCellValue('Title'),
      TextCellValue('Amount'),
      TextCellValue('Date'),
      TextCellValue('Type'),
      TextCellValue('Account Name'), // Empty
      TextCellValue('Account ID'), // Empty or Manual
    ]);

    // Row 1: Completely Empty Account fields
    sheet.appendRow([
      TextCellValue('Txn No Account'),
      const DoubleCellValue(100.0),
      TextCellValue('2024-01-01'),
      TextCellValue('expense'),
      TextCellValue(''), // details
      TextCellValue(''), // id
    ]);

    // Row 2: "Manual" Account ID
    sheet.appendRow([
      TextCellValue('Txn Manual Account'),
      const DoubleCellValue(200.0),
      TextCellValue('2024-01-02'),
      TextCellValue('expense'),
      TextCellValue('Manual'), // details
      TextCellValue('Manual'), // id
    ]);

    excel.delete('Sheet1');

    await excelService.importData(fileBytes: excel.encode()!);

    // Verify
    final captured = verify(() => mockStorage.saveTransactions(captureAny(),
        applyImpact: any(named: 'applyImpact'))).captured;
    final savedTxns = captured.first as List<Transaction>;

    expect(savedTxns.length, 2);

    final t1 = savedTxns.firstWhere((t) => t.title == 'Txn No Account');
    expect(t1.accountId, isNull,
        reason: 'Empty Account ID should result in null');

    final t2 = savedTxns.firstWhere((t) => t.title == 'Txn Manual Account');
    expect(t2.accountId, isNull,
        reason: '"Manual" Account ID should result in null');
  });
}
