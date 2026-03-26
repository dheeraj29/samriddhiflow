import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/models/taxes/insurance_policy.dart';
import 'package:samriddhi_flow/models/taxes/tax_data_models.dart';
import 'package:samriddhi_flow/models/taxes/tax_rules.dart';
import 'package:samriddhi_flow/services/taxes/insurance_tax_service.dart';
import 'package:samriddhi_flow/services/taxes/tax_config_service.dart';

class MockTaxConfigService extends Mock implements TaxConfigService {}

InsurancePolicy _policy({
  required String id,
  required double premium,
  required double sumAssured,
  required DateTime start,
  DateTime? maturity,
  bool isUlip = false,
  bool? isTaxExempt,
  bool installmentEnabled = false,
  DateTime? installmentStartDate,
  Map<int, bool> incomeAddedByYear = const {},
}) {
  return InsurancePolicy(
    id: id,
    policyName: id,
    policyNumber: id,
    annualPremium: premium,
    sumAssured: sumAssured,
    startDate: start,
    maturityDate: maturity ?? start.add(const Duration(days: 365)),
    isUnitLinked: isUlip,
    isTaxExempt: isTaxExempt,
    isInstallmentEnabled: installmentEnabled,
    installmentStartDate: installmentStartDate,
    isIncomeAddedByYear: incomeAddedByYear,
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
  late InsuranceTaxService service;

  setUp(() {
    mockConfig = MockTaxConfigService();
    service = InsuranceTaxService(mockConfig);
    when(() => mockConfig.rules).thenReturn(_rules(premiumRules: []));
  });

  group('InsuranceTaxService - optimizeMaturityTax', () {
    test('bypasses aggregate limit for non-ULIP policies before effective date',
        () {
      final rules = _rules(
        premiumRules: [InsurancePremiumRule(DateTime(2012, 4, 1), 10.0)],
        nonUlipLimit: 100000,
      );
      when(() => mockConfig.rules).thenReturn(rules);

      final result = service.optimizeMaturityTax([
        _policy(
          id: 'legacy',
          premium: 400000,
          sumAssured: 5000000,
          start: DateTime(2020, 1, 1),
        ),
      ]);

      expect(result.single.isTaxExempt, isTrue);
    });

    test('marks policy as taxable if premium exceeds 10% for post-2012 policy',
        () {
      when(() => mockConfig.rules).thenReturn(_rules(premiumRules: [
        InsurancePremiumRule(DateTime(2012, 4, 1), 10.0),
      ]));

      final result = service.optimizeMaturityTax([
        _policy(
          id: 'high-premium',
          premium: 150000,
          sumAssured: 1000000,
          start: DateTime(2015, 1, 1),
        ),
      ]);

      expect(result.single.isTaxExempt, isFalse);
    });

    test('marks policy as exempt if premium is within 10% for post-2012 policy',
        () {
      when(() => mockConfig.rules).thenReturn(_rules(premiumRules: [
        InsurancePremiumRule(DateTime(2012, 4, 1), 10.0),
      ]));

      final result = service.optimizeMaturityTax([
        _policy(
          id: 'exempt-premium',
          premium: 8000,
          sumAssured: 100000,
          start: DateTime(2015, 4, 1),
          maturity: DateTime(2025, 4, 1),
        ),
      ]);

      expect(result.single.isTaxExempt, isTrue);
    });

    test('applies ULIP aggregate limit after effective date', () {
      when(() => mockConfig.rules).thenReturn(_rules(
        premiumRules: [InsurancePremiumRule(DateTime(2012, 4, 1), 10.0)],
        ulipEffective: DateTime(2021, 2, 1),
        ulipLimit: 50000,
      ));

      final result = service.optimizeMaturityTax([
        _policy(
          id: 'ulip-1',
          premium: 30000,
          sumAssured: 1000000,
          start: DateTime(2024, 1, 1),
          isUlip: true,
        ),
        _policy(
          id: 'ulip-2',
          premium: 30000,
          sumAssured: 900000,
          start: DateTime(2024, 2, 1),
          isUlip: true,
        ),
      ]);

      expect(result[0].isTaxExempt, isTrue);
      expect(result[1].isTaxExempt, isFalse);
    });

    test('applies non-ULIP aggregate limit after effective date', () {
      final result = service.optimizeMaturityTax([
        _policy(
          id: 'non-ulip-1',
          premium: 300000,
          sumAssured: 4000000,
          start: DateTime(2024, 4, 1),
        ),
        _policy(
          id: 'non-ulip-2',
          premium: 300000,
          sumAssured: 4000000,
          start: DateTime(2024, 4, 1),
        ),
      ]);

      expect(result.where((policy) => policy.isTaxExempt == true).length, 1);
      expect(result.where((policy) => policy.isTaxExempt == false).length, 1);
    });
  });

  group('InsuranceTaxService - calculateTaxableIncomeSplit', () {
    test('handles lump sum and installments', () {
      final lumpSum = _policy(
        id: 'lump',
        premium: 10000,
        sumAssured: 100000,
        start: DateTime(2020, 1, 1),
        maturity: DateTime(2025, 1, 1),
        isTaxExempt: false,
      );
      final installment = _policy(
        id: 'installment',
        premium: 10000,
        sumAssured: 100000,
        start: DateTime(2020, 1, 1),
        maturity: DateTime(2025, 1, 1),
        isTaxExempt: false,
        installmentEnabled: true,
        installmentStartDate: DateTime(2023, 1, 1),
      );

      final lumpSplit = service.calculateTaxableIncomeSplit(lumpSum);
      final installmentSplit = service.calculateTaxableIncomeSplit(installment);

      expect(lumpSplit['saleConsideration'], 100000);
      expect(lumpSplit['costOfAcquisition'], 50000);
      expect(lumpSplit['taxableGain'], 50000);
      expect(lumpSplit['totalGain'], 50000);

      expect(installmentSplit['saleConsideration'], 20000);
      expect(installmentSplit['costOfAcquisition'], 10000);
      expect(installmentSplit['taxableGain'], 10000);
    });

    test('clamps negative gains to zero', () {
      final split = service.calculateTaxableIncomeSplit(_policy(
        id: 'loss-policy',
        premium: 20000,
        sumAssured: 150000,
        start: DateTime(2020, 1, 1),
        maturity: DateTime(2030, 1, 1),
        isTaxExempt: false,
      ));

      expect(split['saleConsideration'], 150000);
      expect(split['costOfAcquisition'], 150000);
      expect(split['taxableGain'], 0);
      expect(split['totalGain'], 0);
    });
  });

  group('InsuranceTaxService - year applicability', () {
    test('matches a standard policy maturing in the target year', () {
      final policy = _policy(
        id: 'maturity',
        premium: 10000,
        sumAssured: 150000,
        start: DateTime(2020, 1, 1),
        maturity: DateTime(2025, 6, 1),
      );

      expect(service.isApplicableForYear(policy, 2025), isTrue);
      expect(service.isApplicableForYear(policy, 2024), isFalse);
      expect(service.getEventDateForYear(policy, 2025), DateTime(2025, 6, 1));
    });

    test('prefers installment events within the target year', () {
      final policy = _policy(
        id: 'event-policy',
        premium: 10000,
        sumAssured: 100000,
        start: DateTime(2020, 1, 1),
        maturity: DateTime(2027, 3, 31),
        isTaxExempt: false,
        installmentEnabled: true,
        installmentStartDate: DateTime(2025, 5, 1),
      );

      expect(service.isApplicableForYear(policy, 2025), isTrue);
      expect(service.getEventDateForYear(policy, 2025), DateTime(2025, 5, 1));
      expect(service.getEventDateForYear(policy, 2024), isNull);
    });

    test('returns null for installment years outside the payout window', () {
      final policy = _policy(
        id: 'out-of-range',
        premium: 10000,
        sumAssured: 150000,
        start: DateTime(2020, 4, 1),
        maturity: DateTime(2030, 4, 1),
        installmentEnabled: true,
        installmentStartDate: DateTime(2020, 4, 1),
      );

      expect(service.isApplicableForYear(policy, 2031), isFalse);
      expect(service.getEventDateForYear(policy, 2018), isNull);
    });
  });

  group('InsuranceTaxService - summary and entries', () {
    test('aggregates current and future gains in the insurance summary', () {
      final currentYearPolicy = _policy(
        id: 'current',
        premium: 10000,
        sumAssured: 100000,
        start: DateTime(2020, 1, 1),
        maturity: DateTime(2025, 6, 1),
        isTaxExempt: false,
      );
      final futureInstallmentPolicy = _policy(
        id: 'future-ulip',
        premium: 10000,
        sumAssured: 120000,
        start: DateTime(2022, 4, 1),
        maturity: DateTime(2028, 4, 1),
        isUlip: true,
        isTaxExempt: false,
        installmentEnabled: true,
        installmentStartDate: DateTime(2026, 4, 1),
      );
      final pendingPolicy = _policy(
        id: 'pending',
        premium: 5000,
        sumAssured: 50000,
        start: DateTime(2024, 1, 1),
      );

      final summary = service.calculateInsuranceSummaryData(
        [currentYearPolicy, futureInstallmentPolicy, pendingPolicy],
        2025,
      );

      expect(summary.totalPremium, 25000);
      expect(summary.currentTaxableGain, 50000);
      expect(summary.futureTaxableGain, closeTo(30000, 0.001));
      expect(summary.taxableUlipTotal, 60000);
      expect(summary.taxableNonUlipTotal, 50000);
      expect(summary.hasPendingCalculations, isTrue);
    });

    test('returns correct taxable income entry types and null when exempt', () {
      final ulipPolicy = _policy(
        id: 'ulip',
        premium: 10000,
        sumAssured: 80000,
        start: DateTime(2022, 4, 1),
        maturity: DateTime(2028, 4, 1),
        isUlip: true,
        isTaxExempt: false,
        installmentEnabled: true,
        installmentStartDate: DateTime(2025, 5, 1),
      );
      final nonUlipPolicy = _policy(
        id: 'non-ulip',
        premium: 10000,
        sumAssured: 100000,
        start: DateTime(2020, 1, 1),
        maturity: DateTime(2025, 6, 1),
        isTaxExempt: false,
      );
      final exemptPolicy = _policy(
        id: 'exempt',
        premium: 10000,
        sumAssured: 100000,
        start: DateTime(2020, 1, 1),
        maturity: DateTime(2025, 6, 1),
        isTaxExempt: true,
      );

      final ulipEntry = service.getTaxableIncomeEntry(ulipPolicy, 2025);
      final nonUlipEntry = service.getTaxableIncomeEntry(nonUlipPolicy, 2025);

      expect(ulipEntry, isA<CapitalGainEntry>());
      expect(ulipEntry.description, contains('Insurance Payout: ulip'));
      expect(nonUlipEntry, isA<OtherIncome>());
      expect(nonUlipEntry.name, contains('Insurance Maturity: non-ulip'));
      expect(service.getTaxableIncomeEntry(exemptPolicy, 2025), isNull);
      expect(
        service.hasUnaddedTaxableInsurance(
          [
            nonUlipPolicy.copyWith(isIncomeAddedByYear: {2025: false}),
          ],
          2025,
        ),
        isTrue,
      );
    });
  });
}
