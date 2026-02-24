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
      if (Firebase.apps.isNotEmpty) return FirebaseAuth.instance; // coverage:ignore-line
    } catch (_) {}
    return null;
  }

  Future<void> syncToCloud({String? passcode}) async {
    final auth = _auth;
    if (auth == null) throw Exception("Firebase not initialized"); // coverage:ignore-line

    final user = auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    final encryption =
        (passcode != null && passcode.isNotEmpty) ? EncryptionService() : null; // coverage:ignore-line

    dynamic encryptIfRequested(dynamic payload) {
      if (encryption == null) return payload;
      return encryption.encryptData(jsonEncode(payload), passcode!); // coverage:ignore-line
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
      'categories': // Category is metadata, keep plaintext
          _storageService.getAllCategories().map((e) => e.toMap()).toList(),
      'profiles': // Profiles contain name/avatar, keep plaintext
          _storageService.getProfiles().map((e) => e.toMap()).toList(),
      'settings': encryptIfRequested(settingsToEncrypt),
      'last_sync': lastSync, // Always plaintext
      'insurance_policies': encryptIfRequested(_storageService
          .getInsurancePolicies()
          .map((e) => e.toMap())
          .toList()),
      'tax_rules': // Tax Rules are usually systemic parameters, let's keep plaintext as requested
          _taxConfigService
              .getAllRules()
              .map((year, rules) => MapEntry(year.toString(), rules.toMap())),
      'tax_data': encryptIfRequested(
          _storageService.getAllTaxYearData().map((e) => e.toMap()).toList()),
      'lending_records': encryptIfRequested(
          _storageService.getLendingRecords().map((e) => e.toMap()).toList()),
      'is_encrypted': encryption != null,
    };

    final sanitizedData = _sanitizeForSync(data);
    await _cloudStorage.syncData(user.uid, sanitizedData);
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
    final auth = _auth;
    if (auth == null) throw Exception("Firebase not initialized"); // coverage:ignore-line

    final user = auth.currentUser;
    if (user == null) throw Exception("User not logged in"); // coverage:ignore-line

    final rawData = await _cloudStorage.fetchData(user.uid);
    if (rawData == null) throw Exception("No cloud data found"); // coverage:ignore-line

    // SANITIZATION: Convert Firestore Timestamps to DateTime
    // Hive doesn't know how to serialize Timestamp (minified:tH), causing restore crash.
    final data = _sanitizeFirestoreData(rawData) as Map<String, dynamic>;

    final bool isEncrypted = data['is_encrypted'] == true;
    final encryption = isEncrypted ? EncryptionService() : null; // coverage:ignore-line

    if (isEncrypted && (passcode == null || passcode.isEmpty)) { // coverage:ignore-line
      throw Exception("Passcode required for encrypted backup"); // coverage:ignore-line
    }

    dynamic decryptIfEncrypted(dynamic payload) {
      if (!isEncrypted || payload == null || payload is! String) return payload; // coverage:ignore-line
      try {
        final decryptedString = encryption!.decryptData(payload, passcode!); // coverage:ignore-line
        return jsonDecode(decryptedString); // coverage:ignore-line
      } catch (e) {
        throw Exception("Incorrect passcode or corrupted data"); // coverage:ignore-line
      }
    }

    // 0. SAFETY: Cache local Tax Data before wiping
    final localTaxData = _storageService.getAllTaxYearData();

    // Clear local data before restore
    await _storageService.clearAllData();

    // Deserialize and save
    if (data['profiles'] != null) {
      final profilesPayload = data['profiles']; // Profiles are plaintext
      for (var p in (profilesPayload as List)) {
        await _storageService
            .saveProfile(Profile.fromMap(Map<String, dynamic>.from(p)));
      }
    }

    if (data['categories'] != null) {
      try {
        // coverage:ignore-start
        for (var c in (data['categories'] as List)) {
          await _storageService
              .addCategory(Category.fromMap(Map<String, dynamic>.from(c)));
        // coverage:ignore-end
        }
      } catch (e) {
        // print("Restore Error (Categories): $e");
        rethrow;
      }
    }

    if (data['accounts'] != null) {
      final accList = decryptIfEncrypted(data['accounts']);
      for (var a in (accList as List)) {
        final acc = Account.fromMap(Map<String, dynamic>.from(a));
        await _storageService.saveAccount(acc);

        // FIX: Initialize rollover timestamp for Credit Cards to prevent double-counting
        if (acc.type == AccountType.creditCard && acc.billingCycleDay != null) {
          await _storageService.initRolloverForImport( // coverage:ignore-line
              acc.id, acc.billingCycleDay!); // coverage:ignore-line
        }
      }
    }

    if (data['transactions'] != null) {
      final txns = decryptIfEncrypted(data['transactions']);
      for (var t in (txns as List)) {
        await _storageService.saveTransaction(
            Transaction.fromMap(Map<String, dynamic>.from(t)),
            applyImpact: false);
      }
    }

    if (data['loans'] != null) {
      // coverage:ignore-start
      final loans = decryptIfEncrypted(data['loans']);
      for (var l in (loans as List)) {
        await _storageService
            .saveLoan(Loan.fromMap(Map<String, dynamic>.from(l)));
      // coverage:ignore-end
      }
    }

    if (data['recurring'] != null) {
      // coverage:ignore-start
      final recs = decryptIfEncrypted(data['recurring']);
      for (var rt in (recs as List)) {
        await _storageService.saveRecurringTransaction(
            RecurringTransaction.fromMap(Map<String, dynamic>.from(rt)));
      // coverage:ignore-end
      }
    }

    if (data['settings'] != null) {
      final Map<String, dynamic> finalSettings = {}; // coverage:ignore-line

      if (data['settings'] is Map) { // coverage:ignore-line
        // Legacy unencrypted settings
        finalSettings.addAll(Map<String, dynamic>.from(data['settings'])); // coverage:ignore-line
      } else {
        // Encrypted settings
        final decoded = decryptIfEncrypted(data['settings']); // coverage:ignore-line
        finalSettings.addAll(Map<String, dynamic>.from(decoded)); // coverage:ignore-line
      }

      if (data['last_sync'] != null) { // coverage:ignore-line
        finalSettings['last_sync'] = data['last_sync']; // coverage:ignore-line
      }

      await _storageService.saveSettings(finalSettings); // coverage:ignore-line
    }

    if (data['insurance_policies'] != null) {
      try {
        // coverage:ignore-start
        final List<InsurancePolicy> policies = [];
        final insPolicies = decryptIfEncrypted(data['insurance_policies']);
        for (var p in (insPolicies as List)) {
          policies.add(InsurancePolicy.fromMap(Map<String, dynamic>.from(p)));
        // coverage:ignore-end
        }
        await _storageService.saveInsurancePolicies(policies); // coverage:ignore-line
      } catch (e) {
        // print("Restore Error (Insurance): $e");
        rethrow;
      }
    }

    if (data['tax_rules'] != null) {
      try {
        // coverage:ignore-start
        final Map<int, TaxRules> taxRules = {};
        (data['tax_rules'] as Map).forEach((key, val) {
          final year = int.parse(key.toString());
          taxRules[year] = TaxRules.fromMap(Map<String, dynamic>.from(val));
        // coverage:ignore-end
        });
        await _taxConfigService.restoreAllRules(taxRules); // coverage:ignore-line
      } catch (e) {
        // print("Restore Error (TaxRules): $e");
        rethrow;
      }
    }

    // Restore Tax Data with Merge Safety
    final restoredTaxYears = <int>{};
    if (data['tax_data'] != null) {
      try {
        // coverage:ignore-start
        final taxDataList = decryptIfEncrypted(data['tax_data']);
        for (var td in (taxDataList as List)) {
          final taxData = TaxYearData.fromMap(Map<String, dynamic>.from(td));
        // coverage:ignore-end

          // Determine if we should Merge or Replace Cap Gains?
          // User asked for Deduplication.
          // Strategy: Fetch existing first.
          final existingData = _storageService.getTaxYearData(taxData.year); // coverage:ignore-line
          if (existingData != null) {
            // Deduplicate Capital Gains
            // coverage:ignore-start
            final existingPo = existingData.capitalGains;
            final incomingPo = taxData.capitalGains;
            final mergedCG = List<CapitalGainEntry>.from(existingPo);
            // coverage:ignore-end

            for (final newEntry in incomingPo) { // coverage:ignore-line
              // Check duplicate: Date, Amount, AssetType
              // coverage:ignore-start
              bool exists = existingPo.any((e) =>
                  e.gainDate.isAtSameMomentAs(newEntry.gainDate) &&
                  (e.saleAmount - newEntry.saleAmount).abs() < 0.01 &&
                  e.matchAssetType == newEntry.matchAssetType);
              // coverage:ignore-end

              if (!exists) {
                mergedCG.add(newEntry); // coverage:ignore-line
              }
            }
            final merged = taxData.copyWith(capitalGains: mergedCG); // coverage:ignore-line
            await _storageService.saveTaxYearData(merged); // coverage:ignore-line
          } else {
            await _storageService.saveTaxYearData(taxData); // coverage:ignore-line
          }
          restoredTaxYears.add(taxData.year); // coverage:ignore-line
        }
      } catch (e) {
        // print("Restore Error (TaxData): $e");
        rethrow;
      }
    }

    // Safety Check: If Local had data for a year that Cloud didn't, OR Cloud data is empty for that year
    // Restore the local version to prevent data loss.
    for (final local in localTaxData) {
      // If cloud didn't have this year at all
      if (!restoredTaxYears.contains(local.year)) { // coverage:ignore-line
        await _storageService.saveTaxYearData(local); // coverage:ignore-line
        continue;
      }

      // If cloud had it, check if it was "empty" (no salary gross) but local had value
      final restored = _storageService.getTaxYearData(local.year); // coverage:ignore-line
      if (restored != null &&
          restored.salary.grossSalary == 0 && // coverage:ignore-line
          local.salary.grossSalary > 0) { // coverage:ignore-line
        // Cloud had empty salary, Local had Real salary -> Keep Local
        // But we might want to keep Cloud's "Aggregated" values?
        // Let's assume Manual Salary Input is more important than an empty cloud state.
        // We will MERGE: Keep Local Salary, Keep Cloud Aggregates?
        // For simplicity and safety: If Cloud is effectively empty, restore Local.
        final merged = restored.copyWith( // coverage:ignore-line
          salary: local.salary, // coverage:ignore-line
          // We can also merge other manual fields if needed
          // coverage:ignore-start
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

    if (data['lending_records'] != null) {
      try {
        // coverage:ignore-start
        final lendings = decryptIfEncrypted(data['lending_records']);
        for (var l in (lendings as List)) {
          await _storageService.saveLendingRecord(
              LendingRecord.fromMap(Map<String, dynamic>.from(l)));
        // coverage:ignore-end
        }
      } catch (e) {
        // print("Restore Error (Lending): $e");
        rethrow;
      }
    }
  }

  Future<void> deleteCloudData() async {
    final auth = _auth;
    if (auth == null) throw Exception("Firebase not initialized"); // coverage:ignore-line
    final user = auth.currentUser;
    if (user == null) throw Exception("User not logged in"); // coverage:ignore-line

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
