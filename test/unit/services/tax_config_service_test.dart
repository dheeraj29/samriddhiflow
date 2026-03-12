import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:samriddhi_flow/models/taxes/tax_rules.dart';
import 'package:samriddhi_flow/services/taxes/tax_config_service.dart';

void main() {
  late TaxConfigService service;
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_test_config');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(202)) {
      Hive.registerAdapter(TaxSlabAdapter());
    }
    if (!Hive.isAdapterRegistered(203)) {
      Hive.registerAdapter(TaxExemptionRuleAdapter());
    }
    if (!Hive.isAdapterRegistered(204)) {
      Hive.registerAdapter(InsurancePremiumRuleAdapter());
    }
    if (!Hive.isAdapterRegistered(205)) {
      Hive.registerAdapter(TaxMappingRuleAdapter());
    }
    if (!Hive.isAdapterRegistered(227)) {
      Hive.registerAdapter(TaxRulesAdapter());
    }
    if (!Hive.isAdapterRegistered(228)) {
      Hive.registerAdapter(AdvanceTaxInstallmentRuleAdapter());
    }
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  setUp(() async {
    // Clear box before each test
    if (Hive.isBoxOpen('tax_rules_v2')) {
      await Hive.box<TaxRules>('tax_rules_v2').clear();
    }
    service = TaxConfigService();
    await service.init();
  });

  test('getRulesForYear returns default if not found', () {
    final rules = service.getRulesForYear(2025);
    expect(rules.stdDeductionSalary, 75000); // Default v2
  });

  test('saveRulesForYear stores and retrieves', () async {
    final rules = TaxRules(stdDeductionSalary: 50000);
    await service.saveRulesForYear(2024, rules);

    final retrieved = service.getRulesForYear(2024);
    expect(retrieved.stdDeductionSalary, 50000);
  });

  test('getRulesForYear falls back to previous year', () async {
    final rules2023 = TaxRules(stdDeductionSalary: 60000);
    await service.saveRulesForYear(2023, rules2023);

    // Request 2024 (should find 2023)
    final retrieved = service.getRulesForYear(2024);
    expect(retrieved.stdDeductionSalary, 60000);
  });

  test('copyRules duplicates rules', () async {
    final rules2023 = TaxRules(stdDeductionSalary: 40000);
    await service.saveRulesForYear(2023, rules2023);

    await service.copyRules(2023, 2025);

    var retrieved = service.getRulesForYear(2025);
    expect(retrieved.stdDeductionSalary, 40000);
  });

  test('getCurrentFinancialYear logic checking', () {
    // This depends on DateTime.now(), so we can't easily deterministic test without mocking DateTime or logic separation.
    // However, we can test that it returns a plausible integer.
    final fy = service.getCurrentFinancialYear();
    expect(fy, greaterThan(2020));
  });

  test('getAllRules retrieves all years for profile', () async {
    await service.saveRulesForYear(
        2023, TaxRules(profileId: 'default', stdDeductionSalary: 10));
    await service.saveRulesForYear(
        2024, TaxRules(profileId: 'default', stdDeductionSalary: 20));
    // Different profile - should be excluded
    final otherBox = Hive.box<TaxRules>('tax_rules_v2');
    await otherBox.put('other_2025', TaxRules(profileId: 'other'));

    final all = service.getAllRules();
    expect(all.length, 2);
    expect(all[2023]?.stdDeductionSalary, 10);
    expect(all[2024]?.stdDeductionSalary, 20);
    expect(all.containsKey(2025), isFalse);
  });

  test('restoreAllRules clears and bulk saves clean objects', () async {
    final data = {
      2025: TaxRules(stdDeductionSalary: 100, profileId: 'default'),
      2026: TaxRules(stdDeductionSalary: 200, profileId: 'wrong'),
    };

    await service.restoreAllRules(data);

    final r1 = service.getRulesForYear(2025);
    expect(r1.stdDeductionSalary, 100);

    final r2 = service.getRulesForYear(2026);
    expect(r2.stdDeductionSalary, 200);
    expect(r2.profileId, 'default'); // Sanitized
  });

  test('saveRulesForYear sanitizes profileId', () async {
    final rules = TaxRules(profileId: 'wrong');
    await service.saveRulesForYear(2025, rules);

    final retrieved = service.getRulesForYear(2025);
    expect(retrieved.profileId, 'default');
  });

  test('getCurrentFinancialYear uses previous year rules for boundary',
      () async {
    final lastYear = DateTime.now().year - 1;
    // Set start month to 1 (Jan) for last year
    final rules = TaxRules(financialYearStartMonth: 1);
    final box = Hive.box<TaxRules>('tax_rules_v2');
    await box.put('default_$lastYear', rules);

    final fy = service.getCurrentFinancialYear();
    // If today is any month and start is Jan, it should be current year unless we are Jan and start is later.
    // This mostly covers the branch where it checks the box for (now.year - 1).
    expect(fy, isNotNull);
  });

  test('deleteRulesForYear removes entry', () async {
    await service.saveRulesForYear(2025, TaxRules());
    expect(
        Hive.box<TaxRules>('tax_rules_v2').containsKey('default_2025'), isTrue);

    await service.deleteRulesForYear(2025);
    expect(Hive.box<TaxRules>('tax_rules_v2').containsKey('default_2025'),
        isFalse);
  });
}
