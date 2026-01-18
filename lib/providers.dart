import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'services/storage_service.dart';
import 'utils/network_utils.dart';
import 'utils/debug_logger.dart';
import 'services/loan_service.dart';
import 'models/account.dart';
import 'models/transaction.dart';
import 'models/loan.dart';
import 'models/recurring_transaction.dart';
import 'models/category.dart';
import 'models/profile.dart';

import 'services/auth_service.dart';
import 'services/file_service.dart';
import 'services/firebase_web_safe.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'firebase_options.dart' as prod;
import 'firebase_options_debug.dart' as dev;

class LocalModeNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  set value(bool v) => state = v;
}

final localModeProvider =
    NotifierProvider<LocalModeNotifier, bool>(LocalModeNotifier.new);

// --- Service Providers ---

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

final storageInitializerProvider = FutureProvider<void>((ref) async {
  // Initialize Hive & Register Adapters (Moved from main.dart to unblock UI)
  DebugLogger().log("StorageInit: Starting Hive Initialization...");
  try {
    await Hive.initFlutter();

    // Register Adapters
    Hive.registerAdapter(AccountAdapter());
    Hive.registerAdapter(AccountTypeAdapter());
    Hive.registerAdapter(TransactionAdapter());
    Hive.registerAdapter(TransactionTypeAdapter());
    Hive.registerAdapter(LoanAdapter());
    Hive.registerAdapter(LoanTransactionAdapter());
    Hive.registerAdapter(LoanTransactionTypeAdapter());
    Hive.registerAdapter(LoanTypeAdapter());
    Hive.registerAdapter(RecurringTransactionAdapter());
    Hive.registerAdapter(FrequencyAdapter());
    Hive.registerAdapter(ScheduleTypeAdapter());
    Hive.registerAdapter(CategoryAdapter());
    Hive.registerAdapter(CategoryUsageAdapter());
    Hive.registerAdapter(CategoryTagAdapter());
    Hive.registerAdapter(ProfileAdapter());

    // Open specialized boxes
    await Hive.openBox('sum_tracker');

    final storage = ref.watch(storageServiceProvider);
    await storage.init();
    DebugLogger()
        .log("StorageInit: Hive Initialized & Boxes Opened Successfully.");
  } catch (e) {
    DebugLogger().log("StorageInit Error: $e");
    debugPrint("Hive/Storage Init Failed: $e");
    rethrow; // Propagate to AuthWrapper UI
  }
});
final loanServiceProvider = Provider<LoanService>((ref) {
  return LoanService();
});
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final authStreamProvider = StreamProvider<User?>((ref) {
  // Dependency: Wait for Firebase Init to complete
  final init = ref.watch(firebaseInitializerProvider);

  return init.when(
    data: (_) {
      final authService = ref.watch(authServiceProvider);
      return authService.authStateChanges;
    },
    loading: () => Stream.value(null),
    error: (_, __) {
      // If init failed (Offline), DO NOT instantiate AuthService (it crashes without Firebase).
      // Return null user stream. The UI will handle "Offline Login" or "Local Mode".
      DebugLogger().log(
          "AuthStream: Firebase Init failed (Offline?). Returning null stream.");
      return Stream.value(null);
    },
  );
});

final fileServiceProvider = Provider<FileService>((ref) {
  return FileService();
});

final firebaseInitializerProvider = FutureProvider<void>((ref) async {
  // Check connectivity first to avoid hanging on init if offline (Lazy Load)
  DebugLogger().log("FirebaseInit: Checking Connectivity...");
  if (await NetworkUtils.isOffline()) {
    DebugLogger().log("FirebaseInit: Offline Detected. Skipping Init.");
    debugPrint("Offline: Skipping Firebase Init (Lazy Load)");
    throw Exception("Offline Mode");
  }

  // CRITICAL: iOS PWA Offline Safety Check
  // Even if NetworkUtils says we are online (or fails to detect offline),
  // if the actual JS scripts failed to load (404), calling initializeApp will CRASH.
  if (kIsWeb) {
    // Import manually or use dynamic if import cycle, but we have the file.
    if (!FirebaseWebSafe.isFirebaseJsAvailable) {
      DebugLogger()
          .log("FirebaseInit: JS SDK Missing. Aborting Init (iOS Safety).");
      throw Exception("Firebase JS SDK Missing (Offline Safe Mode)");
    }
  }

  DebugLogger().log("FirebaseInit: Starting Firebase.initializeApp...");
  try {
    await Firebase.initializeApp(
      options: kDebugMode
          ? dev.DefaultFirebaseOptions.currentPlatform
          : prod.DefaultFirebaseOptions.currentPlatform,
    ).timeout(
        const Duration(seconds: 10)); // Increased to 10s for better reliability

    // Finalize Redirect session if applicable
    DebugLogger().log("FirebaseInit: Handling Redirect Result...");
    await ref.read(authServiceProvider).handleRedirectResult();

    DebugLogger().log("FirebaseInit: Initialization Complete.");
  } catch (e) {
    DebugLogger().log("FirebaseInit Error: $e");
    debugPrint("Firebase Init Failed: $e");
    rethrow;
  }
});

// --- Profile Providers ---

class ProfileNotifier extends Notifier<String> {
  @override
  String build() {
    final init = ref.watch(storageInitializerProvider);
    if (!init.hasValue) return 'default'; // Safe default until Hive is ready

    final storage = ref.watch(storageServiceProvider);
    return storage.getActiveProfileId();
  }

  Future<void> setProfile(String id) async {
    final storage = ref.read(storageServiceProvider);
    await storage.setActiveProfileId(id);
    state = id;
  }
}

final activeProfileIdProvider =
    NotifierProvider<ProfileNotifier, String>(ProfileNotifier.new);

final profilesProvider = FutureProvider<List<Profile>>((ref) async {
  final storage = ref.watch(storageServiceProvider);
  // Re-fetch when activeProfileId changes if needed, but profiles are global
  return storage.getProfiles();
});

final activeProfileProvider = Provider<Profile?>((ref) {
  final id = ref.watch(activeProfileIdProvider);
  final profiles = ref.watch(profilesProvider).value ?? [];
  final matches = profiles.where((p) => p.id == id);
  if (matches.isNotEmpty) return matches.first;
  return profiles.isNotEmpty ? profiles.first : null;
});

// --- Data Providers (Profile Aware) ---

final accountsProvider = FutureProvider<List<Account>>((ref) async {
  // CRITICAL: Decouple from Firebase Init. Use storageInitializerProvider (Hive) only.
  ref.watch(storageInitializerProvider);
  ref.watch(activeProfileIdProvider);
  final storage = ref.watch(storageServiceProvider);
  return storage.getAccounts();
});

final transactionsProvider = FutureProvider<List<Transaction>>((ref) async {
  ref.watch(storageInitializerProvider);
  ref.watch(activeProfileIdProvider);
  final storage = ref.watch(storageServiceProvider);
  return storage.getTransactions();
});

final loansProvider = FutureProvider<List<Loan>>((ref) async {
  ref.watch(activeProfileIdProvider);
  final storage = ref.watch(storageServiceProvider);
  return storage.getLoans();
});

final recurringTransactionsProvider =
    FutureProvider<List<RecurringTransaction>>((ref) async {
  ref.watch(activeProfileIdProvider);
  final storage = ref.watch(storageServiceProvider);
  return storage.getRecurring();
});

// --- Settings Providers (Profile Aware) ---

class CurrencyNotifier extends Notifier<String> {
  @override
  String build() {
    final init = ref.watch(storageInitializerProvider);
    if (!init.hasValue) return 'en_IN';

    final storage = ref.watch(storageServiceProvider);
    return storage.getCurrencyLocale();
  }

  Future<void> setCurrency(String locale) async {
    state = locale;
    final storage = ref.read(storageServiceProvider);
    await storage.setCurrencyLocale(locale);
  }
}

final currencyProvider =
    NotifierProvider<CurrencyNotifier, String>(CurrencyNotifier.new);

class IsLoggedInNotifier extends Notifier<bool> {
  @override
  bool build() {
    final init = ref.watch(storageInitializerProvider);
    if (!init.hasValue) return false;

    final storage = ref.watch(storageServiceProvider);
    return storage.getAuthFlag();
  }

  Future<void> setLoggedIn(bool value) async {
    final storage = ref.read(storageServiceProvider);
    await storage.setAuthFlag(value);
    state = value;
  }
}

final isLoggedInProvider =
    NotifierProvider<IsLoggedInNotifier, bool>(IsLoggedInNotifier.new);

class BudgetNotifier extends Notifier<double> {
  @override
  double build() {
    final init = ref.watch(storageInitializerProvider);
    if (!init.hasValue) return 0;

    final storage = ref.watch(storageServiceProvider);
    return storage.getMonthlyBudget();
  }

  Future<void> setBudget(double amount) async {
    state = amount;
    final storage = ref.read(storageServiceProvider);
    await storage.setMonthlyBudget(amount);
  }
}

final monthlyBudgetProvider =
    NotifierProvider<BudgetNotifier, double>(BudgetNotifier.new);

class CategoriesNotifier extends Notifier<List<Category>> {
  @override
  List<Category> build() {
    final init = ref.watch(storageInitializerProvider);
    if (!init.hasValue) return [];

    final storage = ref.watch(storageServiceProvider);
    return storage.getCategories();
  }

  Future<void> refresh() async {
    final storage = ref.read(storageServiceProvider);
    state = storage.getCategories();
  }

  Future<void> addCategory(Category category) async {
    final storage = ref.read(storageServiceProvider);
    await storage.addCategory(category);
    state = storage.getCategories();
  }

  Future<void> removeCategory(String id) async {
    final storage = ref.read(storageServiceProvider);
    await storage.removeCategory(id);
    state = storage.getCategories();
  }

  Future<void> updateCategory(String id,
      {required String name,
      required CategoryUsage usage,
      required CategoryTag tag,
      required int iconCode}) async {
    final storage = ref.read(storageServiceProvider);
    await storage.updateCategory(id,
        name: name, usage: usage, tag: tag, iconCode: iconCode);
    state = storage.getCategories();
  }
}

final categoriesProvider = NotifierProvider<CategoriesNotifier, List<Category>>(
    CategoriesNotifier.new);

// --- General Settings ---

class BackupThresholdNotifier extends Notifier<int> {
  @override
  int build() {
    final init = ref.watch(storageInitializerProvider);
    if (!init.hasValue) return 20;

    final storage = ref.watch(storageServiceProvider);
    return storage.getBackupThreshold();
  }

  Future<void> setThreshold(int threshold) async {
    final storage = ref.read(storageServiceProvider);
    await storage.setBackupThreshold(threshold);
    state = threshold;
  }
}

final backupThresholdProvider =
    NotifierProvider<BackupThresholdNotifier, int>(BackupThresholdNotifier.new);

class TxnsSinceBackupNotifier extends Notifier<int> {
  @override
  int build() {
    final init = ref.watch(storageInitializerProvider);
    if (!init.hasValue) return 0;

    final storage = ref.watch(storageServiceProvider);
    return storage.getTxnsSinceBackup();
  }

  void refresh() {
    final storage = ref.read(storageServiceProvider);
    state = storage.getTxnsSinceBackup();
  }

  Future<void> reset() async {
    final storage = ref.read(storageServiceProvider);
    await storage.resetTxnsSinceBackup();
    state = 0;
  }
}

final txnsSinceBackupProvider =
    NotifierProvider<TxnsSinceBackupNotifier, int>(TxnsSinceBackupNotifier.new);

class HolidaysNotifier extends Notifier<List<DateTime>> {
  @override
  List<DateTime> build() {
    final init = ref.watch(storageInitializerProvider);
    if (!init.hasValue) return [];

    final storage = ref.watch(storageServiceProvider);
    return storage.getHolidays();
  }

  Future<void> addHoliday(DateTime date) async {
    final storage = ref.read(storageServiceProvider);
    await storage.addHoliday(date);
    state = storage.getHolidays();
  }

  Future<void> removeHoliday(DateTime date) async {
    final storage = ref.read(storageServiceProvider);
    await storage.removeHoliday(date);
    state = storage.getHolidays();
  }
}

final holidaysProvider =
    NotifierProvider<HolidaysNotifier, List<DateTime>>(HolidaysNotifier.new);

class CurrencyFormatNotifier extends Notifier<bool> {
  @override
  bool build() => true; // true = compact, false = long
  set value(bool v) => state = v;
}

final currencyFormatProvider =
    NotifierProvider<CurrencyFormatNotifier, bool>(CurrencyFormatNotifier.new);
