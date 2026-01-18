import 'dart:math';
import '../models/loan.dart';
import '../utils/currency_utils.dart';

class LoanService {
  bool isLeapYear(int year) {
    if (year % 4 != 0) return false;
    if (year % 100 != 0) return true;
    return year % 400 == 0;
  }

  int getDaysInYear(int year) => isLeapYear(year) ? 366 : 365;

  /// Calculates exact interest accrued between two dates using Daily Reducing Balance.
  /// Handles year boundaries and leap years correctly.
  double calculateAccruedInterest({
    required double principal,
    required double annualRate,
    required DateTime fromDate,
    required DateTime toDate,
  }) {
    if (principal <= 0 || annualRate <= 0 || !toDate.isAfter(fromDate)) {
      return 0;
    }

    double totalInterest = 0;
    DateTime current = fromDate;

    // Iterate day by day or optimize by year
    while (current.year < toDate.year) {
      final endOfYear = DateTime(current.year, 12, 31);
      final daysInThisYearForPeriod = endOfYear.difference(current).inDays + 1;
      totalInterest += (principal * annualRate * daysInThisYearForPeriod) /
          (getDaysInYear(current.year) * 100);
      current = DateTime(current.year + 1, 1, 1);
    }

    final remainingDays = toDate.difference(current).inDays;
    if (remainingDays > 0) {
      totalInterest += (principal * annualRate * remainingDays) /
          (getDaysInYear(current.year) * 100);
    }

    return CurrencyUtils.roundTo2Decimals(totalInterest);
  }

  /// Calculates EMI using the standard formula.
  double calculateEMI({
    required double principal,
    required double annualRate,
    required int tenureMonths,
  }) {
    if (principal <= 0 || tenureMonths <= 0) return 0;
    if (annualRate <= 0) return principal / tenureMonths;

    double monthlyRate = annualRate / 12 / 100;
    double numerator =
        principal * monthlyRate * pow(1 + monthlyRate, tenureMonths);
    double denominator = pow(1 + monthlyRate, tenureMonths) - 1;

    return CurrencyUtils.roundTo2Decimals(numerator / denominator);
  }

  /// Generates a forecast of future payments based on Daily Reducing Balance.
  List<Map<String, dynamic>> calculateAmortizationSchedule(Loan loan) {
    if (loan.remainingPrincipal <= 0) return [];

    List<Map<String, dynamic>> schedule = [];
    double balance = loan.remainingPrincipal;

    // Determine last payment date or start date
    DateTime lastDate = loan.transactions.isNotEmpty
        ? loan.transactions
            .map((t) => t.date)
            .reduce((a, b) => a.isAfter(b) ? a : b)
        : loan.startDate;

    // Normalize lastDate to date only to avoid time drifts
    lastDate = DateTime(lastDate.year, lastDate.month, lastDate.day);

    double emi = loan.emiAmount;
    if (emi <= 0) return [];

    int safetyCounter = 0;
    while (balance > 0.01 && safetyCounter < 600) {
      // Max 50 years
      safetyCounter++;

      // Target next payment date based on emiDay
      DateTime nextDate =
          DateTime(lastDate.year, lastDate.month + 1, loan.emiDay);

      double interest = calculateAccruedInterest(
          principal: balance,
          annualRate: loan.interestRate,
          fromDate: lastDate,
          toDate: nextDate);

      double principal = CurrencyUtils.roundTo2Decimals(emi - interest);

      if (balance < principal || principal <= 0) {
        principal = balance;
        emi = CurrencyUtils.roundTo2Decimals(principal + interest);
      }

      balance = CurrencyUtils.roundTo2Decimals(balance - principal);
      if (balance < 0) balance = 0;

      schedule.add({
        'month': safetyCounter,
        'date': nextDate,
        'emi': emi,
        'interest': interest,
        'principal': principal,
        'balance': balance,
      });

      lastDate = nextDate;
    }

    return schedule;
  }

  /// Calculates new attributes after a prepayment using Daily Reducing Balance.
  Map<String, dynamic> calculatePrepaymentImpact({
    required Loan loan,
    required double prepaymentAmount,
    required bool reduceTenure,
  }) {
    double newPrincipal = loan.remainingPrincipal - prepaymentAmount;
    if (newPrincipal <= 0) {
      return {
        'newEMI': 0.0,
        'newTenure': 0,
        'interestSaved': calculateTotalRemainingInterest(loan),
        'tenureSaved': calculateTenureForEMI(
            principal: loan.remainingPrincipal,
            annualRate: loan.interestRate,
            emi: loan.emiAmount)
      };
    }

    // Original Path Interest
    final originalRemainingInterest = calculateTotalRemainingInterest(loan);

    if (reduceTenure) {
      final newTenure = calculateTenureForEMI(
        principal: newPrincipal,
        annualRate: loan.interestRate,
        emi: loan.emiAmount,
      );

      // New Path Interest (Approximate but consistent)
      final newRemainingInterest = (loan.emiAmount * newTenure) - newPrincipal;

      return {
        'newEMI': loan.emiAmount,
        'newTenure': newTenure,
        'interestSaved': (originalRemainingInterest - newRemainingInterest)
            .clamp(0, double.infinity),
        'tenureSaved': (calculateTenureForEMI(
                  principal: loan.remainingPrincipal,
                  annualRate: loan.interestRate,
                  emi: loan.emiAmount,
                ) -
                newTenure)
            .clamp(0, 600),
      };
    } else {
      // Keep Tenure same (remaining tenure), recalculate EMI
      int monthsPassed = DateTime.now().difference(loan.startDate).inDays ~/ 30;
      int remainingMonths = (loan.tenureMonths - monthsPassed).clamp(1, 600);

      double newEMI = calculateEMI(
        principal: newPrincipal,
        annualRate: loan.interestRate,
        tenureMonths: remainingMonths,
      );

      final newRemainingInterest = (newEMI * remainingMonths) - newPrincipal;

      return {
        'newEMI': newEMI,
        'newTenure': remainingMonths,
        'interestSaved': (originalRemainingInterest - newRemainingInterest)
            .clamp(0, double.infinity),
        'tenureSaved': 0,
      };
    }
  }

  double calculateTotalRemainingInterest(Loan loan) {
    if (loan.remainingPrincipal <= 0) return 0;
    // Sum of interest in current projected schedule
    final schedule = calculateAmortizationSchedule(loan);
    return schedule.fold(
        0.0, (sum, item) => sum + (item['interest'] as double));
  }

  /// Calculates tenure (n) given Principal (P), Rate (r), and EMI (E)
  /// n = -log(1 - (r*P)/E) / log(1+r)
  int calculateTenureForEMI({
    required double principal,
    required double annualRate,
    required double emi,
  }) {
    if (principal <= 0 || emi <= 0) return 0;
    if (annualRate <= 0) return (principal / emi).ceil();

    double r = annualRate / 12 / 100;

    // If interest alone is greater than EMI, it will never be paid off
    if (emi <= principal * r) return 1200; // Cap at 100 years

    double inner = 1 - (r * principal / emi);
    double n = -log(inner) / log(1 + r);
    return n.ceil();
  }

  /// Calculates interest rate (r) given Principal (P), Tenure (n), and EMI (E)
  /// Uses the Bisection Method to find the annual interest rate that results in the target EMI.
  double calculateRateForEMITenure({
    required double principal,
    required int tenureMonths,
    required double emi,
  }) {
    // Edge cases: If EMI is less than principal/tenure, rate is theoretically negative or 0.
    if (principal <= 0 ||
        tenureMonths <= 0 ||
        emi <= principal / tenureMonths) {
      return 0.0;
    }

    // Standard monthly EMI formula: E = P * r * (1+r)^n / ((1+r)^n - 1)
    // We want to find 'r' such that CalculateEMI(P, r, n) - targetEMI = 0

    double low = 0.0; // 0% annual
    double high = 1.0; // 1200% annual (extremely high upper bound)
    const double precision = 0.0000001;
    const int maxIterations = 100;

    for (int i = 0; i < maxIterations; i++) {
      double mid = (low + high) / 2;
      double calculatedEMI = calculateEMI(
          principal: principal,
          annualRate:
              mid * 12 * 100, // Convert monthly rate back to annual percentage
          tenureMonths: tenureMonths);

      if (calculatedEMI > emi) {
        high = mid;
      } else {
        low = mid;
      }

      if ((high - low).abs() < precision) {
        break;
      }
    }

    double finalMonthlyRate = (low + high) / 2;
    double annualRate = finalMonthlyRate * 12 * 100;

    // Round to 2 decimal places as per requirement
    return (annualRate * 100).round() / 100;
  }

  /// Calculates the total unpaid accrued interest from the start of the loan
  /// until [tillDate], accounting for all transactions (payments, top-ups, rate changes).
  double calculateCumulativeAccruedInterest(Loan loan, {DateTime? tillDate}) {
    final endDate = tillDate ?? DateTime.now();
    if (loan.startDate.isAfter(endDate)) return 0;

    // 1. Sort transactions by date
    final sortedTxns = List<LoanTransaction>.from(loan.transactions)
      ..sort((a, b) => a.date.compareTo(b.date));

    // Deduce Initial Principal
    // If no transactions, current balance is the initial balance.
    // If transactions exist, we take the FIRST transaction's state to deduce what was before it.

    double activePrincipal;
    if (sortedTxns.isEmpty) {
      // No history, so the current remaining is the start logic (unless reduced externally, but we assume integrity).
      activePrincipal = loan.remainingPrincipal;
    } else {
      final firstTxn = sortedTxns.first;
      if (firstTxn.type == LoanTransactionType.topup) {
        // Before TopUp, Principal was Resultant - TopUp Amount
        // (Assuming principalComponent stores amount added to principal)
        activePrincipal =
            firstTxn.resultantPrincipal - firstTxn.principalComponent;
      } else if (firstTxn.type == LoanTransactionType.emi ||
          firstTxn.type == LoanTransactionType.prepayment) {
        // Before Payment, Principal was Resultant + Payment
        activePrincipal =
            firstTxn.resultantPrincipal + firstTxn.principalComponent;
      } else {
        // Rate change or others, principal usually unchanged
        activePrincipal = firstTxn.resultantPrincipal;
      }
    }

    // Safety check: Principal shouldn't be negative.
    if (activePrincipal < 0) activePrincipal = 0;

    double totalAccrued = 0;
    double totalInterestPaid = 0;

    double activeRate =
        loan.interestRate; // Assuming constant for MVP Gold Loan
    DateTime lastDate = loan.startDate;

    for (var txn in sortedTxns) {
      if (txn.date.isAfter(endDate)) break;

      // Calculate Interest for interval [lastDate -> txn.date]
      final accruedInInterval = calculateAccruedInterest(
        principal: activePrincipal,
        annualRate: activeRate,
        fromDate: lastDate,
        toDate: txn.date,
      );

      totalAccrued += accruedInInterval;

      // Handle Transaction Impact
      if (txn.type == LoanTransactionType.emi) {
        totalInterestPaid += txn.interestComponent;
        activePrincipal = txn.resultantPrincipal;
      } else if (txn.type == LoanTransactionType.prepayment) {
        totalInterestPaid += txn.interestComponent;
        activePrincipal = txn.resultantPrincipal;
      } else if (txn.type == LoanTransactionType.topup) {
        activePrincipal = txn.resultantPrincipal;
      } else if (txn.type == LoanTransactionType.rateChange) {
        activeRate = txn.amount;
      }

      lastDate = txn.date;
    }

    // Final Segment: Last Txn -> Now
    if (endDate.isAfter(lastDate)) {
      totalAccrued += calculateAccruedInterest(
        principal: activePrincipal,
        annualRate: activeRate,
        fromDate: lastDate,
        toDate: endDate,
      );
    }

    // Return unpaid interest
    return (totalAccrued - totalInterestPaid).clamp(0, double.infinity);
  }
}
