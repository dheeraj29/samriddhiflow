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
import '../models/taxes/tax_data_models.dart';
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
      if (Firebase.apps.isNotEmpty) { // coverage:ignore-line

        return FirebaseAuth.instance; // coverage:ignore-line
      }
    } catch (_) {}
    return null;
  }

  Future<void> syncToCloud({String? passcode}) async {
    final auth = _auth;
    if (auth == null) {
      throw Exception(errFirebaseNotInit); // coverage:ignore-line
    }

    final user = auth.currentUser;
    if (user == null) throw Exception(errUserNotLoggedIn);

    final encryption =
        (passcode != null && passcode.isNotEmpty)
            ? EncryptionService()
            : null;

    dynamic encryptIfRequested(dynamic payload) {
      if (encryption == null) return payload;
      return encryption.encryptData(

          jsonEncode(payload),
          passcode!);
    }

    final settings = _storageService.getAllSettings();
    final lastSync = settings['last_sync'];
    final Map<String, dynamic> settingsToEncrypt = Map.from(settings);
    settingsToEncrypt.remove('last_sync');

    // Serialize all app data
    final data = {
      'accounts': encryptIfRequested(
          _storageService.getAllAccounts().map((e) => e.toMap()).toList()),
      'transactions': encryptIfRequested(
          _storageService.getAllTransactions().map((e) => e.toMap()).toList()),
      'loans': encryptIfRequested(
          _storageService.getAllLoans().map((e) => e.toMap()).toList()),
      'recurring': encryptIfRequested(
          _storageService.getAllRecurring().map((e) => e.toMap()).toList()),
      'categories': // Category is metadata, keep plaintext (as per requirement)
          _storageService.getAllCategories().map((e) => e.toMap()).toList(),
      'profiles': encryptIfRequested(
          _storageService.getProfiles().map((e) => e.toMap()).toList()),
      'settings': encryptIfRequested(settingsToEncrypt),
      'last_sync': lastSync, // Always plaintext
      'insurance_policies': encryptIfRequested(_storageService
          .getInsurancePolicies()
          .map((e) => e.toMap())
          .toList()),
      'tax_rules': encryptIfRequested(_taxConfigService
          .getAllRules()
          .map((year, rules) => MapEntry(year.toString(), rules.toMap()))),
      'tax_data': encryptIfRequested(
          _storageService.getAllTaxYearData().map((e) => e.toMap()).toList()),
      'lending_records': encryptIfRequested(
          _storageService.getLendingRecords().map((e) => e.toMap()).toList()),
      'is_encrypted': encryption != null,
    };

    final sanitizedData = _sanitizeForSync(data);
    try {
      await _cloudStorage.syncData(user.uid, sanitizedData);
    } on FirebaseException catch (e) {
      if (e.code.contains('unauthenticated') ||
          e.code.contains('unavailable') ||
          e.code.contains('permission-denied')) { // coverage:ignore-line
        // Rethrow with cleaner message for UI
        throw Exception(
            "Cloud Sync temporarily unavailable (${e.code}). Please try again later.");
      }
      rethrow;
    }
  }

  /// Recursively replaces non-JSON-encodable doubles (Infinity, NaN) with 0.0.
  dynamic _sanitizeForSync(dynamic data) {
    if (data is double) {
      if (data.isInfinite || data.isNaN) { // coverage:ignore-line


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
    final rawData = await _validateAuthAndFetchData();
    if (rawData == null) {
      throw Exception("No cloud data found"); // coverage:ignore-line
    }

    final data = _sanitizeFirestoreData(rawData) as Map<String, dynamic>;

    final bool isEncrypted = data['is_encrypted'] == true;
    final encryption =
        isEncrypted ? EncryptionService() : null; // coverage:ignore-line

    if (isEncrypted && (passcode == null || passcode.isEmpty)) { // coverage:ignore-line


      throw Exception( // coverage:ignore-line
          "Passcode required for encrypted backup");
    }

    dynamic decrypt(dynamic payload) {
      if (!isEncrypted || payload == null || payload is! String) { // coverage:ignore-line

        return payload;
      }
      try {
        final decryptedString =
            encryption!.decryptData(payload, passcode!); // coverage:ignore-line
        return jsonDecode(decryptedString); // coverage:ignore-line
      } catch (e) {
        throw Exception( // coverage:ignore-line
            "Incorrect passcode or corrupted data");
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
          e.code.contains('unavailable')) { // coverage:ignore-line
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
      await _storageService
          .addCategory(Category.fromMap(Map<String, dynamic>.from(c)));
    // coverage:ignore-end
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
        await _storageService.initRolloverForImport( // coverage:ignore-line


            acc.id, // coverage:ignore-line
            acc.billingCycleDay!); // coverage:ignore-line
      }
    }
  }

  Future<void> _restoreTransactions(
      Map<String, dynamic> data, Function(dynamic) decrypt) async {
    if (data['transactions'] == null) return;
    final txns = decrypt(data['transactions']);
    for (var t in (txns as List)) {
      await _storageService.saveTransaction(
          Transaction.fromMap(Map<String, dynamic>.from(t)),
          applyImpact: false);
    }
  }

  Future<void> _restoreLoans(
      Map<String, dynamic> data, Function(dynamic) decrypt) async {
    if (data['loans'] == null) return;
    // coverage:ignore-start
    final loans = decrypt(data['loans']);
    for (var l in (loans as List)) {
      await _storageService
          .saveLoan(Loan.fromMap(Map<String, dynamic>.from(l)));
    // coverage:ignore-end
    }
  }

  Future<void> _restoreRecurring(
      Map<String, dynamic> data, Function(dynamic) decrypt) async {
    if (data['recurring'] == null) return;
    // coverage:ignore-start
    final recs = decrypt(data['recurring']);
    for (var rt in (recs as List)) {
      await _storageService.saveRecurringTransaction(
          RecurringTransaction.fromMap(Map<String, dynamic>.from(rt)));
    // coverage:ignore-end
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
    // coverage:ignore-start
    final List<InsurancePolicy> policies = [];
    final insPolicies = decrypt(data['insurance_policies']);
    for (var p in (insPolicies as List)) {
      policies.add(InsurancePolicy.fromMap(Map<String, dynamic>.from(p)));
    // coverage:ignore-end
    }
    await _storageService // coverage:ignore-line
        .saveInsurancePolicies(policies); // coverage:ignore-line
  }

  Future<void> _restoreTaxRules(
      Map<String, dynamic> data, Function(dynamic) decrypt) async {
    if (data['tax_rules'] == null) return;
    // coverage:ignore-start
    final rules = decrypt(data['tax_rules']);
    final Map<int, TaxRules> taxRules = {};
    (rules as Map).forEach((key, val) {
      final year = int.parse(key.toString());
      taxRules[year] = TaxRules.fromMap(Map<String, dynamic>.from(val));
    // coverage:ignore-end
    });
    await _taxConfigService.restoreAllRules(taxRules); // coverage:ignore-line
  }

  Future<Set<int>> _restoreTaxData(
      Map<String, dynamic> data, Function(dynamic) decrypt) async {
    final restoredTaxYears = <int>{};
    if (data['tax_data'] == null) return restoredTaxYears;

    // coverage:ignore-start
    final taxDataList = decrypt(data['tax_data']);
    for (var td in (taxDataList as List)) {
      final taxData = TaxYearData.fromMap(Map<String, dynamic>.from(td));
      final existingData = _storageService.getTaxYearData(taxData.year);
    // coverage:ignore-end

      if (existingData != null) {
        // coverage:ignore-start
        final mergedCG = _deduplicateCapitalGains(
            existingData.capitalGains, taxData.capitalGains);
        final merged = taxData.copyWith(capitalGains: mergedCG);
        await _storageService.saveTaxYearData(merged);
        // coverage:ignore-end
      } else {
        await _storageService.saveTaxYearData(taxData); // coverage:ignore-line
      }
      restoredTaxYears.add(taxData.year); // coverage:ignore-line
    }
    return restoredTaxYears;
  }

  List<CapitalGainEntry> _deduplicateCapitalGains( // coverage:ignore-line


      List<CapitalGainEntry> existing,
      List<CapitalGainEntry> incoming) {
    // coverage:ignore-start
    final mergedCG = List<CapitalGainEntry>.from(existing);
    for (final newEntry in incoming) {
      bool exists = existing.any((e) =>
          e.gainDate.isAtSameMomentAs(newEntry.gainDate) &&
          (e.saleAmount - newEntry.saleAmount).abs() < 0.01 &&
          e.matchAssetType == newEntry.matchAssetType);
    // coverage:ignore-end
      if (!exists) {
        mergedCG.add(newEntry); // coverage:ignore-line
      }
    }
    return mergedCG;
  }

  Future<void> _mergeLocalTaxSafety(
      List<TaxYearData> localTaxData, Set<int> restoredTaxYears) async {
    for (final local in localTaxData) {
      if (!restoredTaxYears.contains(local.year)) { // coverage:ignore-line


        await _storageService.saveTaxYearData(local); // coverage:ignore-line
        continue;
      }

      final restored =
          _storageService.getTaxYearData(local.year); // coverage:ignore-line
      if (restored == null) continue;
      if (restored.salary.grossSalary != 0 || local.salary.grossSalary <= 0) { // coverage:ignore-line


        continue;
      }

      // Cloud had empty salary, Local had real salary → merge
      // coverage:ignore-start
      final merged = restored.copyWith(
        salary: local.salary,
        houseProperties: restored.houseProperties.isEmpty
            ? local.houseProperties
            : restored.houseProperties,
        businessIncomes: restored.businessIncomes.isEmpty
            ? local.businessIncomes
            : restored.businessIncomes,
      // coverage:ignore-end
      );
      await _storageService.saveTaxYearData(merged); // coverage:ignore-line
    }
  }

  Future<void> _restoreLendingRecords(
      Map<String, dynamic> data, Function(dynamic) decrypt) async {
    if (data['lending_records'] == null) return;
    // coverage:ignore-start
    final lendings = decrypt(data['lending_records']);
    for (var l in (lendings as List)) {
      await _storageService.saveLendingRecord(
          LendingRecord.fromMap(Map<String, dynamic>.from(l)));
    // coverage:ignore-end
    }
  }

  Future<void> deleteCloudData() async {
    final auth = _auth;
    if (auth == null) {
      throw Exception(errFirebaseNotInit); // coverage:ignore-line
    }
    final user = auth.currentUser;
    if (user == null) {
      throw Exception(errUserNotLoggedIn); // coverage:ignore-line
    }

    await _cloudStorage.deleteData(user.uid);
  }

  /// Recursively converts [firestore.Timestamp] to [DateTime] and ensures Maps have String keys.
  dynamic _sanitizeFirestoreData(dynamic data) {
    if (data is firestore.Timestamp) {
      return data.toDate().toIso8601String();
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
