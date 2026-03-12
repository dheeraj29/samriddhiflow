import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:samriddhi_flow/models/taxes/tax_rules.dart';
import 'package:samriddhi_flow/models/taxes/tax_data_models.dart';
import 'package:samriddhi_flow/models/taxes/tax_data.dart';
import 'package:samriddhi_flow/services/taxes/tax_config_service.dart';
import 'package:samriddhi_flow/services/taxes/indian_tax_service.dart';

// Create a Mock manually since we can't use Mockito generator easily here
class MockTaxConfigService extends Mock implements TaxConfigService {
  final Map<int, TaxRules> _rules = {};

  @override
  TaxRules getRulesForYear(int year) {
    if (_rules.containsKey(year)) return _rules[year]!;
    return TaxRules();
  }
}

void main() {
  group('Employer Gifts Taxation', () {
    test('Calculates salary income correctly with gifts > exemption', () {
      final mockConfig = MockTaxConfigService();
      final service = IndianTaxService(mockConfig);

      final rules = TaxRules().copyWith(
          isGiftFromEmployerEnabled: true,
          giftFromEmployerExemptionLimit: 5000,
          isStdDeductionSalaryEnabled: false,
          isRetirementExemptionEnabled: false);

      final data = TaxYearData(
          year: 2025,
          salary: SalaryDetails(history: [
            SalaryStructure(
              id: 's1',
              monthlyBasic: 100000 / 12,
              effectiveDate: DateTime(2025, 4, 1),
            )
          ], independentAllowances: [
            const CustomAllowance(
                id: 'gift',
                name: 'Gift',
                payoutAmount: 8000,
                frequency: PayoutFrequency.annually,
                startMonth: 4,
                exemptionLimit: 5000)
          ]));

      final salaryIncome = service.calculateSalaryIncome(data, rules);
      // Expected: 100,000 + (8000 - 5000) = 103,000
      expect(salaryIncome, closeTo(103000, 1));
    });

    test('Calculates salary income correctly with gifts < exemption', () {
      final mockConfig = MockTaxConfigService();
      final service = IndianTaxService(mockConfig);

      final rules = TaxRules().copyWith(
          isGiftFromEmployerEnabled: true,
          giftFromEmployerExemptionLimit: 5000,
          isStdDeductionSalaryEnabled: false);

      final data = TaxYearData(
          year: 2025,
          salary: SalaryDetails(
            history: [
              SalaryStructure(
                  id: "s1",
                  monthlyBasic: 100000 / 12,
                  effectiveDate: DateTime(2025, 4, 1))
            ],
          ));

      final salaryIncome = service.calculateSalaryIncome(data, rules);
      expect(salaryIncome, closeTo(100000, 1));
    });
    test('Ignores gifts if disabled', () {
      final mockConfig = MockTaxConfigService();
      final service = IndianTaxService(mockConfig);

      final rules = TaxRules().copyWith(
          isGiftFromEmployerEnabled: false,
          giftFromEmployerExemptionLimit: 5000,
          isStdDeductionSalaryEnabled: false);

      final data = TaxYearData(
          year: 2025,
          salary: SalaryDetails(history: [
            SalaryStructure(
                id: "s1",
                monthlyBasic: 100000 / 12,
                effectiveDate: DateTime(2025, 4, 1))
          ]));

      final salaryIncome = service.calculateSalaryIncome(data, rules);
      expect(salaryIncome, closeTo(100000, 1));
    });
  });
}
