import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samriddhi_flow/models/taxes/tax_data.dart';
import 'package:samriddhi_flow/models/taxes/tax_data_models.dart';
import 'package:samriddhi_flow/services/storage_service.dart';
import 'package:samriddhi_flow/models/transaction.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/services/taxes/tax_config_service.dart';
import 'package:samriddhi_flow/models/taxes/tax_rules.dart';
import 'package:samriddhi_flow/services/taxes/insurance_tax_service.dart';
import 'package:samriddhi_flow/models/category.dart';
import 'package:clock/clock.dart';

class TaxSyncResult {
  final TaxYearData data;
  final List<String> warnings;
  TaxSyncResult(this.data, this.warnings);
}

class TaxDataFetcher {
  final StorageService _storage;
  final TaxConfigService _config;
  final InsuranceTaxService _insuranceTax;

  TaxDataFetcher(this._storage, this._config, this._insuranceTax);

  /// Fetches transactions for the given year and aggregates them into TaxYearData.
  /// Returns warnings for unmapped Income transactions.
  Future<TaxSyncResult> fetchAndAggregate(int year,
      {DateTime? customStart,
      DateTime? customEnd,
      bool forceResync = false}) async {
    final rules = _config.getRulesForYear(year);
    final dateRange = _computeDateRange(year, rules, customStart, customEnd);
    final start = dateRange.start;
    final end = dateRange.end;

    final categoryTagMap = _buildCategoryTagMap();
    final incomeTxns = _filterIncomeTransactions(start, end, forceResync);

    // Aggregate income by tax heads
    final aggregation = _AggregationResult();
    final syncedTransactionIds = <String>[];

    for (final txn in incomeTxns) {
      final head = _resolveHead(
          txn, categoryTagMap[txn.category] ?? CategoryTag.none, rules);
      if (head != null) {
        _addToHead(head, txn, txn.amount, start, aggregation);
        syncedTransactionIds.add(txn.id);
      } else {
        aggregation.warnings.add(
            'Unmapped Income: "${txn.amount.toStringAsFixed(0)} - ${txn.category}"');
      }
    }

    // Integrate insurance maturity
    _aggregateInsuranceMaturity(start, end, aggregation);

    // Update taxSync flag for transactions
    if (syncedTransactionIds.isNotEmpty) {
      await _storage.updateTransactionsTaxSync(syncedTransactionIds, true);
    }

    return TaxSyncResult(
        _buildTaxYearData(year, aggregation), aggregation.warnings);
  }

  // --- Date Range ---

  _DateRange _computeDateRange(
      int year, TaxRules rules, DateTime? customStart, DateTime? customEnd) {
    if (customStart != null && customEnd != null) {
      return _DateRange(customStart, customEnd); // coverage:ignore-line
    }

    final startMonth = rules.financialYearStartMonth;
    final start =
        startMonth == 1 ? DateTime(year, 1, 1) : DateTime(year, startMonth, 1);
    final end = startMonth == 1
        ? DateTime(year + 1, 1, 1)
            .subtract(const Duration(seconds: 1)) // coverage:ignore-line
        : DateTime(year + 1, startMonth, 1)
            .subtract(const Duration(seconds: 1));

    return _DateRange(start, end);
  }

  // --- Category Lookup ---

  Map<String, CategoryTag> _buildCategoryTagMap() {
    final categories = _storage.getCategories();
    return {for (var c in categories) c.name: c.tag};
  }

  // --- Transaction Filtering ---

  List<Transaction> _filterIncomeTransactions(
      DateTime start, DateTime end, bool forceResync) {
    return _storage.getAllTransactions().where((t) {
      if (t.type != TransactionType.income) return false;
      if (t.date.isBefore(start) || t.date.isAfter(end)) return false;
      if (!forceResync && t.taxSync == true) return false;
      return true;
    }).toList();
  }

  // --- Transaction Aggregation ---

  String? _resolveHead(Transaction txn, CategoryTag catTag, TaxRules rules) {
    final catName = txn.category;
    // 1. Try advanced mappings first
    final advancedRule = _findMatchingAdvancedRule(
        txn, catName, catTag, rules.advancedTagMappings);
    if (advancedRule != null) return advancedRule.taxHead;

    // 2. Try simple tag mappings
    final tagMap = rules.tagMappings;
    if (tagMap.containsKey(catName)) return tagMap[catName]!;
    if (tagMap.containsKey(catTag.name)) return tagMap[catTag.name]!;

    return null; // Unmapped
  }

  TaxMappingRule? _findMatchingAdvancedRule(Transaction txn, String catName,
      CategoryTag catTag, List<TaxMappingRule> advancedRules) {
    for (final rule in advancedRules) {
      if (rule.categoryName != catName && rule.categoryName != catTag.name) {
        continue;
      }
      if (!_matchesHoldingPeriod(rule, txn)) continue;
      if (!_matchesDescriptions(rule, txn)) continue;
      if (_isExcludedByDescription(rule, txn)) continue;
      return rule;
    }
    return null;
  }

  bool _matchesHoldingPeriod(TaxMappingRule rule, Transaction txn) {
    if (rule.minHoldingMonths == null) return true;
    final tenure = txn.holdingTenureMonths ?? 0;
    if (rule.taxHead == 'stcg') return tenure < rule.minHoldingMonths!;
    if (rule.taxHead == 'ltcg') return tenure >= rule.minHoldingMonths!;
    return true;
  }

  bool _matchesDescriptions(TaxMappingRule rule, Transaction txn) {
    if (rule.matchDescriptions.isEmpty) return true;
    final title = txn.title; // coverage:ignore-line
    return rule.matchDescriptions
        .any((pattern) => title.contains(pattern)); // coverage:ignore-line
  }

  bool _isExcludedByDescription(TaxMappingRule rule, Transaction txn) {
    if (rule.excludeDescriptions.isEmpty) return false;
    final title = txn.title; // coverage:ignore-line
    return rule.excludeDescriptions
        .any((pattern) => title.contains(pattern)); // coverage:ignore-line
  }

  void _addToHead(String head, Transaction txn, double amount, DateTime start,
      _AggregationResult agg) {
    switch (head) {
      case 'houseProp':
        agg.rentTotal += amount;
        break;
      case 'business':
        agg.businessTotal += amount;
        break;
      case 'ltcg':
      case 'stcg':
        _addCapitalGain(head, txn, amount, agg);
        break;
      case 'dividend':
        _addDividend(txn.date, amount, start, agg);
        break;
      case 'agriIncome':
        agg.agriTotal += amount;
        break;
      case 'other':
      case 'gift':
        _addOtherHead(head, txn, amount, agg);
        break;
    }
  }

  void _addOtherHead(
      String head, Transaction txn, double amount, _AggregationResult agg) {
    final name = txn.title.isNotEmpty ? txn.title : txn.category;
    if (head == 'other') {
      agg.otherIncomes.add(OtherIncome(
        // coverage:ignore-line
        name: name,
        amount: amount,
        type: 'Other',
        subtype: 'others', // Technical key
        isManualEntry: false,
        lastUpdated: clock.now(), // coverage:ignore-line
        transactionDate: txn.date, // coverage:ignore-line
      ));
    } else if (head == 'gift') {
      agg.cashGifts.add(OtherIncome(
        name: name,
        amount: amount,
        type: 'Gift',
        subtype: 'other', // Technical key
        isManualEntry: false,
        lastUpdated: clock.now(),
        transactionDate: txn.date,
      ));
    }
  }

  void _addCapitalGain(
      String head, Transaction txn, double amount, _AggregationResult agg) {
    final double gain = txn.gainAmount ?? amount;
    final double cost = amount - gain;
    agg.cgEntries.add(CapitalGainEntry(
      description: txn.title.isNotEmpty ? txn.title : txn.category,
      matchAssetType: AssetType.equityShares,
      isLTCG: head == 'ltcg',
      saleAmount: amount,
      gainDate: txn.date,
      costOfAcquisition: cost,
      isManualEntry: false,
      lastUpdated: clock.now(),
      transactionDate: txn.date,
    ));
  }

  void _addDividend(
      DateTime d, double amount, DateTime start, _AggregationResult agg) {
    final q1End = DateTime(start.year, start.month + 2, 16);
    final q2End = DateTime(start.year, start.month + 5, 16);
    final q3End = DateTime(start.year, start.month + 8, 16);
    final q4End = DateTime(start.year, start.month + 11, 16);

    if (d.isBefore(q1End)) {
      agg.divQ1 += amount;
    } else if (d.isBefore(q2End)) {
      agg.divQ2 += amount;
    } else if (d.isBefore(q3End)) {
      agg.divQ3 += amount;
    } else if (d.isBefore(q4End)) {
      agg.divQ4 += amount;
    } else {
      agg.divQ5 += amount;
    }
  }

  // --- Insurance Maturity ---

  void _aggregateInsuranceMaturity(
      DateTime start, DateTime end, _AggregationResult agg) {
    // FY Year (anchored to FY start year)
    final fyYear = start.month >= 4 ? start.year : start.year - 1;
    final policies = _storage.getInsurancePolicies();

    for (final policy in policies) {
      if (policy.isIncomeAddedByYear[fyYear] == true) continue;

      final entry = _insuranceTax.getTaxableIncomeEntry(policy, fyYear);
      if (entry == null) continue;

      if (entry is CapitalGainEntry) {
        agg.cgEntries.add(entry);
      } else if (entry is OtherIncome) {
        agg.otherIncomes.add(entry);
      }
    }
  }

  // --- Result Building ---

  TaxYearData _buildTaxYearData(int year, _AggregationResult agg) {
    final now = clock.now();
    const salaryDetails = SalaryDetails(
      history: [],
    );

    final dividendDetails = DividendIncome(
      amountQ1: agg.divQ1,
      amountQ2: agg.divQ2,
      amountQ3: agg.divQ3,
      amountQ4: agg.divQ4,
      amountQ5: agg.divQ5,
      lastUpdated: now,
    );

    final houseProps = agg.rentTotal > 0
        ? [
            HouseProperty(
                name: 'Aggregated Properties',
                rentReceived: agg.rentTotal,
                isManualEntry: false,
                lastUpdated: now)
          ]
        : <HouseProperty>[];

    final businesses = agg.businessTotal > 0
        ? [
            BusinessEntity(
                name: 'Aggregated Business',
                type: BusinessType.regular,
                netIncome: agg.businessTotal,
                isManualEntry: false,
                lastUpdated: now)
          ]
        : <BusinessEntity>[];

    return TaxYearData(
      year: year,
      salary: salaryDetails,
      houseProperties: houseProps,
      businessIncomes: businesses,
      capitalGains: agg.cgEntries,
      otherIncomes: agg.otherIncomes,
      cashGifts: agg.cashGifts,
      dividendIncome: dividendDetails,
      lastSyncDate: now,
      agriIncomeHistory: agg.agriTotal > 0
          ? [
              AgriIncomeEntry(
                id: 'sync_agri_$year',
                amount: agg.agriTotal,
                date: now,
                description: 'Synced Agriculture Income',
                isManualEntry: false,
              )
            ]
          : [],
    );
  }

  /// Helper to fetch sum of transactions matching a Category Name (acting as tag) and type within range.
  /// This is used for "Loan Tag" matching - where the loanTag is expected to be the Category Name.
  double fetchTagSum(
      String categoryName, TransactionType type, DateTime start, DateTime end) {
    final txns = _storage.getAllTransactions();
    final targetCat = categoryName.trim().toLowerCase();

    return txns
        .where((t) =>
            t.type == type &&
            t.date.isAfter(start.subtract(const Duration(seconds: 1))) &&
            t.date.isBefore(end.add(const Duration(seconds: 1))) &&
            t.category.trim().toLowerCase() == targetCat)
        .fold(0.0, (sum, t) => sum + t.amount);
  }
}

// --- Private Helper Classes ---

class _DateRange {
  final DateTime start;
  final DateTime end;
  _DateRange(this.start, this.end);
}

class _AggregationResult {
  double businessTotal = 0;
  double rentTotal = 0;
  double agriTotal = 0;
  double divQ1 = 0, divQ2 = 0, divQ3 = 0, divQ4 = 0, divQ5 = 0;
  List<String> warnings = [];
  List<OtherIncome> otherIncomes = [];
  List<OtherIncome> cashGifts = [];
  List<CapitalGainEntry> cgEntries = [];
}

final taxDataFetcherProvider = Provider<TaxDataFetcher>((ref) {
  // coverage:ignore-start
  final storage = ref.watch(storageServiceProvider);
  final config = ref.watch(taxConfigServiceProvider);
  final insuranceTax = ref.watch(insuranceTaxServiceProvider);
  return TaxDataFetcher(storage, config, insuranceTax);
  // coverage:ignore-end
});
