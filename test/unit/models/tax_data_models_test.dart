import 'package:flutter_test/flutter_test.dart';
import 'package:samriddhi_flow/models/taxes/tax_data_models.dart';
import 'package:samriddhi_flow/models/taxes/insurance_policy.dart';
import 'package:samriddhi_flow/models/taxes/tax_data.dart';

void main() {
  group('HouseProperty', () {
    test('copyWith returns new instance with overridden values', () {
      final hp = HouseProperty(
        name: 'House 1',
        isSelfOccupied: true,
        rentReceived: 10000,
        municipalTaxes: 2000,
        interestOnLoan: 5000,
        loanId: 'loan-1',
        lastUpdated: DateTime(2025, 1, 1),
        isManualEntry: true,
        transactionDate: DateTime(2025, 6, 1),
      );

      final updated = hp.copyWith(
        name: 'House 2',
        isSelfOccupied: false,
        rentReceived: 20000,
        municipalTaxes: 3000,
        interestOnLoan: 8000,
        loanId: 'loan-2',
        lastUpdated: DateTime(2025, 2, 1),
        isManualEntry: false,
        transactionDate: DateTime(2025, 7, 1),
      );

      expect(updated.name, 'House 2');
      expect(updated.isSelfOccupied, false);
      expect(updated.rentReceived, 20000);
      expect(updated.municipalTaxes, 3000);
      expect(updated.interestOnLoan, 8000);
      expect(updated.loanId, 'loan-2');
      expect(updated.isManualEntry, false);
    });

    test('copyWith preserves original when no args passed', () {
      const hp = HouseProperty(name: 'HP', rentReceived: 5000);
      final copy = hp.copyWith();
      expect(copy.name, 'HP');
      expect(copy.rentReceived, 5000);
    });

    test('fromMap with lastUpdated and transactionDate null branch', () {
      final hp = HouseProperty.fromMap({
        'name': 'Test',
        'lastUpdated': null,
        'transactionDate': null,
      });
      expect(hp.lastUpdated, isNull);
      expect(hp.transactionDate, isNull);
    });

    test('fromMap with lastUpdated and transactionDate string branch', () {
      final hp = HouseProperty.fromMap({
        'name': 'Test',
        'lastUpdated': '2025-01-01T00:00:00.000',
        'transactionDate': '2025-06-01T00:00:00.000',
      });
      expect(hp.lastUpdated, isNotNull);
      expect(hp.transactionDate, isNotNull);
    });
  });

  group('BusinessEntity', () {
    test('copyWith returns new instance with overridden values', () {
      final be = BusinessEntity(
        name: 'Biz 1',
        type: BusinessType.regular,
        grossTurnover: 100000,
        netIncome: 50000,
        presumptiveIncome: 0,
        lastUpdated: DateTime(2025, 1, 1),
        isManualEntry: true,
        transactionDate: DateTime(2025, 6, 1),
      );

      final updated = be.copyWith(
        name: 'Biz 2',
        type: BusinessType.section44AD,
        grossTurnover: 200000,
        netIncome: 80000,
        presumptiveIncome: 12000,
        lastUpdated: DateTime(2025, 2, 1),
        isManualEntry: false,
        transactionDate: DateTime(2025, 7, 1),
      );

      expect(updated.name, 'Biz 2');
      expect(updated.type, BusinessType.section44AD);
      expect(updated.grossTurnover, 200000);
      expect(updated.netIncome, 80000);
      expect(updated.presumptiveIncome, 12000);
      expect(updated.isManualEntry, false);
    });

    test('copyWith preserves original when no args passed', () {
      const be = BusinessEntity(name: 'B', grossTurnover: 5000);
      final copy = be.copyWith();
      expect(copy.name, 'B');
      expect(copy.grossTurnover, 5000);
    });

    test('fromMap with transactionDate null vs string', () {
      final be1 =
          BusinessEntity.fromMap({'name': 'T', 'transactionDate': null});
      expect(be1.transactionDate, isNull);

      final be2 = BusinessEntity.fromMap(
          {'name': 'T', 'transactionDate': '2025-03-01T00:00:00.000'});
      expect(be2.transactionDate, isNotNull);
    });

    test('fromMap with lastUpdated null vs string', () {
      final be1 = BusinessEntity.fromMap({'name': 'T', 'lastUpdated': null});
      expect(be1.lastUpdated, isNull);

      final be2 = BusinessEntity.fromMap(
          {'name': 'T', 'lastUpdated': '2025-03-01T00:00:00.000'});
      expect(be2.lastUpdated, isNotNull);
    });
  });

  group('OtherIncome', () {
    test('copyWith returns new instance with overridden values', () {
      final oi = OtherIncome(
        name: 'Dividend',
        amount: 1000,
        type: 'Dividend',
        subtype: 'other',
        linkedExemptionId: 'ex-1',
        lastUpdated: DateTime(2025, 1, 1),
        isManualEntry: true,
        transactionDate: DateTime(2025, 6, 1),
      );

      final updated = oi.copyWith(
        name: 'Interest',
        amount: 2000,
        type: 'Interest',
        subtype: 'savings_interest',
        linkedExemptionId: 'ex-2',
        lastUpdated: DateTime(2025, 2, 1),
        isManualEntry: false,
        transactionDate: DateTime(2025, 7, 1),
      );

      expect(updated.name, 'Interest');
      expect(updated.amount, 2000);
      expect(updated.type, 'Interest');
      expect(updated.subtype, 'savings_interest');
      expect(updated.linkedExemptionId, 'ex-2');
      expect(updated.isManualEntry, false);
    });

    test('copyWith preserves original when no args passed', () {
      const oi = OtherIncome(name: 'O', amount: 500);
      final copy = oi.copyWith();
      expect(copy.name, 'O');
      expect(copy.amount, 500);
    });

    test('fromMap with optional DateTime fields null vs string', () {
      final oi1 = OtherIncome.fromMap({
        'name': 'T',
        'amount': 100,
        'lastUpdated': null,
        'transactionDate': null,
      });
      expect(oi1.lastUpdated, isNull);
      expect(oi1.transactionDate, isNull);

      final oi2 = OtherIncome.fromMap({
        'name': 'T',
        'amount': 100,
        'lastUpdated': '2025-01-01T00:00:00.000',
        'transactionDate': '2025-06-01T00:00:00.000',
      });
      expect(oi2.lastUpdated, isNotNull);
      expect(oi2.transactionDate, isNotNull);
    });
  });

  group('AgriIncomeEntry', () {
    test('create factory generates an entry with UUID', () {
      final entry = AgriIncomeEntry.create(
        amount: 50000,
        date: DateTime(2025, 4, 1),
        description: 'Rice harvest',
      );
      expect(entry.id, isNotEmpty);
      expect(entry.amount, 50000);
      expect(entry.description, 'Rice harvest');
      expect(entry.isManualEntry, true);
    });

    test('toMap and fromMap roundtrip', () {
      final entry = AgriIncomeEntry(
        id: 'test-id',
        amount: 75000,
        date: DateTime(2025, 4, 15),
        description: 'Wheat',
        isManualEntry: false,
      );

      final map = entry.toMap();
      expect(map['id'], 'test-id');
      expect(map['amount'], 75000);
      expect(map['description'], 'Wheat');

      final restored = AgriIncomeEntry.fromMap(map);
      expect(restored.id, 'test-id');
      expect(restored.amount, 75000);
      expect(restored.description, 'Wheat');
    });

    test('fromMap with missing fields uses defaults', () {
      final entry = AgriIncomeEntry.fromMap({});
      expect(entry.id, isNotEmpty); // UUID generated
      expect(entry.amount, 0);
      expect(entry.description, '');
      expect(entry.isManualEntry, true);
    });
  });

  group('SalaryDetails', () {
    test('fromMap with monthlyGross, history, netSalaryReceived', () {
      final sd = SalaryDetails.fromMap({
        'history': [
          {
            'id': 's1',
            'effectiveDate': '2024-04-01',
            'monthlyBasic': 100000 / 12,
          }
        ],
        'netSalaryReceived': {'1': 70000, '2': 72000},
        'independentAllowances': [],
        'independentExemptions': [],
        'independentDeductions': [],
      });
      expect(sd.history.length, 1);
      expect(sd.netSalaryReceived[2], 72000);
    });

    test('fromMap with null optional lists', () {
      final sd = SalaryDetails.fromMap({
        'history': null,
        'netSalaryReceived': null,
        'independentAllowances': null,
        'independentExemptions': null,
        'independentDeductions': null,
      });
      expect(sd.history, isEmpty);
      expect(sd.netSalaryReceived, isEmpty);
    });
  });

  group('CapitalGainEntry', () {
    test('fromMap with reinvestDate null vs present', () {
      final cg1 = CapitalGainEntry.fromMap({
        'gainDate': '2025-01-01T00:00:00.000',
        'reinvestDate': null,
        'lastUpdated': null,
      });
      expect(cg1.reinvestDate, isNull);
      expect(cg1.lastUpdated, isNull);

      final cg2 = CapitalGainEntry.fromMap({
        'gainDate': '2025-01-01T00:00:00.000',
        'reinvestDate': '2025-06-01T00:00:00.000',
        'lastUpdated': '2025-06-01T00:00:00.000',
      });
      expect(cg2.reinvestDate, isNotNull);
      expect(cg2.lastUpdated, isNotNull);
    });

    test('capitalGainAmount computed property', () {
      final entry = CapitalGainEntry(
        gainDate: DateTime(2025, 1, 1),
        saleAmount: 100000,
        costOfAcquisition: 60000,
      );
      expect(entry.capitalGainAmount, 40000);
    });
  });

  group('InsurancePolicy', () {
    test('copyWith returns new instance with overridden values', () {
      final policy = InsurancePolicy(
        id: 'p1',
        policyName: 'Term Plan',
        policyNumber: 'TP001',
        annualPremium: 15000,
        sumAssured: 5000000,
        startDate: DateTime(2020, 1, 1),
        maturityDate: DateTime(2050, 1, 1),
        isUnitLinked: false,
        isHandicapDependent: false,
        isTaxExempt: true,
        profileId: 'default',
      );

      final updated = policy.copyWith(
        policyName: 'ULIP Plan',
        policyNumber: 'UL001',
        annualPremium: 25000,
        sumAssured: 1000000,
        startDate: DateTime(2022, 1, 1),
        maturityDate: DateTime(2032, 1, 1),
        isUnitLinked: true,
        isHandicapDependent: true,
        isTaxExempt: false,
        profileId: 'profile-2',
      );

      expect(updated.id, 'p1'); // id is preserved
      expect(updated.policyName, 'ULIP Plan');
      expect(updated.annualPremium, 25000);
      expect(updated.isUnitLinked, true);
      expect(updated.isHandicapDependent, true);
      expect(updated.isTaxExempt, false);
      expect(updated.profileId, 'profile-2');
    });

    test('create factory generates with UUID', () {
      final policy = InsurancePolicy.create(
        name: 'New Policy',
        number: 'NP001',
        premium: 30000,
        sumAssured: 2000000,
        start: DateTime(2025, 1, 1),
        maturity: DateTime(2055, 1, 1),
      );

      expect(policy.id, isNotEmpty);
      expect(policy.policyName, 'New Policy');
      expect(policy.annualPremium, 30000);
    });

    test('toMap and fromMap roundtrip', () {
      final policy = InsurancePolicy(
        id: 'p2',
        policyName: 'Health',
        policyNumber: 'H002',
        annualPremium: 20000,
        sumAssured: 1000000,
        startDate: DateTime(2021, 6, 1),
        maturityDate: DateTime(2041, 6, 1),
      );

      final map = policy.toMap();
      final restored = InsurancePolicy.fromMap(map);
      expect(restored.policyName, 'Health');
      expect(restored.annualPremium, 20000);

      // Coverage for copyWith empty args
      final copy = policy.copyWith();
      expect(copy.id, policy.id);
    });
  });

  group('CustomDeduction', () {
    test('copyWith and toMap/fromMap roundtrip', () {
      const cd = CustomDeduction(
        id: 'cd1',
        name: 'PF',
        amount: 5000,
        isTaxable: true,
        frequency: PayoutFrequency.monthly,
      );

      final updated = cd.copyWith(name: 'VPF', amount: 8000);
      expect(updated.name, 'VPF');
      expect(updated.amount, 8000);

      // Coverage for missing copyWith branches
      final cd2 = cd.copyWith();
      expect(cd2.id, cd.id);

      final map = cd.toMap();
      final restored = CustomDeduction.fromMap(map);
      expect(restored.name, 'PF');
      expect(restored.amount, 5000);
    });

    test('fromMap with string frequency fallback', () {
      final cd = CustomDeduction.fromMap({
        'name': 'Test',
        'amount': 100,
        'frequency': 'quarterly',
      });
      expect(cd.frequency, PayoutFrequency.quarterly);
    });
  });

  group('CustomAllowance', () {
    test('copyWith and toMap/fromMap roundtrip', () {
      const ca = CustomAllowance(
        id: 'ca1',
        name: 'HRA',
        payoutAmount: 15000,
        isCliffExemption: true,
        exemptionLimit: 5000,
      );

      final updated = ca.copyWith(name: 'DA', payoutAmount: 10000);
      expect(updated.name, 'DA');
      expect(updated.payoutAmount, 10000);
      expect(updated.isCliffExemption, true); // preserved

      final map = ca.toMap();
      final restored = CustomAllowance.fromMap(map);
      expect(restored.name, 'HRA');
      expect(restored.exemptionLimit, 5000);
    });

    test('fromMap with legacy monthlyAmount field', () {
      final ca = CustomAllowance.fromMap({
        'name': 'Old',
        'monthlyAmount': 12000,
      });
      expect(ca.payoutAmount, 12000);
    });

    test('fromMap with string frequency', () {
      final ca = CustomAllowance.fromMap({
        'name': 'Test',
        'payoutAmount': 100,
        'frequency': 'halfYearly',
      });
      expect(ca.frequency, PayoutFrequency.halfYearly);
    });
  });

  group('CustomExemption', () {
    test('copyWith and toMap/fromMap roundtrip', () {
      const ce = CustomExemption(
        id: 'ce1',
        name: 'LTC',
        amount: 50000,
        isCliffExemption: true,
        exemptionLimit: 25000,
      );

      final updated = ce.copyWith(name: 'Leave', amount: 30000);
      expect(updated.name, 'Leave');
      expect(updated.amount, 30000);

      final map = ce.toMap();
      final restored = CustomExemption.fromMap(map);
      expect(restored.name, 'LTC');
      expect(restored.exemptionLimit, 25000);
    });

    test('simple toMap/fromMap', () {
      const ex = CustomExemption(id: 'e1', name: 'Test', amount: 5000);
      final map = ex.toMap();
      final back = CustomExemption.fromMap(map);

      expect(back.name, 'Test');
      expect(back.amount, 5000);
    });
  });

  group('DividendIncome', () {
    test('grossDividend calculated correctly', () {
      const di = DividendIncome(
        amountQ1: 1000,
        amountQ2: 2000,
        amountQ3: 3000,
        amountQ4: 4000,
        amountQ5: 500,
      );
      expect(di.grossDividend, 10500);
    });

    test('toMap and fromMap roundtrip', () {
      final di = DividendIncome(
        amountQ1: 100,
        lastUpdated: DateTime(2025, 3, 1),
      );
      final map = di.toMap();
      final restored = DividendIncome.fromMap(map);
      expect(restored.amountQ1, 100);
      expect(restored.lastUpdated, isNotNull);
    });

    test('fromMap with null lastUpdated', () {
      final di = DividendIncome.fromMap({'lastUpdated': null});
      expect(di.lastUpdated, isNull);
    });
  });

  group('SalaryStructure', () {
    test('toMap and fromMap roundtrip with performance/variable pay amounts',
        () {
      final ss = SalaryStructure(
        id: 'ss1',
        effectiveDate: DateTime(2025, 4, 1),
        monthlyBasic: 40000,
        monthlyPerformancePay: 5000,
        annualVariablePay: 120000,
        isPerformancePayPartial: true,
        performancePayAmounts: {4: 2000, 5: 3000},
        isVariablePayPartial: true,
        variablePayAmounts: {5: 10000, 11: 15000},
        stoppedMonths: const [10, 11],
      );

      final map = ss.toMap();
      final restored = SalaryStructure.fromMap(map);

      expect(restored.monthlyBasic, 40000);
      expect(restored.isPerformancePayPartial, true);
      expect(restored.performancePayAmounts[4], 2000);
      expect(restored.variablePayAmounts[5], 10000);
      expect(restored.stoppedMonths, contains(10));
    });

    test('estimatedMonthlyGross calculates correctly for various months', () {
      final ss = SalaryStructure(
        id: 'ss1',
        effectiveDate: DateTime(2025, 4, 1), // April
        monthlyBasic: 40000,
        monthlyFixedAllowances: 10000,
        monthlyPerformancePay: 5000,
        performancePayFrequency: PayoutFrequency.monthly,
        annualVariablePay: 120000,
        variablePayFrequency:
            PayoutFrequency.quarterly, // April, July, Oct, Jan
        variablePayStartMonth: 4,
        customAllowances: [
          const CustomAllowance(
            id: 'ca1',
            name: 'Bonus',
            payoutAmount: 20000,
            frequency: PayoutFrequency.annually,
            startMonth: 4,
          ),
        ],
        stoppedMonths: const [10], // Oct is stopped
      );

      // April: basic(40) + allowances(10) + performance(5) + variable(120/4=30) + custom(20) = 105000
      expect(ss.estimatedMonthlyGross, 105000);

      // May: basic(40) + allowances(10) + performance(5) + variable(0) + custom(0) = 55000
      final ssMay = ss.copyWith(effectiveDate: DateTime(2025, 5, 1));
      expect(ssMay.estimatedMonthlyGross, 55000);

      // October: Stopped month
      final ssOct = ss.copyWith(effectiveDate: DateTime(2025, 10, 1));
      expect(ssOct.estimatedMonthlyGross, 0);
    });

    test('estimatedMonthlyGross handles custom frequency variable pay', () {
      final ss = SalaryStructure(
        id: 'ss1',
        effectiveDate: DateTime(2025, 6, 1),
        monthlyBasic: 50000,
        annualVariablePay: 60000,
        variablePayFrequency: PayoutFrequency.custom,
        variablePayCustomMonths: const [6, 12],
      );

      // June: basic(50) + variable(60/2=30) = 80000
      expect(ss.estimatedMonthlyGross, 80000);
    });

    test('estimatedMonthlyGross handles partial pay components', () {
      final ss = SalaryStructure(
        id: 'ss1',
        effectiveDate: DateTime(2025, 4, 1),
        monthlyBasic: 50000,
        isPerformancePayPartial: true,
        performancePayFrequency: PayoutFrequency.monthly,
        performancePayAmounts: const {
          4: 2500,
          5: 3500,
        },
      );

      // April: 50000 + 2500 = 52500
      expect(ss.estimatedMonthlyGross, 52500);

      // May: 50000 + 3500 = 53500
      final ssMay = ss.copyWith(effectiveDate: DateTime(2025, 5, 1));
      expect(ssMay.estimatedMonthlyGross, 53500);
    });
  });

  group('TaxPaymentEntry', () {
    test('copyWith and toMap/fromMap roundtrip', () {
      final entry = TaxPaymentEntry(
        id: 'tp1',
        amount: 50000,
        date: DateTime(2025, 6, 15),
        source: 'Bank',
        description: 'Advance Tax Q1',
      );

      final updated = entry.copyWith(amount: 75000, source: 'Online');
      expect(updated.amount, 75000);
      expect(updated.source, 'Online');
      expect(updated.description, 'Advance Tax Q1'); // preserved

      final updatedEmpty = entry.copyWith();
      expect(updatedEmpty.id, entry.id);

      final map = entry.toMap();
      final restored = TaxPaymentEntry.fromMap(map);
      expect(restored.id, 'tp1');
      expect(restored.amount, 50000);
    });
  });

  group('OtherIncomeSubtypeExtension', () {
    test('toOtherSourceDisplay returns correct labels', () {
      expect('savings_interest'.toOtherSourceDisplay(), 'Savings Interest');
      expect('fd_interest'.toOtherSourceDisplay(), 'FD Interest');
      expect('chit_fund_interest'.toOtherSourceDisplay(), 'Chit Fund Interest');
      expect('family_pension'.toOtherSourceDisplay(), 'Family Pension');
      expect('other'.toOtherSourceDisplay(), 'Others');
      expect('others'.toOtherSourceDisplay(), 'Others');
      expect('custom_type'.toOtherSourceDisplay(), 'custom_type');
      expect(''.toOtherSourceDisplay(), 'Others');
    });

    test('toGiftDisplay returns correct labels', () {
      expect('friend'.toGiftDisplay(), 'Friend');
      expect('relative'.toGiftDisplay(), 'Relative');
      expect('marriage'.toGiftDisplay(), 'Marriage');
      expect('other'.toGiftDisplay(), 'Other');
      expect('others'.toGiftDisplay(), 'Other');
      expect('some_gift'.toGiftDisplay(), 'some_gift');
      expect(''.toGiftDisplay(), 'Other');
    });
  });

  group('BusinessTypeExt', () {
    test('toHumanReadable covers all types', () {
      expect(BusinessType.regular.toHumanReadable(), contains('Regular'));
      expect(BusinessType.section44AD.toHumanReadable(), contains('44AD'));
      expect(BusinessType.section44ADA.toHumanReadable(), contains('44ADA'));
    });
  });

  group('AssetTypeExtension', () {
    test('toHumanReadable covers all types', () {
      expect(AssetType.equityShares.toHumanReadable(), contains('Equity'));
      expect(AssetType.residentialProperty.toHumanReadable(),
          contains('Residential'));
      expect(AssetType.agriculturalLand.toHumanReadable(),
          contains('Agricultural'));
      expect(AssetType.other.toHumanReadable(), contains('Other'));
    });
  });

  group('ReinvestmentTypeExtension', () {
    test('toHumanReadable covers all types', () {
      expect(ReinvestmentType.none.toHumanReadable(), 'None');
      expect(ReinvestmentType.residentialProperty.toHumanReadable(),
          contains('54'));
      expect(
          ReinvestmentType.agriculturalLand.toHumanReadable(), contains('54B'));
      expect(ReinvestmentType.bonds54EC.toHumanReadable(), contains('54EC'));
    });
  });

  group('TaxStringHelpers', () {
    test('toHumanReadable mappings', () {
      expect('salary'.toHumanReadable(), 'Salary');
      expect('houseProp'.toHumanReadable(), 'House Property');
      expect('business'.toHumanReadable(), 'Business / Profession');
      expect('capitalGain'.toHumanReadable(), 'Capital Gain');
      expect('otherIncome'.toHumanReadable(), 'Other Sources');
      expect(''.toHumanReadable(), '');
    });

    test('camelCase fallback', () {
      expect('equityShares'.toHumanReadable(), contains('Equity'));
    });
  });

  group('Tax data model regressions', () {
    test('SalaryDetails copyWith preserves untouched values', () {
      final details = SalaryDetails(
        history: [
          SalaryStructure(
            id: 's1',
            effectiveDate: DateTime(2024, 4, 1),
            monthlyBasic: 1000000 / 12,
          ),
        ],
        npsEmployer: 50000,
      );

      final copy = details.copyWith(
        history: [
          SalaryStructure(
            id: 's1',
            effectiveDate: DateTime(2024, 4, 1),
            monthlyBasic: 1100000 / 12,
          ),
        ],
      );

      expect(copy.history.first.monthlyBasic, 1100000 / 12);
      expect(copy.npsEmployer, 50000);
    });

    test('SalaryStructure calculateContribution supports all payout modes', () {
      final base = SalaryStructure(
        id: 'test',
        effectiveDate: DateTime(2023, 4, 1),
        monthlyBasic: 10000,
        annualVariablePay: 12000,
      );

      final monthly =
          base.copyWith(variablePayFrequency: PayoutFrequency.monthly);
      expect(monthly.calculateContribution(1, 4), 11000);

      final annual = base.copyWith(
        variablePayFrequency: PayoutFrequency.annually,
        variablePayStartMonth: 3,
      );
      expect(annual.calculateContribution(3, 4), 22000);
      expect(annual.calculateContribution(1, 4), 10000);

      final quarterly = base.copyWith(
        variablePayFrequency: PayoutFrequency.quarterly,
        variablePayStartMonth: 3,
      );
      expect(quarterly.calculateContribution(3, 4), 13000);
      expect(quarterly.calculateContribution(6, 4), 13000);
      expect(quarterly.calculateContribution(1, 4), 10000);

      final trimester = base.copyWith(
        variablePayFrequency: PayoutFrequency.trimester,
        variablePayStartMonth: 3,
      );
      expect(trimester.calculateContribution(3, 4), 14000);
      expect(trimester.calculateContribution(7, 4), 14000);

      final halfYearly = base.copyWith(
        variablePayFrequency: PayoutFrequency.halfYearly,
        variablePayStartMonth: 3,
      );
      expect(halfYearly.calculateContribution(3, 4), 16000);
      expect(halfYearly.calculateContribution(9, 4), 16000);

      final custom = base.copyWith(
        variablePayFrequency: PayoutFrequency.custom,
        variablePayCustomMonths: [1, 5],
      );
      expect(custom.calculateContribution(1, 4), 16000);

      final withAllowance = base.copyWith(
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
      expect(withAllowance.calculateContribution(4, 4), 15000);
      expect(withAllowance.calculateContribution(5, 4), 10000);
    });

    test('TaxYearData serialization preserves salary history', () {
      final data = TaxYearData(
        year: 2024,
        salary: SalaryDetails(
          history: [
            SalaryStructure(
              id: 's1',
              effectiveDate: DateTime(2024, 4, 1),
              monthlyBasic: 10000,
            ),
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

      final fromMap = TaxYearData.fromMap(data.toMap());
      expect(fromMap.year, 2024);
      expect(fromMap.salary.history.length, 1);
    });

    test('TaxYearData totalSalary legacy getter remains zero', () {
      const monthly = TaxYearData(
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
      const quarterly = TaxYearData(
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
      const annually = TaxYearData(
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
      const custom = TaxYearData(
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
      const partial = TaxYearData(
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

      expect(monthly.totalSalary, 0);
      expect(quarterly.totalSalary, 0);
      expect(annually.totalSalary, 0);
      expect(custom.totalSalary, 0);
      expect(partial.totalSalary, 0);
    });
  });
}
