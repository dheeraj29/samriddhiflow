import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:firebase_core/firebase_core.dart';
import 'cloud_storage_interface.dart';
import 'storage_service.dart';
import '../models/account.dart';
import '../models/transaction.dart';
import '../models/loan.dart';
import '../models/recurring_transaction.dart';
import '../models/category.dart';
import '../models/profile.dart';
import '../models/taxes/insurance_policy.dart';
import '../models/taxes/tax_rules.dart';
import '../models/taxes/tax_data.dart';
import 'taxes/tax_config_service.dart';
import '../models/lending_record.dart';
import 'dart:convert';
import 'encryption_service.dart';

const errUserNotLoggedIn = 'User not logged in';
const errFirebaseNotInit = 'Firebase not initialized';

class CloudSyncService {
  final CloudStorageInterface _cloudStorage;
  final StorageService _storageService;
  final TaxConfigService _taxConfigService;
  final FirebaseAuth? _firebaseAuth;

  CloudSyncService(
      this._cloudStorage, this._storageService, this._taxConfigService,
      {FirebaseAuth? firebaseAuth})
      : _firebaseAuth = firebaseAuth;

  FirebaseAuth? get _auth {
    if (_firebaseAuth != null) return _firebaseAuth;
    try {
      if (Firebase.apps.isNotEmpty) {
        // coverage:ignore-line
        return FirebaseAuth.instance; // coverage:ignore-line
      }
    } catch (_) {}
    return null;
  }

  void _checkRegionLock() {
    final country = _storageService.getDetectedCountry();
    if (country != null && country.toUpperCase() != 'IN') {
      // coverage:ignore-line
      throw Exception(// coverage:ignore-line
          'Cloud Synchronization is only available for users in India.');
    }
  }

  Future<void> syncToCloud({String? passcode, String? appPin}) async {
    _checkRegionLock();
    final auth = _auth;
    if (auth == null) {
      throw Exception(errFirebaseNotInit); // coverage:ignore-line
    }

    final user = auth.currentUser;
    if (user == null) throw Exception(errUserNotLoggedIn);

    final encryption =
        (passcode != null && passcode.isNotEmpty) ? EncryptionService() : null;

    dynamic encryptIfRequested(dynamic payload) {
      if (encryption == null) return payload;
      return encryption.encryptData(jsonEncode(payload), passcode!);
    }

    final settings = _storageService.getAllSettings();
    final lastSync = settings['last_sync'];
    final Map<String, dynamic> settingsToEncrypt = Map.from(settings);
    settingsToEncrypt.remove('last_sync');

    // Inject plaintext appPin for backup if provided
    if (appPin != null) {
      settingsToEncrypt['appPin'] = appPin; // coverage:ignore-line
    }

    // Serialize all app data
    final data = {
      'accounts': encryptIfRequested(
          _storageService.getAllAccounts().map((e) => e.toMap()).toList()),
      'transactions_v2': _preparePartitionedTransactions(
          _storageService.getAllTransactions(), encryptIfRequested),
      'loans_v2': _preparePartitionedLoans(
          _storageService.getAllLoans(), encryptIfRequested),
      'recurring': encryptIfRequested(
          _storageService.getAllRecurring().map((e) => e.toMap()).toList()),
      'categories':
          _storageService.getAllCategories().map((e) => e.toMap()).toList(),
      'profiles': encryptIfRequested(
          _storageService.getProfiles().map((e) => e.toMap()).toList()),
      'settings': encryptIfRequested(settingsToEncrypt),
      'last_sync': lastSync,
      'insurance_policies': encryptIfRequested(_storageService
          .getInsurancePolicies()
          .map((e) => e.toMap())
          .toList()),
      'tax_rules_v2': _preparePartitionedTaxRules(
          _taxConfigService.getAllRules(), encryptIfRequested),
      'tax_data_v2': _preparePartitionedTaxData(
          _storageService.getAllTaxYearData(), encryptIfRequested),
      'lending_records': encryptIfRequested(
          _storageService.getLendingRecords().map((e) => e.toMap()).toList()),
      'is_encrypted': encryption != null,
      'sync_format_version': 2,
    };

    try {
      await _cloudStorage.syncData(user.uid, _sanitizeForSync(data));
    } on FirebaseException catch (e) {
      _handleSyncError(e);
    }
  }

  Map<String, dynamic> _preparePartitionedTransactions(
      List<Transaction> transactions, dynamic Function(dynamic) encryptor) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var t in transactions) {
      final bucket =
          "${t.date.year}-${t.date.month.toString().padLeft(2, '0')}";
      grouped.putIfAbsent(bucket, () => []).add(t.toMap());
    }
    return grouped.map((k, v) => MapEntry(k, encryptor(v)));
  }

  Map<String, dynamic> _preparePartitionedLoans(
      List<Loan> loans, dynamic Function(dynamic) encryptor) {
    return {for (var l in loans) l.id: encryptor(l.toMap())};
  }

  Map<String, dynamic> _preparePartitionedTaxRules(
      Map<int, TaxRules> rules, dynamic Function(dynamic) encryptor) {
    return {
      for (var entry in rules.entries)
        entry.key.toString(): encryptor(entry.value.toMap())
    };
  }

  Map<String, dynamic> _preparePartitionedTaxData(
      List<TaxYearData> taxData, dynamic Function(dynamic) encryptor) {
    return {for (var td in taxData) td.year.toString(): encryptor(td.toMap())};
  }

  void _handleSyncError(FirebaseException e) {
    if (e.code.contains('unauthenticated') ||
        e.code.contains('unavailable') ||
        e.code.contains('permission-denied')) {
      // coverage:ignore-line
      throw Exception(
          "Cloud Sync temporarily unavailable (${e.code}). Please try again later.");
    }
    throw e;
  }

  /// Recursively replaces non-JSON-encodable doubles (Infinity, NaN) with 0.0.
  dynamic _sanitizeForSync(dynamic data) {
    if (data is double) {
      if (data.isInfinite || data.isNaN) {
        return 0.0;
      }
      return data;
    } else if (data is Map) {
      return data
          .map(
              (key, value) => MapEntry(key.toString(), _sanitizeForSync(value)))
          .cast<String, dynamic>();
    } else if (data is List) {
      return data.map((e) => _sanitizeForSync(e)).toList().cast<dynamic>();
    }
    return data;
  }

  Future<void> restoreFromCloud({String? passcode}) async {
    _checkRegionLock();
    final rawData = await _validateAuthAndFetchData();
    if (rawData == null) {
      throw Exception("No cloud data found");
    }

    final data = _sanitizeFirestoreData(rawData) as Map<String, dynamic>;

    final bool isEncrypted = data['is_encrypted'] == true;
    final encryption =
        isEncrypted ? EncryptionService() : null; // coverage:ignore-line

    if (isEncrypted && (passcode == null || passcode.isEmpty)) {
      // coverage:ignore-line
      throw Exception(
          "Passcode required for encrypted backup"); // coverage:ignore-line
    }

    dynamic decrypt(dynamic payload) {
      if (!isEncrypted || payload == null || payload is! String) {
        // coverage:ignore-line
        return payload;
      }
      try {
        final decryptedString =
            encryption!.decryptData(payload, passcode!); // coverage:ignore-line
        return jsonDecode(decryptedString); // coverage:ignore-line
      } catch (e) {
        throw Exception(
            "Incorrect passcode or corrupted data"); // coverage:ignore-line
      }
    }

    // Cache local Tax Data before wiping
    final localTaxData = _storageService.getAllTaxYearData();

    await _storageService.clearAllData();

    await _restoreProfiles(data, decrypt);
    await _restoreCategories(data);
    await _restoreAccounts(data, decrypt);
    await _restoreTransactions(data, decrypt);
    await _restoreLoans(data, decrypt);
    await _restoreRecurring(data, decrypt);
    await _restoreSettings(data, decrypt);
    await _restoreInsurancePolicies(data, decrypt);
    await _restoreTaxRules(data, decrypt);
    final restoredTaxYears = await _restoreTaxData(data, decrypt);
    await _mergeLocalTaxSafety(localTaxData, restoredTaxYears);
    await _restoreLendingRecords(data, decrypt);
  }

  Future<Map<String, dynamic>?> _validateAuthAndFetchData() async {
    final auth = _auth;
    if (auth == null) {
      throw Exception(errFirebaseNotInit); // coverage:ignore-line
    }

    final user = auth.currentUser;
    if (user == null) {
      throw Exception(errUserNotLoggedIn); // coverage:ignore-line
    }

    try {
      return await _cloudStorage.fetchData(user.uid);
    } on FirebaseException catch (e) {
      if (e.code.contains('unauthenticated') ||
          e.code.contains('unavailable')) {
        // coverage:ignore-line
        throw Exception("Cloud Restore failed: Connection issues (${e.code})");
      }
      rethrow;
    }
  }

  Future<void> _restoreProfiles(
      Map<String, dynamic> data, Function(dynamic) decrypt) async {
    if (data['profiles'] == null) return;
    final profiles = decrypt(data['profiles']);
    for (var p in (profiles as List)) {
      await _storageService
          .saveProfile(Profile.fromMap(Map<String, dynamic>.from(p)));
    }
  }

  Future<void> _restoreCategories(Map<String, dynamic> data) async {
    if (data['categories'] == null) return;
    // coverage:ignore-start
    for (var c in (data['categories'] as List)) {
      await _storageService.addCategory(
          Category.fromMap(Map<String, dynamic>.from(c)),
          // coverage:ignore-end
          isRestore: true);
    }
  }

  Future<void> _restoreAccounts(
      Map<String, dynamic> data, Function(dynamic) decrypt) async {
    if (data['accounts'] == null) return;
    final accList = decrypt(data['accounts']);
    for (var a in (accList as List)) {
      final acc = Account.fromMap(Map<String, dynamic>.from(a));
      await _storageService.saveAccount(acc);

      if (acc.type == AccountType.creditCard && acc.billingCycleDay != null) {
        await _storageService.initRolloverForImport(
            acc.id, acc.billingCycleDay!);
      }
    }
  }

  Future<void> _restoreTransactions(
      Map<String, dynamic> data, Function(dynamic) decrypt) async {
    final v2Data = data['transactions_v2'];
    if (v2Data == null || v2Data is! Map) return;

    for (var bucketValue in v2Data.values) {
      final txns = decrypt(bucketValue);
      for (var t in (txns as List)) {
        await _storageService.saveTransaction(
            Transaction.fromMap(Map<String, dynamic>.from(t)),
            applyImpact: false);
      }
    }
  }

  Future<void> _restoreLoans(
      Map<String, dynamic> data, Function(dynamic) decrypt) async {
    final v2Data = data['loans_v2'];
    if (v2Data == null || v2Data is! Map) return;

    for (var bucketValue in v2Data.values) {
      final loanMap = decrypt(bucketValue);
      await _storageService
          .saveLoan(Loan.fromMap(Map<String, dynamic>.from(loanMap)));
    }
  }

  Future<void> _restoreRecurring(
      Map<String, dynamic> data, Function(dynamic) decrypt) async {
    if (data['recurring'] == null) return;
    final recs = decrypt(data['recurring']);
    for (var rt in (recs as List)) {
      await _storageService.saveRecurringTransaction(
          RecurringTransaction.fromMap(Map<String, dynamic>.from(rt)));
    }
  }

  Future<void> _restoreSettings(
      Map<String, dynamic> data, Function(dynamic) decrypt) async {
    if (data['settings'] == null) return;
    final Map<String, dynamic> finalSettings = {};

    if (data['settings'] is Map) {
      finalSettings.addAll(Map<String, dynamic>.from(data['settings']));
    } else {
      final decoded = decrypt(data['settings']); // coverage:ignore-line
      finalSettings
          .addAll(Map<String, dynamic>.from(decoded)); // coverage:ignore-line
    }

    // Never restore active connection info from backup payload
    finalSettings.remove('isLoggedIn');

    if (data['last_sync'] != null) {
      finalSettings['last_sync'] = data['last_sync']; // coverage:ignore-line
    }

    await _storageService.saveSettings(finalSettings);
  }

  Future<void> _restoreInsurancePolicies(
      Map<String, dynamic> data, Function(dynamic) decrypt) async {
    if (data['insurance_policies'] == null) return;
    final List<InsurancePolicy> policies = [];
    final insPolicies = decrypt(data['insurance_policies']);
    for (var p in (insPolicies as List)) {
      policies.add(InsurancePolicy.fromMap(Map<String, dynamic>.from(p)));
    }
    await _storageService.saveInsurancePolicies(policies);
  }

  Future<void> _restoreTaxRules(
      Map<String, dynamic> data, Function(dynamic) decrypt) async {
    final v2Data = data['tax_rules_v2'];
    if (v2Data == null || v2Data is! Map) return;

    final Map<int, TaxRules> taxRules = {};
    for (var entry in v2Data.entries) {
      final year = int.parse(entry.key.toString());
      final rulesMap = decrypt(entry.value);
      taxRules[year] = TaxRules.fromMap(Map<String, dynamic>.from(rulesMap));
    }
    await _taxConfigService.restoreAllRules(taxRules);
  }

  Future<Set<int>> _restoreTaxData(
      Map<String, dynamic> data, Function(dynamic) decrypt) async {
    final restoredTaxYears = <int>{};
    final v2Data = data['tax_data_v2'];

    if (v2Data == null || v2Data is! Map) return restoredTaxYears;

    for (var bucketValue in v2Data.values) {
      final tdMap = decrypt(bucketValue);
      final taxData = TaxYearData.fromMap(Map<String, dynamic>.from(tdMap));
      await _storageService.saveTaxYearData(taxData);
      restoredTaxYears.add(taxData.year);
    }
    return restoredTaxYears;
  }

  Future<void> _mergeLocalTaxSafety(
      List<TaxYearData> localTaxData, Set<int> restoredTaxYears) async {
    for (final local in localTaxData) {
      if (!restoredTaxYears.contains(local.year)) {
        await _storageService.saveTaxYearData(local);
        continue;
      }

      final restored = _storageService.getTaxYearData(local.year);
      if (restored == null) continue;
      if (restored.salary.history.isNotEmpty || local.salary.history.isEmpty) {
        continue;
      }

      // Cloud had empty salary, Local had real salary → merge
      final merged = restored.copyWith(
        salary: local.salary,
        houseProperties: restored.houseProperties.isEmpty
            ? local.houseProperties
            : restored.houseProperties, // coverage:ignore-line
        businessIncomes: restored.businessIncomes.isEmpty
            ? local.businessIncomes
            : restored.businessIncomes, // coverage:ignore-line
      );
      await _storageService.saveTaxYearData(merged);
    }
  }

  Future<void> _restoreLendingRecords(
      Map<String, dynamic> data, Function(dynamic) decrypt) async {
    if (data['lending_records'] == null) return;
    final lendings = decrypt(data['lending_records']);
    for (var l in (lendings as List)) {
      await _storageService.saveLendingRecord(
          LendingRecord.fromMap(Map<String, dynamic>.from(l)));
    }
  }

  Future<void> deleteCloudData() async {
    final auth = _auth;
    if (auth == null) {
      throw Exception(errFirebaseNotInit); // coverage:ignore-line
    }
    final user = auth.currentUser;
    if (user == null) {
      throw Exception(errUserNotLoggedIn);
    }

    await _cloudStorage.deleteData(user.uid);
  }

  /// Recursively converts [firestore.Timestamp] to [DateTime] and ensures Maps have String keys.
  dynamic _sanitizeFirestoreData(dynamic data) {
    if (data is firestore.Timestamp) {
      return data.toDate().toIso8601String(); // coverage:ignore-line
    }
    if (data is Map) {
      // Create a new Map to avoid mutation issues and ensure String keys
      final newMap = <String, dynamic>{};
      data.forEach((key, value) {
        newMap[key.toString()] = _sanitizeFirestoreData(value);
      });
      return newMap;
    }
    if (data is List) {
      return data.map((item) => _sanitizeFirestoreData(item)).toList();
    }
    return data;
  }
}
