import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samriddhi_flow/models/taxes/tax_rules.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/utils/debug_logger.dart';

class TaxConfigService {
  final String profileId;
  TaxConfigService({this.profileId = 'default'});

  static const String _boxName =
      'tax_rules_v2'; // Changed box name for migration safety

  Box<TaxRules> get _box => Hive.box<TaxRules>(_boxName);

  Future<void> init() async {
    if (!Hive.isBoxOpen(_boxName)) {
      try {
        await Hive.openBox<TaxRules>(_boxName);
      } catch (e) {
        // Fallback or retry if type conflict occurs in development
        DebugLogger().log(
            "TaxConfigService: Error opening box $_boxName: $e"); // coverage:ignore-line
        await Hive.openBox(
            _boxName); // Open as dynamic if strict type fails // coverage:ignore-line
      }
    }
  }

  bool get isReady => Hive.isBoxOpen(_boxName);

  /// Returns rules for ALL profiles. Key is the raw Hive key (profile_year).
  // coverage:ignore-start
  Map<String, TaxRules> getAllRulesGlobal() {
    if (!_box.isOpen) return {};
    return Map<String, TaxRules>.from(_box.toMap());
    // coverage:ignore-end
  }

  /// Clears the box and restores all rules from a global map.
  /// Handles legacy keys (just year) by mapping them to profileId + year.
  // coverage:ignore-start
  Future<void> restoreAllRulesGlobal(Map<String, TaxRules> allRules) async {
    if (!isReady) await init();
    await _box.clear();
    final Map<String, TaxRules> normalized = {};
    allRules.forEach((key, rule) {
      if (!key.contains('_')) {
        // coverage:ignore-end
        // Legacy key (just a year). Map it to the profileId in the rule or 'default'.
        final year = int.tryParse(key); // coverage:ignore-line
        if (year != null) {
          final targetKey = '${rule.profileId}_$year'; // coverage:ignore-line
          normalized[targetKey] = rule; // coverage:ignore-line
        } else {
          normalized[key] = rule; // coverage:ignore-line
        }
      } else {
        normalized[key] = rule; // coverage:ignore-line
      }
    });
    await _box.putAll(normalized); // coverage:ignore-line
  }

  /// Returns rules for the current profile, indexed by year.
  /// If not found, attempts to return rules from (year-1).
  /// If that fails, returns default rules.
  TaxRules getRulesForYear(int year) {
    if (!isReady) return TaxRules(profileId: profileId);

    final key = '${profileId}_$year';
    if (_box.containsKey(key)) {
      return _box.get(key)!;
    }

    // Try Previous Year
    final prevKey = '${profileId}_${year - 1}';
    if (_box.containsKey(prevKey)) {
      return _box.get(prevKey)!;
    }

    return TaxRules(profileId: profileId);
  }

  Future<void> saveRulesForYear(int year, TaxRules rules) async {
    final rulesToSave = rules.profileId == profileId
        ? rules
        : rules.copyWith(profileId: profileId);
    await _box.put('${profileId}_$year', rulesToSave);
  }

  Future<void> deleteRulesForYear(int year) async {
    await _box.delete('${profileId}_$year');
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
      if (key is String && key.startsWith('${profileId}_')) {
        final year = int.tryParse(key.replaceFirst('${profileId}_', ''));
        if (year != null) {
          all[year] = _box.get(key)!;
        }
      }
    }
    return all;
  }

  /// RESTORE: Bulk save rules with Sanitization
  Future<void> restoreAllRules(Map<int, TaxRules> data) async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox<TaxRules>(_boxName); // coverage:ignore-line
    }

    await _box.clear();

    for (var entry in data.entries) {
      try {
        // SANITIZATION:
        // Re-construct the object to ensure it is PURE and matches our current schema.
        // This strips out any hidden "minified" types or runtime wrappers from the source.
        final cleanRules = TaxRules.fromMap(entry.value.toMap());

        final keyToSave = '${profileId}_${entry.key}';
        final rulesToSave = cleanRules.profileId == profileId
            ? cleanRules
            : cleanRules.copyWith(profileId: profileId);

        await _box.put(keyToSave, rulesToSave);
      } catch (e) {
        // Detailed logging to identify the "unknown type" error
        // likely caused by minified class names not being registered or mismatch
        DebugLogger().log(// coverage:ignore-line
            "CRITICAL RESTORE ERROR: Failed to save TaxRules for Year ${entry.key}: $e"); // coverage:ignore-line
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
    final prevYearKey = '${profileId}_${now.year - 1}';
    if (_box.containsKey(prevYearKey)) {
      prevYearRules = _box.get(prevYearKey);
    }

    // Use previous year's config if available to determine boundary
    final referenceRules = prevYearRules ?? getRulesForYear(now.year);

    // If today's month is BEFORE the start month, we are in the previous FY.
    if (now.month < referenceRules.financialYearStartMonth) {
      return now.year - 1; // coverage:ignore-line
    }
    return now.year;
  }

  /// For backward compatibility or convenience property (defaults to CURRENT FY)
  TaxRules get rules =>
      getRulesForYear(getCurrentFinancialYear()); // coverage:ignore-line
}

final taxConfigServiceProvider = Provider<TaxConfigService>((ref) {
  final profileId = ref.watch(activeProfileIdProvider); // coverage:ignore-line
  return TaxConfigService(profileId: profileId); // coverage:ignore-line
});
