import 'package:flutter_test/flutter_test.dart';
import 'package:samriddhi_flow/models/transaction.dart';

void main() {
  group('Transaction Model Tests', () {
    test('Transaction.create initializes defaults', () {
      final txn = Transaction.create(
        title: 'Test Expense',
        amount: 500.0,
        type: TransactionType.expense,
        category: 'Food',
        accountId: 'acc_1',
        date: DateTime.now(), // Required
      );

      expect(txn.id, isNotEmpty);
      expect(txn.amount, 500.0);
      expect(txn.category, 'Food');
    });
  });
}
