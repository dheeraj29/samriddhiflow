import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'cloud_storage_interface.dart';
import 'storage_service.dart';
import '../models/account.dart';
import '../models/transaction.dart';
import '../models/loan.dart';
import '../models/recurring_transaction.dart';
import '../models/category.dart';
import '../models/profile.dart';

class CloudSyncService {
  final CloudStorageInterface _cloudStorage;
  final StorageService _storageService;

  CloudSyncService(this._cloudStorage, this._storageService);

  FirebaseAuth? get _auth {
    try {
      if (Firebase.apps.isNotEmpty) return FirebaseAuth.instance;
    } catch (_) {}
    return null;
  }

  Future<void> syncToCloud() async {
    final auth = _auth;
    if (auth == null) throw Exception("Firebase not initialized");

    final user = auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    // Serialize all app data
    final data = {
      'accounts': _storageService
          .getAllAccounts()
          .map((e) => _accountToMap(e))
          .toList(),
      'transactions': _storageService
          .getAllTransactions()
          .map((e) => _transactionToMap(e))
          .toList(),
      'loans': _storageService.getAllLoans().map((e) => _loanToMap(e)).toList(),
      'recurring': _storageService
          .getAllRecurring()
          .map((e) => _recurringToMap(e))
          .toList(),
      'categories': _storageService
          .getAllCategories()
          .map((e) => _categoryToMap(e))
          .toList(),
      'profiles':
          _storageService.getProfiles().map((e) => _profileToMap(e)).toList(),
      'settings': {
        'activeProfileId': _storageService.getActiveProfileId(),
        'backupThreshold': _storageService.getBackupThreshold(),
        'currencyLocale': _storageService.getCurrencyLocale(),
        'monthlyBudget': _storageService.getMonthlyBudget(),
      }
    };

    await _cloudStorage.syncData(user.uid, data);
  }

  Future<void> restoreFromCloud() async {
    final auth = _auth;
    if (auth == null) throw Exception("Firebase not initialized");

    final user = auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    final data = await _cloudStorage.fetchData(user.uid);
    if (data == null) throw Exception("No cloud data found");

    // Clear local data before restore
    await _storageService.clearAllData();

    // Deserialize and save
    if (data['profiles'] != null) {
      for (var p in (data['profiles'] as List)) {
        await _storageService
            .saveProfile(_mapToProfile(Map<String, dynamic>.from(p)));
      }
    }

    if (data['categories'] != null) {
      for (var c in (data['categories'] as List)) {
        await _storageService
            .addCategory(_mapToCategory(Map<String, dynamic>.from(c)));
      }
    }

    if (data['accounts'] != null) {
      for (var a in (data['accounts'] as List)) {
        await _storageService
            .saveAccount(_mapToAccount(Map<String, dynamic>.from(a)));
      }
    }

    if (data['transactions'] != null) {
      for (var t in (data['transactions'] as List)) {
        await _storageService
            .saveTransaction(_mapToTransaction(Map<String, dynamic>.from(t)));
      }
    }

    if (data['loans'] != null) {
      for (var l in (data['loans'] as List)) {
        await _storageService
            .saveLoan(_mapToLoan(Map<String, dynamic>.from(l)));
      }
    }

    if (data['recurring'] != null) {
      for (var rt in (data['recurring'] as List)) {
        await _storageService.saveRecurringTransaction(
            _mapToRecurring(Map<String, dynamic>.from(rt)));
      }
    }

    if (data['settings'] != null) {
      final s = Map<String, dynamic>.from(data['settings']);
      if (s['activeProfileId'] != null) {
        await _storageService.setActiveProfileId(s['activeProfileId']);
      }
      if (s['backupThreshold'] != null) {
        await _storageService.setBackupThreshold(s['backupThreshold']);
      }
      if (s['currencyLocale'] != null) {
        await _storageService.setCurrencyLocale(s['currencyLocale']);
      }
      if (s['monthlyBudget'] != null) {
        await _storageService.setMonthlyBudget(s['monthlyBudget']);
      }
    }
  }

  Future<void> deleteCloudData() async {
    final auth = _auth;
    if (auth == null) throw Exception("Firebase not initialized");
    final user = auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    await _cloudStorage.deleteData(user.uid);
  }

  // --- Mappers ---

  Map<String, dynamic> _accountToMap(Account a) => {
        'id': a.id,
        'name': a.name,
        'balance': a.balance,
        'type': a.type.index,
        'profileId': a.profileId,
        'billingCycleDay': a.billingCycleDay,
      };

  Account _mapToAccount(Map<String, dynamic> m) => Account(
        id: m['id'],
        name: m['name'],
        balance: (m['balance'] as num).toDouble(),
        type: AccountType.values[m['type']],
        profileId: m['profileId'],
        billingCycleDay: m['billingCycleDay'],
      );

  Map<String, dynamic> _transactionToMap(Transaction t) => {
        'id': t.id,
        'title': t.title,
        'amount': t.amount,
        'date': t.date.toIso8601String(),
        'type': t.type.index,
        'category': t.category,
        'accountId': t.accountId,
        'toAccountId': t.toAccountId,
        'loanId': t.loanId,
        'isRecurringInstance': t.isRecurringInstance,
        'isDeleted': t.isDeleted,
        'holdingTenureMonths': t.holdingTenureMonths,
        'gainAmount': t.gainAmount,
        'profileId': t.profileId,
      };

  Transaction _mapToTransaction(Map<String, dynamic> m) => Transaction(
        id: m['id'],
        title: m['title'],
        amount: (m['amount'] as num).toDouble(),
        date: DateTime.parse(m['date']),
        type: TransactionType.values[m['type']],
        category: m['category'],
        accountId: m['accountId'],
        toAccountId: m['toAccountId'],
        loanId: m['loanId'],
        isRecurringInstance: m['isRecurringInstance'] ?? false,
        isDeleted: m['isDeleted'] ?? false,
        holdingTenureMonths: m['holdingTenureMonths'],
        gainAmount: (m['gainAmount'] as num?)?.toDouble(),
        profileId: m['profileId'],
      );

  Map<String, dynamic> _loanToMap(Loan l) => {
        'id': l.id,
        'name': l.name,
        'totalPrincipal': l.totalPrincipal,
        'remainingPrincipal': l.remainingPrincipal,
        'interestRate': l.interestRate,
        'tenureMonths': l.tenureMonths,
        'startDate': l.startDate.toIso8601String(),
        'emiAmount': l.emiAmount,
        'accountId': l.accountId,
        'type': l.type.index,
        'emiDay': l.emiDay,
        'firstEmiDate': l.firstEmiDate.toIso8601String(),
        'profileId': l.profileId,
        'transactions':
            l.transactions.map((t) => _loanTransactionToMap(t)).toList(),
      };

  Loan _mapToLoan(Map<String, dynamic> m) => Loan(
        id: m['id'],
        name: m['name'],
        totalPrincipal: (m['totalPrincipal'] as num).toDouble(),
        remainingPrincipal: (m['remainingPrincipal'] as num).toDouble(),
        interestRate: (m['interestRate'] as num).toDouble(),
        tenureMonths: m['tenureMonths'],
        startDate: DateTime.parse(m['startDate']),
        emiAmount: (m['emiAmount'] as num).toDouble(),
        accountId: m['accountId'],
        type: LoanType.values[m['type'] ?? 0],
        emiDay: m['emiDay'] ?? 1,
        firstEmiDate: DateTime.parse(m['firstEmiDate']),
        profileId: m['profileId'],
        transactions: (m['transactions'] as List?)
                ?.map(
                    (t) => _mapToLoanTransaction(Map<String, dynamic>.from(t)))
                .toList() ??
            [],
      );

  Map<String, dynamic> _loanTransactionToMap(LoanTransaction lt) => {
        'id': lt.id,
        'date': lt.date.toIso8601String(),
        'amount': lt.amount,
        'type': lt.type.index,
        'principalComponent': lt.principalComponent,
        'interestComponent': lt.interestComponent,
        'resultantPrincipal': lt.resultantPrincipal,
      };

  LoanTransaction _mapToLoanTransaction(Map<String, dynamic> m) =>
      LoanTransaction(
        id: m['id'],
        date: DateTime.parse(m['date']),
        amount: (m['amount'] as num).toDouble(),
        type: LoanTransactionType.values[m['type']],
        principalComponent: (m['principalComponent'] as num).toDouble(),
        interestComponent: (m['interestComponent'] as num).toDouble(),
        resultantPrincipal: (m['resultantPrincipal'] as num).toDouble(),
      );

  Map<String, dynamic> _recurringToMap(RecurringTransaction rt) => {
        'id': rt.id,
        'title': rt.title,
        'amount': rt.amount,
        'category': rt.category,
        'accountId': rt.accountId,
        'frequency': rt.frequency.index,
        'interval': rt.interval,
        'byMonthDay': rt.byMonthDay,
        'byWeekDay': rt.byWeekDay,
        'nextExecutionDate': rt.nextExecutionDate.toIso8601String(),
        'isActive': rt.isActive,
        'scheduleType': rt.scheduleType.index,
        'selectedWeekday': rt.selectedWeekday,
        'adjustForHolidays': rt.adjustForHolidays,
        'profileId': rt.profileId,
      };

  RecurringTransaction _mapToRecurring(Map<String, dynamic> m) =>
      RecurringTransaction(
        id: m['id'],
        title: m['title'],
        amount: (m['amount'] as num).toDouble(),
        category: m['category'],
        accountId: m['accountId'],
        frequency: Frequency.values[m['frequency']],
        interval: m['interval'] ?? 1,
        byMonthDay: m['byMonthDay'],
        byWeekDay: m['byWeekDay'],
        nextExecutionDate: DateTime.parse(m['nextExecutionDate']),
        isActive: m['isActive'] ?? true,
        scheduleType: ScheduleType.values[m['scheduleType'] ?? 0],
        selectedWeekday: m['selectedWeekday'],
        adjustForHolidays: m['adjustForHolidays'] ?? false,
        profileId: m['profileId'] ?? 'default',
      );

  Map<String, dynamic> _categoryToMap(Category c) => {
        'id': c.id,
        'name': c.name,
        'usage': c.usage.index,
        'tag': c.tag.index,
        'iconCode': c.iconCode,
        'profileId': c.profileId,
      };

  Category _mapToCategory(Map<String, dynamic> m) => Category(
        id: m['id'],
        name: m['name'],
        usage: CategoryUsage.values[m['usage']],
        tag: CategoryTag.values[m['tag']],
        iconCode: m['iconCode'],
        profileId: m['profileId'],
      );

  Map<String, dynamic> _profileToMap(Profile p) => {
        'id': p.id,
        'name': p.name,
        'currencyLocale': p.currencyLocale,
        'monthlyBudget': p.monthlyBudget,
      };

  Profile _mapToProfile(Map<String, dynamic> m) => Profile(
        id: m['id'],
        name: m['name'],
        currencyLocale: m['currencyLocale'] ?? 'en_IN',
        monthlyBudget: (m['monthlyBudget'] as num?)?.toDouble() ?? 0.0,
      );
}
