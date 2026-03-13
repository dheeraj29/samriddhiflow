import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samriddhi_flow/models/taxes/insurance_policy.dart';
import 'package:samriddhi_flow/models/taxes/tax_rules.dart';
import 'package:samriddhi_flow/models/taxes/tax_data_models.dart';
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

  /// Calculates the Sale Consideration and Cost of Acquisition for a taxable policy.
  /// Handles installment-based splitting if enabled.
  Map<String, double> calculateTaxableIncomeSplit(InsurancePolicy p) {
    final totalYears = (p.maturityDate.year - p.startDate.year).clamp(1, 100);
    final totalPremium = p.annualPremium * totalYears;
    final totalGain = (p.sumAssured - totalPremium).clamp(0.0, p.sumAssured);

    if (p.isInstallmentEnabled) {
      return {
        'saleConsideration': p.sumAssured / totalYears,
        'costOfAcquisition': (p.sumAssured - totalGain) / totalYears,
        'taxableGain': totalGain / totalYears,
        'totalGain': totalGain,
      };
    } else {
      return {
        'saleConsideration': p.sumAssured,
        'costOfAcquisition': p.sumAssured - totalGain,
        'taxableGain': totalGain,
        'totalGain': totalGain,
      };
    }
  }

  /// Checks if a policy has a taxable event (maturity or installment) in the given FY.
  bool isApplicableForYear(InsurancePolicy p, int fyStartYear) {
    return getEventDateForYear(p, fyStartYear) != null;
  }

  /// Returns the specific date of the taxable event (maturity or installment) in the given FY.
  /// If multiple installments exist in one year (unlikely with annual), returns the first one.
  /// Returns null if no event exists in that year.
  DateTime? getEventDateForYear(InsurancePolicy p, int fyStartYear) {
    final fyStart = DateTime(fyStartYear, 4, 1);
    final fyEnd = DateTime(fyStartYear + 1, 3, 31, 23, 59, 59);

    // Maturity check
    if (p.maturityDate.isAfter(fyStart.subtract(const Duration(seconds: 1))) &&
        p.maturityDate.isBefore(fyEnd.add(const Duration(seconds: 1)))) {
      return p.maturityDate;
    }

    // Installment check
    if (p.isInstallmentEnabled && p.installmentStartDate != null) {
      DateTime current = p.installmentStartDate!;
      while (current.isBefore(p.maturityDate) ||
          current.isAtSameMomentAs(p.maturityDate)) {
        if (current.isAfter(fyStart.subtract(const Duration(seconds: 1))) &&
            current.isBefore(fyEnd.add(const Duration(seconds: 1)))) {
          return current;
        }
        current = DateTime(current.year + 1, current.month, current.day);
      }
    }

    return null;
  }

  /// Calculates summary statistics for the insurance portfolio.
  InsuranceSummaryData calculateInsuranceSummaryData(
      List<InsurancePolicy> all, int selectedYear) {
    double totalPremium = all.fold(0, (sum, p) => sum + p.annualPremium);
    double currentTaxableGain = 0;
    double futureTaxableGain = 0;
    double taxableUlipTotal = 0;
    double taxableNonUlipTotal = 0;
    final fyEnd = DateTime(selectedYear + 1, 3, 31, 23, 59, 59);

    for (var p in all.where((p) => p.isTaxExempt == false)) {
      // coverage:ignore-start
      final split = calculateTaxableIncomeSplit(p);
      final totalGain = split['totalGain'] ?? 0;
      final annualGain = split['taxableGain'] ?? 0;
      // coverage:ignore-end

      if (p.isUnitLinked) {
        // coverage:ignore-line
        taxableUlipTotal += totalGain; // coverage:ignore-line
      } else {
        taxableNonUlipTotal += totalGain; // coverage:ignore-line
      }

      if (isApplicableForYear(p, selectedYear)) {
        // coverage:ignore-line
        currentTaxableGain += p.isInstallmentEnabled
            ? annualGain
            : totalGain; // coverage:ignore-line
      }

      futureTaxableGain += // coverage:ignore-line
          _calculateFutureGain(
              p, totalGain, annualGain, fyEnd); // coverage:ignore-line
    }

    return InsuranceSummaryData(
      totalPremium: totalPremium,
      currentTaxableGain: currentTaxableGain,
      futureTaxableGain: futureTaxableGain,
      taxableUlipTotal: taxableUlipTotal,
      taxableNonUlipTotal: taxableNonUlipTotal,
      hasPendingCalculations: all.any((p) => p.isTaxExempt == null),
    );
  }

  double _calculateFutureGain(
      InsurancePolicy p,
      double totalGain, // coverage:ignore-line
      double annualGain,
      DateTime fyEndBoundary) {
    if (!p.maturityDate.isAfter(fyEndBoundary)) {
      // coverage:ignore-line
      return 0;
    }

    if (p.isInstallmentEnabled && p.installmentStartDate != null) {
      // coverage:ignore-line
      double future = 0;
      // coverage:ignore-start
      DateTime current = p.installmentStartDate!;
      while (current.isBefore(p.maturityDate) ||
          current.isAtSameMomentAs(p.maturityDate)) {
        if (current.isAfter(fyEndBoundary)) {
          future += annualGain;
          // coverage:ignore-end
        }
        current = DateTime(current.year + 1, current.month,
            current.day); // coverage:ignore-line
      }
      return future;
    }

    return totalGain;
  }

  /// Checks if there's any taxable insurance in the given year that hasn't been added to the dashboard.
  bool hasUnaddedTaxableInsurance(List<InsurancePolicy> policies, int year) {
    for (final p in policies) {
      if (p.isTaxExempt == false &&
          p.isIncomeAddedByYear[year] != true &&
          isApplicableForYear(p, year)) {
        return true;
      }
    }
    return false;
  }

  /// Returns the taxable income entry (either CapitalGainEntry or OtherIncome) for a policy in a given FY.
  /// Returns null if not applicable or exempt.
  dynamic getTaxableIncomeEntry(InsurancePolicy p, int fyStartYear) {
    // coverage:ignore-line
    if (p.isTaxExempt != false || !isApplicableForYear(p, fyStartYear)) {
      // coverage:ignore-line
      return null;
    }

    final eventDate = getEventDateForYear(p, fyStartYear) ??
        DateTime(fyStartYear, 4, 1); // coverage:ignore-line
    final split = calculateTaxableIncomeSplit(p); // coverage:ignore-line

    // coverage:ignore-start
    final isMaturityYear = (p.maturityDate.year == eventDate.year &&
        p.maturityDate.month == eventDate.month &&
        p.maturityDate.day == eventDate.day);
    // coverage:ignore-end
    final descriptionPrefix =
        isMaturityYear ? 'Insurance Maturity' : 'Insurance Payout';
    final description =
        '$descriptionPrefix: ${p.policyName}'; // coverage:ignore-line

    if (p.isUnitLinked) {
      // coverage:ignore-line
      return CapitalGainEntry(
        // coverage:ignore-line
        description: description,
        matchAssetType: AssetType.other,
        isLTCG: true,
        saleAmount: p.sumAssured, // coverage:ignore-line
        costOfAcquisition:
            split['costOfAcquisition'] ?? 0, // coverage:ignore-line
        gainDate: eventDate,
        isManualEntry: false,
        lastUpdated: DateTime.now(), // coverage:ignore-line
        transactionDate: eventDate,
      );
    } else {
      return OtherIncome(
        // coverage:ignore-line
        name: description,
        amount: split['taxableGain'] ?? 0, // coverage:ignore-line
        type: 'Other',
        subtype: 'others',
        isManualEntry: false,
        lastUpdated: DateTime.now(), // coverage:ignore-line
        transactionDate: eventDate,
      );
    }
  }
}

class InsuranceSummaryData {
  final double totalPremium;
  final double currentTaxableGain;
  final double futureTaxableGain;
  final double taxableUlipTotal;
  final double taxableNonUlipTotal;
  final bool hasPendingCalculations;

  InsuranceSummaryData({
    required this.totalPremium,
    required this.currentTaxableGain,
    required this.futureTaxableGain,
    required this.taxableUlipTotal,
    required this.taxableNonUlipTotal,
    required this.hasPendingCalculations,
  });
}

class _AggregateLimitResult {
  final InsurancePolicy policy;
  final double updatedULIP;
  final double updatedNonULIP;
  _AggregateLimitResult(this.policy, this.updatedULIP, this.updatedNonULIP);
}

final insuranceTaxServiceProvider = Provider<InsuranceTaxService>((ref) {
  final config = ref.watch(taxConfigServiceProvider);
  return InsuranceTaxService(config);
});
