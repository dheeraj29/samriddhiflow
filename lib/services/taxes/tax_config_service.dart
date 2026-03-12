import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samriddhi_flow/models/taxes/tax_rules.dart';
import 'package:hive_ce/hive.dart';
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
      await Hive.openBox<TaxRules>(_boxName);
    }
  }

  bool get isReady => Hive.isBoxOpen(_boxName);

  /// Get rules for a specific Assessment Year.
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
    if (_box.containsKey(now.year - 1)) {
      prevYearRules = _box.get(now.year - 1); // coverage:ignore-line
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
  TaxRules get rules =>
      getRulesForYear(getCurrentFinancialYear()); // coverage:ignore-line
}

final taxConfigServiceProvider = Provider<TaxConfigService>((ref) {
  final profileId = ref.watch(activeProfileIdProvider); // coverage:ignore-line
  return TaxConfigService(profileId: profileId); // coverage:ignore-line
});
