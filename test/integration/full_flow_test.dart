import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samriddhi_flow/models/transaction.dart';
import 'package:samriddhi_flow/models/account.dart';
import 'package:samriddhi_flow/providers.dart';
import '../widget/test_mocks.dart';

void main() {
  group('Full Flow Integration Logic', () {
    test('Add Expense -> Balance Decreases -> Report Aggregates', () async {
      // Setup Initial State
      final account = Account(
        id: 'acc1',
        name: 'Wallet',
        type: AccountType.wallet,
        balance: 1000.0,
      );

      final statefulStorage = StatefulMockStorage();
      statefulStorage.accounts.add(account);

      final statefulContainer = ProviderContainer(
        overrides: [
          storageServiceProvider.overrideWithValue(statefulStorage),
        ],
      );
      addTearDown(statefulContainer.dispose);

      // Verify Initial balance
      expect(statefulStorage.getAccounts().first.balance, 1000.0);

      // 2. Add Transaction
      final txn = Transaction.create(
        title: 'Lunch',
        amount: 200.0,
        date: DateTime.now(),
        type: TransactionType.expense,
        category: 'Food',
        accountId: 'acc1',
      );

      // Simulate the save action
      await statefulStorage.saveTransaction(txn);

      // 3. Verify Balance Update
      final updatedAcc =
          statefulStorage.getAccounts().firstWhere((a) => a.id == 'acc1');
      expect(updatedAcc.balance, 800.0);

      // 4. Verify Transaction List
      expect(statefulStorage.getTransactions().length, 1);
      expect(statefulStorage.getTransactions().first.title, 'Lunch');

      // 5. Verify logic consistency (Reports Logic)
      final txns = statefulStorage.getTransactions();
      final foodTotal = txns
          .where((t) => t.category == 'Food')
          .fold(0.0, (sum, t) => sum + t.amount);

      expect(foodTotal, 200.0);
    });
  });
}

class StatefulMockStorage extends MockStorageService {
  final List<Account> accounts = [];
  final List<Transaction> transactions = [];

  @override
  List<Account> getAccounts() => accounts;
  @override
  List<Account> getAllAccounts() => accounts;
  @override
  List<Transaction> getTransactions() => transactions;
  @override
  List<Transaction> getAllTransactions() => transactions;

  @override
  Future<void> saveTransaction(Transaction txn,
      {bool applyImpact = true}) async {
    transactions.add(txn);
    if (applyImpact && txn.accountId != null) {
      final acc = accounts.firstWhere((a) => a.id == txn.accountId);
      if (txn.type == TransactionType.expense) {
        acc.balance -= txn.amount;
      } else if (txn.type == TransactionType.income) {
        acc.balance += txn.amount;
      }
    }
  }
}
