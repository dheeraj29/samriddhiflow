import 'package:flutter_test/flutter_test.dart';
import 'package:samriddhi_flow/models/profile.dart';
import 'package:samriddhi_flow/models/account.dart';
import 'package:samriddhi_flow/models/transaction.dart';
import 'package:samriddhi_flow/models/lending_record.dart';
import 'package:samriddhi_flow/models/dashboard_config.dart';

void main() {
  group('Model Coverage', () {
    test('Profile model coverage', () {
      final p1 = Profile(
          id: '1',
          name: 'User 1',
          currencyLocale: 'en_US',
          monthlyBudget: 1000);
      expect(p1.id, '1');
      expect(p1.name, 'User 1');
      expect(p1.currencyLocale, 'en_US');
      expect(p1.monthlyBudget, 1000);

      final p2 = Profile.create(name: 'User 2');
      expect(p2.name, 'User 2');
      expect(p2.id, isNotEmpty);

      final map = p1.toMap();
      final fromMap = Profile.fromMap(map);
      expect(fromMap.id, p1.id);
      expect(fromMap.name, p1.name);
      expect(fromMap.currencyLocale, p1.currencyLocale);

      final fromMapDefault = Profile.fromMap({'id': '2', 'name': 'User 2'});
      expect(fromMapDefault.currencyLocale, 'en_IN');
      expect(fromMapDefault.monthlyBudget, 0.0);

      final p3 = p1.copyWith(name: 'New Name', monthlyBudget: 500);
      expect(p3.name, 'New Name');
      expect(p3.monthlyBudget, 500);
      expect(p3.id, '1');
    });

    test('Account model coverage', () {
      final a1 = Account(
          id: '1',
          name: 'Acc 1',
          type: AccountType.savings,
          balance: 100,
          profileId: 'p1',
          creditLimit: 5000,
          billingCycleDay: 15,
          paymentDueDateDay: 5,
          currency: 'INR');

      expect(a1.name, 'Acc 1');
      expect(a1.calculateBilledAmount([]), 100);

      final cc = Account(
          id: '2',
          name: 'CC',
          type: AccountType.creditCard,
          balance: -50,
          billingCycleDay: 10);
      expect(cc.calculateBilledAmount([]), 0.0); // Clamped to 0

      expect(a1.copyWith(balance: 200).balance, 200);

      final aEmpty = Account.empty();
      expect(aEmpty.id, '');

      final aCreate = Account.create(name: 'New', type: AccountType.wallet);
      expect(aCreate.name, 'New');

      final map = a1.toMap();
      final fromMap = Account.fromMap(map);
      expect(fromMap.id, a1.id);
      expect(fromMap.type, a1.type);

      // Edge cases: NaN/Inf
      final fromMapEdge = Account.fromMap({
        'id': '3',
        'name': 'Edge',
        'balance': double.infinity,
        'type': 0,
        'creditLimit': double.nan
      });
      expect(fromMapEdge.balance, 0.0);
      expect(fromMapEdge.creditLimit, 0.0);

      // CopyWith most fields
      final a4 = a1.copyWith(
          name: 'New Acc',
          type: AccountType.creditCard,
          billingCycleDay: 1,
          paymentDueDateDay: 10,
          profileId: 'p2',
          currency: 'USD');
      expect(a4.name, 'New Acc');
      expect(a4.type, AccountType.creditCard);
    });

    test('Transaction model coverage', () {
      final t1 = Transaction(
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

      expect(t1.title, 'T1');
      final map = t1.toMap();
      final fromMap = Transaction.fromMap(map);
      expect(fromMap.id, t1.id);
      expect(fromMap.toAccountId, 'a2');
      expect(fromMap.taxSync, true);

      // CopyWith all fields
      final t2 = t1.copyWith(
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
          taxSync: false);
      expect(t2.id, '2');
      expect(t2.isDeleted, true);
      expect(t2.gainAmount, 500);

      final tCreate = Transaction.create(
          title: 'New T',
          amount: 10,
          date: DateTime.now(),
          type: TransactionType.income,
          category: 'Sal',
          accountId: 'a1',
          loanId: 'lx',
          holdingTenureMonths: 24,
          gainAmount: 100,
          profileId: 'p1');
      expect(tCreate.title, 'New T');
      expect(tCreate.loanId, 'lx');

      // fromMap edge cases & all fields
      final tEdge = Transaction.fromMap({
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
        'toAccountId': 'a2'
      });
      expect(tEdge.amount, 0.0);
      expect(tEdge.gainAmount, 0.0);
      expect(tEdge.isDeleted, true);
      expect(tEdge.isRecurringInstance, true);
      expect(tEdge.taxSync, false);
      expect(tEdge.accountId, 'a1');
      expect(tEdge.toAccountId, 'a2');
    });

    test('LendingRecord model coverage', () {
      final r1 = LendingRecord(
          id: '1',
          personName: 'P1',
          amount: 100,
          date: DateTime(2024),
          type: LendingType.lent,
          reason: 'R1',
          profileId: 'p1',
          isClosed: true,
          closedDate: DateTime(2024, 1, 2));
      expect(r1.isClosed, true);
      expect(r1.copyWith(isClosed: false, personName: 'New').personName, 'New');

      final p1 = LendingPayment(
          id: 'p1', amount: 50, date: DateTime(2024), note: 'P note');
      final r2 = LendingRecord(
          id: '1',
          personName: 'P1',
          amount: 100,
          reason: 'R1',
          date: DateTime(2024),
          type: LendingType.lent,
          payments: [p1]);
      expect(r2.totalPaid, 50);
      expect(r2.remainingAmount, 50);

      final map = r2.toMap();
      final fromMap = LendingRecord.fromMap(map);
      expect(fromMap.id, r2.id);
      expect(fromMap.payments.length, 1);
      expect(fromMap.payments.first.note, 'P note');

      // fromMap with null payments
      final fromMapNull = LendingRecord.fromMap({
        'id': '1',
        'personName': 'P',
        'amount': 100,
        'reason': 'R',
        'date': DateTime.now().toIso8601String(),
        'type': 0,
        'payments': null,
        'profileId': 'px',
        'isClosed': true,
        'closedDate': DateTime.now().toIso8601String()
      });
      expect(fromMapNull.payments, isEmpty);
      expect(fromMapNull.profileId, 'px');
      expect(fromMapNull.isClosed, true);

      final paymentMap = p1.toMap();
      final pFromMap = LendingPayment.fromMap(paymentMap);
      expect(pFromMap.id, p1.id);
    });

    test('DashboardVisibilityConfig coverage', () {
      const config =
          DashboardVisibilityConfig(showIncomeExpense: false, showBudget: true);
      final map = config.toMap();
      final fromMap =
          DashboardVisibilityConfig.fromMap(Map<String, dynamic>.from(map));
      expect(fromMap.showIncomeExpense, false);

      const configDefault = DashboardVisibilityConfig();
      expect(configDefault.showIncomeExpense, true);
      expect(configDefault.copyWith(showBudget: false).showBudget, false);

      // fromMap with missing keys
      final fromMapEmpty = DashboardVisibilityConfig.fromMap({});
      expect(fromMapEmpty.showIncomeExpense, true);
    });
  });

  group('Models edge cases', () {
    test('Transaction edge cases', () {
      expect(
          () => Transaction.fromMap({
                'id': 'x',
                'title': 'X',
                'amount': 1,
                'date': 'invalid',
                'type': 0,
                'category': 'C'
              }),
          throwsFormatException);
    });
  });
}
