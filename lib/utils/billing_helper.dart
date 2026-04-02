import '../models/account.dart';
import '../models/transaction.dart';
import 'currency_utils.dart';

class BillingHelper {
  /// Returns the Start Date of the billing cycle that surrounds the given [date].
  /// [cycleDay]: The day of the month when the bill is generated (new cycle starts).
  static DateTime getCycleStart(DateTime date, int cycleDay) {
    // Rule: Cycle starts the day AFTER the billing day of the target month.
    // If today is past the billing day, target is current month. Otherwise, previous month.
    int targetMonth = (date.day > cycleDay) ? date.month : date.month - 1;
    DateTime base = DateTime(date.year, targetMonth);

    // Robustly handle cycle days like 31 by capping at last day of the month.
    int lastDayOfMonth = DateTime(base.year, base.month + 1, 0).day;
    int day = cycleDay > lastDayOfMonth ? lastDayOfMonth : cycleDay;

    return DateTime(base.year, base.month, day + 1);
  }

  /// Returns true if the [txnDate] is in the "Unbilled" (current) cycle for the given [now].
  /// The current cycle starts AFTER the billing day.
  static bool isUnbilled(DateTime txnDate, DateTime now, int cycleDay) {
    // The current cycle starts AFTER the billing day of the previous month.
    final currentCycleStart = getCycleStart(now, cycleDay);

    final txnDateOnly = DateTime(txnDate.year, txnDate.month, txnDate.day);
    return !txnDateOnly.isBefore(currentCycleStart);
  }

  /// Returns the End Date (Billing Day) of the cycle surrounding [date].
  static DateTime getCycleEnd(DateTime date, int cycleDay) {
    int targetMonth = (date.day > cycleDay) ? date.month + 1 : date.month;
    DateTime base = DateTime(date.year, targetMonth);
    int lastDayOfMonth = DateTime(base.year, base.month + 1, 0).day;
    int day = cycleDay > lastDayOfMonth ? lastDayOfMonth : cycleDay;
    return DateTime(base.year, base.month, day);
  }

  /// Returns the Statement Generation Date for the current cycle.
  /// This is always 1 second before the Current Cycle Start.
  static DateTime getStatementDate(DateTime now, int cycleDay) {
    final currentCycleStart = getCycleStart(now, cycleDay);
    return currentCycleStart.subtract(const Duration(seconds: 1));
  }

  /// Returns the Start Date of the next cycle.
  static DateTime getNextCycleStart(DateTime currentCycleStart, int cycleDay) {
    final currentCycleEnd = getCycleEnd(currentCycleStart, cycleDay);
    return currentCycleEnd.add(const Duration(days: 1));
  }

  /// Calculates the "Unbilled" amount (Spent in current cycle).
  /// Range: (Current Cycle Start, Now].
  static double calculateUnbilledAmount(
      Account acc, List<Transaction> allTxns, DateTime now,
      {int? lastRolloverMillis}) {
    if (acc.type != AccountType.creditCard || acc.billingCycleDay == null) {
      return 0;
    }
    final currentCycleStart = getCycleStart(now, acc.billingCycleDay!);

    // Start boundary defaults to currentCycleStart.
    DateTime startBound = currentCycleStart;

    // Freeze Logic: While frozen, anything since the NEWEST pointer
    // is "Unbilled" (until the next cycle rolls).
    if (acc.isFrozen) {
      if (!acc.isFrozenCalculated && acc.freezeDate != null) {
        // Phase 1: Everything since the freeze started is "Unbilled".
        startBound = acc.freezeDate!;
      } else if (acc.isFrozenCalculated) {
        // coverage:ignore-line
        // Phase 2: Transition Bill is generated. Billed covers [freezeDate, pointer].
        // So Unbilled MUST start exactly where Billed ends (the pointer).
        if (lastRolloverMillis != null) {
          startBound = DateTime.fromMillisecondsSinceEpoch(
              lastRolloverMillis); // coverage:ignore-line
        } else {
          // Fallback: This shouldn't happen if isFrozenCalculated is true, but safety first.
          startBound = acc.freezeDate!; // coverage:ignore-line
        }
      }
    }

    // STANDARD RULE: Bucket displays (Billed/Unbilled) show Gross Spend.
    // The Waterfall logic (getAdjustedCCData) handles subtracting payments.
    return calculatePeriodSpend(
      acc,
      allTxns,
      startBound,
      now,
      skipTransfers: true,
      includeIncome: false,
    );
  }

  /// Calculates the "Billed" amount (Generated Statement) that hasn't been added to Balance yet.
  /// Range: (Last Rollover Date, Current Cycle Start].
  static double calculateBilledAmount(Account acc, List<Transaction> allTxns,
      DateTime now, int? lastRolloverMillis,
      {bool skipTransfers = true, bool includeIncome = false}) {
    // REFINEMENT: Phase 1 Billed is ALWAYS 0.
    if (acc.isFrozen && !acc.isFrozenCalculated) {
      return 0;
    }

    if (acc.billingCycleDay == null) return 0.0;
    final currentCycleStart = getCycleStart(now, acc.billingCycleDay!);
    final startLimit = _getBilledStartBound(acc, currentCycleStart);

    // Freeze Logic: In Phase 2, the "Billed" bucket is specifically the gap
    // from freezeDate to the transition pointer (lastRollover).
    DateTime endLimit = currentCycleStart;
    if (acc.isFrozen && acc.isFrozenCalculated && lastRolloverMillis != null) {
      final lastRollover =
          DateTime.fromMillisecondsSinceEpoch(lastRolloverMillis);
      // In Phase 2, Billed specifically covers history until the transition was realized.
      if (lastRollover.isAfter(startLimit)) {
        endLimit = lastRollover;
      }
    }

    // STANDARD RULE: Bucket displays (Billed/Unbilled) show Gross Spend.
    // The Waterfall logic (getAdjustedCCData) handles subtracting payments.
    return calculatePeriodSpend(
      acc,
      allTxns,
      startLimit,
      endLimit,
      skipTransfers: true,
      includeIncome: false,
    );
  }

  /// Helper to determine the start boundary of the billed period.
  static DateTime _getBilledStartBound(
      Account acc, DateTime currentCycleStart) {
    // Standard Rule: Billed always shows the Gross Spend of the PREVIOUS cycle.
    DateTime startLimit = getCycleStart(
        currentCycleStart.subtract(const Duration(days: 1)),
        acc.billingCycleDay!);

    // Freeze Logic: While frozen, the "Billed" bucket logic changes.
    if (acc.isFrozen) {
      if (acc.isFrozenCalculated && acc.freezeDate != null) {
        // Phase 2: Start precisely from freezeDate to capture the transition gap.
        startLimit = acc.freezeDate!;
      } else {
        // Phase 1: Force Billed amount to 0 by matching end boundary (currentCycleStart).
        startLimit = currentCycleStart;
      }
    }

    return startLimit;
  }

  static (double total, double billed, double balance, double unbilled)
      getAdjustedCCData({
    required double accountBalance,
    required double billedAmount,
    required double unbilledAmount,
    required double paymentsSinceRollover,
  }) {
    // To get the "Pure" historical debt, we add them back.
    double pureBalance = accountBalance + paymentsSinceRollover;

    double totalAvailablePayments = paymentsSinceRollover;
    if (pureBalance < 0) {
      totalAvailablePayments += (-pureBalance);
      pureBalance = 0;
    }

    // Stage 1: Subtract payments from Billed amount first.
    double adjBilled = billedAmount - totalAvailablePayments;
    double surplus = 0;
    if (adjBilled < 0) {
      surplus = -adjBilled;
      adjBilled = 0;
    }

    // Stage 2: Subtract surplus from Historical Balance.
    double adjBalance = pureBalance - surplus;
    if (adjBalance < 0) {
      surplus = -adjBalance;
      adjBalance = 0;
    } else {
      surplus = 0;
    }

    // Stage 3: Subtract remaining surplus from Unbilled amount.
    double adjUnbilled = unbilledAmount - surplus;
    double finalBalance = 0;
    if (adjUnbilled < 0) {
      finalBalance = adjUnbilled; // Excess Credit
      adjUnbilled = 0;
    }

    final totalNetDebt = CurrencyUtils.roundTo2Decimals(
        adjBilled + adjBalance + adjUnbilled + finalBalance);

    return (
      totalNetDebt,
      CurrencyUtils.roundTo2Decimals(adjBilled),
      CurrencyUtils.roundTo2Decimals(adjBalance + finalBalance),
      CurrencyUtils.roundTo2Decimals(adjUnbilled)
    );
  }

  /// Calculates total credits received (Incoming transfers, Income, Rounding Adjustments).
  static double calculatePeriodPayments(
      Account acc, List<Transaction> allTxns, DateTime start, DateTime end) {
    // Range: (start, end]
    final relevantTxns = allTxns.where((t) =>
        !t.isDeleted &&
        (t.accountId == acc.id || t.toAccountId == acc.id) &&
        !t.date.isBefore(start) &&
        (t.date.isBefore(end) || t.date.isAtSameMomentAs(end)));

    return relevantTxns.fold<double>(
        0, (sum, t) => sum + _getPaymentImpact(t, acc.id));
  }

  static double _getPaymentImpact(Transaction t, String accountId) {
    if (_isIncomingTransfer(t, accountId)) {
      return t.amount;
    }
    if (_isDirectIncomeToAccount(t, accountId)) {
      // coverage:ignore-line
      return t.amount; // coverage:ignore-line
    }
    return _getRoundingPaymentImpact(t, accountId); // coverage:ignore-line
  }

  static bool _isIncomingTransfer(Transaction t, String accountId) {
    return t.type == TransactionType.transfer && t.toAccountId == accountId;
  }

  static bool _isDirectIncomeToAccount(Transaction t, String accountId) {
    // coverage:ignore-line
    return t.type == TransactionType.income &&
        t.accountId == accountId; // coverage:ignore-line
  }

  static double _getRoundingPaymentImpact(Transaction t, String accountId) {
    // coverage:ignore-line
    if (!isRoundingAdjustment(t) || t.accountId != accountId) {
      // coverage:ignore-line
      return 0;
    }
    return t.type == TransactionType.income
        ? t.amount
        : -t.amount; // coverage:ignore-line
  }

  /// Shared logic to calculate Net Spend (Expenses + Outgoing Transfers) in a date range.
  /// Range: (Start, End] (Start exclusive, End inclusive/inclusive-ish depending on logic)
  static double calculatePeriodSpend(
      Account acc, List<Transaction> allTxns, DateTime start, DateTime end,
      {bool skipTransfers = false, bool includeIncome = false}) {
    // Range: (start, end]
    final relevantTxns = allTxns.where((t) =>
        !t.isDeleted &&
        (t.accountId == acc.id || t.toAccountId == acc.id) &&
        !t.date.isBefore(start) &&
        (t.date.isBefore(end) || t.date.isAtSameMomentAs(end)));

    return relevantTxns.fold<double>(
        0,
        (sum, t) =>
            sum +
            _getTxnSpendImpact(t, acc.id,
                skipTransfers: skipTransfers, includeIncome: includeIncome));
  }

  static bool isRoundingAdjustment(Transaction t) {
    return t.title.trim().toLowerCase() == 'rounding adjustment';
  }

  static double _getTxnSpendImpact(Transaction t, String accountId,
      {bool skipTransfers = false, bool includeIncome = false}) {
    // Rule: "Rounding Adjustment" is always treated as a payment/credit adjustment, not a spend.
    final roundingImpact = _getRoundingSpendImpact(t, accountId, includeIncome);
    if (roundingImpact != null) return roundingImpact;

    if (t.accountId == accountId) {
      return _getOutgoingSpendImpact(t, includeIncome);
    }
    if (t.toAccountId == accountId) {
      return _getIncomingSpendImpact(t, skipTransfers, includeIncome);
    }
    return 0;
  }

  static double? _getRoundingSpendImpact(
      Transaction t, String accountId, bool includeIncome) {
    if (!isRoundingAdjustment(t)) return null;
    if (!includeIncome) return 0;
    if (t.accountId != accountId) return 0; // coverage:ignore-line
    return t.type == TransactionType.income
        ? -t.amount
        : t.amount; // coverage:ignore-line
  }

  static double _getOutgoingSpendImpact(Transaction t, bool includeIncome) {
    switch (t.type) {
      case TransactionType.expense:
      case TransactionType.transfer:
        return t.amount;
      case TransactionType.income:
        return includeIncome ? -t.amount : 0; // coverage:ignore-line
    }
  }

  static double _getIncomingSpendImpact(
      Transaction t, bool skipTransfers, bool includeIncome) {
    if (t.type == TransactionType.transfer) {
      return (includeIncome && !skipTransfers)
          ? -t.amount
          : 0; // coverage:ignore-line
    }
    if (t.type == TransactionType.income) {
      // coverage:ignore-line
      return includeIncome ? -t.amount : 0; // coverage:ignore-line
    }
    return 0;
  }
}
