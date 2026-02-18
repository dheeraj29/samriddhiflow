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
    // Fetch rules for that year to know FY Start Month
    final rules = _config.getRulesForYear(year);
    final startMonth = rules.financialYearStartMonth;

    // 1. Define Date Range
    // If startMonth is 1 (Jan), Range is Jan 1 to Dec 31 of 'year'.
    // If startMonth is 4 (Apr), Range is Apr 1 'year' to Mar 31 'year+1'.
    DateTime start;
    DateTime end;

    if (customStart != null && customEnd != null) {
      start = customStart;
      end = customEnd;
    } else {
      if (startMonth == 1) {
        start = DateTime(year, 1, 1);
        end = DateTime(year, 12, 31, 23, 59, 59);
      } else {
        start = DateTime(year, startMonth, 1);
        end = DateTime(year + 1, startMonth - 1, 0, 23, 59, 59)
            .add(const Duration(hours: 23, minutes: 59, seconds: 59));
        // Fix: day 0 is last day of prev month.
        // Simpler:
        // end = DateTime(year + 1, startMonth, 1).subtract(const Duration(seconds: 1));
      }

      // Correct Logic for End Date:
      if (startMonth == 1) {
        end = DateTime(year + 1, 1, 1).subtract(const Duration(seconds: 1));
      } else {
        end = DateTime(year + 1, startMonth, 1)
            .subtract(const Duration(seconds: 1));
      }
    }

    final allTxns = _storage.getAllTransactions();

    // Pre-fetch categories for lookup
    final categories = _storage.getCategories();
    final Map<String, CategoryTag> categoryTagMap = {
      for (var c in categories) c.name: c.tag
    };

    // 2. Filter Strict: Income Only
    final incomeTxns = allTxns.where((t) {
      if (t.type != TransactionType.income) return false;
      if (t.date.isBefore(start) || t.date.isAfter(end)) return false;
      return true;
    }).toList();

    // 3. Aggregate by Heads
    double businessTotal = 0;
    double rentTotal = 0;
    double agriTotal = 0;

    // Dividend Split (Advance Tax Quarters)
    double divQ1 = 0;
    double divQ2 = 0;
    double divQ3 = 0;
    double divQ4 = 0;
    double divQ5 = 0;

    List<String> warnings = [];
    List<OtherIncome> individualOtherIncomes = [];
    final cgEntries = <CapitalGainEntry>[];

    for (final txn in incomeTxns) {
      double amount = txn.amount;
      String head = 'other';
      bool matched = false;
      // Fix: Use rules for the SELECTED year, not current config
      final tagMap = rules.tagMappings;

      // Determine Head
      // Fix: Exact Match (No Lowercase)
      final catName = txn.category;
      final catTag = categoryTagMap[catName] ?? CategoryTag.none;

      // MAPPING LOGIC
      // 1. Advanced Mappings (Complex rules with months/descriptions)
      final advancedRules = rules.advancedTagMappings;
      TaxMappingRule? matchingAdvancedRule;

      for (final rule in advancedRules) {
        if (rule.categoryName == catName || rule.categoryName == catTag.name) {
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
            final title = txn.title;
            for (final pattern in rule.matchDescriptions) {
              if (title.contains(pattern)) {
                descMatch = true;
                break;
              }
            }
          }

          if (monthsMatch && descMatch) {
            // Check exclusions
            bool excluded = false;
            if (rule.excludeDescriptions.isNotEmpty) {
              final title = txn.title;
              for (final pattern in rule.excludeDescriptions) {
                if (title.contains(pattern)) {
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
      if (head == 'houseProp') {
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
        final d = txn.date;

        // Dynamic Dividend Split for Advance Tax logic
        // Q1: Upto 15th of 3rd month (e.g. June 15 if starting April)
        // Q2: Upto 15th of 6th month (e.g. Sept 15)
        // Q3: Upto 15th of 9th month (e.g. Dec 15)
        // Q4: Upto 15th of 12th month (e.g. Mar 15)
        // Q5: Rest (Mar 16 - Mar 31)

        // Cutoff Dates (using start.month + offset)
        final q1End =
            DateTime(start.year, start.month + 2, 16); // Before June 16
        final q2End =
            DateTime(start.year, start.month + 5, 16); // Before Sept 16
        final q3End =
            DateTime(start.year, start.month + 8, 16); // Before Dec 16
        final q4End =
            DateTime(start.year, start.month + 11, 16); // Before Mar 16

        if (d.isBefore(q1End)) {
          // Q1 approx
          divQ1 += amount;
        } else if (d.isBefore(q2End)) {
          divQ2 += amount;
        } else if (d.isBefore(q3End)) {
          divQ3 += amount;
        } else if (d.isBefore(q4End)) {
          divQ4 += amount;
        } else {
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
    final salaryDetails = const SalaryDetails(
      grossSalary: 0,
      giftsFromEmployer: 0,
      netSalaryReceived: {},
    );

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
