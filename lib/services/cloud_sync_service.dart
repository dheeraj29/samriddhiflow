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
      'accounts':
          _storageService.getAllAccounts().map((e) => e.toMap()).toList(),
      'transactions':
          _storageService.getAllTransactions().map((e) => e.toMap()).toList(),
      'loans': _storageService.getAllLoans().map((e) => e.toMap()).toList(),
      'recurring':
          _storageService.getAllRecurring().map((e) => e.toMap()).toList(),
      'categories':
          _storageService.getAllCategories().map((e) => e.toMap()).toList(),
      'profiles': _storageService.getProfiles().map((e) => e.toMap()).toList(),
      'settings': _storageService.getAllSettings(),
      'insurance_policies':
          _storageService.getInsurancePolicies().map((e) => e.toMap()).toList(),
      'tax_rules': _taxConfigService
          .getAllRules()
          .map((year, rules) => MapEntry(year.toString(), rules.toMap())),
      'tax_data':
          _storageService.getAllTaxYearData().map((e) => e.toMap()).toList(),
      'lending_records':
          _storageService.getLendingRecords().map((e) => e.toMap()).toList(),
    };

    await _cloudStorage.syncData(user.uid, data);
  }

  Future<void> restoreFromCloud() async {
    final auth = _auth;
    if (auth == null) throw Exception("Firebase not initialized");

    final user = auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    final rawData = await _cloudStorage.fetchData(user.uid);
    if (rawData == null) throw Exception("No cloud data found");

    // SANITIZATION: Convert Firestore Timestamps to DateTime
    // Hive doesn't know how to serialize Timestamp (minified:tH), causing restore crash.
    final data = _sanitizeFirestoreData(rawData) as Map<String, dynamic>;

    // Clear local data before restore
    await _storageService.clearAllData();

    // Deserialize and save
    if (data['profiles'] != null) {
      for (var p in (data['profiles'] as List)) {
        await _storageService
            .saveProfile(Profile.fromMap(Map<String, dynamic>.from(p)));
      }
    }

    if (data['categories'] != null) {
      try {
        for (var c in (data['categories'] as List)) {
          await _storageService
              .addCategory(Category.fromMap(Map<String, dynamic>.from(c)));
        }
      } catch (e) {
        // print("Restore Error (Categories): $e");
        rethrow;
      }
    }

    if (data['accounts'] != null) {
      for (var a in (data['accounts'] as List)) {
        final acc = Account.fromMap(Map<String, dynamic>.from(a));
        await _storageService.saveAccount(acc);

        // FIX: Initialize rollover timestamp for Credit Cards to prevent double-counting
        if (acc.type == AccountType.creditCard && acc.billingCycleDay != null) {
          await _storageService.initRolloverForImport(
              acc.id, acc.billingCycleDay!);
        }
      }
    }

    if (data['transactions'] != null) {
      for (var t in (data['transactions'] as List)) {
        await _storageService.saveTransaction(
            Transaction.fromMap(Map<String, dynamic>.from(t)),
            applyImpact: false);
      }
    }

    if (data['loans'] != null) {
      for (var l in (data['loans'] as List)) {
        await _storageService
            .saveLoan(Loan.fromMap(Map<String, dynamic>.from(l)));
      }
    }

    if (data['recurring'] != null) {
      for (var rt in (data['recurring'] as List)) {
        await _storageService.saveRecurringTransaction(
            RecurringTransaction.fromMap(Map<String, dynamic>.from(rt)));
      }
    }

    if (data['settings'] != null) {
      await _storageService
          .saveSettings(Map<String, dynamic>.from(data['settings']));
    }

    if (data['insurance_policies'] != null) {
      try {
        final List<InsurancePolicy> policies = [];
        for (var p in (data['insurance_policies'] as List)) {
          policies.add(InsurancePolicy.fromMap(Map<String, dynamic>.from(p)));
        }
        await _storageService.saveInsurancePolicies(policies);
      } catch (e) {
        // print("Restore Error (Insurance): $e");
        rethrow;
      }
    }

    if (data['tax_rules'] != null) {
      try {
        final Map<int, TaxRules> taxRules = {};
        (data['tax_rules'] as Map).forEach((key, val) {
          final year = int.parse(key.toString());
          taxRules[year] = TaxRules.fromMap(Map<String, dynamic>.from(val));
        });
        await _taxConfigService.restoreAllRules(taxRules);
      } catch (e) {
        // print("Restore Error (TaxRules): $e");
        rethrow;
      }
    }

    if (data['tax_data'] != null) {
      try {
        for (var td in (data['tax_data'] as List)) {
          final taxData = TaxYearData.fromMap(Map<String, dynamic>.from(td));
          await _storageService.saveTaxYearData(taxData);
        }
      } catch (e) {
        // print("Restore Error (TaxData): $e");
        rethrow;
      }
    }

    if (data['lending_records'] != null) {
      try {
        for (var l in (data['lending_records'] as List)) {
          await _storageService.saveLendingRecord(
              LendingRecord.fromMap(Map<String, dynamic>.from(l)));
        }
      } catch (e) {
        // print("Restore Error (Lending): $e");
        rethrow;
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
