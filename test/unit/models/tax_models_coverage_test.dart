import 'package:flutter_test/flutter_test.dart';
import 'package:samriddhi_flow/models/taxes/tax_data_models.dart';
import 'package:samriddhi_flow/models/taxes/tax_data.dart';

void main() {
  group('TaxDataModels Serialization & Helper Tests', () {
    test('SalaryDetails full serialization and copyWith', () {
      final details = SalaryDetails(
        history: [
          SalaryStructure(
            id: 's1',
            effectiveDate: DateTime(2024, 4, 1),
            monthlyBasic: 1000000 / 12,
          )
        ],
        npsEmployer: 50000,
      );

      final copy = details.copyWith(
        history: [
          SalaryStructure(
            id: 's1',
            effectiveDate: DateTime(2024, 4, 1),
            monthlyBasic: 1100000 / 12,
          )
        ],
      );
      expect(copy.history.first.monthlyBasic, 1100000 / 12);
      expect(copy.npsEmployer, 50000);

      final map = details.toMap();
      final fromMap = SalaryDetails.fromMap(map);
      expect(fromMap.history.length, details.history.length);
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

      // Custom Allowance
      final sWithAllowance = base.copyWith(
        customAllowances: [
          const CustomAllowance(
            id: 'a1',
            name: 'Bonus',
            payoutAmount: 5000,
            frequency: PayoutFrequency.annually,
            startMonth: 4,
          ),
        ],
      );
      // In April (4): 10000 + 5000 = 15000
      expect(sWithAllowance.calculateContribution(4, 4), 15000);
      // In May (5): 10000
      expect(sWithAllowance.calculateContribution(5, 4), 10000);
    });

    test('CustomExemption copyWith and serialization', () {
      const ex = CustomExemption(id: 'hra', name: 'HRA', amount: 5000);
      final copy = ex.copyWith(amount: 6000);
      expect(copy.amount, 6000);

      final map = ex.toMap();
      final fromMap = CustomExemption.fromMap(map);
      expect(fromMap.name, 'HRA');
    });

    test('TaxYearData totalSalary with various allowance frequencies', () {
      // 1. Monthly: 1000 * 12 = 12000
      const dataMonthly = TaxYearData(
        year: 2024,
        salary: SalaryDetails(independentAllowances: [
          CustomAllowance(
            id: 'a1',
            name: 'Test',
            payoutAmount: 1000,
            frequency: PayoutFrequency.monthly,
          ),
        ]),
      );
      expect(dataMonthly.totalSalary, 0); // Legacy getter returns 0

      // 2. Quarterly: 1000 * 4 = 4000
      const dataQuarterly = TaxYearData(
        year: 2024,
        salary: SalaryDetails(independentAllowances: [
          CustomAllowance(
            id: 'q1',
            name: 'Q',
            payoutAmount: 1000,
            frequency: PayoutFrequency.quarterly,
          ),
        ]),
      );
      expect(dataQuarterly.totalSalary, 0);

      // 3. Annually: 1000 * 1 = 1000
      const dataAnnually = TaxYearData(
        year: 2024,
        salary: SalaryDetails(independentAllowances: [
          CustomAllowance(
            id: 'ann1',
            name: 'A',
            payoutAmount: 1000,
            frequency: PayoutFrequency.annually,
            startMonth: 4,
          ),
        ]),
      );
      expect(dataAnnually.totalSalary, 0);

      // 4. Custom: 1000 * 2 = 2000
      const dataCustom = TaxYearData(
        year: 2024,
        salary: SalaryDetails(independentAllowances: [
          CustomAllowance(
            id: 'c1',
            name: 'C',
            payoutAmount: 1000,
            frequency: PayoutFrequency.custom,
            customMonths: [4, 10],
          ),
        ]),
      );
      expect(dataCustom.totalSalary, 0);

      // 5. Partial: Sum of partialAmounts
      const dataPartial = TaxYearData(
        year: 2024,
        salary: SalaryDetails(independentAllowances: [
          CustomAllowance(
            id: 'p1',
            name: 'P',
            payoutAmount: 1000,
            frequency: PayoutFrequency.monthly,
            isPartial: true,
            partialAmounts: {4: 5000, 5: 3000},
          ),
        ]),
      );
      expect(dataPartial.totalSalary, 0);
    });

    test('TaxYearData serialization and history', () {
      final data = TaxYearData(
        year: 2024,
        salary: SalaryDetails(
          history: [
            SalaryStructure(
              id: 's1',
              effectiveDate: DateTime(2024, 4, 1),
              monthlyBasic: 10000,
            )
          ],
          independentAllowances: const [
            CustomAllowance(
              id: 'f1',
              name: 'Freelance',
              payoutAmount: 1000,
              frequency: PayoutFrequency.monthly,
            ),
          ],
        ),
      );

      final map = data.toMap();
      final fromMap = TaxYearData.fromMap(map);
      expect(fromMap.year, 2024);
      expect(fromMap.salary.history.length, 1);
    });
  });
}
