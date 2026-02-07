import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samriddhi_flow/models/taxes/tax_rules.dart';
import 'package:hive_ce/hive.dart';

class TaxConfigService {
  late Box<TaxRules> _box;
  static const String _boxName =
      'tax_rules_v2'; // Changed box name for migration safety

  Future<void> init() async {
    // Adapter registration is handled by centralized registrar in providers.dart
    _box = await Hive.openBox<TaxRules>(_boxName);
  }

  /// Get rules for a specific Assessment Year.
  /// If not found, attempts to return rules from (year-1).
  /// If that fails, returns default rules.
  TaxRules getRulesForYear(int year) {
    if (_box.containsKey(year)) {
      return _box.get(year)!;
    }

    // Try Previous Year
    if (_box.containsKey(year - 1)) {
      return _box.get(year - 1)!;
    }

    return TaxRules();
  }

  Future<void> saveRulesForYear(int year, TaxRules rules) async {
    await _box.put(year, rules);
  }

  /// Explicitly copy rules from one year to another
  Future<void> copyRules(int fromYear, int toYear) async {
    final rules = getRulesForYear(fromYear);
    await saveRulesForYear(toYear, rules);
  }

  /// Get all rules across all years for backup
  Map<int, TaxRules> getAllRules() {
    final Map<int, TaxRules> all = {};
    for (var key in _box.keys) {
      if (key is int) {
        all[key] = _box.get(key)!;
      }
    }
    return all;
  }

  /// RESTORE: Bulk save rules
  Future<void> restoreAllRules(Map<int, TaxRules> data) async {
    await _box.clear();
    for (var entry in data.entries) {
      await _box.put(entry.key, entry.value);
    }
  }

  /// For backward compatibility or convenience property (defaults to current year)
  TaxRules get rules => getRulesForYear(DateTime.now().year);
}

final taxConfigServiceProvider = Provider<TaxConfigService>((ref) {
  return TaxConfigService();
});
