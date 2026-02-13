import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:samriddhi_flow/models/taxes/tax_rules.dart';
import 'package:samriddhi_flow/services/taxes/tax_config_service.dart';

void main() {
  test('TaxConfigService Robust Restore Test', () async {
    final tempDir = Directory.systemTemp.createTempSync('hive_restore_test');
    Hive.init(tempDir.path);

    // Register Adapters externally (Simulating providers.dart)
    Hive.registerAdapter<TaxRules>(TaxRulesAdapter());
    Hive.registerAdapter<TaxSlab>(TaxSlabAdapter());
    Hive.registerAdapter<TaxExemptionRule>(TaxExemptionRuleAdapter());
    Hive.registerAdapter<InsurancePremiumRule>(InsurancePremiumRuleAdapter());
    Hive.registerAdapter<TaxMappingRule>(TaxMappingRuleAdapter());

    // Note: We deliberately do NOT register adapters here externally
    // to test if the Service registers them internally as expected.

    final service = TaxConfigService();
    await service.init();

    // Create a complex map simulating cloud data
    // This map might contain "dynamic" types or extra fields that usually cause issues
    final Map<int, TaxRules> cloudData = {};

    final rulesMap = {
      'currencyLimit10_10D': 500000,
      'stdDeductionSalary': 75000,
      'slabs': [
        {'upto': 400000.0, 'rate': 0.0}, // Double explicitly
        {'upto': 800000, 'rate': 5} // Int mixed
      ],
      'tagMappings': {'Shop': 'Business'},
      'customExemptions': [
        {
          'name': 'Test Exempt',
          'incomeHead': 'Salary',
          'limit': 1000,
          'isPercentage': false,
          'isEnabled': true
        }
      ],
      // Simulate an "unknown" field that should be stripped by fromMap
      'unknown_field_from_future_version': 'some_value'
    };

    cloudData[2024] = TaxRules.fromMap(rulesMap);
    cloudData[2025] = TaxRules();

    try {
      await service.restoreAllRules(cloudData);
      // print("Restore Successful!");

      // Verify data
      final restored2024 = service.getRulesForYear(2024);
      expect(restored2024.stdDeductionSalary, 75000);
      expect(restored2024.slabs.length, 2);
    } catch (e) {
      fail("Restore failed with error: $e");
    } finally {
      // Cleanup
      try {
        await Hive.deleteBoxFromDisk('tax_rules_v2');
      } catch (_) {}
      tempDir.deleteSync(recursive: true);
    }
  });
}
