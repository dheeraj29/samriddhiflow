import 'package:flutter_test/flutter_test.dart';
import 'package:samriddhi_flow/models/loan.dart';

void main() {
  group('Loan Model Tests', () {
    test('Loan serialization and deserialization', () {
      final loan = Loan.create(
        name: 'Test Loan',
        principal: 10000,
        rate: 5.5,
        tenureMonths: 12,
        startDate: DateTime(2024, 1, 1),
        emiAmount: 850,
        emiDay: 5,
        firstEmiDate: DateTime(2024, 2, 5),
        accountId: 'acc1',
        type: LoanType.home,
      );

      // Add a transaction
      final txn = LoanTransaction(
        id: 'txn1',
        date: DateTime(2024, 2, 5),
        amount: 850,
        type: LoanTransactionType.emi,
        principalComponent: 800,
        interestComponent: 50,
        resultantPrincipal: 9200,
      );
      loan.transactions.add(txn);

      // Verify Loan Create
      expect(loan.name, 'Test Loan');
      expect(loan.remainingPrincipal, 10000);
      expect(loan.totalPrincipal, 10000);
      expect(loan.transactions, isNotEmpty);
      expect(loan.transactions.first.amount, 850);
      expect(loan.transactions.first.resultantPrincipal, 9200);

      // Verify Defaults
      final defaultLoan = Loan.create(
        name: 'Default',
        principal: 5000,
        rate: 5,
        tenureMonths: 10,
        startDate: DateTime.now(),
        emiAmount: 500,
        emiDay: 1,
        firstEmiDate: DateTime.now(),
      );
      expect(defaultLoan.type, LoanType.personal);
      expect(defaultLoan.profileId, 'default');
      expect(defaultLoan.transactions, isEmpty);
    });
  });
}
