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
import 'package:samriddhi_flow/services/storage_service.dart';
import 'package:samriddhi_flow/services/taxes/tax_config_service.dart';
import 'package:samriddhi_flow/core/app_constants.dart';

class JsonDataService {
  final StorageService _storageService;
  final TaxConfigService _taxConfigService;

  JsonDataService(this._storageService, this._taxConfigService);

  /// Creates a ZIP package containing separate JSON files for each data type.
  Future<List<int>> createBackupPackage() async {
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
    final settings = _storageService.getAllSettings();
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
    // We could check versions here if needed

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

    // A. Profiles (Restore first as others might depend on it, though IDs are usually enough)
    final profilesList = getJson('profiles.json');
    if (profilesList != null) {
      int count = 0;
      for (var p in (profilesList as List)) {
        await _storageService.saveProfile(Profile.fromMap(p));
        count++;
      }
      stats['profiles'] = count;
    }

    // B. Categories
    final categoriesList = getJson('categories.json');
    if (categoriesList != null) {
      int count = 0;
      for (var c in (categoriesList as List)) {
        await _storageService.addCategory(Category.fromMap(c));
        count++;
      }
      stats['categories'] = count;
    }

    // C. Accounts
    final accountsList = getJson('accounts.json');
    if (accountsList != null) {
      int count = 0;
      for (var a in (accountsList as List)) {
        final acc = Account.fromMap(a);
        await _storageService.saveAccount(acc);
        // Retain original rollover logic from import if needed,
        // but if settings.json is restored later, it might overwrite 'last_rollover'.
        // However, 'settings' usually contains global app settings.
        // The 'last_rollover_X' keys are kept in settings box.
        count++;
      }
      stats['accounts'] = count;
    }

    // D. Transactions
    final transactionsList = getJson('transactions.json');
    if (transactionsList != null) {
      int count = 0;
      for (var t in (transactionsList as List)) {
        // saveTransaction applies impact, but we are doing a full restore.
        // If accounts were already restored with balances, applying impact again effectively doubles it
        // OR calculates it from 0 if accounts were saved with 0.
        // The 'Account.fromMap' restores the balance snapshot.
        // 'saveTransaction(applyImpact: false)' is safest for full restore
        // IF the account balance in JSON is the correct final state.
        // Let's assume the backup is consistent.
        await _storageService.saveTransaction(Transaction.fromMap(t),
            applyImpact: false);
        count++;
      }
      stats['transactions'] = count;
    }

    // E. Loans
    final loansList = getJson('loans.json');
    if (loansList != null) {
      int count = 0;
      for (var l in (loansList as List)) {
        await _storageService.saveLoan(Loan.fromMap(l));
        count++;
      }
      stats['loans'] = count;
    }

    // F. Recurring
    final recurringList = getJson('recurring.json');
    if (recurringList != null) {
      int count = 0;
      for (var r in (recurringList as List)) {
        await _storageService
            .saveRecurringTransaction(RecurringTransaction.fromMap(r));
        count++;
      }
      stats['recurring'] = count;
    }

    // G. Settings (Includes last_rollover dates, theme, etc.)
    final settingsMap = getJson('settings.json');
    if (settingsMap != null) {
      await _storageService.saveSettings(settingsMap);
      stats['settings'] = (settingsMap as Map).length;
    }

    // H. Insurance Policies
    final policiesList = getJson('insurance_policies.json');
    if (policiesList != null) {
      final List<InsurancePolicy> policies = [];
      for (var p in (policiesList as List)) {
        policies.add(InsurancePolicy.fromMap(p));
      }
      await _storageService.saveInsurancePolicies(policies);
      stats['insurance_policies'] = policies.length;
    }

    // I. Tax Rules
    final rulesMap = getJson('tax_rules.json');
    if (rulesMap != null) {
      final Map<int, TaxRules> rules = {};
      (rulesMap as Map).forEach((k, v) {
        rules[int.parse(k)] = TaxRules.fromMap(v);
      });
      await _taxConfigService.restoreAllRules(rules);
      stats['tax_rules'] = rules.length;
    }

    // J. Tax Year Data
    final taxDataList = getJson('tax_data.json');
    if (taxDataList != null) {
      int count = 0;
      for (var td in (taxDataList as List)) {
        await _storageService.saveTaxYearData(TaxYearData.fromMap(td));
        count++;
      }
      stats['tax_data'] = count;
    }

    // K. Lending Records
    final lendingList = getJson('lending_records.json');
    if (lendingList != null) {
      int count = 0;
      for (var l in (lendingList as List)) {
        await _storageService.saveLendingRecord(LendingRecord.fromMap(l));
        count++;
      }
      stats['lending_records'] = count;
    }

    return stats;
  }
}
