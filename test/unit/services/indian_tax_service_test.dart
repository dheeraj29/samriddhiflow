import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/models/taxes/tax_data.dart';
import 'package:samriddhi_flow/models/taxes/tax_data_models.dart';
import 'package:samriddhi_flow/models/taxes/tax_rules.dart';
import 'package:samriddhi_flow/services/taxes/indian_tax_service.dart';
import 'package:samriddhi_flow/services/taxes/tax_config_service.dart';

class MockTaxConfigService extends Mock implements TaxConfigService {}

void main() {
  late MockTaxConfigService mockConfig;
  late IndianTaxService taxService;

  setUp(() {
    mockConfig = MockTaxConfigService();
    taxService = IndianTaxService(mockConfig);
  });

  TaxRules createBasicRules() {
    return TaxRules(
      stdDeductionSalary: 50000,
      isStdDeductionSalaryEnabled: true,
      rebateLimit: 0, // Disable rebate for simple calculation
      isRebateEnabled: false,
      isCessEnabled: true,
      cessRate: 4.0,
      stdExemption112A: 125000,
      isLTCGExemption112AEnabled: true,
      ltcgRateEquity: 12.5,
      stcgRate: 20.0,
      isCGRatesEnabled: true,
      slabs: const [
        TaxSlab(250000, 0),
        TaxSlab(500000, 5),
        TaxSlab(1000000, 20),
        TaxSlab(double.infinity, 30),
      ],
    );
  }

  group('IndianTaxService - Salary', () {
    test('calculateSalaryIncome with standard deduction', () {
      final rules = createBasicRules();
      final data = TaxYearData(
        year: 2025,
        salary: const SalaryDetails(
          grossSalary: 600000,
        ),
      );

      final income = taxService.calculateSalaryIncome(data, rules);

      // Expected Salary Income: 600,000 - 50,000 (Std Ded) = 550,000
      expect(income, 550000);
    });

    test('calculateSalaryIncome with zero salary', () {
      final rules = createBasicRules();
      final data = TaxYearData(
        year: 2025,
        salary: const SalaryDetails(
          grossSalary: 0,
        ),
      );

      final income = taxService.calculateSalaryIncome(data, rules);
      expect(income, 0);
    });

    test('Standard Deduction disabled', () {
      final rules =
          createBasicRules().copyWith(isStdDeductionSalaryEnabled: false);
      final data = TaxYearData(
        year: 2025,
        salary: const SalaryDetails(
          grossSalary: 600000,
        ),
      );

      final income = taxService.calculateSalaryIncome(data, rules);
      expect(income, 600000);
    });
  });

  group('IndianTaxService - House Property', () {
    test('calculateHousePropertyIncome with municipal taxes and std deduction',
        () {
      final rules = createBasicRules().copyWith(
        standardDeductionRateHP: 30.0,
        isStdDeductionHPEnabled: true,
      );
      final data = TaxYearData(
        year: 2025,
        houseProperties: const [
          HouseProperty(
            name: 'Home',
            rentReceived: 100000,
            municipalTaxes: 10000,
            isSelfOccupied: false,
          ),
        ],
      );

      final income = taxService.calculateHousePropertyIncome(data, rules);

      // Net Annual Value (NAV) = 100,000 - 10,000 = 90,000
      // Std Deduction (30%) = 0.3 * 90,000 = 27,000
      // Taxable HP = 90,000 - 27,000 = 63,000
      expect(income, 63000);
    });

    test('calculateHousePropertyIncome with interest on loan', () {
      final rules = createBasicRules().copyWith(
        standardDeductionRateHP: 30.0,
        isStdDeductionHPEnabled: true,
        maxHPDeductionLimit: 200000,
      );
      final data = TaxYearData(
        year: 2025,
        houseProperties: const [
          HouseProperty(
            name: 'Home',
            isSelfOccupied: true,
            rentReceived: 0,
            interestOnLoan: 250000,
          ),
        ],
      );

      final income = taxService.calculateHousePropertyIncome(data, rules);

      // Self-occupied property loss capped at 200,000
      expect(income, -200000);
    });
  });

  group('IndianTaxService - Agriculture Income (Partial Integration)', () {
    test('applyPartialIntegration correctly', () {
      final rules = createBasicRules().copyWith(
        isAgriIncomeEnabled: true,
        agricultureIncomeThreshold: 5000,
        agricultureBasicExemptionLimit: 250000,
      );

      // Case: Normal Income 300,000, Agri Income 100,000
      // netTaxableNormalIncome = 300,000 (after ded)
      // Step 1: Base = 300k + 100k = 400k. Tax(400k) = (400k-250k)*5% = 7500
      // Step 2: Base = 250k + 100k = 350k. Tax(350k) = (350k-250k)*5% = 5000
      // Slab Tax = 7500 - 5000 = 2500

      final data = TaxYearData(
        year: 2025,
        salary: const SalaryDetails(
            grossSalary: 350000), // after std ded is 300,000
        agricultureIncome: 100000,
      );

      when(() => mockConfig.getRulesForYear(2025)).thenReturn(rules);

      final liability = taxService.calculateLiability(data);
      // Cess 4% of 2500 = 100. Total = 2600
      expect(liability, 2600);
    });
  });

  group('IndianTaxService - Capital Gains', () {
    test('calculateCapitalGains Equity LTCG with exemption', () {
      final rules = createBasicRules();
      final data = TaxYearData(
        year: 2025,
        capitalGains: [
          CapitalGainEntry(
            description: 'Equity Sale',
            matchAssetType: AssetType.equityShares,
            isLTCG: true,
            saleAmount: 300000,
            costOfAcquisition: 100000,
            gainDate: DateTime(2025, 5, 1),
          ),
        ],
      );

      // Gain = 200,000
      // Exemption (112A) = 125,000
      // Taxable = 75,000
      // Tax (12.5%) = 0.125 * 75,000 = 9375

      when(() => mockConfig.getRulesForYear(2025)).thenReturn(rules);

      final liability = taxService.calculateLiability(data);
      // Normal income is 0.
      // Cess 4% of 9375 = 375. Total = 9750
      expect(liability, 9750);
    });

    test('calculateCapitalGains Property LTCG with reinvestment', () {
      final rules = createBasicRules().copyWith(
        maxCGReinvestLimit: 100000000,
      );
      final data = TaxYearData(
        year: 2025,
        capitalGains: [
          CapitalGainEntry(
            description: 'Flat Sale',
            matchAssetType: AssetType.residentialProperty,
            isLTCG: true,
            saleAmount: 10000000,
            costOfAcquisition: 4000000,
            gainDate: DateTime(2025, 5, 1),
            reinvestedAmount: 5000000,
            matchReinvestType: ReinvestmentType.residentialProperty,
            intendToReinvest: true,
          ),
        ],
      );

      // Gain = 6,000,000
      // Reinvestment Exemption = 5,000,000
      // Taxable = 1,000,000
      // Tax (12.5%) = 0.125 * 1,000,000 = 125,000

      when(() => mockConfig.getRulesForYear(2025)).thenReturn(rules);

      final liability = taxService.calculateLiability(data);
      // Cess 4% of 125,000 = 5,000. Total = 130,000
      expect(liability, 130000);
    });
  });

  group('IndianTaxService - ITR Suggestions', () {
    test('suggests ITR-1 for simple salary', () {
      final data = TaxYearData(
          year: 2025, salary: const SalaryDetails(grossSalary: 500000));
      expect(taxService.suggestITR(data), 'ITR-1 (Sahaj)');
    });

    test('suggests ITR-2 for capital gains', () {
      final data = TaxYearData(
        year: 2025,
        capitalGains: [
          CapitalGainEntry(
            gainDate: DateTime(2025, 5, 1),
            saleAmount: 10000,
            costOfAcquisition: 5000,
          ),
        ],
      );
      expect(taxService.suggestITR(data), 'ITR-2');
    });

    test('suggests ITR-3 or ITR-4 for business income', () {
      final data = TaxYearData(
        year: 2025,
        businessIncomes: [
          const BusinessEntity(name: 'Store', netIncome: 100000),
        ],
      );
      expect(taxService.suggestITR(data), 'ITR-3 or ITR-4');
    });
  });
}
