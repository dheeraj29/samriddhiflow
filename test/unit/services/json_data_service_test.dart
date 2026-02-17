import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:archive/archive.dart';
import 'package:samriddhi_flow/services/json_data_service.dart';
import 'package:samriddhi_flow/services/storage_service.dart';
import 'package:samriddhi_flow/services/taxes/tax_config_service.dart';
import 'package:samriddhi_flow/models/account.dart';
import 'package:samriddhi_flow/models/transaction.dart';
import 'package:samriddhi_flow/models/loan.dart';
import 'package:samriddhi_flow/models/recurring_transaction.dart';
import 'package:samriddhi_flow/models/category.dart';
import 'package:samriddhi_flow/models/profile.dart';
import 'package:samriddhi_flow/models/taxes/insurance_policy.dart';
import 'package:samriddhi_flow/models/taxes/tax_data.dart';
import 'package:samriddhi_flow/models/lending_record.dart';

class MockStorageService extends Mock implements StorageService {}

class MockTaxConfigService extends Mock implements TaxConfigService {}

void main() {
  late JsonDataService jsonDataService;
  late MockStorageService mockStorageService;
  late MockTaxConfigService mockTaxConfigService;

  setUp(() {
    mockStorageService = MockStorageService();
    mockTaxConfigService = MockTaxConfigService();
    jsonDataService = JsonDataService(mockStorageService, mockTaxConfigService);

    registerFallbackValue(
        Account(id: 'a', name: 'a', type: AccountType.savings, balance: 0));
    registerFallbackValue(Transaction(
        id: 't',
        title: 't',
        amount: 0,
        date: DateTime.now(),
        type: TransactionType.expense,
        category: 'c'));
    registerFallbackValue(Loan(
        id: 'l',
        name: 'l',
        totalPrincipal: 0,
        remainingPrincipal: 0,
        interestRate: 0,
        tenureMonths: 0,
        startDate: DateTime.now(),
        emiAmount: 0,
        firstEmiDate: DateTime.now()));
    registerFallbackValue(RecurringTransaction(
        id: 'r',
        title: 'r',
        amount: 0,
        type: TransactionType.expense,
        category: 'c',
        frequency: Frequency.monthly,
        nextExecutionDate: DateTime.now()));
    registerFallbackValue(Category(
        id: 'c',
        name: 'c',
        usage: CategoryUsage.expense,
        iconCode: 0,
        tag: CategoryTag.none));
    registerFallbackValue(Profile(id: 'p', name: 'p'));
    registerFallbackValue(InsurancePolicy(
        id: 'i',
        policyName: 'i',
        policyNumber: 'pn',
        annualPremium: 0,
        sumAssured: 0,
        startDate: DateTime.now(),
        maturityDate: DateTime.now()));
    registerFallbackValue(TaxYearData(year: 2024));
    registerFallbackValue(LendingRecord(
        id: 'lr',
        personName: 'n',
        amount: 0,
        reason: 'r',
        date: DateTime.now(),
        type: LendingType.lent));
  });

  test('createBackupPackage collects all data and returns a ZIP', () async {
    // Setup
    when(() => mockStorageService.getAllAccounts()).thenReturn([]);
    when(() => mockStorageService.getAllTransactions()).thenReturn([]);
    when(() => mockStorageService.getAllLoans()).thenReturn([]);
    when(() => mockStorageService.getAllRecurring()).thenReturn([]);
    when(() => mockStorageService.getAllCategories()).thenReturn([]);
    when(() => mockStorageService.getProfiles()).thenReturn([]);
    when(() => mockStorageService.getAllSettings()).thenReturn({});
    when(() => mockStorageService.getInsurancePolicies()).thenReturn([]);
    when(() => mockTaxConfigService.getAllRules()).thenReturn({});
    when(() => mockStorageService.getAllTaxYearData()).thenReturn([]);
    when(() => mockStorageService.getLendingRecords()).thenReturn([]);

    // Run
    final zipBytes = await jsonDataService.createBackupPackage();

    // Verify
    expect(zipBytes, isNotEmpty);
    final archive = ZipDecoder().decodeBytes(zipBytes);
    expect(archive.findFile('metadata.json'), isNotNull);
    expect(archive.findFile('accounts.json'), isNotNull);
    expect(archive.findFile('transactions.json'), isNotNull);
    expect(archive.findFile('loans.json'), isNotNull);
    expect(archive.findFile('recurring.json'), isNotNull);
    expect(archive.findFile('categories.json'), isNotNull);
    expect(archive.findFile('profiles.json'), isNotNull);
    expect(archive.findFile('settings.json'), isNotNull);
    expect(archive.findFile('insurance_policies.json'), isNotNull);
    expect(archive.findFile('tax_rules.json'), isNotNull);
    expect(archive.findFile('tax_data.json'), isNotNull);
    expect(archive.findFile('lending_records.json'), isNotNull);
  });

  test('restoreFromPackage clears and restores data', () async {
    // Setup
    final archive = Archive();
    void add(String name, dynamic content) {
      final bytes = utf8.encode(jsonEncode(content));
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    }

    add('metadata.json', {'version': '1.0.0'});
    add('profiles.json', [Profile(id: 'p1', name: 'P1').toMap()]);
    add('categories.json', [
      Category(
              id: 'c1',
              name: 'C1',
              usage: CategoryUsage.expense,
              iconCode: 0,
              tag: CategoryTag.none)
          .toMap()
    ]);
    add('accounts.json', [
      Account(id: 'a1', name: 'A1', type: AccountType.savings, balance: 100)
          .toMap()
    ]);
    add('transactions.json', [
      Transaction(
              id: 't1',
              title: 'T1',
              amount: 50,
              date: DateTime(2025),
              type: TransactionType.expense,
              category: 'C1',
              accountId: 'a1')
          .toMap()
    ]);
    add('loans.json', []);
    add('recurring.json', []);
    add('settings.json', {'theme': 'dark'});
    add('insurance_policies.json', []);
    add('tax_rules.json', {});
    add('tax_data.json', []);
    add('lending_records.json', []);

    final zipBytes = ZipEncoder().encode(archive);

    when(() => mockStorageService.clearAllData()).thenAnswer((_) async {});
    when(() => mockStorageService.saveProfile(any())).thenAnswer((_) async {});
    when(() => mockStorageService.addCategory(any())).thenAnswer((_) async {});
    when(() => mockStorageService.saveAccount(any())).thenAnswer((_) async {});
    when(() => mockStorageService.saveTransaction(any(),
        applyImpact: any(named: 'applyImpact'))).thenAnswer((_) async {});
    when(() => mockStorageService.saveLoan(any())).thenAnswer((_) async {});
    when(() => mockStorageService.saveRecurringTransaction(any()))
        .thenAnswer((_) async {});
    when(() => mockStorageService.saveSettings(any())).thenAnswer((_) async {});
    when(() => mockStorageService.saveInsurancePolicies(any()))
        .thenAnswer((_) async {});
    when(() => mockTaxConfigService.restoreAllRules(any()))
        .thenAnswer((_) async {});
    when(() => mockStorageService.saveTaxYearData(any()))
        .thenAnswer((_) async {});
    when(() => mockStorageService.saveLendingRecord(any()))
        .thenAnswer((_) async {});

    // Run
    final stats = await jsonDataService.restoreFromPackage(zipBytes);

    // Verify
    verify(() => mockStorageService.clearAllData()).called(1);
    verify(() => mockStorageService.saveProfile(any())).called(1);
    verify(() => mockStorageService.addCategory(any())).called(1);
    verify(() => mockStorageService.saveAccount(any())).called(1);
    verify(() => mockStorageService.saveTransaction(any(), applyImpact: false))
        .called(1);
    verify(() => mockStorageService.saveSettings(any())).called(1);

    expect(stats['profiles'], 1);
    expect(stats['accounts'], 1);
    expect(stats['transactions'], 1);
  });

  test('restoreFromPackage throws on missing metadata', () async {
    final archive = Archive();
    final zipBytes = ZipEncoder().encode(archive);
    expect(() => jsonDataService.restoreFromPackage(zipBytes), throwsException);
  });
}
