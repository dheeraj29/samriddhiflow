import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/models/taxes/tax_data.dart';
import 'package:samriddhi_flow/models/taxes/tax_data_models.dart';
import 'package:samriddhi_flow/models/taxes/tax_rules.dart';
import 'package:samriddhi_flow/services/taxes/indian_tax_service.dart';
import 'package:samriddhi_flow/services/taxes/tax_config_service.dart';

class MockTaxConfigService extends Mock implements TaxConfigService {}

void main() {
  late IndianTaxService taxService;
  late MockTaxConfigService mockConfig;

  final defaultSlabs = [
    const TaxSlab(300000, 0),
    const TaxSlab(600000, 5),
    const TaxSlab(900000, 10),
    const TaxSlab(1200000, 15),
    const TaxSlab(1500000, 20),
    const TaxSlab(double.infinity, 30),
  ];

  final defaultRules = TaxRules(
    slabs: defaultSlabs,
    stdDeductionSalary: 75000,
    rebateLimit: 700000,
    cessRate: 4,
    limitLeaveEncashment: 2500000,
    limitGratuity: 2000000,
    isStdDeductionSalaryEnabled: true,
    isRebateEnabled: true,
    isCessEnabled: true,
  );

  setUp(() {
    mockConfig = MockTaxConfigService();
    taxService = IndianTaxService(mockConfig);
    when(() => mockConfig.getRulesForYear(any())).thenReturn(defaultRules);
  });

  group('IndianTaxService - calculateDetailedLiability', () {
    test('Basic salary calculation with Standard Deduction', () {
      final data = TaxYearData(
        year: 2025,
        salary: const SalaryDetails(grossSalary: 1000000),
      );

      final result = taxService.calculateDetailedLiability(data, defaultRules);

      // Gross = 10L, Net Taxable = 10L - 75k (StdDed) = 9.25L
      // Slabs:
      // 0-3L: 0
      // 3-6L: 3L * 5% = 15000
      // 6-9L: 3L * 10% = 30000
      // 9-9.25L: 25k * 15% = 3750
      // Total Slab Tax = 48750
      // Cess = 48750 * 4% = 1950
      // Total = 50700
      expect(result['slabTax'], 48750);
      expect(result['cess'], 1950);
      expect(result['totalTax'], 50700);
    });

    test('Rebate u/s 87A for income below threshold', () {
      final data = TaxYearData(
        year: 2025,
        salary: const SalaryDetails(grossSalary: 700000),
      );

      final result = taxService.calculateDetailedLiability(data, defaultRules);

      // Taxable = 700k - 75k = 625k
      // 625k <= 700k (rebate limit), so tax should be 0
      expect(result['totalTax'], 0);
    });
  });

  group('IndianTaxService - calculateSalaryIncome', () {
    test('Exempts Leave Encashment and Gratuity up to limits', () {
      final data = TaxYearData(
        year: 2025,
        salary: const SalaryDetails(
          grossSalary: 1000000,
          leaveEncashment: 500000,
          gratuity: 300000,
        ),
      );

      final rules = defaultRules.copyWith(
        limitLeaveEncashment: 200000,
        limitGratuity: 100000,
        isRetirementExemptionEnabled: true,
      );

      final salaryIncome = taxService.calculateSalaryIncome(data, rules);

      // Gross = 10L
      // Exempt Leave = min(5L, 2L) = 2L
      // Exempt Grat = min(3L, 1L) = 1L
      // Net = 10L - 2L - 1L = 7L
      // Taxable = 7L - 75k (StdDed) = 6.25L
      expect(salaryIncome, 625000);
    });

    test('Handles Gifts from Employer exemption', () {
      final data = TaxYearData(
        year: 2025,
        salary:
            const SalaryDetails(grossSalary: 500000, giftsFromEmployer: 8000),
      );
      final rules = defaultRules.copyWith(
        isGiftFromEmployerEnabled: true,
        giftFromEmployerExemptionLimit: 5000,
      );

      final salaryIncome = taxService.calculateSalaryIncome(data, rules);
      // Taxable Gifts = 8000 - 5000 = 3000
      // Total Gross = 500k + 3k = 503k
      // Taxable = 503k - 75k = 428k
      expect(salaryIncome, 428000);
    });
  });

  group('IndianTaxService - calculateHousePropertyIncome', () {
    test('Self-occupied property with interest loss capped', () {
      final data = TaxYearData(
        year: 2025,
        houseProperties: [
          const HouseProperty(
            name: 'Home',
            isSelfOccupied: true,
            interestOnLoan: 250000,
          ),
        ],
      );
      final rules = defaultRules.copyWith(
        isHPMaxInterestEnabled: true,
        maxHPDeductionLimit: 200000,
      );

      final hpIncome = taxService.calculateHousePropertyIncome(data, rules);
      expect(hpIncome, -200000);
    });

    test('Let-out property with rent and municipal taxes', () {
      final data = TaxYearData(
        year: 2025,
        houseProperties: [
          const HouseProperty(
            name: 'Rental',
            isSelfOccupied: false,
            rentReceived: 300000,
            municipalTaxes: 20000,
            interestOnLoan: 50000,
          ),
        ],
      );
      final rules = defaultRules.copyWith(
        isStdDeductionHPEnabled: true,
        standardDeductionRateHP: 30.0,
      );

      final hpIncome = taxService.calculateHousePropertyIncome(data, rules);
      // NAV = 300k - 20k = 280k
      // Std Ded = 280k * 30% = 84k
      // Income = 280k - 84k - 50k = 146k
      expect(hpIncome, 146000);
    });
  });

  group('IndianTaxService - calculateCapitalGains', () {
    test('Separates Equity and Other LTCG/STCG', () {
      final now = DateTime(2024, 6, 1);
      final data = TaxYearData(
        year: 2024,
        capitalGains: [
          CapitalGainEntry(
            description: 'Stocks',
            saleAmount: 1000000,
            costOfAcquisition: 800000,
            gainDate: now,
            matchAssetType: AssetType.equityShares,
            isLTCG: true,
          ),
          CapitalGainEntry(
            description: 'Gold',
            saleAmount: 500000,
            costOfAcquisition: 400000,
            gainDate: now,
            matchAssetType: AssetType.other,
            isLTCG: true,
          ),
          CapitalGainEntry(
            description: 'Intraday',
            saleAmount: 150000,
            costOfAcquisition: 100000,
            gainDate: now,
            matchAssetType: AssetType.other,
            isLTCG: false,
          ),
        ],
      );

      when(() => mockConfig.getRulesForYear(2024)).thenReturn(defaultRules);

      final cgResults = taxService.calculateCapitalGains(data, defaultRules);
      expect(cgResults['LTCG_Equity'], 200000);
      expect(cgResults['LTCG_Other'], 100000);
      expect(cgResults['STCG'], 50000);
    });

    test('Handles Reinvestment Exemption (u/s 54F for Equity)', () {
      final now = DateTime(2024, 6, 1);
      final data = TaxYearData(
        year: 2024,
        capitalGains: [
          CapitalGainEntry(
            description: 'Stocks',
            saleAmount: 2000000,
            costOfAcquisition: 1000000,
            gainDate: now,
            matchAssetType: AssetType.equityShares,
            isLTCG: true,
            reinvestedAmount: 600000,
            matchReinvestType: ReinvestmentType.residentialProperty,
          ),
        ],
      );

      final rules = defaultRules.copyWith(
        isCGReinvestmentEnabled: true,
        maxCGReinvestLimit: 10000000,
        windowGainReinvest: 2,
      );

      when(() => mockConfig.getRulesForYear(2024)).thenReturn(rules);

      final cgResults = taxService.calculateCapitalGains(data, rules);
      // Gain = 10L, Reinvest = 6L (Valid target: Residential)
      // Taxable = 10L - 6L = 4L
      expect(cgResults['LTCG_Equity'], 400000);
    });
  });

  group('IndianTaxService - calculateMonthlySalaryBreakdown', () {
    test('Correctly identifies extras and calculates marginal tax', () {
      // Setup a simple salary structure
      final structure = SalaryStructure(
        id: 's1',
        effectiveDate: DateTime(2024, 4, 1),
        monthlyBasic: 50000,
        monthlyFixedAllowances: 10000,
        performancePayFrequency: PayoutFrequency.monthly,
        monthlyPerformancePay: 5000,
        customAllowances: [],
      );

      final data = TaxYearData(
        year: 2025, // FY 2024-25
        salary: SalaryDetails(
          history: [structure],
          independentAllowances: [
            const CustomAllowance(
              name: 'Bonus',
              payoutAmount: 100000,
              frequency: PayoutFrequency.annually,
              startMonth: 10,
            ),
          ],
        ),
      );

      final breakdown =
          taxService.calculateMonthlySalaryBreakdown(data, defaultRules);

      // Regular Month Gross = 50k + 10k + 5k = 65k
      // Oct Gross = 65k + 100k = 165k
      expect(breakdown[4]!['gross'], 65000);
      expect(breakdown[10]!['gross'], 165000);
      expect(breakdown[10]!['extras'], 100000);
      expect(breakdown[10]!['tax'], greaterThan(breakdown[4]!['tax']!));
    });

    test('Handles multiple salary structures in Financial Year', () {
      final s1 = SalaryStructure(
        id: 's1',
        effectiveDate: DateTime(2024, 4, 1),
        monthlyBasic: 50000,
        monthlyFixedAllowances: 10000,
      );
      final s2 = SalaryStructure(
        id: 's2',
        effectiveDate: DateTime(2024, 10, 1), // Hike in October
        monthlyBasic: 70000,
        monthlyFixedAllowances: 15000,
      );

      final data = TaxYearData(
        year: 2024, // FY 2024-25
        salary: SalaryDetails(history: [s1, s2]),
      );

      final breakdown =
          taxService.calculateMonthlySalaryBreakdown(data, defaultRules);

      // Apr to Sep -> s1 (60k)
      // Oct to Mar -> s2 (85k)
      expect(breakdown[4]!['gross'], 60000);
      expect(breakdown[9]!['gross'], 60000);
      expect(breakdown[10]!['gross'], 85000);
      expect(breakdown[3]!['gross'], 85000); // March of next calendar year
    });

    test('Includes independent monthly allowances and deductions', () {
      final s1 = SalaryStructure(
        id: 's1',
        effectiveDate: DateTime(2024, 4, 1),
        monthlyBasic: 100000,
      );

      final data = TaxYearData(
        year: 2024,
        salary: SalaryDetails(
          history: [s1],
          independentAllowances: [
            const CustomAllowance(
              name: 'Internet',
              payoutAmount: 2000,
              frequency: PayoutFrequency.monthly,
            ),
          ],
          independentDeductions: [
            const CustomDeduction(
              name: 'Professional Tax',
              amount: 200,
              frequency: PayoutFrequency.monthly,
              isTaxable: true, // Deduction from taxable income
            ),
            const CustomDeduction(
              name: 'LWF',
              amount: 10,
              frequency: PayoutFrequency.monthly,
              isTaxable: false, // Post-tax deduction
            ),
          ],
        ),
      );

      final breakdown =
          taxService.calculateMonthlySalaryBreakdown(data, defaultRules);

      // Gross = 100k + 2k = 102k
      expect(breakdown[4]!['gross'], 102000);
      // Deductions = 200 + 10 = 210
      expect(breakdown[4]!['deductions'], 210);
      // Verify take-home calculation includes these
      final tax = breakdown[4]!['tax']!;
      final expectedTakeHome = 102000 - tax - 210;
      expect(breakdown[4]!['takeHome'], closeTo(expectedTakeHome, 1));
    });

    test('Applies Marginal Relief for income slightly above rebate limit', () {
      final data = TaxYearData(
        year: 2025,
        salary: const SalaryDetails(
            grossSalary: 800000), // Net 7.25L after 75k StdDed
      );

      final result = taxService.calculateDetailedLiability(data, defaultRules);

      // Tax on 7.25L (New Regime): 3-6 (15k), 6-7.25 (12.5k). Total = 27.5k.
      // Excess Income = 7.25L - 7L = 25k.
      // Marginal Relief caps taxBeforeCess at 25k.
      // Cess 4% on 25k = 1000. Total = 26000.
      expect(result['totalTax'], 26000);
    });

    test('LTCG Equity handles 1.25L exemption correctly', () {
      final rules = defaultRules.copyWith(
        stdExemption112A: 125000,
        isCGRatesEnabled: true,
        ltcgRateEquity: 12.5,
      );

      final data = TaxYearData(
        year: 2025,
        capitalGains: [
          CapitalGainEntry(
            description: 'Stocks',
            saleAmount: 1000000,
            costOfAcquisition: 0, // 10L gain
            gainDate: DateTime(2025, 5, 1),
            matchAssetType: AssetType.equityShares,
            isLTCG: true,
          ),
        ],
      );

      final result = taxService.calculateDetailedLiability(data, rules);
      // Gain = 10L. Exemption = 125k. Taxable = 8.75L.
      // Tax @ 12.5% = 109375.
      expect(result['specialTax'], 109375);
    });

    test('Handles Cash Gifts correctly (Exempt vs Taxable)', () {
      final data = TaxYearData(
        year: 2025,
        cashGifts: [
          const OtherIncome(
              name: 'G1', amount: 40000, type: 'Gift', subtype: 'Other'),
          const OtherIncome(
              name: 'G2', amount: 100000, type: 'Gift', subtype: 'Marriage'),
        ],
      );

      final rules = defaultRules.copyWith(cashGiftExemptionLimit: 50000);

      var income = taxService.calculateOtherSources(data, rules);
      expect(income, 0); // Aggregate 40k <= 50k

      final data2 = data.copyWith(cashGifts: [
        ...data.cashGifts,
        const OtherIncome(
            name: 'G3', amount: 20000, type: 'Gift', subtype: 'Other'),
      ]);
      // Total Other = 40k + 20k = 60k (> 50k)

      income = taxService.calculateOtherSources(data2, rules);
      expect(income, 60000); // Fully taxable
    });
  });
}
