import 'package:flutter_test/flutter_test.dart';
import 'package:samriddhi_flow/models/taxes/tax_rules.dart';

void main() {
  group('TaxExemptionRule', () {
    test('copyWith overrides all fields', () {
      const rule = TaxExemptionRule(
        id: 'r1',
        name: 'Standard',
        incomeHead: 'Salary',
        limit: 50000,
      );

      final updated = rule.copyWith(
        id: 'r2',
        name: 'Custom',
        incomeHead: 'Business',
        limit: 100000,
        isPercentage: true,
        isEnabled: false,
        isCliffExemption: true,
      );

      expect(updated.id, 'r2');
      expect(updated.name, 'Custom');
      expect(updated.incomeHead, 'Business');
      expect(updated.limit, 100000);
      expect(updated.isPercentage, true);
      expect(updated.isEnabled, false);
      expect(updated.isCliffExemption, true);
    });

    test('toMap and fromMap roundtrip', () {
      const rule = TaxExemptionRule(
        id: 'e1',
        name: 'Gift Exemption',
        incomeHead: 'otherIncome',
        limit: 50000,
        isCliffExemption: true,
      );

      final map = rule.toMap();
      final restored = TaxExemptionRule.fromMap(map);
      expect(restored.id, 'e1');
      expect(restored.name, 'Gift Exemption');
      expect(restored.isCliffExemption, true);
    });

    test('fromMap with missing/null fields uses defaults', () {
      final rule = TaxExemptionRule.fromMap({});
      expect(rule.name, '');
      expect(rule.incomeHead, '');
      expect(rule.limit, 0);
      expect(rule.isPercentage, false);
      expect(rule.isEnabled, true);
      expect(rule.isCliffExemption, false);
    });
  });

  group('TaxSlab', () {
    test('isUnlimited returns true for infinity substitute', () {
      const slab = TaxSlab(TaxRules.infinitySubstitute, 30);
      expect(slab.isUnlimited, true);

      const normalSlab = TaxSlab(500000, 5);
      expect(normalSlab.isUnlimited, false);
    });

    test('toMap and fromMap roundtrip', () {
      const slab = TaxSlab(400000, 5.0);
      final map = slab.toMap();
      final restored = TaxSlab.fromMap(map);
      expect(restored.upto, 400000);
      expect(restored.rate, 5.0);
    });
  });

  group('InsurancePremiumRule', () {
    test('toMap and fromMap roundtrip', () {
      final rule = InsurancePremiumRule(DateTime(2012, 4, 1), 10.0);
      final map = rule.toMap();
      final restored = InsurancePremiumRule.fromMap(map);
      expect(restored.limitPercentage, 10.0);
    });
  });

  group('TaxMappingRule', () {
    test('copyWith overrides fields', () {
      const rule = TaxMappingRule(
        categoryName: 'Investments',
        taxHead: 'capitalGain',
        matchDescriptions: ['stock', 'mutual fund'],
      );

      final updated = rule.copyWith(
        categoryName: 'Income',
        taxHead: 'salary',
        excludeDescriptions: ['bonus'],
        minHoldingMonths: 12,
      );

      expect(updated.categoryName, 'Income');
      expect(updated.taxHead, 'salary');
      expect(updated.excludeDescriptions, ['bonus']);
      expect(updated.minHoldingMonths, 12);
    });

    test('toMap and fromMap roundtrip', () {
      const rule = TaxMappingRule(
        categoryName: 'Salary',
        taxHead: 'salary',
        matchDescriptions: ['pay'],
        excludeDescriptions: ['reimburse'],
        minHoldingMonths: null,
      );

      final map = rule.toMap();
      final restored = TaxMappingRule.fromMap(map);
      expect(restored.categoryName, 'Salary');
      expect(restored.matchDescriptions, ['pay']);
      expect(restored.excludeDescriptions, ['reimburse']);
    });
  });

  group('AdvanceTaxInstallmentRule', () {
    test('copyWith overrides fields', () {
      const rule = AdvanceTaxInstallmentRule(
        startMonth: 4,
        startDay: 1,
        endMonth: 6,
        endDay: 15,
        requiredPercentage: 15.0,
        interestRate: 1.0,
      );

      final updated = rule.copyWith(
        startMonth: 7,
        requiredPercentage: 45.0,
      );

      expect(updated.startMonth, 7);
      expect(updated.requiredPercentage, 45.0);
      expect(updated.endMonth, 6); // preserved
    });

    test('toMap and fromMap roundtrip', () {
      const rule = AdvanceTaxInstallmentRule(
        startMonth: 9,
        startDay: 16,
        endMonth: 12,
        endDay: 15,
        requiredPercentage: 75.0,
        interestRate: 1.0,
      );

      final map = rule.toMap();
      final restored = AdvanceTaxInstallmentRule.fromMap(map);
      expect(restored.startMonth, 9);
      expect(restored.requiredPercentage, 75.0);
    });
  });

  group('TaxRules', () {
    test('toMap and fromMap roundtrip preserves all fields', () {
      final rules = TaxRules(
        currencyLimit10_10D: 600000,
        stdDeductionSalary: 80000,
        rebateLimit: 1500000,
        jurisdiction: 'India',
        is44ADEnabled: false,
        limit44AD: 30000000,
        profileId: 'test_profile',
      );

      final map = rules.toMap();
      final restored = TaxRules.fromMap(map);
      expect(restored.currencyLimit10_10D, 600000);
      expect(restored.stdDeductionSalary, 80000);
      expect(restored.rebateLimit, 1500000);
      expect(restored.is44ADEnabled, false);
      expect(restored.limit44AD, 30000000);
      expect(restored.profileId, 'test_profile');
    });

    test('fromMap with empty map uses all defaults', () {
      final rules = TaxRules.fromMap({});
      expect(rules.currencyLimit10_10D, 500000);
      expect(rules.stdDeductionSalary, 75000);
      expect(rules.cessRate, 4.0);
      expect(rules.slabs, isEmpty); // null slabs → []
    });

    test('fromMap with slabs list parses correctly', () {
      final rules = TaxRules.fromMap({
        'slabs': [
          {'upto': 400000, 'rate': 0},
          {'upto': 800000, 'rate': 5},
        ],
      });
      expect(rules.slabs.length, 2);
      expect(rules.slabs[0].rate, 0);
      expect(rules.slabs[1].rate, 5);
    });

    test('copyWith overrides selected fields', () {
      final rules = TaxRules();
      final updated = rules.copyWith(
        cessRate: 5.0,
        isRebateEnabled: false,
        profileId: 'new_profile',
      );
      expect(updated.cessRate, 5.0);
      expect(updated.isRebateEnabled, false);
      expect(updated.profileId, 'new_profile');
      expect(updated.stdDeductionSalary, 75000); // preserved
    });
  });
}
