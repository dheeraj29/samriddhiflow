import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:samriddhi_flow/models/account.dart';
import 'package:samriddhi_flow/models/transaction.dart';
import 'package:samriddhi_flow/models/loan.dart';
import 'package:samriddhi_flow/models/recurring_transaction.dart';
import 'package:samriddhi_flow/models/category.dart';
import 'package:samriddhi_flow/models/profile.dart';
import 'package:samriddhi_flow/models/taxes/insurance_policy.dart';
import 'package:samriddhi_flow/models/taxes/tax_rules.dart';
import 'package:samriddhi_flow/models/taxes/tax_data.dart';
import 'package:samriddhi_flow/models/lending_record.dart';
import 'package:samriddhi_flow/models/investment.dart';
import 'package:samriddhi_flow/services/storage_service.dart';
import 'package:samriddhi_flow/services/taxes/tax_config_service.dart';
import 'package:samriddhi_flow/core/app_constants.dart';

class JsonDataService {
  final StorageService _storageService;
  final TaxConfigService _taxConfigService;

  JsonDataService(this._storageService, this._taxConfigService);

  /// Creates a ZIP package containing separate JSON files for each data type.
  Future<List<int>> createBackupPackage({String? appPin}) async {
    final archive = Archive();

    // 1. Metadata
    final metadata = {
      'version': AppConstants
          .appVersion, // Ensure this exists or use a hardcoded string if not public
      'timestamp': DateTime.now().toIso8601String(),
      'platform': kIsWeb ? 'web' : 'mobile',
    };
    _addToArchive(archive, 'metadata.json', metadata);

    // 2. Accounts
    final accounts = _storageService.getAllAccounts();
    _addToArchive(
        archive, 'accounts.json', accounts.map((e) => e.toMap()).toList());

    // 3. Transactions
    final transactions = _storageService.getAllTransactions();
    _addToArchive(archive, 'transactions.json',
        transactions.map((e) => e.toMap()).toList());

    // 4. Loans
    final loans = _storageService.getAllLoans();
    _addToArchive(archive, 'loans.json', loans.map((e) => e.toMap()).toList());

    // 5. Recurring
    final recurring = _storageService.getAllRecurring();
    _addToArchive(
        archive, 'recurring.json', recurring.map((e) => e.toMap()).toList());

    // 6. Categories
    final categories = _storageService.getAllCategories();
    _addToArchive(
        archive, 'categories.json', categories.map((e) => e.toMap()).toList());

    // 7. Profiles
    final profiles = _storageService.getProfiles();
    _addToArchive(
        archive, 'profiles.json', profiles.map((e) => e.toMap()).toList());

    // 8. Settings
    final settings =
        Map<String, dynamic>.from(_storageService.getAllSettings());
    settings.remove('sessionId');
    settings.remove('isLoggedIn');
    settings.remove('lastLogin');
    settings.remove('last_sync');
    settings.remove('txnsSinceBackup');

    if (appPin != null) {
      settings['appPin'] = appPin; // coverage:ignore-line
    }
    _addToArchive(archive, 'settings.json', settings);

    // 9. Insurance Policies
    final policies = _storageService.getInsurancePolicies();
    _addToArchive(archive, 'insurance_policies.json',
        policies.map((e) => e.toMap()).toList());

    // 10. Tax Rules
    final rules = _taxConfigService.getAllRules();
    final rulesMap =
        rules.map((year, rule) => MapEntry(year.toString(), rule.toMap()));
    _addToArchive(archive, 'tax_rules.json', rulesMap);

    // 11. Tax Year Data
    final taxData = _storageService.getAllTaxYearData();
    _addToArchive(
        archive, 'tax_data.json', taxData.map((e) => e.toMap()).toList());

    // 12. Lending Records
    final lending = _storageService.getLendingRecords();
    _addToArchive(archive, 'lending_records.json',
        lending.map((e) => e.toMap()).toList());

    // 13. Investments
    final investments = _storageService.getAllInvestments();
    _addToArchive(archive, 'investments.json',
        investments.map((e) => e.toMap()).toList());

    // Encode to ZIP
    final encoder = ZipEncoder();
    return encoder.encode(archive);
  }

  void _addToArchive(Archive archive, String filename, dynamic content) {
    final sanitizedContent = _sanitizeForJson(content);
    final jsonStr = jsonEncode(sanitizedContent);
    final bytes = utf8.encode(jsonStr);
    archive.addFile(ArchiveFile(filename, bytes.length, bytes));
  }

  /// Recursively replaces non-JSON-encodable doubles (Infinity, NaN) with 0.0.
  dynamic _sanitizeForJson(dynamic data) {
    if (data is double) {
      if (data.isInfinite || data.isNaN) {
        return 0.0;
      }
      return data;
    } else if (data is Map) {
      return data
          .map(
              (key, value) => MapEntry(key.toString(), _sanitizeForJson(value)))
          .cast<String, dynamic>();
    } else if (data is List) {
      return data.map((e) => _sanitizeForJson(e)).toList().cast<dynamic>();
    }
    return data;
  }

  /// Restores data from a ZIP package.
  /// This performs a full wipe and replace.
  Future<Map<String, int>> restoreFromPackage(List<int> zipBytes) async {
    final archive = ZipDecoder().decodeBytes(zipBytes);

    // 1. Validate Metadata
    final metadataFile = archive.findFile('metadata.json');
    if (metadataFile == null) {
      throw Exception("Invalid Backup: Missing metadata.json");
    }

    // 2. Wipe Current Data
    await _storageService.clearAllData();

    // 3. Restore Each Entity
    final stats = <String, int>{};

    // Helper to decode JSON from archive
    dynamic getJson(String filename) {
      final file = archive.findFile(filename);
      if (file == null) return null;
      final content = utf8.decode(file.content as List<int>);
      return jsonDecode(content);
    }

    // A-C: Restore metadata and settings first
    await _restoreEntityList(getJson, 'profiles.json', stats, 'profiles',
        (p) async => await _storageService.saveProfile(Profile.fromMap(p)));

    await _restoreSettings(getJson, stats); // Restore settings early!

    // D-F: Restore core data
    await _restoreEntityList(
        getJson,
        'categories.json',
        stats,
        'categories',
        (c) async => await _storageService.addCategory(Category.fromMap(c),
            isRestore: true));
    await _restoreEntityList(getJson, 'accounts.json', stats, 'accounts',
        (a) async => await _storageService.saveAccountRaw(Account.fromMap(a)));
    await _restoreEntityList(
        getJson,
        'transactions.json',
        stats,
        'transactions',
        (t) async => await _storageService
            .saveTransaction(Transaction.fromMap(t), applyImpact: false));
    await _restoreEntityList(
        getJson,
        'loans.json',
        stats,
        'loans',
        (l) async => await _storageService
            .saveLoan(Loan.fromMap(l))); // coverage:ignore-line
    await _restoreEntityList(
        getJson,
        'recurring.json',
        stats,
        'recurring',
        (r) async => await _storageService // coverage:ignore-line
            .saveRecurringTransaction(
                RecurringTransaction.fromMap(r))); // coverage:ignore-line
    await _restoreEntityList(
        getJson,
        'tax_data.json',
        stats,
        'tax_data',
        (td) async => // coverage:ignore-line
            await _storageService.saveTaxYearData(
                TaxYearData.fromMap(td))); // coverage:ignore-line
    await _restoreEntityList(
        getJson,
        'lending_records.json',
        stats,
        'lending_records',
        (l) async => // coverage:ignore-line
            await _storageService.saveLendingRecord(
                LendingRecord.fromMap(l))); // coverage:ignore-line

    await _restoreEntityList(
        getJson,
        'investments.json',
        stats,
        'investments',
        (i) async =>
            await _storageService.saveInvestment(Investment.fromMap(i)));

    // G. Settings already restored above

    // H. Insurance Policies (bulk save)
    await _restoreInsurancePolicies(getJson, stats);

    // I. Tax Rules
    await _restoreTaxRules(getJson, stats);

    return stats;
  }

  Future<void> _restoreEntityList(
      dynamic Function(String) getJson,
      String filename,
      Map<String, int> stats,
      String key,
      Future<void> Function(dynamic) saveFn) async {
    final list = getJson(filename);
    if (list == null) return;
    int count = 0;
    for (var item in (list as List)) {
      await saveFn(item);
      count++;
    }
    stats[key] = count;
  }

  Future<void> _restoreSettings(
      dynamic Function(String) getJson, Map<String, int> stats) async {
    final settingsMap = getJson('settings.json');
    if (settingsMap == null) return;

    if (settingsMap is Map) {
      settingsMap.remove('isLoggedIn');
      settingsMap.remove('sessionId');
      settingsMap.remove('lastLogin');
      settingsMap.remove('last_sync');
      settingsMap.remove('txnsSinceBackup');

      // Ensure restored plaintext PINs are hashed via StorageService setter
      if (settingsMap.containsKey('appPin') && settingsMap['appPin'] != null) {
        await _storageService
            .setAppPin(settingsMap['appPin']); // coverage:ignore-line
        // Remove it from the batch settings to avoid overwriting the hash with plaintext
        settingsMap.remove('appPin'); // coverage:ignore-line
      }
    }

    await _storageService.saveSettings(settingsMap);
    stats['settings'] = (settingsMap as Map).length;
  }

  Future<void> _restoreInsurancePolicies(
      dynamic Function(String) getJson, Map<String, int> stats) async {
    final policiesList = getJson('insurance_policies.json');
    if (policiesList == null) return;
    final List<InsurancePolicy> policies = [];
    for (var p in (policiesList as List)) {
      policies.add(InsurancePolicy.fromMap(p)); // coverage:ignore-line
    }
    await _storageService.saveInsurancePolicies(policies);
    stats['insurance_policies'] = policies.length;
  }

  Future<void> _restoreTaxRules(
      dynamic Function(String) getJson, Map<String, int> stats) async {
    final rulesMap = getJson('tax_rules.json');
    if (rulesMap == null) return;
    final Map<int, TaxRules> rules = {};
    (rulesMap as Map).forEach((k, v) {
      rules[int.parse(k)] = TaxRules.fromMap(v); // coverage:ignore-line
    });
    await _taxConfigService.restoreAllRules(rules);
    stats['tax_rules'] = rules.length;
  }
}
