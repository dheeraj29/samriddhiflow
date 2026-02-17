import 'package:flutter_test/flutter_test.dart';
import 'package:samriddhi_flow/models/taxes/tax_data_models.dart';
import 'package:samriddhi_flow/models/taxes/insurance_policy.dart';
import 'package:samriddhi_flow/models/taxes/tax_data.dart';

void main() {
  group('TaxDataModels Serialization & Helper Tests', () {
    test('SalaryDetails full serialization and copyWith', () {
      const details = SalaryDetails(
        grossSalary: 1000000,
        npsEmployer: 50000,
      );

      final copy = details.copyWith(grossSalary: 1100000);
      expect(copy.grossSalary, 1100000);
      expect(copy.npsEmployer, 50000);

      final map = details.toMap();
      final fromMap = SalaryDetails.fromMap(map);
      expect(fromMap.grossSalary, details.grossSalary);
      expect(fromMap.npsEmployer, details.npsEmployer);
    });

    test('HouseProperty serialization', () {
      const hp = HouseProperty(name: 'My Home', rentReceived: 20000);
      final map = hp.toMap();
      final fromMap = HouseProperty.fromMap(map);
      expect(fromMap.name, 'My Home');
      expect(fromMap.rentReceived, 20000);
    });

    test('BusinessEntity and BusinessType extension', () {
      const entity =
          BusinessEntity(name: 'Shop', type: BusinessType.section44AD);
      expect(entity.type.toHumanReadable(), contains('44AD'));

      final map = entity.toMap();
      final fromMap = BusinessEntity.fromMap(map);
      expect(fromMap.type, BusinessType.section44AD);
    });

    test('CapitalGainEntry and AssetType extension', () {
      final entry = CapitalGainEntry(
        description: 'Shares',
        matchAssetType: AssetType.equityShares,
        saleAmount: 500000,
        costOfAcquisition: 300000,
        gainDate: DateTime(2023, 1, 1),
      );

      expect(entry.capitalGainAmount, 200000);
      expect(AssetType.residentialProperty.toHumanReadable(),
          contains('Residential'));
      expect(ReinvestmentType.bonds54EC.toHumanReadable(), contains('54EC'));

      final map = entry.toMap();
      final fromMap = CapitalGainEntry.fromMap(map);
      expect(fromMap.description, 'Shares');
      expect(fromMap.matchAssetType, AssetType.equityShares);
    });

    test('OtherIncome serialization', () {
      const income = OtherIncome(name: 'Interest', amount: 5000);
      final map = income.toMap();
      final fromMap = OtherIncome.fromMap(map);
      expect(fromMap.name, 'Interest');
      expect(fromMap.amount, 5000);
    });

    test('SalaryStructure.calculateContribution for all frequencies', () {
      final base = SalaryStructure(
        id: 'test',
        effectiveDate: DateTime(2023, 4, 1),
        monthlyBasic: 10000,
        annualVariablePay: 12000,
      );

      // Monthly: (10000 + 12000/12) = 11000
      final sMonthly =
          base.copyWith(variablePayFrequency: PayoutFrequency.monthly);
      expect(sMonthly.calculateContribution(1, 4), 11000);

      // Annually: 10000 + 12000 = 22000 in startMonth
      final sAnnual = base.copyWith(
          variablePayFrequency: PayoutFrequency.annually,
          variablePayStartMonth: 3);
      expect(sAnnual.calculateContribution(3, 4), 22000);
      expect(sAnnual.calculateContribution(1, 4), 10000);

      // Quarterly: 10000 + 12000/4 = 13000 in Mar, Jun, Sep, Dec
      final sQuarterly = base.copyWith(
          variablePayFrequency: PayoutFrequency.quarterly,
          variablePayStartMonth: 3);
      expect(sQuarterly.calculateContribution(3, 4), 13000);
      expect(sQuarterly.calculateContribution(6, 4), 13000);
      expect(sQuarterly.calculateContribution(1, 4), 10000);

      // Trimester: 10000 + 12000/3 = 14000
      final sTrimester = base.copyWith(
          variablePayFrequency: PayoutFrequency.trimester,
          variablePayStartMonth: 3);
      expect(sTrimester.calculateContribution(3, 4), 14000);
      expect(sTrimester.calculateContribution(7, 4), 14000);

      // Half-yearly: 10000 + 12000/2 = 16000
      final sHalf = base.copyWith(
          variablePayFrequency: PayoutFrequency.halfYearly,
          variablePayStartMonth: 3);
      expect(sHalf.calculateContribution(3, 4), 16000);
      expect(sHalf.calculateContribution(9, 4), 16000);

      // Custom
      final sCustom = base.copyWith(
          variablePayFrequency: PayoutFrequency.custom,
          variablePayCustomMonths: [1, 5]);
      expect(sCustom.calculateContribution(1, 4), 16000); // 10000 + 12000/2
    });

    test('SalaryStructure.toMap/fromMap full sync', () {
      final structure = SalaryStructure(
        id: 's1',
        effectiveDate: DateTime(2023, 4, 1),
        monthlyBasic: 50000,
      );
      final map = structure.toMap();
      final fromMap = SalaryStructure.fromMap(map);
      expect(fromMap.id, 's1');
      expect(fromMap.monthlyBasic, 50000);
    });

    test('DividendIncome serialization', () {
      const div = DividendIncome(amountQ1: 1000, amountQ2: 2000);
      expect(div.grossDividend, 3000);

      final map = div.toMap();
      final fromMap = DividendIncome.fromMap(map);
      expect(fromMap.amountQ1, 1000);
      expect(fromMap.grossDividend, 3000);
    });

    test('TaxPaymentEntry serialization', () {
      final entry = TaxPaymentEntry(amount: 5000, date: DateTime(2023, 6, 15));
      final map = entry.toMap();
      final fromMap = TaxPaymentEntry.fromMap(map);
      expect(fromMap.amount, 5000);
    });

    test('TaxStringHelpers extension', () {
      expect('salary'.toHumanReadable(), 'Salary');
      expect('houseProp'.toHumanReadable(), 'House Property');
      expect('equityShares'.toHumanReadable(), 'Equity Shares');
      expect(''.toHumanReadable(), '');
    });

    test('CustomExemption copyWith and serialization', () {
      const ex = CustomExemption(name: 'HRA', amount: 5000);
      final copy = ex.copyWith(amount: 6000);
      expect(copy.amount, 6000);

      final map = ex.toMap();
      final fromMap = CustomExemption.fromMap(map);
      expect(fromMap.name, 'HRA');
    });

    test('TaxYearData serialization', () {
      final data = TaxYearData(year: 2024);
      final map = data.toMap();
      final fromMap = TaxYearData.fromMap(map);
      expect(fromMap.year, 2024);
    });
  });

  group('InsurancePolicy Tests', () {
    test('InsurancePolicy full flow', () {
      final policy = InsurancePolicy.create(
        name: 'LIC',
        number: '12345',
        premium: 25000,
        sumAssured: 500000,
        start: DateTime(2020, 1, 1),
        maturity: DateTime(2040, 1, 1),
      );

      expect(policy.policyName, 'LIC');

      final copy = policy.copyWith(annualPremium: 30000);
      expect(copy.annualPremium, 30000);
      expect(copy.id, policy.id);

      final map = policy.toMap();
      final fromMap = InsurancePolicy.fromMap(map);
      expect(fromMap.policyName, 'LIC');
      expect(fromMap.annualPremium, 25000);
    });
  });
}
