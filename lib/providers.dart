import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'services/storage_service.dart';
import 'utils/network_utils.dart';
import 'utils/debug_logger.dart';
import 'services/loan_service.dart';
import 'package:samriddhi_flow/models/account.dart';
import 'package:samriddhi_flow/models/transaction.dart';
import 'package:samriddhi_flow/models/loan.dart';
import 'package:samriddhi_flow/models/recurring_transaction.dart';
import 'package:samriddhi_flow/models/category.dart';
import 'package:samriddhi_flow/models/profile.dart';
import 'package:samriddhi_flow/models/taxes/insurance_policy.dart';
import 'package:samriddhi_flow/models/taxes/tax_data_models.dart';
import 'package:samriddhi_flow/models/taxes/tax_data.dart';
import 'package:samriddhi_flow/models/taxes/tax_rules.dart';
import 'package:samriddhi_flow/services/taxes/tax_config_service.dart';
import 'package:samriddhi_flow/models/dashboard_config.dart';

import 'services/auth_service.dart';
import 'services/file_service.dart';
import 'services/firebase_web_safe.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'firebase_options.dart' as prod;
import 'firebase_options_debug.dart' as dev;

import 'utils/connectivity_platform.dart';

final isOfflineProvider =
    NotifierProvider<IsOfflineNotifier, bool>(IsOfflineNotifier.new);

final connectivityCheckProvider = Provider<Future<bool> Function()>((ref) {
  return () => NetworkUtils.isOffline();
});

final connectivityStreamProvider =
    StreamProvider<List<ConnectivityResult>>((ref) {
  return Connectivity().onConnectivityChanged;
});

class IsOfflineNotifier extends Notifier<bool> {
  @override
  bool build() {
    bool initial = false;
    if (kIsWeb) {
      initial = ConnectivityPlatform.getInitialWebStatus();

      // Web Native Listeners (Fastest response)
      ConnectivityPlatform.setupWebListeners(ref, (val) => state = val);
    }

    // Continuous Monitoring via Plugin (Platform agnostic fallback)
    final subscription = Connectivity().onConnectivityChanged.listen((results) {
      // On Web, plugin helps catch edge cases or specific interface changes.
      // We combine it with navigator.onLine for maximum accuracy.
      bool reportOffline = !results.any((r) =>
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.ethernet);

      if (kIsWeb) {
        reportOffline = reportOffline || !ConnectivityPlatform.checkWebOnline();
      }
      state = reportOffline;
    });

    ref.onDispose(() => subscription.cancel());

    return initial;
  }
}

class LocalModeNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  set value(bool v) => state = v;
}

final localModeProvider =
    NotifierProvider<LocalModeNotifier, bool>(LocalModeNotifier.new);

class DashboardConfigNotifier extends Notifier<DashboardVisibilityConfig> {
  @override
  DashboardVisibilityConfig build() {
    final storage = ref.read(storageServiceProvider);
    return storage.getDashboardConfig();
  }

  Future<void> updateConfig({bool? showIncomeExpense, bool? showBudget}) async {
    state = state.copyWith(
        showIncomeExpense: showIncomeExpense, showBudget: showBudget);
    await ref.read(storageServiceProvider).saveDashboardConfig(state);
  }
}

final dashboardConfigProvider =
    NotifierProvider<DashboardConfigNotifier, DashboardVisibilityConfig>(
        DashboardConfigNotifier.new);

// --- Service Providers ---

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

// coverage:ignore-start
final storageInitializerProvider = FutureProvider<void>((ref) async {
  // Initialize Hive & Register Adapters (Moved from main.dart to unblock UI)
  DebugLogger().log("StorageInit: Starting Hive Initialization...");
  try {
    await Hive.initFlutter();

    // Register all Adapters using explicit generic types to avoid 'dynamic' registration conflicts
    // and fixed 'unknown type' errors during write.
    // Register all Adapters using explicit generic types to avoid 'dynamic' registration conflicts
    // and fixed 'unknown type' errors during write. We use override: true to ensure
    // that even if an adapter was registered (possibly as dynamic in a previous run),
    // it is now correctly paired with its tight class type.
    Hive.registerAdapter<Account>(AccountAdapter(), override: true);
    Hive.registerAdapter<AccountType>(AccountTypeAdapter(), override: true);
    Hive.registerAdapter<AssetType>(AssetTypeAdapter(), override: true);
    Hive.registerAdapter<BusinessEntity>(BusinessEntityAdapter(),
        override: true);
    Hive.registerAdapter<BusinessType>(BusinessTypeAdapter(), override: true);
    Hive.registerAdapter<CapitalGainEntry>(CapitalGainEntryAdapter(),
        override: true);
    Hive.registerAdapter<Category>(CategoryAdapter(), override: true);
    Hive.registerAdapter<CategoryTag>(CategoryTagAdapter(), override: true);
    Hive.registerAdapter<CategoryUsage>(CategoryUsageAdapter(), override: true);
    Hive.registerAdapter<DividendIncome>(DividendIncomeAdapter(),
        override: true);
    Hive.registerAdapter<Frequency>(FrequencyAdapter(), override: true);
    Hive.registerAdapter<HouseProperty>(HousePropertyAdapter(), override: true);
    Hive.registerAdapter<InsurancePolicy>(InsurancePolicyAdapter(),
        override: true);
    Hive.registerAdapter<InsurancePremiumRule>(InsurancePremiumRuleAdapter(),
        override: true);
    Hive.registerAdapter<Loan>(LoanAdapter(), override: true);
    Hive.registerAdapter<LoanTransaction>(LoanTransactionAdapter(),
        override: true);
    Hive.registerAdapter<LoanTransactionType>(LoanTransactionTypeAdapter(),
        override: true);
    Hive.registerAdapter<LoanType>(LoanTypeAdapter(), override: true);
    Hive.registerAdapter<OtherIncome>(OtherIncomeAdapter(), override: true);
    Hive.registerAdapter<Profile>(ProfileAdapter(), override: true);
    Hive.registerAdapter<RecurringTransaction>(RecurringTransactionAdapter(),
        override: true);
    Hive.registerAdapter<ReinvestmentType>(ReinvestmentTypeAdapter(),
        override: true);
    Hive.registerAdapter<SalaryDetails>(SalaryDetailsAdapter(), override: true);
    Hive.registerAdapter<ScheduleType>(ScheduleTypeAdapter(), override: true);
    Hive.registerAdapter<TaxExemptionRule>(TaxExemptionRuleAdapter(),
        override: true);
    Hive.registerAdapter<TaxMappingRule>(TaxMappingRuleAdapter(),
        override: true);
    Hive.registerAdapter<TaxPaymentEntry>(TaxPaymentEntryAdapter(),
        override: true);
    Hive.registerAdapter<TaxRules>(TaxRulesAdapter(), override: true);
    Hive.registerAdapter<TaxSlab>(TaxSlabAdapter(), override: true);
    Hive.registerAdapter<Transaction>(TransactionAdapter(), override: true);
    Hive.registerAdapter<TransactionType>(TransactionTypeAdapter(),
        override: true);
    Hive.registerAdapter<PayoutFrequency>(PayoutFrequencyAdapter(),
        override: true);
    Hive.registerAdapter<SalaryStructure>(SalaryStructureAdapter(),
        override: true);
    Hive.registerAdapter<CustomAllowance>(CustomAllowanceAdapter(),
        override: true);
    Hive.registerAdapter<TaxYearData>(TaxYearDataAdapter(), override: true);

    // Open specialized boxes
    await Hive.openBox('sum_tracker');

    final storage = ref.watch(storageServiceProvider);
    await storage.init();

    final taxConfig = ref.read(taxConfigServiceProvider);
    await taxConfig.init();

    // Recalculate CC Balances to handle Cycle Rollovers on restart
    await storage.recalculateCCBalances();

    DebugLogger()
        .log("StorageInit: Hive Initialized & Boxes Opened Successfully.");
  } catch (e) {
    DebugLogger().log("StorageInit Error: $e");
    debugPrint("Hive/Storage Init Failed: $e");
    rethrow; // Propagate to AuthWrapper UI
  }
});
// coverage:ignore-end

final loanServiceProvider = Provider<LoanService>((ref) {
  return LoanService();
});
final authServiceProvider = Provider<AuthService>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return AuthService(FirebaseAuth.instance, storage);
});

class LogoutRequestedNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  set value(bool v) => state = v;
}

final logoutRequestedProvider = NotifierProvider<LogoutRequestedNotifier, bool>(
    LogoutRequestedNotifier.new);

// coverage:ignore-start
final authStreamProvider = StreamProvider<User?>((ref) {
  // Dependency: Wait for Firebase Init to settle
  // By watching the future value, we ensure we only react when init transitions
  final init = ref.watch(firebaseInitializerProvider);

  return init.when(
    data: (_) {
      final authService = ref.watch(authServiceProvider);
      final isLoggingOut = ref.watch(logoutRequestedProvider);

      // FORCE NULL if logout is explicitly requested (Synchronous Snap)
      if (isLoggingOut) {
        return Stream.value(null);
      }

      return authService.authStateChanges;
    },
    // If we are still initializing (loading), return an empty stream
    // to prevent the UI from prematurely deciding there is no user.
    loading: () => const Stream.empty(),
    error: (e, __) {
      DebugLogger().log("AuthStream: Firebase Init Error ($e). Staying idle.");
      return const Stream.empty();
    },
  );
});
// coverage:ignore-end

final fileServiceProvider = Provider<FileService>((ref) {
  return FileService();
});

// coverage:ignore-start
final firebaseInitializerProvider = FutureProvider<void>((ref) async {
  // 1. Connectivity Check
  DebugLogger().log("FirebaseInit: Checking Connectivity...");
  if (await NetworkUtils.isOffline()) {
    DebugLogger().log("FirebaseInit: Offline Detected. Skipping Init.");
    return;
  }

  // 2. Reachability Check (DNS/iOS Transition safety)
  // We try up to 3 times to see if DNS has settled.
  bool reachable = false;
  for (int i = 0; i < 3; i++) {
    if (await NetworkUtils.hasActualInternet()) {
      reachable = true;
      break;
    }
    DebugLogger().log(
        "FirebaseInit: Reachability attempt ${i + 1} failed. DNS settling?");
    await Future.delayed(Duration(seconds: 1 + i));
  }

  if (!reachable) {
    DebugLogger().log("FirebaseInit: Actual internet not reachable. Aborting.");
    throw Exception("Internet reached a timeout (DNS/Reachability issue).");
  }

  // 3. iOS PWA Offline Safety Check
  if (kIsWeb && !FirebaseWebSafe.isFirebaseJsAvailable) {
    DebugLogger().log("FirebaseInit: JS SDK Missing. Aborting Init.");
    throw Exception("Firebase JS SDK Missing (Offline Safe Mode)");
  }

  // 4. Initialization with Retry Loop
  int attempts = 0;
  const maxAttempts = 3;

  while (attempts < maxAttempts) {
    try {
      attempts++;
      DebugLogger().log(
          "FirebaseInit: Starting Firebase.initializeApp (Attempt $attempts)...");

      // We use a progressive timeout: 20s, 40s, 60s
      await Firebase.initializeApp(
        options: kDebugMode
            ? dev.DefaultFirebaseOptions.currentPlatform
            : prod.DefaultFirebaseOptions.currentPlatform,
      ).timeout(Duration(seconds: 20 * attempts));

      // Handling Redirect Result
      DebugLogger().log("FirebaseInit: Handling Redirect Result...");
      await ref.read(authServiceProvider).handleRedirectResult(ref);

      DebugLogger().log("FirebaseInit: Initialization Complete.");
      return;
    } catch (e) {
      final isTimeout = e.toString().toLowerCase().contains("timeout");
      DebugLogger().log("FirebaseInit: Attempt $attempts failed ($e).");

      if (attempts >= maxAttempts) {
        if (isTimeout) {
          throw Exception(
              "Firebase initialization timed out after $maxAttempts attempts.");
        }
        rethrow;
      }

      // Wait before next attempt (Exponential-ish backoff)
      await Future.delayed(Duration(seconds: 2 * attempts));
    }
  }
});
// coverage:ignore-end

// --- Profile Providers ---

class ProfileNotifier extends Notifier<String> {
  @override
  String build() {
    // Watch the profile ID from settings box reactively
    final profileIdStream = ref.watch(activeProfileIdHiveStreamProvider);

    return profileIdStream.maybeWhen(
      data: (id) => id,
      orElse: () {
        final init = ref.watch(storageInitializerProvider);
        if (!init.hasValue) return 'default';
        final storage = ref.watch(storageServiceProvider);
        return storage.getActiveProfileId();
      },
    );
  }

  Future<void> setProfile(String id) async {
    final storage = ref.read(storageServiceProvider);
    await storage.setActiveProfileId(id);
    state = id;
  }
}

/// Reactive stream that monitors the Hive 'activeProfileId' key directly.
final activeProfileIdHiveStreamProvider = StreamProvider<String>((ref) async* {
  await ref.watch(storageInitializerProvider.future);
  final box = Hive.box('settings');
  yield box.get('activeProfileId', defaultValue: 'default') as String;
  yield* box
      .watch(key: 'activeProfileId')
      .map((event) => (event.value as String?) ?? 'default');
});

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

// --- Data Providers (Profile Aware - Reactive) ---

final accountsProvider = StreamProvider<List<Account>>((ref) async* {
  // Wait for Hive
  await ref.watch(storageInitializerProvider.future);
  ref.watch(activeProfileIdProvider);
  final storage = ref.watch(storageServiceProvider);

  // Trigger CC Rollovers (profile agnostic)
  storage.checkCreditCardRollovers();

  final box = Hive.box<Account>('accounts');

  // Initial fetch
  yield storage.getAccounts();

  // Watch for any changes in the accounts box
  yield* box
      .watch()
      .map((_) => storage.getAccounts().whereType<Account>().toList());
});

final transactionsProvider = StreamProvider<List<Transaction>>((ref) async* {
  // Wait for Hive
  await ref.watch(storageInitializerProvider.future);
  ref.watch(activeProfileIdProvider);
  final storage = ref.watch(storageServiceProvider);

  final box = Hive.box<Transaction>('transactions');

  // Initial fetch
  yield storage.getTransactions();

  // Watch for any changes in the transactions box
  yield* box
      .watch()
      .map((_) => storage.getTransactions().whereType<Transaction>().toList());
});

final loansProvider = StreamProvider<List<Loan>>((ref) async* {
  await ref.watch(storageInitializerProvider.future);
  final storage = ref.watch(storageServiceProvider);
  final box = Hive.box<Loan>('loans');

  yield storage.getLoans();
  yield* box.watch().map((_) => storage.getLoans());
});

final recurringTransactionsProvider =
    StreamProvider<List<RecurringTransaction>>((ref) async* {
  await ref.watch(storageInitializerProvider.future);
  final storage = ref.watch(storageServiceProvider);
  final box = Hive.box<RecurringTransaction>('recurring');

  yield storage.getRecurring();
  yield* box.watch().map((_) => storage.getRecurring());
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
    // Watch the low-level Hive stream
    final hiveStatus = ref.watch(isLoggedInHiveStreamProvider);

    return hiveStatus.maybeWhen(
      data: (val) => val,
      orElse: () {
        // Fallback to direct read if stream hasn't emitted yet but Hive is ready
        final init = ref.watch(storageInitializerProvider);
        if (!init.hasValue) return false;
        final storage = ref.watch(storageServiceProvider);
        return storage.getAuthFlag();
      },
    );
  }

  Future<void> setLoggedIn(bool value) async {
    final storage = ref.read(storageServiceProvider);
    await storage.setAuthFlag(value);
    state = value;
  }
}

/// Reactive stream that monitors the Hive 'isLoggedIn' key directly.
final isLoggedInHiveStreamProvider = StreamProvider<bool>((ref) async* {
  // Wait for Hive to be initialized
  await ref.watch(storageInitializerProvider.future);

  final box = Hive.box('settings');

  // 1. Yield initial value
  yield box.get('isLoggedIn', defaultValue: false) as bool;

  // 2. Yield changes
  yield* box
      .watch(key: 'isLoggedIn')
      .map((event) => (event.value as bool?) ?? false);
});

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
    // Watch activeProfileId to ensure we refresh when switching profiles
    ref.watch(activeProfileIdProvider);
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

class AppLockIntentNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void lock() => state = true;
  void reset() => state = false;
}

final appLockIntentProvider =
    NotifierProvider<AppLockIntentNotifier, bool>(AppLockIntentNotifier.new);

final appLockStatusProvider = Provider<bool>((ref) {
  final init = ref.watch(storageInitializerProvider);
  if (!init.hasValue) return false;
  final storage = ref.watch(storageServiceProvider);
  return storage.isAppLockEnabled() && storage.getAppPin() != null;
});
