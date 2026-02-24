import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'providers.dart';
import 'services/firestore_storage_service.dart';
import 'services/cloud_sync_service.dart';
import 'services/json_data_service.dart';

import 'services/calendar_service.dart';
import 'services/notification_service.dart';
import 'services/taxes/tax_config_service.dart';
import 'utils/billing_helper.dart';
import 'models/account.dart';
import 'models/transaction.dart';
import 'models/loan.dart';

// --- Heavy Service Providers (Moved for Bundle Optimization) ---

final cloudSyncServiceProvider = Provider<CloudSyncService>((ref) {
  final storage = ref.watch(storageServiceProvider);
  final taxConfig = ref.watch(taxConfigServiceProvider);
  final firestoreStorage = FirestoreStorageService();
  return CloudSyncService(firestoreStorage, storage, taxConfig,
      firebaseAuth: FirebaseAuth.instance);
});

final jsonDataServiceProvider = Provider<JsonDataService>((ref) {
  final storage = ref.watch(storageServiceProvider);
  final taxConfig = ref.watch(taxConfigServiceProvider);
  return JsonDataService(storage, taxConfig);
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
  int count = 0;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  // 1. Loans
  final loans = ref.watch(loansProvider).value ?? [];
  for (final loan in loans) {
    if (loan.remainingPrincipal <= 0) continue;

    DateTime dueDateObj = DateTime(today.year, today.month, loan.emiDay);
    if (today.year == loan.firstEmiDate.year &&
        today.month == loan.firstEmiDate.month) {
      dueDateObj = loan.firstEmiDate;
    }

    // If due date is past, check payment
    // We strictly check if "Bill is generated" (i.e. we are in the month of due date or past it)
    // Actually, simple logic: Is there an EMI due that isn't paid?
    // User wants "New bill available".

    // Let's count if checking date >= due date AND not paid.
    // Or closer: if we are within X days of due date?
    // User said "Pending or New Bill Is Available".
    // "New Bill" usually implies the cycle has hit.

    // Logic from RemindersScreen:
    final checkDate = dueDateObj;
    final payments = loan.transactions
        .where((t) =>
            t.type == LoanTransactionType.emi &&
            t.date.year == checkDate.year &&
            t.date.month == checkDate.month)
        .toList();
    final totalPaid = payments.fold(0.0, (sum, t) => sum + t.amount);
    final isFullyPaid = totalPaid >= loan.emiAmount - 1;

    // Condition: today is ON or AFTER the due date month?
    // Usually loan bills are known in advance.
    // Let's say if today is within 5 days before due date OR after due date, and not paid.
    // Or simpler: If not paid, and we are in the due month.

    // RemindersScreen shows it if active.
    // Let's alert if: Overdue OR Due within 7 days.
    bool specificCondition = false;
    if (!isFullyPaid) {
      final daysToDue = dueDateObj.difference(today).inDays;
      if (daysToDue <= 7) specificCondition = true; // Due soon or overdue
    }
    if (specificCondition) count++;
  }

  // 2. Credit Cards
  final accounts = ref.watch(accountsProvider).value ?? [];
  final txns = ref.watch(transactionsProvider).value ?? [];
  final storage = ref.watch(storageServiceProvider);

  for (final acc in accounts.where((a) => a.type == AccountType.creditCard)) {
    if (acc.billingCycleDay == null) continue;

    // Check if bill generated
    // Bill generated if today > billingCycleDay (of this month) or we passed it last month
    // Logic from RemindersScreen:
    final lastBillDate = today.day > acc.billingCycleDay!
        ? DateTime(today.year, today.month, acc.billingCycleDay!)
        : DateTime(today.year, today.month - 1, acc.billingCycleDay!);

    // If bill generated, is it paid?
    final billed = BillingHelper.calculateBilledAmount(
        acc, txns, now, storage.getLastRollover(acc.id));
    final totalDue =
        acc.balance + billed; // Approximation from RemindersScreen logic

    // Check payments since bill date
    final payments = txns
        .where((t) =>
            !t.isDeleted &&
            t.toAccountId == acc.id &&
            t.type == TransactionType.transfer &&
            t.date.isAfter(lastBillDate.subtract(const Duration(days: 1))))
        .toList();
    final totalPaid = payments.fold(0.0, (sum, t) => sum + t.amount);

    final isFullyPaid =
        totalDue <= 0.01 || (totalDue > 0 && totalPaid >= totalDue);

    if (!isFullyPaid) {
      count++;
    }
  }

  // 3. Recurring
  final recurring = ref.watch(recurringTransactionsProvider).value ?? [];
  for (final r in recurring) {
    if (r.isActive && !r.nextExecutionDate.isAfter(today)) {
      // Due today or in past
      count++;
    }
  }

  return count;
});

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final init = ref.watch(storageInitializerProvider);
    if (!init.hasValue) return ThemeMode.system;

    final storage = ref.watch(storageServiceProvider);
    final saved = storage.getThemeMode();
    return ThemeMode.values.firstWhere(
      (m) => m.name == saved,
      orElse: () => ThemeMode.system,
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
