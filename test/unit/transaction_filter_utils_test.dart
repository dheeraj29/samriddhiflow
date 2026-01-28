import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_test/flutter_test.dart';
import 'package:samriddhi_flow/models/transaction.dart';
import 'package:samriddhi_flow/utils/transaction_filter_utils.dart';
import 'package:samriddhi_flow/widgets/transaction_filter.dart';

void main() {
  group('TransactionFilterUtils', () {
    final t1 = Transaction(
        id: '1',
        title: 'T1',
        amount: 100,
        date: DateTime(2024, 5, 10),
        type: TransactionType.expense,
        category: 'Food',
        accountId: 'a1',
        profileId: 'p1');
    final t2 = Transaction(
        id: '2',
        title: 'T2',
        amount: 200,
        date: DateTime(2024, 5, 20),
        type: TransactionType.income,
        category: 'Salary',
        accountId: 'a2',
        profileId: 'p1');
    final t3 = Transaction(
        id: '3',
        title: 'T3',
        amount: 50,
        date: DateTime(2024, 4, 15),
        type: TransactionType.expense,
        category: 'Travel',
        accountId: 'a1',
        profileId: 'p1');
    final tTransfer = Transaction(
        id: '4',
        title: 'Transfer',
        amount: 500,
        date: DateTime(2024, 5, 15),
        type: TransactionType.transfer,
        category: 'Transfer',
        accountId: 'a1',
        toAccountId: 'a2',
        profileId: 'p1');
    final tDeleted = Transaction(
        id: '5',
        title: 'Del',
        amount: 10,
        date: DateTime(2024, 5, 5),
        type: TransactionType.expense,
        category: 'Food',
        accountId: 'a1',
        profileId: 'p1',
        isDeleted: true);

    final allTxns = [t1, t2, t3, tTransfer, tDeleted];

    test('Filters out deleted transactions', () {
      final res = TransactionFilterUtils.filter(transactions: allTxns);
      expect(res.contains(tDeleted), false);
      expect(res.length, 4);
    });

    test('Filters by Type', () {
      final res = TransactionFilterUtils.filter(
          transactions: allTxns, type: TransactionType.income);
      expect(res.length, 1);
      expect(res.first.id, '2');
    });

    test('Filters by Category', () {
      final res = TransactionFilterUtils.filter(
          transactions: allTxns, category: 'Food');
      expect(res.length, 1);
      expect(res.first.id, '1');
    });

    test('Filters by Excluded Categories', () {
      final res = TransactionFilterUtils.filter(
          transactions: allTxns, excludedCategories: ['Salary']);
      expect(res.any((t) => t.category == 'Salary'), false);
    });

    test('Filters by Account (Source)', () {
      final res =
          TransactionFilterUtils.filter(transactions: allTxns, accountId: 'a1');
      // t1(a1), t3(a1), tTransfer(a1->a2)
      expect(res.length, 3);
    });

    test('Filters by Account (Target)', () {
      final res =
          TransactionFilterUtils.filter(transactions: allTxns, accountId: 'a2');
      // t2(a2), tTransfer(a1->a2)
      expect(res.length, 2);
    });

    test('Filters by Account (None)', () {
      final tNone = Transaction(
          id: '6',
          title: 'Cash',
          amount: 10,
          date: DateTime.now(),
          type: TransactionType.expense,
          category: 'Misc',
          profileId: 'p1');
      final res = TransactionFilterUtils.filter(
          transactions: [tNone, t1], accountId: 'none');
      expect(res.length, 1);
      expect(res.first.id, '6');
    });

    // Time Filters require dynamic dates, mocking DateTime.now() is hard without a library or wrapper.
    // However, we can construct transactions relative to "now" in the test.
    test('Filters by TimeRange.last30Days', () {
      final now = DateTime.now();
      final tNew = t1.copyWith(date: now.subtract(const Duration(days: 2)));
      final tOld = t1.copyWith(date: now.subtract(const Duration(days: 40)));

      final res = TransactionFilterUtils.filter(
          transactions: [tNew, tOld], range: TimeRange.last30Days);
      expect(res.length, 1);
      expect(res.first, tNew);
    });

    test('Filters by PeriodMode month', () {
      final date = DateTime(2023, 10, 15);
      final tMatch = t1.copyWith(date: date);
      final tMismatch = t1.copyWith(date: DateTime(2023, 11, 1));

      final res = TransactionFilterUtils.filter(
          transactions: [tMatch, tMismatch],
          periodMode: 'month',
          selectedMonth: DateTime(2023, 10, 1));

      expect(res.length, 1);
      expect(res.first, tMatch);
    });

    test('Filters by TimeRange.custom', () {
      final now = DateTime.now();
      final tIn = t1.copyWith(date: now.subtract(const Duration(days: 5)));
      final tOut = t1.copyWith(date: now.subtract(const Duration(days: 20)));

      final range = DateTimeRange(
          start: now.subtract(const Duration(days: 10)), end: now);

      final res = TransactionFilterUtils.filter(
          transactions: [tIn, tOut],
          range: TimeRange.custom,
          customRange: range);

      expect(res.length, 1);
      expect(res.first, tIn);
    });
  });
}
