import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/services/excel_service.dart';
import 'package:samriddhi_flow/services/storage_service.dart';
import 'package:samriddhi_flow/services/file_service.dart';
import 'package:samriddhi_flow/models/profile.dart';

class MockStorageService extends Mock implements StorageService {}

class MockFileService extends Mock implements FileService {}

void main() {
  late MockStorageService mockStorageService;
  late MockFileService mockFileService;
  late ExcelService excelService;

  setUpAll(() {
    registerFallbackValue(Profile(id: 'dummy', name: 'dummy'));
  });

  setUp(() {
    mockStorageService = MockStorageService();
    mockFileService = MockFileService();
    excelService = ExcelService(mockStorageService, mockFileService);

    // Default Stubs
    when(() => mockStorageService.getProfiles()).thenReturn([]);
    when(() => mockStorageService.getAccounts()).thenReturn([]);
    when(() => mockStorageService.getLoans()).thenReturn([]);
    when(() => mockStorageService.getCategories()).thenReturn([]);
    when(() => mockStorageService.getTransactions()).thenReturn([]);
    when(() => mockStorageService.getAllAccounts()).thenReturn([]);
  });

  test('exportData produces valid excel file bytes', () async {
    final bytes = await excelService.exportData();
    expect(bytes, isNotEmpty);

    final excel = Excel.decodeBytes(bytes);
    expect(excel.tables.keys, contains('Accounts'));
    expect(excel.tables.keys, contains('Transactions'));
  });

  test('importData parses valid excel file', () async {
    // Create a sample excel
    final excel = Excel.createExcel();
    final sheet = excel['Profiles'];
    sheet.appendRow([TextCellValue('ID'), TextCellValue('Name')]);
    sheet.appendRow([TextCellValue('p1'), TextCellValue('Test Profile')]);

    final bytes = excel.encode()!;

    when(() => mockStorageService.getActiveProfileId()).thenReturn('default');
    when(() => mockStorageService.saveProfile(any())).thenAnswer((_) async {});
    when(() => mockFileService.pickFile(allowedExtensions: ['xlsx']))
        .thenAnswer((_) async => Uint8List.fromList(bytes));

    final result = await excelService.importData(fileBytes: bytes);

    // Verify parsing
    // Logic: if Profiles sheet exists, it parses it.
    verify(() => mockStorageService.saveProfile(any())).called(1);
    expect(result['profiles'], 1);
  });
}
