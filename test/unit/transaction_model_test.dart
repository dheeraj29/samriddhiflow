import 'package:flutter_test/flutter_test.dart';
import 'package:samriddhi_flow/models/transaction.dart';

void main() {
  group('Transaction Model Tests', () {
    test('Transaction.create initializes all fields', () {
      final now = DateTime.now();
      final txn = Transaction.create(
        title: 'Income Txn',
        amount: 5000.0,
        type: TransactionType.income,
        category: 'Salary',
        accountId: 'acc1',
        toAccountId: 'acc2',
        loanId: 'loan1',
        isRecurringInstance: true,
        holdingTenureMonths: 12,
        gainAmount: 100.0,
        profileId: 'p1',
        date: now,
      );

      expect(txn.id, isNotEmpty);
      expect(txn.title, 'Income Txn');
      expect(txn.amount, 5000.0);
      expect(txn.type, TransactionType.income);
      expect(txn.category, 'Salary');
      expect(txn.accountId, 'acc1');
      expect(txn.toAccountId, 'acc2');
      expect(txn.loanId, 'loan1');
      expect(txn.isRecurringInstance, isTrue);
      expect(txn.isDeleted, isFalse);
      expect(txn.holdingTenureMonths, 12);
      expect(txn.gainAmount, 100.0);
      expect(txn.profileId, 'p1');
      expect(txn.date, now);
    });

    test('Transaction copyWith updates specific fields', () {
      final txn = Transaction.create(
        title: 'Original',
        amount: 100,
        type: TransactionType.expense,
        category: 'Misc',
        date: DateTime.now(),
      );

      final updated = txn.copyWith(
        title: 'Updated',
        amount: 200,
        type: TransactionType.income,
        category: 'NewCat',
        accountId: 'a1',
        toAccountId: 'a2',
        loanId: 'l1',
        isRecurringInstance: true,
        isDeleted: true,
        holdingTenureMonths: 6,
        gainAmount: 50,
        profileId: 'p2',
        date: DateTime(2025),
      );

      expect(updated.id, txn.id);
      expect(updated.title, 'Updated');
      expect(updated.amount, 200);
      expect(updated.type, TransactionType.income);
      expect(updated.category, 'NewCat');
      expect(updated.accountId, 'a1');
      expect(updated.toAccountId, 'a2');
      expect(updated.loanId, 'l1');
      expect(updated.isRecurringInstance, isTrue);
      expect(updated.isDeleted, isTrue);
      expect(updated.holdingTenureMonths, 6);
      expect(updated.gainAmount, 50);
      expect(updated.profileId, 'p2');
      expect(updated.date, DateTime(2025));
    });

    test('Transaction copyWith preserves existing values if null passed', () {
      final txn = Transaction.create(
        title: 'KeepMe',
        amount: 500,
        type: TransactionType.expense,
        category: 'Food',
        date: DateTime.now(),
      );

      final identical = txn.copyWith();

      expect(identical.id, txn.id);
      expect(identical.title, txn.title);
      expect(identical.amount, txn.amount);
      expect(identical.type, txn.type);
      expect(identical.category, txn.category);
    });
  });
}
