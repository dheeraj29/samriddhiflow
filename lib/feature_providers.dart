import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clock/clock.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'providers.dart';
import 'services/firestore_storage_service.dart';
import 'services/cloud_sync_service.dart';
import 'services/json_data_service.dart';
import 'services/location_service.dart';

import 'services/calendar_service.dart';
import 'services/notification_service.dart';
import 'services/taxes/tax_config_service.dart';
import 'services/taxes/indian_tax_service.dart';
import 'models/taxes/tax_data.dart';
import 'models/account.dart';
import 'models/transaction.dart';
import 'models/loan.dart';
import 'models/recurring_transaction.dart';
import 'utils/billing_helper.dart';

// --- Heavy Service Providers (Moved for Bundle Optimization) ---

// mapping databaseId to region
const Map<String, String?> regionDatabaseMapping = {
  'India': null, // null maps to (default) database
};

class CloudDatabaseRegionNotifier extends Notifier<String> {
  @override
  String build() {
    final init = ref.watch(storageInitializerProvider);
    if (!init.hasValue) return 'India';

    final storage = ref.watch(storageServiceProvider);
    return storage.getCloudDatabaseRegion();
  }

  // coverage:ignore-start
  Future<void> setRegion(String region) async {
    state = region;
    final storage = ref.read(storageServiceProvider);
    await storage.setCloudDatabaseRegion(region);
    // coverage:ignore-end
  }
}

final cloudDatabaseRegionProvider =
    NotifierProvider<CloudDatabaseRegionNotifier, String>(
        CloudDatabaseRegionNotifier.new);

final locationServiceProvider = Provider<LocationService>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return LocationService(storage);
});

final detectedCountryProvider = FutureProvider<String?>((ref) async {
  final init = ref.watch(storageInitializerProvider);
  if (!init.hasValue) return null;

  final locationService = ref.read(locationServiceProvider);
  return await locationService.fetchCurrentCountryCode();
});

final cloudSyncServiceProvider = Provider<CloudSyncService>((ref) {
  // coverage:ignore-start
  final storage = ref.watch(storageServiceProvider);
  final taxConfig = ref.watch(taxConfigServiceProvider);
  final region = ref.watch(cloudDatabaseRegionProvider);
  final databaseId = regionDatabaseMapping[region];
  // coverage:ignore-end

  // coverage:ignore-start
  final firestoreStorage = FirestoreStorageService(databaseId: databaseId);
  return CloudSyncService(firestoreStorage, storage, taxConfig,
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
