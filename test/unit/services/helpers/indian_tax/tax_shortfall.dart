import 'package:flutter_test/flutter_test.dart';
import 'package:samriddhi_flow/models/taxes/tax_data.dart';
import 'package:samriddhi_flow/models/taxes/tax_data_models.dart';
import 'package:samriddhi_flow/models/taxes/tax_rules.dart';
import 'package:samriddhi_flow/services/taxes/indian_tax_service.dart';
import 'package:samriddhi_flow/services/taxes/tax_config_service.dart';
import 'package:clock/clock.dart';

void registerTaxShortfallTests() {
  test('Advance Tax Shortfall for current month income (Year End check)', () {
    final rules = TaxRules(
      slabs: const [TaxSlab(400000, 0), TaxSlab(double.infinity, 30.0)],
      advanceTaxRules: const [
        AdvanceTaxInstallmentRule(
            startMonth: 4,
            startDay: 1,
            endDay: 15,
            endMonth: 6,
            requiredPercentage: 15,
            interestRate: 1.0),
        AdvanceTaxInstallmentRule(
            startMonth: 6,
            startDay: 16,
            endDay: 15,
            endMonth: 9,
            requiredPercentage: 45,
            interestRate: 1.0),
        AdvanceTaxInstallmentRule(
            startMonth: 9,
            startDay: 16,
            endDay: 15,
            endMonth: 12,
            requiredPercentage: 75,
            interestRate: 1.0),
        AdvanceTaxInstallmentRule(
            startMonth: 12,
            startDay: 16,
            endDay: 15,
            endMonth: 3,
            requiredPercentage: 100,
            interestRate: 1.0),
      ],
      isCgIncludedInAdvanceTax: true,
      enableAdvanceTaxInterest: true,
      advanceTaxInterestThreshold: 10000.0,
      interestTillPaymentDate: true,
      rebateLimit: 0, // Override rebate
      cessRate: 0, // No cess
    );

    final data = TaxYearData(year: 2025, otherIncomes: [
      OtherIncome(
          name: 'Test', amount: 2000000, transactionDate: DateTime(2026, 3, 12))
    ]);

    // We check the interest after the year ended to calculate total penalties for all quarters.
    withClock(Clock.fixed(DateTime(2026, 4, 1)), () {
      final configService = TaxConfigService();
      final service = IndianTaxService(configService);

      final fullYear = service.calculateDetailedLiability(data, rules);
      double fullYearLiability = fullYear['totalTax']!;

      for (final rule in rules.advanceTaxRules) {
        final d = DateTime(rule.endMonth < 4 ? 2026 : 2025, rule.endMonth,
            rule.endDay, 23, 59, 59);
        service.calculateAccruedLiability(data, rules, d,
            fullYearNormalTax: fullYearLiability);
      }

      final interest =
          service.calculateAdvanceTaxInterest(data, rules, fullYearLiability);

      expect(interest, 4575.0);
    });
  });

  test('Advance Tax Interest Stability (Agri + TDS Pollution Isolation)', () {
    final rules = TaxRules(
      slabs: const [
        TaxSlab(300000, 0),
        TaxSlab(600000, 5),
        TaxSlab(900000, 10),
        TaxSlab(1200000, 15),
        TaxSlab(1500000, 20),
        TaxSlab(double.infinity, 30.0)
      ],
      advanceTaxRules: const [
        AdvanceTaxInstallmentRule(
            startMonth: 4,
            startDay: 1,
            endDay: 15,
            endMonth: 6,
            requiredPercentage: 15,
            interestRate: 1.0),
        AdvanceTaxInstallmentRule(
            startMonth: 6,
            startDay: 16,
            endDay: 15,
            endMonth: 9,
            requiredPercentage: 45,
            interestRate: 1.0),
        AdvanceTaxInstallmentRule(
            startMonth: 9,
            startDay: 16,
            endDay: 15,
            endMonth: 12,
            requiredPercentage: 75,
            interestRate: 1.0),
        AdvanceTaxInstallmentRule(
            startMonth: 12,
            startDay: 16,
            endDay: 15,
            endMonth: 3,
            requiredPercentage: 100,
            interestRate: 1.0),
      ],
      isCgIncludedInAdvanceTax: true,
      enableAdvanceTaxInterest: true,
      advanceTaxInterestThreshold: 10000.0,
      interestTillPaymentDate: true,
      rebateLimit: 700000,
      cessRate: 4.0,
      agricultureIncomeThreshold: 5000.0,
      agricultureBasicExemptionLimit: 300000.0,
      isAgriIncomeEnabled: true,
      isStdDeductionSalaryEnabled: true,
      stdDeductionSalary: 75000.0,
    );

    final salary = SalaryDetails(history: [
      SalaryStructure(
        id: 's1',
        effectiveDate: DateTime(2025, 4, 1),
        monthlyBasic: 150000,
        monthlyFixedAllowances: 8333.33, // ~100k annual
      )
    ]);

    final dataNoAgri =
        TaxYearData(year: 2025, salary: salary, houseProperties: const [
      HouseProperty(name: 'HP1', rentReceived: 200000, isSelfOccupied: false)
    ]);

    final dataLargeAgri = dataNoAgri.copyWith(agriIncomeHistory: [
      AgriIncomeEntry(
          id: 'agri1',
          amount: 400000,
          date: DateTime(2026, 3, 12),
          description: 'Agri')
    ]);

    withClock(Clock.fixed(DateTime(2026, 4, 1)), () {
      final configService = TaxConfigService();
      final service = IndianTaxService(configService);

      final res1 = service.calculateDetailedLiability(dataNoAgri, rules);
      final res2 = service.calculateDetailedLiability(dataLargeAgri, rules);

      final double interest1 = res1['advanceTaxInterest'] as double;
      final double interest2 = res2['advanceTaxInterest'] as double;

      expect(interest2, greaterThanOrEqualTo(interest1),
          reason:
              'Interest should not decrease when late-year income is added (due to improved TDS isolation).');
    });
  });

  test('tax_agri_income_shortfall', () {
    // This test ensures that Agriculture income received in March correctly applies
    // Partial Integration but DOES NOT trigger shortfall interest for June, Sept, or Dec.
    final rules = TaxRules(
      slabs: const [
        TaxSlab(300000, 0),
        TaxSlab(700000, 5),
        TaxSlab(1000000, 10),
        TaxSlab(double.infinity, 30.0)
      ],
      advanceTaxRules: const [
        AdvanceTaxInstallmentRule(
            startMonth: 4,
            startDay: 1,
            endDay: 15,
            endMonth: 6,
            requiredPercentage: 15,
            interestRate: 1.0),
        AdvanceTaxInstallmentRule(
            startMonth: 6,
            startDay: 16,
            endDay: 15,
            endMonth: 9,
            requiredPercentage: 45,
            interestRate: 1.0),
        AdvanceTaxInstallmentRule(
            startMonth: 9,
            startDay: 16,
            endDay: 15,
            endMonth: 12,
            requiredPercentage: 75,
            interestRate: 1.0),
        AdvanceTaxInstallmentRule(
            startMonth: 12,
            startDay: 16,
            endDay: 15,
            endMonth: 3,
            requiredPercentage: 100,
            interestRate: 1.0),
      ],
      interestTillPaymentDate: true,
      rebateLimit: 0,
      cessRate: 4.0,
      agricultureIncomeThreshold: 5000.0,
      agricultureBasicExemptionLimit: 300000.0,
      isAgriIncomeEnabled: true,
      isStdDeductionSalaryEnabled: true,
      stdDeductionSalary: 75000.0,
      advanceTaxInterestThreshold: 100.0,
    );

    final data = TaxYearData(year: 2025, otherIncomes: [
      OtherIncome(
          name: 'Fixed', amount: 800000, transactionDate: DateTime(2025, 4, 1))
    ], agriIncomeHistory: [
      AgriIncomeEntry(
          id: 'a1',
          amount: 500000,
          date: DateTime(2026, 3, 10),
          description: 'March Agri')
    ]);

    withClock(Clock.fixed(DateTime(2026, 4, 1)), () {
      final configService = TaxConfigService();
      final service = IndianTaxService(configService);

      final fullYear = service.calculateDetailedLiability(data, rules);
      final double totalTax = fullYear['totalTax']!;

      // Installment 1: June 15
      final d1 = DateTime(2025, 6, 15, 23, 59, 59);
      final acc1 = service.calculateAccruedLiability(data, rules, d1);

      // liability = 8L income. Tax on 8L (Fixed) should be calculated.
      // Agri (5L) is in March, so it should be EXCLUDED from June's accrued liability.

      final interest =
          service.calculateAdvanceTaxInterest(data, rules, totalTax);

      expect(acc1, lessThan(totalTax),
          reason: 'June accrued tax should not include March Agri income.');
      expect(interest, isPositive);
    });
  });
}
