import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/models/taxes/tax_data.dart';
import 'package:samriddhi_flow/models/taxes/tax_data_models.dart';
import 'package:samriddhi_flow/models/taxes/tax_rules.dart';
import 'package:samriddhi_flow/services/taxes/indian_tax_service.dart';
import 'package:samriddhi_flow/services/taxes/tax_config_service.dart';
import 'package:clock/clock.dart';

class MockTaxConfigService extends Mock implements TaxConfigService {}

void main() {
  late IndianTaxService taxService;
  late MockTaxConfigService mockConfig;

  final defaultRules = TaxRules(
    slabs: const [
      TaxSlab(300000, 0),
      TaxSlab(600000, 5),
      TaxSlab(900000, 10),
      TaxSlab(1200000, 15),
      TaxSlab(1500000, 20),
      TaxSlab(TaxRules.infinitySubstitute, 30),
    ],
    stdDeductionSalary: 75000,
    rebateLimit: 700000,
    cessRate: 4,
    isStdDeductionSalaryEnabled: true,
    isRebateEnabled: true,
    isCessEnabled: true,
    enableAdvanceTaxInterest: true,
    advanceTaxRules: const [
      AdvanceTaxInstallmentRule(
          startMonth: 4,
          startDay: 1,
          endMonth: 6,
          endDay: 15,
          requiredPercentage: 15,
          interestRate: 1.0),
      AdvanceTaxInstallmentRule(
          startMonth: 6,
          startDay: 16,
          endMonth: 9,
          endDay: 15,
          requiredPercentage: 45,
          interestRate: 1.0),
      AdvanceTaxInstallmentRule(
          startMonth: 9,
          startDay: 16,
          endMonth: 12,
          endDay: 15,
          requiredPercentage: 75,
          interestRate: 1.0),
      AdvanceTaxInstallmentRule(
          startMonth: 12,
          startDay: 16,
          endMonth: 3,
          endDay: 15,
          requiredPercentage: 100,
          interestRate: 1.0),
    ],
  );

  setUp(() {
    mockConfig = MockTaxConfigService();
    taxService = IndianTaxService(mockConfig);
    when(() => mockConfig.getRulesForYear(any())).thenReturn(defaultRules);
  });

  group('IndianTaxService - Advance Tax & Generated TDS', () {
    test('getGeneratedSalaryTds generates entries based on breakdown', () {
      final structure = SalaryStructure(
        id: 's1',
        effectiveDate: DateTime(2024, 4, 1),
        monthlyBasic: 200000, // 24L per year
      );

      final data = TaxYearData(
        year: 2024,
        salary: SalaryDetails(history: [structure]),
      );

      final generatedTds = taxService.getGeneratedSalaryTds(data, defaultRules);

      expect(generatedTds.length, 12);
      expect(generatedTds.first.amount, 34450);
      expect(generatedTds.first.source, 'Employer (Salary TDS)');
      expect(generatedTds.first.isManualEntry, false);
    });

    test('calculateDetailedLiability includes generated salary TDS', () {
      final structure = SalaryStructure(
        id: 's1',
        effectiveDate: DateTime(2024, 4, 1),
        monthlyBasic: 100000, // 12L per year
      );

      final data = TaxYearData(
        year: 2024,
        salary: SalaryDetails(history: [structure]),
      );

      final result = taxService.calculateDetailedLiability(data, defaultRules);

      expect(result['tds'], 81900);
      expect(result['netTaxPayable'], 0);
    });

    test('baseForAdvanceTax excludes Capital Gains tax', () {
      final rules = defaultRules.copyWith(
        isCGRatesEnabled: true,
        ltcgRateEquity: 12.5,
        stdExemption112A: 0,
      );

      final data = TaxYearData(
        year: 2024,
        salary: SalaryDetails(
          history: [
            SalaryStructure(
              id: 'test',
              monthlyBasic: 1000000 / 12,
              effectiveDate: DateTime(2024, 4, 1),
            )
          ],
        ), // Net 9.25L
        capitalGains: [
          CapitalGainEntry(
            gainDate: DateTime(2024, 6, 1),
            saleAmount: 200000,
            costOfAcquisition: 0,
            isLTCG: true,
            matchAssetType: AssetType.equityShares,
          ),
        ],
      );

      final result = taxService.calculateDetailedLiability(data, rules,
          includeGeneratedTds: false);

      expect(result['baseForAdvanceTax'], closeTo(50700, 1));
      expect(result['specialTax'], 25000);
    });

    test(
        'Advance tax installments don\'t include CG tax shortfall and interest',
        () {
      final structure = SalaryStructure(
        id: 's1',
        effectiveDate: DateTime(2024, 4, 1),
        monthlyBasic: 100000, // 12L per year (Net 11.25L)
      );

      final data = TaxYearData(
        year: 2024,
        salary: SalaryDetails(history: [structure]),
        capitalGains: [
          CapitalGainEntry(
            gainDate: DateTime(2024, 6, 1),
            saleAmount: 400000, // 4L CG
            costOfAcquisition: 0,
            isLTCG: true,
            matchAssetType: AssetType.equityShares,
          ),
        ],
      );

      withClock(Clock.fixed(DateTime(2024, 9, 20)), () {
        final result = taxService.calculateDetailedLiability(
            data,
            defaultRules.copyWith(
              isCGRatesEnabled: true,
              ltcgRateEquity: 12.5,
            ));

        expect(result['baseForAdvanceTax'], 0);
        expect(result['nextAdvanceTaxAmount'], isNull);
        expect(result['advanceTaxInterest'], 0);
      });
    });

    test('daysUntilAdvanceTax is calculated correctly for 15-day reminder', () {
      final rules = defaultRules.copyWith(
        slabs: const [
          TaxSlab(300000, 0),
          TaxSlab(double.infinity, 30),
        ],
        cessRate: 4,
        isRebateEnabled:
            false, // Ensure tax is calculated for income above slab
        advanceTaxRules: const [
          AdvanceTaxInstallmentRule(
            startMonth: 4,
            startDay: 1,
            endMonth: 6,
            endDay: 15,
            requiredPercentage: 15,
            interestRate: 1.0,
          ),
        ],
        advanceTaxReminderDays: 15,
        enableAdvanceTaxInterest: true,
      );

      final data = TaxYearData(
        year: 2025,
        salary: SalaryDetails(
          history: [
            SalaryStructure(
              id: 'test',
              monthlyBasic: 1000000 / 12,
              effectiveDate: DateTime(2025, 4, 1),
            )
          ],
        ),
      );
      when(() => mockConfig.getRulesForYear(2025)).thenReturn(rules);

      withClock(Clock.fixed(DateTime(2025, 6, 1)), () {
        final result = taxService.calculateDetailedLiability(data, rules,
            salaryIncomeOverride: 1000000, includeGeneratedTds: false);

        expect(result['daysUntilAdvanceTax'], 14);
        expect(result['nextAdvanceTaxAmount'], greaterThan(0));
      });
    });

    test('Super Coverage Test: Covers multiple income heads and interest loops',
        () {
      final rules = defaultRules.copyWith(
        isCGRatesEnabled: true,
        ltcgRateEquity: 10,
        stcgRate: 15,
        isStdDeductionHPEnabled: true,
        isAgriIncomeEnabled: true,
        agricultureIncomeThreshold: 5000,
        agricultureBasicExemptionLimit: 250000,
      );

      final data = TaxYearData(
        year: 2024,
        salary: SalaryDetails(
          history: [
            SalaryStructure(
              id: 's1',
              effectiveDate: DateTime(2024, 4, 1),
              monthlyBasic: 83333, // 10L / 12 approx
            )
          ],
        ),
        houseProperties: const [
          HouseProperty(
            name: 'Rental 1',
            rentReceived: 500000,
            municipalTaxes: 10000,
            interestOnLoan: 50000,
            isSelfOccupied: false,
          ),
        ],
        businessIncomes: const [
          BusinessEntity(
            name: 'Consultancy',
            grossTurnover: 2000000,
            netIncome: 1000000,
            type: BusinessType.regular,
          ),
        ],
        otherIncomes: const [
          OtherIncome(
            name: 'Interest',
            amount: 50000,
            type: 'Other',
            subtype: 'other',
          ),
        ],
        agriIncomeHistory: [
          AgriIncomeEntry(id: 'a1', amount: 10000, date: DateTime(2024, 4, 1))
        ],
        capitalGains: [
          CapitalGainEntry(
            description: 'Equity Sale',
            gainDate: DateTime(2024, 5, 20),
            saleAmount: 100000,
            costOfAcquisition: 0,
            isLTCG: true,
            matchAssetType: AssetType.equityShares,
          ),
          CapitalGainEntry(
            description: 'Other Sale',
            gainDate: DateTime(2024, 8, 20),
            saleAmount: 50000,
            costOfAcquisition: 0,
            isLTCG: false,
            matchAssetType: AssetType.other,
          ),
        ],
        advanceTaxEntries: [
          TaxPaymentEntry(
            id: 'adv1',
            amount: 50000,
            date: DateTime(2024, 7, 10), // Paid LATE for Q1 (due June 15)
            source: 'Self',
            isManualEntry: true,
          ),
        ],
      );

      final result = taxService.calculateDetailedLiability(data, rules);

      expect(result['totalTax'], greaterThan(0));
      expect(result['baseForAdvanceTax'], greaterThan(0));
      expect(result['advanceTaxInterest'], greaterThan(0));
    });

    test('Marginal Relief Section 87A (New Regime)', () {
      final rules = defaultRules.copyWith(
        rebateLimit: 700000,
        isCessEnabled: true,
        isStdDeductionSalaryEnabled: false,
      );

      const data = TaxYearData(
          year: 2024,
          otherIncomes: [
            OtherIncome(
                name: 'Income', amount: 705000, type: 'Other', subtype: 'other')
          ],
          salary: SalaryDetails(history: []));

      final results = taxService.calculateDetailedLiability(data, rules);

      // In the new regime with 700k rebate:
      // Tax on 705,000 without rebate:
      // 0-3L: 0
      // 3-6L: 5% of 3L = 15,000
      // 6-7.05L: 10% of 1.05L = 10,500
      // Total = 25,500
      // Excess Income = 705,000 - 700,000 = 5,000
      // Marginal Relief applies because 25,500 > 5,000
      // Tax capped at 5,000.
      expect(results['slabTax'], 5000);
    });

    test('ITR Suggestions', () {
      expect(taxService.suggestITR(const TaxYearData(year: 2024)),
          'ITR-1 (Sahaj)');

      expect(
          taxService.suggestITR(const TaxYearData(year: 2024, businessIncomes: [
            BusinessEntity(
                name: 'B1',
                grossTurnover: 100,
                netIncome: 50,
                type: BusinessType.regular)
          ])),
          'ITR-3 or ITR-4');

      expect(
          taxService.suggestITR(TaxYearData(year: 2024, capitalGains: [
            CapitalGainEntry(
                description: 'G',
                gainDate: DateTime(2024, 5, 1),
                saleAmount: 100,
                costOfAcquisition: 50,
                isLTCG: true,
                matchAssetType: AssetType.equityShares)
          ])),
          'ITR-2');

      expect(
          taxService.suggestITR(const TaxYearData(year: 2024, houseProperties: [
            HouseProperty(
                name: 'H1',
                rentReceived: 100,
                municipalTaxes: 0,
                interestOnLoan: 0,
                isSelfOccupied: false),
            HouseProperty(
                name: 'H2',
                rentReceived: 100,
                municipalTaxes: 0,
                interestOnLoan: 0,
                isSelfOccupied: false),
          ])),
          'ITR-2');
    });

    test('Insurance Maturity Taxability', () {
      final oldDate = DateTime(2010, 1, 1);
      final newDate = DateTime(2020, 1, 1);

      // Before 2012: 20% limit
      expect(taxService.isInsuranceMaturityTaxable(25000, 100000, oldDate),
          true); // 25% > 20%
      expect(taxService.isInsuranceMaturityTaxable(15000, 100000, oldDate),
          false); // 15% < 20%

      // After 2012: 10% limit
      expect(taxService.isInsuranceMaturityTaxable(15000, 100000, newDate),
          true); // 15% > 10%
      expect(taxService.isInsuranceMaturityTaxable(5000, 100000, newDate),
          false); // 5% < 10%
    });

    test('Complex Monthly Breakdown & Generated TDS', () {
      final rules = defaultRules.copyWith(
        isStdDeductionSalaryEnabled: true,
        stdDeductionSalary: 50000,
      );

      final data = TaxYearData(
        year: 2024,
        salary: SalaryDetails(
          history: [
            SalaryStructure(
              id: 's1',
              effectiveDate: DateTime(2024, 4, 1),
              monthlyBasic: 80000,
            ),
            SalaryStructure(
              id: 's2',
              effectiveDate: DateTime(2024, 10, 1),
              monthlyBasic: 100000,
            ),
          ],
          independentAllowances: [
            const CustomAllowance(
              id: 'bonus1',
              name: 'Bonus',
              payoutAmount: 50000,
              frequency: PayoutFrequency.custom,
              customMonths: [12], // Paid in December
            )
          ],
        ),
      );

      final breakdown = taxService.calculateMonthlySalaryBreakdown(data, rules);
      expect(breakdown.length, 12);
      expect(breakdown[4]!['gross'], 80000); // April
      expect(breakdown[10]!['gross'], 100000); // October (Increment)
      expect(breakdown[12]!['gross'], 150000); // December (Bonus)

      final generatedTds = taxService.getGeneratedSalaryTds(data, rules);
      expect(generatedTds.isNotEmpty, true);
    });

    test('Legacy Advance Tax Fallback', () {
      final rules = defaultRules.copyWith(enableAdvanceTaxInterest: true);
      final data = TaxYearData(
        year: 2024,
        advanceTaxEntries: [
          TaxPaymentEntry(
              id: 'legacy',
              amount: 100000,
              date: DateTime(2024, 6, 15),
              source: 'Legacy Fallback')
        ],
        otherIncomes: [
          const OtherIncome(
              name: 'I', amount: 1000000, type: 'Other', subtype: 'other')
        ],
      );

      final result = taxService.calculateDetailedLiability(data, rules);
      // This should use 100000 as paid advance tax
      expect(result['advanceTax'], 100000);
    });

    test('Disabled Capital Gains Rates', () {
      final rules = defaultRules.copyWith(
        isCGRatesEnabled: false,
        isStdDeductionSalaryEnabled: false,
      );
      final data = TaxYearData(
        year: 2024,
        capitalGains: [
          CapitalGainEntry(
            description: 'G',
            gainDate: DateTime(2024, 5, 1),
            saleAmount: 100000,
            costOfAcquisition: 0,
            isLTCG: true,
            matchAssetType: AssetType.equityShares,
          )
        ],
      );

      final result = taxService.calculateDetailedLiability(data, rules);

      // When CG rates are disabled, CG income is added to normal income
      expect(result['taxableIncome'], 100000);
      expect(result['specialTax'], 0);
    });
  });
}
