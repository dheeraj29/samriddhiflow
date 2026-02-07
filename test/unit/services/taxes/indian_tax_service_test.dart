import 'package:flutter_test/flutter_test.dart';
import 'package:samriddhi_flow/models/taxes/tax_data.dart';
import 'package:samriddhi_flow/models/taxes/tax_data_models.dart';
import 'package:samriddhi_flow/models/taxes/tax_rules.dart';
import 'package:samriddhi_flow/services/taxes/indian_tax_service.dart';
import 'package:samriddhi_flow/services/taxes/tax_config_service.dart';

// Fake Config Service
class FakeTaxConfigService extends Fake implements TaxConfigService {
  @override
  TaxRules getRulesForYear(int year) {
    // Return a dummy rules object if called
    return TaxRules();
  }
}

void main() {
  group('IndianTaxService Partial Integration', () {
    late IndianTaxService service;
    late TaxRules rules;
    late TaxYearData baseData;

    setUp(() {
      service = IndianTaxService(FakeTaxConfigService());

      // Default Rules mimicking New Regime FY 25-26
      rules = TaxRules(
        // slabs: List of TaxSlab(upto, rate) positional
        slabs: const [
          TaxSlab(300000, 0),
          TaxSlab(600000, 5),
          TaxSlab(900000, 10),
          TaxSlab(1200000, 15),
          TaxSlab(1500000, 20),
          TaxSlab(double.infinity, 30),
        ],
        stdDeductionSalary: 75000,
        rebateLimit: 700000, // 87A Limit
        agricultureIncomeThreshold: 5000,
        agricultureBasicExemptionLimit:
            300000, // Matching Slab 0 for test clarity
        isCashGiftExemptionEnabled: false,
        jurisdiction: 'India',
        customExemptions: [],
        tagMappings: {},
        cessRate: 4.0,
      );

      baseData = TaxYearData(
        year: 2025, // int
        salary: const SalaryDetails(grossSalary: 0),
        houseProperties: [],
        businessIncomes: [],
        capitalGains: [],
        otherIncomes: [],
        dividendIncome: const DividendIncome(),
        tdsEntries: [],
        tcsEntries: [],
        agricultureIncome: 0,
      );
    });

    test('Should NOT apply Partial Integration if Agri Income <= Threshold',
        () {
      final data = baseData.copyWith(
        agricultureIncome: 4000, // < 5000
        salary: const SalaryDetails(grossSalary: 1075000), // Net 10L
      );

      final liability = service.calculateDetailedLiability(data, rules);
      // Net Taxable = 10L.
      // Tax on 10L (Slabs: 0-3:0, 3-6:15k, 6-9:30k, 9-10:15k) = 60,000.
      // Cess 4% = 2400.
      // Total = 62,400.

      expect(liability['totalTax'], closeTo(62400, 1));
    });

    test(
        'Should apply Partial Integration if Agri > Threshold and Income > Basic Limit',
        () {
      // Setup: Agri 10k, Net 10L.
      // Agri Basic Limit 3L (matches slab 0).

      // Step 1: Tax(10L + 10k = 10.1L).
      // 0-3: 0
      // 3-6: 15k
      // 6-9: 30k
      // 9-12 (15%): 1.1L * 0.15 = 16,500.
      // Total Step 1 = 61,500.

      // Step 2: Tax(Basic(3L) + Agri(10k) = 3.1L).
      // 0-3: 0
      // 3-6 (5%): 0.1L * 0.05 = 500.
      // Total Step 2 = 500.

      // Slab Tax = 61,500 - 500 = 61,000.
      // Normal Tax was 60,000. So +1000 increase.

      // Cess 4% on 61,000 = 2440.
      // Total = 63,440.

      final data = baseData.copyWith(
        agricultureIncome: 10000,
        salary: const SalaryDetails(grossSalary: 1075000), // Net 10L
      );

      final liability = service.calculateDetailedLiability(data, rules);
      expect(liability['totalTax'], closeTo(63440, 1));
    });

    test('Should use Configurable Basic Exemption Limit correctly', () {
      // Set Config Limit to 4L (higher than slab 0 of 3L).
      // This implies a "discount" as discussed.

      rules = rules.copyWith(agricultureBasicExemptionLimit: 400000);

      final data = baseData.copyWith(
        agricultureIncome: 10000,
        salary: const SalaryDetails(grossSalary: 1075000), // Net 10L
      );

      // Step 1 (10.1L) Tax = 61,500.

      // Step 2 (4L + 10k = 4.1L).
      // 0-3: 0
      // 3-6 (5%): 1.1L * 0.05 = 5,500.

      // Slab Tax = 61,500 - 5,500 = 56,000.
      // Cess 4% = 2240.
      // Total = 58,240.

      final liability = service.calculateDetailedLiability(data, rules);
      expect(liability['totalTax'], closeTo(58240, 1));
    });
  });
}
