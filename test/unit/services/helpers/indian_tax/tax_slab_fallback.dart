import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/models/taxes/tax_data.dart';
import 'package:samriddhi_flow/models/taxes/tax_data_models.dart';
import 'package:samriddhi_flow/models/taxes/tax_rules.dart';
import 'package:samriddhi_flow/services/taxes/indian_tax_service.dart';
import 'package:samriddhi_flow/services/taxes/tax_config_service.dart';

class MockTaxConfigService extends Mock implements TaxConfigService {}

void registerTaxSlabFallbackTests() {
  late IndianTaxService service;
  late MockTaxConfigService mockConfig;

  setUp(() {
    mockConfig = MockTaxConfigService();
    service = IndianTaxService(mockConfig);
  });

  group('Tax Slab Fallback Tests', () {
    test(
        'Should use slab rates for capital gains when special rates are disabled',
        () {
      final rules = TaxRules(
        slabs: const [
          TaxSlab(300000, 0),
          TaxSlab(double.infinity, 10),
        ],
        isCGRatesEnabled: false, // Disabled
        isRebateEnabled: false, // Disable rebate for testing slab tax directly
        isStdDeductionSalaryEnabled: false, // Disable SD for clean testing
        jurisdiction: 'India',
      );

      final data = TaxYearData(
        year: 2025,
        capitalGains: [
          CapitalGainEntry(
            description: 'Equity Sale',
            saleAmount: 100000,
            costOfAcquisition: 50000,
            gainDate: DateTime(2025, 5, 1),
            isLTCG: true,
            matchAssetType: AssetType.equityShares,
          ),
        ],
      );

      // Current implementation of _calculateLTCGTax returns 0 if isCGRatesEnabled is false.
      // If the intent is to fallback to slabs, they should be part of netTaxableNormalIncome.
      // Let's verify current behavior.
      final liability = service.calculateDetailedLiability(data, rules);

      // If specialTax is 0, we need to check if it's included in slabTax.
      // Currently IndianTaxService.calculateDetailedLiability line 81:
      // final specialRateIncome = incomeLTCGEquity + incomeLTCGOther + incomeSTCG;
      // taxableHeadsSum = incomeSalary + incomeHP + incomeBusiness + incomeOther;
      // So CG is NOT in taxableHeadsSum.
      // If CG rules are disabled, they should probably be added to incomeOther or incomeSalary?

      expect(liability['specialTax'], 0);
      // Gain is 50,000. Slab is 0-3L (0%), > 3L (10%).
      // Since total income is 50,000 (< 300,000), slab tax should still be 0.
      // Let's add more income to push it into the 10% bracket.

      final dataHigh = data.copyWith(
        otherIncomes: [const OtherIncome(name: 'Rent', amount: 300000)],
      );
      final liabilityHigh = service.calculateDetailedLiability(dataHigh, rules);
      // Total income = 300,000 (Rent) + 50,000 (CG) = 350,000.
      // Slab tax = (350,000 - 300,000) * 0.10 = 5,000.
      expect(liabilityHigh['slabTax'], 5000);
    });

    test(
        'Should aggregate ALL income into slabs when special rules are disabled',
        () {
      final rules = TaxRules(
        slabs: const [
          TaxSlab(double.infinity, 10), // 10% from ground up for easy math
        ],
        isCGRatesEnabled: false,
        isRebateEnabled: false,
        isStdDeductionSalaryEnabled: false,
        isStdDeductionHPEnabled: false,
        isGiftFromEmployerEnabled: true, // Enable to include in gross
        giftFromEmployerExemptionLimit: 0, // No exemption
        isHPMaxInterestEnabled: false,
        isAgriIncomeEnabled:
            false, // In this mode, we check if Agri is treated as regular or ignored
        jurisdiction: 'India',
      );

      final data = TaxYearData(
        year: 2025,
        salary: SalaryDetails(
          history: [
            SalaryStructure(
              id: 'test',
              monthlyBasic: 100000 / 12,
              effectiveDate: DateTime(2025, 4, 1),
              customAllowances: const [
                CustomAllowance(
                  id: 'gift',
                  name: 'Gifts',
                  payoutAmount: 10000,
                  frequency: PayoutFrequency.annually,
                  startMonth: 4,
                )
              ],
            )
          ],
        ),
        houseProperties: [
          const HouseProperty(
              name: 'Rent', rentReceived: 50000, isSelfOccupied: false),
        ],
        businessIncomes: [
          const BusinessEntity(name: 'Biz', netIncome: 40000),
        ],
        capitalGains: [
          CapitalGainEntry(
            description: 'STCG',
            saleAmount: 30000,
            costOfAcquisition: 10000,
            gainDate: DateTime(2025, 6, 1),
            isLTCG: false,
          ),
        ],
        otherIncomes: [
          const OtherIncome(name: 'Misc', amount: 20000, type: 'Other'),
        ],
        dividendIncome: const DividendIncome(amountQ1: 5000),
      );

      final liability = service.calculateDetailedLiability(data, rules);

      // Math:
      // Salary: 100k (gross) + 10k (gift) = 110k (since rules disabled)
      // HP: 50k (rent) - 0 (no deduction) = 50k
      // Business: 40k
      // CG: 20k (30k-10k)
      // Other: 20k + 5k (div) = 25k
      // Total taxable = 110 + 50 + 40 + 20 + 25 = 245k
      // Tax @ 10% = 24.5k

      expect(liability['taxableIncome'], 245000);
      expect(liability['slabTax'], 24500);
      expect(liability['specialTax'], 0);
    });

    test('Should handle Independent and Custom Exemptions across ALL heads',
        () {
      final rules = TaxRules(
        slabs: const [TaxSlab(double.infinity, 10)],
        isRebateEnabled: false,
        isStdDeductionSalaryEnabled: false,
        isStdDeductionHPEnabled: false,
        customExemptions: [
          const TaxExemptionRule(
            id: 'ex-salary',
            name: 'Bonus Deduct',
            incomeHead: 'Salary',
            limit: 5, // 5%
            isPercentage: true,
          ),
          const TaxExemptionRule(
            id: 'ex1',
            name: 'Business Deduct',
            incomeHead: 'Business',
            limit: 10000,
          ),
          const TaxExemptionRule(
            id: 'ex-hp',
            name: 'Maintenance',
            incomeHead: 'House Property',
            limit: 2000,
          ),
          const TaxExemptionRule(
            id: 'ex2',
            name: 'Other Source Deduct',
            incomeHead: 'Other',
            limit: 5000,
          ),
        ],
        jurisdiction: 'India',
      );

      final data = TaxYearData(
        year: 2025,
        salary: SalaryDetails(
          history: [
            SalaryStructure(
              id: 'test',
              monthlyBasic: 100000 / 12,
              effectiveDate: DateTime(2025, 4, 1),
            )
          ],
          independentExemptions: const [
            CustomExemption(id: 'rent-ind', name: 'Rent', amount: 10000),
          ],
        ),
        houseProperties: const [
          HouseProperty(
              name: 'Flat', rentReceived: 50000, isSelfOccupied: false),
        ],
        businessIncomes: const [
          BusinessEntity(name: 'Biz', netIncome: 40000),
        ],
        otherIncomes: const [
          OtherIncome(name: 'Misc', amount: 20000),
        ],
      );

      final liability = service.calculateDetailedLiability(data, rules);

      // Math:
      // Salary: 100k - 10k (ind) = 90k. Then 5% of 100k = 5k. Salary = 90 - 5 = 85k.
      // HP: 50k (rent) - 0 (no interest) - 2k (custom) = 48k.
      // Business: 40k - 10k (custom rule) = 30k.
      // Other: 20k - 5k (custom rule) = 15k.
      // Total taxable = 85 + 48 + 30 + 15 = 178k.
      // Tax @ 10% = 17.8k.

      expect(liability['taxableIncome'], 178000);
      expect(liability['slabTax'], 17800);
    });

    test('Should handle Agriculture income and custom exemptions', () {
      final rules = TaxRules(
        slabs: const [
          TaxSlab(250000, 0),
          TaxSlab(double.infinity, 10),
        ],
        isAgriIncomeEnabled: true,
        agricultureBasicExemptionLimit: 250000,
        agricultureIncomeThreshold: 5000,
        isRebateEnabled: false,
        isStdDeductionSalaryEnabled: false,
        customExemptions: [
          const TaxExemptionRule(
            id: 'agri-ex',
            name: 'Agri Maintenance',
            incomeHead: 'Agriculture',
            limit: 5000,
          ),
        ],
        jurisdiction: 'India',
      );

      final data = TaxYearData(
        year: 2025,
        agriIncomeHistory: [
          AgriIncomeEntry(id: 'a1', amount: 20000, date: DateTime(2025, 4, 1))
        ],
        otherIncomes: const [OtherIncome(name: 'Interest', amount: 300000)],
      );

      final liability = service.calculateDetailedLiability(data, rules);

      // Math:
      // Normal Income = 300k. Basic Exemption = 250k.
      // Net Normal = 300k. (No SD/NPS)
      // Net Agri = 20k - 5k = 15k.
      // Step 1: Tax on (300k + 15k) = 315k @ 10% above 250k = 6.5k.
      // Step 2: Tax on (250k + 15k) = 265k @ 10% above 250k = 1.5k.
      // Total Slab Tax = 6.5k - 1.5k = 5k.

      expect(liability['slabTax'], 5000);
    });

    test('Should handle Gift income and custom exemptions', () {
      final rules = TaxRules(
        slabs: const [TaxSlab(double.infinity, 10)],
        isRebateEnabled: false,
        isStdDeductionSalaryEnabled: false,
        cashGiftExemptionLimit: 50000,
        customExemptions: [
          const TaxExemptionRule(
            id: 'gift-ex',
            name: 'Special Gift Exemption',
            incomeHead: 'Gift',
            limit: 10000,
          ),
        ],
        jurisdiction: 'India',
      );

      const data = TaxYearData(
        year: 2025,
        cashGifts: [
          OtherIncome(name: 'Gift 1', amount: 60000, subtype: 'friend'),
        ],
      );

      final liability = service.calculateDetailedLiability(data, rules);

      // Math:
      // Taxable Gifts = 60000 (since > 50k threshold).
      // Head Adjustment: 60k - 10k (custom) = 50k.
      // Tax @ 10% = 5k.

      expect(liability['taxableIncome'], 50000);
      expect(liability['slabTax'], 5000);
    });

    test(
        'Should handle Agriculture income correctly when integration is disabled',
        () {
      final rules = TaxRules(
        slabs: const [TaxSlab(double.infinity, 10)],
        isAgriIncomeEnabled: false, // Disabled
        isRebateEnabled: false,
        isStdDeductionSalaryEnabled: false, // Disable SD
        jurisdiction: 'India',
      );

      final data = TaxYearData(
        year: 2025,
        agriIncomeHistory: [
          AgriIncomeEntry(id: 'a1', amount: 50000, date: DateTime(2025, 4, 1))
        ],
        otherIncomes: const [OtherIncome(name: 'Interest', amount: 100000)],
      );

      final liability = service.calculateDetailedLiability(data, rules);
      // Currently, if isAgriIncomeEnabled is false, it's NOT added to taxable pool. It's just ignored.
      // This is standard as Agri income is not federally taxable in India.
      expect(liability['taxableIncome'], 100000);
    });
  });
}
