import 'package:flutter_test/flutter_test.dart';
import 'package:samriddhi_flow/models/loan.dart';
import 'package:samriddhi_flow/models/recurring_transaction.dart';
import 'package:samriddhi_flow/models/transaction.dart';
import 'package:samriddhi_flow/models/account.dart';
import 'package:samriddhi_flow/models/dashboard_config.dart';
import 'package:samriddhi_flow/models/profile.dart';

void main() {
  group('Account Model', () {
    test('Account toMap and fromMap with freeze fields', () {
      final acc = Account(
        id: 'acc1',
        name: 'Test',
        type: AccountType.creditCard,
        balance: 0,
        currency: 'USD',
        freezeDate: DateTime(2025, 1, 1),
        isFrozen: true,
        isFrozenCalculated: true,
      );
      final map = acc.toMap();
      final fromMap = Account.fromMap(map);

      expect(fromMap.id, acc.id);
      expect(fromMap.freezeDate, acc.freezeDate);
      expect(fromMap.isFrozen, true);
      expect(fromMap.isFrozenCalculated, true);
    });

    test('Account handles empty, create, copyWith, and numeric edge cases', () {
      final account = Account(
        id: '1',
        name: 'Acc 1',
        type: AccountType.savings,
        balance: 100,
        profileId: 'p1',
        creditLimit: 5000,
        billingCycleDay: 15,
        paymentDueDateDay: 5,
        currency: 'INR',
      );

      expect(account.calculateBilledAmount([]), 100);
      expect(account.copyWith(balance: 200).balance, 200);

      final empty = Account.empty();
      expect(empty.id, '');

      final created = Account.create(name: 'Wallet', type: AccountType.wallet);
      expect(created.name, 'Wallet');

      final fromMap = Account.fromMap({
        'id': '3',
        'name': 'Edge',
        'balance': double.infinity,
        'type': 0,
        'creditLimit': double.nan,
      });
      expect(fromMap.balance, 0.0);
      expect(fromMap.creditLimit, 0.0);
    });
  });

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

  group('Transaction Model', () {
    test('Transaction supports serialization and copyWith coverage paths', () {
      final transaction = Transaction(
        id: '1',
        title: 'T1',
        amount: 50,
        date: DateTime(2024),
        type: TransactionType.expense,
        category: 'Food',
        accountId: 'a1',
        profileId: 'p1',
        isDeleted: false,
        toAccountId: 'a2',
        taxSync: true,
      );

      final map = transaction.toMap();
      final fromMap = Transaction.fromMap(map);
      expect(fromMap.id, transaction.id);
      expect(fromMap.toAccountId, 'a2');
      expect(fromMap.taxSync, true);

      final updated = transaction.copyWith(
        id: '2',
        title: 'T2',
        amount: 100,
        date: DateTime(2025),
        type: TransactionType.income,
        category: 'Sal',
        accountId: 'a3',
        toAccountId: 'a4',
        loanId: 'l1',
        isRecurringInstance: true,
        isDeleted: true,
        holdingTenureMonths: 12,
        gainAmount: 500,
        profileId: 'p2',
        taxSync: false,
      );
      expect(updated.id, '2');
      expect(updated.isDeleted, isTrue);
      expect(updated.gainAmount, 500);

      final created = Transaction.create(
        title: 'New T',
        amount: 10,
        date: DateTime.now(),
        type: TransactionType.income,
        category: 'Sal',
        accountId: 'a1',
        loanId: 'lx',
        holdingTenureMonths: 24,
        gainAmount: 100,
        profileId: 'p1',
      );
      expect(created.loanId, 'lx');
    });

    test('Transaction fromMap handles edge values and invalid dates', () {
      final edge = Transaction.fromMap({
        'id': 'e',
        'title': 'E',
        'amount': double.nan,
        'date': DateTime(2024).toIso8601String(),
        'type': 0,
        'category': 'C',
        'gainAmount': double.infinity,
        'isRecurringInstance': true,
        'loanId': 'l1',
        'isDeleted': true,
        'holdingTenureMonths': 6,
        'profileId': 'p1',
        'taxSync': false,
        'accountId': 'a1',
        'toAccountId': 'a2',
      });

      expect(edge.amount, 0.0);
      expect(edge.gainAmount, 0.0);
      expect(edge.isRecurringInstance, isTrue);
      expect(edge.taxSync, isFalse);

      expect(
        () => Transaction.fromMap({
          'id': 'x',
          'title': 'X',
          'amount': 1,
          'date': 'invalid',
          'type': 0,
          'category': 'C',
        }),
        throwsFormatException,
      );
    });
  });

  group('Profile Model', () {
    test('Profile covers create, copyWith, defaults, and serialization', () {
      final profile = Profile(
        id: '1',
        name: 'User 1',
        currencyLocale: 'en_US',
        monthlyBudget: 1000,
      );

      expect(profile.id, '1');
      expect(profile.currencyLocale, 'en_US');

      final created = Profile.create(name: 'User 2');
      expect(created.name, 'User 2');
      expect(created.id, isNotEmpty);

      final fromMap = Profile.fromMap(profile.toMap());
      expect(fromMap.id, profile.id);
      expect(fromMap.name, profile.name);

      final defaults = Profile.fromMap({'id': '2', 'name': 'User 2'});
      expect(defaults.currencyLocale, 'en_IN');
      expect(defaults.monthlyBudget, 0.0);

      final updated = profile.copyWith(name: 'New Name', monthlyBudget: 500);
      expect(updated.name, 'New Name');
      expect(updated.monthlyBudget, 500);
    });
  });

  group('DashboardVisibilityConfig Model', () {
    test('DashboardVisibilityConfig handles defaults, copyWith, and fromMap',
        () {
      const config =
          DashboardVisibilityConfig(showIncomeExpense: false, showBudget: true);
      final fromMap = DashboardVisibilityConfig.fromMap(
          Map<String, dynamic>.from(config.toMap()));
      expect(fromMap.showIncomeExpense, isFalse);

      const defaults = DashboardVisibilityConfig();
      expect(defaults.showIncomeExpense, isTrue);
      expect(defaults.copyWith(showBudget: false).showBudget, isFalse);
      expect(DashboardVisibilityConfig.fromMap({}).showIncomeExpense, isTrue);
    });
  });
}
