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
        isRetirementExemptionEnabled: false,
      );

      final data = TaxYearData(
          year: 2025,
          salary: const SalaryDetails(
            grossSalary: 100000,
            giftsFromEmployer: 8000, // 3000 excess
          ));

      final salaryIncome = service.calculateSalaryIncome(data, rules);
      // Expected: 100,000 + (8000 - 5000) = 103,000
      expect(salaryIncome, 103000);
    });

    test('Calculates salary income correctly with gifts < exemption', () {
      final mockConfig = MockTaxConfigService();
      final service = IndianTaxService(mockConfig);

      final rules = TaxRules().copyWith(
        isGiftFromEmployerEnabled: true,
        giftFromEmployerExemptionLimit: 5000,
        isStdDeductionSalaryEnabled: false,
      );

      final data = TaxYearData(
          year: 2025,
          salary: const SalaryDetails(
            grossSalary: 100000,
            giftsFromEmployer: 4000, // No excess
          ));

      final salaryIncome = service.calculateSalaryIncome(data, rules);
      expect(salaryIncome, 100000);
    });
    test('Ignores gifts if disabled', () {
      final mockConfig = MockTaxConfigService();
      final service = IndianTaxService(mockConfig);

      final rules = TaxRules().copyWith(
        isGiftFromEmployerEnabled: false,
        giftFromEmployerExemptionLimit: 5000,
        isStdDeductionSalaryEnabled: false,
      );

      final data = TaxYearData(
          year: 2025,
          salary: const SalaryDetails(
            grossSalary: 100000,
            giftsFromEmployer: 10000,
          ));

      final salaryIncome = service.calculateSalaryIncome(data, rules);
      expect(salaryIncome, 100000);
    });
  });
}
