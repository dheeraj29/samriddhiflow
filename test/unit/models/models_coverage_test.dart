import 'package:flutter_test/flutter_test.dart';
import 'package:samriddhi_flow/models/account.dart';
import 'package:samriddhi_flow/models/transaction.dart';
import 'package:samriddhi_flow/models/loan.dart';
import 'package:samriddhi_flow/models/category.dart';
import 'package:samriddhi_flow/models/recurring_transaction.dart';
import 'package:samriddhi_flow/models/profile.dart';

void main() {
  group('Model Coverage Mastery', () {
    test('Account Model Helpers', () {
      final acc = Account(
          id: 'a1', name: 'A1', type: AccountType.savings, balance: 100);
      expect(acc.calculateBilledAmount([]), 100);

      final cc = Account.create(
          name: 'CC',
          type: AccountType.creditCard,
          initialBalance: 50.555,
          billingCycleDay: 15);
      expect(cc.calculateBilledAmount([]), 50.56); // Rounded

      final empty = Account.empty();
      expect(empty.id, isEmpty);
    });

    test('Transaction Model Helpers', () {
      final now = DateTime.now();
      final txn = Transaction.create(
          title: 'Created',
          amount: 50,
          date: now,
          type: TransactionType.expense,
          category: 'C1');
      expect(txn.id, isNotEmpty);
      expect(txn.title, 'Created');

      final copied = txn.copyWith(title: 'Updated', isDeleted: true);
      expect(copied.id, txn.id);
      expect(copied.title, 'Updated');
      expect(copied.isDeleted, true);
    });

    test('Loan & LoanTransaction Model Helpers', () {
      final now = DateTime.now();
      final loan = Loan.create(
          name: 'L1',
          principal: 5000,
          rate: 10,
          tenureMonths: 12,
          startDate: now,
          emiAmount: 100,
          emiDay: 5,
          firstEmiDate: now);
      expect(loan.name, 'L1');
      expect(loan.totalPrincipal, 5000);

      final lt = LoanTransaction(
          id: 'lt1',
          date: now,
          amount: 100,
          type: LoanTransactionType.emi,
          principalComponent: 80,
          interestComponent: 20,
          resultantPrincipal: 4920);
      expect(lt.amount, 100);
    });

    test('Category Model Helpers', () {
      final cat = Category(
          id: 'c1',
          name: 'C1',
          usage: CategoryUsage.both,
          tag: CategoryTag.none,
          iconCode: 1);
      expect(cat.name, 'C1');
    });

    test('RecurringTransaction Model Helpers', () {
      final rt = RecurringTransaction(
          id: 'r1',
          title: 'R1',
          amount: 10,
          category: 'C1',
          accountId: 'a1',
          frequency: Frequency.monthly,
          nextExecutionDate: DateTime.now());
      expect(rt.title, 'R1');
    });

    test('Profile Model Helpers', () {
      final p = Profile(id: 'p1', name: 'P1');
      expect(p.name, 'P1');
    });
  });
}
