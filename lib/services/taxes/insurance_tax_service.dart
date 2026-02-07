import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samriddhi_flow/models/taxes/insurance_policy.dart';
import 'package:samriddhi_flow/models/taxes/tax_rules.dart';
import 'package:samriddhi_flow/services/taxes/tax_config_service.dart';

class InsuranceTaxService {
  final TaxConfigService _configService;

  // In-memory list for now; typically this would act on a repository/provider
  // Assuming this service is stateless regarding data storage, but logic-heavy.

  InsuranceTaxService(this._configService);

  /// Returns policies categorized into 'Exempt' and 'Taxable' based on Section 10(10D)
  /// optimization for a given financial year (or maturity year).
  ///
  /// Logic:
  /// 1. Policies issued before 1 Apr 2012: Premium must be <= 20% of Sum Assured.
  /// 2. Policies issued after 1 Apr 2012: Premium must be <= 10% of Sum Assured.
  /// 3. Aggregate Premium Rule (1 Apr 2023 onwards): Total premium of claimed policies <= 5L.
  List<InsurancePolicy> optimizeMaturityTax(List<InsurancePolicy> allPolicies) {
    final updatedPolicies = <InsurancePolicy>[];

    // Sort policies: We want to prioritize exempting policies with highest profitability (Maturity - Premium)
    // OR simply by Maturity Amount to save max tax.
    // Let's assume we prioritize tax saving on the largest chunks.
    final sorted = List<InsurancePolicy>.from(allPolicies);
    // Sorting by Sum Assured as a proxy for Maturity Amount
    sorted.sort((a, b) => b.sumAssured.compareTo(a.sumAssured));

    double currentAggregatePremiumNonULIP = 0;
    double currentAggregatePremiumULIP = 0;

    final rules = _configService.rules;
    final limitNonULIP = rules.limitInsuranceNonULIP;
    final dateNonULIP = rules.dateEffectiveNonULIP;

    // --- Dynamic Rule Application ---
    final premiumRules = rules.insurancePremiumRules;

    for (final policy in sorted) {
      bool isEligiblePercent = false;

      // Find valid rule for this policy date
      // Default to 100% (exempt) if no specific rule restricts it (e.g. ancient policies)
      double applicableLimit = 100.0;

      // Sort rules newest first to find the most recent applicable start date
      final sortedRules = List<InsurancePremiumRule>.from(premiumRules)
        ..sort((a, b) => b.startDate.compareTo(a.startDate));

      for (final rule in sortedRules) {
        if (policy.startDate.isAfter(rule.startDate) ||
            policy.startDate.isAtSameMomentAs(rule.startDate)) {
          applicableLimit = rule.limitPercentage;
          break;
        }
      }

      // Check if premium is within the % limit of Sum Assured
      isEligiblePercent =
          policy.annualPremium <= ((applicableLimit / 100) * policy.sumAssured);

      if (!isEligiblePercent) {
        updatedPolicies.add(policy.copyWith(isTaxExempt: false));
        continue;
      }

      // Rule 3: Aggregate Limits based on Policy Type & Date
      if (policy.isUnitLinked) {
        // ULIP Logic
        if (policy.startDate.isBefore(rules.dateEffectiveULIP)) {
          // Old ULIPs are exempt irrespective of 2.5L limit (if they meet 10% rule)
          updatedPolicies.add(policy.copyWith(isTaxExempt: true));
        } else {
          // New ULIPs Check Aggregate
          if (currentAggregatePremiumULIP + policy.annualPremium <=
              rules.limitInsuranceULIP) {
            updatedPolicies.add(policy.copyWith(isTaxExempt: true));
            currentAggregatePremiumULIP += policy.annualPremium;
          } else {
            updatedPolicies.add(policy.copyWith(isTaxExempt: false));
          }
        }
      } else {
        // Non-ULIP (Traditional) Logic
        if (policy.startDate.isBefore(dateNonULIP)) {
          // Old Traditional Policies are exempt
          updatedPolicies.add(policy.copyWith(isTaxExempt: true));
        } else {
          // New Traditional Policies Check Aggregate
          if (currentAggregatePremiumNonULIP + policy.annualPremium <=
              limitNonULIP) {
            updatedPolicies.add(policy.copyWith(isTaxExempt: true));
            currentAggregatePremiumNonULIP += policy.annualPremium;
          } else {
            updatedPolicies.add(policy.copyWith(isTaxExempt: false));
          }
        }
      }
    }

    return updatedPolicies;
  }
}

final insuranceTaxServiceProvider = Provider<InsuranceTaxService>((ref) {
  final config = ref.watch(taxConfigServiceProvider);
  return InsuranceTaxService(config);
});
