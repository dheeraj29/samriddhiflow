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

  @override
  String get countryCode => 'IN';

  @override
  double calculateLiability(TaxYearData data) {
    if (!_configService.isReady) return 0;
    final rules = _configService.getRulesForYear(data.year);
    final details = calculateDetailedLiability(data, rules);
    return details['totalTax'] ?? 0;
  }

  /// Calculates tax liability based ONLY on salary income (used for TDS estimation).
  double calculateSalaryOnlyLiability(TaxYearData data) {
    final rules = _configService.getRulesForYear(data.year);
    final salaryOnlyData = data.copyWith(
      houseProperties: [],
      businessIncomes: [],
      capitalGains: [],
      otherIncomes: [],
      cashGifts: [],
      agricultureIncome: 0,
      dividendIncome: const DividendIncome(),
    );
    final details = calculateDetailedLiability(salaryOnlyData, rules);
    return details['totalTax'] ?? 0;
  }

  Map<String, double> calculateDetailedLiability(
      TaxYearData data, TaxRules rules,
      {double? salaryIncomeOverride}) {
    // 1. Heads calculation
    double salaryGross = calculateSalaryGross(data, rules);
    double salaryExemptions = calculateSalaryExemptions(data, rules);

    // netSalaryIncome is the head used for tax computation
    // Note: If override is provided, we assume it's the Salary Head (Gross - Exemptions - Custom/Ind Deductions)
    // OR just (Gross - Exemptions) depending on the caller.
    // For breakdown catch-up: it provides (Gross - Exemptions - Monthly Custom/Ind Deductions).
    double incomeSalary =
        salaryIncomeOverride ?? (salaryGross - salaryExemptions);

    double incomeHP = calculateHousePropertyIncome(data, rules);
    double incomeBusiness = calculateBusinessIncome(data, rules);

    final cgResults = calculateCapitalGains(data, rules);
    double incomeLTCGEquity = cgResults['LTCG_Equity']!;
    double incomeLTCGOther = cgResults['LTCG_Other']!;
    double incomeSTCG = cgResults['STCG']!;

    double incomeOther = calculateOtherSources(data, rules);

    // Dashboard Gross
    double grossTotalIncome = salaryGross +
        incomeHP +
        incomeBusiness +
        incomeLTCGEquity +
        incomeLTCGOther +
        incomeSTCG +
        incomeOther;

    // 2. Unified Deductions Collection
    double deductions = data.salary.npsEmployer; // NPS 80CCD(2)
    if (rules.isStdDeductionSalaryEnabled) {
      deductions += rules.stdDeductionSalary;
    }

    double totalDisplayDeductions = deductions;

    // ONLY aggregate salary deductions if we are NOT overriding with a pre-calculated head
    if (salaryIncomeOverride == null) {}

    // 3. Tax Calculation
    final specialRateIncome = incomeLTCGEquity + incomeLTCGOther + incomeSTCG;
    double taxableHeadsSum =
        incomeSalary + incomeHP + incomeBusiness + incomeOther;
    double netTaxableNormalIncome =
        (taxableHeadsSum - deductions).clamp(0.0, double.infinity);

    double slabTax = 0;

    // Partial Integration for Agriculture Income
    bool applyPartialIntegration = rules.isAgriIncomeEnabled &&
        data.agricultureIncome > rules.agricultureIncomeThreshold &&
        netTaxableNormalIncome > rules.agricultureBasicExemptionLimit;

    if (applyPartialIntegration) {
      double step1Base = netTaxableNormalIncome + data.agricultureIncome;
      double step2Base =
          rules.agricultureBasicExemptionLimit + data.agricultureIncome;
      slabTax = _calculateSlabTax(step1Base, rules) -
          _calculateSlabTax(step2Base, rules);
    } else {
      slabTax = _calculateSlabTax(netTaxableNormalIncome, rules);
    }

    double ltcgTax =
        _calculateLTCGTax(incomeLTCGEquity, incomeLTCGOther, rules);
    double stcgTax = _calculateSTCGTax(incomeSTCG, rules);
    double specialTax = ltcgTax + stcgTax;

    double taxBeforeCess = slabTax + specialTax;

    // Rebate & Marginal Relief
    double totalTaxableIncome = netTaxableNormalIncome + specialRateIncome;
    if (rules.isRebateEnabled) {
      if (totalTaxableIncome <= rules.rebateLimit) {
        slabTax = 0;
        specialTax = 0;
        taxBeforeCess = 0;
      } else if (rules.rebateLimit >= 700000) {
        // Marginal Relief logic (New Regime)
        double excessIncome = totalTaxableIncome - rules.rebateLimit;
        if (taxBeforeCess > excessIncome) {
          if (taxBeforeCess > 0) {
            double ratio = excessIncome / taxBeforeCess;
            slabTax *= ratio;
            specialTax *= ratio;
          }
          taxBeforeCess = excessIncome;
        }
      }
    }

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

    // Gifts from Employer (only include if feature is enabled)
    if (rules.isGiftFromEmployerEnabled) {
      totalGross += data.salary.giftsFromEmployer;
    }

    // Add Independent Allowances (All)
    for (final a in data.salary.independentAllowances) {
      for (int m = 1; m <= 12; m++) {
        if (SalaryStructure.isPayoutMonth(
            m, a.frequency, a.startMonth, a.customMonths)) {
          totalGross += a.isPartial
              ? (a.partialAmounts[m] ?? a.payoutAmount)
              : a.payoutAmount;
        }
      }
    }
    return totalGross;
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
      if (biz.type == BusinessType.section44AD && rules.is44ADEnabled) {
        total += biz.presumptiveIncome;
      } else if (biz.type == BusinessType.section44ADA &&
          rules.is44ADAEnabled) {
        total += biz.presumptiveIncome;
      } else {
        total += biz.netIncome;
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
      other += o.amount;
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

  @override
  Map<String, double> getDeductionSuggestions(TaxYearData data) => {};

  @override
  String suggestITR(TaxYearData data) {
    if (data.businessIncomes.isNotEmpty) return 'ITR-3 or ITR-4';
    if (data.capitalGains.any((e) => e.capitalGainAmount > 0)) return 'ITR-2';
    if (data.houseProperties.length > 1) return 'ITR-2';
    return 'ITR-1 (Sahaj)';
  }

  @override
  bool isInsuranceMaturityTaxable(
      double annualPremium, double sumAssured, DateTime issueDate) {
    if (issueDate.isBefore(DateTime(2012, 4, 1))) {
      return annualPremium > (0.20 * sumAssured);
    } else {
      return annualPremium > (0.10 * sumAssured);
    }
  }

  Map<int, Map<String, double>> calculateMonthlySalaryBreakdown(
      TaxYearData data, TaxRules rules) {
    final Map<int, Map<String, double>> breakdown = {};

    double accumulatedTaxableTotal = 0;
    final fyMonths = [4, 5, 6, 7, 8, 9, 10, 11, 12, 1, 2, 3];

    // Create an isolated Salary data set to ensure TDS only reflects Salary Income
    final salaryOnlyData = data.copyWith(
      houseProperties: [],
      businessIncomes: [],
      capitalGains: [],
      otherIncomes: [],
      dividendIncome: const DividendIncome(),
      cashGifts: [],
      agricultureIncome: 0,
    );

    for (int i = 0; i < fyMonths.length; i++) {
      int m = fyMonths[i];
      final s = _getStructureForMonth(salaryOnlyData, m);

      double monthlyGrossActual = 0;
      double monthlyTaxableActual = 0;

      if (s != null) {
        monthlyGrossActual =
            s.calculateContribution(m, rules.financialYearStartMonth);
        monthlyTaxableActual = s.calculateContribution(
            m, rules.financialYearStartMonth,
            taxableOnly: true);
      }

      // Add Independent Allowances
      for (final a in salaryOnlyData.salary.independentAllowances) {
        if (SalaryStructure.isPayoutMonth(
            m, a.frequency, a.startMonth, a.customMonths)) {
          double amt = a.isPartial
              ? (a.partialAmounts[m] ?? a.payoutAmount)
              : a.payoutAmount;
          monthlyGrossActual += amt;
          monthlyTaxableActual += amt;
        }
      }

      // Add Gifts from Employer (Assign to March/Month 3 for breakdown visibility)
      if (m == 3) {
        monthlyGrossActual += salaryOnlyData.salary.giftsFromEmployer;
        // Gift taxable part is usually handled annually, but for month-to-month,
        // we follow the same Logic as calculateSalaryExemptions later.
        // For simplicity in the 'gross' field, we add the full gift.
      }

      accumulatedTaxableTotal += monthlyTaxableActual;

      // Current Irregular (for spiking logic)
      double currentIrregular = 0;
      if (s != null) {
        currentIrregular += s.calculateIrregularContribution(
            m, rules.financialYearStartMonth,
            taxableOnly: true);
      }
      for (final a in salaryOnlyData.salary.independentAllowances) {
        if (a.frequency != PayoutFrequency.monthly &&
            SalaryStructure.isPayoutMonth(
                m, a.frequency, a.startMonth, a.customMonths)) {
          currentIrregular += a.isPartial
              ? (a.partialAmounts[m] ?? a.payoutAmount)
              : a.payoutAmount;
        }
      }

      double projectedAnnualTaxableFull = accumulatedTaxableTotal;
      double projectedAnnualTaxableStable =
          accumulatedTaxableTotal - currentIrregular;

      // 3. Project for FUTURE Months (Aggregation)
      for (int j = i + 1; j < fyMonths.length; j++) {
        int futureMonth = fyMonths[j];
        final structure =
            s; // Use current structure for future projection (No Backward Leak)

        // Structure Level Taxable Components
        if (structure != null) {
          projectedAnnualTaxableFull += structure.calculateContribution(
              futureMonth, rules.financialYearStartMonth,
              taxableOnly: true);
          projectedAnnualTaxableStable +=
              structure.calculateRegularContribution(
                  futureMonth, rules.financialYearStartMonth,
                  taxableOnly: true);
        }

        // Independent Allowances (Future)
        for (final a in salaryOnlyData.salary.independentAllowances) {
          if (SalaryStructure.isPayoutMonth(
              futureMonth, a.frequency, a.startMonth, a.customMonths)) {
            double amt = a.isPartial
                ? (a.partialAmounts[futureMonth] ?? a.payoutAmount)
                : a.payoutAmount;
            projectedAnnualTaxableFull += amt;
            if (a.frequency == PayoutFrequency.monthly) {
              projectedAnnualTaxableStable += amt;
            }
          }
        }
      }

      // Note: Independent Exemptions removed from employer projected pool
      // per USER request (Refactor Phase 4).
      // They are now treated as "Total Gross Reduction" for the forecast.
      double totalIndExemptionsForEmployerPool = 0;
      if (rules.isRetirementExemptionEnabled) {
        totalIndExemptionsForEmployerPool += min(
            salaryOnlyData.salary.leaveEncashment, rules.limitLeaveEncashment);
        totalIndExemptionsForEmployerPool +=
            min(salaryOnlyData.salary.gratuity, rules.limitGratuity);
      }

      double totalUserPlannedExemptions = 0;
      for (final ex in salaryOnlyData.salary.independentExemptions) {
        totalUserPlannedExemptions += ex.amount;
      }

      double annualTaxableFull = max(
          0, projectedAnnualTaxableFull - totalIndExemptionsForEmployerPool);
      double annualTaxableWithoutCurrentBonus = max(
          0,
          projectedAnnualTaxableFull -
              currentIrregular -
              totalIndExemptionsForEmployerPool);
      double annualTaxableStable = max(
          0, projectedAnnualTaxableStable - totalIndExemptionsForEmployerPool);

      // Forecasting potential savings with planned exemptions
      double annualTaxableWithPlanning =
          max(0, annualTaxableFull - totalUserPlannedExemptions);

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
      double totalTaxWithoutCurrentBonus =
          resultsWithoutCurrentBonus['totalTax'] ?? 0;
      double totalTaxStable = resultsStable['totalTax'] ?? 0;
      double totalTaxWithPlanning = resultsWithPlanning['totalTax'] ?? 0;

      double marginalBonusTax =
          max(0, totalTaxFull - totalTaxWithoutCurrentBonus);
      double regularMonthlyTax = (totalTaxStable / 12);

      double monthlyTax = regularMonthlyTax + marginalBonusTax;

      // Annual Savings Forecast (Smoothed over 12 months)
      double annualSavingsForecast =
          max(0, totalTaxFull - totalTaxWithPlanning);

      // For UI breakdown, ensure deductions shows out-of-pocket payroll items
      double totalDeductions = 0;
      if (s != null) {
        totalDeductions += s.monthlyEmployeePF;
      }

      for (final a in salaryOnlyData.salary.independentDeductions) {
        if (SalaryStructure.isPayoutMonth(
            m, a.frequency, a.startMonth, a.customMonths)) {
          totalDeductions += a.isPartial
              ? (a.partialAmounts[m] ?? a.payoutAmount)
              : a.payoutAmount;
        }
      }

      double monthlyNpsBenefit = salaryOnlyData.salary.npsEmployer / 12;

      double monthlyExemption = 0;
      // 1. Structure-level non-taxable (Exemptions)
      if (s != null) {
        double gross = s.calculateContribution(m, rules.financialYearStartMonth,
            taxableOnly: false);
        double taxable = s.calculateContribution(
            m, rules.financialYearStartMonth,
            taxableOnly: true);
        monthlyExemption += max(0, gross - taxable);
      }

      // 2. Independent Exemptions (Forecasted savings only, not monthly 'exemption' credit)
      // They are now smoothed over 12 months for the 'exemption' display field
      monthlyExemption += totalUserPlannedExemptions / 12;

      breakdown[m] = {
        'gross': monthlyGrossActual,
        'tax': monthlyTax,
        'deductions': totalDeductions,
        'takeHome': monthlyGrossActual - monthlyTax - totalDeductions,
        'taxSavingsForecast': annualSavingsForecast / 12, // Potential savings
        'extras': monthlyGrossActual -
            (s?.calculateRegularContribution(
                    m, rules.financialYearStartMonth) ??
                0),
        'exemption': monthlyExemption,
        'standardDeduction': rules.isStdDeductionSalaryEnabled
            ? rules.stdDeductionSalary / 12
            : 0,
        'npsDeduction': monthlyNpsBenefit,
      };
    }
    return breakdown;
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
    return sorted.last;
  }
}

final indianTaxServiceProvider = Provider<IndianTaxService>((ref) {
  final config = ref.watch(taxConfigServiceProvider);
  return IndianTaxService(config);
});
