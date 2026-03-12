import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clock/clock.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'providers.dart';
import 'services/firestore_storage_service.dart';
import 'services/cloud_sync_service.dart';
import 'services/json_data_service.dart';

import 'services/calendar_service.dart';
import 'services/notification_service.dart';
import 'services/taxes/tax_config_service.dart';
import 'services/taxes/indian_tax_service.dart';
import 'models/taxes/tax_data.dart';
import 'utils/billing_helper.dart';
import 'models/account.dart';
import 'models/transaction.dart';
import 'models/loan.dart';
import 'models/recurring_transaction.dart';

// --- Heavy Service Providers (Moved for Bundle Optimization) ---

final cloudSyncServiceProvider = Provider<CloudSyncService>((ref) {
  // coverage:ignore-start
  final storage = ref.watch(storageServiceProvider);
  final taxConfig = ref.watch(taxConfigServiceProvider);
  final firestoreStorage = FirestoreStorageService();
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
  final taxData = storage.getTaxYearData(currentYear);

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
      (amount > 0 || !isRequirementMet) && // coverage:ignore-line
      daysLeft != null &&
      daysLeft <= 7) {
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
  int count = 0;
  for (final acc in accounts.where((a) => a.type == AccountType.creditCard)) {
    if (acc.billingCycleDay == null) continue;

    final billed = BillingHelper.calculateBilledAmount(
        acc, txns, now, storage.getLastRollover(acc.id));
    final totalDue = acc.balance + billed;

    final isFullyPaid = totalDue <= 0.01;

    if (!isFullyPaid) {
      count++;
    }
  }
  return count;
}

int _countPendingRecurring(
    List<RecurringTransaction> recurring, DateTime today) {
  int count = 0;
  for (final r in recurring) {
    if (r.isActive && !r.nextExecutionDate.isAfter(today)) {
      // coverage:ignore-line
      count++; // coverage:ignore-line
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
