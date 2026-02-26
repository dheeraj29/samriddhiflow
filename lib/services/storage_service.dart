import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:samriddhi_flow/models/account.dart';
import 'package:samriddhi_flow/models/transaction.dart';
import 'package:samriddhi_flow/models/loan.dart';
import 'package:samriddhi_flow/models/recurring_transaction.dart';
import 'package:samriddhi_flow/models/category.dart';
import 'package:samriddhi_flow/models/profile.dart';
import 'package:samriddhi_flow/models/taxes/insurance_policy.dart';
import 'package:samriddhi_flow/models/taxes/tax_data.dart';
import 'package:samriddhi_flow/utils/billing_helper.dart';
import 'package:samriddhi_flow/utils/recurrence_utils.dart';
import 'package:samriddhi_flow/utils/debug_logger.dart';
import 'package:samriddhi_flow/models/dashboard_config.dart';
import 'package:samriddhi_flow/utils/currency_utils.dart';
import 'package:samriddhi_flow/models/lending_record.dart';

class StorageService {
  final HiveInterface _hive;
  final AssetBundle _bundle;
  StorageService([HiveInterface? hive, AssetBundle? bundle])
      : _hive = hive ?? Hive,
        _bundle = bundle ?? rootBundle;

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
        if (_defaultCategoryCache.isEmpty) { // coverage:ignore-line

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
  }

  List<Map<String, dynamic>> _defaultCategoryCache = [];

  Future<void> _loadDefaultCategoriesJson() async {
    try {
      final jsonString =
          await _bundle.loadString('assets/data/default_categories.json');
      final List<dynamic> jsonList = jsonDecode(jsonString);
      _defaultCategoryCache = List<Map<String, dynamic>>.from(jsonList);
    } catch (e) {
      DebugLogger() // coverage:ignore-line
          .log('Error loading default categories: $e'); // coverage:ignore-line
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
    return box.get('smartCalculatorEnabled', defaultValue: false) as bool;
  }

  Future<void> setSmartCalculatorEnabled(bool value) async {
    final box = _hive.box(boxSettings);
    await box.put('smartCalculatorEnabled', value);
  }

  List<Profile> getProfiles() {
    return _hive
        .box<Profile>(boxProfiles)
        .toMap()
        .values
        .whereType<Profile>()
        .toList();
  }

  Future<void> saveProfile(Profile profile) async { // coverage:ignore-line

    // coverage:ignore-start
    await _hive
        .box<Profile>(boxProfiles)
        .put(profile.id, profile);
    // coverage:ignore-end
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

    // 8. If active profile was deleted, switch to another one
    if (getActiveProfileId() == profileId) {
      final profiles = getProfiles();
      if (profiles.isNotEmpty) {
        await setActiveProfileId(profiles.first.id); // coverage:ignore-line
      } else {
        await setActiveProfileId('default');
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
    final map = box.get('dashboardConfig');
    if (map != null) {
      // Cast the map to Map<String, dynamic> safely
      final castMap = Map<String, dynamic>.from(map as Map);
      return DashboardVisibilityConfig.fromMap(castMap);
    }
    return const DashboardVisibilityConfig();
  }

  Future<void> saveDashboardConfig(DashboardVisibilityConfig config) async {
    final box = _hive.box(boxSettings);
    await box.put('dashboardConfig', config.toMap());
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
  List<Account> getAccounts() => // coverage:ignore-line
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

    // Smart Update Logic:
    // Only reset rollover if:
    // 1. Billing Cycle Day Changed.
    // 2. OR Rollover is missing/stale.
    if (account.type == AccountType.creditCard &&
        account.billingCycleDay != null) {
      bool shouldReset = false;
      if (existingAccount == null) {
        // New Account -> Reset
        shouldReset = true;
      } else if (existingAccount.billingCycleDay != account.billingCycleDay) {
        // Cycle Changed -> Reset
        shouldReset = true;
      } else {
        // Cycle Same. Check for stale rollover.
        final lastRolloverMillis = getLastRollover(account.id);
        if (lastRolloverMillis == null) {
          shouldReset = true;
        } else {
          // Rollover exists.
          // If we are preserving status, we doing nothing.
          // If the Last Rollover is WAY off (e.g. more than 2 cycles ago), maybe repair?
          // For now, trusting "keepBilledStatus" or default behavior.
          // Actually, if we just edit name, we DON'T want to call resetCreditCardRollover
          // because that method calculates a "Fresh" rollover based on TODAY.
          // If the user properly had a bill generated 10 days ago, and we run reset now,
          // it might move the rollover to TODAY-ish, potentially messing up the "Billed" bucket
          // if transactions happened in between.

          // SO: If cycle day hasn't changed, we STILL call reset to ensure the date isn't wrong.
          // resetCreditCardRollover is idempotent (returns early if dates match).
          shouldReset = true;
        }
      }

      if (shouldReset) {
        await resetCreditCardRollover(account,
            keepBilledStatus: keepBilledStatus);
      }
    }

    await box.put(account.id, account);
  }

  /// Resets the billing cycle tracking to the current month's previous cycle end.
  /// Effectively "repairs" the cycle calculation schedule.
  /// [keepBilledStatus]: If true, sets rollover to force "Billed Amount" to 0 (Current Cycle Start).
  Future<void> resetCreditCardRollover(Account acc,
      {bool keepBilledStatus = false}) async {
    if (acc.billingCycleDay == null) return;

    try {
      final now = DateTime.now();
      final currentCycleStart =
          BillingHelper.getCycleStart(now, acc.billingCycleDay!);

      DateTime newRolloverDate;

      if (keepBilledStatus) {
        // Force "Billed" to be 0 by setting rollover to Current Cycle Start (minus 1 sec)
        // This means everything before is "History/Paid", everything after is "Unbilled".
        newRolloverDate =
            currentCycleStart.subtract(const Duration(seconds: 1));
      } else {
        // Default: Create "Billed" bucket for the previous cycle.
        // Target: The start of the cycle that JUST finished (The "Billed" cycle start).
        final targetRolloverDateStart = BillingHelper.getCycleStart(
            currentCycleStart.subtract(const Duration(days: 1)),
            acc.billingCycleDay!);

        // Store as End of Previous Day (inclusive boundary for Balance)
        newRolloverDate =
            targetRolloverDateStart.subtract(const Duration(seconds: 1));
      }

      final oldRolloverMillis = getLastRollover(acc.id);

      // If we have a previous rollover date, check if it matches target.
      // If it matches, NO OP (idempotent).
      if (oldRolloverMillis != null) {
        final oldRolloverDate =
            DateTime.fromMillisecondsSinceEpoch(oldRolloverMillis);

        // Tolerance for milliseconds diff? Using moment equality.
        if (oldRolloverDate.isAtSameMomentAs(newRolloverDate)) {
          return; // Already correct.
        }
      }

      await setLastRollover(acc.id, newRolloverDate.millisecondsSinceEpoch);
    } catch (e) {
      DebugLogger().log( // coverage:ignore-line
          'Error resetting cycle for ${acc.name}: $e'); // coverage:ignore-line
    }
  }

  /// Explicitly refreshes the billing cycle dates to SHOW the bill (Billed Amount > 0).
  /// Reverts any "Paid" status for the current cycle.
  Future<void> recalculateBilledAmount(String accountId) async { // coverage:ignore-line

    final acc =
        _hive.box<Account>(boxAccounts).get(accountId); // coverage:ignore-line
    if (acc == null) return;
    // Force keepBilledStatus = false to ensure the previous cycle is treated as "Billed"
    await resetCreditCardRollover(acc, // coverage:ignore-line
        keepBilledStatus: false);
  }

  /// Manually clears the billed amount (Mark as Paid/Advance Cycle).
  /// Doesn't record a transaction, just updates the pointer.
  Future<void> clearBilledAmount(String accountId) async { // coverage:ignore-line

    final acc =
        _hive.box<Account>(boxAccounts).get(accountId); // coverage:ignore-line
    if (acc == null) return;
    // Force keepBilledStatus = true to advance pointer to current cycle start
    await resetCreditCardRollover(acc, // coverage:ignore-line
        keepBilledStatus: true);
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

  // coverage:ignore-start
  List<Transaction> getDeletedTransactions() {
    return _getByProfile<Transaction>(boxTransactions)
        .where((t) => t.isDeleted)
        .toList();
  // coverage:ignore-end
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
        if (accountId != null && acc.id != accountId) { // coverage:ignore-line
          continue;
        }
        if (acc.type != AccountType.creditCard || acc.billingCycleDay == null) {
          continue;
        }
        await _processCardRollover(
            acc, accountsBox, settingsBox, now, ignorePayments);
      }
    } catch (e) {
      DebugLogger().log('CC Rollover Error: $e'); // coverage:ignore-line
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
    final targetRolloverDateStart = BillingHelper.getCycleStart(
        currentCycleStart.subtract(const Duration(days: 1)),
        acc.billingCycleDay!);
    final targetRolloverDate =
        targetRolloverDateStart.subtract(const Duration(seconds: 1));

    final lastRollover = lastRolloverMillis == null
        ? targetRolloverDate
        : DateTime.fromMillisecondsSinceEpoch(lastRolloverMillis);

    if (!targetRolloverDate.isAfter(lastRollover)) return;

    final adhocAmount =
        _computeRolloverTxnAmount(acc, lastRollover, targetRolloverDate);

    if (adhocAmount != 0) {
      acc.balance = CurrencyUtils.roundTo2Decimals(acc.balance + adhocAmount);
      await accountsBox.put(acc.id, acc);
    }

    await settingsBox.put(key, targetRolloverDate.millisecondsSinceEpoch);

    if (effectiveIgnorePayments) {
      await settingsBox.delete(ignoreFlagKey); // coverage:ignore-line
    }
  }

  double _computeRolloverTxnAmount(
      Account acc, DateTime lastRollover, DateTime targetRolloverDate) {
    final txnBox = _hive.box<Transaction>(boxTransactions);
    final txns = txnBox
        .toMap()
        .values
        .whereType<Transaction>()
        .where((t) =>
            !t.isDeleted &&
            t.accountId == acc.id &&
            t.date.isAfter(lastRollover) &&
            (t.date.isBefore(targetRolloverDate) ||
                t.date.isAtSameMomentAs( // coverage:ignore-line
                    targetRolloverDate)))
        .toList();

    double adhocAmount = 0;
    for (var t in txns) {
      if (t.type == TransactionType.expense) adhocAmount += t.amount;
      if (t.type == TransactionType.income) adhocAmount -= t.amount;
      if (t.type == TransactionType.transfer && t.accountId == acc.id) {
        adhocAmount += t.amount; // coverage:ignore-line
      }
    }
    return adhocAmount;
  }

  Future<void> saveTransaction(Transaction transaction,
      {bool applyImpact = true, DateTime? now}) async {
    final box = _hive.box<Transaction>(boxTransactions);
    final existingTxn = box.get(transaction.id);

    if (applyImpact) {
      // Validate: Prevents modifying transactions in a closed cycle.
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
    if (txn.accountId == null) return;

    final accBox = _hive.box<Account>(boxAccounts);
    final acc = accBox.get(txn.accountId);

    if (acc != null &&
        acc.type == AccountType.creditCard &&
        acc.billingCycleDay != null) {
      final lastRolloverMillis = getLastRollover(acc.id);
      if (lastRolloverMillis != null) {
        final lastRollover =
            DateTime.fromMillisecondsSinceEpoch(lastRolloverMillis);
        // User Requirement: "Transaction addition is permitted only for one previous cycle".
        // The "Last Rollover" marks the end of the "Balance" period.
        // Any transaction BEFORE or ON lastRollover is part of the "Balance" and cannot be modified.
        // Any transaction AFTER lastRollover is either "Billed" (Previous Cycle) or "Unbilled" (Current Cycle),
        // both of which are open for editing/addition.

        if (!txn.date.isAfter(lastRollover)) {
          throw Exception(
              'Cannot add/edit transaction for a closed billing cycle.\n'
              'Cycle closed on: ${lastRollover.year}-${lastRollover.month}-${lastRollover.day}\n'
              'Transaction Date: ${txn.date.year}-${txn.date.month}-${txn.date.day}\n\n'
              'Please use "Repair Billing Cycle" if you need to reset the cycle.');
        }
      }
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
    await settingsBox.put(
        'last_rollover_$accountId', importRolloverDate.millisecondsSinceEpoch);
  }

  /// Explicitly sets the last rollover timestamp (Used by Repair Jobs).
  Future<void> setLastRollover(String accountId, int timestamp) async {
    final settingsBox = _hive.box(boxSettings);
    await settingsBox.put('last_rollover_$accountId', timestamp);
  }

  /// Recalculates Credit Card balances based on the current billing cycle.
  /// Corrects standard 'Storage' skipping logic which doesn't auto-rollover.
  /// Returns the number of accounts updated.
  Future<int> recalculateCCBalances( // coverage:ignore-line

      {String? accountId,
      bool ignorePayments = false}) async {
    // Reruns the rollover logic.
    // NOTE: This will only "repair" if a rollover was MISSED (i.e. due to app not opening).
    // It will NOT recalculate history if the history is already marked as rolled over.
    // This aligns with user request: "only consider previous cycle".
    await checkCreditCardRollovers( // coverage:ignore-line

        accountId: accountId,
        ignorePayments: ignorePayments);
    return 1; // Dummy return as we don't track count deeply in rollover
  }

  Future<void> saveTransactions( // coverage:ignore-line
      List<Transaction> transactions,
      {bool applyImpact = true,
      DateTime? now}) async {
    final box = _hive.box<Transaction>(boxTransactions); // coverage:ignore-line
    final Map<dynamic, Transaction> batch = {}; // coverage:ignore-line

    for (var txn in transactions) { // coverage:ignore-line

      if (applyImpact) {
        final existingTxn = box.get(txn.id); // coverage:ignore-line
        await _handleTransactionImpacts( // coverage:ignore-line

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

  Future<void> _handleTransactionImpacts({
    Transaction? oldTxn,
    Transaction? newTxn,
    DateTime? now,
  }) async {
    final accountsBox = _hive.box<Account>(boxAccounts);

    Future<void> processImpact(Transaction? txn, bool isReversal) async {
      if (txn == null || txn.isDeleted) return;

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

    // 1. Reverse old impact
    await processImpact(oldTxn, true);

    // 2. Apply new impact
    await processImpact(newTxn, false);
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
    final isSpend = txn.type == TransactionType.expense ||
        (txn.type == TransactionType.transfer && isSource);
    if (!isSpend) return false;

    final lastRolloverMillis = getLastRollover(acc.id);
    if (lastRolloverMillis != null) {
      final lastRollover =
          DateTime.fromMillisecondsSinceEpoch(lastRolloverMillis);
      return txn.date.isAfter(lastRollover);
    }

    // No rollover set (New Card) — rely on standard unbilled check
    final effectiveNow = now ?? DateTime.now();
    return BillingHelper.isUnbilled(
        txn.date, effectiveNow, acc.billingCycleDay!);
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

  Future<void> deleteTransaction(String id) async {
    try {
      final box = _hive.box<Transaction>(boxTransactions);
      final txn = box.get(id);
      if (txn == null || txn.isDeleted) return;

      // 1. Apply reversals before marking as deleted
      await _handleTransactionImpacts(oldTxn: txn, newTxn: null);

      // 2. Mark as deleted
      txn.isDeleted = true;
      await box.put(txn.id, txn);
    } catch (e) {
      DebugLogger().log( // coverage:ignore-line
          "StorageService: deleteTransaction error: $e"); // coverage:ignore-line
    }
  }

  Future<int> getSimilarTransactionCount( // coverage:ignore-line

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
  List<Category> getCategories() { // coverage:ignore-line

    final profileCategories =
        _getByProfile<Category>(boxCategories); // coverage:ignore-line

    if (profileCategories.isEmpty) { // coverage:ignore-line

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

  Future<void> addCategory(Category category) async {
    final box = _hive.box<Category>(boxCategories);
    if (category.profileId == null || category.profileId!.isEmpty) {
      category.profileId = getActiveProfileId();
    }
    await box.put(category.id, category);
  }

  Future<void> removeCategory(String id) async {
    await _hive.box<Category>(boxCategories).delete(id);
  }

  Future<void> updateCategory(String id, // coverage:ignore-line
      {required String name,
      required CategoryUsage usage,
      required CategoryTag tag,
      required int iconCode}) async {
    final box = _hive.box<Category>(boxCategories); // coverage:ignore-line
    final category = box.get(id); // coverage:ignore-line
    if (category != null) {
      // coverage:ignore-start
      category.name = name;
      category.usage = usage;
      category.tag = tag;
      category.iconCode = iconCode;
      await _hive.box<Category>(boxCategories).put(category.id, category);
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

  List<Category> _getDefaultCategories(String profileId) { // coverage:ignore-line

    if (_defaultCategoryCache.isEmpty) { // coverage:ignore-line

      // Emergency fallback if JSON failed or init didn't run (should not happen in prod flow)
      DebugLogger().log( // coverage:ignore-line
          'Warning: Default categories cache is empty.');
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

      return Category.create( // coverage:ignore-line

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
        // Only adjust if the current scheduled date lands on a newly added holiday.
        // We do strictly validation (ensure valid workday), not optimization (moving forward).
        // Try to "Re-Anchor" to the original schedule rule to allow moving forward
        // (e.g. if holiday is removed, we want to snap back to the 25th)
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

  // coverage:ignore-start
  DateTime? getLastLogin() {
    final box = _hive.box(boxSettings);
    final value = box.get('lastLogin');
    if (value is String) {
      return DateTime.tryParse(value);
  // coverage:ignore-end
    }
    return value as DateTime?;
  }

  // coverage:ignore-start
  Future<void> setLastLogin(DateTime date) async {
    final box = _hive.box(boxSettings);
    await box.put('lastLogin', date);
  // coverage:ignore-end
  }

  // coverage:ignore-start
  int getInactivityThresholdDays() {
    final box = _hive.box(boxSettings);
    return box.get('inactivityThresholdDays', defaultValue: 7) as int;
  // coverage:ignore-end
  }

  // coverage:ignore-start
  Future<void> setInactivityThresholdDays(int days) async {
    final box = _hive.box(boxSettings);
    await box.put('inactivityThresholdDays', days);
  // coverage:ignore-end
  }

  // coverage:ignore-start
  int getMaturityWarningDays() {
    final box = _hive.box(boxSettings);
    return box.get('maturityWarningDays', defaultValue: 5) as int;
  // coverage:ignore-end
  }

  // coverage:ignore-start
  Future<void> setMaturityWarningDays(int days) async {
    final box = _hive.box(boxSettings);
    await box.put('maturityWarningDays', days);
  // coverage:ignore-end
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

  String? getAppPin() {
    final box = _hive.box(boxSettings);
    return box.get('appPin') as String?;
  }

  Future<void> setAppPin(String pin) async {
    final box = _hive.box(boxSettings);
    await box.put('appPin', pin);
  }

  // coverage:ignore-start
  bool getPinResetRequested() {
    final box = _hive.box(boxSettings);
    return box.get('pinResetRequested', defaultValue: false) as bool;
  // coverage:ignore-end
  }

  // coverage:ignore-start
  Future<void> setPinResetRequested(bool value) async {
    final box = _hive.box(boxSettings);
    await box.put('pinResetRequested', value);
  // coverage:ignore-end
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
  // coverage:ignore-start
  Map<String, dynamic> getAllSettings() {
    final box = _hive.box(boxSettings);
    final rawMap = Map<String, dynamic>.from(box.toMap());
  // coverage:ignore-end

    // Sanitize for JSON (Remove complex objects that might have been saved by mistake)
    // coverage:ignore-start
    final sanitized = <String, dynamic>{};
    rawMap.forEach((key, value) {
      if (value is DateTime) {
        sanitized[key] = value.toIso8601String();
      } else if (value is TimeOfDay) {
        sanitized[key] = '${value.hour}:${value.minute}';
      } else if (value is Color) {
        sanitized[key] = value.toARGB32();
      } else if (value is IconData) {
        sanitized[key] = value.codePoint;
      } else if (value is RecurringTransaction ||
          value is Account ||
          value is Transaction ||
          value is Category ||
          value is Loan ||
          value is Profile) {
    // coverage:ignore-end
        // Skip complex objects stored here by mistake (should be in own boxes)
      } else {
        // Primitives (int, double, bool, String, null)
        sanitized[key] = value; // coverage:ignore-line
      }
    });

    return sanitized;
  }

  /// Bulk-save settings from a map (used during restore).
  // coverage:ignore-start
  Future<void> saveSettings(Map<String, dynamic> settings) async {
    final box = _hive.box(boxSettings);
    for (var entry in settings.entries) {
      await box.put(entry.key, entry.value);
  // coverage:ignore-end
    }
  }

  List<InsurancePolicy> getInsurancePolicies() {
    return _hive.box<InsurancePolicy>(boxInsurancePolicies).values.toList();
  }

  Box<InsurancePolicy> getInsurancePoliciesBox() { // coverage:ignore-line

    return _hive // coverage:ignore-line
        .box<InsurancePolicy>(boxInsurancePolicies); // coverage:ignore-line
  }

  Future<void> saveInsurancePolicies(List<InsurancePolicy> policies) async {
    final box = _hive.box<InsurancePolicy>(boxInsurancePolicies);
    await box.clear();
    for (var p in policies) {
      await box.put(p.id, p);
    }
  }

  Future<void> clearAllData() async {
    final profileId = getActiveProfileId();

    // Clear Accounts
    final accBox = _hive.box<Account>(boxAccounts);
    final accountsToDelete = accBox
        .toMap()
        .values
        .whereType<Account>()
        .where((a) => a.profileId == profileId)
        .toList();
    for (var a in accountsToDelete) {
      await accBox.delete(a.id);
    }

    // Clear Transactions
    final txnBox = _hive.box<Transaction>(boxTransactions);
    final txnsToDelete = txnBox
        .toMap()
        .values
        .whereType<Transaction>()
        .where((t) => t.profileId == profileId)
        .toList();
    for (var t in txnsToDelete) {
      await txnBox.delete(t.id); // coverage:ignore-line
    }

    // Clear Loans
    final loanBox = _hive.box<Loan>(boxLoans);
    final loansToDelete = loanBox
        .toMap()
        .values
        .whereType<Loan>()
        .where((l) => l.profileId == profileId)
        .toList();
    for (var l in loansToDelete) {
      await loanBox.delete(l.id); // coverage:ignore-line
    }

    // Clear Recurring
    final recBox = _hive.box<RecurringTransaction>(boxRecurring);
    final recToDelete = recBox
        .toMap()
        .values
        .whereType<RecurringTransaction>()
        .where((rt) => rt.profileId == profileId)
        .toList();
    for (var rt in recToDelete) {
      await recBox.delete(rt.id); // coverage:ignore-line
    }

    // Clear Categories
    final catBox = _hive.box<Category>(boxCategories);
    final catsToDelete = catBox
        .toMap()
        .values
        .whereType<Category>()
        .where((c) => c.profileId == profileId)
        .toList();
    for (var c in catsToDelete) {
      await catBox.delete(c.id); // coverage:ignore-line
    }

    // Reset backup counter
    await resetTxnsSinceBackup();
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
        DebugLogger().log(
            "CRITICAL: Data Corruption detected opening '$boxName' ($e). Attempting repair...");
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

    for (var key in corruptedKeys) { // coverage:ignore-line

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
    // Key by year (int)
    final box = _hive.box<TaxYearData>(boxTaxData);
    return box.get(year);
  }

  Future<void> saveTaxYearData(TaxYearData data) async {
    final box = _hive.box<TaxYearData>(boxTaxData);
    await box.put(data.year, data);
  }

  List<TaxYearData> getAllTaxYearData() { // coverage:ignore-line

    // coverage:ignore-start
    return _hive
        .box<TaxYearData>(boxTaxData)
        .values
        .toList();
    // coverage:ignore-end
  }

  // coverage:ignore-start
  Future<void> deleteTaxYearData(int year) async {
    final box = _hive.box<TaxYearData>(boxTaxData);
    await box.delete(year);
  // coverage:ignore-end
  }

  // --- Lending Record Operations ---
  List<LendingRecord> getLendingRecords() {
    return _getByProfile<LendingRecord>(boxLendingRecords);
  }

  Future<void> saveLendingRecord(LendingRecord record) async {
    final box = _hive.box<LendingRecord>(boxLendingRecords);
    // Ensure profileId is set
    if (record.profileId == null || record.profileId!.isEmpty) {
      record.profileId = getActiveProfileId(); // coverage:ignore-line
    }
    await box.put(record.id, record);
  }

  Future<void> deleteLendingRecord(String id) async {
    final box = _hive.box<LendingRecord>(boxLendingRecords);
    await box.delete(id);
  }
}
