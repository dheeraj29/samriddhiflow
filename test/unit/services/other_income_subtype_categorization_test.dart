import 'package:flutter_test/flutter_test.dart';
import 'package:samriddhi_flow/models/taxes/tax_data_models.dart';
import 'package:samriddhi_flow/services/taxes/indian_tax_service.dart';
import 'package:samriddhi_flow/models/taxes/tax_data.dart';
import 'package:samriddhi_flow/models/taxes/tax_rules.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/services/taxes/tax_config_service.dart';

class MockTaxConfigService extends Mock implements TaxConfigService {}

void main() {
  late IndianTaxService taxService;
  late MockTaxConfigService mockConfig;

  setUp(() {
    mockConfig = MockTaxConfigService();
    taxService = IndianTaxService(mockConfig);
  });

  group('OtherIncome Subtype Integration', () {
    test('calculateOtherSources includes all OtherIncome subtypes', () {
      const data = TaxYearData(
        year: 2025,
        otherIncomes: [
          OtherIncome(
              name: 'S1',
              amount: 1000,
              type: 'Other',
              subtype: 'Savings Interest'),
          OtherIncome(
              name: 'F1', amount: 2000, type: 'Other', subtype: 'FD Interest'),
          OtherIncome(
              name: 'C1',
              amount: 3000,
              type: 'Other',
              subtype: 'Chit Fund Interest'),
          OtherIncome(
              name: 'P1',
              amount: 4000,
              type: 'Other',
              subtype: 'Family Pension'),
          OtherIncome(
              name: 'O1', amount: 500, type: 'Other', subtype: 'Others'),
        ],
      );

      final rules = TaxRules(financialYearStartMonth: 4);
      final totalOther = taxService.calculateOtherSources(data, rules);

      // 1000 + 2000 + 3000 + 4000 + 500 = 10500
      expect(totalOther, 10500);
    });

    test(
        'calculateOtherSources correctly handles gift exemptions based on subtype',
        () {
      const data = TaxYearData(
        year: 2025,
        cashGifts: [
          OtherIncome(
              name: 'Marriage Gift',
              amount: 100000,
              type: 'Gift',
              subtype: 'Marriage'),
          OtherIncome(
              name: 'Relative Gift',
              amount: 50000,
              type: 'Gift',
              subtype: 'Relative'),
          OtherIncome(
              name: 'Friend Gift',
              amount: 20000,
              type: 'Gift',
              subtype: 'Friend'),
          OtherIncome(
              name: 'Other Gift',
              amount: 10000,
              type: 'Gift',
              subtype: 'Other'),
        ],
      );

      final rules = TaxRules(cashGiftExemptionLimit: 50000);
      final totalOther = taxService.calculateOtherSources(data, rules);

      // Marriage (100k) and Relative (50k) are exempt by subtype.
      // Friend (20k) and Other (10k) are aggregate = 30k.
      // 30k <= 50k limit, so total taxable other = 0.
      expect(totalOther, 0);
    });

    test('calculateOtherSources makes gifts taxable if aggregate exceeds limit',
        () {
      const data = TaxYearData(
        year: 2025,
        cashGifts: [
          OtherIncome(
              name: 'Friend Gift 1',
              amount: 30000,
              type: 'Gift',
              subtype: 'Friend'),
          OtherIncome(
              name: 'Friend Gift 2',
              amount: 30000,
              type: 'Gift',
              subtype: 'Other'),
        ],
      );

      final rules = TaxRules(cashGiftExemptionLimit: 50000);
      final totalOther = taxService.calculateOtherSources(data, rules);

      // Total = 30k + 30k = 60k (> 50k limit)
      expect(totalOther, 60000);
    });
  });
}
