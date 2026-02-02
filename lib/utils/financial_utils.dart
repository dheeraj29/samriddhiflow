import '../models/transaction.dart';
import '../models/loan.dart';

class FinancialUtils {
  static double calculateTotalIncome(List<Transaction> transactions) {
    return transactions
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  static double calculateTotalExpenses(List<Transaction> transactions) {
    return transactions
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  static double calculateTotalLiability(List<Loan> loans) {
    return loans.fold(0.0, (sum, l) => sum + l.remainingPrincipal);
  }

  static int calculateMaxRemainingTenure(List<Loan> loans) {
    if (loans.isEmpty) return 0;
    return loans.fold<int>(0, (max, l) {
      final tenure = l.tenureMonths;
      return tenure > max ? tenure : max;
    });
  }
}
