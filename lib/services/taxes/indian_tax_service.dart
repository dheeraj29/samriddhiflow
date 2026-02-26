import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/taxes/tax_data.dart';
import '../../models/taxes/tax_data_models.dart';
import '../../models/taxes/tax_rules.dart';
import 'tax_config_service.dart';
import 'tax_strategy.dart';
import 'dart:math';

class IndianTaxService implements TaxStrategy {
  final TaxConfigService _configService;

  IndianTaxService(this._configService);

  @override // coverage:ignore-line
  String get countryCode => 'IN';

  @override // coverage:ignore-line
  double calculateLiability(TaxYearData data) {
    // coverage:ignore-start
    if (!_configService.isReady) return 0;
    final rules = _configService.getRulesForYear(data.year);
    final details = calculateDetailedLiability(data, rules);
    return details['totalTax'] ?? 0;
    // coverage:ignore-end
  }

  /// Calculates tax liability based ONLY on salary income (used for TDS estimation).
  // coverage:ignore-start
  double calculateSalaryOnlyLiability(TaxYearData data) {
    final rules = _configService.getRulesForYear(data.year);
    final salaryOnlyData = data.copyWith(
      houseProperties: [],
      businessIncomes: [],
      capitalGains: [],
      otherIncomes: [],
      cashGifts: [],
  // coverage:ignore-end
      agricultureIncome: 0,
      dividendIncome: const DividendIncome(),
    );
    final details = calculateDetailedLiability(salaryOnlyData, rules); // coverage:ignore-line
    return details['totalTax'] ?? 0; // coverage:ignore-line
  }

  Map<String, double> calculateDetailedLiability(
      TaxYearData data, TaxRules rules,
      {double? salaryIncomeOverride}) {
    // 1. Heads calculation
    double salaryGross = calculateSalaryGross(data, rules);
    double salaryExemptions = calculateSalaryExemptions(data, rules);
    double incomeSalary =
        salaryIncomeOverride ?? (salaryGross - salaryExemptions);

    double incomeHP = calculateHousePropertyIncome(data, rules);
    double incomeBusiness = calculateBusinessIncome(data, rules);

    final cgResults = calculateCapitalGains(data, rules);
    double incomeLTCGEquity = cgResults['LTCG_Equity']!;
    double incomeLTCGOther = cgResults['LTCG_Other']!;
    double incomeSTCG = cgResults['STCG']!;
    double incomeOther = calculateOtherSources(data, rules);

    double grossTotalIncome = salaryGross +
        incomeHP +
        incomeBusiness +
        incomeLTCGEquity +
        incomeLTCGOther +
        incomeSTCG +
        incomeOther;

    // 2. Deductions
    double deductions = data.salary.npsEmployer;
    if (rules.isStdDeductionSalaryEnabled) {
      deductions += rules.stdDeductionSalary;
    }
    double totalDisplayDeductions = deductions;
    if (salaryIncomeOverride == null) {}

    // 3. Tax Calculation
    final specialRateIncome = incomeLTCGEquity + incomeLTCGOther + incomeSTCG;
    double taxableHeadsSum =
        incomeSalary + incomeHP + incomeBusiness + incomeOther;
    double netTaxableNormalIncome =
        (taxableHeadsSum - deductions).clamp(0.0, double.infinity);

    double slabTax = _computeSlabTaxWithAgri(
        netTaxableNormalIncome, data.agricultureIncome, rules);
    double ltcgTax =
        _calculateLTCGTax(incomeLTCGEquity, incomeLTCGOther, rules);
    double stcgTax = _calculateSTCGTax(incomeSTCG, rules);
    double specialTax = ltcgTax + stcgTax;
    double taxBeforeCess = slabTax + specialTax;

    // Rebate & Marginal Relief
    double totalTaxableIncome = netTaxableNormalIncome + specialRateIncome;
    final rebateResult = _applyRebate(
        taxBeforeCess, slabTax, specialTax, totalTaxableIncome, rules);
    slabTax = rebateResult.slabTax;
    specialTax = rebateResult.specialTax;
    taxBeforeCess = rebateResult.taxBeforeCess;

    double cess =
        rules.isCessEnabled ? taxBeforeCess * (rules.cessRate / 100) : 0;
    double totalTax = taxBeforeCess + cess;

    return {
      'slabTax': slabTax,
      'specialTax': specialTax,
      'cess': cess,
      'totalTax': totalTax,
      'grossIncome': grossTotalIncome,
      'taxableIncome': totalTaxableIncome,
      'exemptions': salaryExemptions,
      'netTaxPayable': totalTax - (data.advanceTax + data.tds + data.tcs),
      'advanceTax': data.advanceTax,
      'tds': data.tds,
      'tcs': data.tcs,
      'totalDeductions': totalDisplayDeductions,
    };
  }

  double _computeSlabTaxWithAgri(
      double netTaxableNormalIncome, double agriIncome, TaxRules rules) {
    bool applyPartialIntegration = rules.isAgriIncomeEnabled &&
        agriIncome > rules.agricultureIncomeThreshold &&
        netTaxableNormalIncome > rules.agricultureBasicExemptionLimit;

    if (applyPartialIntegration) {
      double step1Base = netTaxableNormalIncome + agriIncome;
      double step2Base = rules.agricultureBasicExemptionLimit + agriIncome;
      return _calculateSlabTax(step1Base, rules) -
          _calculateSlabTax(step2Base, rules);
    }
    return _calculateSlabTax(netTaxableNormalIncome, rules);
  }

  ({double slabTax, double specialTax, double taxBeforeCess}) _applyRebate(
      double taxBeforeCess,
      double slabTax,
      double specialTax,
      double totalTaxableIncome,
      TaxRules rules) {
    if (!rules.isRebateEnabled) {
      return (
        slabTax: slabTax,
        specialTax: specialTax,
        taxBeforeCess: taxBeforeCess
      );
    }
    if (totalTaxableIncome <= rules.rebateLimit) {
      return (slabTax: 0, specialTax: 0, taxBeforeCess: 0);
    }
    if (rules.rebateLimit >= 700000 && taxBeforeCess > 0) {
      double excessIncome = totalTaxableIncome - rules.rebateLimit;
      if (taxBeforeCess > excessIncome) {
        double ratio = excessIncome / taxBeforeCess;
        return (
          slabTax: slabTax * ratio,
          specialTax: specialTax * ratio,
          taxBeforeCess: excessIncome
        );
      }
    }
    return (
      slabTax: slabTax,
      specialTax: specialTax,
      taxBeforeCess: taxBeforeCess
    );
  }

  double calculateSalaryIncome(TaxYearData data, TaxRules rules) {
    double gross = calculateSalaryGross(data, rules);
    double exemptions = calculateSalaryExemptions(data, rules);
    return max(0, gross - exemptions);
  }

  double calculateSalaryGross(TaxYearData data, TaxRules rules) {
    double totalGross = 0;
    if (data.salary.history.isNotEmpty) {
      for (int i = 0; i < 12; i++) {
        int month = (rules.financialYearStartMonth + i - 1) % 12 + 1;
        final s = _getStructureForMonth(data, month);
        if (s != null) {
          totalGross += s.calculateContribution(
              month, rules.financialYearStartMonth,
              taxableOnly: false);
        }
      }
    } else {
      totalGross = data.salary.grossSalary;
    }

    if (rules.isGiftFromEmployerEnabled) {
      totalGross += data.salary.giftsFromEmployer;
    }

    totalGross += _computeIndependentAllowanceGross(data);
    return totalGross;
  }

  double _computeIndependentAllowanceGross(TaxYearData data) {
    double total = 0;
    for (final a in data.salary.independentAllowances) {
      for (int m = 1; m <= 12; m++) {
        if (SalaryStructure.isPayoutMonth(
            m, a.frequency, a.startMonth, a.customMonths)) {
          total += a.isPartial
              ? (a.partialAmounts[m] ?? a.payoutAmount)
              : a.payoutAmount;
        }
      }
    }
    return total;
  }

  double calculateSalaryExemptions(TaxYearData data, TaxRules rules) {
    double totalExemptions = 0;
    double gifts = data.salary.giftsFromEmployer;

    // 1. Retirement Exemptions
    if (rules.isRetirementExemptionEnabled) {
      totalExemptions +=
          min(data.salary.leaveEncashment, rules.limitLeaveEncashment);
      totalExemptions += min(data.salary.gratuity, rules.limitGratuity);
    }

    // 2. Gift Exemption
    if (rules.isGiftFromEmployerEnabled && gifts > 0) {
      totalExemptions += min(gifts, rules.giftFromEmployerExemptionLimit);
    }

    // 3. Structure-level Non-Taxable components
    if (data.salary.history.isNotEmpty) {
      for (int i = 0; i < 12; i++) {
        int month = (rules.financialYearStartMonth + i - 1) % 12 + 1;
        final s = _getStructureForMonth(data, month);
        if (s != null) {
          double gross = s.calculateContribution(
              month, rules.financialYearStartMonth,
              taxableOnly: false);
          double taxable = s.calculateContribution(
              month, rules.financialYearStartMonth,
              taxableOnly: true);
          totalExemptions += max(0, gross - taxable);
        }
      }
    }

    // 4. Independent Non-Taxable Allowances (Removed)
    // All independent allowances are now inherently taxable

    return totalExemptions;
  }

  double calculateHousePropertyIncome(TaxYearData data, TaxRules rules) {
    double totalNet = 0;
    for (var hp in data.houseProperties) {
      if (hp.isSelfOccupied) {
        double interest = hp.interestOnLoan;
        if (rules.isHPMaxInterestEnabled) {
          interest = min(interest, rules.maxHPDeductionLimit);
        }
        totalNet += -interest;
        continue;
      }

      double nav = hp.rentReceived - hp.municipalTaxes;
      double stdDed = rules.isStdDeductionHPEnabled
          ? (nav * rules.standardDeductionRateHP / 100)
          : 0;
      double income = nav - stdDed - hp.interestOnLoan;
      totalNet += income;
    }
    return totalNet;
  }

  double calculateBusinessIncome(TaxYearData data, TaxRules rules) {
    double total = 0;
    for (var biz in data.businessIncomes) {
      // coverage:ignore-start
      if (biz.type == BusinessType.section44AD && rules.is44ADEnabled) {
        total += biz.presumptiveIncome;
      } else if (biz.type == BusinessType.section44ADA &&
          rules.is44ADAEnabled) {
        total += biz.presumptiveIncome;
      // coverage:ignore-end
      } else {
        total += biz.netIncome; // coverage:ignore-line
      }
    }
    return total;
  }

  Map<String, double> calculateCapitalGains(TaxYearData data, TaxRules rules) {
    double ltcgEquity = 0;
    double ltcgOther = 0;
    double stcg = 0;

    for (var entry in data.capitalGains) {
      double gain = entry.capitalGainAmount;
      if (rules.isCGReinvestmentEnabled) {
        gain = max(0, gain - entry.reinvestedAmount);
      }

      if (entry.isLTCG) {
        if (entry.matchAssetType == AssetType.equityShares) {
          ltcgEquity += gain;
        } else {
          ltcgOther += gain;
        }
      } else {
        stcg += gain;
      }
    }

    return {
      'LTCG_Equity': ltcgEquity,
      'LTCG_Other': ltcgOther,
      'STCG': stcg,
    };
  }

  double calculateOtherSources(TaxYearData data, TaxRules rules) {
    double other = 0;
    for (var o in data.otherIncomes) {
      other += o.amount; // coverage:ignore-line
    }
    other += data.dividendIncome.grossDividend;

    double aggregateGifts = 0;
    for (var gift in data.cashGifts) {
      if (gift.subtype.toLowerCase() == 'marriage' ||
          gift.subtype.toLowerCase() == 'relative') {
        continue;
      }
      aggregateGifts += gift.amount;
    }

    double taxableGifts =
        aggregateGifts <= rules.cashGiftExemptionLimit ? 0 : aggregateGifts;
    return other + taxableGifts;
  }

  double _calculateSlabTax(double income, TaxRules rules) {
    double tax = 0;
    double previousLimit = 0;

    for (final slab in rules.slabs) {
      if (income <= previousLimit) break;

      final isUnlimited = slab.isUnlimited || slab.upto == double.infinity;
      double checkLimit = isUnlimited ? double.maxFinite : slab.upto;

      double taxableInSlab = income > checkLimit
          ? checkLimit - previousLimit
          : income - previousLimit;

      if (taxableInSlab > 0) {
        tax += taxableInSlab * (slab.rate / 100);
      }
      previousLimit = checkLimit;
      if (isUnlimited) break;
    }
    return tax;
  }

  double _calculateLTCGTax(
      double equityGain, double otherGain, TaxRules rules) {
    if (!rules.isCGRatesEnabled) return 0;

    double exemptEquity =
        rules.isLTCGExemption112AEnabled ? rules.stdExemption112A : 0;
    double taxableEquity =
        (equityGain - exemptEquity).clamp(0, double.infinity);
    double taxEquity = taxableEquity * (rules.ltcgRateEquity / 100);

    double taxOther = otherGain * (rules.ltcgRateEquity / 100);
    return taxEquity + taxOther;
  }

  double _calculateSTCGTax(double gain, TaxRules rules) {
    if (!rules.isCGRatesEnabled) return 0;
    return gain * (rules.stcgRate / 100);
  }

  @override // coverage:ignore-line
  Map<String, double> getDeductionSuggestions(TaxYearData data) => {}; // coverage:ignore-line

  @override // coverage:ignore-line
  String suggestITR(TaxYearData data) {
    // coverage:ignore-start
    if (data.businessIncomes.isNotEmpty) return 'ITR-3 or ITR-4';
    if (data.capitalGains.any((e) => e.capitalGainAmount > 0)) return 'ITR-2';
    if (data.houseProperties.length > 1) return 'ITR-2';
    // coverage:ignore-end
    return 'ITR-1 (Sahaj)';
  }

  @override // coverage:ignore-line
  bool isInsuranceMaturityTaxable(
      double annualPremium, double sumAssured, DateTime issueDate) {
    if (issueDate.isBefore(DateTime(2012, 4, 1))) { // coverage:ignore-line
      return annualPremium > (0.20 * sumAssured); // coverage:ignore-line
    } else {
      return annualPremium > (0.10 * sumAssured); // coverage:ignore-line
    }
  }

  Map<int, Map<String, double>> calculateMonthlySalaryBreakdown(
      TaxYearData data, TaxRules rules) {
    final Map<int, Map<String, double>> breakdown = {};
    double accumulatedTaxableTotal = 0;
    final fyMonths = [4, 5, 6, 7, 8, 9, 10, 11, 12, 1, 2, 3];

    final salaryOnlyData = data.copyWith(
      houseProperties: [],
      businessIncomes: [],
      capitalGains: [],
      otherIncomes: [],
      dividendIncome: const DividendIncome(),
      cashGifts: [],
      agricultureIncome: 0,
    );

    final exemptionPools = _computeExemptionPools(salaryOnlyData, rules);

    for (int i = 0; i < fyMonths.length; i++) {
      int m = fyMonths[i];
      final s = _getStructureForMonth(salaryOnlyData, m);

      final monthGross = _computeMonthGross(salaryOnlyData, s, m, rules);
      accumulatedTaxableTotal += monthGross.taxable;

      double currentIrregular =
          _computeCurrentIrregular(salaryOnlyData, s, m, rules);

      final projected = _projectFutureTaxable(
        salaryOnlyData,
        s,
        fyMonths,
        i,
        accumulatedTaxableTotal,
        currentIrregular,
        rules,
      );

      double annualTaxableFull =
          max(0, projected.full - exemptionPools.retirementExemptions);
      double annualTaxableWithoutCurrentBonus = max(
          0,
          projected.full -
              currentIrregular -
              exemptionPools.retirementExemptions);
      double annualTaxableStable =
          max(0, projected.stable - exemptionPools.retirementExemptions);
      double annualTaxableWithPlanning =
          max(0, annualTaxableFull - exemptionPools.plannedExemptions);

      final resultsFull = calculateDetailedLiability(salaryOnlyData, rules,
          salaryIncomeOverride: annualTaxableFull);
      final resultsWithoutCurrentBonus = calculateDetailedLiability(
          salaryOnlyData, rules,
          salaryIncomeOverride: annualTaxableWithoutCurrentBonus);
      final resultsStable = calculateDetailedLiability(salaryOnlyData, rules,
          salaryIncomeOverride: annualTaxableStable);
      final resultsWithPlanning = calculateDetailedLiability(
          salaryOnlyData, rules,
          salaryIncomeOverride: annualTaxableWithPlanning);

      double totalTaxFull = resultsFull['totalTax'] ?? 0;
      double totalTaxWithoutBonus = resultsWithoutCurrentBonus['totalTax'] ?? 0;
      double totalTaxStable = resultsStable['totalTax'] ?? 0;
      double totalTaxWithPlanning = resultsWithPlanning['totalTax'] ?? 0;

      double marginalBonusTax = max(0, totalTaxFull - totalTaxWithoutBonus);
      double regularMonthlyTax = totalTaxStable / 12;
      double monthlyTax = regularMonthlyTax + marginalBonusTax;
      double annualSavingsForecast =
          max(0, totalTaxFull - totalTaxWithPlanning);

      double totalDeductions = _computeMonthlyDeductions(salaryOnlyData, s, m);
      double monthlyExemption = _computeMonthlyExemption(
          salaryOnlyData, s, m, rules, exemptionPools.plannedExemptions);

      breakdown[m] = {
        'gross': monthGross.gross,
        'tax': monthlyTax,
        'deductions': totalDeductions,
        'takeHome': monthGross.gross - monthlyTax - totalDeductions,
        'taxSavingsForecast': annualSavingsForecast / 12,
        'extras': monthGross.gross -
            (s?.calculateRegularContribution(
                    m, rules.financialYearStartMonth) ??
                0),
        'exemption': monthlyExemption,
        'standardDeduction': rules.isStdDeductionSalaryEnabled
            ? rules.stdDeductionSalary / 12
            : 0,
        'npsDeduction': salaryOnlyData.salary.npsEmployer / 12,
      };
    }
    return breakdown;
  }

  ({double gross, double taxable}) _computeMonthGross(
      TaxYearData data, SalaryStructure? s, int m, TaxRules rules) {
    double gross = 0;
    double taxable = 0;

    if (s != null) {
      gross = s.calculateContribution(m, rules.financialYearStartMonth);
      taxable = s.calculateContribution(m, rules.financialYearStartMonth,
          taxableOnly: true);
    }

    for (final a in data.salary.independentAllowances) {
      if (SalaryStructure.isPayoutMonth(
          m, a.frequency, a.startMonth, a.customMonths)) {
        double amt = a.isPartial
            ? (a.partialAmounts[m] ?? a.payoutAmount)
            : a.payoutAmount;
        gross += amt;
        taxable += amt;
      }
    }

    // Add Gifts from Employer in March
    if (m == 3) {
      gross += data.salary.giftsFromEmployer;
    }

    return (gross: gross, taxable: taxable);
  }

  double _computeCurrentIrregular(
      TaxYearData data, SalaryStructure? s, int m, TaxRules rules) {
    double irregular = 0;
    if (s != null) {
      irregular += s.calculateIrregularContribution(
          m, rules.financialYearStartMonth,
          taxableOnly: true);
    }
    for (final a in data.salary.independentAllowances) {
      if (a.frequency != PayoutFrequency.monthly &&
          SalaryStructure.isPayoutMonth(
              m, a.frequency, a.startMonth, a.customMonths)) {
        irregular += a.isPartial
            ? (a.partialAmounts[m] ?? a.payoutAmount) // coverage:ignore-line
            : a.payoutAmount;
      }
    }
    return irregular;
  }

  ({double full, double stable}) _projectFutureTaxable(
    TaxYearData data,
    SalaryStructure? currentStructure,
    List<int> fyMonths,
    int currentIndex,
    double accumulatedTaxable,
    double currentIrregular,
    TaxRules rules,
  ) {
    double projFull = accumulatedTaxable;
    double projStable = accumulatedTaxable - currentIrregular;

    for (int j = currentIndex + 1; j < fyMonths.length; j++) {
      int futureMonth = fyMonths[j];
      _addFutureMonthProjection(
          data, currentStructure, futureMonth, rules, projFull, projStable);
      if (currentStructure != null) {
        projFull += currentStructure.calculateContribution(
            futureMonth, rules.financialYearStartMonth,
            taxableOnly: true);
        projStable += currentStructure.calculateRegularContribution(
            futureMonth, rules.financialYearStartMonth,
            taxableOnly: true);
      }

      for (final a in data.salary.independentAllowances) {
        if (!SalaryStructure.isPayoutMonth(
            futureMonth, a.frequency, a.startMonth, a.customMonths)) {
          continue;
        }
        double amt = a.isPartial
            ? (a.partialAmounts[futureMonth] ?? a.payoutAmount)
            : a.payoutAmount;
        projFull += amt;
        if (a.frequency == PayoutFrequency.monthly) projStable += amt;
      }
    }
    return (full: projFull, stable: projStable);
  }

  void _addFutureMonthProjection(TaxYearData data, SalaryStructure? s,
      int month, TaxRules rules, double full, double stable) {
    // Placeholder for future extensibility
  }

  ({double retirementExemptions, double plannedExemptions})
      _computeExemptionPools(TaxYearData data, TaxRules rules) {
    double retirement = 0;
    if (rules.isRetirementExemptionEnabled) {
      retirement +=
          min(data.salary.leaveEncashment, rules.limitLeaveEncashment);
      retirement += min(data.salary.gratuity, rules.limitGratuity);
    }

    double planned = 0;
    for (final ex in data.salary.independentExemptions) {
      planned += ex.amount;
    }

    return (retirementExemptions: retirement, plannedExemptions: planned);
  }

  double _computeMonthlyDeductions(
      TaxYearData data, SalaryStructure? s, int m) {
    double total = 0;
    if (s != null) {
      total += s.monthlyEmployeePF;
    }
    for (final a in data.salary.independentDeductions) {
      if (SalaryStructure.isPayoutMonth(
          m, a.frequency, a.startMonth, a.customMonths)) {
        total += a.isPartial
            ? (a.partialAmounts[m] ?? a.payoutAmount)
            : a.payoutAmount;
      }
    }
    return total;
  }

  double _computeMonthlyExemption(TaxYearData data, SalaryStructure? s, int m,
      TaxRules rules, double totalPlannedExemptions) {
    double exemption = 0;
    if (s != null) {
      double gross = s.calculateContribution(m, rules.financialYearStartMonth,
          taxableOnly: false);
      double taxable = s.calculateContribution(m, rules.financialYearStartMonth,
          taxableOnly: true);
      exemption += max(0, gross - taxable);
    }
    exemption += totalPlannedExemptions / 12;
    return exemption;
  }

  SalaryStructure? _getStructureForMonth(TaxYearData data, int month) {
    if (data.salary.history.isEmpty) return null;
    final sorted = List<SalaryStructure>.from(data.salary.history)
      ..sort((a, b) => b.effectiveDate.compareTo(a.effectiveDate));
    int yr = (month >= 4) ? data.year : data.year + 1;
    final targetDate = DateTime(yr, month, 28);
    for (final s in sorted) {
      if (s.effectiveDate.isBefore(targetDate) ||
          s.effectiveDate.isAtSameMomentAs(targetDate)) {
        return s;
      }
    }
    return sorted.last; // coverage:ignore-line
  }
}

// coverage:ignore-start
final indianTaxServiceProvider = Provider<IndianTaxService>((ref) {
  final config = ref.watch(taxConfigServiceProvider);
  return IndianTaxService(config);
// coverage:ignore-end
});
