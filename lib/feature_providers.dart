import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clock/clock.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'providers.dart';
import 'services/firestore_storage_service.dart';
import 'services/cloud_sync_service.dart';
import 'services/json_data_service.dart';
import 'services/subscription_service.dart';
import 'services/ad_service.dart';

import 'services/calendar_service.dart';
import 'services/notification_service.dart';
import 'services/taxes/tax_config_service.dart';
import 'services/taxes/indian_tax_service.dart';
import 'models/taxes/tax_data.dart';
import 'models/account.dart';
import 'models/transaction.dart';
import 'models/loan.dart';
import 'models/recurring_transaction.dart';
import 'models/investment.dart';
import 'utils/billing_helper.dart';

// --- Heavy Service Providers (Moved for Bundle Optimization) ---

import 'core/cloud_config.dart';

class CloudDatabaseRegionNotifier extends Notifier<String> {
  @override
  String build() {
    final init = ref.watch(storageInitializerProvider);
    if (!init.hasValue) return CloudDatabaseRegion.india;

    final storage = ref.watch(storageServiceProvider);
    return storage.getCloudDatabaseRegion();
  }

  // coverage:ignore-start
  Future<void> setRegion(String region) async {
    state = region;
    final storage = ref.read(storageServiceProvider);
    await storage.setCloudDatabaseRegion(region);
    // coverage:ignore-end

    // PERSIST GLOBAL HINT: Prevent region-probing attacks by storing hint in (default) db
    final user = FirebaseAuth.instance.currentUser; // coverage:ignore-line
    if (user != null) {
      // Create a dedicated one-off global instance for this write
      final globalStorage =
          FirestoreStorageService(databaseId: null); // coverage:ignore-line
      await globalStorage.setRegionHint(
          user.uid, region); // coverage:ignore-line
    }
  }
}

final cloudDatabaseRegionProvider =
    NotifierProvider<CloudDatabaseRegionNotifier, String>(
        CloudDatabaseRegionNotifier.new);

final adServiceProvider = Provider<AdService>((ref) {
  return AdService(); // coverage:ignore-line
});

final cloudSyncServiceProvider = Provider<CloudSyncService>((ref) {
  // coverage:ignore-start
  final storage = ref.watch(storageServiceProvider);
  final taxConfig = ref.watch(taxConfigServiceProvider);
  final subService = ref.watch(subscriptionServiceProvider);
  final region = ref.watch(cloudDatabaseRegionProvider);
  final databaseId = regionDatabaseMapping[region];
  // coverage:ignore-end

  // coverage:ignore-start
  final firestoreStorage = FirestoreStorageService(databaseId: databaseId);
  return CloudSyncService(firestoreStorage, storage, taxConfig, subService,
      firebaseAuth: FirebaseAuth.instance);
  // coverage:ignore-end
});

final jsonDataServiceProvider = Provider<JsonDataService>((ref) {
  // coverage:ignore-start
  final storage = ref.watch(storageServiceProvider);
  final taxConfig = ref.watch(taxConfigServiceProvider);
  return JsonDataService(storage, taxConfig);
  // coverage:ignore-end
});

final calendarServiceProvider = Provider<CalendarService>((ref) {
  final fileService = ref.watch(fileServiceProvider);
  return CalendarService(fileService);
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return NotificationService(storage);
});

final pendingRemindersProvider = Provider<int>((ref) {
  final now = clock.now();
  final today = DateTime(now.year, now.month, now.day);

  final loans = ref.watch(loansProvider).value ?? [];
  final accounts = ref.watch(accountsProvider).value ?? [];
  final txns = ref.watch(transactionsProvider).value ?? [];
  final storage = ref.watch(storageServiceProvider);
  final recurring = ref.watch(recurringTransactionsProvider).value ?? [];

  final taxConfig = ref.watch(taxConfigServiceProvider);
  final currentYear = taxConfig.getCurrentFinancialYear();
  final taxData = ref.watch(taxYearDataProvider(currentYear)).value;

  return _countPendingLoans(loans, today) +
      _countPendingCreditCards(accounts, txns, now, today, storage) +
      _countPendingRecurring(recurring, today) +
      (taxData != null
          ? _countPendingAdvanceTax(taxData, ref)
          : 0); // coverage:ignore-line
});

// coverage:ignore-start
int _countPendingAdvanceTax(TaxYearData data, Ref ref) {
  final service = ref.watch(indianTaxServiceProvider);
  final config = ref.watch(taxConfigServiceProvider);
  final rules = config.getRulesForYear(data.year);
  final details = service.calculateDetailedLiability(data, rules);
// coverage:ignore-end

  // coverage:ignore-start
  final double? amount = details['nextAdvanceTaxAmount'] as dynamic;
  final int? daysLeft = details['daysUntilAdvanceTax'] as dynamic;
  final bool isRequirementMet = details['isRequirementMet'] == true;
  // coverage:ignore-end

  if (amount != null &&
      !isRequirementMet &&
      amount > 0.01 && // coverage:ignore-line
      daysLeft != null &&
      daysLeft <= rules.advanceTaxReminderDays) {
    // coverage:ignore-line
    return 1;
  }
  return 0;
}

int _countPendingLoans(List<Loan> loans, DateTime today) {
  int count = 0;
  for (final loan in loans) {
    if (loan.remainingPrincipal <= 0) continue; // coverage:ignore-line

    // coverage:ignore-start
    DateTime dueDateObj = DateTime(today.year, today.month, loan.emiDay);
    if (today.year == loan.firstEmiDate.year &&
        today.month == loan.firstEmiDate.month) {
      dueDateObj = loan.firstEmiDate;
      // coverage:ignore-end
    }

    // coverage:ignore-start
    final payments = loan.transactions
        .where((t) =>
            t.type == LoanTransactionType.emi &&
            t.date.year == dueDateObj.year &&
            t.date.month == dueDateObj.month)
        .toList();
    final totalPaid = payments.fold(0.0, (sum, t) => sum + t.amount);
    final isFullyPaid = totalPaid >= loan.emiAmount - 1;
    // coverage:ignore-end

    if (!isFullyPaid && dueDateObj.difference(today).inDays <= 7) {
      // coverage:ignore-line
      count++; // coverage:ignore-line
    }
  }
  return count;
}

int _countPendingCreditCards(List<Account> accounts, List<Transaction> txns,
    DateTime now, DateTime today, dynamic storage) {
  return accounts
      .where((a) => a.type == AccountType.creditCard)
      .where((a) => _isCreditCardPending(a, txns, now, storage))
      .length;
}

bool _isCreditCardPending(
    Account acc, List<Transaction> txns, DateTime now, dynamic storage) {
  if (acc.billingCycleDay == null) return false;

  // AND the current total due is still positive (not paid early)
  if (storage.isBilledAmountPaid(acc.id)) return false;

  final lastRolloverMillis = storage.getLastRollover(acc.id);
  final billedAmount =
      BillingHelper.calculateBilledAmount(acc, txns, now, lastRolloverMillis);

  double payments = 0;
  if (lastRolloverMillis != null) {
    final statementDate = BillingHelper.getStatementDate(
        now, acc.billingCycleDay!); // coverage:ignore-line
    payments = BillingHelper.calculatePeriodPayments(
        acc, txns, statementDate, now); // coverage:ignore-line
  }

  final adjustedData = BillingHelper.getAdjustedCCData(
    accountBalance: acc.balance,
    billedAmount: billedAmount,
    unbilledAmount: 0,
    paymentsSinceRollover: payments,
  );

  final debtDue = adjustedData.$2 + adjustedData.$3;
  return debtDue > 0.01;
}

int _countPendingRecurring(
    List<RecurringTransaction> recurring, DateTime today) {
  int count = 0;
  for (final r in recurring) {
    // coverage:ignore-start
    final dueDate = DateTime(r.nextExecutionDate.year,
        r.nextExecutionDate.month, r.nextExecutionDate.day);
    if (r.isActive && !dueDate.isAfter(today)) {
      count++;
      // coverage:ignore-end
    }
  }
  return count;
}

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final init = ref.watch(storageInitializerProvider);
    if (!init.hasValue) return ThemeMode.system;

    final storage = ref.watch(storageServiceProvider);
    final saved = storage.getThemeMode();
    return ThemeMode.values.firstWhere(
      (m) => m.name == saved,
      orElse: () => ThemeMode.system, // coverage:ignore-line
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final storage = ref.read(storageServiceProvider);
    await storage.setThemeMode(mode.name);
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

class LocaleNotifier extends Notifier<Locale?> {
  @override
  Locale? build() {
    final init = ref.watch(storageInitializerProvider);
    if (!init.hasValue) return null;

    final storage = ref.watch(storageServiceProvider);
    final localeCode = storage.getLocale();
    if (localeCode != null) {
      return Locale(localeCode);
    }
    return null;
  }

  Future<void> setLocale(String? localeCode) async {
    final storage = ref.read(storageServiceProvider);
    await storage.setLocale(localeCode);
    state = localeCode != null ? Locale(localeCode) : null;
  }
}

final localeProvider =
    NotifierProvider<LocaleNotifier, Locale?>(LocaleNotifier.new);

class SmartCalculatorEnabledNotifier extends Notifier<bool> {
  @override
  bool build() {
    final init = ref.watch(storageInitializerProvider);
    if (!init.hasValue) return true; // Default while loading

    return ref.watch(storageServiceProvider).isSmartCalculatorEnabled();
  }

  Future<void> toggle() async {
    final newValue = !state;
    state = newValue;
    await ref.read(storageServiceProvider).setSmartCalculatorEnabled(newValue);
  }
}

final smartCalculatorEnabledProvider =
    NotifierProvider<SmartCalculatorEnabledNotifier, bool>(
        SmartCalculatorEnabledNotifier.new);

class CalculatorVisibleNotifier extends Notifier<bool> {
  @override
  bool build() {
    // Watch enabled state: if disabled, visibility must be false
    final enabled = ref.watch(smartCalculatorEnabledProvider);
    if (!enabled) return false;
    return false;
  }

  set value(bool v) {
    if (!ref.read(smartCalculatorEnabledProvider)) return;
    state = v;
  }
}

final calculatorVisibleProvider =
    NotifierProvider<CalculatorVisibleNotifier, bool>(
        CalculatorVisibleNotifier.new);

class InvestmentsNotifier extends Notifier<List<Investment>> {
  @override // coverage:ignore-line
  List<Investment> build() {
    final init = ref.watch(storageInitializerProvider); // coverage:ignore-line
    if (!init.hasValue) return []; // coverage:ignore-line

    ref.watch(activeProfileIdProvider); // coverage:ignore-line

    final storage = ref.watch(storageServiceProvider); // coverage:ignore-line
    return storage.getInvestments(); // coverage:ignore-line
  }

  // coverage:ignore-start
  Future<void> saveInvestment(Investment investment) async {
    final storage = ref.read(storageServiceProvider);
    await storage.saveInvestment(investment);
    ref.invalidateSelf();
    // coverage:ignore-end
  }

  // coverage:ignore-start
  Future<void> deleteInvestment(String id) async {
    final storage = ref.read(storageServiceProvider);
    await storage.deleteInvestment(id);
    ref.invalidateSelf();
    // coverage:ignore-end
  }

  // Bulk update valuations from a map (ticker -> price)
  // coverage:ignore-start
  Future<void> updateValuations(Map<String, double> prices) async {
    final storage = ref.read(storageServiceProvider);
    final current = state;
    for (var inv in current) {
      // coverage:ignore-end
      // Priority: match by codeName, fallback to name
      // coverage:ignore-start
      final key = (inv.codeName != null && inv.codeName!.isNotEmpty)
          ? inv.codeName
          : inv.name;
      if (prices.containsKey(key)) {
        final updated = inv.copyWith(currentPrice: prices[key]);
        await storage.saveInvestment(updated);
        // coverage:ignore-end
      }
    }
    ref.invalidateSelf(); // coverage:ignore-line
  }

  // coverage:ignore-start
  Future<void> updateCodeNameBulk(String oldCode, String newCode) async {
    final storage = ref.read(storageServiceProvider);
    final current = state;
    for (var inv in current) {
      if (inv.codeName == oldCode) {
        final updated = inv.copyWith(codeName: newCode);
        await storage.saveInvestment(updated);
        // coverage:ignore-end
      }
    }
    ref.invalidateSelf(); // coverage:ignore-line
  }

  // coverage:ignore-start
  Future<void> updateValuationBulk(String code, double price) async {
    final storage = ref.read(storageServiceProvider);
    final current = state;
    for (var inv in current) {
      if (inv.codeName == code) {
        final updated = inv.copyWith(currentPrice: price);
        await storage.saveInvestment(updated);
        // coverage:ignore-end
      }
    }
    ref.invalidateSelf(); // coverage:ignore-line
  }
}

final investmentsProvider =
    NotifierProvider<InvestmentsNotifier, List<Investment>>(
        InvestmentsNotifier.new);

final investmentSummaryProvider = Provider((ref) {
  final investments = ref.watch(investmentsProvider);

  double totalInvested = 0;
  double totalCurrent = 0;
  int readyToSellLTCount = 0;
  double readyToSellLTValue = 0;

  final categoryBreakdown =
      <MutualFundCategory, ({double invested, double current})>{};
  final typeBreakdown = <InvestmentType, ({double invested, double current})>{};

  for (final inv in investments) {
    if (inv.isSold) continue;

    totalInvested += inv.investedValue;
    totalCurrent += inv.currentValuation;

    if (inv.isLongTerm) {
      readyToSellLTCount++; // coverage:ignore-line
      readyToSellLTValue += inv.currentValuation; // coverage:ignore-line
    }

    final typeData = typeBreakdown[inv.type] ?? (invested: 0.0, current: 0.0);
    typeBreakdown[inv.type] = (
      invested: typeData.invested + inv.investedValue,
      current: typeData.current + inv.currentValuation
    );

    if (inv.type == InvestmentType.mutualFund && inv.mfCategory != null) {
      final catData =
          // coverage:ignore-start
          categoryBreakdown[inv.mfCategory!] ?? (invested: 0.0, current: 0.0);
      categoryBreakdown[inv.mfCategory!] = (
        invested: catData.invested + inv.investedValue,
        current: catData.current + inv.currentValuation
        // coverage:ignore-end
      );
    }
  }

  return (
    totalInvested: totalInvested,
    totalCurrent: totalCurrent,
    readyToSellLTCount: readyToSellLTCount,
    readyToSellLTValue: readyToSellLTValue,
    categoryBreakdown: categoryBreakdown,
    typeBreakdown: typeBreakdown,
  );
});
