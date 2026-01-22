import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import '../models/account.dart';
import '../models/transaction.dart';
import '../utils/billing_helper.dart';
import '../models/loan.dart';
import '../models/recurring_transaction.dart';
import '../models/category.dart';
import '../models/profile.dart';
import '../utils/debug_logger.dart';
import '../utils/currency_utils.dart';

class StorageService {
  static const String boxAccounts = 'accounts';
  static const String boxTransactions = 'transactions';
  static const String boxLoans = 'loans';
  static const String boxRecurring = 'recurring';
  static const String boxSettings = 'settings';
  static const String boxProfiles = 'profiles';
  static const String boxCategories = 'categories_v3';

  Future<void> init() async {
    if (!Hive.isBoxOpen(boxAccounts)) await Hive.openBox<Account>(boxAccounts);
    if (!Hive.isBoxOpen(boxTransactions)) {
      await Hive.openBox<Transaction>(boxTransactions);
    }
    if (!Hive.isBoxOpen(boxLoans)) await Hive.openBox<Loan>(boxLoans);
    if (!Hive.isBoxOpen(boxRecurring)) {
      await Hive.openBox<RecurringTransaction>(boxRecurring);
    }
    if (!Hive.isBoxOpen(boxSettings)) await Hive.openBox(boxSettings);
    if (!Hive.isBoxOpen(boxProfiles)) await Hive.openBox<Profile>(boxProfiles);
    if (!Hive.isBoxOpen(boxCategories)) {
      await Hive.openBox<Category>(boxCategories);
    }

    // Initial profile
    final pBox = Hive.box<Profile>(boxProfiles);
    if (pBox.isEmpty) {
      final defaultProfile = Profile(id: 'default', name: 'Default');
      await pBox.put('default', defaultProfile);
    }

    // Migrate categories from settings to boxCategories if needed
    final cBox = Hive.box<Category>(boxCategories);
    if (cBox.isEmpty) {
      final sBox = Hive.box(boxSettings);
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
    final box = Hive.box(boxSettings);
    return box.get('activeProfileId', defaultValue: 'default');
  }

  Future<void> setActiveProfileId(String id) async {
    final box = Hive.box(boxSettings);
    await box.put('activeProfileId', id);
  }

  // --- Auth Optimistic Flag ---
  bool getAuthFlag() {
    final box = Hive.box(boxSettings);
    return box.get('isLoggedIn', defaultValue: false) as bool;
  }

  Future<void> setAuthFlag(bool value) async {
    final box = Hive.box(boxSettings);
    await box.put('isLoggedIn', value);
  }

  // --- Smart Calculator Preference ---
  bool isSmartCalculatorEnabled() {
    final box = Hive.box(boxSettings);
    return box.get('smartCalculatorEnabled', defaultValue: true) as bool;
  }

  Future<void> setSmartCalculatorEnabled(bool value) async {
    final box = Hive.box(boxSettings);
    await box.put('smartCalculatorEnabled', value);
  }

  List<Profile> getProfiles() {
    return Hive.box<Profile>(boxProfiles).values.whereType<Profile>().toList();
  }

  Future<void> saveProfile(Profile profile) async {
    await Hive.box<Profile>(boxProfiles).put(profile.id, profile);
  }

  Future<void> deleteProfile(String profileId) async {
    // 1. Delete Profile record
    await Hive.box<Profile>(boxProfiles).delete(profileId);

    // 2. Delete Accounts
    final accBox = Hive.box<Account>(boxAccounts);
    final accountsToDelete =
        accBox.values.where((a) => a.profileId == profileId).toList();
    for (var a in accountsToDelete) {
      await accBox.delete(a.id);
    }

    // 3. Delete Transactions
    final txnBox = Hive.box<Transaction>(boxTransactions);
    final txnsToDelete =
        txnBox.values.where((t) => t.profileId == profileId).toList();
    for (var t in txnsToDelete) {
      await txnBox.delete(t.id);
    }

    // 4. Delete Loans
    final loanBox = Hive.box<Loan>(boxLoans);
    final loansToDelete =
        loanBox.values.where((l) => l.profileId == profileId).toList();
    for (var l in loansToDelete) {
      await loanBox.delete(l.id);
    }

    // 5. Delete Recurring
    final recBox = Hive.box<RecurringTransaction>(boxRecurring);
    final recToDelete =
        recBox.values.where((rt) => rt.profileId == profileId).toList();
    for (var rt in recToDelete) {
      await recBox.delete(rt.id);
    }

    // 6. Delete Categories
    final catBox = Hive.box<Category>(boxCategories);
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
    return Hive.box<Account>(boxAccounts)
        .values
        .whereType<Account>()
        .where((a) => a.profileId == profileId)
        .toList();
  }

  List<Account> getAllAccounts() {
    return Hive.box<Account>(boxAccounts).values.whereType<Account>().toList();
  }

  Future<void> saveAccount(Account account) async {
    final box = Hive.box<Account>(boxAccounts);
    await box.put(account.id, account);
  }

  Future<void> deleteAccount(String id) async {
    final box = Hive.box<Account>(boxAccounts);
    final account = box.get(id);
    if (account != null && account.type == AccountType.wallet) {
      // Cascade delete transactions for wallet
      final txnsBox = Hive.box<Transaction>(boxTransactions);
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
    final box = Hive.box<Transaction>(boxTransactions);
    final list = box.values
        .whereType<Transaction>()
        .where((t) => !t.isDeleted && t.profileId == profileId)
        .toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  List<Transaction> getAllTransactions() {
    return Hive.box<Transaction>(boxTransactions)
        .values
        .whereType<Transaction>()
        .toList();
  }

  List<Transaction> getDeletedTransactions() {
    final profileId = getActiveProfileId();
    final box = Hive.box<Transaction>(boxTransactions);
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
      final settingsBox = Hive.box(boxSettings);
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

            final box = Hive.box<Transaction>(boxTransactions);
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
              await acc.save();
            }
          }
        }
      }
    } finally {
      _isCheckingRollover = false;
    }
  }

  Future<void> saveTransaction(Transaction transaction) async {
    final box = Hive.box<Transaction>(boxTransactions);
    final accountsBox = Hive.box<Account>(boxAccounts);

    final existingTxn = box.get(transaction.id);

    if (existingTxn != null && !existingTxn.isDeleted) {
      // Impact of Source Account
      if (existingTxn.accountId != null) {
        final oldAccFrom = accountsBox.get(existingTxn.accountId);
        if (oldAccFrom != null) {
          _applyTransactionImpact(oldAccFrom, existingTxn,
              isReversal: true, isSource: true);
          await oldAccFrom.save();
        }
      }
      // Impact of Target Account
      if (existingTxn.type == TransactionType.transfer &&
          existingTxn.toAccountId != null) {
        final oldAccTo = accountsBox.get(existingTxn.toAccountId);
        if (oldAccTo != null) {
          _applyTransactionImpact(oldAccTo, existingTxn,
              isReversal: true, isSource: false);
          await oldAccTo.save();
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
          await newAccFrom.save();
        }
      }
      // Impact of Target Account
      if (transaction.type == TransactionType.transfer &&
          transaction.toAccountId != null) {
        final newAccTo = accountsBox.get(transaction.toAccountId);
        if (newAccTo != null) {
          _applyTransactionImpact(newAccTo, transaction,
              isReversal: false, isSource: false);
          await newAccTo.save();
        }
      }
    }

    await box.put(transaction.id, transaction);
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

      if ((txn.date.isAtSameMomentAs(cycleStart) ||
          txn.date.isAfter(cycleStart))) {
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
    final box = Hive.box(boxSettings);
    final count = box.get('txnsSinceBackup', defaultValue: 0) as int;
    await box.put('txnsSinceBackup', count + 1);
  }

  int getTxnsSinceBackup() {
    final box = Hive.box(boxSettings);
    return box.get('txnsSinceBackup', defaultValue: 0) as int;
  }

  Future<void> resetTxnsSinceBackup() async {
    final box = Hive.box(boxSettings);
    await box.put('txnsSinceBackup', 0);
  }

  Future<void> deleteTransaction(String id) async {
    try {
      final box = Hive.box<Transaction>(boxTransactions);
      final txn = box.get(id);
      if (txn == null || txn.isDeleted) return;

      // 1. Mark as deleted immediately for UI reactivity
      txn.isDeleted = true;
      await txn.save();

      // 2. Apply reverses if account-linked
      if (txn.accountId != null) {
        final accountsBox = Hive.box<Account>(boxAccounts);
        final accFrom = accountsBox.get(txn.accountId);

        if (accFrom != null) {
          _applyTransactionImpact(accFrom, txn,
              isReversal: true, isSource: true);
          await accFrom.save();
        }

        if (txn.type == TransactionType.transfer && txn.toAccountId != null) {
          final accTo = accountsBox.get(txn.toAccountId);
          if (accTo != null) {
            _applyTransactionImpact(accTo, txn,
                isReversal: true, isSource: false);
            await accTo.save();
          }
        }
      }
    } catch (e) {
      DebugLogger().log("StorageService: deleteTransaction error: $e");
    }
  }

  Future<void> restoreTransaction(String id) async {
    final box = Hive.box<Transaction>(boxTransactions);
    final txn = box.get(id);
    if (txn != null && txn.isDeleted) {
      txn.isDeleted = false;
      await txn.save();

      final accountsBox = Hive.box<Account>(boxAccounts);
      final accFrom =
          txn.accountId != null ? accountsBox.get(txn.accountId) : null;

      if (accFrom != null) {
        _applyTransactionImpact(accFrom, txn,
            isReversal: false, isSource: true);
        await accFrom.save();

        if (txn.type == TransactionType.transfer && txn.toAccountId != null) {
          final accTo = accountsBox.get(txn.toAccountId);
          if (accTo != null) {
            _applyTransactionImpact(accTo, txn,
                isReversal: false, isSource: false);
            await accTo.save();
          }
        }
      }
    }
  }

  Future<void> permanentlyDeleteTransaction(String id) async {
    final box = Hive.box<Transaction>(boxTransactions);
    await box.delete(id);
  }

  // --- Loan Operations ---
  List<Loan> getLoans() {
    final profileId = getActiveProfileId();
    return Hive.box<Loan>(boxLoans)
        .values
        .where((l) => l.profileId == profileId)
        .toList();
  }

  List<Loan> getAllLoans() {
    return Hive.box<Loan>(boxLoans).values.whereType<Loan>().toList();
  }

  Future<void> saveLoan(Loan loan) async {
    final box = Hive.box<Loan>(boxLoans);
    await box.put(loan.id, loan);
  }

  Future<void> deleteLoan(String id) async {
    await Hive.box<Loan>(boxLoans).delete(id);
  }

  // --- Recurring Operations ---
  List<RecurringTransaction> getRecurring() {
    final profileId = getActiveProfileId();
    return Hive.box<RecurringTransaction>(boxRecurring)
        .values
        .where((rt) => rt.profileId == profileId)
        .toList();
  }

  List<RecurringTransaction> getAllRecurring() {
    return Hive.box<RecurringTransaction>(boxRecurring)
        .values
        .whereType<RecurringTransaction>()
        .toList();
  }

  Future<void> saveRecurringTransaction(RecurringTransaction rt) async {
    final box = Hive.box<RecurringTransaction>(boxRecurring);
    if (box.containsKey(rt.id)) {
      await rt.save();
    } else {
      await box.put(rt.id, rt);
    }
  }

  Future<void> deleteRecurringTransaction(String id) async {
    await Hive.box<RecurringTransaction>(boxRecurring).delete(id);
  }

  Future<void> advanceRecurringTransactionDate(String id) async {
    final box = Hive.box<RecurringTransaction>(boxRecurring);
    final rt = box.get(id);
    if (rt != null) {
      rt.nextExecutionDate = rt.calculateNextOccurrence(rt.nextExecutionDate);
      await rt.save();
    }
  }

  // --- Category Operations ---
  List<Category> getCategories() {
    final profileId = getActiveProfileId();
    final box = Hive.box<Category>(boxCategories);
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
    return Hive.box<Category>(boxCategories)
        .values
        .whereType<Category>()
        .toList();
  }

  Future<void> addCategory(Category category) async {
    final box = Hive.box<Category>(boxCategories);
    await box.put(category.id, category);
  }

  Future<void> removeCategory(String id) async {
    await Hive.box<Category>(boxCategories).delete(id);
  }

  Future<void> updateCategory(String id,
      {required String name,
      required CategoryUsage usage,
      required CategoryTag tag,
      required int iconCode}) async {
    final box = Hive.box<Category>(boxCategories);
    final category = box.get(id);
    if (category != null) {
      category.name = name;
      category.usage = usage;
      category.tag = tag;
      category.iconCode = iconCode;
      await category.save();
    }
  }

  Future<void> copyCategories(String fromId, String toId) async {
    final box = Hive.box<Category>(boxCategories);
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
    ];
  }

  // --- Other Settings ---
  String getCurrencyLocale() {
    final profileId = getActiveProfileId();
    final pBox = Hive.box<Profile>(boxProfiles);
    return pBox.get(profileId)?.currencyLocale ?? 'en_IN';
  }

  Future<void> setCurrencyLocale(String locale) async {
    final profileId = getActiveProfileId();
    final pBox = Hive.box<Profile>(boxProfiles);
    final p = pBox.get(profileId);
    if (p != null) {
      p.currencyLocale = locale;
      await p.save();
      // Force flush to ensure persistence survives immediate app kill
      // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
      // await pBox.flush(); // Hive CE might not need this but it's safer.
      // Actually standard hive behavior implies save() is enough, but flush ensures disk write.
    }
  }

  double getMonthlyBudget() {
    final profileId = getActiveProfileId();
    final pBox = Hive.box<Profile>(boxProfiles);
    return pBox.get(profileId)?.monthlyBudget ?? 0.0;
  }

  Future<void> setMonthlyBudget(double budget) async {
    final profileId = getActiveProfileId();
    final pBox = Hive.box<Profile>(boxProfiles);
    final p = pBox.get(profileId);
    if (p != null) {
      p.monthlyBudget = budget;
      await p.save();
    }
  }

  int getBackupThreshold() {
    final box = Hive.box(boxSettings);
    return box.get('backupThreshold', defaultValue: 5) as int;
  }

  Future<void> setBackupThreshold(int threshold) async {
    final box = Hive.box(boxSettings);
    await box.put('backupThreshold', threshold);
  }

  // --- Holiday Operations ---
  List<DateTime> getHolidays() {
    final box = Hive.box(boxSettings);
    final List<dynamic> list = box.get('holidays', defaultValue: []);
    return list.map((e) => e as DateTime).toList();
  }

  Future<void> addHoliday(DateTime date) async {
    final box = Hive.box(boxSettings);
    final holidays = getHolidays();
    final normalized = DateTime(date.year, date.month, date.day);
    if (!holidays.any((h) =>
        h.year == normalized.year &&
        h.month == normalized.month &&
        h.day == normalized.day)) {
      holidays.add(normalized);
      await box.put('holidays', holidays);
    }
  }

  Future<void> removeHoliday(DateTime date) async {
    final box = Hive.box(boxSettings);
    final holidays = getHolidays();
    holidays.removeWhere((h) =>
        h.year == date.year && h.month == date.month && h.day == date.day);
    await box.put('holidays', holidays);
  }

  DateTime? getLastLogin() {
    final box = Hive.box(boxSettings);
    return box.get('lastLogin') as DateTime?;
  }

  Future<void> setLastLogin(DateTime date) async {
    final box = Hive.box(boxSettings);
    await box.put('lastLogin', date);
  }

  int getInactivityThresholdDays() {
    final box = Hive.box(boxSettings);
    return box.get('inactivityThresholdDays', defaultValue: 7) as int;
  }

  Future<void> setInactivityThresholdDays(int days) async {
    final box = Hive.box(boxSettings);
    await box.put('inactivityThresholdDays', days);
  }

  int getMaturityWarningDays() {
    final box = Hive.box(boxSettings);
    return box.get('maturityWarningDays', defaultValue: 5) as int;
  }

  Future<void> setMaturityWarningDays(int days) async {
    final box = Hive.box(boxSettings);
    await box.put('maturityWarningDays', days);
  }

  // --- App Lock ---
  bool isAppLockEnabled() {
    final box = Hive.box(boxSettings);
    return box.get('appLockEnabled', defaultValue: false) as bool;
  }

  Future<void> setAppLockEnabled(bool enabled) async {
    final box = Hive.box(boxSettings);
    await box.put('appLockEnabled', enabled);
  }

  String? getAppPin() {
    final box = Hive.box(boxSettings);
    return box.get('appPin') as String?;
  }

  Future<void> setAppPin(String pin) async {
    final box = Hive.box(boxSettings);
    await box.put('appPin', pin);
  }

  // --- Theme Mode ---
  String getThemeMode() {
    final box = Hive.box(boxSettings);
    return box.get('themeMode', defaultValue: 'system') as String;
  }

  Future<void> setThemeMode(String mode) async {
    final box = Hive.box(boxSettings);
    await box.put('themeMode', mode);
  }

  Future<void> clearAllData() async {
    final profileId = getActiveProfileId();

    // Clear Accounts
    final accBox = Hive.box<Account>(boxAccounts);
    final accountsToDelete =
        accBox.values.where((a) => a.profileId == profileId).toList();
    for (var a in accountsToDelete) {
      await accBox.delete(a.id);
    }

    // Clear Transactions
    final txnBox = Hive.box<Transaction>(boxTransactions);
    final txnsToDelete =
        txnBox.values.where((t) => t.profileId == profileId).toList();
    for (var t in txnsToDelete) {
      await txnBox.delete(t.id);
    }

    // Clear Loans
    final loanBox = Hive.box<Loan>(boxLoans);
    final loansToDelete =
        loanBox.values.where((l) => l.profileId == profileId).toList();
    for (var l in loansToDelete) {
      await loanBox.delete(l.id);
    }

    // Clear Recurring
    final recBox = Hive.box<RecurringTransaction>(boxRecurring);
    final recToDelete =
        recBox.values.where((rt) => rt.profileId == profileId).toList();
    for (var rt in recToDelete) {
      await recBox.delete(rt.id);
    }

    // Clear Categories
    final catBox = Hive.box<Category>(boxCategories);
    final catsToDelete =
        catBox.values.where((c) => c.profileId == profileId).toList();
    for (var c in catsToDelete) {
      await catBox.delete(c.id);
    }

    // Reset backup counter
    await resetTxnsSinceBackup();
  }
}
