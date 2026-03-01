import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samriddhi_flow/models/taxes/tax_data.dart';
import 'package:samriddhi_flow/models/taxes/tax_data_models.dart';
import 'package:samriddhi_flow/services/storage_service.dart';
import 'package:samriddhi_flow/models/transaction.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/services/taxes/tax_config_service.dart';
import 'package:samriddhi_flow/models/taxes/tax_rules.dart';
import 'package:samriddhi_flow/models/category.dart';

class TaxSyncResult {
  final TaxYearData data;
  final List<String> warnings;
  TaxSyncResult(this.data, this.warnings);
}

class TaxDataFetcher {
  final StorageService _storage;
  final TaxConfigService _config;

  TaxDataFetcher(this._storage, this._config);

  /// Fetches transactions for the given year and aggregates them into TaxYearData.
  /// Returns warnings for unmapped Income transactions.
  Future<TaxSyncResult> fetchAndAggregate(int year,
      {DateTime? customStart, DateTime? customEnd}) async {
    final rules = _config.getRulesForYear(year);
    final dateRange = _computeDateRange(year, rules, customStart, customEnd);
    final start = dateRange.start;
    final end = dateRange.end;

    final categoryTagMap = _buildCategoryTagMap();
    final incomeTxns = _filterIncomeTransactions(start, end);

    // Aggregate income by tax heads
    final aggregation = _AggregationResult();
    for (final txn in incomeTxns) {
      _aggregateTransaction(txn, rules, categoryTagMap, start, aggregation);
    }

    // Integrate insurance maturity
    _aggregateInsuranceMaturity(start, end, aggregation);

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
        ? DateTime(year + 1, 1, 1) // coverage:ignore-line
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

  List<Transaction> _filterIncomeTransactions(DateTime start, DateTime end) {
    return _storage.getAllTransactions().where((t) {
      if (t.type != TransactionType.income) return false;
      if (t.date.isBefore(start) || t.date.isAfter(end)) return false;
      return true;
    }).toList();
  }

  // --- Transaction Aggregation ---

  void _aggregateTransaction(
      Transaction txn,
      TaxRules rules,
      Map<String, CategoryTag> categoryTagMap,
      DateTime start,
      _AggregationResult agg) {
    final amount = txn.amount;
    final catName = txn.category;
    final catTag = categoryTagMap[catName] ?? CategoryTag.none;

    final head = _resolveHead(txn, catName, catTag, rules);
    if (head == null) {
      agg.warnings.add(
          'Unmapped Income: "${amount.toStringAsFixed(0)} - ${txn.category}"');
      return;
    }

    _addToHead(head, txn, amount, start, agg);
  }

  String? _resolveHead(
      Transaction txn, String catName, CategoryTag catTag, TaxRules rules) {
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
    // coverage:ignore-start
    final title = txn.title;
    return rule.matchDescriptions
        .any((pattern) => title.contains(pattern));
    // coverage:ignore-end
  }

  bool _isExcludedByDescription(TaxMappingRule rule, Transaction txn) {
    if (rule.excludeDescriptions.isEmpty) return false;
    // coverage:ignore-start
    final title = txn.title;
    return rule.excludeDescriptions
        .any((pattern) => title.contains(pattern));
    // coverage:ignore-end
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


      String head,
      Transaction txn,
      double amount,
      _AggregationResult agg) {
    final name = txn.title.isNotEmpty ? txn.title : txn.category;
    if (head == 'other') {
      agg.otherIncomes // coverage:ignore-line
          .add(OtherIncome(name: name, amount: amount, type: 'Other')); // coverage:ignore-line
    } else if (head == 'gift') {
      agg.cashGifts.add(OtherIncome(
        name: name,
        amount: amount,
        type: 'Gift',
        subtype: 'Other',
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
    final policies = _storage.getInsurancePolicies();
    for (final policy in policies) {
      if (policy.isTaxExempt != false) continue;
      if (policy.maturityDate
              .isBefore(start.subtract(const Duration(seconds: 1))) ||
          policy.maturityDate.isAfter(end.add(const Duration(seconds: 1)))) {
        continue;
      }

      final years = policy.maturityDate.year - policy.startDate.year;
      final cost = policy.annualPremium * years.clamp(1, 100);

      if (policy.isUnitLinked) {
        agg.cgEntries.add(CapitalGainEntry(
          description: 'Insurance Maturity: ${policy.policyName}',
          matchAssetType: AssetType.other,
          isLTCG: true,
          saleAmount: policy.sumAssured,
          costOfAcquisition: cost,
          gainDate: policy.maturityDate,
        ));
      } else {
        final gain = (policy.sumAssured - cost).clamp(0.0, policy.sumAssured);
        agg.otherIncomes.add(OtherIncome(
          name: 'Insurance Maturity: ${policy.policyName}',
          amount: gain,
          type: 'Other',
          subtype: 'other',
        ));
      }
    }
  }

  // --- Result Building ---

  TaxYearData _buildTaxYearData(int year, _AggregationResult agg) {
    const salaryDetails = SalaryDetails(
      grossSalary: 0,
      giftsFromEmployer: 0,
      netSalaryReceived: {},
    );

    final dividendDetails = DividendIncome(
        amountQ1: agg.divQ1,
        amountQ2: agg.divQ2,
        amountQ3: agg.divQ3,
        amountQ4: agg.divQ4,
        amountQ5: agg.divQ5);

    final houseProps = agg.rentTotal > 0
        ? [
            HouseProperty(
                name: 'Aggregated Properties', rentReceived: agg.rentTotal)
          ]
        : <HouseProperty>[];

    final businesses = agg.businessTotal > 0
        ? [
            BusinessEntity(
                name: 'Aggregated Business',
                type: BusinessType.regular,
                netIncome: agg.businessTotal)
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
      agricultureIncome: agg.agriTotal,
      dividendIncome: dividendDetails,
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

// coverage:ignore-start
final taxDataFetcherProvider = Provider<TaxDataFetcher>((ref) {
  final storage = ref.watch(storageServiceProvider);
  final config = ref.watch(taxConfigServiceProvider);
  return TaxDataFetcher(storage, config);
// coverage:ignore-end
});
