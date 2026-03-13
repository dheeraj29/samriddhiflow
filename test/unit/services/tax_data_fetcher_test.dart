import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/models/taxes/tax_rules.dart';
import 'package:samriddhi_flow/models/transaction.dart';
import 'package:samriddhi_flow/services/storage_service.dart';
import 'package:samriddhi_flow/services/taxes/tax_config_service.dart';
import 'package:samriddhi_flow/services/taxes/tax_data_fetcher.dart';
import 'package:samriddhi_flow/models/taxes/insurance_policy.dart';
import 'package:samriddhi_flow/services/taxes/insurance_tax_service.dart';
import 'package:samriddhi_flow/models/taxes/tax_data_models.dart';

class MockStorageService extends Mock implements StorageService {}

class MockTaxConfigService extends Mock implements TaxConfigService {}

class MockInsuranceTaxService extends Mock implements InsuranceTaxService {}

void main() {
  late TaxDataFetcher fetcher;
  late MockStorageService mockStorage;
  late MockTaxConfigService mockConfig;
  late MockInsuranceTaxService mockInsuranceTax;

  setUp(() {
    mockStorage = MockStorageService();
    mockConfig = MockTaxConfigService();
    mockInsuranceTax = MockInsuranceTaxService();
    fetcher = TaxDataFetcher(mockStorage, mockConfig, mockInsuranceTax);

    // Default stub for taxSync update
    when(() => mockStorage.updateTransactionsTaxSync(any(), any()))
        .thenAnswer((_) async {});
  });

  group('TaxDataFetcher - fetchAndAggregate', () {
    test('Correctly aggregates basic income heads in FY range', () async {
      const year = 2024;
      final rules = TaxRules(financialYearStartMonth: 4, tagMappings: {
        'Rent': 'houseProp',
        'Profit': 'business',
        'Agriculture': 'agriIncome',
      });

      when(() => mockConfig.getRulesForYear(year)).thenReturn(rules);
      when(() => mockStorage.getCategories()).thenReturn([]);
      when(() => mockStorage.getInsurancePolicies()).thenReturn([]);

      final txns = [
        Transaction(
            id: '1',
            title: 'Flat Rent',
            amount: 30000,
            date: DateTime(2024, 4, 15),
            type: TransactionType.income,
            category: 'Rent'),
        Transaction(
            id: '2',
            title: 'Business Payout',
            amount: 50000,
            date: DateTime(2024, 10, 10),
            type: TransactionType.income,
            category: 'Profit'),
        Transaction(
            id: '3',
            title: 'Farm Income',
            amount: 10000,
            date: DateTime(2025, 3, 5),
            type: TransactionType.income,
            category: 'Agriculture'),
        // Out of range
        Transaction(
            id: '4',
            title: 'Old Rent',
            amount: 30000,
            date: DateTime(2024, 3, 31),
            type: TransactionType.income,
            category: 'Rent'),
      ];
      when(() => mockStorage.getAllTransactions()).thenReturn(txns);

      final result = await fetcher.fetchAndAggregate(year);

      expect(result.data.houseProperties.first.rentReceived, 30000);
      expect(result.data.businessIncomes.first.netIncome, 50000);
      expect(
          result.data.agriIncomeHistory.fold(0.0, (sum, e) => sum + e.amount),
          10000);
      expect(result.warnings, isEmpty);
    });

    test('Handles advanced tag mappings and holding tenure', () async {
      const year = 2024;
      final rules = TaxRules(advancedTagMappings: [
        const TaxMappingRule(
            categoryName: 'Stock Gain', taxHead: 'ltcg', minHoldingMonths: 12),
        const TaxMappingRule(
            categoryName: 'Stock Gain',
            taxHead: 'stcg',
            minHoldingMonths: 12 // less than 12
            ),
      ]);

      when(() => mockConfig.getRulesForYear(year)).thenReturn(rules);
      when(() => mockStorage.getCategories()).thenReturn([]);
      when(() => mockStorage.getInsurancePolicies()).thenReturn([]);

      final txns = [
        Transaction(
          id: '1',
          title: 'HDFC LTCG',
          amount: 100000,
          gainAmount: 20000,
          date: DateTime(2024, 6, 1),
          type: TransactionType.income,
          category: 'Stock Gain',
          holdingTenureMonths: 14,
        ),
        Transaction(
          id: '2',
          title: 'Zomato STCG',
          amount: 50000,
          gainAmount: 5000,
          date: DateTime(2025, 1, 1),
          type: TransactionType.income,
          category: 'Stock Gain',
          holdingTenureMonths: 6,
        ),
      ];
      when(() => mockStorage.getAllTransactions()).thenReturn(txns);

      final result = await fetcher.fetchAndAggregate(year);

      expect(result.data.capitalGains.length, 2);
      expect(
          result.data.capitalGains
              .any((e) => e.isLTCG && e.saleAmount == 100000),
          true);
      expect(
          result.data.capitalGains
              .any((e) => !e.isLTCG && e.saleAmount == 50000),
          true);
    });

    test('Integrates maturing insurance policies (ULIP and Non-ULIP)',
        () async {
      const year = 2024;
      final rules = TaxRules(financialYearStartMonth: 4);
      when(() => mockConfig.getRulesForYear(year)).thenReturn(rules);
      when(() => mockStorage.getCategories()).thenReturn([]);
      when(() => mockStorage.getAllTransactions()).thenReturn([]);

      final now = DateTime(2024, 6, 1);
      final policies = <InsurancePolicy>[
        InsurancePolicy(
          id: 'p1',
          policyName: 'Non-ULIP',
          sumAssured: 500000,
          policyNumber: '1',
          annualPremium: 10000,
          startDate: now.subtract(const Duration(days: 365 * 10)),
          maturityDate: now,
          isTaxExempt: false,
          isUnitLinked: false,
        ),
        InsurancePolicy(
          id: 'p2',
          policyName: 'ULIP',
          sumAssured: 300000,
          policyNumber: '2',
          annualPremium: 5000,
          startDate: now.subtract(const Duration(days: 365 * 5)),
          maturityDate: now.add(const Duration(days: 1)),
          isTaxExempt: false,
          isUnitLinked: true,
        ),
      ];
      when(() => mockStorage.getInsurancePolicies()).thenReturn(policies);

      // Mock the service calls
      when(() => mockInsuranceTax.getTaxableIncomeEntry(policies[0], year))
          .thenReturn(OtherIncome(
        name: 'Insurance Maturity: Non-ULIP',
        amount: 400000,
        type: 'Other',
        subtype: 'others',
        transactionDate: now,
        lastUpdated: DateTime.now(),
      ));

      when(() => mockInsuranceTax.getTaxableIncomeEntry(policies[1], year))
          .thenReturn(CapitalGainEntry(
        description: 'Insurance Maturity: ULIP',
        matchAssetType: AssetType.other,
        isLTCG: true,
        saleAmount: 300000,
        costOfAcquisition: 25000,
        gainDate: now.add(const Duration(days: 1)),
        transactionDate: now.add(const Duration(days: 1)),
        lastUpdated: DateTime.now(),
      ));

      final result = await fetcher.fetchAndAggregate(year);

      // Non-ULIP -> Other Income. Gain = 500k - (10k * 10) = 400k
      expect(result.data.otherIncomes.any((e) => e.amount == 400000), true);
      // ULIP -> LTCG. Gain = 300k - (5k * 5) = 275k
      expect(
          result.data.capitalGains
              .any((e) => e.isLTCG && e.saleAmount == 300000),
          true);
    });

    test('Correctly splits dividends into Advance Tax Quarters', () async {
      const year = 2024;
      final rules = TaxRules(
          financialYearStartMonth: 4, tagMappings: {'Div': 'dividend'});
      when(() => mockConfig.getRulesForYear(year)).thenReturn(rules);
      when(() => mockStorage.getCategories()).thenReturn([]);
      when(() => mockStorage.getInsurancePolicies()).thenReturn([]);

      final txns = [
        Transaction(
            id: 'q1',
            title: 'Q1',
            amount: 1000,
            date: DateTime(2024, 5, 1),
            type: TransactionType.income,
            category: 'Div'),
        Transaction(
            id: 'q2',
            title: 'Q2',
            amount: 2000,
            date: DateTime(2024, 8, 1),
            type: TransactionType.income,
            category: 'Div'),
        Transaction(
            id: 'q3',
            title: 'Q3',
            amount: 3000,
            date: DateTime(2024, 11, 1),
            type: TransactionType.income,
            category: 'Div'),
        Transaction(
            id: 'q4',
            title: 'Q4',
            amount: 4000,
            date: DateTime(2025, 2, 1),
            type: TransactionType.income,
            category: 'Div'),
        Transaction(
            id: 'q5',
            title: 'Q5',
            amount: 5000,
            date: DateTime(2025, 3, 20),
            type: TransactionType.income,
            category: 'Div'),
      ];
      when(() => mockStorage.getAllTransactions()).thenReturn(txns);

      final result = await fetcher.fetchAndAggregate(year);
      expect(result.data.dividendIncome.amountQ1, 1000);
      expect(result.data.dividendIncome.amountQ2, 2000);
      expect(result.data.dividendIncome.amountQ3, 3000);
      expect(result.data.dividendIncome.amountQ4, 4000);
      expect(result.data.dividendIncome.amountQ5, 5000);
    });

    test('Returns warnings for unmapped income transactions', () async {
      const year = 2024;
      final rules = TaxRules(tagMappings: {});
      when(() => mockConfig.getRulesForYear(year)).thenReturn(rules);
      when(() => mockStorage.getCategories()).thenReturn([]);
      when(() => mockStorage.getInsurancePolicies()).thenReturn([]);
      when(() => mockStorage.getAllTransactions()).thenReturn([
        Transaction(
            id: '1',
            title: 'Unknown',
            amount: 500,
            date: DateTime(2024, 6, 1),
            type: TransactionType.income,
            category: 'N/A'),
      ]);

      final result = await fetcher.fetchAndAggregate(year);
      expect(result.warnings.length, 1);
      expect(result.warnings.first, contains('Unmapped Income'));
    });

    test('fetchTagSum correctly filters and sums transactions', () {
      final start = DateTime(2024, 4, 1);
      final end = DateTime(2025, 3, 31);
      final txns = [
        Transaction(
            id: '1',
            title: 'Interest',
            amount: 100,
            date: DateTime(2024, 6, 1),
            type: TransactionType.income,
            category: 'LoanTag'),
        Transaction(
            id: '2',
            title: 'Interest',
            amount: 150,
            date: DateTime(2024, 7, 1),
            type: TransactionType.income,
            category: 'LoanTag'),
        Transaction(
            id: '3',
            title: 'Wrong Type',
            amount: 500,
            date: DateTime(2024, 8, 1),
            type: TransactionType.expense,
            category: 'LoanTag'),
        Transaction(
            id: '4',
            title: 'Other',
            amount: 100,
            date: DateTime(2024, 6, 1),
            type: TransactionType.income,
            category: 'Other'),
      ];
      when(() => mockStorage.getAllTransactions()).thenReturn(txns);

      final sum =
          fetcher.fetchTagSum('LoanTag', TransactionType.income, start, end);
      expect(sum, 250);
    });
    test('Correctly categorizes Gifts with default subtype Other', () async {
      const year = 2024;
      final rules = TaxRules(financialYearStartMonth: 4, tagMappings: {
        'GiftCategory': 'gift',
      });

      when(() => mockConfig.getRulesForYear(year)).thenReturn(rules);
      when(() => mockStorage.getCategories()).thenReturn([]);
      when(() => mockStorage.getInsurancePolicies()).thenReturn([]);

      final txns = [
        Transaction(
            id: 'g1',
            title: 'Gift from Friend',
            amount: 5000,
            date: DateTime(2024, 5, 1),
            type: TransactionType.income,
            category: 'GiftCategory'),
      ];
      when(() => mockStorage.getAllTransactions()).thenReturn(txns);

      final result = await fetcher.fetchAndAggregate(year);

      expect(result.data.cashGifts.length, 1);
      expect(result.data.cashGifts.first.subtype, 'other');
      expect(result.data.cashGifts.first.type, 'Gift');
    });

    test('taxSync: Filters out already synced transactions unless forced',
        () async {
      const year = 2024;
      final rules = TaxRules(financialYearStartMonth: 4, tagMappings: {
        'Rent': 'houseProp',
      });

      when(() => mockConfig.getRulesForYear(year)).thenReturn(rules);
      when(() => mockStorage.getCategories()).thenReturn([]);
      when(() => mockStorage.getInsurancePolicies()).thenReturn([]);
      when(() => mockStorage.updateTransactionsTaxSync(any(), any()))
          .thenAnswer((_) async {});

      final txns = [
        Transaction(
            id: 'synced-1',
            title: 'Synced Rent',
            amount: 10000,
            date: DateTime(2024, 5, 1),
            type: TransactionType.income,
            category: 'Rent',
            taxSync: true),
        Transaction(
            id: 'new-1',
            title: 'New Rent',
            amount: 20000,
            date: DateTime(2024, 6, 1),
            type: TransactionType.income,
            category: 'Rent',
            taxSync: false),
        Transaction(
            id: 'null-1',
            title: 'Null Sync Rent',
            amount: 5000,
            date: DateTime(2024, 7, 1),
            type: TransactionType.income,
            category: 'Rent',
            taxSync: null),
      ];
      when(() => mockStorage.getAllTransactions()).thenReturn(txns);

      // 1. Partial sync (Normal)
      final result = await fetcher.fetchAndAggregate(year);
      // Should include new-1 and null-1 = 20000 + 5000 = 25000
      expect(result.data.houseProperties.first.rentReceived, 25000);
      verify(() =>
              mockStorage.updateTransactionsTaxSync(['new-1', 'null-1'], true))
          .called(1);

      // 2. Force resync
      final resultForced =
          await fetcher.fetchAndAggregate(year, forceResync: true);
      // Should include all = 10000 + 20000 + 5000 = 35000
      expect(resultForced.data.houseProperties.first.rentReceived, 35000);
      verify(() => mockStorage.updateTransactionsTaxSync(
          ['synced-1', 'new-1', 'null-1'], true)).called(1);
    });
  });
}
