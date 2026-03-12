import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/models/taxes/insurance_policy.dart';
import 'package:samriddhi_flow/models/taxes/tax_rules.dart';
import 'package:samriddhi_flow/services/taxes/insurance_tax_service.dart';
import 'package:samriddhi_flow/services/taxes/tax_config_service.dart';

class MockTaxConfigService extends Mock implements TaxConfigService {}

InsurancePolicy _policy({
  required String id,
  required double premium,
  required double sumAssured,
  required DateTime start,
  bool isUlip = false,
}) {
  return InsurancePolicy(
    id: id,
    policyName: id,
    policyNumber: id,
    annualPremium: premium,
    sumAssured: sumAssured,
    startDate: start,
    maturityDate: start.add(const Duration(days: 365)),
    isUnitLinked: isUlip,
  );
}

TaxRules _rules({
  required List<InsurancePremiumRule> premiumRules,
  DateTime? ulipEffective,
  DateTime? nonUlipEffective,
  double ulipLimit = 250000,
  double nonUlipLimit = 500000,
}) {
  return TaxRules(
    insurancePremiumRules: premiumRules,
    dateEffectiveULIP: ulipEffective ?? DateTime(2021, 2, 1),
    dateEffectiveNonULIP: nonUlipEffective ?? DateTime(2023, 4, 1),
    limitInsuranceULIP: ulipLimit,
    limitInsuranceNonULIP: nonUlipLimit,
  );
}

void main() {
  late MockTaxConfigService mockConfig;

  setUp(() {
    mockConfig = MockTaxConfigService();
  });

  test('marks policy taxable when premium exceeds applicable percent limit',
      () {
    final rules = _rules(premiumRules: [
      InsurancePremiumRule(DateTime(2012, 4, 1), 10.0),
      InsurancePremiumRule(DateTime(2003, 4, 1), 20.0),
    ]);
    when(() => mockConfig.rules).thenReturn(rules);

    final service = InsuranceTaxService(mockConfig);
    final policy = _policy(
      id: 'p1',
      premium: 15000,
      sumAssured: 100000,
      start: DateTime(2015, 1, 1),
    );

    final result = service.optimizeMaturityTax([policy]);
    expect(result.single.isTaxExempt, isFalse);
  });

  test('applies ULIP aggregate limit after effective date', () {
    final rules = _rules(premiumRules: [
      InsurancePremiumRule(DateTime(2012, 4, 1), 10.0),
    ]);
    when(() => mockConfig.rules).thenReturn(rules);

    final service = InsuranceTaxService(mockConfig);
    final p1 = _policy(
      id: 'ulip1',
      premium: 200000,
      sumAssured: 2500000,
      start: DateTime(2022, 1, 1),
      isUlip: true,
    );
    final p2 = _policy(
      id: 'ulip2',
      premium: 100000,
      sumAssured: 2000000,
      start: DateTime(2022, 1, 1),
      isUlip: true,
    );

    final result = service.optimizeMaturityTax([p2, p1]);
    final byId = {for (final p in result) p.id: p};

    expect(byId['ulip1']?.isTaxExempt, isTrue);
    expect(byId['ulip2']?.isTaxExempt, isFalse);
  });

  test('applies Non-ULIP aggregate limit after effective date', () {
    final rules = _rules(premiumRules: [
      InsurancePremiumRule(DateTime(2012, 4, 1), 10.0),
    ], nonUlipLimit: 500000);
    when(() => mockConfig.rules).thenReturn(rules);

    final service = InsuranceTaxService(mockConfig);
    final p1 = _policy(
      id: 'n1',
      premium: 300000,
      sumAssured: 4000000,
      start: DateTime(2024, 5, 1),
    );
    final p2 = _policy(
      id: 'n2',
      premium: 300000,
      sumAssured: 3500000,
      start: DateTime(2024, 5, 1),
    );

    final result = service.optimizeMaturityTax([p2, p1]);
    final byId = {for (final p in result) p.id: p};

    expect(byId['n1']?.isTaxExempt, isTrue);
    expect(byId['n2']?.isTaxExempt, isFalse);
  });

  test('Non-ULIP before effective date bypasses aggregate limit', () {
    final rules = _rules(premiumRules: [
      InsurancePremiumRule(DateTime(2012, 4, 1), 10.0),
    ], nonUlipLimit: 100000);
    when(() => mockConfig.rules).thenReturn(rules);

    final service = InsuranceTaxService(mockConfig);
    final policy = _policy(
      id: 'legacy',
      premium: 400000,
      sumAssured: 5000000,
      start: DateTime(2020, 1, 1),
    );

    final result = service.optimizeMaturityTax([policy]);
    expect(result.single.isTaxExempt, isTrue);
  });
}
