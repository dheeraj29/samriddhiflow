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
    // 1. Initial Check (Attempt to detect offline state immediately)
    // We can't use 'await' in build(), so we trigger a check and update state if needed.
    NetworkUtils.isOffline().then((isOff) {
      if (state != isOff) {
        state = isOff;
      }
    });

    if (kIsWeb) {
      state =
          ConnectivityPlatform.getInitialWebStatus(); // coverage:ignore-line

      // Web Native Listeners (Fastest response)
      ConnectivityPlatform.setupWebListeners(
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

    return true; // Default to offline for safety
  }

  void setOffline(bool isOffline) {
    state = isOffline;
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

void _registerAdapter<T>(TypeAdapter<T> a) {
  if (!Hive.isAdapterRegistered(a.typeId)) {
    Hive.registerAdapter<T>(a);
  }
}

void _registerHiveAdapters() {
  _registerAdapter(AccountAdapter());
  _registerAdapter(AccountTypeAdapter());
  _registerAdapter(AssetTypeAdapter());
  _registerAdapter(BusinessEntityAdapter());
  _registerAdapter(BusinessTypeAdapter());
  _registerAdapter(CapitalGainEntryAdapter());
  _registerAdapter(CategoryAdapter());
  _registerAdapter(CategoryTagAdapter());
  _registerAdapter(CategoryUsageAdapter());
  _registerAdapter(DividendIncomeAdapter());
  _registerAdapter(FrequencyAdapter());
  _registerAdapter(HousePropertyAdapter());
  _registerAdapter(InsurancePolicyAdapter());
  _registerAdapter(InsurancePremiumRuleAdapter());
  _registerAdapter(LoanAdapter());
  _registerAdapter(LendingRecordAdapter());
  _registerAdapter(LendingTypeAdapter());
  _registerAdapter(LendingPaymentAdapter());
  _registerAdapter(LoanTransactionAdapter());
  _registerAdapter(LoanTransactionTypeAdapter());
  _registerAdapter(LoanTypeAdapter());
  _registerAdapter(OtherIncomeAdapter());
  _registerAdapter(ProfileAdapter());
  _registerAdapter(RecurringTransactionAdapter());
  _registerAdapter(ReinvestmentTypeAdapter());
  _registerAdapter(SalaryDetailsAdapter());
  _registerAdapter(ScheduleTypeAdapter());
  _registerAdapter(TaxExemptionRuleAdapter());
  _registerAdapter(TaxMappingRuleAdapter());
  _registerAdapter(TaxPaymentEntryAdapter());
  _registerAdapter(TaxRulesAdapter());
  _registerAdapter(TaxSlabAdapter());
  _registerAdapter(TransactionAdapter());
  _registerAdapter(TransactionTypeAdapter());
  _registerAdapter(PayoutFrequencyAdapter());
  _registerAdapter(SalaryStructureAdapter());
  _registerAdapter(CustomAllowanceAdapter());
  _registerAdapter(CustomDeductionAdapter());
  _registerAdapter(CustomExemptionAdapter());
  _registerAdapter(AdvanceTaxInstallmentRuleAdapter());
  _registerAdapter(AgriIncomeEntryAdapter());
  _registerAdapter(TaxYearDataAdapter());
}

final storageInitializerProvider = FutureProvider<void>((ref) async {
  // Initialize Hive & Register Adapters (Moved from main.dart to unblock UI)
  try {
    _registerHiveAdapters();

    await Hive.initFlutter();

    // Open specialized boxes
    await Hive.openBox('sum_tracker');

    final storage = ref.watch(storageServiceProvider);
    await storage.init(); // coverage:ignore-line

    // Ensure tax rules box is open (Lazy pick-up by TaxConfigService later)
    if (!Hive.isBoxOpen('tax_rules_v2')) {
      // coverage:ignore-line
      await Hive.openBox<TaxRules>('tax_rules_v2'); // coverage:ignore-line
    }

    // Recalculate CC Balances to handle Cycle Rollovers on restart
    await storage.recalculateCCBalances(); // coverage:ignore-line
  } catch (e) {
    if (!e.toString().contains('Cannot use the Ref')) {
      DebugLogger().log("StorageInit Error: $e"); // coverage:ignore-line
    }
    rethrow; // Propagate to AuthWrapper UI
  }
});

final loanServiceProvider = Provider<LoanService>((ref) {
  return LoanService();
});
final authServiceProvider = Provider<AuthService>((ref) {
  final storage = ref.watch(storageServiceProvider);
  // Pass null to force AuthService to use its safe lazy getter for _auth
  return AuthService(null, storage);
});

class LogoutRequestedNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  set value(bool v) => state = v;
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
        return Stream.value(null);
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
  final isOffline = ref.watch(isOfflineProvider);
  if (isOffline) {
    throw Exception("Cannot initialize Firebase in offline mode.");
  }

  // 2. Reachability Check
  await _checkReachability(); // coverage:ignore-line

  // 3. iOS PWA Offline Safety Check
  if (kIsWeb && !FirebaseWebSafe.isFirebaseJsAvailable) {
    // coverage:ignore-line
    throw Exception(
        "Firebase JS SDK Missing (Offline Safe Mode)"); // coverage:ignore-line
  }

  // 4. Initialization with Retry Loop
  await _initializeWithRetry(ref); // coverage:ignore-line
});

Future<void> _checkReachability() async {
  // coverage:ignore-line
  bool reachable = false;
  for (int i = 0; i < 3; i++) {
    // coverage:ignore-line
    if (await NetworkUtils.hasActualInternet()) {
      // coverage:ignore-line
      reachable = true;
      break;
    }
    await Future.delayed(Duration(seconds: 1 + i)); // coverage:ignore-line
  }
  if (!reachable) {
    throw Exception(
        "Internet reached a timeout (DNS/Reachability issue)."); // coverage:ignore-line
  }
}

Future<void> _initializeWithRetry(Ref ref) async {
  // coverage:ignore-line
  int attempts = 0;
  const maxAttempts = 3;

  while (attempts < maxAttempts) {
    // coverage:ignore-line
    try {
      attempts++; // coverage:ignore-line
      // Prevent duplicate initialization error
      if (Firebase.apps.isNotEmpty) return; // coverage:ignore-line

      await Firebase.initializeApp(
        // coverage:ignore-line
        options: kDebugMode
            // coverage:ignore-start
            ? dev.DefaultFirebaseOptions.currentPlatform
            : prod.DefaultFirebaseOptions.currentPlatform,
      ).timeout(Duration(seconds: 20 * attempts));
      // coverage:ignore-end

      await _handleRedirectIfNeeded(ref); // coverage:ignore-line
      return;
    } catch (e) {
      if (attempts >= maxAttempts) {
        // coverage:ignore-line
        _throwFinalError(e, maxAttempts); // coverage:ignore-line
      }
      await Future.delayed(
          Duration(seconds: 2 * attempts)); // coverage:ignore-line
    }
  }
}

// coverage:ignore-start
Future<void> _handleRedirectIfNeeded(Ref ref) async {
  if (ref.read(logoutRequestedProvider)) return;
  final user = await ref.read(authServiceProvider).handleRedirectResult();
// coverage:ignore-end
  if (user != null) {
    ref.read(logoutRequestedProvider.notifier).value =
        false; // coverage:ignore-line
  }
}

Never _throwFinalError(Object e, int maxAttempts) {
  // coverage:ignore-line
  final isTimeout =
      e.toString().toLowerCase().contains("timeout"); // coverage:ignore-line
  if (isTimeout) {
    throw Exception(// coverage:ignore-line
        "Firebase initialization timed out after $maxAttempts attempts."); // coverage:ignore-line
  }
  throw e.toString(); // coverage:ignore-line
}

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
  ref.watch(activeProfileIdProvider);
  final storage = ref.watch(storageServiceProvider);
  final box = Hive.box<Loan>('loans');

  yield storage.getLoans();
  yield* box.watch().map((_) => storage.getLoans());
});

final recurringTransactionsProvider =
    StreamProvider<List<RecurringTransaction>>((ref) async* {
  await ref.watch(storageInitializerProvider.future);
  ref.watch(activeProfileIdProvider);
  final storage = ref.watch(storageServiceProvider);
  final box = Hive.box<RecurringTransaction>('recurring');

  yield storage.getRecurring();
  yield* box.watch().map((_) => storage.getRecurring());
});

final insurancePoliciesProvider =
    StreamProvider<List<InsurancePolicy>>((ref) async* {
  // coverage:ignore-start
  await ref.watch(storageInitializerProvider.future);
  ref.watch(activeProfileIdProvider);
  final storage = ref.watch(storageServiceProvider);
  final box = Hive.box<InsurancePolicy>('insurance_policies');
  // coverage:ignore-end

  yield storage.getInsurancePolicies(); // coverage:ignore-line
  yield* box
      .watch()
      .map((_) => storage.getInsurancePolicies()); // coverage:ignore-line
});

final taxYearDataProvider =
    StreamProvider.family<TaxYearData?, int>((ref, year) async* {
  // coverage:ignore-start
  await ref.watch(storageInitializerProvider.future);
  ref.watch(activeProfileIdProvider);
  final storage = ref.watch(storageServiceProvider);
  final box = Hive.box<TaxYearData>('tax_data');
  // coverage:ignore-end

  yield storage.getTaxYearData(year); // coverage:ignore-line
  yield* box
      .watch()
      .map((_) => storage.getTaxYearData(year)); // coverage:ignore-line
});

final allTaxYearDataProvider = StreamProvider<List<TaxYearData>>((ref) async* {
  // coverage:ignore-start
  await ref.watch(storageInitializerProvider.future);
  ref.watch(activeProfileIdProvider);
  final storage = ref.watch(storageServiceProvider);
  final box = Hive.box<TaxYearData>('tax_data');
  // coverage:ignore-end

  yield storage.getAllTaxYearData(); // coverage:ignore-line
  yield* box
      .watch()
      .map((_) => storage.getAllTaxYearData()); // coverage:ignore-line
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
        // Optimization: Use Hive.isBoxOpen directly to avoid flickering if storage init is refreshing
        if (Hive.isBoxOpen('settings')) {
          return Hive.box('settings').get('isLoggedIn', defaultValue: false)
              as bool;
        }

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
    ref.watch(activeProfileIdProvider);
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
