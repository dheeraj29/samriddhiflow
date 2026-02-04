import 'package:flutter_test/flutter_test.dart';
import 'package:samriddhi_flow/models/transaction.dart';
import 'package:samriddhi_flow/models/category.dart';
import 'package:samriddhi_flow/utils/transaction_filter_utils.dart';
import 'package:samriddhi_flow/utils/report_utils.dart';

void main() {
  final now = DateTime.now();
  final t1 = Transaction(
    id: '1',
    title: 'Salary',
    amount: 5000,
    date: now,
    type: TransactionType.income,
    category: 'Salary',
    accountId: 'acc1',
  );
  final t2 = Transaction(
    id: '2',
    title: 'Food',
    amount: 50,
    date: now.subtract(const Duration(days: 5)),
    type: TransactionType.expense,
    category: 'Food',
    accountId: 'acc1',
  );
  final t3 = Transaction(
    id: '3',
    title: 'Rent',
    amount: 1000,
    date: now.subtract(const Duration(days: 40)), // Outside 30 days
    type: TransactionType.expense,
    category: 'Rent',
    accountId: 'acc2',
  );
  final tLoan = Transaction(
    id: '4',
    title: 'Loan Interest',
    amount: 100,
    date: now,
    type: TransactionType.expense,
    category: 'Loan Payment',
    loanId: 'loan1',
    // accountId is null for manual loan records
  );
  final tGain = Transaction(
    id: '5',
    title: 'Stock Profit',
    amount: 1000,
    date: now,
    type: TransactionType.income,
    category: 'Stocks',
    gainAmount: 200,
  );

  final transactions = [t1, t2, t3, tLoan, tGain];

  group('TransactionFilterUtils Tests', () {
    test('Filter by Type', () {
      final res = TransactionFilterUtils.filter(
        transactions: transactions,
        type: TransactionType.income,
      );
      expect(res.length, 2);
      expect(res.contains(t1), true);
      expect(res.contains(tGain), true);
    });

    test('Filter by Account', () {
      final res = TransactionFilterUtils.filter(
        transactions: transactions,
        accountId: 'acc1',
      );
      expect(res.length, 2);
      expect(res.contains(t1), true);
      expect(res.contains(t2), true);
    });

    test('Filter by periodMode (30 Days)', () {
      final res = TransactionFilterUtils.filter(
        transactions: transactions,
        periodMode: '30',
      );
      expect(res.length, 4); // t1, t2, tLoan, tGain are within 30 days
      expect(res.contains(t3), false);
    });
  });

  group('ReportUtils Tests', () {
    test('Aggregate by Category - Expense', () {
      final expenses = [t2, t3, tLoan];
      final res = ReportUtils.aggregateByCategory(
        transactions: expenses,
        type: TransactionType.expense,
      );
      // tLoan should be excluded if accountId is null and loanId exists
      expect(res.length, 2);
      expect(res['Food'], 50);
      expect(res['Rent'], 1000);
      expect(res.containsKey('Loan Payment'), false);
    });

    test('Aggregate Loan Payments', () {
      final res = ReportUtils.aggregateLoanPayments(transactions: transactions);
      expect(res.length, 1);
      expect(res['Loan Interest'], 100);
    });

    test('Aggregate Capital Gains', () {
      final cats = <Category>[
        Category.create(
          name: 'Stocks',
          usage: CategoryUsage.income,
          tag: CategoryTag.capitalGain,
        ),
        Category.create(
          name: 'Food',
          usage: CategoryUsage.expense,
        ),
      ];
      final res = ReportUtils.aggregateCapitalGains(
        transactions: transactions,
        categories: cats,
        reportType: TransactionType.income,
      );
      expect(res.length, 1);
      expect(res['Stocks'], 200);
    });

    test('Get Capital Gain Transactions', () {
      final cats = <Category>[
        Category.create(
          name: 'Stocks',
          usage: CategoryUsage.income,
          tag: CategoryTag.capitalGain,
        ),
      ];
      final res = ReportUtils.getCapitalGainTransactions(
        transactions: transactions,
        categories: cats,
        reportType: TransactionType.income,
      );
      expect(res.length, 1);
      expect(res.first.id, '5'); // tGain
    });
  });
}
