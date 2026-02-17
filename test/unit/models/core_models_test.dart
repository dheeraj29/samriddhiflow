import 'package:flutter_test/flutter_test.dart';
import 'package:samriddhi_flow/models/loan.dart';
import 'package:samriddhi_flow/models/recurring_transaction.dart';
import 'package:samriddhi_flow/models/transaction.dart';

void main() {
  group('Loan Model', () {
    test('Loan toMap and fromMap', () {
      final loan = Loan(
        id: 'l1',
        name: 'Home Loan',
        totalPrincipal: 5000000,
        remainingPrincipal: 4500000,
        interestRate: 8.5,
        tenureMonths: 240,
        startDate: DateTime(2023, 1, 1),
        type: LoanType.personal,
        profileId: 'p1',
        emiAmount: 43391,
        firstEmiDate: DateTime(2023, 2, 1),
      );

      final map = loan.toMap();
      final fromMap = Loan.fromMap(map);

      expect(fromMap.id, loan.id);
      expect(fromMap.name, loan.name);
      expect(fromMap.totalPrincipal, loan.totalPrincipal);
      expect(fromMap.interestRate, loan.interestRate);
      expect(fromMap.tenureMonths, loan.tenureMonths);
      expect(fromMap.type, loan.type);
    });

    test('LoanTransaction toMap and fromMap', () {
      final tx = LoanTransaction(
        id: 'lt1',
        amount: 50000,
        date: DateTime(2023, 2, 1),
        type: LoanTransactionType.emi,
        principalComponent: 10000,
        interestComponent: 40000,
        resultantPrincipal: 4490000,
      );

      final map = tx.toMap();
      final fromMap = LoanTransaction.fromMap(map);

      expect(fromMap.id, tx.id);
      expect(fromMap.amount, tx.amount);
      expect(fromMap.type, tx.type);
    });
  });

  group('RecurringTransaction Model', () {
    test('RecurringTransaction toMap and fromMap', () {
      final rt = RecurringTransaction(
        id: 'rt1',
        title: 'Rent',
        amount: 25000,
        category: 'Housing',
        frequency: Frequency.monthly,
        nextExecutionDate: DateTime(2024, 1, 1),
        profileId: 'p1',
        type: TransactionType.expense,
      );

      final map = rt.toMap();
      final fromMap = RecurringTransaction.fromMap(map);

      expect(fromMap.id, rt.id);
      expect(fromMap.title, rt.title);
      expect(fromMap.amount, rt.amount);
      expect(fromMap.frequency, rt.frequency);
    });
  });
}
