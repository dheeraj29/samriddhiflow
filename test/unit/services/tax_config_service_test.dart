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
    if (!Hive.isAdapterRegistered(224)) Hive.registerAdapter(TaxRulesAdapter());
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

  test('Handles tag mappings correctly', () async {
    final rules = TaxRules(tagMappings: {'Salary': 'salary'});
    await service.saveRulesForYear(2025, rules);

    final retrieved = service.getRulesForYear(2025);
    expect(retrieved.tagMappings['Salary'], 'salary');
  });

  test('getRulesForYear falls back to Default if no past rules exist',
      () async {
    // Clear all
    await Hive.box<TaxRules>('tax_rules_v2').clear();
    final retrieved = service.getRulesForYear(2030);
    expect(retrieved.stdDeductionSalary, 75000); // v2 default
  });
}
