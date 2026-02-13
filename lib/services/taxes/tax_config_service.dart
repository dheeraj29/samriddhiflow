import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samriddhi_flow/models/taxes/tax_rules.dart';
import 'package:hive_ce/hive.dart';

class TaxConfigService {
  late Box<TaxRules> _box;
  static const String _boxName =
      'tax_rules_v2'; // Changed box name for migration safety

  Future<void> init() async {
    if (!Hive.isBoxOpen(_boxName)) {
      // Actually, standard practice is register BEFORE open.
      _box = await Hive.openBox<TaxRules>(_boxName);
    } else {
      _box = Hive.box<TaxRules>(_boxName);
    }
  }

  /// Get rules for a specific Assessment Year.
  /// If not found, attempts to return rules from (year-1).
  /// If that fails, returns default rules.
  TaxRules getRulesForYear(int year) {
    if (!_box.isOpen) return TaxRules();

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
    if (!_box.isOpen) return {};
    final Map<int, TaxRules> all = {};
    for (var key in _box.keys) {
      if (key is int) {
        all[key] = _box.get(key)!;
      }
    }
    return all;
  }

  /// RESTORE: Bulk save rules with Sanitization
  Future<void> restoreAllRules(Map<int, TaxRules> data) async {
    if (!_box.isOpen) {
      _box = await Hive.openBox<TaxRules>(_boxName);
    }

    await _box.clear();

    for (var entry in data.entries) {
      try {
        // SANITIZATION:
        // Re-construct the object to ensure it is PURE and matches our current schema.
        // This strips out any hidden "minified" types or runtime wrappers from the source.
        final cleanRules = TaxRules.fromMap(entry.value.toMap());

        await _box.put(entry.key, cleanRules);
      } catch (e) {
        // Detailed logging to identify the "unknown type" error
        // likely caused by minified class names not being registered or mismatch
        // print("CRITICAL RESTORE ERROR: Failed to save TaxRules for Year ${entry.key}: $e");
      }
    }
  }

  /// Get the Current Financial Year based on Rules
  /// e.g. If specific rule says FY starts in Jan, and today is Feb 2026 -> FY 2026.
  /// If FY starts in April, and today is Feb 2026 -> FY 2025.
  int getCurrentFinancialYear() {
    final now = DateTime.now();

    // Strategy: To avoid "future year creation" loop:
    // 1. Check rules for (Year - 1). If valid, use its Start Month to decide if we crossed into Year.
    // 2. If (Year - 1) rules don't exist, fallback to Year.

    // Example: Today is Feb 2026.
    // Check 2025 Rules. Start Month = 4 (April).
    // Feb < 4, so we are still in 2025. Return 2025.

    // If we checked 2026 Rules (which might not exist yet -> gets created with defaults),
    // and default is Jan (1), then Feb >= 1 -> Return 2026. This is the bug.

    TaxRules? prevYearRules;
    if (_box.containsKey(now.year - 1)) {
      prevYearRules = _box.get(now.year - 1);
    }

    // Use previous year's config if available to determine boundary
    final referenceRules = prevYearRules ?? getRulesForYear(now.year);

    // If today's month is BEFORE the start month, we are in the previous FY.
    if (now.month < referenceRules.financialYearStartMonth) {
      return now.year - 1;
    }
    return now.year;
  }

  /// For backward compatibility or convenience property (defaults to CURRENT FY)
  TaxRules get rules => getRulesForYear(getCurrentFinancialYear());
}

final taxConfigServiceProvider = Provider<TaxConfigService>((ref) {
  return TaxConfigService();
});
