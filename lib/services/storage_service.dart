import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import '../models/account.dart';
import '../models/transaction.dart';
import '../utils/billing_helper.dart';
import '../utils/recurrence_utils.dart'; // Added import
import '../models/loan.dart';
import '../models/recurring_transaction.dart';
import '../models/category.dart';
import '../models/profile.dart';
import '../utils/debug_logger.dart';
import '../utils/currency_utils.dart';

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

  Future<void> init() async {
    // Load default categories JSON into memory
    await _loadDefaultCategoriesJson();

    if (!_hive.isBoxOpen(boxAccounts)) {
      await _hive.openBox<Account>(boxAccounts);
    }
    if (!_hive.isBoxOpen(boxTransactions)) {
      await _hive.openBox<Transaction>(boxTransactions);
    }
    if (!_hive.isBoxOpen(boxLoans)) await _hive.openBox<Loan>(boxLoans);
    if (!_hive.isBoxOpen(boxRecurring)) {
      await _hive.openBox<RecurringTransaction>(boxRecurring);
    }
    if (!_hive.isBoxOpen(boxSettings)) await _hive.openBox(boxSettings);
    if (!_hive.isBoxOpen(boxProfiles)) {
      await _hive.openBox<Profile>(boxProfiles);
    }
    if (!_hive.isBoxOpen(boxCategories)) {
      await _hive.openBox<Category>(boxCategories);
    }

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
        // Cache should be loaded by now if init() completed fully.
        // If not, we await loading here (just in case migration happens before cache is ready, though init handles flow).
        if (_defaultCategoryCache.isEmpty) {
          await _loadDefaultCategoriesJson();
        }
        final defaults = _getDefaultCategories('default');
        for (var c in defaults) {
          await cBox.put(c.id, c);
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
      DebugLogger().log('Error loading default categories: $e');
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
    return _hive.box<Profile>(boxProfiles).values.whereType<Profile>().toList();
  }

  Future<void> saveProfile(Profile profile) async {
    await _hive.box<Profile>(boxProfiles).put(profile.id, profile);
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

    // 7. If active profile was deleted, switch to another one
    if (getActiveProfileId() == profileId) {
      final profiles = getProfiles();
      if (profiles.isNotEmpty) {
        await setActiveProfileId(profiles.first.id);
      } else {
        await setActiveProfileId('default');
      }
    }
  }

  Future<void> _deleteItemsByProfile<T>(String boxName, String profileId,
      {Future<void> Function(T)? onBeforeDelete}) async {
    final box = _hive.box<T>(boxName);
    // Values is an iterable, we enable 'cast' if needed via dynamic check or strict type
    // Since we can't easily rely on a common interface for 'profileId' without mixins,
    // we use dynamic access safely as done in _getByProfile
    final itemsToDelete = box.values.where((item) {
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
    return _hive.box<T>(boxName).values.where((item) {
      if (item is Account) return item.profileId == profileId;
      if (item is Transaction) return item.profileId == profileId;
      if (item is Loan) return item.profileId == profileId;
      if (item is RecurringTransaction) return item.profileId == profileId;
      if (item is Category) return item.profileId == profileId;
      try {
        return (item as dynamic).profileId == profileId;
      } catch (_) {
        return false;
      }
    }).toList();
  }

  // --- Account Operations ---
  List<Account> getAccounts() => _getByProfile<Account>(boxAccounts);

  List<Account> getAllAccounts() {
    return _hive.box<Account>(boxAccounts).values.whereType<Account>().toList();
  }

  Future<void> saveAccount(Account account) async {
    final box = _hive.box<Account>(boxAccounts);
    await box.put(account.id, account);
  }

  Future<void> deleteAccount(String id) async {
    final box = _hive.box<Account>(boxAccounts);
    final account = box.get(id);
    if (account != null && account.type == AccountType.wallet) {
      // Cascade delete transactions for wallet
      final txnsBox = _hive.box<Transaction>(boxTransactions);
      final associatedTxns = txnsBox.values
          .where((t) => t.accountId == id || t.toAccountId == id)
          .toList();
      for (var t in associatedTxns) {
        await txnsBox.delete(t.id);
      }
    }
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

  List<Transaction> getAllTransactions() {
    return _hive
        .box<Transaction>(boxTransactions)
        .values
        .whereType<Transaction>()
        .toList();
  }

  List<Transaction> getDeletedTransactions() {
    return _getByProfile<Transaction>(boxTransactions)
        .where((t) => t.isDeleted)
        .toList();
  }

  // --- Rollover Logic ---
  static bool _isCheckingRollover = false;

  Future<void> checkCreditCardRollovers({DateTime? nowOverride}) async {
    if (_isCheckingRollover) return;
    _isCheckingRollover = true;

    try {
      final accountsBox = _hive.box<Account>(boxAccounts);
      final accounts = accountsBox.values.toList(); // Run for ALL profiles
      final settingsBox = _hive.box(boxSettings);
      final now = nowOverride ?? DateTime.now();

      for (var acc in accounts) {
        if (acc.type == AccountType.creditCard && acc.billingCycleDay != null) {
          final key = 'last_rollover_${acc.id}';
          final lastRolloverMillis = settingsBox.get(key);

          DateTime lastRollover;
          final currentCycleStart =
              BillingHelper.getCycleStart(now, acc.billingCycleDay!);

          if (lastRolloverMillis == null) {
            // New card or first time check: initialize to the start of current cycle
            await settingsBox.put(
                key, currentCycleStart.millisecondsSinceEpoch);
            continue;
          } else {
            lastRollover =
                DateTime.fromMillisecondsSinceEpoch(lastRolloverMillis);
          }

          if (currentCycleStart.isAfter(lastRollover)) {
            // There are pending cycles to roll over
            final txnBox = _hive.box<Transaction>(boxTransactions);

            // Fetch txns: (lastRollover, currentCycleStart]
            final txns = txnBox.values
                .where((t) =>
                    !t.isDeleted &&
                    t.accountId == acc.id &&
                    t.date.isAfter(lastRollover) &&
                    (t.date.isBefore(currentCycleStart) ||
                        t.date.isAtSameMomentAs(currentCycleStart)))
                .toList();

            double adhocAmount = 0;
            for (var t in txns) {
              if (t.type == TransactionType.expense) adhocAmount += t.amount;
              if (t.type == TransactionType.income) adhocAmount -= t.amount;
              if (t.type == TransactionType.transfer) {
                // If CC is source, balance increases
                if (t.accountId == acc.id) adhocAmount += t.amount;
              }
            }

            // Also check if CC was the TARGET of a transfer (payment)
            final payments = txnBox.values
                .where((t) =>
                    !t.isDeleted &&
                    t.type == TransactionType.transfer &&
                    t.toAccountId != null &&
                    t.toAccountId == acc.id &&
                    t.date.isAfter(lastRollover) &&
                    (t.date.isBefore(currentCycleStart) ||
                        t.date.isAtSameMomentAs(currentCycleStart)))
                .toList();

            for (var p in payments) {
              adhocAmount -= p.amount;
            }

            if (adhocAmount != 0) {
              acc.balance =
                  CurrencyUtils.roundTo2Decimals(acc.balance + adhocAmount);
              await accountsBox.put(acc.id, acc);
            }

            // Mark as rolled over to the current cycle start
            await settingsBox.put(
                key, currentCycleStart.millisecondsSinceEpoch);

            DebugLogger().log(
                'CC Rollover: ${acc.name} updated by $adhocAmount. New Balance: ${acc.balance}');
          }
        }
      }
    } catch (e) {
      DebugLogger().log('CC Rollover Error: $e');
    } finally {
      _isCheckingRollover = false;
    }
  }

  Future<void> saveTransaction(Transaction transaction,
      {bool applyImpact = true, DateTime? now}) async {
    final box = _hive.box<Transaction>(boxTransactions);
    final existingTxn = box.get(transaction.id);

    if (applyImpact) {
      await _handleTransactionImpacts(
        oldTxn: existingTxn,
        newTxn: transaction,
        now: now,
      );
    }

    await box.put(transaction.id, transaction);
    await _incrementBackupCounter();
  }

  Future<void> saveTransactions(List<Transaction> transactions,
      {bool applyImpact = true, DateTime? now}) async {
    final box = _hive.box<Transaction>(boxTransactions);
    final Map<dynamic, Transaction> batch = {};

    for (var txn in transactions) {
      if (applyImpact) {
        final existingTxn = box.get(txn.id);
        await _handleTransactionImpacts(
          oldTxn: existingTxn,
          newTxn: txn,
          now: now,
        );
      }
      batch[txn.id] = txn;
    }

    await box.putAll(batch);
    await _incrementBackupCounter();
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

  void _applyTransactionImpact(Account acc, Transaction txn,
      {required bool isReversal, required bool isSource, DateTime? now}) {
    double amount = txn.amount;

    bool skipBalanceUpdate = false;
    if (acc.type == AccountType.creditCard && acc.billingCycleDay != null) {
      final effectiveNow = now ?? DateTime.now();
      if (BillingHelper.isUnbilled(
          txn.date, effectiveNow, acc.billingCycleDay!)) {
        // Skip updates for unbilled expenses/transfers-out on CC
        // Because CC balance only tracks "Billed" debt + "Unbilled" is virtual until rollover
        // Wait, current logic:
        // Expense: Skip if unbilled.
        // Transfer (Source): Skip if unbilled.
        // Income: Skip if unbilled.
        // Transfer (Target - Payment): NEVER Skip.

        if (txn.type == TransactionType.expense ||
            (txn.type == TransactionType.transfer && isSource) ||
            txn.type == TransactionType.income) {
          skipBalanceUpdate = true;
        }
      }

      if (!isSource && txn.type == TransactionType.transfer) {
        // Payment to CC -> Always apply
        skipBalanceUpdate = false;
      }
    }

    if (skipBalanceUpdate) return;

    // Calculate Net Worth Impact
    // Expense: -amount
    // Income: +amount
    // Transfer (Source): -amount
    // Transfer (Target): +amount
    double impact = 0.0;
    if (txn.type == TransactionType.expense) {
      impact = -amount;
    } else if (txn.type == TransactionType.income) {
      impact = amount;
    } else if (txn.type == TransactionType.transfer) {
      impact = isSource ? -amount : amount;
    }

    // Reverse if needed (e.g. deleting a transaction)
    if (isReversal) impact = -impact;

    // Apply to Account
    // Credit Cards track LIABILITY (Positive Balance = Debt)
    // So Expense (-100 Net Worth) means Debt INCREASES (+100 Balance)
    // We invert the Net Worth Impact for Credit Cards.
    if (acc.type == AccountType.creditCard) {
      acc.balance = CurrencyUtils.roundTo2Decimals(acc.balance - impact);
    } else {
      acc.balance = CurrencyUtils.roundTo2Decimals(acc.balance + impact);
    }
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
      DebugLogger().log("StorageService: deleteTransaction error: $e");
    }
  }

  Future<int> getSimilarTransactionCount(
      String title, String category, String excludeId) async {
    final box = _hive.box<Transaction>(boxTransactions);
    final profileId = getActiveProfileId();
    return box.values
        .where((t) =>
            t.profileId == profileId &&
            t.id != excludeId &&
            t.title.trim().toLowerCase() == title.trim().toLowerCase() &&
            t.category == category &&
            !t.isDeleted)
        .length;
  }

  Future<void> bulkUpdateCategory(
      String title, String oldCategory, String newCategory) async {
    final box = _hive.box<Transaction>(boxTransactions);
    final profileId = getActiveProfileId();
    final toUpdate = box.values
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

  Future<void> permanentlyDeleteTransaction(String id) async {
    final box = _hive.box<Transaction>(boxTransactions);
    await box.delete(id);
  }

  // --- Loan Operations ---
  List<Loan> getLoans() => _getByProfile<Loan>(boxLoans);

  List<Loan> getAllLoans() {
    return _hive.box<Loan>(boxLoans).values.whereType<Loan>().toList();
  }

  Future<void> saveLoan(Loan loan) async {
    final box = _hive.box<Loan>(boxLoans);
    await box.put(loan.id, loan);
  }

  Future<void> deleteLoan(String id) async {
    await _hive.box<Loan>(boxLoans).delete(id);
  }

  // --- Recurring Operations ---
  List<RecurringTransaction> getRecurring() =>
      _getByProfile<RecurringTransaction>(boxRecurring);

  List<RecurringTransaction> getAllRecurring() {
    return _hive
        .box<RecurringTransaction>(boxRecurring)
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
  List<Category> getCategories() {
    final profileCategories = _getByProfile<Category>(boxCategories);

    if (profileCategories.isEmpty) {
      // Create defaults for this profile
      final profileId = getActiveProfileId();
      final box = _hive.box<Category>(boxCategories);
      final defaults = _getDefaultCategories(profileId);
      for (var c in defaults) {
        box.put(c.id, c);
      }
      return defaults;
    }
    return profileCategories;
  }

  List<Category> getAllCategories() {
    return _hive
        .box<Category>(boxCategories)
        .values
        .whereType<Category>()
        .toList();
  }

  Future<void> addCategory(Category category) async {
    final box = _hive.box<Category>(boxCategories);
    await box.put(category.id, category);
  }

  Future<void> removeCategory(String id) async {
    await _hive.box<Category>(boxCategories).delete(id);
  }

  Future<void> updateCategory(String id,
      {required String name,
      required CategoryUsage usage,
      required CategoryTag tag,
      required int iconCode}) async {
    final box = _hive.box<Category>(boxCategories);
    final category = box.get(id);
    if (category != null) {
      category.name = name;
      category.usage = usage;
      category.tag = tag;
      category.iconCode = iconCode;
      await _hive.box<Category>(boxCategories).put(category.id, category);
    }
  }

  Future<void> copyCategories(String fromId, String toId) async {
    final box = _hive.box<Category>(boxCategories);
    final source = box.values.where((c) => c.profileId == fromId).toList();
    // Delete existing categories in target if any? User usually expects "add/sync" or "copy".
    // Let's just add ones that don't exist by name.
    final target = box.values.where((c) => c.profileId == toId).toList();

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

  List<Category> _getDefaultCategories(String profileId) {
    if (_defaultCategoryCache.isEmpty) {
      // Emergency fallback if JSON failed or init didn't run (should not happen in prod flow)
      DebugLogger().log('Warning: Default categories cache is empty.');
      return [];
    }

    return _defaultCategoryCache.map((data) {
      final usageStr = data['usage'];
      final tagStr = data['tag'];

      CategoryUsage usage = CategoryUsage.values.firstWhere(
        (e) => e.name == usageStr,
        orElse: () => CategoryUsage.expense,
      );

      CategoryTag tag = CategoryTag.values.firstWhere(
        (e) => e.name == tagStr,
        orElse: () => CategoryTag.none,
      );

      return Category.create(
        name: data['name'] as String,
        usage: usage,
        tag: tag,
        iconCode: data['iconCode'] as int,
        profileId: profileId,
      );
    }).toList();
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
        h.year == normalized.year &&
        h.month == normalized.month &&
        h.day == normalized.day)) {
      holidays.add(normalized);
      await box.put('holidays', holidays);
      await _revalidateRecurringDates();
    }
  }

  Future<void> removeHoliday(DateTime date) async {
    final box = _hive.box(boxSettings);
    final holidays = getHolidays();
    holidays.removeWhere((h) =>
        h.year == date.year && h.month == date.month && h.day == date.day);
    await box.put('holidays', holidays);
    await _revalidateRecurringDates();
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

  DateTime? getLastLogin() {
    final box = _hive.box(boxSettings);
    return box.get('lastLogin') as DateTime?;
  }

  Future<void> setLastLogin(DateTime date) async {
    final box = _hive.box(boxSettings);
    await box.put('lastLogin', date);
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

  String? getAppPin() {
    final box = _hive.box(boxSettings);
    return box.get('appPin') as String?;
  }

  Future<void> setAppPin(String pin) async {
    final box = _hive.box(boxSettings);
    await box.put('appPin', pin);
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
    return Map<String, dynamic>.from(box.toMap());
  }

  /// Bulk-save settings from a map (used during restore).
  Future<void> saveSettings(Map<String, dynamic> settings) async {
    final box = _hive.box(boxSettings);
    for (var entry in settings.entries) {
      await box.put(entry.key, entry.value);
    }
  }

  Future<void> clearAllData() async {
    final profileId = getActiveProfileId();

    // Clear Accounts
    final accBox = _hive.box<Account>(boxAccounts);
    final accountsToDelete =
        accBox.values.where((a) => a.profileId == profileId).toList();
    for (var a in accountsToDelete) {
      await accBox.delete(a.id);
    }

    // Clear Transactions
    final txnBox = _hive.box<Transaction>(boxTransactions);
    final txnsToDelete =
        txnBox.values.where((t) => t.profileId == profileId).toList();
    for (var t in txnsToDelete) {
      await txnBox.delete(t.id);
    }

    // Clear Loans
    final loanBox = _hive.box<Loan>(boxLoans);
    final loansToDelete =
        loanBox.values.where((l) => l.profileId == profileId).toList();
    for (var l in loansToDelete) {
      await loanBox.delete(l.id);
    }

    // Clear Recurring
    final recBox = _hive.box<RecurringTransaction>(boxRecurring);
    final recToDelete =
        recBox.values.where((rt) => rt.profileId == profileId).toList();
    for (var rt in recToDelete) {
      await recBox.delete(rt.id);
    }

    // Clear Categories
    final catBox = _hive.box<Category>(boxCategories);
    final catsToDelete =
        catBox.values.where((c) => c.profileId == profileId).toList();
    for (var c in catsToDelete) {
      await catBox.delete(c.id);
    }

    // Reset backup counter
    await resetTxnsSinceBackup();
  }

  Future<int> repairAccountCurrencies(String defaultCurrency) async {
    if (!_hive.isBoxOpen(boxAccounts)) return 0;
    final box = _hive.box<Account>(boxAccounts);
    int repairedCount = 0;
    for (var key in box.keys) {
      final account = box.get(key);
      if (account != null) {
        bool needsRepair = false;
        // Check for null or empty currency
        if (account.currency.trim().isEmpty) {
          account.currency = defaultCurrency;
          needsRepair = true;
        }

        if (needsRepair) {
          await box.put(key, account);
          repairedCount++;
        }
      }
    }
    return repairedCount;
  }
}
