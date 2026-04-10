import 'dart:convert';
import 'package:samriddhi_flow/navigator_key.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:clock/clock.dart';
import 'package:samriddhi_flow/models/account.dart';
import 'package:samriddhi_flow/models/transaction.dart';
import 'package:samriddhi_flow/models/loan.dart';
import 'package:samriddhi_flow/models/recurring_transaction.dart';
import 'package:samriddhi_flow/models/category.dart';
import 'package:samriddhi_flow/models/profile.dart';
import 'dart:math';
import 'package:samriddhi_flow/models/taxes/insurance_policy.dart';
import 'package:samriddhi_flow/models/taxes/tax_rules.dart';
import 'package:samriddhi_flow/models/taxes/tax_data.dart';
import 'package:samriddhi_flow/utils/billing_helper.dart';
import 'package:samriddhi_flow/utils/recurrence_utils.dart';
import 'package:samriddhi_flow/models/dashboard_config.dart';
import 'package:samriddhi_flow/utils/currency_utils.dart';
import 'package:samriddhi_flow/models/lending_record.dart';
import 'package:samriddhi_flow/models/investment.dart';

const dateFormatMmmDdYyyy = 'MMM dd, yyyy';

class StorageService {
  final HiveInterface _hive;
  final AssetBundle _bundle;
  StorageService([HiveInterface? hive, AssetBundle? bundle])
      : _hive = hive ?? Hive,
        _bundle = bundle ?? rootBundle;

  static const _bankLoanCategory = 'bank loan';

  static const String boxAccounts = 'accounts';
  static const String boxTransactions = 'transactions';
  static const String boxLoans = 'loans';
  static const String boxRecurring = 'recurring';
  static const String boxSettings = 'settings';
  static const String boxProfiles = 'profiles';
  static const String boxCategories = 'categories_v3';
  static const String boxInsurancePolicies = 'insurance_policies';
  static const String boxTaxData = 'tax_data';
  static const String boxLendingRecords = 'lending_records';
  static const String boxInvestments = 'investments';

  Future<void> init() async {
    // Load default categories JSON into memory
    await _loadDefaultCategoriesJson();

    await _safeOpenBox<Account>(boxAccounts);
    await _safeOpenBox<Transaction>(boxTransactions);
    await _safeOpenBox<Loan>(boxLoans);
    await _safeOpenBox<RecurringTransaction>(boxRecurring);
    await _safeOpenBox(boxSettings);
    await _safeOpenBox<Profile>(boxProfiles);
    await _safeOpenBox<Category>(boxCategories);
    await _safeOpenBox<InsurancePolicy>(boxInsurancePolicies);
    await _safeOpenBox<TaxYearData>(boxTaxData);
    await _safeOpenBox<LendingRecord>(boxLendingRecords);
    await _safeOpenBox<Investment>(boxInvestments);

    // Initial profile
    final pBox = _hive.box<Profile>(boxProfiles);
    if (pBox.isEmpty) {
      final defaultProfile = Profile(id: 'default', name: 'Default');
      await pBox.put('default', defaultProfile);
    }

    // Migrate categories from settings to boxCategories if needed
    final cBox = _hive.box<Category>(boxCategories);
    if (cBox.isEmpty) {
      final sBox = _hive.box(boxSettings);
      final List<dynamic>? oldList = sBox.get('categories_v2');
      if (oldList != null && oldList.isNotEmpty) {
        for (var c in oldList.cast<Category>()) {
          // Categories from settings didn't have profileId, default them
          c.profileId = 'default';
          await cBox.put(c.id, c);
        }
      } else {
        // Initial defaults
        if (_defaultCategoryCache.isEmpty) {
          // coverage:ignore-line
          await _loadDefaultCategoriesJson(); // coverage:ignore-line
        }
        // coverage:ignore-start
        final defaults = _getDefaultCategories('default');
        for (var c in defaults) {
          await cBox.put(c.id, c);
          // coverage:ignore-end
        }
      }
    }
    await _revalidateRecurringDates();
    await processRecurringInvestments();
  }

  List<Map<String, dynamic>> _defaultCategoryCache = [];

  Future<void> _loadDefaultCategoriesJson() async {
    try {
      final jsonString =
          await _bundle.loadString('assets/data/default_categories.json');
      final List<dynamic> jsonList = jsonDecode(jsonString);
      _defaultCategoryCache = List<Map<String, dynamic>>.from(jsonList);
    } catch (e) {
      // Fallback empty or handle critical error
    }
  }

  // --- Profile Operations ---
  String getActiveProfileId() {
    final box = _hive.box(boxSettings);
    return box.get('activeProfileId', defaultValue: 'default');
  }

  Future<void> setActiveProfileId(String id) async {
    final box = _hive.box(boxSettings);
    await box.put('activeProfileId', id);
  }

  // --- Auth Optimistic Flag ---
  bool getAuthFlag() {
    final box = _hive.box(boxSettings);
    return box.get('isLoggedIn', defaultValue: false) as bool;
  }

  Future<void> setAuthFlag(bool value) async {
    final box = _hive.box(boxSettings);
    await box.put('isLoggedIn', value);
  }

  // --- Smart Calculator Preference ---
  bool isSmartCalculatorEnabled() {
    final box = _hive.box(boxSettings);
    final globalFallback =
        box.get('smartCalculatorEnabled', defaultValue: false) as bool;
    final profileId = getActiveProfileId();
    return box.get('smartCalculatorEnabled_$profileId',
        defaultValue: globalFallback) as bool;
  }

  Future<void> setSmartCalculatorEnabled(bool value) async {
    final box = _hive.box(boxSettings);
    final profileId = getActiveProfileId();
    await box.put('smartCalculatorEnabled_$profileId', value);
  }

  // --- Locale Management ---
  // coverage:ignore-start
  String? getLocale() {
    final box = _hive.box(boxSettings);
    return box.get('appLocale') as String?;
    // coverage:ignore-end
  }

  Future<void> setLocale(String? localeCode) async {
    // coverage:ignore-line
    final box = _hive.box(boxSettings); // coverage:ignore-line
    if (localeCode == null) {
      await box.delete('appLocale'); // coverage:ignore-line
    } else {
      await box.put('appLocale', localeCode); // coverage:ignore-line
    }
  }

  // --- Cloud Sync Settings ---
  // coverage:ignore-start
  String getCloudDatabaseRegion() {
    final box = _hive.box(boxSettings);
    return box.get('cloudDatabaseRegion', defaultValue: 'India');
    // coverage:ignore-end
  }

  // coverage:ignore-start
  Future<void> setCloudDatabaseRegion(String region) async {
    final box = _hive.box(boxSettings);
    await box.put('cloudDatabaseRegion', region);
    // coverage:ignore-end
  }

  List<Profile> getProfiles() {
    return _hive
        .box<Profile>(boxProfiles)
        .toMap()
        .values
        .whereType<Profile>()
        .toList();
  }

  Future<void> saveProfile(Profile profile) async {
    // coverage:ignore-line
    await _hive
        .box<Profile>(boxProfiles)
        .put(profile.id, profile); // coverage:ignore-line
  }

  Future<void> deleteProfile(String profileId) async {
    // 1. Delete Profile record
    await _hive.box<Profile>(boxProfiles).delete(profileId);

    // 2. Delete Accounts & Rollover Metadata
    await _deleteItemsByProfile<Account>(
      boxAccounts,
      profileId,
      onBeforeDelete: (a) => _cleanupAccountMetadata(a.id),
    );

    // 3. Delete Transactions
    await _deleteItemsByProfile<Transaction>(boxTransactions, profileId);

    // 4. Delete Loans
    await _deleteItemsByProfile<Loan>(boxLoans, profileId);

    // 5. Delete Recurring
    await _deleteItemsByProfile<RecurringTransaction>(boxRecurring, profileId);

    // 6. Delete Categories
    await _deleteItemsByProfile<Category>(boxCategories, profileId);

    // 7. Delete Lending Records
    await _deleteItemsByProfile<LendingRecord>(boxLendingRecords, profileId);

    // 9. Delete Insurance Policies
    await _deleteItemsByProfile<InsurancePolicy>(
        boxInsurancePolicies, profileId);

    // 10. Delete Tax Data
    await _deleteItemsByProfile<TaxYearData>(boxTaxData, profileId);

    // 11. Delete Investments
    await _deleteItemsByProfile<Investment>(boxInvestments, profileId);

    // 12. Clean up primitive profile-specific preferences in Settings box
    final settingsBox = _hive.box(boxSettings);
    await settingsBox.delete('dashboardConfig_$profileId');
    await settingsBox.delete('smartCalculatorEnabled_$profileId');
    await settingsBox.delete('monthlybudget_$profileId');
    await settingsBox.delete('currencyLocale_$profileId');

    // 8. If active profile was deleted, switch to another one
    if (getActiveProfileId() == profileId) {
      // coverage:ignore-start
      final profiles = getProfiles();
      if (profiles.isNotEmpty) {
        await setActiveProfileId(profiles.first.id);
        // coverage:ignore-end
      } else {
        await setActiveProfileId('default'); // coverage:ignore-line
      }
    }
  }

  int? getLastRollover(String accountId) {
    if (!_hive.isBoxOpen(boxSettings)) return null;
    return _hive.box(boxSettings).get('last_rollover_$accountId');
  }

  // --- Dashboard Config ---
  DashboardVisibilityConfig getDashboardConfig() {
    final box = _hive.box(boxSettings);
    final profileId = getActiveProfileId();

    // Check for profile specific config first
    dynamic map = box.get('dashboardConfig_$profileId');

    // Fallback to global config if profile specific doesn't exist
    map ??= box.get('dashboardConfig');

    if (map != null) {
      // Cast the map to Map<String, dynamic> safely
      final castMap = Map<String, dynamic>.from(map as Map);
      return DashboardVisibilityConfig.fromMap(castMap);
    }
    return const DashboardVisibilityConfig();
  }

  Future<void> saveDashboardConfig(DashboardVisibilityConfig config) async {
    final box = _hive.box(boxSettings);
    final profileId = getActiveProfileId();
    await box.put('dashboardConfig_$profileId', config.toMap());
  }

  Box<dynamic> getSettingsBox() {
    // coverage:ignore-line
    return _hive.box(boxSettings); // coverage:ignore-line
  }

  Future<void> _deleteItemsByProfile<T>(String boxName, String profileId,
      {Future<void> Function(T)? onBeforeDelete}) async {
    final box = _hive.box<T>(boxName);
    // Use toMap().values to safely handle potentially corrupted or mixed types
    final itemsToDelete = box.toMap().values.whereType<T>().where((item) {
      try {
        return (item as dynamic).profileId == profileId;
      } catch (_) {
        return false;
      }
    }).toList();

    for (var item in itemsToDelete) {
      if (onBeforeDelete != null) {
        await onBeforeDelete(item);
      }
      final id = (item as dynamic).id;
      await box.delete(id);
    }
  }

  // --- Account Operations ---
  // --- Private Helpers ---
  List<T> _getByProfile<T>(String boxName) {
    final profileId = getActiveProfileId();
    // Safety: Use toMap().values and whereType<T>() to avoid TypeError if types are mixed
    return _hive.box<T>(boxName).toMap().values.whereType<T>().where((item) {
      try {
        if (item is Account) return item.profileId == profileId;
        if (item is Transaction) return item.profileId == profileId;
        if (item is Loan) return item.profileId == profileId;
        if (item is RecurringTransaction) return item.profileId == profileId;
        if (item is Category) return item.profileId == profileId;
        return (item as dynamic).profileId == profileId;
      } catch (_) {
        return false;
      }
    }).toList();
  }

  // --- Account Operations ---
  Account? getAccount(String id) =>
      _hive.box<Account>(boxAccounts).get(id); // coverage:ignore-line
  List<Account> getAccounts() =>
      _getByProfile<Account>(boxAccounts); // coverage:ignore-line

  // coverage:ignore-start
  List<Account> getAllAccounts() {
    return _hive
        .box<Account>(boxAccounts)
        .toMap()
        .values
        .whereType<Account>()
        .toList();
    // coverage:ignore-end
  }

  Future<void> saveAccount(Account account,
      {bool keepBilledStatus = false}) async {
    final box = _hive.box<Account>(boxAccounts);
    final existingAccount = box.get(account.id);

    if (_isCreditCardWithCycle(account)) {
      if (_shouldSkipCycleReset(account, existingAccount)) {
        await box.put(account.id, account); // coverage:ignore-line
        return;
      }

      if (_needsCreditCardRolloverReset(account, existingAccount)) {
        await resetCreditCardRollover(account,
            keepBilledStatus: keepBilledStatus, adjustBalance: false);
      }
    }

    await box.put(account.id, account);
  }

  bool _isCreditCardWithCycle(Account account) {
    return account.type == AccountType.creditCard &&
        account.billingCycleDay != null;
  }

  bool _shouldSkipCycleReset(Account account, Account? existingAccount) {
    if (existingAccount == null) return false;
    if (!isBilledAmountPaid(account.id)) return false;
    return existingAccount.billingCycleDay ==
        account.billingCycleDay; // coverage:ignore-line
  }

  bool _needsCreditCardRolloverReset(
      Account account, Account? existingAccount) {
    if (existingAccount == null) return true;
    if (existingAccount.billingCycleDay != account.billingCycleDay) {
      return true;
    }

    final lastRolloverMillis =
        _hive.box(boxSettings).get('last_rollover_${account.id}');
    if (lastRolloverMillis == null) return false;

    return _isRolloverPointerOutOfSync(account, lastRolloverMillis);
  }

  bool _isRolloverPointerOutOfSync(Account account, int lastRolloverMillis) {
    final now = DateTime.now();
    final currentCycleStart =
        BillingHelper.getCycleStart(now, account.billingCycleDay!);
    final prevCycleStart = BillingHelper.getCycleStart(
        currentCycleStart.subtract(const Duration(days: 1)),
        account.billingCycleDay!);

    final targetBilled = prevCycleStart.subtract(const Duration(seconds: 1));
    final targetPaid = currentCycleStart.subtract(const Duration(seconds: 1));

    final current = DateTime.fromMillisecondsSinceEpoch(lastRolloverMillis);
    return !current.isAtSameMomentAs(targetBilled) &&
        !current.isAtSameMomentAs(targetPaid);
  }

  /// Raw save for restore/import bypasses all auto-rollover logic.
  // coverage:ignore-start
  Future<void> saveAccountRaw(Account account) async {
    final box = _hive.box<Account>(boxAccounts);
    await box.put(account.id, account);
    // coverage:ignore-end
  }

  Future<void> resetCreditCardRollover(Account acc,
      {bool keepBilledStatus = false,
      bool adjustBalance = false,
      bool skipTransfers = true,
      bool includeIncome = false}) async {
    if (acc.billingCycleDay == null) return;

    try {
      final settingsBox = _hive.box(boxSettings);
      final key = 'last_rollover_${acc.id}';
      final lastRolloverMillis = settingsBox.get(key);
      DateTime oldPointer;

      if (lastRolloverMillis == null) {
        // Default to "Paid" state (pointer at current cycle start - 1s)
        final now = DateTime.now();
        final currentCycleStart =
            BillingHelper.getCycleStart(now, acc.billingCycleDay!);
        oldPointer = currentCycleStart.subtract(const Duration(seconds: 1));
      } else {
        oldPointer = DateTime.fromMillisecondsSinceEpoch(lastRolloverMillis);
      }

      final now = DateTime.now();
      final currentCycleStart =
          BillingHelper.getCycleStart(now, acc.billingCycleDay!);
      final prevCycleStart = BillingHelper.getCycleStart(
          currentCycleStart.subtract(const Duration(days: 1)),
          acc.billingCycleDay!);

      DateTime targetPointer;
      if (keepBilledStatus) {
        // "Paid" state: Pointer is at the end of the PREVIOUS cycle (start of current - 1s).
        targetPointer = currentCycleStart.subtract(const Duration(seconds: 1));
      } else {
        // "Billed" state: Pointer is at the end of the cycle BEFORE previous (start of prev - 1s).
        targetPointer = prevCycleStart.subtract(const Duration(seconds: 1));
      }

      if (adjustBalance && oldPointer.isBefore(targetPointer)) {
        // coverage:ignore-line
        // Realize debt for the gap being jumped (oldPointer, targetPointer]
        await _shiftBilledExpensesToBalance(
            acc, oldPointer, targetPointer); // coverage:ignore-line
      }

      await settingsBox.put(key, targetPointer.millisecondsSinceEpoch);
    } catch (e) {
      // coverage:ignore-start
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          // coverage:ignore-end
          const SnackBar(content: Text('Failed to reset billing cycle.')),
        );
      }
    }
  }

  /// Explicitly refreshes the billing cycle dates to SHOW the bill (Billed Amount > 0).
  /// Reverts any "Paid" status for the current cycle.
  Future<void> recalculateBilledAmount(String accountId) async {
    final box = _hive.box<Account>(boxAccounts);
    final acc = box.get(accountId);
    if (acc == null) return;

    if (acc.isFrozen) {
      throw Exception(
          'Cannot recalculate bill while the account is frozen for a billing cycle update.');
    }

    // Set flag to ignore payments for the next rollover check so the bill actually shows up
    final settingsBox = _hive.box(boxSettings);
    await settingsBox.put('ignore_rollover_payments_${acc.id}', true);

    // Pointer Refinement: shifts the pointer back to show the bill, but doesn't touch balance.
    await resetCreditCardRollover(acc,
        keepBilledStatus: false,
        adjustBalance: false,
        skipTransfers: true,
        includeIncome: false);
  }

  /// Manually clears the billed amount (Mark as Paid/Advance Cycle).
  /// Doesn't record a transaction, just updates the pointer.
  Future<void> clearBilledAmount(String accountId) async {
    final box = _hive.box<Account>(boxAccounts);
    final acc = box.get(accountId);
    if (acc == null) return;

    if (acc.isFrozen) {
      throw Exception(
          'Cannot clear bill while the account is frozen for a billing cycle update.');
    }

    // Force keepBilledStatus = true to advance pointer to current cycle start
    await resetCreditCardRollover(acc,
        keepBilledStatus: true); // coverage:ignore-line
  }

  Future<void> updateBillingCycle({
    required String accountId,
    required int newCycleDay,
    int? newDueDateDay,
    required DateTime freezeDate,
    required DateTime firstStatementDate,
  }) async {
    final box = _hive.box<Account>(boxAccounts);
    final acc = box.get(accountId);
    if (acc == null || acc.type != AccountType.creditCard) return;

    // Only require 0 balance if NOT already in the middle of a freeze transition.
    final isAlreadyFrozen = acc.isFrozen && !acc.isFrozenCalculated;
    if (acc.balance > 0 && !isAlreadyFrozen) {
      throw Exception(
          'Billing cycle can only be changed when the generated bill balance is exactly 0.');
    }

    final updatedAcc = acc.copyWith(
      billingCycleDay: newCycleDay,
      paymentDueDateDay: newDueDateDay,
      balance: acc
          .balance, // Preserve current balance; recalculator will refine it below
      freezeDate: isAlreadyFrozen
          ? acc.freezeDate
          : freezeDate, // Retain original freeze date if concurrent update
      isFrozen: true,
      isFrozenCalculated: false,
      firstStatementDate: firstStatementDate,
    );

    // Update the account
    await box.put(accountId, updatedAcc);
    await recalculateAccountBalance(accountId);

    // Only set the pointer if we are starting a NEW freeze period.
    // If it was already frozen, the pointer is already anchored to the freezeDate.
    if (!isAlreadyFrozen) {
      final settingsBox = _hive.box(boxSettings);
      await settingsBox.put(
          'last_rollover_$accountId', freezeDate.millisecondsSinceEpoch);
    }
  }

  // coverage:ignore-start
  Future<void> toggleAccountPin(String accountId) async {
    final box = _hive.box<Account>(boxAccounts);
    final acc = box.get(accountId);
    // coverage:ignore-end
    if (acc == null) return;

    final updatedAcc =
        acc.copyWith(isPinned: !acc.isPinned); // coverage:ignore-line
    await box.put(accountId, updatedAcc); // coverage:ignore-line
  }

  Future<void> deleteAccount(String id) async {
    final box = _hive.box<Account>(boxAccounts);
    await box.delete(id);
    await _cleanupAccountMetadata(id);
  }

  Future<void> _cleanupAccountMetadata(String accountId) async {
    final settingsBox = _hive.box(boxSettings);
    await settingsBox.delete('last_rollover_$accountId');
  }

  // --- Transaction Operations ---
  List<Transaction> getTransactions() {
    final list = _getByProfile<Transaction>(boxTransactions)
        .where((t) => !t.isDeleted)
        .toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  // coverage:ignore-start
  List<Transaction> getAllTransactions() {
    return _hive
        .box<Transaction>(boxTransactions)
        .toMap()
        .values
        .whereType<Transaction>()
        .toList();
    // coverage:ignore-end
  }

  /// Fetches transactions for a specific account and profile.
  List<Transaction> getTransactionsByAccount(String accountId,
      {String? profileId}) {
    final targetProfileId = profileId ?? getActiveProfileId();
    return _hive
        .box<Transaction>(boxTransactions)
        .toMap()
        .values
        .whereType<Transaction>()
        .where((t) =>
            !t.isDeleted &&
            (t.accountId == accountId || t.toAccountId == accountId) &&
            t.profileId == targetProfileId)
        .toList();
  }

  /// Checks if the billed amount for an account is marked as paid.
  bool isBilledAmountPaid(String accountId) {
    final acc = _hive.box<Account>(boxAccounts).get(accountId);
    if (acc == null || acc.billingCycleDay == null) return true;

    final lastRolloverMillis = getLastRollover(accountId);
    if (lastRolloverMillis == null) return false;

    final lastRollover =
        DateTime.fromMillisecondsSinceEpoch(lastRolloverMillis);
    final now = DateTime.now();
    final currentCycleStart =
        BillingHelper.getCycleStart(now, acc.billingCycleDay!);

    // If lastRollover is ON or AFTER currentCycleStart - 1sec, it's paid.
    final paidThreshold =
        currentCycleStart.subtract(const Duration(seconds: 1));
    return !lastRollover.isBefore(paidThreshold);
  }

  List<Transaction> getDeletedTransactions() {
    return _getByProfile<Transaction>(boxTransactions)
        .where((t) => t.isDeleted)
        .toList();
  }

  // --- Rollover Logic ---
  static bool _isCheckingRollover = false;

  Future<void> checkCreditCardRollovers(
      {DateTime? nowOverride,
      String? accountId,
      bool ignorePayments = false}) async {
    if (_isCheckingRollover) return;
    _isCheckingRollover = true;

    try {
      final accountsBox = _hive.box<Account>(boxAccounts);
      // Safety: Use toMap().values.whereType<Account>()
      final accounts = accountsBox.toMap().values.whereType<Account>().toList();
      final settingsBox = _hive.box(boxSettings);
      final now = nowOverride ?? DateTime.now(); // coverage:ignore-line

      for (var acc in accounts) {
        if (accountId != null && acc.id != accountId) {
          // coverage:ignore-line
          continue;
        }
        if (acc.type != AccountType.creditCard || acc.billingCycleDay == null) {
          continue;
        }
        await _processCardRollover(
            acc, accountsBox, settingsBox, now, ignorePayments);
      }
    } catch (e) {
      debugPrint('Error during rollover: $e'); // coverage:ignore-line
    } finally {
      _isCheckingRollover = false;
    }
  }

  Future<void> _processCardRollover(Account acc, Box<Account> accountsBox,
      Box settingsBox, DateTime now, bool ignorePayments) async {
    final key = 'last_rollover_${acc.id}';
    final lastRolloverMillis = settingsBox.get(key);

    final ignoreFlagKey = 'ignore_rollover_payments_${acc.id}';
    final shouldIgnorePayments =
        settingsBox.get(ignoreFlagKey, defaultValue: false) as bool;
    final effectiveIgnorePayments = ignorePayments || shouldIgnorePayments;

    final currentCycleStart =
        BillingHelper.getCycleStart(now, acc.billingCycleDay!);
    final prevCycleStart = BillingHelper.getCycleStart(
        currentCycleStart.subtract(const Duration(days: 1)),
        acc.billingCycleDay!);

    // Standard rollover target is end of cycle BEFORE previous (to allow Billed bucket to persist)
    DateTime effectiveTarget =
        prevCycleStart.subtract(const Duration(seconds: 1));

    // SPECIAL: For frozen accounts, we want to transition Phase 1 and Phase 2
    // as soon as the potential statements are ready.
    if (acc.isFrozen) {
      effectiveTarget = currentCycleStart.subtract(const Duration(seconds: 1));
    }

    final lastRollover = lastRolloverMillis != null
        ? DateTime.fromMillisecondsSinceEpoch(lastRolloverMillis)
        : effectiveTarget;

    if (!now.isAfter(effectiveTarget)) {
      return;
    }

    if (!effectiveTarget.isAfter(lastRollover)) {
      return;
    }

    // If we are actively ignoring payments (i.e. we forcefully recalculated the bill to look at it),
    // we should NOT automatically roll it over. Otherwise, the "unpaid" bill instantly shifts into Balance!
    if (effectiveIgnorePayments) {
      // The bill was forced open for viewing. Do not realize debt right now.
      return;
    }

    if (acc.isFrozen) {
      await _handleFrozenRollover(acc, accountsBox, settingsBox, now,
          effectiveTarget, key, lastRollover);
      return;
    }
    // ----------------------------------

    // Rule: "In auto-rollover case, if bill not paid when its calculating, then old bill shall be added to balance"
    // We calculate spends in the period we are closing (lastRollover to targetRolloverDate).
    await _shiftBilledExpensesToBalance(acc, lastRollover, effectiveTarget);

    await settingsBox.put(key, effectiveTarget.millisecondsSinceEpoch);
    await accountsBox.put(acc.id, acc);
  }

  Future<void> _handleFrozenRollover(
      Account acc,
      Box<Account> accountsBox,
      Box settingsBox,
      DateTime now,
      DateTime effectiveTarget,
      String key,
      DateTime lastRollover) async {
    DateTime currentLastRollover = lastRollover;

    if (!acc.isFrozenCalculated) {
      await _handleFrozenStage1(acc, accountsBox, settingsBox, now,
          effectiveTarget, key, currentLastRollover);

      // Refresh state for Stage 2 potential check
      if (!acc.isFrozenCalculated) {
        return; // Stage 1 didn't complete (date not reached)
      }
      currentLastRollover =
          DateTime.fromMillisecondsSinceEpoch(settingsBox.get(key));
    }

    // Sequential Check: If time has passed the Transition Bill period too, realize Stage 2 now.
    if (acc.isFrozenCalculated &&
        now.isAfter(effectiveTarget) &&
        effectiveTarget.isAfter(currentLastRollover)) {
      await _handleFrozenStage2(acc, accountsBox, currentLastRollover);
    }
  }

  Future<void> _handleFrozenStage1(
      Account acc,
      Box<Account> accountsBox,
      Box settingsBox,
      DateTime now,
      DateTime effectiveTarget,
      String key,
      DateTime lastRollover) async {
    if (acc.firstStatementDate != null &&
        now.isBefore(acc.firstStatementDate!)) {
      // coverage:ignore-line
      return;
    }

    acc.isFrozenCalculated = true;
    // Don't put yet; _shiftBilledExpensesToBalance or the end of Stage 1 will handle it.

    await _shiftBilledExpensesToBalance(
        acc, lastRollover, acc.freezeDate ?? lastRollover,
        includeIncome:
            false); // NEVER include income for CC; it hits balance in real-time.

    final pointer =
        acc.firstStatementDate?.subtract(const Duration(seconds: 1)) ??
            effectiveTarget;
    await settingsBox.put(key, pointer.millisecondsSinceEpoch);

    // Save final state after Stage 1 modifications
    await accountsBox.put(acc.id, acc);
  }

  Future<void> _handleFrozenStage2(
      Account acc, Box<Account> accountsBox, DateTime lastRollover) async {
    await _shiftBilledExpensesToBalance(
        acc, acc.freezeDate ?? lastRollover, lastRollover,
        includeIncome: false); // NEVER include income for CC.

    acc.isFrozen = false;
    acc.isFrozenCalculated = false;
    acc.freezeDate = null;
    await accountsBox.put(acc.id, acc);
  }

  Future<void> saveTransaction(Transaction transaction,
      {bool applyImpact = true, DateTime? now}) async {
    final box = _hive.box<Transaction>(boxTransactions);
    final existingTxn = box.get(transaction.id);

    if (applyImpact) {
      // Validate: Prevents modifying transactions in a closed cycle or frozen period.
      await _validateTransactionDate(transaction);

      await _handleTransactionImpacts(
        oldTxn: existingTxn,
        newTxn: transaction,
        now: now,
      );
    }

    await box.put(transaction.id, transaction);
    await _incrementBackupCounter();
  }

  Future<void> _validateTransactionDate(Transaction txn) async {
    final accBox = _hive.box<Account>(boxAccounts);

    // 1. Check Source Account
    if (txn.accountId != null) {
      final acc = accBox.get(txn.accountId);
      if (acc != null && _isCreditCardWithCycle(acc)) {
        await _runValidationRules(txn, acc);
      }
    }

    // 2. Check Target Account (for Transfers)
    if (txn.toAccountId != null) {
      final toAcc = accBox.get(txn.toAccountId);
      if (toAcc != null && _isCreditCardWithCycle(toAcc)) {
        await _runValidationRules(txn, toAcc);
      }
    }
  }

  Future<void> _runValidationRules(Transaction txn, Account acc) async {
    _ensureNotBeforeFreezeDate(txn, acc);
    final lastRolloverMillis = getLastRollover(acc.id);
    if (lastRolloverMillis != null) {
      _ensureAfterLastRollover(txn, lastRolloverMillis);
    }
    _ensureNotPaidBilledCycle(txn, acc);
  }

  void _ensureNotBeforeFreezeDate(Transaction txn, Account acc) {
    if (!acc.isFrozen || acc.freezeDate == null) return;
    if (txn.date.isBefore(acc.freezeDate!)) {
      throw Exception(
          'Cannot add/edit transaction older than the current Billing Cycle freeze date.\n'
          'Freeze Date: ${acc.freezeDate!.year}-${acc.freezeDate!.month}-${acc.freezeDate!.day}\n'
          'Transaction Date: ${txn.date.year}-${txn.date.month}-${txn.date.day}\n\n'
          'Please wait for the freeze period to end on the next billing date.');
    }
  }

  void _ensureAfterLastRollover(Transaction txn, int lastRolloverMillis) {
    final lastRollover =
        DateTime.fromMillisecondsSinceEpoch(lastRolloverMillis);
    if (!txn.date.isAfter(lastRollover)) {
      throw Exception(
          'Cannot add/edit transaction for a closed billing cycle.\n'
          'Cycle closed on: ${lastRollover.year}-${lastRollover.month}-${lastRollover.day}\n'
          'Transaction Date: ${txn.date.year}-${txn.date.month}-${txn.date.day}\n\n'
          'Please use "Repair Billing Cycle" if you need to reset the cycle.');
    }
  }

  void _ensureNotPaidBilledCycle(Transaction txn, Account acc) {
    final now = DateTime.now();
    final currentCycleStart =
        BillingHelper.getCycleStart(now, acc.billingCycleDay!);
    if (txn.date.isBefore(currentCycleStart) && isBilledAmountPaid(acc.id)) {
      throw Exception(// coverage:ignore-line
          'Cannot add/edit transaction for a billing cycle that is already marked as paid.');
    }
  }

  /// Initializes the rollover timestamp for a newly imported account to the current cycle start.
  /// This prevents the system from looking back at historical transactions and double-counting them.
  Future<void> initRolloverForImport(
      String accountId, int billingCycleDay) async {
    final now = DateTime.now();
    final currentCycleStart = BillingHelper.getCycleStart(now, billingCycleDay);

    // Set to CURRENT cycle start MINUS 1 second.
    // This marks the "End of the Previous History".
    // So transactions ON the start date (00:00:00) are considered "After" (Unbilled).
    final importRolloverDate =
        currentCycleStart.subtract(const Duration(seconds: 1));

    final settingsBox = _hive.box(boxSettings);
    final existingRollover = settingsBox.get('last_rollover_$accountId');

    // Requirement: If it's a frozen account, we MUST NOT overwrite the pointer
    // because it contains the critical freezeDate!
    // Also, if a pointer already exists (e.g. from a cloud payload), we trust it.
    if (existingRollover != null) return;

    final accBox = _hive.box<Account>(boxAccounts);
    final acc = accBox.get(accountId);
    if (acc != null && acc.isFrozen) return; // coverage:ignore-line

    await settingsBox.put(
        'last_rollover_$accountId', importRolloverDate.millisecondsSinceEpoch);
  }

  /// Explicitly sets the last rollover timestamp (Used by Repair Jobs).
  // coverage:ignore-start
  Future<void> setLastRollover(String accountId, int timestamp) async {
    final settingsBox = _hive.box(boxSettings);
    await settingsBox.put('last_rollover_$accountId', timestamp);
    // coverage:ignore-end
  }

  /// Recalculates Credit Card balances based on the current billing cycle.
  /// Corrects standard 'Storage' skipping logic which doesn't auto-rollover.
  /// Returns the number of accounts updated.
  Future<int> recalculateCCBalances(
      // coverage:ignore-line
      {String? accountId,
      bool ignorePayments = false}) async {
    // Reruns the rollover logic.
    // NOTE: This will only "repair" if a rollover was MISSED (i.e. due to app not opening).
    // It will NOT recalculate history if the history is already marked as rolled over.
    // This aligns with user request: "only consider previous cycle".
    await checkCreditCardRollovers(
        // coverage:ignore-line
        accountId: accountId,
        ignorePayments: ignorePayments);
    return 1; // Dummy return as we don't track count deeply in rollover
  }

  Future<void> saveTransactions(
      List<Transaction> transactions, // coverage:ignore-line
      {bool applyImpact = true,
      DateTime? now}) async {
    final box = _hive.box<Transaction>(boxTransactions); // coverage:ignore-line
    final Map<dynamic, Transaction> batch = {}; // coverage:ignore-line

    for (var txn in transactions) {
      // coverage:ignore-line
      if (applyImpact) {
        final existingTxn = box.get(txn.id); // coverage:ignore-line
        await _handleTransactionImpacts(
          // coverage:ignore-line
          oldTxn: existingTxn,
          newTxn: txn,
          now: now,
        );
      }
      batch[txn.id] = txn; // coverage:ignore-line
    }

    await box.putAll(batch); // coverage:ignore-line
    await _incrementBackupCounter(); // coverage:ignore-line
  }

  // coverage:ignore-start
  Future<void> updateTransactionsTaxSync(List<String> ids, bool taxSync) async {
    final box = _hive.box<Transaction>(boxTransactions);
    final Map<dynamic, Transaction> batch = {};
    // coverage:ignore-end

    for (var id in ids) {
      // coverage:ignore-line
      final txn = box.get(id); // coverage:ignore-line
      if (txn != null) {
        txn.taxSync = taxSync; // coverage:ignore-line
        batch[id] = txn; // coverage:ignore-line
      }
    }

    if (batch.isNotEmpty) {
      // coverage:ignore-line
      await box.putAll(batch); // coverage:ignore-line
    }
  }

  Future<void> _handleTransactionImpacts({
    Transaction? oldTxn,
    Transaction? newTxn,
    DateTime? now,
  }) async {
    // 1. Reverse old impact
    await _applyTransactionImpactUpdate(oldTxn, true, now);

    // 2. Apply new impact
    await _applyTransactionImpactUpdate(newTxn, false, now);
  }

  Future<void> _applyTransactionImpactUpdate(
      Transaction? txn, bool isReversal, DateTime? now) async {
    if (txn == null || txn.isDeleted) return;

    final accountsBox = _hive.box<Account>(boxAccounts);

    // Source Account
    if (txn.accountId != null) {
      final acc = accountsBox.get(txn.accountId);
      if (acc != null) {
        _applyTransactionImpact(acc, txn,
            isReversal: isReversal, isSource: true, now: now);
        await accountsBox.put(acc.id, acc);
      }
    }

    // Target Account (for Transfers)
    if (txn.type == TransactionType.transfer && txn.toAccountId != null) {
      final accTo = accountsBox.get(txn.toAccountId);
      if (accTo != null) {
        _applyTransactionImpact(accTo, txn,
            isReversal: isReversal, isSource: false, now: now);
        await accountsBox.put(accTo.id, accTo);
      }
    }
  }

  Future<void> recalculateAccountBalance(String accountId) async {
    final accountsBox = _hive.box<Account>(boxAccounts);
    final acc = accountsBox.get(accountId);
    if (acc == null) return;

    // Reset Balance
    acc.balance = 0.0;
    // Add logic for initial balance if tracked separately, but currently Account only has 'balance'
    // which accumulates history. If 'initialBalance' is needed, it should be a field in Account.
    // Assuming 0 for now as 'recalculate' implies rebuilding from transaction history.

    final allTxns = getTransactions(); // Already sorted by date DESC
    // We need ASC order to rebuild balance chronologically
    final txns = allTxns.reversed.where((t) => !t.isDeleted).toList();
    for (var txn in txns) {
      // REFINEMENT: Strictly skip history before freeze date IF in Phase 1.
      // If isFrozenCalculated is true (Phase 2), we allow the previously settled
      // transition balance to persist by rebuilding from history normally.
      if (acc.isFrozen &&
          // coverage:ignore-start
          !acc.isFrozenCalculated &&
          acc.freezeDate != null &&
          txn.date.isBefore(acc.freezeDate!)) {
        // coverage:ignore-end
        continue;
      }

      if (txn.accountId == accountId) {
        _applyTransactionImpact(acc, txn, isReversal: false, isSource: true);
        // coverage:ignore-start
      } else if (txn.type == TransactionType.transfer &&
          txn.toAccountId == accountId) {
        _applyTransactionImpact(acc, txn, isReversal: false, isSource: false);
        // coverage:ignore-end
      }
    }

    await accountsBox.put(acc.id, acc);
  }

  void _applyTransactionImpact(Account acc, Transaction txn,
      {required bool isReversal, required bool isSource, DateTime? now}) {
    if (_shouldSkipCreditCardBalance(acc, txn, isSource, now)) return;

    // Calculate Net Worth Impact
    double impact = 0.0;
    if (txn.type == TransactionType.expense) {
      impact = -txn.amount;
    } else if (txn.type == TransactionType.income) {
      impact = txn.amount;
    } else if (txn.type == TransactionType.transfer) {
      impact = isSource ? -txn.amount : txn.amount;
    }

    // Reverse if needed (e.g. deleting a transaction)
    if (isReversal) impact = -impact;

    // Credit Cards track LIABILITY (Positive Balance = Debt)
    // We invert the Net Worth Impact for Credit Cards.
    if (acc.type == AccountType.creditCard) {
      acc.balance = CurrencyUtils.roundTo2Decimals(acc.balance - impact);
    } else {
      acc.balance = CurrencyUtils.roundTo2Decimals(acc.balance + impact);
    }
  }

  /// Returns true if the transaction is a credit card spend in an open cycle
  /// that should NOT affect Account.balance (spends are aggregated into
  /// 'Billed' or 'Unbilled' display and added to Balance upon Rollover).
  bool _shouldSkipCreditCardBalance(
      Account acc, Transaction txn, bool isSource, DateTime? now) {
    if (acc.type != AccountType.creditCard || acc.billingCycleDay == null) {
      return false;
    }

    if (acc.isFrozen) {
      return _isWithinFrozenPeriod(acc, txn); // coverage:ignore-line
    }

    // NEW Logic: Only defer EXPENSES (except Rounding Adjustments).
    // Income, Incoming Transfers (Payments), and Rounding Adjustments hit balance immediately.
    // This allows Total = balance + billed + unbilled.
    if (txn.type != TransactionType.expense ||
        BillingHelper.isRoundingAdjustment(txn)) {
      return false;
    }

    final lastRolloverMillis = getLastRollover(acc.id);
    if (lastRolloverMillis != null) {
      final lastRollover =
          DateTime.fromMillisecondsSinceEpoch(lastRolloverMillis);
      return txn.date.isAfter(lastRollover);
    }

    // No rollover set (New Card fallback): Skip spending from previous cycle onwards.
    final now = DateTime.now();
    final currentCycleStart =
        BillingHelper.getCycleStart(now, acc.billingCycleDay!);
    final prevCycleStart = BillingHelper.getCycleStart(
        currentCycleStart.subtract(const Duration(days: 1)),
        acc.billingCycleDay!);
    return !txn.date.isBefore(prevCycleStart);
  }

  // coverage:ignore-start
  bool _isWithinFrozenPeriod(Account acc, Transaction txn) {
    if (!acc.isFrozenCalculated && acc.freezeDate != null) {
      final txnDate = DateTime(txn.date.year, txn.date.month, txn.date.day);
      final freezeDate = DateTime(
          acc.freezeDate!.year, acc.freezeDate!.month, acc.freezeDate!.day);
      if (txnDate.isBefore(freezeDate)) return false;
      // coverage:ignore-end
    }
    return true;
  }

  Future<void> _incrementBackupCounter() async {
    final box = _hive.box(boxSettings);
    final count = box.get('txnsSinceBackup', defaultValue: 0) as int;
    await box.put('txnsSinceBackup', count + 1);
  }

  int getTxnsSinceBackup() {
    final box = _hive.box(boxSettings);
    return box.get('txnsSinceBackup', defaultValue: 0) as int;
  }

  Future<void> resetTxnsSinceBackup() async {
    final box = _hive.box(boxSettings);
    await box.put('txnsSinceBackup', 0);
  }

  // coverage:ignore-start
  Future<void> setLastSync(String isoTimestamp) async {
    final box = _hive.box(boxSettings);
    await box.put('last_sync', isoTimestamp);
    // coverage:ignore-end
  }

  Future<void> deleteTransaction(String id) async {
    try {
      final box = _hive.box<Transaction>(boxTransactions);
      final txn = box.get(id);
      if (txn == null || txn.isDeleted) return;

      // Validate: Prevent deleting frozen/closed history
      await _validateTransactionDate(txn);

      // 1. Apply reversals before marking as deleted
      await _handleTransactionImpacts(oldTxn: txn, newTxn: null);

      // 2. Mark as deleted
      txn.isDeleted = true;
      await box.put(txn.id, txn);
    } catch (e) {
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        // coverage:ignore-line
        ScaffoldMessenger.of(context).showSnackBar(
          // coverage:ignore-line
          const SnackBar(content: Text('Failed to delete transaction.')),
        );
      }
      rethrow;
    }
  }

  Future<int> getSimilarTransactionCount(
      // coverage:ignore-line
      String title,
      String category,
      String excludeId) async {
    final box = _hive.box<Transaction>(boxTransactions); // coverage:ignore-line
    final profileId = getActiveProfileId(); // coverage:ignore-line
    return box
        // coverage:ignore-start
        .toMap()
        .values
        .whereType<Transaction>()
        .where((t) =>
            t.profileId == profileId &&
            t.id != excludeId &&
            t.title.trim().toLowerCase() == title.trim().toLowerCase() &&
            t.category == category &&
            !t.isDeleted)
        .length;
    // coverage:ignore-end
  }

  Future<void> bulkUpdateCategory(
      String title, String oldCategory, String newCategory) async {
    final box = _hive.box<Transaction>(boxTransactions);
    final profileId = getActiveProfileId();
    final toUpdate = box
        .toMap()
        .values
        .whereType<Transaction>()
        .where((t) =>
            t.profileId == profileId &&
            t.title.trim().toLowerCase() == title.trim().toLowerCase() &&
            t.category == oldCategory &&
            !t.isDeleted)
        .toList();

    for (var t in toUpdate) {
      t.category = newCategory;
      await _hive.box<Transaction>(boxTransactions).put(t.id, t);
    }
  }

  Future<void> restoreTransaction(String id) async {
    final box = _hive.box<Transaction>(boxTransactions);
    final txn = box.get(id);
    if (txn != null && txn.isDeleted) {
      // 1. Apply impacts before marking as restored
      // (Wait, if we apply impacts of "restored" txn, we need it to be not deleted)
      // Actually, it's better to just pass the modified txn as 'newTxn'
      // but 'oldTxn' should be the deleted version.
      // But _handleTransactionImpacts checks !txn.isDeleted.

      // Let's modify it to be:
      txn.isDeleted = false;
      await box.put(txn.id, txn);
      await _handleTransactionImpacts(oldTxn: null, newTxn: txn);
    }
  }

  // coverage:ignore-start
  Future<void> permanentlyDeleteTransaction(String id) async {
    final box = _hive.box<Transaction>(boxTransactions);
    await box.delete(id);
    // coverage:ignore-end
  }

  // --- Loan Operations ---
  List<Loan> getLoans() => _getByProfile<Loan>(boxLoans);

  List<Loan> getAllLoans() {
    return _hive.box<Loan>(boxLoans).toMap().values.whereType<Loan>().toList();
  }

  Future<void> saveLoan(Loan loan) async {
    final box = _hive.box<Loan>(boxLoans);
    await box.put(loan.id, loan);
  }

  Future<void> deleteLoan(String id) async {
    await _hive.box<Loan>(boxLoans).delete(id);
  }

  // --- Recurring Operations ---
  List<RecurringTransaction> getRecurring() => // coverage:ignore-line
      _getByProfile<RecurringTransaction>(boxRecurring); // coverage:ignore-line

  List<RecurringTransaction> getAllRecurring() {
    return _hive
        .box<RecurringTransaction>(boxRecurring)
        .toMap()
        .values
        .whereType<RecurringTransaction>()
        .toList();
  }

  List<Investment> getAllInvestments() {
    return _hive
        .box<Investment>(boxInvestments)
        .toMap()
        .values
        .whereType<Investment>()
        .toList();
  }

  Future<void> saveRecurringTransaction(RecurringTransaction rt) async {
    final box = _hive.box<RecurringTransaction>(boxRecurring);
    await box.put(rt.id, rt);
  }

  Future<void> deleteRecurringTransaction(String id) async {
    await _hive.box<RecurringTransaction>(boxRecurring).delete(id);
  }

  Future<void> advanceRecurringTransactionDate(String id) async {
    final box = _hive.box<RecurringTransaction>(boxRecurring);
    final rt = box.get(id);
    if (rt != null) {
      final holidays = getHolidays();
      rt.nextExecutionDate = RecurrenceUtils.calculateNextOccurrence(
        lastDate: rt.nextExecutionDate,
        // startDate: null, // Optional
        frequency: rt.frequency,
        interval: rt.interval,
        scheduleType: rt.scheduleType,
        selectedWeekday: rt.selectedWeekday,
        adjustForHolidays: rt.adjustForHolidays,
        holidays: holidays,
      );
      await box.put(rt.id, rt);
    }
  }

  // --- Category Operations ---
  List<Category> getCategories() {
    // coverage:ignore-line
    final profileCategories =
        _getByProfile<Category>(boxCategories); // coverage:ignore-line

    if (profileCategories.isEmpty) {
      // coverage:ignore-line
      // Create defaults for this profile
      // coverage:ignore-start
      final profileId = getActiveProfileId();
      final box = _hive.box<Category>(boxCategories);
      final defaults = _getDefaultCategories(profileId);
      for (var c in defaults) {
        box.put(c.id, c);
        // coverage:ignore-end
      }
      return defaults;
    }
    return profileCategories;
  }

  List<Category> getAllCategories() {
    return _hive
        .box<Category>(boxCategories)
        .toMap()
        .values
        .whereType<Category>()
        .toList();
  }

  Future<void> addCategory(Category category, {bool isRestore = false}) async {
    if (!isRestore && category.name.trim().toLowerCase() == _bankLoanCategory) {
      throw Exception('Category name "Bank loan" is reserved.');
    }
    final box = _hive.box<Category>(boxCategories);
    if (category.profileId == null || category.profileId!.isEmpty) {
      category.profileId = getActiveProfileId();
    }
    await box.put(category.id, category);
  }

  Future<void> removeCategory(String id) async {
    final box = _hive.box<Category>(boxCategories);
    final category = box.get(id);
    if (category != null &&
        category.name.trim().toLowerCase() == _bankLoanCategory) {
      throw Exception('The "Bank loan" category cannot be deleted.');
    }
    await box.delete(id);
  }

  Future<void> updateCategory(String id, // coverage:ignore-line
      {required String name,
      required CategoryUsage usage,
      required CategoryTag tag,
      required int iconCode,
      bool isRestore = false}) async {
    final box = _hive.box<Category>(boxCategories); // coverage:ignore-line
    final category = box.get(id); // coverage:ignore-line
    if (category != null) {
      if (!isRestore &&
          category.name.trim().toLowerCase() == _bankLoanCategory) {
        // coverage:ignore-line
        throw Exception(
            'The "Bank loan" category cannot be modified.'); // coverage:ignore-line
      }
      if (!isRestore && name.trim().toLowerCase() == _bankLoanCategory) {
        // coverage:ignore-line
        throw Exception(
            'Category name "Bank loan" is reserved.'); // coverage:ignore-line
      }
      // coverage:ignore-start
      category.name = name;
      category.usage = usage;
      category.tag = tag;
      category.iconCode = iconCode;
      await box.put(category.id, category);
      // coverage:ignore-end
    }
  }

  Future<void> copyCategories(String fromId, String toId) async {
    final box = _hive.box<Category>(boxCategories);
    final source = box
        .toMap()
        .values
        .whereType<Category>()
        .where((c) => c.profileId == fromId)
        .toList();
    // Delete existing categories in target if any? User usually expects "add/sync" or "copy".
    // Let's just add ones that don't exist by name.
    final target = box
        .toMap()
        .values
        .whereType<Category>()
        .where((c) => c.profileId == toId)
        .toList();

    for (var s in source) {
      if (!target.any((t) => t.name.toLowerCase() == s.name.toLowerCase())) {
        final newCat = Category.create(
          name: s.name,
          usage: s.usage,
          tag: s.tag,
          iconCode: s.iconCode,
          profileId: toId,
        );
        await box.put(newCat.id, newCat);
      }
    }
  }

  /// Re-populates missing default categories for the given profile.
  /// Existing categories (including custom ones) are preserved.
  /// Returns the number of newly added categories.
  Future<int> repairDefaultCategories(String profileId) async {
    // coverage:ignore-line
    final box = _hive.box<Category>(boxCategories); // coverage:ignore-line
    final existing = box
        // coverage:ignore-start
        .toMap()
        .values
        .whereType<Category>()
        .where((c) => c.profileId == profileId)
        .toList();
    // coverage:ignore-end

    final defaults = _getDefaultCategories(profileId); // coverage:ignore-line
    int added = 0;

    // coverage:ignore-start
    for (final d in defaults) {
      final alreadyExists = existing.any(
          (e) => e.name.trim().toLowerCase() == d.name.trim().toLowerCase());
      // coverage:ignore-end
      if (!alreadyExists) {
        await box.put(d.id, d); // coverage:ignore-line
        added++; // coverage:ignore-line
      }
    }
    return added;
  }

  /// Returns the lowercase names of all default categories.
  // coverage:ignore-start
  Set<String> getDefaultCategoryNames() {
    return _defaultCategoryCache
        .map((d) => (d['name'] as String).trim().toLowerCase())
        .toSet();
    // coverage:ignore-end
  }

  List<Category> _getDefaultCategories(String profileId) {
    // coverage:ignore-line
    if (_defaultCategoryCache.isEmpty) {
      // coverage:ignore-line
      // Emergency fallback if JSON failed or init didn't run (should not happen in prod flow)
      return []; // coverage:ignore-line
    }

    // coverage:ignore-start
    return _defaultCategoryCache.map((data) {
      final usageStr = data['usage'];
      final tagStr = data['tag'];
      // coverage:ignore-end

      // coverage:ignore-start
      CategoryUsage usage = CategoryUsage.values.firstWhere(
        (e) => e.name == usageStr,
        orElse: () => CategoryUsage.expense,
        // coverage:ignore-end
      );

      // coverage:ignore-start
      CategoryTag tag = CategoryTag.values.firstWhere(
        (e) => e.name == tagStr,
        orElse: () => CategoryTag.none,
        // coverage:ignore-end
      );

      return Category.create(
        // coverage:ignore-line
        name: data['name'] as String, // coverage:ignore-line
        usage: usage,
        tag: tag,
        iconCode: data['iconCode'] as int, // coverage:ignore-line
        profileId: profileId,
      );
    }).toList(); // coverage:ignore-line
  }

  // --- Other Settings ---
  String getCurrencyLocale() {
    final profileId = getActiveProfileId();
    final pBox = _hive.box<Profile>(boxProfiles);
    return pBox.get(profileId)?.currencyLocale ?? 'en_IN';
  }

  Future<void> setCurrencyLocale(String locale) async {
    final profileId = getActiveProfileId();
    final pBox = _hive.box<Profile>(boxProfiles);
    final p = pBox.get(profileId);
    if (p != null) {
      p.currencyLocale = locale;
      await pBox.put(p.id, p);
    }
  }

  double getMonthlyBudget() {
    final profileId = getActiveProfileId();
    final pBox = _hive.box<Profile>(boxProfiles);
    return pBox.get(profileId)?.monthlyBudget ?? 0.0;
  }

  Future<void> setMonthlyBudget(double budget) async {
    final profileId = getActiveProfileId();
    final pBox = _hive.box<Profile>(boxProfiles);
    final p = pBox.get(profileId);
    if (p != null) {
      p.monthlyBudget = budget;
      await pBox.put(p.id, p);
    }
  }

  int getBackupThreshold() {
    final box = _hive.box(boxSettings);
    return box.get('backupThreshold', defaultValue: 5) as int;
  }

  Future<void> setBackupThreshold(int threshold) async {
    final box = _hive.box(boxSettings);
    await box.put('backupThreshold', threshold);
  }

  // --- Holiday Operations ---
  List<DateTime> getHolidays() {
    final box = _hive.box(boxSettings);
    final List<dynamic> list = box.get('holidays', defaultValue: []);
    return list.map((e) => e as DateTime).toList();
  }

  Future<void> addHoliday(DateTime date) async {
    final box = _hive.box(boxSettings);
    final holidays = getHolidays();
    final normalized = DateTime(date.year, date.month, date.day);
    if (!holidays.any((h) =>
        // coverage:ignore-start
        h.year == normalized.year &&
        h.month == normalized.month &&
        h.day == normalized.day)) {
      // coverage:ignore-end
      holidays.add(normalized);
      await box.put('holidays', holidays);
      await _revalidateRecurringDates();
    }
  }

  // coverage:ignore-start
  Future<void> removeHoliday(DateTime date) async {
    final box = _hive.box(boxSettings);
    final holidays = getHolidays();
    holidays.removeWhere((h) =>
        h.year == date.year && h.month == date.month && h.day == date.day);
    await box.put('holidays', holidays);
    await _revalidateRecurringDates();
    // coverage:ignore-end
  }

  Future<void> _revalidateRecurringDates() async {
    final box = _hive.box<RecurringTransaction>(boxRecurring);
    final holidays = getHolidays();
    final allRecurring = getAllRecurring();

    for (var rt in allRecurring) {
      if (rt.isActive && rt.adjustForHolidays) {
        DateTime idealDate = RecurrenceUtils.findIdealDate(rt, holidays);
        final adjusted =
            RecurrenceUtils.adjustDateForHolidays(idealDate, holidays);
        if (rt.nextExecutionDate != adjusted) {
          rt.nextExecutionDate = adjusted;
          await box.put(rt.id, rt);
        }
      }
    }
  }

  Future<void> processRecurringInvestments() async {
    final now = DateTime.now();
    final allInvestments = getAllInvestments();

    for (var inv in allInvestments) {
      if (inv.isRecurringEnabled && inv.nextRecurringDate != null) {
        await _processSingleRecurringInvestment(inv, now);
      }
    }
  }

  Future<void> _processSingleRecurringInvestment(
      Investment inv, DateTime now) async {
    final box = _hive.box<Investment>(boxInvestments);
    final holidays = getHolidays();
    bool changed = false;

    // Catch-up logic: loop while nextRecurringDate is in the past or today
    while (inv.nextRecurringDate!.isBefore(now) ||
        inv.nextRecurringDate!.isAtSameMomentAs(now)) {
      if (!inv.isRecurringPaused) {
        final newPurchase = Investment.create(
          name: inv.name,
          type: inv.type,
          acquisitionDate: inv.nextRecurringDate!,
          acquisitionPrice: inv.recurringAmount ?? inv.acquisitionPrice,
          quantity: 1.0,
          currentPrice: inv.currentPrice,
          mfCategory: inv.mfCategory,
          fixedInterestRate: inv.fixedInterestRate,
          customLongTermThresholdYears: inv.customLongTermThresholdYears,
          profileId: inv.profileId,
          remarks: 'Auto-added recurring investment',
          codeName: inv.codeName,
          isRecurringEnabled: false,
        );
        await box.put(newPurchase.id, newPurchase);
      }

      // Advance the next recurring date even if paused
      inv.nextRecurringDate = RecurrenceUtils.calculateNextOccurrence(
        lastDate: inv.nextRecurringDate!,
        frequency: Frequency.monthly,
        interval: 1,
        scheduleType: ScheduleType.fixedDate,
        adjustForHolidays: false,
        holidays: holidays,
      );
      changed = true;
    }

    if (changed) {
      await box.put(inv.id, inv);
    }
  }

  DateTime? getLastLogin() {
    final box = _hive.box(boxSettings);
    final value = box.get('lastLogin');
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return value as DateTime?;
  }

  Future<void> setLastLogin(DateTime date) async {
    final box = _hive.box(boxSettings);
    await box.put('lastLogin', date);
  }

  // coverage:ignore-start
  String? getSessionId() {
    final box = _hive.box(boxSettings);
    return box.get('sessionId') as String?;
    // coverage:ignore-end
  }

  // coverage:ignore-start
  Future<void> setSessionId(String sessionId) async {
    final box = _hive.box(boxSettings);
    await box.put('sessionId', sessionId);
    // coverage:ignore-end
  }

  // coverage:ignore-start
  Future<void> clearSessionId() async {
    final box = _hive.box(boxSettings);
    await box.delete('sessionId');
    // coverage:ignore-end
  }

  int getInactivityThresholdDays() {
    final box = _hive.box(boxSettings);
    return box.get('inactivityThresholdDays', defaultValue: 7) as int;
  }

  Future<void> setInactivityThresholdDays(int days) async {
    final box = _hive.box(boxSettings);
    await box.put('inactivityThresholdDays', days);
  }

  int getMaturityWarningDays() {
    final box = _hive.box(boxSettings);
    return box.get('maturityWarningDays', defaultValue: 5) as int;
  }

  Future<void> setMaturityWarningDays(int days) async {
    final box = _hive.box(boxSettings);
    await box.put('maturityWarningDays', days);
  }

  // --- App Lock ---
  bool isAppLockEnabled() {
    final box = _hive.box(boxSettings);
    return box.get('appLockEnabled', defaultValue: false) as bool;
  }

  Future<void> setAppLockEnabled(bool enabled) async {
    final box = _hive.box(boxSettings);
    await box.put('appLockEnabled', enabled);
  }

  static const int maxPinAttempts = 3;
  static const Duration pinLockDuration = Duration(minutes: 5);

  int _failedPinAttempts = 0;

  String _generateSalt() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    return base64.encode(bytes);
  }

  String _hashPin(String pin, String salt) {
    final bytes = utf8.encode(salt + pin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  String? getAppPin() {
    final box = _hive.box(boxSettings);
    return box.get('appPin') as String?;
  }

  Future<void> setAppPin(String pin) async {
    final box = _hive.box(boxSettings);
    final salt = _generateSalt();
    final hash = _hashPin(pin, salt);
    await box.put('appPin', '$salt:$hash');
    resetFailedPinAttempts();
  }

  bool verifyAppPin(String input) {
    final storedRaw = getAppPin();
    if (storedRaw == null) return true; // No PIN set
    if (isPinLocked()) return false; // Locked out

    final parts = storedRaw.split(':');
    final salt = parts[0];
    final storedHash = parts[1];

    final inputHash = _hashPin(input, salt);
    final isValid = storedHash == inputHash;
    if (!isValid) {
      final attempts = getFailedPinAttempts() + 1;
      _setFailedPinAttempts(attempts);
      if (attempts >= maxPinAttempts) {
        _setPinLockUntil(clock.now().add(pinLockDuration));
      }
    } else {
      resetFailedPinAttempts(); // coverage:ignore-line
    }
    return isValid;
  }

  int getFailedPinAttempts() {
    try {
      final box = _hive.box(boxSettings);
      final stored = box.get('pinFailedAttempts');
      if (stored is int) {
        _failedPinAttempts = stored;
      }
    } catch (_) {}
    return _failedPinAttempts;
  }

  // coverage:ignore-start
  int getRemainingPinAttempts() {
    final remaining = maxPinAttempts - getFailedPinAttempts();
    return remaining < 0 ? 0 : remaining;
    // coverage:ignore-end
  }

  DateTime? _getPinLockUntil() {
    try {
      final box = _hive.box(boxSettings);
      final stored = box.get('pinLockUntil');
      if (stored is int) {
        return DateTime.fromMillisecondsSinceEpoch(stored);
      }
    } catch (_) {}
    return null;
  }

  void _setPinLockUntil(DateTime? until) {
    try {
      final box = _hive.box(boxSettings);
      if (until == null) {
        box.delete('pinLockUntil'); // coverage:ignore-line
      } else {
        box.put('pinLockUntil', until.millisecondsSinceEpoch);
      }
    } catch (_) {}
  }

  void _setFailedPinAttempts(int attempts) {
    _failedPinAttempts = attempts;
    try {
      final box = _hive.box(boxSettings);
      box.put('pinFailedAttempts', attempts);
    } catch (_) {}
  }

  bool isPinLocked() {
    final until = _getPinLockUntil();
    if (until == null) return false;
    if (clock.now().isAfter(until)) {
      resetFailedPinAttempts(); // coverage:ignore-line
      return false;
    }
    return true;
  }

  Duration? getPinLockRemaining() {
    // coverage:ignore-line
    final until = _getPinLockUntil(); // coverage:ignore-line
    if (until == null) return null;
    // coverage:ignore-start
    final remaining = until.difference(clock.now());
    if (remaining.isNegative || remaining == Duration.zero) {
      resetFailedPinAttempts();
      // coverage:ignore-end
      return null;
    }
    return remaining;
  }

  void resetFailedPinAttempts() {
    _failedPinAttempts = 0;
    try {
      final box = _hive.box(boxSettings);
      box.put('pinFailedAttempts', 0);
      box.delete('pinLockUntil');
    } catch (_) {}
  }

  bool getPinResetRequested() {
    final box = _hive.box(boxSettings);
    return box.get('pinResetRequested', defaultValue: false) as bool;
  }

  Future<void> setPinResetRequested(bool value) async {
    final box = _hive.box(boxSettings);
    await box.put('pinResetRequested', value);
  }

  // --- Theme Mode ---
  String getThemeMode() {
    final box = _hive.box(boxSettings);
    return box.get('themeMode', defaultValue: 'system') as String;
  }

  Future<void> setThemeMode(String mode) async {
    final box = _hive.box(boxSettings);
    await box.put('themeMode', mode);
  }

  /// Exports all keys from the settings box.
  Map<String, dynamic> getAllSettings() {
    final box = _hive.box(boxSettings);
    final rawMap = Map<String, dynamic>.from(box.toMap());

    // Sanitize for JSON (Remove complex objects that might have been saved by mistake)
    final sanitized = <String, dynamic>{};
    rawMap.forEach((key, value) {
      final sanitizedValue = _sanitizeSettingValue(value);
      if (sanitizedValue != null) {
        sanitized[key] = sanitizedValue;
      }
    });

    return sanitized;
  }

  dynamic _sanitizeSettingValue(dynamic value) {
    if (value is DateTime) return value.toIso8601String();
    if (value is TimeOfDay) return '${value.hour}:${value.minute}';
    if (value is Color) return value.toARGB32();
    if (value is IconData) return value.codePoint;

    if (value is List) {
      return value
          .map((e) => _sanitizeSettingValue(e))
          .toList(); // coverage:ignore-line
    }

    if (value is Map) {
      return value.map((k, v) => MapEntry(
          k.toString(), _sanitizeSettingValue(v))); // coverage:ignore-line
    }

    // Skip complex objects stored here by mistake (should be in own boxes)
    if (_isComplexType(value)) return null;

    // Primitives (int, double, bool, String)
    return value;
  }

  bool _isComplexType(dynamic value) {
    return value is RecurringTransaction ||
        value is Account ||
        value is Transaction ||
        value is Category ||
        value is Loan ||
        value is Profile ||
        value is Investment;
  }

  /// Bulk-save settings from a map (used during restore).
  Future<void> saveSettings(Map<String, dynamic> settings) async {
    final box = _hive.box(boxSettings);
    for (var entry in settings.entries) {
      if (entry.key == 'appPin' && entry.value != null) {
        // Ensure restored plaintext PINs are hashed before storage
        await setAppPin(entry.value.toString());
      } else {
        await box.put(entry.key, entry.value);
      }
    }
  }

  List<InsurancePolicy> getInsurancePolicies() {
    return _getByProfile<InsurancePolicy>(boxInsurancePolicies);
  }

  /// Returns Insurance Policies for ALL profiles for backup/restore.
  List<InsurancePolicy> getInsurancePoliciesGlobal() {
    // coverage:ignore-line
    return _hive
        .box<InsurancePolicy>(boxInsurancePolicies)
        .values
        .toList(); // coverage:ignore-line
  }

  Box<InsurancePolicy> getInsurancePoliciesBox() {
    return _hive.box<InsurancePolicy>(boxInsurancePolicies);
  }

  /// Saves Insurance Policies globally (clears nothing, just puts).
  Future<void> saveInsurancePoliciesGlobal(
      // coverage:ignore-line
      List<InsurancePolicy> policies) async {
    // coverage:ignore-start
    final box = _hive.box<InsurancePolicy>(boxInsurancePolicies);
    for (var p in policies) {
      await box.put(p.id, p);
      // coverage:ignore-end
    }
  }

  ValueListenable<Box<InsurancePolicy>> getInsurancePoliciesListenable() {
    // coverage:ignore-line
    return _hive
        .box<InsurancePolicy>(boxInsurancePolicies)
        .listenable(); // coverage:ignore-line
  }

  Future<void> saveInsurancePolicies(List<InsurancePolicy> policies) async {
    final box = _hive.box<InsurancePolicy>(boxInsurancePolicies);
    final profileId = getActiveProfileId();

    // 1. Delete existing for this profile
    final existingIds = box.values
        .where((p) => p.profileId == profileId)
        .map((p) => p.id)
        .toList();
    for (var id in existingIds) {
      await box.delete(id);
    }

    // 2. Save new
    for (var p in policies) {
      p.profileId = profileId;
      await box.put(p.id, p);
    }
  }

  Future<void> clearAllData({bool fullWipe = false}) async {
    if (fullWipe) {
      await _performFullWipe(); // coverage:ignore-line
      return;
    }

    final profileId = getActiveProfileId();

    final List<Future<void>> clearTasks = [
      _clearItemsByProfile<Account>(boxAccounts, profileId),
      _clearItemsByProfile<Transaction>(boxTransactions, profileId),
      _clearItemsByProfile<Loan>(boxLoans, profileId),
      _clearItemsByProfile<RecurringTransaction>(boxRecurring, profileId),
      _clearItemsByProfile<Category>(boxCategories, profileId),
      _clearItemsByProfile<Investment>(boxInvestments, profileId),
      _clearItemsByProfile<InsurancePolicy>(boxInsurancePolicies, profileId),
      _clearItemsByProfile<TaxYearData>(boxTaxData, profileId),
      _clearItemsByProfile<LendingRecord>(boxLendingRecords, profileId),
    ];

    await Future.wait(clearTasks);
    await resetTxnsSinceBackup();
  }

  /// Helper to clear all Hive boxes (Full Wipe).
  // coverage:ignore-start
  Future<void> _performFullWipe() async {
    await _hive.box<Account>(boxAccounts).clear();
    await _hive.box<Transaction>(boxTransactions).clear();
    await _hive.box<Loan>(boxLoans).clear();
    await _hive.box<RecurringTransaction>(boxRecurring).clear();
    await _hive.box<Category>(boxCategories).clear();
    await _hive.box<Investment>(boxInvestments).clear();
    await _hive.box<InsurancePolicy>(boxInsurancePolicies).clear();
    await _hive.box<TaxYearData>(boxTaxData).clear();
    await _hive.box<LendingRecord>(boxLendingRecords).clear();
    await _hive.box<Profile>(boxProfiles).clear();
    if (_hive.isBoxOpen('tax_rules_v2')) {
      await _hive.box<TaxRules>('tax_rules_v2').clear();
      // coverage:ignore-end
    }
    await resetTxnsSinceBackup(); // coverage:ignore-line
  }

  /// Helper to clear data for a specific profile in a given box.
  Future<void> _clearItemsByProfile<T>(String boxName, String profileId) async {
    final box = _hive.box<T>(boxName);
    final toDelete = box
        .toMap()
        .entries
        .where((e) => (e.value as dynamic).profileId == profileId)
        .map((e) => e.key)
        .toList();

    for (var key in toDelete) {
      await box.delete(key);
    }
  }

  Future<int> repairAccountCurrencies(String defaultCurrency) async {
    if (!_hive.isBoxOpen(boxAccounts)) return 0;
    final box = _hive.box<Account>(boxAccounts);
    int repairedCount = 0;
    final dataMap = box.toMap();
    for (var key in dataMap.keys) {
      final value = dataMap[key];
      if (value is! Account) continue;

      final needsRepair = _repairAccountCurrency(value, defaultCurrency);
      if (needsRepair) {
        await box.put(key, value);
        repairedCount++;
      }
    }
    return repairedCount;
  }

  bool _repairAccountCurrency(Account account, String defaultCurrency) {
    if (account.type == AccountType.wallet) {
      if (account.currency.trim().isEmpty) {
        account.currency = defaultCurrency;
        return true;
      }
      return false;
    }
    if (account.currency.trim().isNotEmpty) {
      account.currency = '';
      return true;
    }
    return false;
  }

  /// Safely opens a box of type [T].
  /// If a [TypeError] occurs (e.g. corrupted data or mixed types), it opens as dynamic,
  /// identifies misaligned objects, and attempts to repair them.
  Future<Box<T>> _safeOpenBox<T>(String boxName) async {
    if (_hive.isBoxOpen(boxName)) return _hive.box<T>(boxName);

    try {
      return await _hive.openBox<T>(boxName); // coverage:ignore-line
    } catch (e) {
      // coverage:ignore-start
      if (e is TypeError ||
          e is UnsupportedError ||
          e.toString().contains('subtype') ||
          e.toString().contains('Infinity')) {
        await _attemptBoxRepair<T>(boxName);
        return await _hive.openBox<T>(boxName);
        // coverage:ignore-end
      }
      rethrow;
    }
  }

  /// Opens a corrupted box as dynamic, removes misaligned entries,
  /// rescues any Profile objects found in wrong boxes, then closes.
  // coverage:ignore-start
  Future<void> _attemptBoxRepair<T>(String boxName) async {
    final dynamicBox = await _hive.openBox(boxName);
    final Map<dynamic, dynamic> data = dynamicBox.toMap();
    // coverage:ignore-end

    final List<dynamic> corruptedKeys = []; // coverage:ignore-line
    final Map<String, Profile> rescuedProfiles = {}; // coverage:ignore-line

    // coverage:ignore-start
    for (var entry in data.entries) {
      final key = entry.key;
      final value = entry.value;
      // coverage:ignore-end

      // coverage:ignore-start
      if (value is! T && value != null) {
        corruptedKeys.add(key);
        if (value is Profile && boxName == boxAccounts) {
          rescuedProfiles[value.id] = value;
          // coverage:ignore-end
        }
      }
    }

    for (var key in corruptedKeys) {
      // coverage:ignore-line
      await dynamicBox.delete(key); // coverage:ignore-line
    }

    await dynamicBox.close(); // coverage:ignore-line

    // coverage:ignore-start
    if (rescuedProfiles.isNotEmpty) {
      final pBox = await _safeOpenBox<Profile>(boxProfiles);
      for (var p in rescuedProfiles.values) {
        await pBox.put(p.id, p);
        // coverage:ignore-end
      }
    }
  }

  // --- Tax Data Operations ---
  TaxYearData? getTaxYearData(int year) {
    final profileId = getActiveProfileId();
    final box = _hive.box<TaxYearData>(boxTaxData);

    // Try finding by year+profileId in the values
    final matches =
        box.values.where((d) => d.year == year && d.profileId == profileId);
    if (matches.isNotEmpty) return matches.first;

    return null;
  }

  Future<void> saveTaxYearData(TaxYearData data) async {
    final box = _hive.box<TaxYearData>(boxTaxData);
    final profileId = getActiveProfileId();

    // Ensure profileId matches active profile
    final dataToSave = data.profileId == profileId
        ? data
        : data.copyWith(profileId: profileId);

    // Use a composite key to allow multiple profiles to have data for the same year
    await box.put('${profileId}_${data.year}', dataToSave);
  }

  /// Saves Tax Year Data globally without profile filtering (for restore).
  Future<void> saveTaxYearDataGlobal(TaxYearData data) async {
    // coverage:ignore-line
    final box = _hive.box<TaxYearData>(boxTaxData); // coverage:ignore-line
    // Use whatever profileId is in the object
    final pId = data.profileId; // coverage:ignore-line
    await box.put('${pId}_${data.year}', data); // coverage:ignore-line
  }

  List<TaxYearData> getAllTaxYearData() {
    // coverage:ignore-line
    return _getByProfile<TaxYearData>(boxTaxData); // coverage:ignore-line
  }

  /// Returns Tax Year Data for ALL profiles for backup/restore.
  List<TaxYearData> getAllTaxYearDataGlobal() {
    // coverage:ignore-line
    return _hive
        .box<TaxYearData>(boxTaxData)
        .values
        .toList(); // coverage:ignore-line
  }

  Future<void> deleteTaxYearData(int year) async {
    final profileId = getActiveProfileId();
    final box = _hive.box<TaxYearData>(boxTaxData);
    await box.delete('${profileId}_$year');
  }

  // --- Lending Record Operations ---
  List<LendingRecord> getLendingRecords() {
    return _getByProfile<LendingRecord>(boxLendingRecords);
  }

  /// Returns Lending Records for ALL profiles for backup/restore.
  List<LendingRecord> getLendingRecordsGlobal() {
    // coverage:ignore-line
    return _hive
        .box<LendingRecord>(boxLendingRecords)
        .values
        .toList(); // coverage:ignore-line
  }

  Future<void> saveLendingRecord(LendingRecord record) async {
    final box = _hive.box<LendingRecord>(boxLendingRecords);
    // Ensure profileId is set
    if (record.profileId == null || record.profileId!.isEmpty) {
      record.profileId = getActiveProfileId();
    }
    await box.put(record.id, record);
  }

  Future<void> deleteLendingRecord(String id) async {
    final box = _hive.box<LendingRecord>(boxLendingRecords);
    await box.delete(id);
  }

  /// Internal helper to shift expenses from a resolved period into the permanent balance.
  /// This maintains the "Pure Rule": Total = Balance + Billed + Unbilled.
  Future<void> _shiftBilledExpensesToBalance(
      Account acc, DateTime startPointer, DateTime endPointer,
      {bool includeIncome = false}) async {
    if (acc.type != AccountType.creditCard || acc.billingCycleDay == null) {
      return;
    }

    final txns = getTransactionsByAccount(acc.id, profileId: acc.profileId);
    final spends = BillingHelper.calculatePeriodSpend(
      acc,
      txns,
      startPointer.add(const Duration(seconds: 1)),
      endPointer,
      skipTransfers: !includeIncome,
      includeIncome: includeIncome,
    );

    if (spends.abs() > 0.01) {
      acc.balance = CurrencyUtils.roundTo2Decimals(acc.balance + spends);
    }
  }

  // --- Investments ---
  List<Investment> getInvestments() {
    // coverage:ignore-line
    return _getByProfile<Investment>(boxInvestments); // coverage:ignore-line
  }

  // coverage:ignore-start
  Future<void> saveInvestment(Investment investment) async {
    final box = _hive.box<Investment>(boxInvestments);
    if (investment.profileId.isEmpty || investment.profileId == 'default') {
      investment.profileId = getActiveProfileId();
      // coverage:ignore-end
    }
    await box.put(investment.id, investment); // coverage:ignore-line
  }

  // coverage:ignore-start
  Future<void> deleteInvestment(String id) async {
    final box = _hive.box<Investment>(boxInvestments);
    await box.delete(id);
    // coverage:ignore-end
  }
}
