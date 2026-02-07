import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'providers.dart';
import 'services/firestore_storage_service.dart';
import 'services/cloud_sync_service.dart';
import 'services/excel_service.dart';
import 'services/calendar_service.dart';
import 'services/notification_service.dart';
import 'services/taxes/tax_config_service.dart';

// --- Heavy Service Providers (Moved for Bundle Optimization) ---

final cloudSyncServiceProvider = Provider<CloudSyncService>((ref) {
  final storage = ref.watch(storageServiceProvider);
  final taxConfig = ref.watch(taxConfigServiceProvider);
  final firestoreStorage = FirestoreStorageService();
  return CloudSyncService(firestoreStorage, storage, taxConfig,
      firebaseAuth: FirebaseAuth.instance);
});

final excelServiceProvider = Provider<ExcelService>((ref) {
  final storage = ref.watch(storageServiceProvider);
  final fileService = ref.watch(fileServiceProvider);
  return ExcelService(storage, fileService);
});

final calendarServiceProvider = Provider<CalendarService>((ref) {
  final fileService = ref.watch(fileServiceProvider);
  return CalendarService(fileService);
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return NotificationService(storage);
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
