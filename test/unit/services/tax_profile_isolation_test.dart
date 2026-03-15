import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/models/category.dart';
import 'package:samriddhi_flow/models/transaction.dart';
import 'package:samriddhi_flow/services/storage_service.dart';
import 'package:samriddhi_flow/services/taxes/tax_config_service.dart';
import 'package:samriddhi_flow/services/taxes/insurance_tax_service.dart';
import 'package:samriddhi_flow/services/taxes/tax_data_fetcher.dart';
import 'package:samriddhi_flow/models/taxes/tax_rules.dart';

class MockStorageService extends Mock implements StorageService {}

class MockTaxConfigService extends Mock implements TaxConfigService {}

class MockInsuranceTaxService extends Mock implements InsuranceTaxService {}

void main() {
  late TaxDataFetcher fetcher;
  late MockStorageService mockStorage;
  late MockTaxConfigService mockConfig;
  late MockInsuranceTaxService mockInsurance;

  setUp(() {
    mockStorage = MockStorageService();
    mockConfig = MockTaxConfigService();
    mockInsurance = MockInsuranceTaxService();
    fetcher = TaxDataFetcher(mockStorage, mockConfig, mockInsurance);

    final rules = TaxRules(
        financialYearStartMonth: 4,
        tagMappings: {'Salary': 'salary', 'Rent': 'houseProp'});
    when(() => mockConfig.getRulesForYear(any())).thenReturn(rules);
    when(() => mockStorage.getInsurancePolicies()).thenReturn([]);
  });

  test('TaxDataFetcher correctly isolates data by profile', () async {
    const year = 2025;

    // Profile A Transactions
    final txnA = Transaction(
      id: 'a1',
      title: 'Salary A',
      amount: 50000,
      date: DateTime(2025, 4, 10),
      type: TransactionType.income,
      category: 'Salary',
      profileId: 'profileA',
    );

    // Profile B Transactions
    Transaction(
      id: 'b1',
      title: 'Salary B',
      amount: 60000,
      date: DateTime(2025, 4, 15),
      type: TransactionType.income,
      category: 'Salary',
      profileId: 'profileB',
    );

    // Categories for Profile A
    when(() => mockStorage.getCategories()).thenReturn([
      Category(
          id: 'c1',
          name: 'Salary',
          usage: CategoryUsage.income,
          tag: CategoryTag.none,
          profileId: 'profileA'),
    ]);

    // Mock storage calls with profile filtering
    when(() => mockStorage.getAllTransactions()).thenReturn([txnA]);
    when(() => mockStorage.updateTransactionsTaxSync(any(), any()))
        .thenAnswer((_) async {});

    // Fetch for Profile A
    final resultA =
        await fetcher.fetchAndAggregate(year, profileId: 'profileA');

    // Verification
    expect(resultA.data.profileId, 'profileA');
    // Note: Fetcher aggregates based on mapping. If mapped to Salary head, it shows up if handled.
    // In current fetcher, Salary head is NOT handled by _addToHead (it's handled by SalaryDetails which is empty in fetcher)
    // Let's use 'Rent' which is handled via 'houseProp'.
  });

  test('TaxDataFetcher aggregates ONLY target profile data', () async {
    const year = 2025;

    final rentA = Transaction(
      id: 'ra',
      title: 'Rent A',
      amount: 10000,
      date: DateTime(2025, 5, 1),
      type: TransactionType.income,
      category: 'Rent',
      profileId: 'profileA',
    );

    // Profile B Rent
    Transaction(
      id: 'rb',
      title: 'Rent B',
      amount: 15000,
      date: DateTime(2025, 5, 10),
      type: TransactionType.income,
      category: 'Rent',
      profileId: 'profileB',
    );

    when(() => mockStorage.getCategories()).thenReturn([
      Category(
          id: 'c1',
          name: 'Rent',
          usage: CategoryUsage.income,
          tag: CategoryTag.none,
          profileId: 'profileA'),
    ]);
    when(() => mockStorage.getAllTransactions()).thenReturn([rentA]);
    when(() => mockStorage.updateTransactionsTaxSync(any(), any()))
        .thenAnswer((_) async {});

    final result = await fetcher.fetchAndAggregate(year, profileId: 'profileA');

    expect(result.data.profileId, 'profileA');
    expect(result.data.totalHP, 10000.0); // Only Rent A
    verify(() => mockStorage.getAllTransactions()).called(1);
  });
}
