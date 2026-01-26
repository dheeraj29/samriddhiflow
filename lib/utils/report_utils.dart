import '../models/transaction.dart';
import '../models/category.dart';

class ReportUtils {
  static Map<String, double> aggregateByCategory({
    required List<Transaction> transactions,
    required TransactionType type,
  }) {
    Map<String, double> data = {};
    for (var t in transactions) {
      if (t.type != type) continue;

      // Business Rule: Exclude manual loan transactions (account is null but loanId exists)
      // These are filtered out from Spending/Income reports as they reflect debt, not direct cash flow
      if (t.accountId == null && t.loanId != null) continue;

      data[t.category] = (data[t.category] ?? 0) + t.amount;
    }
    return data;
  }

  static Map<String, double> aggregateLoanPayments({
    required List<Transaction> transactions,
  }) {
    Map<String, double> data = {};
    for (var t in transactions) {
      if (t.loanId != null &&
          (t.category == 'EMI' ||
              t.category == 'Prepayment' ||
              t.category == 'Loan Payment')) {
        data[t.title] = (data[t.title] ?? 0) + t.amount;
      }
    }
    return data;
  }

  static Map<String, double> aggregateCapitalGains({
    required List<Transaction> transactions,
    required List<Category> categories,
    required TransactionType reportType,
  }) {
    final catMap = {for (var c in categories) c.name: c};
    Map<String, double> gainsByCategory = {};

    final gainTxns = transactions.where((t) {
      final catObj = catMap[t.category];
      if (catObj?.tag != CategoryTag.capitalGain) return false;

      // Match report type (Income for profits, Expense for losses usually,
      // but here we filter by TransactionType as well)
      return t.type == reportType;
    }).toList();

    for (var t in gainTxns) {
      final amount = t.gainAmount ?? 0;
      gainsByCategory[t.category] = (gainsByCategory[t.category] ?? 0) + amount;
    }

    return gainsByCategory;
  }

  static List<Transaction> getCapitalGainTransactions({
    required List<Transaction> transactions,
    required List<Category> categories,
    required TransactionType reportType,
  }) {
    final catMap = {for (var c in categories) c.name: c};
    return transactions.where((t) {
      final catObj = catMap[t.category];
      if (catObj?.tag != CategoryTag.capitalGain) return false;
      return t.type == reportType;
    }).toList();
  }
}
