import 'package:flutter_test/flutter_test.dart';
import 'package:samriddhi_flow/models/taxes/insurance_policy.dart';
import 'package:samriddhi_flow/models/taxes/tax_data_models.dart';
import 'package:samriddhi_flow/models/taxes/tax_rules.dart';
import 'package:samriddhi_flow/models/dashboard_config.dart';
import 'package:samriddhi_flow/models/taxes/tax_data.dart';

void main() {
  group('Insurance Policy Serialization', () {
    test('InsurancePolicy toMap/fromMap', () {
      final policy = InsurancePolicy(
        id: '1',
        policyName: 'Health',
        policyNumber: 'P123',
        annualPremium: 5000,
        sumAssured: 500000,
        startDate: DateTime(2025, 1, 1),
        maturityDate: DateTime(2045, 1, 1),
        isUnitLinked: false,
        isHandicapDependent: false,
        isTaxExempt: true,
      );

      final map = policy.toMap();
      final fromMap = InsurancePolicy.fromMap(map);

      expect(fromMap.id, policy.id);
      expect(fromMap.policyName, policy.policyName);
      expect(fromMap.annualPremium, policy.annualPremium);
      expect(fromMap.isTaxExempt, true);
    });
  });

  group('Tax Data Models Serialization', () {
    test('SalaryDetails', () {
      const data = SalaryDetails(
        grossSalary: 500000,
        npsEmployer: 20000,
        leaveEncashment: 50000,
        gratuity: 100000,
        giftsFromEmployer: 4000,
      );
      final map = data.toMap();
      final fromMap = SalaryDetails.fromMap(map);
      expect(fromMap.grossSalary, 500000);
      expect(fromMap.gratuity, 100000);
    });

    test('HouseProperty', () {
      const hp = HouseProperty(
        name: 'My House',
        isSelfOccupied: true,
        rentReceived: 0,
        municipalTaxes: 0,
        interestOnLoan: 200000,
      );
      final map = hp.toMap();
      final fromMap = HouseProperty.fromMap(map);
      expect(fromMap.interestOnLoan, 200000);
      expect(fromMap.isSelfOccupied, true);
    });

    test('BusinessEntity', () {
      const b = BusinessEntity(
        name: 'Biz',
        type: BusinessType.section44ADA,
        grossTurnover: 1000000,
        presumptiveIncome: 500000,
      );
      final map = b.toMap();
      final fromMap = BusinessEntity.fromMap(map);
      expect(fromMap.grossTurnover, 1000000);
    });

    test('CapitalGainEntry', () {
      final cg = CapitalGainEntry(
        description: 'Stock',
        gainDate: DateTime(2024),
        saleAmount: 200,
        costOfAcquisition: 100,
        isLTCG: true,
      );
      final map = cg.toMap();
      final fromMap = CapitalGainEntry.fromMap(map);
      expect(fromMap.description, 'Stock');
      expect(fromMap.capitalGainAmount, 100);
    });

    test('OtherIncome', () {
      const oi = OtherIncome(
        name: 'Interest',
        amount: 5000,
        type: 'Interest',
      );
      final map = oi.toMap();
      final fromMap = OtherIncome.fromMap(map);
      expect(fromMap.amount, 5000);
    });

    test('DividendIncome', () {
      const d = DividendIncome(
        amountQ1: 100,
        amountQ2: 200,
        amountQ3: 300,
        amountQ4: 400,
        amountQ5: 500,
      );
      final map = d.toMap();
      final fromMap = DividendIncome.fromMap(map);
      expect(fromMap.grossDividend, 1500);
    });
    test('CustomAllowance', () {
      const allowance = CustomAllowance(
        name: 'Bonus',
        payoutAmount: 50000,
        frequency: PayoutFrequency.annually,
        startMonth: 3,
      );

      final map = allowance.toMap();
      expect(map['name'], 'Bonus');
      expect(map['payoutAmount'], 50000.0);
      expect(map['frequency'], PayoutFrequency.annually.index);

      final fromMap = CustomAllowance.fromMap(map);
      expect(fromMap.name, 'Bonus');
      expect(fromMap.payoutAmount, 50000.0);
      expect(fromMap.frequency, PayoutFrequency.annually);
    });

    test('CustomAllowance monthlyAmount backward compatibility (fromMap)', () {
      final map = {
        'name': 'Bonus',
        'monthlyAmount': 50000.0,
        'frequency': PayoutFrequency.annually.index,
      };

      final fromMap = CustomAllowance.fromMap(map);
      expect(fromMap.payoutAmount, 50000.0);
    });
    test('SalaryStructure', () {
      final ss = SalaryStructure(
          id: 's1',
          effectiveDate: DateTime(2024, 4, 1),
          monthlyBasic: 50000,
          customAllowances: const [
            CustomAllowance(name: 'A1', payoutAmount: 100)
          ]);
      final map = ss.toMap();
      final fromMap = SalaryStructure.fromMap(map);
      expect(fromMap.id, 's1');
      expect(fromMap.monthlyBasic, 50000);
      expect(fromMap.customAllowances.length, 1);
    });
  });

  group('Dashboard Config Serialization', () {
    test('DashboardVisibilityConfig', () {
      const config = DashboardVisibilityConfig(
        showIncomeExpense: false,
        showBudget: false,
      );

      final map = config.toMap();
      final fromMap = DashboardVisibilityConfig.fromMap(map);

      expect(fromMap.showIncomeExpense, false);
      expect(fromMap.showBudget, false);

      const def = DashboardVisibilityConfig();
      expect(def.showIncomeExpense, true);
    });
  });

  group('TaxYearData Serialization', () {
    test('TaxYearData full serialization', () {
      final data = TaxYearData(
        year: 2024,
        salary: const SalaryDetails(grossSalary: 100),
        houseProperties: const [HouseProperty(name: 'HP1', interestOnLoan: 50)],
        businessIncomes: const [BusinessEntity(name: 'B1')],
        capitalGains: [
          CapitalGainEntry(
              gainDate: DateTime.now(), saleAmount: 20, costOfAcquisition: 10)
        ],
        otherIncomes: const [OtherIncome(name: 'O1', amount: 500)],
        tdsEntries: [TaxPaymentEntry(date: DateTime.now(), amount: 100)],
      );

      final map = data.toMap();
      final fromMap = TaxYearData.fromMap(map);

      expect(fromMap.year, 2024);
      expect(fromMap.salary.grossSalary, 100);
      expect(fromMap.houseProperties.length, 1);
      expect(fromMap.businessIncomes.length, 1);
      expect(fromMap.capitalGains.length, 1);
      expect(fromMap.tdsEntries.length, 1);
    });
  });

  group('Tax Rules Components Serialization', () {
    test('TaxExemptionRule', () {
      const rule = TaxExemptionRule(
        id: 'r1',
        name: 'Section 80C',
        incomeHead: 'Salary',
        limit: 150000,
        isPercentage: false,
        isEnabled: true,
      );
      final map = rule.toMap();
      final fromMap = TaxExemptionRule.fromMap(map);
      expect(fromMap.id, 'r1');
      expect(fromMap.limit, 150000);
    });

    test('TaxSlab', () {
      const slab = TaxSlab(250000, 5.0);
      final map = slab.toMap();
      final fromMap = TaxSlab.fromMap(map);
      expect(fromMap.upto, 250000);
      expect(fromMap.rate, 5.0);
    });

    test('InsurancePremiumRule', () {
      final rule = InsurancePremiumRule(DateTime(2023, 4, 1), 10.0);
      final map = rule.toMap();
      final fromMap = InsurancePremiumRule.fromMap(map);
      expect(fromMap.startDate.year, 2023);
      expect(fromMap.limitPercentage, 10.0);
    });
  });
}
