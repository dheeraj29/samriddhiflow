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
import 'package:samriddhi_flow/models/lending_record.dart';
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
  return () => NetworkUtils.isOffline(); // coverage:ignore-line
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
      initial =
          ConnectivityPlatform.getInitialWebStatus(); // coverage:ignore-line

      // Web Native Listeners (Fastest response)
      ConnectivityPlatform.setupWebListeners( // coverage:ignore-line
          ref, (val) => state = val); // coverage:ignore-line
    }

    // Continuous Monitoring via Plugin (Platform agnostic fallback)
    final subscription = Connectivity().onConnectivityChanged.listen((results) {
      // On Web, plugin helps catch edge cases or specific interface changes.
      // We combine it with navigator.onLine for maximum accuracy.
      // coverage:ignore-start
      bool reportOffline = !results.any((r) =>
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.ethernet);
      // coverage:ignore-end

      if (kIsWeb) {
        reportOffline = reportOffline ||
            !ConnectivityPlatform.checkWebOnline(); // coverage:ignore-line
      }
      state = reportOffline; // coverage:ignore-line
    });

    ref.onDispose(() => subscription.cancel());

    return initial;
  }
}

class LocalModeNotifier extends Notifier<bool> {
  @override // coverage:ignore-line
  bool build() => false;
  set value(bool v) => state = v; // coverage:ignore-line
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

final storageInitializerProvider = FutureProvider<void>((ref) async {
  // Initialize Hive & Register Adapters (Moved from main.dart to unblock UI)
  try {
    await Hive.initFlutter();

    // Register all Adapters using explicit generic types to avoid 'dynamic' registration conflicts
    // and fixed 'unknown type' errors during write.
    // Register all Adapters using explicit generic types to avoid 'dynamic' registration conflicts
    // and fixed 'unknown type' errors during write. We use override: true to ensure
    // that even if an adapter was registered (possibly as dynamic in a previous run),
    // it is now correctly paired with its tight class type.
    // coverage:ignore-start
    Hive.registerAdapter<Account>(AccountAdapter(), override: true);
    Hive.registerAdapter<AccountType>(AccountTypeAdapter(), override: true);
    Hive.registerAdapter<AssetType>(AssetTypeAdapter(), override: true);
    Hive.registerAdapter<BusinessEntity>(BusinessEntityAdapter(),
    // coverage:ignore-end
        override: true);
    Hive.registerAdapter<BusinessType>(BusinessTypeAdapter(), // coverage:ignore-line
        override: true);
    Hive.registerAdapter<CapitalGainEntry>( // coverage:ignore-line
        CapitalGainEntryAdapter(), // coverage:ignore-line
        override: true);
    // coverage:ignore-start
    Hive.registerAdapter<Category>(CategoryAdapter(), override: true);
    Hive.registerAdapter<CategoryTag>(CategoryTagAdapter(), override: true);
    Hive.registerAdapter<CategoryUsage>(CategoryUsageAdapter(), override: true);
    Hive.registerAdapter<DividendIncome>(DividendIncomeAdapter(),
    // coverage:ignore-end
        override: true);
    // coverage:ignore-start
    Hive.registerAdapter<Frequency>(FrequencyAdapter(), override: true);
    Hive.registerAdapter<HouseProperty>(HousePropertyAdapter(), override: true);
    Hive.registerAdapter<InsurancePolicy>(InsurancePolicyAdapter(),
    // coverage:ignore-end
        override: true);
    Hive.registerAdapter<InsurancePremiumRule>( // coverage:ignore-line
        InsurancePremiumRuleAdapter(), // coverage:ignore-line
        override: true);
    // coverage:ignore-start
    Hive.registerAdapter<Loan>(LoanAdapter(), override: true);
    Hive.registerAdapter<LendingRecord>(LendingRecordAdapter(), override: true);
    Hive.registerAdapter<LendingType>(LendingTypeAdapter(), override: true);
    Hive.registerAdapter<LendingPayment>(LendingPaymentAdapter(),
    // coverage:ignore-end
        override: true);
    Hive.registerAdapter<LoanTransaction>(LoanTransactionAdapter(), // coverage:ignore-line
        override: true);
    Hive.registerAdapter<LoanTransactionType>( // coverage:ignore-line
        LoanTransactionTypeAdapter(), // coverage:ignore-line
        override: true);
    // coverage:ignore-start
    Hive.registerAdapter<LoanType>(LoanTypeAdapter(), override: true);
    Hive.registerAdapter<OtherIncome>(OtherIncomeAdapter(), override: true);
    Hive.registerAdapter<Profile>(ProfileAdapter(), override: true);
    Hive.registerAdapter<RecurringTransaction>(RecurringTransactionAdapter(),
    // coverage:ignore-end
        override: true);
    Hive.registerAdapter<ReinvestmentType>( // coverage:ignore-line
        ReinvestmentTypeAdapter(), // coverage:ignore-line
        override: true);
    // coverage:ignore-start
    Hive.registerAdapter<SalaryDetails>(SalaryDetailsAdapter(), override: true);
    Hive.registerAdapter<ScheduleType>(ScheduleTypeAdapter(), override: true);
    Hive.registerAdapter<TaxExemptionRule>(TaxExemptionRuleAdapter(),
    // coverage:ignore-end
        override: true);
    Hive.registerAdapter<TaxMappingRule>( // coverage:ignore-line
        TaxMappingRuleAdapter(), // coverage:ignore-line
        override: true);
    Hive.registerAdapter<TaxPaymentEntry>( // coverage:ignore-line
        TaxPaymentEntryAdapter(), // coverage:ignore-line
        override: true);
    // coverage:ignore-start
    Hive.registerAdapter<TaxRules>(TaxRulesAdapter(), override: true);
    Hive.registerAdapter<TaxSlab>(TaxSlabAdapter(), override: true);
    Hive.registerAdapter<Transaction>(TransactionAdapter(), override: true);
    Hive.registerAdapter<TransactionType>(TransactionTypeAdapter(),
    // coverage:ignore-end
        override: true);
    Hive.registerAdapter<PayoutFrequency>( // coverage:ignore-line
        PayoutFrequencyAdapter(), // coverage:ignore-line
        override: true);
    Hive.registerAdapter<SalaryStructure>( // coverage:ignore-line
        SalaryStructureAdapter(), // coverage:ignore-line
        override: true);
    Hive.registerAdapter<CustomAllowance>( // coverage:ignore-line
        CustomAllowanceAdapter(), // coverage:ignore-line
        override: true);
    Hive.registerAdapter<CustomDeduction>( // coverage:ignore-line
        CustomDeductionAdapter(), // coverage:ignore-line
        override: true);
    Hive.registerAdapter<CustomExemption>( // coverage:ignore-line
        CustomExemptionAdapter(), // coverage:ignore-line
        override: true);
    Hive.registerAdapter<TaxYearData>(TaxYearDataAdapter(), // coverage:ignore-line
        override: true);

    // Open specialized boxes
    await Hive.openBox('sum_tracker'); // coverage:ignore-line

    final storage = ref.watch(storageServiceProvider); // coverage:ignore-line
    await storage.init(); // coverage:ignore-line

    final taxConfig =
        ref.read(taxConfigServiceProvider); // coverage:ignore-line
    await taxConfig.init(); // coverage:ignore-line

    // Recalculate CC Balances to handle Cycle Rollovers on restart
    await storage.recalculateCCBalances(); // coverage:ignore-line
  } catch (e) {
    DebugLogger().log("StorageInit Error: $e"); // coverage:ignore-line
    rethrow; // Propagate to AuthWrapper UI
  }
});

final loanServiceProvider = Provider<LoanService>((ref) {
  return LoanService();
});
final authServiceProvider = Provider<AuthService>((ref) {
  final storage = ref.watch(storageServiceProvider); // coverage:ignore-line
  return AuthService(FirebaseAuth.instance, storage); // coverage:ignore-line
});

class LogoutRequestedNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  set value(bool v) => state = v; // coverage:ignore-line
}

final logoutRequestedProvider = NotifierProvider<LogoutRequestedNotifier, bool>(
    LogoutRequestedNotifier.new);

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
        return Stream.value(null); // coverage:ignore-line
      }

      return authService.authStateChanges;
    },
    // If we are still initializing (loading), return an empty stream
    // to prevent the UI from prematurely deciding there is no user.
    loading: () => const Stream.empty(),
    error: (e, __) => const Stream.empty(), // coverage:ignore-line
  );
});

final fileServiceProvider = Provider<FileService>((ref) {
  return FileService();
});

final firebaseInitializerProvider = FutureProvider<void>((ref) async {
  // 1. Connectivity Check
  if (await NetworkUtils.isOffline()) { // coverage:ignore-line

    return;
  }

  // 2. Reachability Check (DNS/iOS Transition safety)
  // We try up to 3 times to see if DNS has settled.
  bool reachable = false;
  for (int i = 0; i < 3; i++) { // coverage:ignore-line

    if (await NetworkUtils.hasActualInternet()) { // coverage:ignore-line

      reachable = true;
      break;
    }
    await Future.delayed(Duration(seconds: 1 + i)); // coverage:ignore-line
  }

  if (!reachable) {
    throw Exception( // coverage:ignore-line
        "Internet reached a timeout (DNS/Reachability issue).");
  }

  // 3. iOS PWA Offline Safety Check
  if (kIsWeb && !FirebaseWebSafe.isFirebaseJsAvailable) { // coverage:ignore-line

    throw Exception( // coverage:ignore-line
        "Firebase JS SDK Missing (Offline Safe Mode)");
  }

  // 4. Initialization with Retry Loop
  int attempts = 0;
  const maxAttempts = 3;

  while (attempts < maxAttempts) { // coverage:ignore-line

    try {
      attempts++; // coverage:ignore-line

      // We use a progressive timeout: 20s, 40s, 60s
      await Firebase.initializeApp( // coverage:ignore-line

        options: kDebugMode
            // coverage:ignore-start
            ? dev.DefaultFirebaseOptions.currentPlatform
            : prod.DefaultFirebaseOptions.currentPlatform,
      ).timeout(Duration(seconds: 20 * attempts));
            // coverage:ignore-end

      // Handling Redirect Result

      // Check if logout was requested to avoid accidental re-login during redirect processing
      if (!ref.read(logoutRequestedProvider)) { // coverage:ignore-line

        final user = await ref
            .read(authServiceProvider) // coverage:ignore-line
            .handleRedirectResult(); // coverage:ignore-line
        if (user != null) {
          // If a user was successfully recovered from redirect, clear the logout flag
          ref.read(logoutRequestedProvider.notifier).value = // coverage:ignore-line
              false;
        }
      }

      return;
    } catch (e) {
      final isTimeout = e
          // coverage:ignore-start
          .toString()
          .toLowerCase()
          .contains("timeout");
          // coverage:ignore-end

      if (attempts >= maxAttempts) { // coverage:ignore-line

        if (isTimeout) {
          throw Exception( // coverage:ignore-line
              "Firebase initialization timed out after $maxAttempts attempts.");
        }
        // Fix for Web: Stringify exception to avoid interop subtype errors
        throw e.toString(); // coverage:ignore-line
      }

      // Wait before next attempt (Exponential-ish backoff)
      await Future.delayed( // coverage:ignore-line
          Duration(seconds: 2 * attempts)); // coverage:ignore-line
    }
  }
});

// --- Profile Providers ---

class ProfileNotifier extends Notifier<String> {
  @override
  String build() {
    // Watch the profile ID from settings box reactively
    final profileIdStream = ref.watch(activeProfileIdHiveStreamProvider);

    return profileIdStream.maybeWhen(
      data: (id) => id, // coverage:ignore-line
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
  yield box.get('activeProfileId', defaultValue: 'default') // coverage:ignore-line
      as String;
  yield* box
      // coverage:ignore-start
      .watch(key: 'activeProfileId')
      .map((event) =>
          (event.value as String?) ?? 'default');
      // coverage:ignore-end
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
  final storage = ref.watch(storageServiceProvider); // coverage:ignore-line

  // Trigger CC Rollovers (profile agnostic)
  storage.checkCreditCardRollovers(); // coverage:ignore-line

  final box = Hive.box<Account>('accounts'); // coverage:ignore-line

  // Initial fetch
  yield storage.getAccounts(); // coverage:ignore-line

  // Watch for any changes in the accounts box
  yield* box
      // coverage:ignore-start
      .watch()
      .map((_) => storage
          .getAccounts()
          .whereType<Account>()
          .toList());
      // coverage:ignore-end
});

final transactionsProvider = StreamProvider<List<Transaction>>((ref) async* {
  // Wait for Hive
  // coverage:ignore-start
  await ref.watch(storageInitializerProvider.future);
  ref.watch(activeProfileIdProvider);
  final storage = ref.watch(storageServiceProvider);
  // coverage:ignore-end

  final box = Hive.box<Transaction>('transactions'); // coverage:ignore-line

  // Initial fetch
  yield storage.getTransactions(); // coverage:ignore-line

  // Watch for any changes in the transactions box
  yield* box
      // coverage:ignore-start
      .watch()
      .map((_) => storage
          .getTransactions()
          .whereType<Transaction>()
          .toList());
      // coverage:ignore-end
});

final loansProvider = StreamProvider<List<Loan>>((ref) async* {
  // coverage:ignore-start
  await ref.watch(storageInitializerProvider.future);
  final storage = ref.watch(storageServiceProvider);
  final box = Hive.box<Loan>('loans');
  // coverage:ignore-end

  yield storage.getLoans(); // coverage:ignore-line
  yield* box.watch().map((_) => storage.getLoans()); // coverage:ignore-line
});

final recurringTransactionsProvider =
    StreamProvider<List<RecurringTransaction>>((ref) async* {
  // coverage:ignore-start
  await ref.watch(storageInitializerProvider.future);
  final storage = ref.watch(storageServiceProvider);
  final box = Hive.box<RecurringTransaction>('recurring');
  // coverage:ignore-end

  yield storage.getRecurring(); // coverage:ignore-line
  yield* box.watch().map((_) => storage.getRecurring()); // coverage:ignore-line
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
      data: (val) => val, // coverage:ignore-line
      orElse: () {
        // Fallback to direct read if stream hasn't emitted yet but Hive is ready
        final init = ref.watch(storageInitializerProvider);
        if (!init.hasValue) return false;
        final storage = ref.watch(storageServiceProvider);
        return storage.getAuthFlag();
      },
    );
  }

  // coverage:ignore-start
  Future<void> setLoggedIn(bool value) async {
    final storage = ref.read(storageServiceProvider);
    await storage.setAuthFlag(value);
    state = value;
  // coverage:ignore-end
  }
}

/// Reactive stream that monitors the Hive 'isLoggedIn' key directly.
final isLoggedInHiveStreamProvider = StreamProvider<bool>((ref) async* {
  // Wait for Hive to be initialized
  await ref.watch(storageInitializerProvider.future);

  final box = Hive.box('settings');

  // 1. Yield initial value
  yield box.get('isLoggedIn', defaultValue: false) // coverage:ignore-line
      as bool;

  // 2. Yield changes
  yield* box
      .watch(key: 'isLoggedIn') // coverage:ignore-line
      .map((event) => (event.value as bool?) ?? false); // coverage:ignore-line
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

  // coverage:ignore-start
  Future<void> refresh() async {
    final storage = ref.read(storageServiceProvider);
    state = storage.getCategories();
  // coverage:ignore-end
  }

  // coverage:ignore-start
  Future<void> addCategory(Category category) async {
    final storage = ref.read(storageServiceProvider);
    await storage.addCategory(category);
    state = storage.getCategories();
  // coverage:ignore-end
  }

  // coverage:ignore-start
  Future<void> removeCategory(String id) async {
    final storage = ref.read(storageServiceProvider);
    await storage.removeCategory(id);
    state = storage.getCategories();
  // coverage:ignore-end
  }

  Future<void> updateCategory(String id, // coverage:ignore-line
      {required String name,
      required CategoryUsage usage,
      required CategoryTag tag,
      required int iconCode}) async {
    final storage = ref.read(storageServiceProvider); // coverage:ignore-line
    await storage.updateCategory(id, // coverage:ignore-line
        name: name,
        usage: usage,
        tag: tag,
        iconCode: iconCode);
    state = storage.getCategories(); // coverage:ignore-line
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
  @override // coverage:ignore-line
  int build() {
    final init = ref.watch(storageInitializerProvider); // coverage:ignore-line
    if (!init.hasValue) return 0; // coverage:ignore-line

    final storage = ref.watch(storageServiceProvider); // coverage:ignore-line
    return storage.getTxnsSinceBackup(); // coverage:ignore-line
  }

  // coverage:ignore-start
  void refresh() {
    final storage = ref.read(storageServiceProvider);
    state = storage.getTxnsSinceBackup();
  // coverage:ignore-end
  }

  // coverage:ignore-start
  Future<void> reset() async {
    final storage = ref.read(storageServiceProvider);
    await storage.resetTxnsSinceBackup();
    state = 0;
  // coverage:ignore-end
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
  set value(bool v) => state = v; // coverage:ignore-line
}

final currencyFormatProvider =
    NotifierProvider<CurrencyFormatNotifier, bool>(CurrencyFormatNotifier.new);

class AppLockIntentNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void lock() => state = true; // coverage:ignore-line
  void reset() => state = false; // coverage:ignore-line
}

final appLockIntentProvider =
    NotifierProvider<AppLockIntentNotifier, bool>(AppLockIntentNotifier.new);

final appLockStatusProvider = Provider<bool>((ref) {
  final init = ref.watch(storageInitializerProvider);
  if (!init.hasValue) return false;
  final storage = ref.watch(storageServiceProvider);
  return storage.isAppLockEnabled() && storage.getAppPin() != null;
});
