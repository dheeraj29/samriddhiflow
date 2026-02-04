import 'package:flutter_test/flutter_test.dart';
import 'package:samriddhi_flow/models/loan.dart';
import 'package:samriddhi_flow/services/loan_service.dart';

void main() {
  late LoanService loanService;
  late Loan sampleLoan;

  setUp(() {
    loanService = LoanService();
    sampleLoan = Loan(
      id: "123",
      name: "Test Loan",
      totalPrincipal: 100000,
      remainingPrincipal: 100000,
      interestRate: 12.0, // 1% monthly
      tenureMonths: 24,
      startDate: DateTime.now(),
      firstEmiDate: DateTime.now().add(const Duration(days: 30)),
      emiAmount: 0,
      type: LoanType.personal,
      transactions: [],
      emiDay: 1,
    );
  });

  group('LoanService - Basic Math', () {
    test('calculateEMI returns correct value', () {
      final emi = loanService.calculateEMI(
          principal: 100000, annualRate: 12, tenureMonths: 24);
      expect(emi, 4707.35);
    });

    test('calculateTenureForEMI reverses calculation', () {
      final tenure = loanService.calculateTenureForEMI(
          principal: 100000, annualRate: 12, emi: 4707.35);
      expect(tenure, 24);
    });

    test('calculateAccruedInterest handles standard periods', () {
      final interest = loanService.calculateAccruedInterest(
          principal: 100000,
          annualRate: 12,
          fromDate: DateTime(2025, 1, 1),
          toDate: DateTime(2025, 1, 31));
      expect(interest, closeTo(986.30, 0.5));
    });

    test('calculateAccruedInterest handles Leap Year', () {
      final interest = loanService.calculateAccruedInterest(
          principal: 100000,
          annualRate: 12,
          fromDate: DateTime(2024, 1, 1),
          toDate: DateTime(2024, 1, 31));
      expect(interest, closeTo(983.60, 0.5));
    });

    test('calculateAccruedInterest handles year boundaries', () {
      final interest = loanService.calculateAccruedInterest(
          principal: 100000,
          annualRate: 12,
          fromDate: DateTime(2024, 12, 30),
          toDate: DateTime(2025, 1, 2));

      final int2024 = (100000 * 12 * 2) / (366 * 100);
      final int2025 = (100000 * 12 * 1) / (365 * 100);
      expect(interest, closeTo(int2024 + int2025, 0.1));
    });

    test('calculateEMI handles zero annual rate', () {
      final emi = loanService.calculateEMI(
          principal: 12000, annualRate: 0, tenureMonths: 12);
      expect(emi, 1000.0);
    });
  });

  group('LoanService - Prepayment Impact', () {
    test('calculatePrepaymentImpact (Reduce EMI, Keep Tenure)', () {
      sampleLoan.emiAmount = 4707.35;
      final result = loanService.calculatePrepaymentImpact(
          loan: sampleLoan, prepaymentAmount: 50000, reduceTenure: false);
      expect(result['newEMI'], closeTo(2353.67, 1.0));
      expect(result['tenureSaved'], 0);
    });

    test('calculatePrepaymentImpact (Keep EMI, Reduce Tenure)', () {
      sampleLoan.emiAmount = 4707.35;
      final result = loanService.calculatePrepaymentImpact(
          loan: sampleLoan, prepaymentAmount: 50000, reduceTenure: true);
      expect(result['newEMI'], 4707.35);
      expect(result['newTenure'], lessThan(24));
      expect(result['tenureSaved'], greaterThan(0));
    });
  });

  group('LoanService - Specialized Calculations', () {
    test('calculateRateForEMITenure finds correct rate', () {
      final rate = loanService.calculateRateForEMITenure(
          principal: 100000, tenureMonths: 24, emi: 4707.35);
      expect(rate, closeTo(12.0, 0.1));
    });

    test('calculateAmortizationSchedule generates valid schedule', () {
      sampleLoan.emiAmount = 4707.35;
      sampleLoan.emiDay = 1;
      sampleLoan.startDate = DateTime(2025, 1, 1);
      final schedule = loanService.calculateAmortizationSchedule(sampleLoan);
      expect(schedule, isNotEmpty);
      expect(schedule.length, closeTo(24, 2));
      expect(schedule.last['balance'], closeTo(0, 0.5));
    });

    test('calculateCumulativeAccruedInterest handles empty history', () {
      sampleLoan.startDate = DateTime(2025, 1, 1);
      final interest = loanService.calculateCumulativeAccruedInterest(
          sampleLoan,
          tillDate: DateTime(2025, 2, 1));
      expect(interest, closeTo(1019.18, 0.1));
    });

    test('calculateCumulativeAccruedInterest accounts for payments', () {
      sampleLoan.startDate = DateTime(2025, 1, 1);
      sampleLoan.transactions = [
        LoanTransaction(
          id: 't1',
          date: DateTime(2025, 2, 1),
          amount: 5000,
          type: LoanTransactionType.emi,
          principalComponent: 4000,
          interestComponent: 1000,
          resultantPrincipal: 96000,
        ),
      ];
      final unpaidInterest = loanService.calculateCumulativeAccruedInterest(
          sampleLoan,
          tillDate: DateTime(2025, 2, 1));
      expect(unpaidInterest, closeTo(19.18, 0.1));
    });
  });
}
