import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/models/taxes/tax_data.dart';
import 'package:samriddhi_flow/models/taxes/tax_data_models.dart';
import 'package:samriddhi_flow/models/taxes/tax_rules.dart';
import 'package:samriddhi_flow/services/taxes/indian_tax_service.dart';
import 'package:samriddhi_flow/services/taxes/tax_config_service.dart';

class MockTaxConfigService extends Mock implements TaxConfigService {}

void main() {
  late IndianTaxService service;
  late MockTaxConfigService mockConfig;

  setUp(() {
    mockConfig = MockTaxConfigService();
    service = IndianTaxService(mockConfig);
  });

  group('IndianTaxService Refactored Helpers', () {
    test('calculateDetailedLiability keeps cess splits at zero when disabled',
        () {
      final data = TaxYearData(
        year: 2025,
        salary: SalaryDetails(history: [
          SalaryStructure(
            id: 's1',
            monthlyBasic: 900000 / 12,
            effectiveDate: DateTime(2025, 4, 1),
          )
        ]),
      );
      final rules = TaxRules(
        slabs: const [
          TaxSlab(300000, 0),
          TaxSlab(600000, 5),
          TaxSlab(900000, 10),
          TaxSlab(double.infinity, 20),
        ],
        stdDeductionSalary: 75000,
        isStdDeductionSalaryEnabled: true,
        isCessEnabled: false,
        isRebateEnabled: false,
      );

      final result = service.calculateDetailedLiability(data, rules);

      expect(result['totalTax'], greaterThan(0));
      expect(result['cess'], 0);
      expect(result['cessOnSlab'], 0);
      expect(result['cessOnSpecial'], 0);
    });

    test('calculateLiability matches detailed total tax from configured rules',
        () {
      final data = TaxYearData(
        year: 2025,
        salary: SalaryDetails(history: [
          SalaryStructure(
            id: 's1',
            monthlyBasic: 1000000 / 12,
            effectiveDate: DateTime(2025, 4, 1),
          )
        ]),
      );
      final rules = TaxRules(
        slabs: const [
          TaxSlab(300000, 0),
          TaxSlab(600000, 5),
          TaxSlab(900000, 10),
          TaxSlab(1200000, 15),
          TaxSlab(double.infinity, 20),
        ],
        stdDeductionSalary: 75000,
        isStdDeductionSalaryEnabled: true,
        isCessEnabled: true,
      );

      when(() => mockConfig.isReady).thenReturn(true);
      when(() => mockConfig.getRulesForYear(2025)).thenReturn(rules);

      final liability = service.calculateLiability(data);
      final detailed = service.calculateDetailedLiability(data, rules);

      expect(liability, detailed['totalTax']);
    });

    test('calculateLiability returns zero when tax config service is not ready',
        () {
      const data = TaxYearData(year: 2025);

      when(() => mockConfig.isReady).thenReturn(false);

      expect(service.calculateLiability(data), 0);
    });
  });
}
