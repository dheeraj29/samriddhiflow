import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/models/taxes/tax_data.dart';
import 'package:samriddhi_flow/models/taxes/tax_data_models.dart';
import 'package:samriddhi_flow/models/taxes/tax_rules.dart';
import 'package:samriddhi_flow/services/taxes/indian_tax_service.dart';
import 'package:samriddhi_flow/services/taxes/tax_config_service.dart';
import 'package:clock/clock.dart';
import 'dart:math';

class MockTaxConfigService extends Mock implements TaxConfigService {}

class BreakdownMockConfig extends Mock implements TaxConfigService {
  @override
  TaxRules getRulesForYear(int year) {
    // Return a basic ruleset for 2025 (New Regime)
    return TaxRules(
      slabs: [
        const TaxSlab(400000, 0),
        const TaxSlab(800000, 5),
        const TaxSlab(1200000, 10),
        const TaxSlab(1600000, 15),
        const TaxSlab(2000000, 20),
        const TaxSlab(double.infinity, 30),
      ],
      isStdDeductionSalaryEnabled: true,
      stdDeductionSalary: 75000,
      cessRate: 4.0,
      rebateLimit: 1200000, // Budget 2025-26 New Regime Limit
    );
  }

  @override
  bool get isReady => true;
}

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
      isCessEnabled: true);

  setUp(() {
    mockConfig = MockTaxConfigService();
    taxService = IndianTaxService(mockConfig);
    when(() => mockConfig.getRulesForYear(any())).thenReturn(defaultRules);
  });

  group('IndianTaxService - calculateDetailedLiability', () {
    test('Basic salary calculation with Standard Deduction', () {
      final data = TaxYearData(
          year: 2025,
          salary: SalaryDetails(history: [
            SalaryStructure(
                id: 'test',
                monthlyBasic: 1000000 / 12,
                effectiveDate: DateTime(2025, 4, 1))
          ]));

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
      expect(result['slabTax'], closeTo(48750, 1));
      expect(result['cess'], closeTo(1950, 1));
      expect(result['totalTax'], closeTo(50700, 1));
    });

    test('Rebate for income below threshold', () {
      final data = TaxYearData(
          year: 2025,
          salary: SalaryDetails(history: [
            SalaryStructure(
                id: 'test',
                monthlyBasic: 700000 / 12,
                effectiveDate: DateTime(2025, 4, 1))
          ]));

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
          salary: SalaryDetails(history: [
            SalaryStructure(
                id: 'test',
                monthlyBasic: 200000 / 12,
                effectiveDate: DateTime(2025, 4, 1))
          ], leaveEncashment: 500000, gratuity: 300000));

      final rules = defaultRules.copyWith(
          limitLeaveEncashment: 200000,
          limitGratuity: 100000,
          isRetirementExemptionEnabled: true);

      final salaryIncome = taxService.calculateSalaryIncome(data, rules);

      // Gross = 10L
      // Taxable = 7L
      expect(salaryIncome, 700000);
    });

    test('Handles Gifts from Employer exemption', () {
      final data = TaxYearData(
          year: 2025,
          salary: SalaryDetails(history: [
            SalaryStructure(
                id: 'test',
                monthlyBasic: 500000 / 12,
                effectiveDate: DateTime(2025, 4, 1),
                customAllowances: const [
                  CustomAllowance(
                      id: 'gift',
                      name: 'Gift Vouchers',
                      payoutAmount: 8000,
                      frequency: PayoutFrequency.annually,
                      startMonth: 4,
                      exemptionLimit: 5000)
                ])
          ]));
      final rules = defaultRules.copyWith(
          isGiftFromEmployerEnabled: true,
          giftFromEmployerExemptionLimit: 5000);

      final salaryIncome = taxService.calculateSalaryIncome(data, rules);
      // Taxable Gifts = 8000 - 5000 = 3000
      // Total Gross = 500k + 3k = 503k
      expect(salaryIncome, closeTo(503000, 1));
    });

    test('Leaves salary unchanged when employer gifts stay within exemption',
        () {
      final data = TaxYearData(
          year: 2025,
          salary: SalaryDetails(history: [
            SalaryStructure(
                id: 'gift-under-limit',
                monthlyBasic: 100000 / 12,
                effectiveDate: DateTime(2025, 4, 1),
                customAllowances: const [
                  CustomAllowance(
                      id: 'gift',
                      name: 'Gift Voucher',
                      payoutAmount: 4000,
                      frequency: PayoutFrequency.annually,
                      startMonth: 4,
                      exemptionLimit: 5000)
                ])
          ]));

      final rules = defaultRules.copyWith(
        isGiftFromEmployerEnabled: true,
        giftFromEmployerExemptionLimit: 5000,
        isStdDeductionSalaryEnabled: false,
      );

      final salaryIncome = taxService.calculateSalaryIncome(data, rules);
      expect(salaryIncome, closeTo(100000, 1));
    });

    test('Ignores employer gift exemption logic when the feature is disabled',
        () {
      final data = TaxYearData(
          year: 2025,
          salary: SalaryDetails(history: [
            SalaryStructure(
                id: 'gift-disabled',
                monthlyBasic: 100000 / 12,
                effectiveDate: DateTime(2025, 4, 1))
          ]));

      final rules = defaultRules.copyWith(
        isGiftFromEmployerEnabled: false,
        giftFromEmployerExemptionLimit: 5000,
        isStdDeductionSalaryEnabled: false,
      );

      final salaryIncome = taxService.calculateSalaryIncome(data, rules);
      expect(salaryIncome, closeTo(100000, 1));
    });
  });

  group('IndianTaxService - calculateHousePropertyIncome', () {
    test('Self-occupied property with interest loss capped', () {
      const data = TaxYearData(year: 2025, houseProperties: [
        HouseProperty(
            name: 'Home', isSelfOccupied: true, interestOnLoan: 250000),
      ]);
      final rules = defaultRules.copyWith(
          isHPMaxInterestEnabled: true, maxHPDeductionLimit: 200000);

      final hpIncome = taxService.calculateHousePropertyIncome(data, rules);
      expect(hpIncome, 0);
    });

    test('Let-out property with rent and municipal taxes', () {
      const data = TaxYearData(year: 2025, houseProperties: [
        HouseProperty(
            name: 'Rental',
            isSelfOccupied: false,
            rentReceived: 300000,
            municipalTaxes: 20000,
            interestOnLoan: 50000),
      ]);
      final rules = defaultRules.copyWith(
          isStdDeductionHPEnabled: true, standardDeductionRateHP: 30.0);

      final hpIncome = taxService.calculateHousePropertyIncome(data, rules);
      expect(hpIncome, 146000);
    });

    test('Multiple properties: Loss on one does not reduce income on another',
        () {
      const data = TaxYearData(year: 2025, houseProperties: [
        HouseProperty(
            name: 'Gain Prop',
            isSelfOccupied: false,
            rentReceived: 200000,
            municipalTaxes: 0,
            interestOnLoan: 0),
        HouseProperty(
            name: 'Loss Prop', isSelfOccupied: true, interestOnLoan: 50000),
      ]);
      final rules = defaultRules.copyWith(
          isStdDeductionHPEnabled: true, standardDeductionRateHP: 30.0);

      final hpIncome = taxService.calculateHousePropertyIncome(data, rules);
      // Gain Prop: 200k - (30% of 200k = 60k) = 140k
      // Loss Prop: -50k capped at 0
      // Total should be 140k
      expect(hpIncome, 140000);
    });
  });

  group('IndianTaxService - calculateCapitalGains', () {
    test('Separates Equity and Other LTCG/STCG', () {
      final now = DateTime(2024, 6, 1);
      final data = TaxYearData(year: 2024, capitalGains: [
        CapitalGainEntry(
            description: 'Stocks',
            saleAmount: 1000000,
            costOfAcquisition: 800000,
            gainDate: now,
            matchAssetType: AssetType.equityShares,
            isLTCG: true),
        CapitalGainEntry(
            description: 'Gold',
            saleAmount: 500000,
            costOfAcquisition: 400000,
            gainDate: now,
            matchAssetType: AssetType.other,
            isLTCG: true),
        CapitalGainEntry(
            description: 'Intraday',
            saleAmount: 150000,
            costOfAcquisition: 100000,
            gainDate: now,
            matchAssetType: AssetType.other,
            isLTCG: false),
      ]);

      when(() => mockConfig.getRulesForYear(2024)).thenReturn(defaultRules);

      final cgResults = taxService.calculateCapitalGains(data, defaultRules);
      expect(cgResults['LTCG_Equity'], 200000);
      expect(cgResults['LTCG_Other'], 100000);
      expect(cgResults['STCG'], 50000);

      final detailedLiability =
          taxService.calculateDetailedLiability(data, defaultRules);
      expect(detailedLiability['capitalGainsTotal'], 350000);
      expect(detailedLiability['LTCG_Equity'], 200000);
      expect(detailedLiability['LTCG_Other'], 100000);
      expect(detailedLiability['STCG'], 50000);
    });

    test('Handles Reinvestment Exemption (Equity)', () {
      final now = DateTime(2024, 6, 1);
      final data = TaxYearData(year: 2024, capitalGains: [
        CapitalGainEntry(
            description: 'Stocks',
            saleAmount: 2000000,
            costOfAcquisition: 1000000,
            gainDate: now,
            matchAssetType: AssetType.equityShares,
            isLTCG: true,
            reinvestedAmount: 600000,
            matchReinvestType: ReinvestmentType.residentialProperty),
      ]);

      final rules = defaultRules.copyWith(
          isCGReinvestmentEnabled: true,
          isLTCGExemption112AEnabled: false,
          maxCGReinvestLimit: 10000000,
          windowGainReinvest: 2);

      when(() => mockConfig.getRulesForYear(2024)).thenReturn(rules);

      final cgResults = taxService.calculateCapitalGains(data, rules);
      // Gain = 10L, Reinvest = 6L (Valid target: Residential)
      // Restored logic: calculateCapitalGains returns Net Gain (4L)
      expect(cgResults['LTCG_Equity'], 400000.0);

      final details = taxService.calculateDetailedLiability(data, rules);
      // capitalGainsTotal reflects Gross
      expect(details['capitalGainsTotal'], 1000000.0);
      // cgDeductions reflects Reinvestments + 112A exemptions
      expect(details['cgDeductions'], 600000.0);
      // Net taxable isolation check: Total taxable from this source = 10L - 6L = 4L
      // Standard exemption for 112A might apply if enabled, but here rules has 12.5k or similar?
      // actually defaultRules has isCGRatesEnabled: false.
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
          customAllowances: []);

      final data = TaxYearData(
          year: 2025, // FY 2024-25
          salary: SalaryDetails(history: [
            structure
          ], independentAllowances: [
            const CustomAllowance(
                id: 'bonus1',
                name: 'Bonus',
                payoutAmount: 100000,
                frequency: PayoutFrequency.annually,
                startMonth: 10),
          ]));

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
          monthlyFixedAllowances: 10000);
      final s2 = SalaryStructure(
          id: 's2',
          effectiveDate: DateTime(2024, 10, 1), // Hike in October
          monthlyBasic: 70000,
          monthlyFixedAllowances: 15000);

      final data = TaxYearData(
          year: 2024, // FY 2024-25
          salary: SalaryDetails(history: [s1, s2]));

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
          id: 's1', effectiveDate: DateTime(2024, 4, 1), monthlyBasic: 100000);

      final data = TaxYearData(
          year: 2024,
          salary: SalaryDetails(history: [
            s1
          ], independentAllowances: [
            const CustomAllowance(
                id: 'internet_allowance',
                name: 'Internet',
                payoutAmount: 2000,
                frequency: PayoutFrequency.monthly),
          ]));

      final breakdown =
          taxService.calculateMonthlySalaryBreakdown(data, defaultRules);

      // Gross = 100k + 2k = 102k
      expect(breakdown[4]!['gross'], 102000);
      // Deductions = 0
      expect(breakdown[4]!['deductions'], 0);
      // Verify take-home calculation
      final tax = breakdown[4]!['tax']!;
      final expectedTakeHome = 102000 - tax;
      expect(breakdown[4]!['takeHome'], closeTo(expectedTakeHome, 1));
    });

    test(
        'Exemption Refactor: independentExemptions reduce taxable income and show in exemption display',
        () {
      final rules = TaxRules(
        slabs: [
          const TaxSlab(400000, 0),
          const TaxSlab(800000, 5),
          const TaxSlab(1200000, 10),
          const TaxSlab(double.infinity, 30),
        ],
        stdDeductionSalary: 75000,
        rebateLimit: 1200000,
        isStdDeductionSalaryEnabled: true,
      );

      final data = TaxYearData(
        year: 2025,
        salary: SalaryDetails(
          history: [
            SalaryStructure(
              id: 's1',
              effectiveDate: DateTime(2025, 4, 1),
              monthlyBasic: 110000, // 1.32M annual
            )
          ],
          independentExemptions: [
            const CustomExemption(
              id: 'test-id',
              name: 'Huge Planning',
              amount: 200000,
            )
          ],
        ),
      );

      final breakdown = taxService.calculateMonthlySalaryBreakdown(data, rules);
      final april = breakdown[4]!;

      expect(april['tax']!, closeTo(0, 1));
      expect(april['taxSavingsForecast']!, closeTo(0, 1));
      expect(april['exemption']!, closeTo(16666, 100));
    });

    test('Applies Marginal Relief for income slightly above rebate limit', () {
      final data = TaxYearData(
          year: 2025,
          salary: SalaryDetails(history: [
            SalaryStructure(
                id: 'test',
                monthlyBasic: 800000 / 12,
                effectiveDate: DateTime(2025, 4, 1))
          ]));

      final result = taxService.calculateDetailedLiability(data, defaultRules);

      // Tax on 7.25L (New Regime): 3-6 (15k), 6-7.25 (12.5k). Total = 27.5k.
      // Excess Income = 7.25L - 7L = 25k.
      // Marginal Relief caps taxBeforeCess at 25k.
      // Cess 4% on 25k = 1000. Total = 26000.
      expect(result['totalTax'], closeTo(26000, 1));
    });

    test('Marginal Tax debugging for 13.5L user scenario', () {
      final data = TaxYearData(
          year: 2026, // FY 2025-26 -> rules for 2026
          salary: SalaryDetails(history: [
            SalaryStructure(
                id: 'test',
                monthlyBasic: 1350000 / 12,
                effectiveDate: DateTime(2025, 4, 1))
          ], npsEmployer: 35000));

      // By default, defaultRules has rebateLimit=700000. We need to mock rules for 2026?
      // Actually, defaultRules has what the test setup gave it.
      // Let's create a custom rule with 12L rebate.
      final rules = defaultRules.copyWith(rebateLimit: 1200000);

      final details = taxService.calculateDetailedLiability(data, rules);

      // Expected Taxable: 13,50,000 - 75,000 (std) - 35,000 (nps) = 12,40,000
      expect(details['totalTax'], closeTo(41600, 0.01));
    });

    test('LTCG Equity handles 1.25L exemption correctly', () {
      final rules = defaultRules.copyWith(
          stdExemption112A: 125000,
          isCGRatesEnabled: true,
          ltcgRateEquity: 12.5);

      final data = TaxYearData(year: 2025, capitalGains: [
        CapitalGainEntry(
            description: 'Stocks',
            saleAmount: 1000000,
            costOfAcquisition: 0, // 10L gain
            gainDate: DateTime(2025, 5, 1),
            matchAssetType: AssetType.equityShares,
            isLTCG: true),
      ]);

      final result = taxService.calculateDetailedLiability(data, rules);
      // Gain = 10L. Exemption = 125k. Taxable = 8.75L.
      // Tax @ 12.5% = 109375.
      expect(result['specialTax'], 109375);
    });

    test('Handles Cash Gifts correctly (Exempt vs Taxable)', () {
      const data = TaxYearData(year: 2025, cashGifts: [
        OtherIncome(name: 'G1', amount: 40000, type: 'Gift', subtype: 'Other'),
        OtherIncome(
            name: 'G2', amount: 100000, type: 'Gift', subtype: 'Marriage'),
      ]);

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

  group('IndianTaxService - Aggregate Summaries (UI Helpers)', () {
    test('Calculates total Business turnover and income', () {
      const data = TaxYearData(year: 2025, businessIncomes: [
        BusinessEntity(name: 'B1', grossTurnover: 100000, netIncome: 10000),
        BusinessEntity(name: 'B2', grossTurnover: 200000, netIncome: 30000),
      ]);

      final totalTurnover =
          data.businessIncomes.fold(0.0, (sum, b) => sum + b.grossTurnover);
      final totalNet =
          data.businessIncomes.fold(0.0, (sum, b) => sum + b.netIncome);

      expect(totalTurnover, 300000);
      expect(totalNet, 40000);
    });

    test('Calculates total House Property rent and interest', () {
      const data = TaxYearData(year: 2025, houseProperties: [
        HouseProperty(
            name: 'HP1',
            isSelfOccupied: false,
            rentReceived: 100000,
            interestOnLoan: 10000),
        HouseProperty(name: 'HP2', isSelfOccupied: true, interestOnLoan: 20000),
      ]);

      final totalRent = data.houseProperties
          .where((h) => !h.isSelfOccupied)
          .fold(0.0, (sum, h) => sum + h.rentReceived);
      final totalInterest =
          data.houseProperties.fold(0.0, (sum, h) => sum + h.interestOnLoan);

      expect(totalRent, 100000);
      expect(totalInterest, 30000);
    });
  });

  group('IndianTaxService Partial Integration', () {
    late IndianTaxService service;
    late TaxRules rules;
    late TaxYearData baseData;

    setUp(() {
      service = IndianTaxService(mockConfig);

      // Default Rules mimicking New Regime FY 25-26
      rules = TaxRules(
          // slabs: List of TaxSlab(upto, rate) positional
          slabs: const [
            TaxSlab(300000, 0),
            TaxSlab(600000, 5),
            TaxSlab(900000, 10),
            TaxSlab(1200000, 15),
            TaxSlab(1500000, 20),
            TaxSlab(double.infinity, 30),
          ],
          stdDeductionSalary: 75000,
          rebateLimit: 700000, // 87A Limit
          agricultureIncomeThreshold: 5000,
          agricultureBasicExemptionLimit:
              300000, // Matching Slab 0 for test clarity
          isCashGiftExemptionEnabled: false,
          jurisdiction: 'India',
          customExemptions: const [],
          tagMappings: const {},
          cessRate: 4.0);

      when(() => mockConfig.getRulesForYear(any())).thenReturn(rules);
      baseData = const TaxYearData(
          year: 2025, // int
          salary: SalaryDetails(history: []),
          houseProperties: [],
          businessIncomes: [],
          capitalGains: [],
          otherIncomes: [],
          dividendIncome: DividendIncome(),
          tdsEntries: [],
          tcsEntries: [],
          agriIncomeHistory: []);
    });

    test('Should NOT apply Partial Integration if Agri Income <= Threshold',
        () {
      final data = baseData.copyWith(
          agriIncomeHistory: [
            AgriIncomeEntry(id: 'a1', amount: 4000, date: DateTime(2025, 4, 1))
          ],
          salary: SalaryDetails(history: [
            SalaryStructure(
                id: 'test',
                monthlyBasic: 1075000 / 12,
                effectiveDate: DateTime(2025, 4, 1))
          ]));

      final liability = service.calculateDetailedLiability(data, rules);
      // Net Taxable = 10L.
      // Tax on 10L (Slabs: 0-3:0, 3-6:15k, 6-9:30k, 9-10:15k) = 60,000.
      // Cess 4% = 2400.
      // Total = 62,400.

      expect(liability['totalTax'], closeTo(62400, 1));
    });

    test(
        'Should apply Partial Integration if Agri > Threshold and Income > Basic Limit',
        () {
      // Setup: Agri 10k, Net 10L.
      // Agri Basic Limit 3L (matches slab 0).

      // Step 1: Tax(10L + 10k = 10.1L).
      // 0-3: 0
      // 3-6: 15k
      // 6-9: 30k
      // 9-12 (15%): 1.1L * 0.15 = 16,500.
      // Total Step 1 = 61,500.

      // Step 2: Tax(Basic(3L) + Agri(10k) = 3.1L).
      // 0-3: 0
      // 3-6 (5%): 0.1L * 0.05 = 500.
      // Total Step 2 = 500.

      // Slab Tax = 61,500 - 500 = 61,000.
      // Normal Tax was 60,000. So +1000 increase.

      // Cess 4% on 61,000 = 2440.
      // Total = 63,440.

      final data = baseData.copyWith(
        agriIncomeHistory: [
          AgriIncomeEntry(id: 'a1', amount: 10000, date: DateTime(2025, 4, 1))
        ],
        salary: SalaryDetails(history: [
          SalaryStructure(
              id: 's1',
              monthlyBasic: 1075000 / 12,
              effectiveDate: DateTime(2025, 4, 1))
        ]), // Net 10L
      );

      final liability = service.calculateDetailedLiability(data, rules);
      expect(liability['totalTax'], closeTo(63440, 1));
    });

    test('Should use Configurable Basic Exemption Limit correctly', () {
      // Set Config Limit to 4L (higher than slab 0 of 3L).
      // This implies a "discount" as discussed.

      rules = rules.copyWith(agricultureBasicExemptionLimit: 400000);

      final data = baseData.copyWith(
        agriIncomeHistory: [
          AgriIncomeEntry(id: 'a1', amount: 10000, date: DateTime(2025, 4, 1))
        ],
        salary: SalaryDetails(history: [
          SalaryStructure(
              id: 's1',
              monthlyBasic: 1075000 / 12,
              effectiveDate: DateTime(2025, 4, 1))
        ]), // Net 10L
      );

      // Step 1 (10.1L) Tax = 61,500.

      // Step 2 (4L + 10k = 4.1L).
      // 0-3: 0
      // 3-6 (5%): 1.1L * 0.05 = 5,500.

      // Slab Tax = 61,500 - 5,500 = 56,000.
      // Cess 4% = 2240.
      // Total = 58,240.

      final liability = service.calculateDetailedLiability(data, rules);
      expect(liability['totalTax'], closeTo(58240, 1));
    });

    test('Agri Income + Marginal Relief interaction', () {
      // Scenario: Net Taxable = 7,00,100 (New Regime limit 7L).
      // Agri = 1,00,000.
      // Basic Limit 3L.
      rules = rules.copyWith(rebateLimit: 700000);

      final data = baseData.copyWith(
        agriIncomeHistory: [
          AgriIncomeEntry(id: 'a1', amount: 100000, date: DateTime(2025, 4, 1))
        ],
        salary: SalaryDetails(history: [
          SalaryStructure(
              id: 's1',
              monthlyBasic: 775100 / 12, // 775100 - 75000 = 700100
              effectiveDate: DateTime(2025, 4, 1))
        ]),
      );

      final liability = service.calculateDetailedLiability(data, rules);
      // Tax on 7,00,100 + 1L = 8,00,100.
      // Slabs: 0-3:0, 3-6:15k, 6-8.001 (10%): 20,010. Total Step 1 = 35,010.
      // Step 2: Tax(3L + 1L = 4L). 0-3:0, 3-4 (5%): 5000. Total Step 2 = 5000.
      // Slab Tax = 35,010 - 5000 = 30,010.
      // Special Tax = 0.
      // Tax Before Cess = 30,010.
      // Total Taxable = 7,00,100.
      // Excess over 7L = 100.
      // Marginal Relief: If tax (30,010) > excess (100), tax = 100.
      // Cess 4% on 100 = 4. Total = 104.

      expect(liability['totalTax'], closeTo(104, 1));
    });

    test('Agri Income + Multiple Heads (Combined non-agri income)', () {
      // Scenario: Salary (Net after deductions) = 5L, Business = 5L.
      // Total Slab Income = 10L.
      // Agri = 50,000. Threshold = 5k. Basic = 3L.
      final data = baseData.copyWith(
        agriIncomeHistory: [
          AgriIncomeEntry(id: 'a1', amount: 50000, date: DateTime(2025, 4, 1))
        ],
        salary: SalaryDetails(history: [
          SalaryStructure(
              id: 's1',
              monthlyBasic: 575000 / 12, // 5L + 75k std
              effectiveDate: DateTime(2025, 4, 1))
        ]),
        businessIncomes: [
          const BusinessEntity(
              name: 'Shop', netIncome: 500000, type: BusinessType.regular)
        ],
      );

      final liability = service.calculateDetailedLiability(data, rules);
      // Step 1: Tax(10L + 50k = 10.5L).
      // 0-3:0, 3-6:15k, 6-9:30k, 9-10.5(15%): 1.5L*0.15=22.5k.
      // Total Step 1 = 15k + 30k + 22.5k = 67,500.
      // Step 2: Tax(Basic(3L) + Agri(50k) = 3.5L).
      // 0-3:0, 3-3.5 (5%): 2,500.
      // Total Step 2 = 2,500.
      // Slab Tax = 67,500 - 2,500 = 65,000.
      // Total = 65,000 * 1.04 = 67,600.
      expect(liability['totalTax'], closeTo(67600, 1));
    });

    test('Boundary: Integration only when Slab Income > Basic Limit', () {
      // Scenario: Salary = 3L (Exactly basic limit). Agri = 1L.
      final data = baseData.copyWith(
        agriIncomeHistory: [
          AgriIncomeEntry(id: 'a1', amount: 100000, date: DateTime(2025, 4, 1))
        ],
        salary: SalaryDetails(history: [
          SalaryStructure(
              id: 's1',
              monthlyBasic: 375000 / 12,
              effectiveDate: DateTime(2025, 4, 1))
        ]),
      );

      final liability = service.calculateDetailedLiability(data, rules);
      // Net Taxable = 3L. Agri integration should NOT trigger.
      // Tax on 3L = 0.
      expect(liability['totalTax'], 0);
    });

    test('Agri Income with Capital Gains (Special Rate Isolation)', () {
      // Scenario: Salary = 2L (Below 3L limit), STCG = 2L.
      // Total non-agri income = 4L (> 3L limit).
      // BUT Slab income = 2L (<= 3L limit).
      // Partial integration should NOT trigger.

      final data = baseData.copyWith(
        agriIncomeHistory: [
          AgriIncomeEntry(id: 'a1', amount: 100000, date: DateTime(2025, 4, 1))
        ],
        salary: SalaryDetails(history: [
          SalaryStructure(
              id: 's1',
              monthlyBasic: 275000 / 12,
              effectiveDate: DateTime(2025, 4, 1))
        ]),
        capitalGains: [
          CapitalGainEntry(
              description: 'Stocks',
              saleAmount: 200000,
              costOfAcquisition: 0,
              gainDate: DateTime(2025, 6, 1),
              matchAssetType: AssetType.other, // STCG at special rate
              isLTCG: false),
        ],
      );

      rules = rules.copyWith(isCGRatesEnabled: true, stcgRate: 15.0);

      final liability = service.calculateDetailedLiability(data, rules);

      // Special Tax: 2L * 15% = 30,000.
      // Slab Tax: 0 (since Slab Income 2L < 3L).
      // Total Taxable Income = 4L. (Rebate Limit is 7L, so fully rebated if enabled).
      // Let's check rebate behavior.
      expect(liability['totalTax'], 0); // Rebate applies (Total 4L <= 7L)

      // Turn off rebate to see the specific integration behavior.
      rules = rules.copyWith(isRebateEnabled: false);
      final liabilityNoRebate = service.calculateDetailedLiability(data, rules);
      // If integration applied:
      // Step 1 (Slab 2L + Agri 1L = 3L): Tax = 0.
      // Step 2 (Limit 3L + Agri 1L = 4L): Tax = 5000.
      // 0 - 5000 = -5000? No, clamped at slab level.
      // The core concern is whether it ADDED to the tax.
      // Here slab income is below limit, so result should be same as no agri income.
      expect(liabilityNoRebate['slabTax'], 0);
      expect(liabilityNoRebate['specialTax'], 30000);
    });
  });

  group('Tax Breakdown Logic Tests', () {
    late IndianTaxService service;
    late BreakdownMockConfig mockConfig;

    setUp(() {
      mockConfig = BreakdownMockConfig();
      service = IndianTaxService(mockConfig);
    });

    test('Marginal Tax Spike for One-Time Bonus', () {
      // ... previous test ...
      final s1 = SalaryStructure(
          id: 's1', effectiveDate: DateTime(2025, 4, 1), monthlyBasic: 100000);
      final data = TaxYearData(
          year: 2025,
          salary: SalaryDetails(history: [
            s1
          ], independentAllowances: [
            const CustomAllowance(
                id: 'bonus_spike',
                name: 'Bonus',
                payoutAmount: 500000,
                frequency: PayoutFrequency.custom,
                customMonths: [10]),
          ]));
      final rules = mockConfig.getRulesForYear(2025);
      final breakdown = service.calculateMonthlySalaryBreakdown(data, rules);
      double septTax = breakdown[9]?['tax'] ?? 0;
      double octTax = breakdown[10]?['tax'] ?? 0;
      expect(octTax, greaterThan(septTax * 2));
    });

    test('Stepped Tax for Salary Hike (13.5L to 19L + NPS 35k)', () {
      final s1 = SalaryStructure(
          id: 's1',
          effectiveDate: DateTime(2025, 4, 1),
          monthlyBasic: 112500); // 13.5L
      final s2 = SalaryStructure(
          id: 's2',
          effectiveDate: DateTime(2025, 7, 1),
          monthlyBasic: 158333); // 19L
      final data = TaxYearData(
          year: 2025,
          salary: SalaryDetails(npsEmployer: 35777, history: [s1, s2]));
      final rules = mockConfig.getRulesForYear(2025);
      final breakdown = service.calculateMonthlySalaryBreakdown(data, rules);

      // With Blind Projection, April tax only sees 13.5L.
      // 13.5L Gross - 75k Std - 35k NPS = 12.4L Taxable.
      // Tax on 12.4L (New Regime) = 60k (at 12L) + 4k (excess) = 64k?
      // No, Marginal Relief: Tax = excess over 12L = 40,000.
      // 40,000 * 1.04 cess = 41600. 41600 / 12 = 3466.
      double aprTax = breakdown[4]?['tax'] ?? 0;
      double julTax = breakdown[7]?['tax'] ?? 0;

      expect(aprTax, closeTo(3400, 100));
      expect(julTax,
          greaterThan(aprTax * 2)); // Big jump in July to catch up to 19L avg
    });

    test('Benchmark: 13.35L Income with 110k Deductions (75k Std + 35k NPS)',
        () {
      final s1Val = SalaryStructure(
        id: 's1',
        effectiveDate: DateTime(2025, 4, 1),
        monthlyBasic: 111250, // 1,335,000 / 12
      );

      final data = TaxYearData(
          year: 2025,
          salary: SalaryDetails(npsEmployer: 35000, history: [s1Val]));

      final rules = mockConfig
          .getRulesForYear(2025)
          .copyWith(stdDeductionSalary: 75000, rebateLimit: 1200000);

      final details = service.calculateDetailedLiability(data, rules);
      expect(details['slabTax'], closeTo(25000, 1));

      final breakdown = service.calculateMonthlySalaryBreakdown(data, rules);
      double aprTax = breakdown[4]?['tax'] ?? 0;
      expect(aprTax * 12, closeTo(26000, 50));
    });

    test('Regression: Mid-year Hike Simulation (Blind Step Behavior)', () {
      // April structure: 10L Annual
      final s1 = SalaryStructure(
          id: 's1', effectiveDate: DateTime(2025, 4, 1), monthlyBasic: 83333);
      // July hike: 24L Annual
      final s2 = SalaryStructure(
          id: 's2', effectiveDate: DateTime(2025, 7, 1), monthlyBasic: 200000);

      final data =
          TaxYearData(year: 2025, salary: SalaryDetails(history: [s1, s2]));

      final rules = mockConfig.getRulesForYear(2025);
      final breakdown = service.calculateMonthlySalaryBreakdown(data, rules);

      // In April, projection only "sees" 10L. Tax should be 0.
      expect(breakdown[4]?['tax'], closeTo(0, 1));
      // In July, hike happens. Total annual approx 20.5L.
      // July tax should jump to catch up.
      expect(breakdown[7]?['tax'], greaterThan(15000));
    });

    test('Regression: Bonus Tax at 12L Rebate Boundary (New Regime)', () {
      // Annual Salary 12.75L Gross -> 12L Taxable (Net 0 tax in New Regime FY 25-26)
      final s1 = SalaryStructure(
        id: 's1',
        effectiveDate: DateTime(2025, 4, 1),
        monthlyBasic: 100000,
        monthlyFixedAllowances: 6250, // 106250 monthly -> 12.75L annual
      );
      final data = TaxYearData(
          year: 2025,
          salary: SalaryDetails(history: [
            s1
          ], independentAllowances: [
            const CustomAllowance(
                id: 'bonus_rebate',
                name: 'Bonus',
                payoutAmount: 12000,
                frequency: PayoutFrequency.custom,
                customMonths: [10]), // October bonus
          ]));

      final rules =
          mockConfig.getRulesForYear(2025).copyWith(rebateLimit: 1200000);
      final breakdown = service.calculateMonthlySalaryBreakdown(data, rules);

      double octTax = breakdown[10]?['tax'] ?? 0;
      double sepTax = breakdown[9]?['tax'] ?? 0;

      // Without bonus, annual taxable is 12L (Tax 0).
      // With 12k bonus, taxable is 12.12L. Tax is capped at excess over 12L = 12k.
      // So October tax should should include the 12k marginal tax.
      expect(octTax, greaterThan(11500));
      expect(sepTax,
          closeTo(0, 10)); // Baseline tax should be 0 or small smoothing
    });

    test('Regression: Mid-year Hike Visibility in Take-Home', () {
      final s1 = SalaryStructure(
          id: 's1', effectiveDate: DateTime(2025, 4, 1), monthlyBasic: 100000);
      final s2 = SalaryStructure(
          id: 's2',
          effectiveDate: DateTime(2025, 7, 1), // Hike in July
          monthlyBasic: 150000);
      final data =
          TaxYearData(year: 2025, salary: SalaryDetails(history: [s1, s2]));

      final rules = mockConfig.getRulesForYear(2025);
      final breakdown = service.calculateMonthlySalaryBreakdown(data, rules);

      double aprTakeHome = breakdown[4]?['takeHome'] ?? 0;
      double julTakeHome = breakdown[7]?['takeHome'] ?? 0;

      // With Blind Projection, April tax is 0 (since 1.2L < 12L rebate).
      // So April TakeHome is just 100k.
      expect(aprTakeHome, 100000);

      // In July, the hike happens.
      expect(julTakeHome, lessThan(150000));
      expect(julTakeHome, closeTo(135500, 2000)); // 150k - ~14.5k tax catch-up
    });

    test('Regression: Mixed Income Isolation', () {
      final s1 = SalaryStructure(
          id: 's1', effectiveDate: DateTime(2025, 4, 1), monthlyBasic: 100000);

      final dataWithOtherIncome = TaxYearData(
          year: 2025,
          salary: SalaryDetails(history: [s1]),
          houseProperties: [
            const HouseProperty(
                name: 'Home', rentReceived: 50000 * 12, interestOnLoan: 200000),
          ],
          businessIncomes: [
            const BusinessEntity(
                name: 'Store', netIncome: 1000000, type: BusinessType.regular),
          ]);

      final dataSalaryOnly =
          TaxYearData(year: 2025, salary: SalaryDetails(history: [s1]));

      final rules = mockConfig.getRulesForYear(2025);
      final breakdownMixed =
          service.calculateMonthlySalaryBreakdown(dataWithOtherIncome, rules);
      final breakdownSalaryOnly =
          service.calculateMonthlySalaryBreakdown(dataSalaryOnly, rules);

      // April Tax should be identical despite high HP and Business income
      expect(breakdownMixed[4]?['tax'], breakdownSalaryOnly[4]?['tax']);
      expect(
          breakdownMixed[4]?['takeHome'], breakdownSalaryOnly[4]?['takeHome']);
    });

    test('Regression: Future Partial Allowance Impact', () {
      final s1 = SalaryStructure(
          id: 's1',
          effectiveDate: DateTime(2025, 4, 1),
          monthlyBasic: 100000,
          customAllowances: [
            const CustomAllowance(
                id: 'bonus_partial_small',
                name: 'Bonus',
                payoutAmount: 0,
                isPartial: true,
                frequency: PayoutFrequency.monthly,
                partialAmounts: {
                  6: 120000, // Large bonus in June
                }),
          ]);

      final dataSmallBonus =
          TaxYearData(year: 2025, salary: SalaryDetails(history: [s1]));

      final s2 = s1.copyWith(customAllowances: [
        s1.customAllowances.first
            .copyWith(id: 'bonus_partial_large', partialAmounts: {
          6: 240000, // Doubled bonus in June
        }),
      ]);

      final dataLargeBonus =
          TaxYearData(year: 2025, salary: SalaryDetails(history: [s2]));

      final rules = mockConfig.getRulesForYear(2025);

      final breakdownSmall =
          service.calculateMonthlySalaryBreakdown(dataSmallBonus, rules);
      final breakdownLarge =
          service.calculateMonthlySalaryBreakdown(dataLargeBonus, rules);

      // REVERTED to match Blind behavior: April tax should be IDENTICAL
      // because it only sees current structure (which is same) and
      // ignores future partial payouts in other months.
      expect(breakdownLarge[4]?['tax'] ?? 0,
          closeTo(breakdownSmall[4]?['tax'] ?? 0, 1));
    });

    test('Tax Sum Validation (Total vs Monthly Sum)', () {
      final s1 = SalaryStructure(
        id: 's1',
        effectiveDate: DateTime(2025, 4, 1),
        monthlyBasic: 100000, // 12L Annual
      );
      final data = TaxYearData(
          year: 2025,
          salary: SalaryDetails(history: [
            s1
          ], independentAllowances: [
            const CustomAllowance(
                id: 'irregular_bonus',
                name: 'Bonus',
                payoutAmount: 50000,
                frequency: PayoutFrequency.custom,
                customMonths: [10]),
          ]));

      final rules = mockConfig.getRulesForYear(2025);

      final liability = service.calculateDetailedLiability(data, rules);
      double expectedTotalTax = liability['totalTax'] ?? 0;

      final breakdown = service.calculateMonthlySalaryBreakdown(data, rules);
      double sumMonthlyTax = 0;
      for (var m in [4, 5, 6, 7, 8, 9, 10, 11, 12, 1, 2, 3]) {
        sumMonthlyTax += (breakdown[m]?['tax'] ?? 0);
      }

      expect(sumMonthlyTax, closeTo(expectedTotalTax, 10),
          reason: "Sum of monthly taxes should equal total annual tax.");
    });

    test('Regression: isPartial Allowance added to Gross', () {
      final s1 = SalaryStructure(
          id: 's1',
          effectiveDate: DateTime(2025, 4, 1),
          monthlyBasic: 100000,
          customAllowances: [
            const CustomAllowance(
              id: 'incentive_partial',
              name: 'Incentive',
              payoutAmount: 0,
              isPartial: true,
              frequency: PayoutFrequency.monthly,
              partialAmounts: {4: 5000}, // 5k in April
            ),
          ]);
      final data = TaxYearData(
          year: 2025,
          salary: SalaryDetails(history: [
            s1
          ], independentAllowances: [
            const CustomAllowance(
              id: 'ind_incentive_partial',
              name: 'Ind Incentive',
              payoutAmount: 0,
              isPartial: true,
              frequency: PayoutFrequency.monthly,
              partialAmounts: {4: 3000}, // 3k in April
            ),
          ]));

      final rules = mockConfig.getRulesForYear(2025);
      final breakdown = service.calculateMonthlySalaryBreakdown(data, rules);
      expect(breakdown[4]?['gross'], 108000);
    });

    test('Regression: Custom Exemption in Take-Home', () {
      final s1 = SalaryStructure(
        id: 's1',
        effectiveDate: DateTime(2025, 4, 1),
        monthlyBasic: 100000, // 12L Annual
      );
      final data = TaxYearData(
          year: 2025,
          salary: SalaryDetails(history: [
            s1
          ], independentExemptions: [
            const CustomExemption(
              id: 'rent_receipt_exemption',
              name: 'Rent Receipt',
              amount: 120000, // 10k monthly -> 120k annual
            ),
          ]));

      final rules = mockConfig.getRulesForYear(2025);
      final breakdown = service.calculateMonthlySalaryBreakdown(data, rules);

      final april = breakdown[4];
      expect(april?['gross'], 100000);
      expect(april?['tax'], 0);
      expect(april?['takeHome'], 100000);
    });

    test('Regression: Independent Deductions in Take-Home', () {
      final s1 = SalaryStructure(
        id: 's1',
        effectiveDate: DateTime(2025, 4, 1),
        monthlyBasic: 100000, // 12L Annual
      );
      final data = TaxYearData(
          year: 2025,
          salary: SalaryDetails(history: [
            s1
          ], independentDeductions: [
            const CustomDeduction(
                id: 'd1',
                name: 'Test',
                amount: 5000,
                frequency: PayoutFrequency.monthly),
            const CustomDeduction(
                id: 'd2',
                name: 'Professional Tax',
                amount: 200,
                frequency: PayoutFrequency.monthly),
            const CustomDeduction(
              id: 'd3',
              name: 'One-off Fine',
              amount: 0,
              isPartial: true,
              frequency: PayoutFrequency.monthly,
              partialAmounts: {4: 1000}, // Only in April
            ),
          ]));

      final rules = mockConfig.getRulesForYear(2025);
      final breakdown = service.calculateMonthlySalaryBreakdown(data, rules);

      final april = breakdown[4];
      expect(april?['gross'], 100000);
      expect(april?['tax'], 0);
      expect(april?['deductions'], 6200);
      expect(april?['takeHome'], 93800);
    });

    test('IndianTaxService applying Cliff Exemption on Salary Allowance', () {
      const standardAllowance = CustomAllowance(
          id: 'std_allowance',
          name: 'Standard Allowance',
          payoutAmount: 10000,
          exemptionLimit: 5000,
          isCliffExemption: false,
          frequency: PayoutFrequency.monthly);

      const cliffAllowanceTaxable = CustomAllowance(
          id: 'cliff-t',
          name: 'Cliff Taxable',
          payoutAmount: 10000,
          exemptionLimit: 5000,
          isCliffExemption: true,
          frequency: PayoutFrequency.monthly);

      const cliffAllowanceExempt = CustomAllowance(
          id: 'cliff-e',
          name: 'Cliff Exempt',
          payoutAmount: 4000,
          exemptionLimit: 5000,
          isCliffExemption: true,
          frequency: PayoutFrequency.monthly);

      final s1 = SalaryStructure(
          id: 's1',
          effectiveDate: DateTime(2025, 4, 1),
          customAllowances: [
            standardAllowance,
            cliffAllowanceTaxable,
            cliffAllowanceExempt
          ]);

      final data =
          TaxYearData(year: 2025, salary: SalaryDetails(history: [s1]));

      final rules = mockConfig.getRulesForYear(2025);
      final breakdown = service.calculateMonthlySalaryBreakdown(data, rules);

      expect(breakdown[4]?['gross'], 24000);

      double exemptions = service.calculateSalaryExemptions(data, rules);
      expect(exemptions, closeTo(9000 * 12, 1.0));
    });

    test('IndianTaxService calculates dynamic Advance Tax Interest', () {
      withClock(Clock.fixed(DateTime(2026, 4, 1)), () {
        final data = TaxYearData(
            year: 2025,
            salary: SalaryDetails(history: [
              SalaryStructure(
                  id: 's1',
                  effectiveDate: DateTime(2025, 4, 1),
                  monthlyBasic: 500000)
            ]),
            tdsEntries: []);

        final dynamicRules = TaxRules(
            isCessEnabled: false,
            enableAdvanceTaxInterest: true,
            advanceTaxRules: const [
              AdvanceTaxInstallmentRule(
                  startMonth: 4,
                  startDay: 1,
                  endMonth: 6,
                  endDay: 15,
                  requiredPercentage: 15.0,
                  interestRate: 1.0),
              AdvanceTaxInstallmentRule(
                  startMonth: 6,
                  startDay: 16,
                  endMonth: 9,
                  endDay: 15,
                  requiredPercentage: 45.0,
                  interestRate: 1.0),
              AdvanceTaxInstallmentRule(
                  startMonth: 9,
                  startDay: 16,
                  endMonth: 12,
                  endDay: 15,
                  requiredPercentage: 75.0,
                  interestRate: 1.0),
              AdvanceTaxInstallmentRule(
                  startMonth: 12,
                  startDay: 16,
                  endMonth: 3,
                  endDay: 15,
                  requiredPercentage: 100.0,
                  interestRate: 1.0),
            ]);

        final result1 = service.calculateDetailedLiability(data, dynamicRules);
        double expectedPayable =
            result1['totalTax']! - result1['tds']! - result1['tcs']!;

        double expectedInterestBase = (expectedPayable * 0.15 * 0.03) +
            (expectedPayable * 0.45 * 0.03) +
            (expectedPayable * 0.75 * 0.03) +
            (expectedPayable * 1.00 * 0.01);

        expect(
            result1['advanceTaxInterest'], closeTo(expectedInterestBase, 10));

        final dataPaid = data.copyWith(advanceTaxEntries: [
          TaxPaymentEntry(
              id: 'adv-tax-1', amount: 100000, date: DateTime(2025, 6, 1)),
          TaxPaymentEntry(
              id: 'adv-tax-2', amount: 165000, date: DateTime(2025, 8, 1)),
          TaxPaymentEntry(
              id: 'adv-tax-3', amount: 142000, date: DateTime(2025, 12, 17)),
        ]);

        final result2 =
            service.calculateDetailedLiability(dataPaid, dynamicRules);

        double junShortfall = max(0.0, (expectedPayable * 0.15) - 100000);
        double sepShortfall = max(0.0, (expectedPayable * 0.45) - 265000);
        double decShortfall = max(0.0, (expectedPayable * 0.75) - 265000);
        double marShortfall = max(0.0, (expectedPayable * 1.00) - 407000);

        double expectedPaidInterest = (junShortfall * 0.03) +
            (sepShortfall * 0.03) +
            (decShortfall * 0.03) +
            (marShortfall * 0.01);

        expect(result2['advanceTaxInterest'], closeTo(expectedPaidInterest, 5));
      });
    });

    test('User Scenario: 14L to 20L Hike with Mid-Quarter Bonus', () {
      final s1 = SalaryStructure(
          id: 's1',
          effectiveDate: DateTime(2025, 4, 1),
          monthlyBasic: 116666); // 14L annual gross
      final s2 = SalaryStructure(
          id: 's2',
          effectiveDate: DateTime(2025, 7, 1), // Hike in July
          monthlyBasic: 166666); // 20L annual gross

      final data = TaxYearData(
          year: 2025,
          salary: SalaryDetails(history: [
            s1,
            s2
          ], independentAllowances: [
            const CustomAllowance(
                id: 'bonus_sep',
                name: 'Bonus',
                payoutAmount: 50000,
                frequency: PayoutFrequency.custom,
                customMonths: [9]), // September bonus
          ]));

      final rules = mockConfig.getRulesForYear(2025);
      final breakdown = service.calculateMonthlySalaryBreakdown(data, rules);

      // Verify June (Old structure, Blind)
      final juneTax = breakdown[6]?['tax'] ?? 0;
      expect(juneTax, isPositive);

      // Verify September (New structure + Bonus)
      expect(breakdown[9]?['gross'], closeTo(166666 + 50000, 1));
      final sepTax = breakdown[9]?['tax'] ?? 0;
      final augTax = breakdown[8]?['tax'] ?? 0;

      // September tax should have a spike due to marginalBonusTax
      expect(sepTax, greaterThan(augTax));

      // Final Check: Monthly Sum vs Total Liability
      double totalLiability =
          service.calculateDetailedLiability(data, rules)['totalTax']!;
      double monthlySum = 0;
      for (var m in [4, 5, 6, 7, 8, 9, 10, 11, 12, 1, 2, 3]) {
        monthlySum += (breakdown[m]?['tax'] ?? 0);
      }

      expect(monthlySum, closeTo(totalLiability, 10));
    });
  });
}
