import 'package:flutter_test/flutter_test.dart';
import 'package:samriddhi_flow/models/taxes/tax_data.dart';
import 'package:samriddhi_flow/models/taxes/tax_data_models.dart';
import 'package:samriddhi_flow/models/taxes/tax_rules.dart';
import 'package:samriddhi_flow/services/taxes/indian_tax_service.dart';
import 'package:samriddhi_flow/services/taxes/tax_config_service.dart';
import 'package:clock/clock.dart';

void registerAgriIncomeShortfallTests() {
  test('Advance Tax Shortfall for late-year Agricultural Income', () {
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
      rebateLimit: 0,
      cessRate: 0,
    );

    // Give some base income so Agri triggers the partial-integration tax effect.
    final data = TaxYearData(year: 2025, otherIncomes: const [
      OtherIncome(name: 'Base Salary Equivalent', amount: 800000)
    ], agriIncomeHistory: [
      AgriIncomeEntry(
          id: 'test_agri_1',
          amount: 1500000,
          date: DateTime(2026, 3, 12),
          description: 'Crop Sale')
    ]);

    withClock(Clock.fixed(DateTime(2026, 4, 1)), () {
      final configService = TaxConfigService();
      final service = IndianTaxService(configService);

      final fullYear = service.calculateDetailedLiability(data, rules);
      double fullYearLiability = fullYear['totalTax']!;

      final interest =
          service.calculateAdvanceTaxInterest(data, rules, fullYearLiability);

      expect(interest, isNotNull);
    });
  });
}
