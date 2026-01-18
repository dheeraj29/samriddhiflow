import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers.dart';
import 'services/excel_service.dart';
import 'services/firestore_storage_service.dart';
import 'services/cloud_sync_service.dart';
import 'services/calendar_service.dart';
import 'services/notification_service.dart';

// --- Heavy Service Providers (Moved for Bundle Optimization) ---

final cloudSyncServiceProvider = Provider<CloudSyncService>((ref) {
  final storage = ref.watch(storageServiceProvider);
  final firestoreStorage = FirestoreStorageService();
  return CloudSyncService(firestoreStorage, storage);
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
  ThemeMode build() => ThemeMode.system;

  void setThemeMode(ThemeMode mode) {
    state = mode;
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

class CalculatorVisibleNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  set value(bool v) => state = v;
}

final calculatorVisibleProvider =
    NotifierProvider<CalculatorVisibleNotifier, bool>(
        CalculatorVisibleNotifier.new);
