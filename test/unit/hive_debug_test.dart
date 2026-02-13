import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:samriddhi_flow/models/taxes/tax_rules.dart';

void main() {
  test('Hive Write TaxRules Debug', () async {
    final tempDir = Directory.systemTemp.createTempSync('hive_debug');
    Hive.init(tempDir.path);

    // Register Adapters as in providers.dart
    Hive.registerAdapter<TaxRules>(TaxRulesAdapter());
    Hive.registerAdapter<TaxSlab>(TaxSlabAdapter());
    Hive.registerAdapter<TaxExemptionRule>(TaxExemptionRuleAdapter());
    Hive.registerAdapter<InsurancePremiumRule>(InsurancePremiumRuleAdapter());
    Hive.registerAdapter<TaxMappingRule>(TaxMappingRuleAdapter());

    // Create a TaxRules object exactly like fromMap
    final map = {
      'currencyLimit10_10D': 500000,
      'stdDeductionSalary': 75000,
      'slabs': [
        {'upto': 400000, 'rate': 0},
        {'upto': 800000, 'rate': 5}
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
      'insurancePremiumRules': [
        {'startDate': '2000-01-01T00:00:00.000', 'limitPercentage': 10.0}
      ],
      'advancedTagMappings': [
        {'categoryName': 'Test', 'taxHead': 'Salary'}
      ]
    };

    final rules = TaxRules.fromMap(map);

    final box = await Hive.openBox<TaxRules>('tax_rules_debug');

    try {
      await box.put(2025, rules);
      // print("Write Successful!");
    } catch (e) {
      // print("Write Failed: $e");
      rethrow;
    } finally {
      await box.close();
      tempDir.deleteSync(recursive: true);
    }
  });
}
