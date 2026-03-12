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
    final sorted = List<InsurancePolicy>.from(allPolicies);
    sorted.sort((a, b) => b.sumAssured.compareTo(a.sumAssured));

    double currentAggregatePremiumNonULIP = 0;
    double currentAggregatePremiumULIP = 0;

    final rules = _configService.rules;
    final premiumRules = rules.insurancePremiumRules;

    for (final policy in sorted) {
      final applicableLimit = _findApplicableLimit(policy, premiumRules);
      final isEligiblePercent =
          policy.annualPremium <= ((applicableLimit / 100) * policy.sumAssured);

      if (!isEligiblePercent) {
        updatedPolicies.add(policy.copyWith(isTaxExempt: false));
        continue;
      }

      // Apply aggregate limit rules
      final result = _applyAggregateLimit(
        policy: policy,
        rules: rules,
        currentULIP: currentAggregatePremiumULIP,
        currentNonULIP: currentAggregatePremiumNonULIP,
      );

      updatedPolicies.add(result.policy);
      currentAggregatePremiumULIP = result.updatedULIP;
      currentAggregatePremiumNonULIP = result.updatedNonULIP;
    }

    return updatedPolicies;
  }

  double _findApplicableLimit(
      InsurancePolicy policy, List<InsurancePremiumRule> premiumRules) {
    double applicableLimit = 100.0;
    final sortedRules = List<InsurancePremiumRule>.from(premiumRules)
      ..sort((a, b) => b.startDate.compareTo(a.startDate));
    for (final rule in sortedRules) {
      if (policy.startDate.isAfter(rule.startDate) ||
          policy.startDate.isAtSameMomentAs(rule.startDate)) {
        // coverage:ignore-line
        applicableLimit = rule.limitPercentage;
        break;
      }
    }
    return applicableLimit;
  }

  _AggregateLimitResult _applyAggregateLimit({
    required InsurancePolicy policy,
    required TaxRules rules,
    required double currentULIP,
    required double currentNonULIP,
  }) {
    if (policy.isUnitLinked) {
      return _applyULIPLimit(policy, rules, currentULIP, currentNonULIP);
    }
    return _applyNonULIPLimit(policy, rules, currentULIP, currentNonULIP);
  }

  _AggregateLimitResult _applyULIPLimit(InsurancePolicy policy, TaxRules rules,
      double currentULIP, double currentNonULIP) {
    if (policy.startDate.isBefore(rules.dateEffectiveULIP)) {
      return _AggregateLimitResult(
          // coverage:ignore-line
          policy.copyWith(isTaxExempt: true),
          currentULIP,
          currentNonULIP); // coverage:ignore-line
    }
    if (currentULIP + policy.annualPremium <= rules.limitInsuranceULIP) {
      return _AggregateLimitResult(policy.copyWith(isTaxExempt: true),
          currentULIP + policy.annualPremium, currentNonULIP);
    }
    return _AggregateLimitResult(
        policy.copyWith(isTaxExempt: false), currentULIP, currentNonULIP);
  }

  _AggregateLimitResult _applyNonULIPLimit(InsurancePolicy policy,
      TaxRules rules, double currentULIP, double currentNonULIP) {
    if (policy.startDate.isBefore(rules.dateEffectiveNonULIP)) {
      return _AggregateLimitResult(
          policy.copyWith(isTaxExempt: true), currentULIP, currentNonULIP);
    }
    if (currentNonULIP + policy.annualPremium <= rules.limitInsuranceNonULIP) {
      return _AggregateLimitResult(policy.copyWith(isTaxExempt: true),
          currentULIP, currentNonULIP + policy.annualPremium);
    }
    return _AggregateLimitResult(
        policy.copyWith(isTaxExempt: false), currentULIP, currentNonULIP);
  }
}

class _AggregateLimitResult {
  final InsurancePolicy policy;
  final double updatedULIP;
  final double updatedNonULIP;
  _AggregateLimitResult(this.policy, this.updatedULIP, this.updatedNonULIP);
}

final insuranceTaxServiceProvider = Provider<InsuranceTaxService>((ref) {
  final config = ref.watch(taxConfigServiceProvider); // coverage:ignore-line
  return InsuranceTaxService(config); // coverage:ignore-line
});
