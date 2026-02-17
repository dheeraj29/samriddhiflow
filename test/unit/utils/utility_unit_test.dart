import 'package:flutter_test/flutter_test.dart';
import 'package:samriddhi_flow/models/transaction.dart';
import 'package:samriddhi_flow/models/loan.dart';

import 'package:samriddhi_flow/utils/financial_utils.dart';

void main() {
  group('FinancialUtils Tests', () {
    final now = DateTime.now();

    test('calculateTotalIncome - sums up income transactions', () {
      final txns = <Transaction>[
        Transaction.create(
            title: 'Salary',
            amount: 5000,
            date: now,
            type: TransactionType.income,
            category: 'Job'),
        Transaction.create(
            title: 'Gift',
            amount: 100,
            date: now,
            type: TransactionType.income,
            category: 'Social'),
        Transaction.create(
            title: 'Rent',
            amount: 1000,
            date: now,
            type: TransactionType.expense,
            category: 'Home'),
      ];
      expect(FinancialUtils.calculateTotalIncome(txns), 5100.0);
    });

    test('calculateTotalExpenses - sums up expense transactions', () {
      final txns = <Transaction>[
        Transaction.create(
            title: 'Rent',
            amount: 1000,
            date: now,
            type: TransactionType.expense,
            category: 'Home'),
        Transaction.create(
            title: 'Food',
            amount: 200,
            date: now,
            type: TransactionType.expense,
            category: 'Food'),
        Transaction.create(
            title: 'Salary',
            amount: 5000,
            date: now,
            type: TransactionType.income,
            category: 'Job'),
      ];
      expect(FinancialUtils.calculateTotalExpenses(txns), 1200.0);
    });

    test('calculateTotalLiability - sums up remaining loan principals', () {
      // Note: Loan.create sets remainingPrincipal = principal initially.
      // For testing calculateTotalLiability, we can use the constructor directly if we want different values
      // or copyWith if available. Loan doesn't have copyWith easily accessible in outline.
      // Let's use the constructor to test diverse remaining principals.
      final loans = <Loan>[
        Loan(
            id: 'l1',
            name: 'Home Loan',
            type: LoanType.home,
            totalPrincipal: 100000,
            remainingPrincipal: 80000,
            interestRate: 8,
            tenureMonths: 240,
            emiAmount: 1000,
            emiDay: 1,
            startDate: now,
            firstEmiDate: now),
        Loan(
            id: 'l2',
            name: 'Car Loan',
            type: LoanType.car,
            totalPrincipal: 20000,
            remainingPrincipal: 15000,
            interestRate: 10,
            tenureMonths: 60,
            emiAmount: 500,
            emiDay: 1,
            startDate: now,
            firstEmiDate: now),
      ];
      expect(FinancialUtils.calculateTotalLiability(loans), 95000.0);
    });

    test('calculateMaxRemainingTenure - returns the highest tenure', () {
      final loans = <Loan>[
        Loan.create(
            name: 'Short',
            type: LoanType.personal,
            principal: 1000,
            rate: 10,
            tenureMonths: 12,
            emiAmount: 100,
            emiDay: 1,
            startDate: now,
            firstEmiDate: now),
        Loan.create(
            name: 'Long',
            type: LoanType.home,
            principal: 100000,
            rate: 8,
            tenureMonths: 240,
            emiAmount: 1000,
            emiDay: 1,
            startDate: now,
            firstEmiDate: now),
      ];
      expect(FinancialUtils.calculateMaxRemainingTenure(loans), 240);
    });

    test('calculateMaxRemainingTenure - returns 0 for empty list', () {
      expect(FinancialUtils.calculateMaxRemainingTenure([]), 0);
    });
  });
}
