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
  StorageService([HiveInterface? hive]) : _hive = hive ?? Hive;

  static const String boxAccounts = 'accounts';
  static const String boxTransactions = 'transactions';
  static const String boxLoans = 'loans';
  static const String boxRecurring = 'recurring';
  static const String boxSettings = 'settings';
  static const String boxProfiles = 'profiles';
  static const String boxCategories = 'categories_v3';

  Future<void> init() async {
    if (!_hive.isBoxOpen(boxAccounts))
      await _hive.openBox<Account>(boxAccounts);
    if (!_hive.isBoxOpen(boxTransactions)) {
      await _hive.openBox<Transaction>(boxTransactions);
    }
    if (!_hive.isBoxOpen(boxLoans)) await _hive.openBox<Loan>(boxLoans);
    if (!_hive.isBoxOpen(boxRecurring)) {
      await _hive.openBox<RecurringTransaction>(boxRecurring);
    }
    if (!_hive.isBoxOpen(boxSettings)) await _hive.openBox(boxSettings);
    if (!_hive.isBoxOpen(boxProfiles))
      await _hive.openBox<Profile>(boxProfiles);
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
        final defaults = _getDefaultCategories('default');
        for (var c in defaults) {
          await cBox.put(c.id, c);
        }
      }
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

    // 2. Delete Accounts
    final accBox = _hive.box<Account>(boxAccounts);
    final accountsToDelete =
        accBox.values.where((a) => a.profileId == profileId).toList();
    for (var a in accountsToDelete) {
      await accBox.delete(a.id);
    }

    // 3. Delete Transactions
    final txnBox = _hive.box<Transaction>(boxTransactions);
    final txnsToDelete =
        txnBox.values.where((t) => t.profileId == profileId).toList();
    for (var t in txnsToDelete) {
      await txnBox.delete(t.id);
    }

    // 4. Delete Loans
    final loanBox = _hive.box<Loan>(boxLoans);
    final loansToDelete =
        loanBox.values.where((l) => l.profileId == profileId).toList();
    for (var l in loansToDelete) {
      await loanBox.delete(l.id);
    }

    // 5. Delete Recurring
    final recBox = _hive.box<RecurringTransaction>(boxRecurring);
    final recToDelete =
        recBox.values.where((rt) => rt.profileId == profileId).toList();
    for (var rt in recToDelete) {
      await recBox.delete(rt.id);
    }

    // 6. Delete Categories
    final catBox = _hive.box<Category>(boxCategories);
    final catsToDelete =
        catBox.values.where((c) => c.profileId == profileId).toList();
    for (var c in catsToDelete) {
      await catBox.delete(c.id);
    }

    // 7. If active profile was deleted, switch to another one
    if (getActiveProfileId() == profileId) {
      final profiles = getProfiles();
      if (profiles.isNotEmpty) {
        await setActiveProfileId(profiles.first.id);
      } else {
        // Should not happen as we always have default, but for safety:
        await setActiveProfileId('default');
      }
    }
  }

  // --- Account Operations ---
  List<Account> getAccounts() {
    final profileId = getActiveProfileId();
    return _hive
        .box<Account>(boxAccounts)
        .values
        .whereType<Account>()
        .where((a) => a.profileId == profileId)
        .toList();
  }

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
  }

  // --- Transaction Operations ---
  List<Transaction> getTransactions() {
    final profileId = getActiveProfileId();
    final box = _hive.box<Transaction>(boxTransactions);
    final list = box.values
        .whereType<Transaction>()
        .where((t) => !t.isDeleted && t.profileId == profileId)
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
    final profileId = getActiveProfileId();
    final box = _hive.box<Transaction>(boxTransactions);
    return box.values
        .whereType<Transaction>()
        .where((t) => t.isDeleted && t.profileId == profileId)
        .toList();
  }

  // --- Rollover Logic ---
  static bool _isCheckingRollover = false;

  Future<void> checkCreditCardRollovers() async {
    if (_isCheckingRollover) return;
    _isCheckingRollover = true;

    try {
      final accounts = getAccounts(); // Already filtered by profile
      final settingsBox = _hive.box(boxSettings);
      final now = DateTime.now();

      for (var acc in accounts) {
        if (acc.type == AccountType.creditCard && acc.billingCycleDay != null) {
          final key = 'last_rollover_${acc.id}';
          final lastRolloverMillis = settingsBox.get(key);

          DateTime lastRollover;
          final currentCycleStart =
              BillingHelper.getCycleStart(now, acc.billingCycleDay!);

          if (lastRolloverMillis == null) {
            await settingsBox.put(
                key, currentCycleStart.millisecondsSinceEpoch);
            continue;
          } else {
            lastRollover =
                DateTime.fromMillisecondsSinceEpoch(lastRolloverMillis);
          }

          if (currentCycleStart.isAfter(lastRollover)) {
            // CRITICAL: Mark as processed BEFORE saving account changes to prevent
            // infinite loop if the listener fires immediately.
            await settingsBox.put(
                key, currentCycleStart.millisecondsSinceEpoch);

            final box = _hive.box<Transaction>(boxTransactions);
            final txns = box.values
                .where((t) =>
                    !t.isDeleted &&
                    t.accountId == acc.id &&
                    t.date.isAfter(lastRollover) &&
                    t.date.isBefore(currentCycleStart) &&
                    (t.date.isAtSameMomentAs(lastRollover) ||
                        t.date.isAfter(lastRollover)))
                .toList();

            double adhocAmount = 0;
            for (var t in txns) {
              if (t.type == TransactionType.expense) adhocAmount += t.amount;
              if (t.type == TransactionType.income) adhocAmount -= t.amount;
              if (t.type == TransactionType.transfer) adhocAmount += t.amount;
            }

            if (adhocAmount != 0) {
              acc.balance =
                  CurrencyUtils.roundTo2Decimals(acc.balance + adhocAmount);
              await _hive.box<Account>(boxAccounts).put(acc.id, acc);
            }
          }
        }
      }
    } finally {
      _isCheckingRollover = false;
    }
  }

  Future<void> saveTransaction(Transaction transaction,
      {bool applyImpact = true}) async {
    final box = _hive.box<Transaction>(boxTransactions);
    final accountsBox = _hive.box<Account>(boxAccounts);

    final existingTxn = box.get(transaction.id);

    if (applyImpact) {
      if (existingTxn != null && !existingTxn.isDeleted) {
        // Impact of Source Account
        if (existingTxn.accountId != null) {
          final oldAccFrom = accountsBox.get(existingTxn.accountId);
          if (oldAccFrom != null) {
            _applyTransactionImpact(oldAccFrom, existingTxn,
                isReversal: true, isSource: true);
            await _hive
                .box<Account>(boxAccounts)
                .put(oldAccFrom.id, oldAccFrom);
          }
        }
        // Impact of Target Account
        if (existingTxn.type == TransactionType.transfer &&
            existingTxn.toAccountId != null) {
          final oldAccTo = accountsBox.get(existingTxn.toAccountId);
          if (oldAccTo != null) {
            _applyTransactionImpact(oldAccTo, existingTxn,
                isReversal: true, isSource: false);
            await _hive.box<Account>(boxAccounts).put(oldAccTo.id, oldAccTo);
          }
        }
      }

      if (!transaction.isDeleted) {
        // Impact of Source Account
        if (transaction.accountId != null) {
          final newAccFrom = accountsBox.get(transaction.accountId);
          if (newAccFrom != null) {
            _applyTransactionImpact(newAccFrom, transaction,
                isReversal: false, isSource: true);
            await _hive
                .box<Account>(boxAccounts)
                .put(newAccFrom.id, newAccFrom);
          }
        }
        // Impact of Target Account
        if (transaction.type == TransactionType.transfer &&
            transaction.toAccountId != null) {
          final newAccTo = accountsBox.get(transaction.toAccountId);
          if (newAccTo != null) {
            _applyTransactionImpact(newAccTo, transaction,
                isReversal: false, isSource: false);
            await _hive.box<Account>(boxAccounts).put(newAccTo.id, newAccTo);
          }
        }
      }
    }

    await box.put(transaction.id, transaction);
    await _incrementBackupCounter();
  }

  Future<void> saveTransactions(List<Transaction> transactions,
      {bool applyImpact = true}) async {
    final box = _hive.box<Transaction>(boxTransactions);
    final accountsBox = _hive.box<Account>(boxAccounts);

    final Map<dynamic, Transaction> batch = {};
    for (var txn in transactions) {
      if (applyImpact) {
        // Apply Logic
        final existingTxn = box.get(txn.id);
        if (existingTxn != null && !existingTxn.isDeleted) {
          if (existingTxn.accountId != null) {
            final oldAcc = accountsBox.get(existingTxn.accountId);
            if (oldAcc != null) {
              _applyTransactionImpact(oldAcc, existingTxn,
                  isReversal: true, isSource: true);
              await _hive.box<Account>(boxAccounts).put(oldAcc.id, oldAcc);
            }
          }
          if (existingTxn.type == TransactionType.transfer &&
              existingTxn.toAccountId != null) {
            final oldAccTo = accountsBox.get(existingTxn.toAccountId);
            if (oldAccTo != null) {
              _applyTransactionImpact(oldAccTo, existingTxn,
                  isReversal: true, isSource: false);
              await _hive.box<Account>(boxAccounts).put(oldAccTo.id, oldAccTo);
            }
          }
        }

        if (!txn.isDeleted) {
          if (txn.accountId != null) {
            final newAcc = accountsBox.get(txn.accountId);
            if (newAcc != null) {
              _applyTransactionImpact(newAcc, txn,
                  isReversal: false, isSource: true);
              await _hive.box<Account>(boxAccounts).put(newAcc.id, newAcc);
            }
          }
          if (txn.type == TransactionType.transfer && txn.toAccountId != null) {
            final newAccTo = accountsBox.get(txn.toAccountId);
            if (newAccTo != null) {
              _applyTransactionImpact(newAccTo, txn,
                  isReversal: false, isSource: false);
              await _hive.box<Account>(boxAccounts).put(newAccTo.id, newAccTo);
            }
          }
        }
      } // End applyImpact

      batch[txn.id] = txn;
    }

    await box.putAll(batch);
    await _incrementBackupCounter();
  }

  void _applyTransactionImpact(Account acc, Transaction txn,
      {required bool isReversal, required bool isSource}) {
    double amount = txn.amount;
    if (isReversal) amount = -amount;

    bool skipBalanceUpdate = false;
    if (acc.type == AccountType.creditCard && acc.billingCycleDay != null) {
      final now = DateTime.now();
      final cycleStart = BillingHelper.getCycleStart(now, acc.billingCycleDay!);

      final txnDateOnly = DateTime(txn.date.year, txn.date.month, txn.date.day);

      if (txnDateOnly.isAfter(cycleStart)) {
        if (txn.type == TransactionType.expense ||
            (txn.type == TransactionType.transfer && isSource)) {
          skipBalanceUpdate = true;
        }
        if (txn.type == TransactionType.income) skipBalanceUpdate = true;
      }

      if (!isSource && txn.type == TransactionType.transfer) {
        skipBalanceUpdate = false;
      }
    }

    if (skipBalanceUpdate) return;

    if (txn.type == TransactionType.expense) {
      if (acc.type == AccountType.creditCard) {
        acc.balance = CurrencyUtils.roundTo2Decimals(acc.balance + amount);
      } else {
        acc.balance = CurrencyUtils.roundTo2Decimals(acc.balance - amount);
      }
    } else if (txn.type == TransactionType.income) {
      if (acc.type == AccountType.creditCard) {
        acc.balance = CurrencyUtils.roundTo2Decimals(acc.balance - amount);
      } else {
        acc.balance = CurrencyUtils.roundTo2Decimals(acc.balance + amount);
      }
    } else if (txn.type == TransactionType.transfer) {
      if (isSource) {
        acc.balance = CurrencyUtils.roundTo2Decimals(acc.balance - amount);
      } else {
        if (acc.type == AccountType.creditCard) {
          acc.balance = CurrencyUtils.roundTo2Decimals(acc.balance - amount);
        } else {
          acc.balance = CurrencyUtils.roundTo2Decimals(acc.balance + amount);
        }
      }
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

      // 1. Mark as deleted immediately for UI reactivity
      txn.isDeleted = true;
      await _hive.box<Transaction>(boxTransactions).put(txn.id, txn);

      // 2. Apply reverses if account-linked
      if (txn.accountId != null) {
        final accountsBox = _hive.box<Account>(boxAccounts);
        final accFrom = accountsBox.get(txn.accountId);

        if (accFrom != null) {
          _applyTransactionImpact(accFrom, txn,
              isReversal: true, isSource: true);
          await _hive.box<Account>(boxAccounts).put(accFrom.id, accFrom);
        }

        if (txn.type == TransactionType.transfer && txn.toAccountId != null) {
          final accTo = accountsBox.get(txn.toAccountId);
          if (accTo != null) {
            _applyTransactionImpact(accTo, txn,
                isReversal: true, isSource: false);
            await _hive.box<Account>(boxAccounts).put(accTo.id, accTo);
          }
        }
      }
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
      txn.isDeleted = false;
      await _hive.box<Transaction>(boxTransactions).put(txn.id, txn);

      final accountsBox = _hive.box<Account>(boxAccounts);
      final accFrom =
          txn.accountId != null ? accountsBox.get(txn.accountId) : null;

      if (accFrom != null) {
        _applyTransactionImpact(accFrom, txn,
            isReversal: false, isSource: true);
        await _hive.box<Account>(boxAccounts).put(accFrom.id, accFrom);

        if (txn.type == TransactionType.transfer && txn.toAccountId != null) {
          final accTo = accountsBox.get(txn.toAccountId);
          if (accTo != null) {
            _applyTransactionImpact(accTo, txn,
                isReversal: false, isSource: false);
            await _hive.box<Account>(boxAccounts).put(accTo.id, accTo);
          }
        }
      }
    }
  }

  Future<void> permanentlyDeleteTransaction(String id) async {
    final box = _hive.box<Transaction>(boxTransactions);
    await box.delete(id);
  }

  // --- Loan Operations ---
  List<Loan> getLoans() {
    final profileId = getActiveProfileId();
    return _hive
        .box<Loan>(boxLoans)
        .values
        .where((l) => l.profileId == profileId)
        .toList();
  }

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
  List<RecurringTransaction> getRecurring() {
    final profileId = getActiveProfileId();
    return _hive
        .box<RecurringTransaction>(boxRecurring)
        .values
        .where((rt) => rt.profileId == profileId)
        .toList();
  }

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
    final profileId = getActiveProfileId();
    final box = _hive.box<Category>(boxCategories);
    final profileCategories =
        box.values.where((c) => c.profileId == profileId).toList();

    if (profileCategories.isEmpty) {
      // Create defaults for this profile
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
    return [
      // Income
      Category.create(
          name: 'Salary',
          usage: CategoryUsage.income,
          tag: CategoryTag.directTax,
          iconCode: 0xeb6f,
          profileId: profileId),
      Category.create(
          name: 'Property Rental',
          usage: CategoryUsage.income,
          tag: CategoryTag.directTax,
          iconCode: 0xf8eb,
          profileId: profileId),
      Category.create(
          name: 'Divestment',
          usage: CategoryUsage.income,
          tag: CategoryTag.capitalGain,
          iconCode: 0xf3ee,
          profileId: profileId),
      Category.create(
          name: 'Saving Interest',
          usage: CategoryUsage.income,
          tag: CategoryTag.directTax,
          iconCode: 0xe2eb,
          profileId: profileId),
      Category.create(
          name: 'Dividend',
          usage: CategoryUsage.income,
          tag: CategoryTag.directTax,
          iconCode: 0xf3ee,
          profileId: profileId),
      Category.create(
          name: 'Family Gift',
          usage: CategoryUsage.income,
          tag: CategoryTag.taxFree,
          iconCode: 0xe8b1,
          profileId: profileId),
      Category.create(
          name: 'Gift',
          usage: CategoryUsage.income,
          tag: CategoryTag.directTax,
          iconCode: 0xe8b1,
          profileId: profileId),

      // Expense
      Category.create(
          name: 'Gadgets',
          usage: CategoryUsage.expense,
          iconCode: 0xe1b1, // Devices
          profileId: profileId),
      Category.create(
          name: 'Clothes',
          usage: CategoryUsage.expense,
          iconCode: 0xf19e, // Checkroom
          profileId: profileId),
      Category.create(
          name: 'Bank loan',
          usage: CategoryUsage.expense,
          iconCode: 0xeb6f,
          profileId: profileId),
      Category.create(
          name: 'Insurance',
          usage: CategoryUsage.expense,
          iconCode: 0xf19d, // Policy
          profileId: profileId),
      Category.create(
          name: 'Cashback',
          usage: CategoryUsage.income,
          iconCode: 0xea61, // Paid
          profileId: profileId),
      Category.create(
          name: 'Festival',
          usage: CategoryUsage.expense,
          iconCode: 0xea68,
          profileId: profileId),
      Category.create(
          name: 'Snacks',
          usage: CategoryUsage.expense,
          iconCode: 0xe57a, // Fastfood
          profileId: profileId),
      Category.create(
          name: 'Beauty',
          usage: CategoryUsage.expense,
          iconCode: 0xeb4c, // Spa / Beauty
          profileId: profileId),
      Category.create(
          name: 'Service Charges',
          usage: CategoryUsage.expense,
          iconCode: 0xef63,
          profileId: profileId),
      Category.create(
          name: 'Food',
          usage: CategoryUsage.expense,
          iconCode: 0xe56c, // Restaurant
          profileId: profileId),
      Category.create(
          name: 'Toys',
          usage: CategoryUsage.expense,
          iconCode: 0xe332,
          profileId: profileId),
      Category.create(
          name: 'Entertainment',
          usage: CategoryUsage.expense,
          iconCode: 0xea68,
          profileId: profileId),
      Category.create(
          name: 'Others',
          usage: CategoryUsage.expense,
          iconCode: 0xea14,
          profileId: profileId),
      Category.create(
          name: 'Investment',
          usage: CategoryUsage.expense,
          tag: CategoryTag.budgetFree,
          iconCode: 0xef92,
          profileId: profileId),
      Category.create(
          name: 'Groceries',
          usage: CategoryUsage.expense,
          iconCode: 0xef97,
          profileId: profileId),
      Category.create(
          name: 'Rent',
          usage: CategoryUsage.expense,
          iconCode: 0xef63,
          profileId: profileId),
      Category.create(
          name: 'Travel',
          usage: CategoryUsage.expense,
          iconCode: 0xe6ca,
          profileId: profileId),
      Category.create(
          name: 'Health',
          usage: CategoryUsage.expense,
          iconCode: 0xe1d5,
          profileId: profileId),
      Category.create(
          name: 'Gas',
          usage: CategoryUsage.expense,
          iconCode: 0xe546,
          profileId: profileId),
      Category.create(
          name: 'Utility Bill',
          usage: CategoryUsage.expense,
          iconCode: 0xe8b0,
          profileId: profileId),
      Category.create(
          name: 'Pharmacy',
          usage: CategoryUsage.expense,
          iconCode: 0xe550,
          profileId: profileId),
      Category.create(
          name: 'Maid',
          usage: CategoryUsage.expense,
          iconCode: 0xf0ff,
          profileId: profileId),
      Category.create(
          name: 'Care Taker',
          usage: CategoryUsage.expense,
          iconCode: 0xeb41,
          profileId: profileId),
      Category.create(
          name: 'Repairs',
          usage: CategoryUsage.expense,
          iconCode: 0xe869,
          profileId: profileId),
      Category.create(
          name: 'Salon',
          usage: CategoryUsage.expense,
          iconCode: 0xef9d,
          profileId: profileId),
      Category.create(
          name: 'Laundry',
          usage: CategoryUsage.expense,
          iconCode: 0xe2a8,
          profileId: profileId),
      Category.create(
          name: 'Vegetables',
          usage: CategoryUsage.expense,
          iconCode: 0xef97,
          profileId: profileId),
      Category.create(
          name: 'Fruits',
          usage: CategoryUsage.expense,
          iconCode: 0xe110,
          profileId: profileId),
      Category.create(
          name: 'Meat',
          usage: CategoryUsage.expense,
          iconCode: 0xe842,
          profileId: profileId),
      Category.create(
          name: 'School',
          usage: CategoryUsage.expense,
          iconCode: 0xe80c,
          profileId: profileId),
      Category.create(
          name: 'Subscriptions',
          usage: CategoryUsage.expense,
          iconCode: 0xe064,
          profileId: profileId),
      Category.create(
          name: 'Services',
          usage: CategoryUsage.expense,
          iconCode: 0xe86a,
          profileId: profileId),
      Category.create(
          name: 'Movies',
          usage: CategoryUsage.expense,
          iconCode: 0xe02c,
          profileId: profileId),
      Category.create(
          name: 'Hospital',
          usage: CategoryUsage.expense,
          iconCode: 0xe548,
          profileId: profileId),
      Category.create(
          name: 'Shopping',
          usage: CategoryUsage.expense,
          iconCode: 0xf1cc,
          profileId: profileId),
    ];
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
        DateTime idealDate = rt.nextExecutionDate;

        if (rt.frequency == Frequency.monthly &&
            rt.scheduleType == ScheduleType.fixedDate) {
          // Use byMonthDay as anchor if available, otherwise best effort with current day
          int targetDay = rt.byMonthDay ?? rt.nextExecutionDate.day;

          // Check closest candidate around the current execution date
          DateTime currentMonthAndYear = DateTime(
              rt.nextExecutionDate.year, rt.nextExecutionDate.month, 1);

          // Candidates: current month, next month (if we shifted back from 1st to 31st)
          DateTime c1 = _getSafeDate(
              currentMonthAndYear.year, currentMonthAndYear.month, targetDay);
          DateTime c2 = _getSafeDate(currentMonthAndYear.year,
              currentMonthAndYear.month + 1, targetDay);

          // Pick closest to current nextExecutionDate
          if ((c1.difference(rt.nextExecutionDate).abs()) <
              (c2.difference(rt.nextExecutionDate).abs())) {
            idealDate = c1;
          } else {
            idealDate = c2;
          }
        }

        final adjusted =
            RecurrenceUtils.adjustDateForHolidays(idealDate, holidays);

        if (rt.nextExecutionDate != adjusted) {
          rt.nextExecutionDate = adjusted;
          await box.put(rt.id, rt);
        }
      }
    }
  }

  DateTime _getSafeDate(int year, int month, int day) {
    // Handle overflow (e.g. Feb 30 -> Feb 28)
    int safeDay = day;
    int daysInMonth = DateTime(year, month + 1, 0).day;
    if (safeDay > daysInMonth) safeDay = daysInMonth;
    return DateTime(year, month, safeDay);
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

  // --- Theme Mode ---
  String getThemeMode() {
    final box = _hive.box(boxSettings);
    return box.get('themeMode', defaultValue: 'system') as String;
  }

  Future<void> setThemeMode(String mode) async {
    final box = _hive.box(boxSettings);
    await box.put('themeMode', mode);
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
}
