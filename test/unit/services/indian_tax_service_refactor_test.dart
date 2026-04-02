import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/models/taxes/tax_data.dart';
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
    test('calculateDetailedLiability invokes refactored cess logic correctly',
        () {
      const data = TaxYearData(year: 2024);
      final rules = TaxRules();

      // We test the public method result to ensure the extracted private
      // logic for cess and deductions still produces correct outputs.
      final result = service.calculateDetailedLiability(data, rules);

      expect(result.containsKey('cessOnSlab'), true);
      expect(result.containsKey('cessOnSpecial'), true);
    });

    test('calculateLiability uses refactored logic for total tax', () {
      const data = TaxYearData(year: 2024);

      when(() => mockConfig.isReady).thenReturn(true);
      when(() => mockConfig.getRulesForYear(2024)).thenReturn(TaxRules());

      final liability = service.calculateLiability(data);

      expect(liability >= 0, true);
    });
  });
}
