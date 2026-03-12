import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/models/taxes/tax_data_models.dart';
import 'package:samriddhi_flow/models/taxes/tax_data.dart';
import 'package:samriddhi_flow/models/taxes/tax_rules.dart';
import 'package:samriddhi_flow/services/taxes/indian_tax_service.dart';
import 'package:samriddhi_flow/services/taxes/tax_config_service.dart';

class MockTaxConfigService extends Mock implements TaxConfigService {}

void main() {
  late IndianTaxService service;
  late MockTaxConfigService mockConfig;

  final defaultRules = TaxRules(
    slabs: [
      const TaxSlab(400000, 0),
      const TaxSlab(800000, 5),
      const TaxSlab(1200000, 10),
      const TaxSlab(double.infinity, 30),
    ],
    stdDeductionSalary: 75000,
    rebateLimit: 1200000,
    isStdDeductionSalaryEnabled: true,
  );

  setUp(() {
    mockConfig = MockTaxConfigService();
    service = IndianTaxService(mockConfig);
    when(() => mockConfig.getRulesForYear(any())).thenReturn(defaultRules);
  });

  test(
      'Exemption Refactor: independentExemptions do NOT reduce monthly tax but show in forecast',
      () {
    final data = TaxYearData(
      year: 2025,
      salary: SalaryDetails(
        history: [
          SalaryStructure(
            id: 's1',
            effectiveDate: DateTime(2025, 4, 1),
            monthlyBasic: 110000, // 1.32M annual
          )
        ],
        independentExemptions: [
          const CustomExemption(
            id: 'test-id',
            name: 'Huge Planning',
            amount: 200000, // Should save ~20k in tax (10% bracket mostly)
          )
        ],
      ),
    );

    final breakdown =
        service.calculateMonthlySalaryBreakdown(data, defaultRules);

    // Month 4 (April)
    final april = breakdown[4]!;

    // Taxable without exemption = 1.32M - 75k = 1.245M
    // Taxable 1.245M is > 1.2M rebate limit.
    // Marginal Relief applies: tax = (1.245M - 1.2M) = 45k.
    // Cess (4%) = 45k * 0.04 = 1.8k.
    // Total Tax = 46.8k. Monthly = 46.8k / 12 = 3900.
    expect(april['tax']!, closeTo(3900, 10));

    // Savings Forecast
    // Taxable WITH exemption = 1.245M - 200k = 1.045M
    // 1.045M <= 1.2M rebate limit -> Tax = 0.
    // Annual Savings = 46.8k - 0 = 46.8k.
    // Monthly Savings Forecast = 46.8k / 12 = 3900.
    expect(april['taxSavingsForecast']!, closeTo(3900, 10));

    // Smoothed Exemption Display
    // 200k / 12 = 16,666
    expect(april['exemption']!, closeTo(16666, 100));
  });

  test('Model Serialization: CustomExemption simple toMap/fromMap', () {
    const ex = CustomExemption(id: 'e1', name: 'Test', amount: 5000);
    final map = ex.toMap();
    final back = CustomExemption.fromMap(map);

    expect(back.name, 'Test');
    expect(back.amount, 5000);
  });
}
