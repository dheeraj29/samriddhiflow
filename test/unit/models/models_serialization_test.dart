import 'package:flutter_test/flutter_test.dart';
import 'package:samriddhi_flow/models/taxes/tax_data_models.dart';
import 'package:samriddhi_flow/models/taxes/tax_data.dart';

void main() {
  group('Tax Data Models Serialization', () {
    test('SalaryDetails', () {
      final data = SalaryDetails(
        history: [
          SalaryStructure(
            id: 's1',
            effectiveDate: DateTime(2024, 4, 1),
            monthlyBasic: 500000 / 12,
          )
        ],
        npsEmployer: 20000,
        leaveEncashment: 50000,
        gratuity: 100000,
      );
      final map = data.toMap();
      final fromMap = SalaryDetails.fromMap(map);
      expect(fromMap.history.length, 1);
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
        id: 'a1',
        name: 'Bonus',
        payoutAmount: 12000,
        frequency: PayoutFrequency.monthly,
      );

      final map = allowance.toMap();
      expect(map['name'], 'Bonus');
      expect(map['payoutAmount'], 12000.0);
      expect(map['frequency'], PayoutFrequency.monthly.index);

      final fromMap = CustomAllowance.fromMap(map);
      expect(fromMap.name, 'Bonus');
      expect(fromMap.payoutAmount, 12000.0);
      expect(fromMap.frequency, PayoutFrequency.monthly);
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
            CustomAllowance(
                id: 'test-id',
                name: 'A1',
                payoutAmount: 100,
                frequency: PayoutFrequency.monthly)
          ]);
      final map = ss.toMap();
      final fromMap = SalaryStructure.fromMap(map);
      expect(fromMap.id, 's1');
      expect(fromMap.monthlyBasic, 50000);
      expect(fromMap.customAllowances.length, 1);
    });
  });

  group('TaxYearData Serialization', () {
    test('TaxYearData full serialization', () {
      final data = TaxYearData(
        year: 2024,
        salary: SalaryDetails(
          history: [
            SalaryStructure(
              id: 's1',
              effectiveDate: DateTime(2024, 4, 1),
              monthlyBasic: 100 / 12,
            )
          ],
          independentExemptions: const [
            CustomExemption(id: 'e1', name: 'Rent', amount: 10000),
          ],
        ),
        houseProperties: const [HouseProperty(name: 'HP1', interestOnLoan: 50)],
        businessIncomes: const [BusinessEntity(name: 'B1')],
        capitalGains: [
          CapitalGainEntry(
              gainDate: DateTime.now(), saleAmount: 20, costOfAcquisition: 10)
        ],
        otherIncomes: const [OtherIncome(name: 'O1', amount: 500)],
        tdsEntries: [
          TaxPaymentEntry(id: 't1', date: DateTime.now(), amount: 100)
        ],
      );

      final map = data.toMap();
      final fromMap = TaxYearData.fromMap(map);

      expect(fromMap.year, 2024);
      expect(fromMap.salary.history.length, 1);
      expect(fromMap.houseProperties.length, 1);
      expect(fromMap.businessIncomes.length, 1);
      expect(fromMap.capitalGains.length, 1);
      expect(fromMap.tdsEntries.length, 1);
      expect(fromMap.salary.independentExemptions.length, 1);
    });
  });

  group('Tax Rules Components Serialization', () {});
}
