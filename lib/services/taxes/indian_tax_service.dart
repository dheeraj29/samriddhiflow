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
    final rules = _configService.getRulesForYear(data.year);
    final details = calculateDetailedLiability(data, rules);
    return details['totalTax'] ?? 0;
  }

  Map<String, double> calculateDetailedLiability(
      TaxYearData data, TaxRules rules) {
    // Heads
    double incomeSalary = calculateSalaryIncome(data, rules);
    double incomeHP = calculateHousePropertyIncome(data, rules);
    double incomeBusiness = calculateBusinessIncome(data, rules);

    // CG with granular rules checks
    final cgResults = calculateCapitalGains(data, rules);
    double incomeLTCGEquity = cgResults['LTCG_Equity']!;
    double incomeLTCGOther = cgResults['LTCG_Other']!;
    double incomeSTCG = cgResults['STCG']!;

    double incomeOther = calculateOtherSources(data, rules);

    double grossTotalIncome = incomeSalary +
        incomeHP +
        incomeBusiness +
        incomeLTCGEquity +
        incomeLTCGOther +
        incomeSTCG +
        incomeOther;

    // Deductions (Chapter VI-A)
    double deductions = data.salary.npsEmployer; // NPS is 80CCD(2)

    // Calculate "Total Deductions" for Display (Std Ded + Exemptions + NPS)
    double exemptLeave =
        min(data.salary.leaveEncashment, rules.limitLeaveEncashment);
    double exemptGratuity = min(data.salary.gratuity, rules.limitGratuity);
    double stdDed =
        (data.salary.grossSalary > 0 && rules.isStdDeductionSalaryEnabled)
            ? rules.stdDeductionSalary
            : 0;

    // Ensure stdDed doesn't exceed salary? `calculateSalaryIncome` does text: (net - std).
    // For display, we just show the flat amount usually, or the utilized amount?
    // "Deduction" usually means what was reduced.
    // If Salary is 50k and StdDed is 75k, taxable is 0. Effective ded is 50k.
    // But usually people want to see the Standard Deduction amount (75k).
    // Let's use the rule amount for simplicity unless salary is 0.

    double totalDisplayDeductions =
        stdDed + deductions + exemptLeave + exemptGratuity;

    final specialRateIncome = incomeLTCGEquity + incomeLTCGOther + incomeSTCG;
    final normalIncome = rules.isCGRatesEnabled
        ? max(0, grossTotalIncome - specialRateIncome)
        : grossTotalIncome;
    final netTaxableNormalIncome =
        (normalIncome - deductions).clamp(0.0, double.infinity);

    // Tax
    double slabTax = 0;

    // Partial Integration for Agriculture Income
    // Condition: Agri Income > Threshold AND Non-Agri Income (Net Taxable) > Basic Exemption
    bool applyPartialIntegration = rules.isAgriIncomeEnabled &&
        data.agricultureIncome > rules.agricultureIncomeThreshold &&
        netTaxableNormalIncome > rules.agricultureBasicExemptionLimit;

    if (applyPartialIntegration) {
      double step1Base = netTaxableNormalIncome + data.agricultureIncome;
      double step2Base =
          rules.agricultureBasicExemptionLimit + data.agricultureIncome;

      double splitTax1 = _calculateSlabTax(step1Base, rules);
      double splitTax2 = _calculateSlabTax(step2Base, rules);

      slabTax = splitTax1 - splitTax2;
    } else {
      slabTax = _calculateSlabTax(netTaxableNormalIncome, rules);
    }

    double ltcgTax =
        _calculateLTCGTax(incomeLTCGEquity, incomeLTCGOther, rules);
    double stcgTax = _calculateSTCGTax(incomeSTCG, rules);
    double specialTax = ltcgTax + stcgTax;

    double taxBeforeCess = slabTax + specialTax;

    // Rebate u/s 87A
    double totalTaxableIncome = netTaxableNormalIncome + specialRateIncome;
    if (rules.isRebateEnabled && totalTaxableIncome <= rules.rebateLimit) {
      slabTax = 0;
      specialTax = 0;
      taxBeforeCess = 0;
    }

    double cess =
        rules.isCessEnabled ? taxBeforeCess * (rules.cessRate / 100) : 0;
    double totalTax = taxBeforeCess + cess;

    // Net Payable
    double prepaidTaxes = data.advanceTax + data.tds + data.tcs;
    double netTaxPayable = totalTax - prepaidTaxes;

    return {
      'slabTax': slabTax,
      'specialTax': specialTax,
      'cess': cess,
      'totalTax': totalTax,
      'grossIncome': grossTotalIncome,
      'taxableIncome': totalTaxableIncome,
      'netTaxPayable': netTaxPayable,
      'advanceTax': data.advanceTax,
      'tds': data.tds,
      'tcs': data.tcs,
      'totalDeductions': totalDisplayDeductions,
    };
  }

  double calculateSalaryIncome(TaxYearData data, TaxRules rules) {
    double gross = data.salary.grossSalary;
    if (gross == 0) return 0;

    double exemptLeave = rules.isRetirementExemptionEnabled
        ? min(data.salary.leaveEncashment, rules.limitLeaveEncashment)
        : 0;
    double exemptGratuity = rules.isRetirementExemptionEnabled
        ? min(data.salary.gratuity, rules.limitGratuity)
        : 0;

    double netSalary = gross - exemptLeave - exemptGratuity;
    double stdDed =
        rules.isStdDeductionSalaryEnabled ? rules.stdDeductionSalary : 0;
    return (netSalary - stdDed).clamp(0, double.infinity);
  }

  double calculateHousePropertyIncome(TaxYearData data, TaxRules rules) {
    double totalNet = 0;
    for (var hp in data.houseProperties) {
      if (hp.isSelfOccupied) {
        double interest = hp.interestOnLoan;
        if (rules.isHPMaxInterestEnabled) {
          interest = min(interest, rules.maxHPDeductionLimit);
        }
        totalNet += -interest; // Loss from self-occupied property
        continue;
      }

      // Allowable Deduction Cap Check
      double stdDedRate =
          rules.isStdDeductionHPEnabled ? rules.standardDeductionRateHP : 0;
      double interest = hp.interestOnLoan;

      if (rules.isHPMaxInterestEnabled) {
        interest = min(interest, rules.maxHPDeductionLimit);
      }

      double nav = hp.rentReceived - hp.municipalTaxes;
      double stdDed = nav * (stdDedRate / 100);

      totalNet += max(0, nav - stdDed - interest);
    }
    return totalNet;
  }

  double calculateBusinessIncome(TaxYearData data, TaxRules rules) {
    double total = 0;
    for (var b in data.businessIncomes) {
      if (b.type == BusinessType.regular) {
        total += b.netIncome;
      } else if (b.type == BusinessType.section44AD) {
        total += max(b.netIncome, b.grossTurnover * 0.06);
      } else if (b.type == BusinessType.section44ADA) {
        total += max(b.netIncome, b.grossTurnover * 0.50);
      }
    }
    return total;
  }

  // --- NEW CAPITAL GAINS LOGIC ---
  Map<String, double> calculateCapitalGains(TaxYearData data, TaxRules rules) {
    double totalLTCGEquity = 0;
    double totalLTCGOther = 0;
    double totalSTCG = 0;

    if (!rules.isCGRatesEnabled) {
      // If CG rates are disabled, all capital gains are treated as normal income.
      // So, we return them as STCG which will then be added to normal income.
      double totalGain = data.capitalGains
          .fold(0.0, (sum, entry) => sum + entry.capitalGainAmount);
      return {
        'LTCG_Equity': 0,
        'LTCG_Other': 0,
        'STCG': totalGain,
      };
    }

    int currentFYStart = data.year;

    for (var entry in data.capitalGains) {
      double gainAmount = entry.capitalGainAmount;
      double taxableGain = gainAmount;

      int gainFyStart = entry.gainDate.year;
      if (entry.gainDate.month < 4) gainFyStart -= 1;

      int yearsPassed = currentFYStart - gainFyStart;

      // Handle Reinvestment Exemption
      double exemption = 0;

      // Use rules from the Gain Year (User Requirement: Rules effective at time of gain apply)
      final gainYearRules = _configService.getRulesForYear(gainFyStart);

      if (!rules.isCGReinvestmentEnabled ||
          yearsPassed > gainYearRules.windowGainReinvest) {
        // EXPIRED or DISABLED. No exemption.
        exemption = 0;
      } else {
        // WITHIN WINDOW.
        if (entry.reinvestedAmount > 0) {
          if (_isValidReinvestment(
              entry.matchAssetType, entry.matchReinvestType)) {
            // Cap limit (Using CURRENT year's limit? Or Gain Year's limit?
            // Usually limits are based on filing year law if claiming now?
            // But window is structural.
            // Let's stick to Current Rules for limits/rates, but Gain Year Rules for WINDOW validity as requested.)
            double validReinvest =
                min(entry.reinvestedAmount, rules.maxCGReinvestLimit);
            exemption = validReinvest;
          }
        }
      }

      taxableGain = max(0, gainAmount - exemption);

      if (entry.isLTCG) {
        if (entry.matchAssetType == AssetType.equityShares) {
          totalLTCGEquity += taxableGain;
        } else {
          totalLTCGOther += taxableGain;
        }
      } else {
        totalSTCG += taxableGain;
      }
    }

    return {
      'LTCG_Equity': totalLTCGEquity,
      'LTCG_Other': totalLTCGOther,
      'STCG': totalSTCG
    };
  }

  bool _isValidReinvestment(AssetType source, ReinvestmentType target) {
    if (target == ReinvestmentType.none) return false;

    // 1. Equity allowed -> Residential (54F)
    if (source == AssetType.equityShares) {
      return target == ReinvestmentType.residentialProperty;
    }

    // 2. Residential Property allowed -> Residential (54) OR Bonds (54EC)
    if (source == AssetType.residentialProperty) {
      return target == ReinvestmentType.residentialProperty ||
          target == ReinvestmentType.bonds54EC;
    }

    // 3. Agri Land -> Agri Land (54B)
    if (source == AssetType.agriculturalLand) {
      return target == ReinvestmentType.agriculturalLand;
    }

    return false;
  }

  double calculateOtherSources(TaxYearData data, TaxRules rules) {
    // 1. Regular Other Income (Fully Taxable)
    double other =
        data.otherIncomes.fold(0.0, (sum, item) => sum + item.amount);

    // 2. Cash Gifts
    // Rules:
    // - Gifts from Family/Relative, Marriage, Inheritance are EXEMPT.
    // - Others are aggregated. If total > 50,000 (or limit), FULLY TAXABLE.
    double aggregateGifts = 0;
    for (var gift in data.cashGifts) {
      if (['Family/Relative', 'Marriage', 'Inheritance']
          .contains(gift.subtype)) {
        continue; // Exempt
      }
      aggregateGifts += gift.amount;
    }

    double taxableGifts =
        aggregateGifts <= rules.cashGiftExemptionLimit ? 0 : aggregateGifts;

    return other + taxableGifts;
  }

  double _calculateSlabTax(double income, TaxRules rules) {
    // Note: Rebate check is done in calculateDetailedLiability on TOTAL Taxable Income.
    // This helper just computes slab tax on a given base.

    double tax = 0;
    double previousLimit = 0;

    for (final slab in rules.slabs) {
      if (income <= previousLimit) break;
      double slabLimit = slab.upto;
      double checkLimit =
          slabLimit == double.infinity ? double.maxFinite : slabLimit;
      double taxableInSlab = income > checkLimit
          ? checkLimit - previousLimit
          : income - previousLimit;

      if (taxableInSlab > 0) {
        tax += taxableInSlab * (slab.rate / 100);
      }
      previousLimit = checkLimit;
      if (slabLimit == double.infinity) break;
    }
    return tax;
  }

  double _calculateLTCGTax(
      double equityGain, double otherGain, TaxRules rules) {
    if (!rules.isCGRatesEnabled) {
      return 0; // Everything falls back to Slabs if false?
    }
    // User asked "Option to disable ... capital gains rates".
    // Usually that means taxing them as normal income.
    // In our engine, specialRateIncome is deducted from normalIncome.
    // So if isCGRatesEnabled is false, we should return 0 here,
    // and let the top-level calculateDetailedLiability treat it as normal income.

    // 112A: Equity LTCG > 1.25L is taxed at 12.5%
    double exemptEquity =
        rules.isLTCGExemption112AEnabled ? rules.stdExemption112A : 0;
    double taxableEquity =
        (equityGain - exemptEquity).clamp(0, double.infinity);
    double taxEquity = taxableEquity * (rules.ltcgRateEquity / 100);

    // Other LTCG (Real Estate, Gold etc) -> Usually 20% with indexation (Old) OR 12.5% without indexation (New)?
    // The budget 2024 changes are complex.
    // Assumption for New Regime "Samriddhi Flow":
    // Everything is 12.5% for simplicity per some new generic LTCG rules?
    // OR allow user config?
    // User complaint was: "equity exemption is getting applied for all".
    // So "Other LTCG" should NOT get the 1.25L exemption.
    // Let's tax Other LTCG flat at the same rate but NO exemption threshold.

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
    bool percentRule = false;
    if (issueDate.isBefore(DateTime(2012, 4, 1))) {
      percentRule = annualPremium <= (0.20 * sumAssured);
    } else {
      percentRule = annualPremium <= (0.10 * sumAssured);
    }
    return !percentRule;
  }
}

final indianTaxServiceProvider = Provider<IndianTaxService>((ref) {
  final config = ref.watch(taxConfigServiceProvider);
  return IndianTaxService(config);
});
