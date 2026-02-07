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
    // 1. Define Date Range
    final start = customStart ?? DateTime(year, 4, 1);
    final end = customEnd ?? DateTime(year + 1, 3, 31, 23, 59, 59);

    final allTxns = _storage.getAllTransactions();

    // Pre-fetch categories for lookup
    final categories = _storage.getCategories();
    final Map<String, CategoryTag> categoryTagMap = {
      for (var c in categories) c.name.toLowerCase(): c.tag
    };

    // 2. Filter Strict: Income Only
    final incomeTxns = allTxns.where((t) {
      if (t.type != TransactionType.income) return false;
      if (t.date.isBefore(start) || t.date.isAfter(end)) return false;
      return true;
    }).toList();

    // 3. Aggregate by Heads
    double salaryTotal = 0;
    double businessTotal = 0;
    double rentTotal = 0;
    double agriTotal = 0;

    // Dividend Split (Advance Tax Quarters)
    double divQ1 = 0; // Apr 1 - Jun 15
    double divQ2 = 0; // Jun 16 - Sep 15
    double divQ3 = 0; // Sep 16 - Dec 15
    double divQ4 = 0; // Dec 16 - Mar 15
    double divQ5 = 0; // Mar 16 - Mar 31

    List<String> warnings = [];
    List<OtherIncome> individualOtherIncomes = [];
    final cgEntries = <CapitalGainEntry>[];

    for (final txn in incomeTxns) {
      double amount = txn.amount;
      String head = 'other';
      bool matched = false;
      final tagMap = _config.rules.tagMappings;

      // Determine Head
      final catName = txn.category.toLowerCase();
      final catTag = categoryTagMap[catName] ?? CategoryTag.none;

      // MAPPING LOGIC
      // 1. Advanced Mappings (Complex rules with months/descriptions)
      final advancedRules = _config.rules.advancedTagMappings;
      TaxMappingRule? matchingAdvancedRule;

      for (final rule in advancedRules) {
        if (rule.categoryName.toLowerCase() == catName ||
            rule.categoryName.toLowerCase() == catTag.name.toLowerCase()) {
          // Check months
          bool monthsMatch = true;
          if (rule.minHoldingMonths != null) {
            final tenure = txn.holdingTenureMonths ?? 0;
            if (rule.taxHead == 'stcg') {
              if (tenure >= rule.minHoldingMonths!) {
                monthsMatch = false;
              }
            } else if (rule.taxHead == 'ltcg') {
              if (tenure < rule.minHoldingMonths!) {
                monthsMatch = false;
              }
            }
          }

          // Check descriptions
          bool descMatch = true;
          if (rule.matchDescriptions.isNotEmpty) {
            descMatch = false;
            final title = txn.title.toLowerCase();
            for (final pattern in rule.matchDescriptions) {
              if (title.contains(pattern.toLowerCase())) {
                descMatch = true;
                break;
              }
            }
          }

          if (monthsMatch && descMatch) {
            // Check exclusions
            bool excluded = false;
            if (rule.excludeDescriptions.isNotEmpty) {
              final title = txn.title.toLowerCase();
              for (final pattern in rule.excludeDescriptions) {
                if (title.contains(pattern.toLowerCase())) {
                  excluded = true;
                  break;
                }
              }
            }

            if (!excluded) {
              matchingAdvancedRule = rule;
              break;
            }
          }
        }
      }

      if (matchingAdvancedRule != null) {
        head = matchingAdvancedRule.taxHead;
        matched = true;
      } else if (tagMap.containsKey(catName)) {
        head = tagMap[catName]!;
        matched = true;
      } else if (tagMap.containsKey(catTag.name)) {
        head = tagMap[catTag.name]!;
        matched = true;
      }

      if (!matched) {
        // Collect Warning & SKIP (Do not treat as Other)
        warnings.add(
            'Unmapped Income: "₹${amount.toStringAsFixed(0)} - ${txn.category}"');
        continue;
      }

      // Aggregate
      if (head == 'salary') {
        salaryTotal += amount;
      } else if (head == 'houseProp') {
        rentTotal += amount;
      } else if (head == 'business') {
        businessTotal += amount;
      } else if (head == 'ltcg' || head == 'stcg') {
        final double gain = txn.gainAmount ?? amount;
        final double cost = amount - gain;
        cgEntries.add(CapitalGainEntry(
          description: txn.title.isNotEmpty ? txn.title : txn.category,
          matchAssetType:
              AssetType.equityShares, // Defaulting to equity for now
          isLTCG: head == 'ltcg',
          saleAmount: amount,
          gainDate: txn.date,
          costOfAcquisition: cost,
        ));
      } else if (head == 'dividend') {
        // Quarterly Split Logic
        final d = txn.date;
        // Year is dynamic (start.year), but quarters are fixed relative to start date
        // Start: Apr 1 (Year) -> End: Mar 31 (Year+1)
        final y1 = start.year;
        // Q1: Apr 1 - Jun 15
        if (d.isBefore(DateTime(y1, 6, 16))) {
          divQ1 += amount;
        }
        // Q2: Jun 16 - Sep 15
        else if (d.isBefore(DateTime(y1, 9, 16))) {
          divQ2 += amount;
        }
        // Q3: Sep 16 - Dec 15
        else if (d.isBefore(DateTime(y1, 12, 16))) {
          divQ3 += amount;
        }
        // Q4: Dec 16 - Mar 15 (Next Year)
        else if (d.isBefore(DateTime(y1 + 1, 3, 16))) {
          divQ4 += amount;
        }
        // Q5: Mar 16 - Mar 31
        else {
          divQ5 += amount;
        }
      } else if (head == 'agriIncome') {
        agriTotal += amount;
      } else if (head == 'other' || head == 'gift') {
        individualOtherIncomes.add(OtherIncome(
          name: txn.title.isNotEmpty ? txn.title : txn.category,
          amount: amount,
          type: head == 'gift' ? 'Gift' : 'Other',
        ));
      }
    }

    // 4. Integrate Insurance Maturity (Manual Trigger Driver)
    final policies = _storage.getInsurancePolicies();
    for (final policy in policies) {
      if (policy.isTaxExempt == false) {
        // Check if maturing in this range
        if (policy.maturityDate
                .isAfter(start.subtract(const Duration(seconds: 1))) &&
            policy.maturityDate.isBefore(end.add(const Duration(seconds: 1)))) {
          if (policy.isUnitLinked) {
            // ULIP -> LTCG
            final years = policy.maturityDate.year - policy.startDate.year;
            final cost = policy.annualPremium * years.clamp(1, 100);
            cgEntries.add(CapitalGainEntry(
              description: 'Insurance Maturity: ${policy.policyName}',
              matchAssetType: AssetType.other,
              isLTCG: true,
              saleAmount: policy.sumAssured,
              costOfAcquisition: cost,
              gainDate: policy.maturityDate,
            ));
          } else {
            // Non-ULIP -> Other Income
            final years = policy.maturityDate.year - policy.startDate.year;
            final cost = policy.annualPremium * years.clamp(1, 100);
            final gain =
                (policy.sumAssured - cost).clamp(0.0, policy.sumAssured);
            individualOtherIncomes.add(OtherIncome(
              name: 'Insurance Maturity: ${policy.policyName}',
              amount: gain,
              type: 'Other',
              subtype: 'other',
            ));
          }
        }
      }
    }

    // Construct Granular Objects
    final salaryDetails = SalaryDetails(grossSalary: salaryTotal);

    final dividendDetails = DividendIncome(
        amountQ1: divQ1,
        amountQ2: divQ2,
        amountQ3: divQ3,
        amountQ4: divQ4,
        amountQ5: divQ5);

    final houseProps = rentTotal > 0
        ? [
            HouseProperty(
                name: 'Aggregated Properties', rentReceived: rentTotal)
          ]
        : <HouseProperty>[];

    final businesses = businessTotal > 0
        ? [
            BusinessEntity(
                name: 'Aggregated Business',
                type: BusinessType.regular,
                netIncome: businessTotal)
          ]
        : <BusinessEntity>[];

    final otherIncomes = individualOtherIncomes;

    return TaxSyncResult(
        TaxYearData(
          year: year,
          salary: salaryDetails,
          houseProperties: houseProps,
          businessIncomes: businesses,
          capitalGains: cgEntries,
          otherIncomes: otherIncomes,
          agricultureIncome: agriTotal,
          dividendIncome: dividendDetails,
        ),
        warnings);
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

final taxDataFetcherProvider = Provider<TaxDataFetcher>((ref) {
  final storage = ref.watch(storageServiceProvider);
  final config = ref.watch(taxConfigServiceProvider);
  return TaxDataFetcher(storage, config);
});
