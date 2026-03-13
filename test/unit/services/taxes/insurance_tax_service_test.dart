import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/models/taxes/insurance_policy.dart';
import 'package:samriddhi_flow/models/taxes/tax_rules.dart';
import 'package:samriddhi_flow/services/taxes/insurance_tax_service.dart';
import 'package:samriddhi_flow/services/taxes/tax_config_service.dart';

class MockTaxConfigService extends Mock implements TaxConfigService {}

void main() {
  late InsuranceTaxService service;
  late MockTaxConfigService mockConfig;

  setUp(() {
    mockConfig = MockTaxConfigService();
    service = InsuranceTaxService(mockConfig);

    // Default rules
    final rules = TaxRules();
    when(() => mockConfig.rules).thenReturn(rules);
  });

  group('InsuranceTaxService - optimizeMaturityTax', () {
    test('marks policy as taxable if premium exceeds 10% for post-2012 policy',
        () {
      final policy = InsurancePolicy.create(
        name: 'Taxable Policy',
        number: '123',
        premium: 15000,
        sumAssured: 100000, // 15% > 10%
        start: DateTime(2015, 4, 1),
        maturity: DateTime(2025, 4, 1),
      );

      final results = service.optimizeMaturityTax([policy]);
      expect(results.first.isTaxExempt, false);
    });

    test('marks policy as exempt if premium is within 10% for post-2012 policy',
        () {
      final policy = InsurancePolicy.create(
        name: 'Exempt Policy',
        number: '123',
        premium: 8000,
        sumAssured: 100000, // 8% < 10%
        start: DateTime(2015, 4, 1),
        maturity: DateTime(2025, 4, 1),
      );

      final results = service.optimizeMaturityTax([policy]);
      expect(results.first.isTaxExempt, true);
    });

    test('Aggregate Limit Rule - ULIPs over 2.5L premium after 2021', () {
      final policy1 = InsurancePolicy.create(
        name: 'ULIP 1',
        number: 'U1',
        premium: 150000,
        sumAssured: 2000000,
        start: DateTime(2022, 4, 1),
        maturity: DateTime(2032, 4, 1),
        isUlip: true,
      );
      final policy2 = InsurancePolicy.create(
        name: 'ULIP 2',
        number: 'U2',
        premium: 150000,
        sumAssured: 2000000,
        start: DateTime(2022, 4, 1),
        maturity: DateTime(2032, 4, 1),
        isUlip: true,
      );

      // Total 3L > 2.5L limit
      final results = service.optimizeMaturityTax([policy1, policy2]);

      // One should be exempt, one taxable (order depends on optimization which sorts by sumAssured)
      // Since both have same sumAssured, it depends on list order.
      final exemptCount = results.where((p) => p.isTaxExempt == true).length;
      final taxableCount = results.where((p) => p.isTaxExempt == false).length;

      expect(exemptCount, 1);
      expect(taxableCount, 1);
    });

    test('Aggregate Limit Rule - Non-ULIPs over 5L premium after 2023', () {
      final policy1 = InsurancePolicy.create(
        name: 'Non-ULIP 1',
        number: 'N1',
        premium: 300000,
        sumAssured: 4000000,
        start: DateTime(2024, 4, 1),
        maturity: DateTime(2034, 4, 1),
        isUlip: false,
      );
      final policy2 = InsurancePolicy.create(
        name: 'Non-ULIP 2',
        number: 'N2',
        premium: 300000,
        sumAssured: 4000000,
        start: DateTime(2024, 4, 1),
        maturity: DateTime(2034, 4, 1),
        isUlip: false,
      );

      // Total 6L > 5L limit
      final results = service.optimizeMaturityTax([policy1, policy2]);

      expect(results.where((p) => p.isTaxExempt == true).length, 1);
      expect(results.where((p) => p.isTaxExempt == true).length, 1);
      expect(results.where((p) => p.isTaxExempt == false).length, 1);
    });
  });

  group('InsuranceTaxService - calculateTaxableIncomeSplit', () {
    test('Standard Policy - Single Payout', () {
      final policy = InsurancePolicy.create(
        name: 'Standard',
        number: '1',
        premium: 10000,
        sumAssured: 150000,
        start: DateTime(2020, 1, 1),
        maturity: DateTime(2030, 1, 1), // 10 years
      );

      final split = service.calculateTaxableIncomeSplit(policy);

      expect(split['saleConsideration'], 150000);
      expect(split['costOfAcquisition'], 100000);
      expect(split['taxableGain'], 50000);
      expect(split['totalGain'], 50000);
    });

    test('Installment Policy - Split Gain', () {
      final policy = InsurancePolicy.create(
        name: 'Installment',
        number: '2',
        premium: 10000,
        sumAssured: 150000,
        start: DateTime(2020, 1, 1),
        maturity: DateTime(2030, 1, 1), // 10 years
        isInstallmentEnabled: true,
      );

      final split = service.calculateTaxableIncomeSplit(policy);

      expect(split['saleConsideration'], 15000);
      expect(split['costOfAcquisition'], 10000);
      expect(split['taxableGain'], 5000);
      expect(split['totalGain'], 50000);
    });

    test('Negative Gain (Loss) - Clamp to 0', () {
      final policy = InsurancePolicy.create(
        name: 'Loss Policy',
        number: '3',
        premium: 20000,
        sumAssured: 150000,
        start: DateTime(2020, 1, 1),
        maturity: DateTime(2030, 1, 1), // 10 years, 200k premium
      );

      final split = service.calculateTaxableIncomeSplit(policy);

      expect(split['saleConsideration'], 150000);
      expect(split['costOfAcquisition'], 150000);
      expect(split['taxableGain'], 0);
      expect(split['totalGain'], 0);
    });
  });

  group('InsuranceTaxService - isApplicableForYear', () {
    test('Standard Policy maturing in FY', () {
      final policy = InsurancePolicy.create(
        name: 'Maturity',
        number: '1',
        premium: 10000,
        sumAssured: 150000,
        start: DateTime(2020, 1, 1),
        maturity: DateTime(2025, 6, 1),
      );

      expect(service.isApplicableForYear(policy, 2025), true);
      expect(service.isApplicableForYear(policy, 2024), false);
    });

    test('Installment Policy with payout in FY', () {
      final policy = InsurancePolicy.create(
        name: 'Installment',
        number: '2',
        premium: 10000,
        sumAssured: 150000,
        start: DateTime(2020, 4, 1),
        maturity: DateTime(2030, 4, 1),
        isInstallmentEnabled: true,
        installmentStartDate: DateTime(2020, 4, 1),
      );

      // FY 2031-32 is after maturity
      expect(service.isApplicableForYear(policy, 2031), false);
    });
  });

  group('InsuranceTaxService - getEventDateForYear', () {
    test('Standard Policy - returns maturity date', () {
      final policy = InsurancePolicy.create(
        name: 'Maturity',
        number: '1',
        premium: 10000,
        sumAssured: 150000,
        start: DateTime(2020, 1, 1),
        maturity: DateTime(2025, 6, 1),
      );

      final date = service.getEventDateForYear(policy, 2025);
      expect(date, DateTime(2025, 6, 1));
    });

    test('Installment Policy - returns current year installment date', () {
      final policy = InsurancePolicy.create(
        name: 'Installment',
        number: '2',
        premium: 10000,
        sumAssured: 150000,
        start: DateTime(2020, 4, 1),
        maturity: DateTime(2030, 4, 1),
        isInstallmentEnabled: true,
        installmentStartDate: DateTime(2020, 4, 1),
      );

      // April 2025 is in FY 2025-26
      expect(service.getEventDateForYear(policy, 2025), DateTime(2025, 4, 1));
      // April 2026 is in FY 2026-27
      expect(service.getEventDateForYear(policy, 2026), DateTime(2026, 4, 1));
      // Out of range
      expect(service.getEventDateForYear(policy, 2018), null);
    });
  });
}
