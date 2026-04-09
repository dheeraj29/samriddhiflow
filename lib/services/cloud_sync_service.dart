import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:firebase_core/firebase_core.dart';
import 'cloud_storage_interface.dart';
import 'firestore_storage_service.dart';
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
import 'subscription_service.dart';
import '../models/lending_record.dart';
import '../models/investment.dart';
import 'encryption_service.dart';
import 'package:uuid/uuid.dart';

const errUserNotLoggedIn = 'User not logged in';
const errFirebaseNotInit = 'Firebase not initialized';

class CloudSyncService {
  final CloudStorageInterface _cloudStorage;
  final StorageService _storageService;
  final TaxConfigService _taxConfigService;
  final SubscriptionService _subscriptionService;
  final FirebaseAuth? _firebaseAuth;

  CloudSyncService(this._cloudStorage, this._storageService,
      this._taxConfigService, this._subscriptionService,
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
    final region = _storageService.getCloudDatabaseRegion();
    if (region.toUpperCase() != 'INDIA') {
      throw Exception(// coverage:ignore-line
          'Cloud Synchronization is currently only available for the India region.');
    }
  }

  void _verifySubscription() {
    if (!_subscriptionService.isCloudSyncEnabled()) {
      throw Exception(// coverage:ignore-line
          "Premium Subscription required for Cloud Backup & Restore.");
    }
  }

  Future<void> updateActiveSessionId(String deviceId) async {
    final auth = _auth;
    if (auth == null) return;
    final user = auth.currentUser;
    if (user == null) return;
    try {
      await user.getIdToken(true); // Force token refresh for Rules enforcement
      await _cloudStorage.setActiveSessionId(user.uid, deviceId);
    } catch (_) {
      // Ignore if offline or failing
    }
  }

  Future<String?> getCloudSessionId(String uid) async {
    try {
      return await _cloudStorage.getActiveSessionId(uid);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearActiveSessionId(String uid) async {
    // coverage:ignore-line
    try {
      await _cloudStorage.clearActiveSessionId(uid); // coverage:ignore-line
    } catch (_) {
      // Ignore failures during logout cleanup
    }
  }

  Future<void> _verifySession(User user) async {
    // 1. Force token refresh to satisfy <12s Token Issue Time requirement in Firestore Rules
    await user.getIdToken(true);

    // 2. Enforce Single Device Session Logic
    final cloudSessionId = await _cloudStorage.getActiveSessionId(user.uid);
    final localSessionId = _storageService.getSessionId();

    if (localSessionId == null ||
        (cloudSessionId != null && cloudSessionId != localSessionId)) {
      throw Exception(
          "SESSION_EXPIRED:Logged in from another device."); // coverage:ignore-line
    }
  }

  /// Explicitly claims the cloud session for the current device.
  /// This bypasses the match check and effectively takes over ownership.
  Future<void> claimSession() async {
    final auth = _auth;
    if (auth == null) {
      throw Exception(errFirebaseNotInit); // coverage:ignore-line
    }
    final user = auth.currentUser;
    if (user == null) {
      throw Exception(errUserNotLoggedIn); // coverage:ignore-line
    }

    // Generate local ID if missing
    var localSessionId = _storageService.getSessionId();
    if (localSessionId == null) {
      localSessionId = const Uuid().v4(); // coverage:ignore-line
      await _storageService
          .setSessionId(localSessionId); // coverage:ignore-line
    }

    await updateActiveSessionId(localSessionId);
  }

  Future<String> _ensureLocalSessionId() async {
    var sessionId = _storageService.getSessionId();
    if (sessionId == null) {
      sessionId = const Uuid().v4();
      await _storageService.setSessionId(sessionId);
    }
    return sessionId;
  }

  Future<void> deactivateAndCleanCloud() async {
    // coverage:ignore-line
    _verifySubscription(); // coverage:ignore-line

    final auth = _auth; // coverage:ignore-line
    if (auth == null) {
      throw Exception(errFirebaseNotInit); // coverage:ignore-line
    }

    final user = auth.currentUser; // coverage:ignore-line
    if (user == null) {
      throw Exception(errUserNotLoggedIn); // coverage:ignore-line
    }

    await _cloudStorage.clearActiveSessionId(user.uid); // coverage:ignore-line
    await _cloudStorage.deleteData(user.uid); // coverage:ignore-line
  }

  Future<void> syncToCloud({String? passcode, String? appPin}) async {
    _verifySubscription();
    _checkRegionLock();
    final auth = _auth;
    if (auth == null) {
      throw Exception(errFirebaseNotInit); // coverage:ignore-line
    }

    final user = auth.currentUser;
    if (user == null) throw Exception(errUserNotLoggedIn);

    // Ensure session exists before verification (first backup on a new device).
    // Uses direct write (not fire-and-forget) so the cloud is guaranteed to
    // reflect the local session ID before _verifySession reads it.
    final sessionId = await _ensureLocalSessionId();
    await user.getIdToken(true);
    await _cloudStorage.setActiveSessionId(user.uid, sessionId);

    await _verifySession(user);

    final encryption =
        (passcode != null && passcode.isNotEmpty) ? EncryptionService() : null;

    Uint8List? preDerivedKey;
    Uint8List? salt;
    if (encryption != null) {
      salt = encryption.generateSalt();
      preDerivedKey = await encryption.deriveKey(passcode!, salt);
    }

    Future<dynamic> encryptIfRequested(dynamic payload) async {
      if (encryption == null) return payload;
      return await encryption.encryptData(jsonEncode(payload), passcode!,
          preDerivedKey: preDerivedKey, salt: salt);
    }

    final settings = _storageService.getAllSettings();
    final lastSync = settings['last_sync'];

    // Scrub local-only / device-specific settings
    final Map<String, dynamic> settingsToEncrypt = Map.from(settings);
    settingsToEncrypt.remove('last_sync');
    settingsToEncrypt.remove('sessionId');
    settingsToEncrypt.remove('isLoggedIn');
    settingsToEncrypt.remove('lastLogin');
    settingsToEncrypt.remove('txnsSinceBackup');

    // Inject plaintext appPin for backup if provided
    if (appPin != null) {
      settingsToEncrypt['appPin'] = appPin; // coverage:ignore-line
    }

    // Serialize all app data
    final data = await _createSyncPayload(
      encryptor: encryptIfRequested,
      isEncrypted: encryption != null,
      settingsToEncrypt: settingsToEncrypt,
      lastSync: lastSync,
    );

    try {
      await _cloudStorage.syncData(user.uid, _sanitizeForSync(data));
    } on FirebaseException catch (e) {
      _handleSyncError(e);
    }
  }

  Future<Map<String, dynamic>> _createSyncPayload({
    required Future<dynamic> Function(dynamic) encryptor,
    required bool isEncrypted,
    required Map<String, dynamic> settingsToEncrypt,
    dynamic lastSync,
  }) async {
    return {
      'accounts': await encryptor(
          _storageService.getAllAccounts().map((e) => e.toMap()).toList()),
      'transactions_v2': await _preparePartitionedTransactions(
          _storageService.getAllTransactions(), encryptor),
      'loans_v2': await _preparePartitionedLoans(
          _storageService.getAllLoans(), encryptor),
      'recurring': await encryptor(
          _storageService.getAllRecurring().map((e) => e.toMap()).toList()),
      'categories':
          _storageService.getAllCategories().map((e) => e.toMap()).toList(),
      'profiles': await encryptor(
          _storageService.getProfiles().map((e) => e.toMap()).toList()),
      'settings': await encryptor(settingsToEncrypt),
      'last_sync': lastSync,
      'insurance_policies': await encryptor(_storageService
          .getInsurancePoliciesGlobal()
          .map((e) => e.toMap())
          .toList()),
      'tax_rules_v2': await _preparePartitionedTaxRules(
          _taxConfigService.getAllRulesGlobal(), encryptor),
      'tax_data_v2': await _preparePartitionedTaxData(
          _storageService.getAllTaxYearDataGlobal(), encryptor),
      'lending_records': await _preparePartitionedLendingRecords(
          _storageService.getLendingRecordsGlobal(), encryptor),
      'is_encrypted': isEncrypted,
      'sync_format_version': 2,
      'investments_v2': await _preparePartitionedInvestments(
          _storageService.getAllInvestments(), encryptor),
    };
  }

  Future<dynamic> Function(dynamic) _createDecryptor({
    required bool isEncrypted,
    required EncryptionService? encryption,
    required String? passcode,
  }) {
    Uint8List? sessionKey;

    return (dynamic payload) async {
      if (!isEncrypted || payload == null || payload is! String) {
        // coverage:ignore-line
        return payload;
      }
      try {
        if (sessionKey == null) {
          // coverage:ignore-start
          final parts = payload.split('|');
          if (parts.length == 6) {
            final salt = base64.decode(parts[2]);
            sessionKey = await encryption!.deriveKey(passcode!, salt);
            // coverage:ignore-end
          }
        }

        final decryptedString = await encryption!.decryptData(
            payload, passcode!,
            preDerivedKey: sessionKey); // coverage:ignore-line
        return jsonDecode(decryptedString); // coverage:ignore-line
      } catch (e) {
        throw Exception(
            "Incorrect passcode or corrupted data"); // coverage:ignore-line
      }
    };
  }

  Future<Map<String, dynamic>> _preparePartitionedTransactions(
      List<Transaction> transactions,
      Future<dynamic> Function(dynamic) encryptor) async {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var t in transactions) {
      final bucket =
          "${t.date.year}-${t.date.month.toString().padLeft(2, '0')}";
      grouped.putIfAbsent(bucket, () => []).add(t.toMap());
    }

    final Map<String, dynamic> encryptedMap = {};
    for (var entry in grouped.entries) {
      encryptedMap[entry.key] = await encryptor(entry.value);
    }
    return encryptedMap;
  }

  Future<Map<String, dynamic>> _preparePartitionedLoans(
      List<Loan> loans, Future<dynamic> Function(dynamic) encryptor) async {
    final Map<String, dynamic> encryptedMap = {};
    for (var l in loans) {
      encryptedMap[l.id] = await encryptor(l.toMap()); // coverage:ignore-line
    }
    return encryptedMap;
  }

  Future<Map<String, dynamic>> _preparePartitionedTaxRules(
      Map<String, TaxRules> rules,
      Future<dynamic> Function(dynamic) encryptor) async {
    final Map<String, dynamic> encryptedMap = {};
    for (var entry in rules.entries) {
      encryptedMap[entry.key] = await encryptor(entry.value.toMap());
    }
    return encryptedMap;
  }

  Future<Map<String, dynamic>> _preparePartitionedTaxData(
      List<TaxYearData> taxData,
      Future<dynamic> Function(dynamic) encryptor) async {
    final Map<String, dynamic> encryptedMap = {};
    for (var td in taxData) {
      encryptedMap[td.year.toString()] = await encryptor(td.toMap());
    }
    return encryptedMap;
  }

  Future<Map<String, dynamic>> _preparePartitionedInvestments(
      List<Investment> investments,
      Future<dynamic> Function(dynamic) encryptor) async {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var i in investments) {
      final bucket =
          "${i.acquisitionDate.year}-${i.acquisitionDate.month.toString().padLeft(2, '0')}";
      grouped.putIfAbsent(bucket, () => []).add(i.toMap());
    }

    final Map<String, dynamic> encryptedMap = {};
    for (var entry in grouped.entries) {
      encryptedMap[entry.key] = await encryptor(entry.value);
    }
    return encryptedMap;
  }

  Future<Map<String, dynamic>> _preparePartitionedLendingRecords(
      List<LendingRecord> records,
      Future<dynamic> Function(dynamic) encryptor) async {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var r in records) {
      final bucket =
          "${r.date.year}-${r.date.month.toString().padLeft(2, '0')}";
      grouped.putIfAbsent(bucket, () => []).add(r.toMap());
    }

    final Map<String, dynamic> encryptedMap = {};
    for (var entry in grouped.entries) {
      encryptedMap[entry.key] = await encryptor(entry.value);
    }
    return encryptedMap;
  }

  void _handleSyncError(FirebaseException e) {
    if (e.code.contains('unauthenticated') ||
        e.code.contains('unavailable') ||
        e.code.contains(FirestoreStorageService.permissionDeniedCode)) {
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

  Future<void> _syncSessionBeforeRestore() async {
    final auth = _auth;
    if (auth == null || auth.currentUser == null) return;

    final existingLocalId = _storageService.getSessionId();
    if (existingLocalId != null) {
      return; // Existing device — let _verifySession handle it
    }

    // New device: create a local session and push it to cloud
    final newLocalId = await _ensureLocalSessionId();
    final user = auth.currentUser!;
    await user.getIdToken(true);
    await _cloudStorage.setActiveSessionId(user.uid, newLocalId);
  }

  Map<String, dynamic> _captureLocalIdentity() {
    return {
      'pId': _storageService.getActiveProfileId(),
      'sId': _storageService.getSessionId(),
      'isLog': _storageService.getAuthFlag(),
      'lLog': _storageService.getLastLogin(),
      'reg': _storageService.getCloudDatabaseRegion(),
    };
  }

  Future<void> _restoreLocalIdentity(Map<String, dynamic> identity) async {
    final sId = identity['sId'];
    final lLog = identity['lLog'];
    if (sId != null) {
      await _storageService.setSessionId(sId);
    }
    await _storageService.setAuthFlag(identity['isLog']);
    if (lLog != null) {
      await _storageService.setLastLogin(lLog);
    }
    await _storageService.setCloudDatabaseRegion(identity['reg']);
    await _storageService.setActiveProfileId(identity['pId']);
  }

  Future<void> restoreFromCloud({String? passcode}) async {
    _verifySubscription();
    _checkRegionLock();

    await _syncSessionBeforeRestore();

    final rawData = await _validateAuthAndFetchData();
    if (rawData == null) {
      throw Exception("No cloud data found");
    }

    final sessionId = _storageService.getSessionId();
    if (sessionId != null) {
      await updateActiveSessionId(sessionId);
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

    final decrypt = _createDecryptor(
      isEncrypted: isEncrypted,
      encryption: encryption,
      passcode: passcode,
    );

    // Cache local Tax Data and critical Session state before wiping
    final localTaxData = _storageService.getAllTaxYearData();
    final identity = _captureLocalIdentity();

    await _storageService.clearAllData(fullWipe: true);

    // Immediately restore Session identity to prevent verification failures
    await _restoreLocalIdentity(identity);

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
    await _restoreInvestments(data, decrypt);
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
      await _verifySession(user);
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

  Future<void> _restoreProfiles(Map<String, dynamic> data,
      Future<dynamic> Function(dynamic) decrypt) async {
    if (data['profiles'] == null) return;
    final profiles = await decrypt(data['profiles']);
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

  Future<void> _restoreAccounts(Map<String, dynamic> data,
      Future<dynamic> Function(dynamic) decrypt) async {
    if (data['accounts'] == null) return;
    final accList = await decrypt(data['accounts']);
    for (var a in (accList as List)) {
      final acc = Account.fromMap(Map<String, dynamic>.from(a));
      await _storageService.saveAccount(acc);

      if (acc.type == AccountType.creditCard && acc.billingCycleDay != null) {
        await _storageService.initRolloverForImport(
            acc.id, acc.billingCycleDay!);
      }
    }
  }

  Future<void> _restoreTransactions(Map<String, dynamic> data,
      Future<dynamic> Function(dynamic) decrypt) async {
    final v2Data = data['transactions_v2'];
    if (v2Data == null || v2Data is! Map) return;

    for (var bucketValue in v2Data.values) {
      final txns = await decrypt(bucketValue);
      for (var t in (txns as List)) {
        await _storageService.saveTransaction(
            Transaction.fromMap(Map<String, dynamic>.from(t)),
            applyImpact: false);
      }
    }
  }

  Future<void> _restoreLoans(Map<String, dynamic> data,
      Future<dynamic> Function(dynamic) decrypt) async {
    final v2Data = data['loans_v2'];
    if (v2Data == null || v2Data is! Map) return;

    for (var loanData in v2Data.values) {
      final l = await decrypt(loanData);
      await _storageService
          .saveLoan(Loan.fromMap(Map<String, dynamic>.from(l)));
    }
  }

  Future<void> _restoreRecurring(Map<String, dynamic> data,
      Future<dynamic> Function(dynamic) decrypt) async {
    if (data['recurring'] == null) return;
    final recurring = await decrypt(data['recurring']);
    for (var rt in (recurring as List)) {
      await _storageService.saveRecurringTransaction(
          RecurringTransaction.fromMap(Map<String, dynamic>.from(rt)));
    }
  }

  Future<void> _restoreSettings(Map<String, dynamic> data,
      Future<dynamic> Function(dynamic) decrypt) async {
    if (data['settings'] == null) return;
    final Map<String, dynamic> finalSettings = {};

    if (data['settings'] is Map) {
      finalSettings.addAll(Map<String, dynamic>.from(data['settings']));
    } else {
      final decoded = await decrypt(data['settings']); // coverage:ignore-line
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

  Future<void> _restoreInsurancePolicies(Map<String, dynamic> data,
      Future<dynamic> Function(dynamic) decrypt) async {
    if (data['insurance_policies'] == null) return;
    final List<InsurancePolicy> policies = [];
    final insPolicies = await decrypt(data['insurance_policies']);
    for (var p in (insPolicies as List)) {
      policies.add(InsurancePolicy.fromMap(Map<String, dynamic>.from(p)));
    }
    await _storageService.saveInsurancePoliciesGlobal(policies);
  }

  Future<void> _restoreTaxRules(Map<String, dynamic> data,
      Future<dynamic> Function(dynamic) decrypt) async {
    final v2Data = data['tax_rules_v2'];
    if (v2Data == null || v2Data is! Map) return;

    final Map<String, TaxRules> allRules = {};
    for (var entry in v2Data.entries) {
      final r = await decrypt(entry.value);
      allRules[entry.key] = TaxRules.fromMap(Map<String, dynamic>.from(r));
    }
    await _taxConfigService.restoreAllRulesGlobal(allRules);
  }

  Future<Set<int>> _restoreTaxData(Map<String, dynamic> data,
      Future<dynamic> Function(dynamic) decrypt) async {
    final v2Data = data['tax_data_v2'];
    if (v2Data == null || v2Data is! Map) return {};

    final Set<int> restoredYears = {};
    for (var entry in v2Data.entries) {
      final td = await decrypt(entry.value);
      final taxData = TaxYearData.fromMap(Map<String, dynamic>.from(td));
      await _storageService.saveTaxYearDataGlobal(taxData);
      restoredYears.add(taxData.year);
    }
    return restoredYears;
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

  Future<void> _restoreLendingRecords(Map<String, dynamic> data,
      Future<dynamic> Function(dynamic) decrypt) async {
    final lendingData = data['lending_records'];
    if (lendingData == null || lendingData is! Map) {
      return;
    }

    // Partitioned Format
    for (var bucketValue in lendingData.values) {
      final records = await decrypt(bucketValue);
      if (records == null || records is! List) continue;
      for (var r in records) {
        await _storageService.saveLendingRecord(
            LendingRecord.fromMap(Map<String, dynamic>.from(r)));
      }
    }
  }

  Future<void> _restoreInvestments(Map<String, dynamic> data,
      Future<dynamic> Function(dynamic) decrypt) async {
    final v2Data = data['investments_v2'];
    if (v2Data == null || v2Data is! Map) return;

    for (var bucketValue in v2Data.values) {
      final investments = await decrypt(bucketValue);
      for (var i in (investments as List)) {
        await _storageService
            .saveInvestment(Investment.fromMap(Map<String, dynamic>.from(i)));
      }
    }
  }

  Future<void> deleteCloudData() async {
    _verifySubscription();
    final auth = _auth;
    if (auth == null) {
      throw Exception(errFirebaseNotInit); // coverage:ignore-line
    }
    final user = auth.currentUser;
    if (user == null) {
      throw Exception(errUserNotLoggedIn);
    }

    // Proactively check and sync sessionId before deletion verification
    final localId = await _ensureLocalSessionId();
    final cloudId = await getCloudSessionId(user.uid);
    if (cloudId != localId) {
      await updateActiveSessionId(localId); // coverage:ignore-line
    }

    await _verifySession(user);
    // Claim session in cloud before deletion
    final sessionId = _storageService.getSessionId();
    if (sessionId != null) {
      await updateActiveSessionId(sessionId);
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
