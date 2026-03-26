import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/models/taxes/tax_data.dart';
import 'package:samriddhi_flow/models/taxes/tax_data_models.dart';
import 'package:samriddhi_flow/models/taxes/tax_rules.dart';
import 'package:samriddhi_flow/services/taxes/indian_tax_service.dart';
import 'package:samriddhi_flow/services/taxes/tax_config_service.dart';
import 'package:clock/clock.dart';

class MockTaxConfigService extends Mock implements TaxConfigService {}

void registerSalaryAdvanceTaxReproTests() {
  late IndianTaxService taxService;
  late MockTaxConfigService mockConfig;

  setUp(() {
    mockConfig = MockTaxConfigService();
    taxService = IndianTaxService(mockConfig);
  });

  group('Salary Advance Tax Regression', () {
    test('Salary only (with history) should have zero advance tax interest',
        () {
      final rules = TaxRules(
        rebateLimit: 700000,
        slabs: const [
          TaxSlab(300000, 0),
          TaxSlab(600000, 5),
          TaxSlab(900000, 10),
          TaxSlab(1200000, 15),
          TaxSlab(1500000, 20),
          TaxSlab(double.infinity, 30),
        ],
        stdDeductionSalary: 75000,
        enableAdvanceTaxInterest: true,
      );

      final data = TaxYearData(
        year: 2025,
        salary: SalaryDetails(
          history: [
            SalaryStructure(
              id: 's1',
              effectiveDate: DateTime(2025, 4, 1),
              monthlyBasic: 100000,
              monthlyFixedAllowances: 6250,
            ),
          ],
        ),
      );

      withClock(Clock.fixed(DateTime(2026, 4, 1)), () {
        final result = taxService.calculateDetailedLiability(data, rules);
        expect(result['advanceTaxInterest'], 0.0,
            reason:
                'Salary only should not trigger advance tax interest if TDS covers it.');
      });
    });

    test(
        'Salary hike mid-year should NOT trigger advance tax interest (REPRODUCTION OF HIKE BUG)',
        () {
      final rules = TaxRules(
        rebateLimit: 700000,
        slabs: const [
          TaxSlab(300000, 0),
          TaxSlab(600000, 5),
          TaxSlab(900000, 10),
          TaxSlab(1200000, 15),
          TaxSlab(1500000, 20),
          TaxSlab(double.infinity, 30),
        ],
        stdDeductionSalary: 75000,
        enableAdvanceTaxInterest: true,
      );

      final data = TaxYearData(
        year: 2025,
        salary: SalaryDetails(
          history: [
            SalaryStructure(
              id: 's1',
              effectiveDate: DateTime(2025, 4, 1),
              monthlyBasic: 50000, // 6L annual gross -> 0 tax
            ),
            SalaryStructure(
              id: 's2',
              effectiveDate: DateTime(2025, 10, 1),
              monthlyBasic: 200000, // Hike!
            ),
          ],
        ),
      );

      withClock(Clock.fixed(DateTime(2026, 4, 1)), () {
        final result = taxService.calculateDetailedLiability(data, rules);

        // This is expected to FAIL if projection doesn't catch up
        expect(result['advanceTaxInterest'], 0.0,
            reason: 'Salary hike should have matching TDS by year end.');
      });
    });
  });
}
