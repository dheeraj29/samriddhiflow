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
      startDate: DateTime.now(), // Start now so 0 months passed
      firstEmiDate: DateTime.now().add(const Duration(days: 30)),
      emiAmount: 0, // To be calculated
      type: LoanType.personal,
      transactions: [],
    );
  });

  group('LoanService - Basic Math', () {
    test('calculateEMI returns correct value', () {
      // Principal: 100,000, Rate: 12%, Tenure: 24m
      // r = 1% = 0.01
      // E = 100000 * 0.01 * (1.01)^24 / ((1.01)^24 - 1)
      // E ≈ 1000 * 1.2697 / 0.2697 ≈ 4707.34
      final emi = loanService.calculateEMI(
          principal: 100000, annualRate: 12, tenureMonths: 24);
      expect(emi, 4707.35); // Allow small rounding diff
    });

    test('calculateTenureForEMI reverses calculation', () {
      // If we pay 4707.35, tenure should be 24
      final tenure = loanService.calculateTenureForEMI(
          principal: 100000, annualRate: 12, emi: 4707.35);
      expect(tenure, 24);
    });

    test('calculateAccruedInterest handles standard periods', () {
      // 100,000 at 12% for 30 days
      // Interest = 100000 * 12 * 30 / (365 * 100) = 986.30
      final interest = loanService.calculateAccruedInterest(
          principal: 100000,
          annualRate: 12,
          fromDate: DateTime(2025, 1, 1),
          toDate: DateTime(2025, 1, 31)); // 30 days diff
      expect(interest, closeTo(986.30, 0.5));
    });

    test('calculateAccruedInterest handles Leap Year', () {
      // 2024 is leap year (366 days)
      final interest = loanService.calculateAccruedInterest(
          principal: 100000,
          annualRate: 12,
          fromDate: DateTime(2024, 1, 1),
          toDate: DateTime(2024, 1, 31)); // 30 days
      // Interest = 100000 * 12 * 30 / (366 * 100) = 983.60
      expect(interest, closeTo(983.60, 0.5));
    });
  });

  group('LoanService - Prepayment Impact', () {
    test('calculatePrepaymentImpact (Reduce EMI, Keep Tenure)', () {
      sampleLoan.emiAmount = 4707.35;

      final result = loanService.calculatePrepaymentImpact(
          loan: sampleLoan, prepaymentAmount: 50000, reduceTenure: false);

      // Remaining Principal: 50,000. Tenure: 24.
      // New EMI should be roughly half.
      expect(result['newEMI'], closeTo(2353.67, 1.0));
      // Tenure saved should be 0 or small due to rounding, but we passed keepTenure so newTenure should be close to original
      // Logic for keepTenure recalculates based on remaining time.
    });
  });
}
