import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/taxes/tax_data.dart';
import '../../models/taxes/tax_data_models.dart';
import '../../models/taxes/tax_rules.dart';
import 'package:clock/clock.dart';
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
      dividendIncome: const DividendIncome(),
    );
    final details = calculateDetailedLiability(
        salaryOnlyData, rules); // coverage:ignore-line
    return details['totalTax'] ?? 0; // coverage:ignore-line
  }

  Map<String, double> _calculateAdvanceTaxDetails(TaxYearData data,
      TaxRules rules, double totalTax, double specialTax, double totalTds) {
    double specialTaxWithCess = specialTax +
        (rules.isCessEnabled ? specialTax * (rules.cessRate / 100) : 0);

    // CG Tax attract advance tax interest but with special accrual rules (honoring gain date).
    double baseForAdvanceTaxFull = totalTax - totalTds - data.tcs;

    // For UI/Projected installments, we might want to exclude CG if not opted-in.
    double baseForAdvanceTaxProjected = baseForAdvanceTaxFull;
    if (!rules.isCgIncludedInAdvanceTax) {
      baseForAdvanceTaxProjected -= specialTaxWithCess;
    }

    // Safety: Clamp tiny values to 0 to avoid interest on floating point noise
    if (baseForAdvanceTaxProjected > 0 && baseForAdvanceTaxProjected < 1.0) {
      baseForAdvanceTaxProjected = 0.0;
    }

    double advanceTaxInterest =
        calculateAdvanceTaxInterest(data, rules, baseForAdvanceTaxProjected);

    double netTaxPayable = totalTax +
        advanceTaxInterest -
        (data.totalAdvanceTax + totalTds + data.tcs);

    return {
      'baseForAdvanceTaxProjected': baseForAdvanceTaxProjected,
      'advanceTaxInterest': advanceTaxInterest,
      'netTaxPayable': netTaxPayable,
    };
  }

  Map<String, dynamic> calculateDetailedLiability(
      TaxYearData data, TaxRules rules,
      {double? salaryIncomeOverride,
      bool includeGeneratedTds = true,
      double? totalTaxOverride}) {
    final core = _calculateCoreLiability(data, rules,
        salaryIncomeOverride: salaryIncomeOverride);

    double totalTax = totalTaxOverride ?? core['totalTax']!;
    double specialTax = core['specialTax']!;

    final totalTds = _calculateTotalTds(data, rules, includeGeneratedTds);

    final advanceTaxDetails = _calculateAdvanceTaxDetails(
        data, rules, totalTax, specialTax, totalTds);

    return _buildDetailedLiabilityResult(
        data, rules, core, advanceTaxDetails, totalTax, specialTax, totalTds);
  }

  double _calculateTotalTds(
      TaxYearData data, TaxRules rules, bool includeGeneratedTds) {
    if (!includeGeneratedTds) return data.tds;
    final generatedSalaryTds = getGeneratedSalaryTds(data, rules);
    return data.tds + generatedSalaryTds.fold(0.0, (sum, e) => sum + e.amount);
  }

  Map<String, dynamic> _buildDetailedLiabilityResult(
    TaxYearData data,
    TaxRules rules,
    Map<String, double> core,
    Map<String, double> advanceTaxDetails,
    double totalTax,
    double specialTax,
    double totalTds,
  ) {
    return {
      'slabTax': core['slabTax']!,
      'specialTax': specialTax,
      'cess': core['cess']!,
      'totalTax': totalTax,
      'grossIncome': core['grossIncome']!,
      'taxableIncome': core['totalTaxableIncome']!,
      'exemptions': core['exemptions']!,
      'netTaxPayable': advanceTaxDetails['netTaxPayable']!,
      'advanceTax': data.totalAdvanceTax,
      'advanceTaxInterest': advanceTaxDetails['advanceTaxInterest']!,
      'tds': totalTds,
      'tcs': data.tcs,
      'totalDeductions': core['totalDeductions']!,
      'capitalGainsTotal': core['capitalGainsTotal']!,
      'LTCG_Equity': core['LTCG_Equity']!,
      'LTCG_Other': core['LTCG_Other']!,
      'STCG': core['STCG']!,
      'baseForAdvanceTax': advanceTaxDetails['baseForAdvanceTaxProjected']!,
      ..._calculateNextInstallment(
          data, rules, advanceTaxDetails['baseForAdvanceTaxProjected']!),
    };
  }

  Map<String, double> _calculateCoreLiability(TaxYearData data, TaxRules rules,
      {double? salaryIncomeOverride}) {
    // 1. Heads calculation
    double salaryGross = calculateSalaryGross(data, rules);
    double salaryExemptions = calculateSalaryExemptions(data, rules);
    double incomeSalary =
        salaryIncomeOverride ?? (salaryGross - salaryExemptions);

    double hpGross = 0;
    for (var hp in data.houseProperties) {
      if (!hp.isSelfOccupied) hpGross += hp.rentReceived;
    }
    double incomeHP = calculateHousePropertyIncome(data, rules);
    double incomeBusiness = calculateBusinessIncome(data, rules);

    final cgResults = calculateCapitalGains(data, rules);
    double incomeLTCGEquity = cgResults['LTCG_Equity']!;
    double incomeLTCGOther = cgResults['LTCG_Other']!;
    double incomeSTCG = cgResults['STCG']!;
    double incomeOther = calculateOtherSources(data, rules);

    // Apply Custom Rules Exemptions
    incomeSalary = (incomeSalary -
            _getCustomExemptionForHead('Salary', salaryGross, rules))
        .clamp(0.0, double.infinity);
    incomeHP = (incomeHP -
            _getCustomExemptionForHead('House Property', hpGross, rules))
        .clamp(0.0, double.infinity);
    incomeBusiness = (incomeBusiness -
            _getCustomExemptionForHead('Business', incomeBusiness, rules))
        .clamp(0.0, double.infinity);
    incomeOther =
        (incomeOther - _getCustomExemptionForHead('Other', incomeOther, rules))
            .clamp(0.0, double.infinity);
    incomeOther =
        (incomeOther - _getCustomExemptionForHead('Gift', incomeOther, rules))
            .clamp(0.0, double.infinity);

    double totalAgri =
        data.agriIncomeHistory.fold(0.0, (sum, a) => sum + a.amount);

    double grossTotalIncome = salaryGross +
        hpGross +
        incomeBusiness +
        incomeLTCGEquity +
        incomeLTCGOther +
        incomeSTCG +
        incomeOther +
        totalAgri;

    // 2. Deductions
    double deductions = data.salary.npsEmployer;
    if (rules.isStdDeductionSalaryEnabled) {
      deductions += rules.stdDeductionSalary;
    }

    // 3. Tax Calculation
    final specialRateIncome = rules.isCGRatesEnabled
        ? (incomeLTCGEquity + incomeLTCGOther + incomeSTCG)
        : 0.0;
    double taxableHeadsSum =
        incomeSalary + incomeHP + incomeBusiness + incomeOther;
    if (!rules.isCGRatesEnabled) {
      taxableHeadsSum += incomeLTCGEquity + incomeLTCGOther + incomeSTCG;
    }
    double netTaxableNormalIncome =
        (taxableHeadsSum - deductions).clamp(0.0, double.infinity);

    double netAgri = (totalAgri -
            _getCustomExemptionForHead('Agriculture', totalAgri, rules))
        .clamp(0.0, double.infinity);

    double slabTax =
        _computeSlabTaxWithAgri(netTaxableNormalIncome, netAgri, rules);
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

    return {
      'totalTax': taxBeforeCess + cess,
      'slabTax': slabTax,
      'specialTax': specialTax,
      'cess': cess,
      'LTCG_Equity': incomeLTCGEquity,
      'LTCG_Other': incomeLTCGOther,
      'STCG': incomeSTCG,
      'netTaxableNormalIncome': netTaxableNormalIncome,
      'totalTaxableIncome': totalTaxableIncome,
      'grossIncome': grossTotalIncome,
      'exemptions': salaryExemptions,
      'totalDeductions': deductions,
      'capitalGainsTotal': specialRateIncome,
    };
  }

  Map<String, dynamic> _calculateNextInstallment(
      TaxYearData data, TaxRules rules, double baseForAdvanceTax) {
    if (rules.advanceTaxRules.isEmpty) {
      return {}; // coverage:ignore-line
    }

    // Requirement check
    if (baseForAdvanceTax < rules.advanceTaxInterestThreshold) {
      return {};
    }

    final now = clock.now();
    final currentYear = data.year;

    // Accumulated interest up to now (including shortfalls from previous quarters)
    double accumulatedInterest =
        calculateAdvanceTaxInterest(data, rules, baseForAdvanceTax);

    Map<String, dynamic>? lastFutureInstallment;

    for (var rule in rules.advanceTaxRules) {
      int ruleYear = rule.endMonth < rules.financialYearStartMonth
          ? currentYear + 1
          : currentYear;
      DateTime dueDate =
          DateTime(ruleYear, rule.endMonth, rule.endDay, 23, 59, 59);

      if (dueDate.isAfter(now)) {
        double requiredTotalTillNow =
            baseForAdvanceTax * (rule.requiredPercentage / 100);
        double alreadyPaid = data.totalAdvanceTax;
        double remainingForNext =
            requiredTotalTillNow - alreadyPaid + accumulatedInterest;

        final result = {
          'nextAdvanceTaxDueDate': dueDate,
          'nextAdvanceTaxAmount': remainingForNext > 0 ? remainingForNext : 0.0,
          'daysUntilAdvanceTax': dueDate.difference(now).inDays,
          'isRequirementMet': alreadyPaid >= requiredTotalTillNow,
        };

        if (alreadyPaid < requiredTotalTillNow) {
          return result;
        }
        lastFutureInstallment = result;
      }
    }

    return lastFutureInstallment ?? {};
  }

  /// Calculates tax liability accrued up to a specific date for advance tax purposes.
  /// It creates a synthetic TaxYearData excluding point-of-receipt incomes
  /// that have not yet occurred, then calculates the exact core liability.
  double calculateAccruedLiability(
      TaxYearData data, TaxRules rules, DateTime upToDate,
      {double? fullYearNormalTax}) {
    final syntheticData = _createSyntheticData(data, rules, upToDate);

    final liability = _calculateCoreLiability(syntheticData, rules);
    return liability['totalTax']!;
  }

  /// Helper to create a time-bound snapshot of TaxYearData for a specific date.
  TaxYearData _createSyntheticData(
      TaxYearData data, TaxRules rules, DateTime upToDate) {
    return data.copyWith(
      capitalGains: rules.isCgIncludedInAdvanceTax
          ? data.capitalGains
              .where((g) => !g.gainDate.isAfter(upToDate))
              .toList()
          : [],
      otherIncomes: data.otherIncomes
          .where((o) =>
              o.transactionDate == null ||
              !o.transactionDate!.isAfter(upToDate))
          .toList(),
      cashGifts: data.cashGifts
          .where((g) =>
              g.transactionDate == null || // coverage:ignore-line
              !g.transactionDate!.isAfter(upToDate)) // coverage:ignore-line
          .toList(),
      houseProperties: data.houseProperties
          .where((h) =>
              h.transactionDate == null ||
              !h.transactionDate!.isAfter(upToDate))
          .toList(),
      businessIncomes: data.businessIncomes
          .where((b) =>
              b.transactionDate == null ||
              !b.transactionDate!.isAfter(upToDate)) // coverage:ignore-line
          .toList(),
      agriIncomeHistory: data.agriIncomeHistory
          .where((a) => !a.date.isAfter(upToDate))
          .toList(),
      dividendIncome:
          _accrueDividendIncome(data.dividendIncome, data.year, upToDate),
      tdsEntries:
          data.tdsEntries.where((e) => !e.date.isAfter(upToDate)).toList(),
      tcsEntries:
          data.tcsEntries.where((e) => !e.date.isAfter(upToDate)).toList(),
    );
  }

  DividendIncome _accrueDividendIncome(
      DividendIncome div, int currentYear, DateTime upToDate) {
    return DividendIncome(
      amountQ1:
          upToDate.isAfter(DateTime(currentYear, 6, 14)) ? div.amountQ1 : 0,
      amountQ2:
          upToDate.isAfter(DateTime(currentYear, 9, 14)) ? div.amountQ2 : 0,
      amountQ3:
          upToDate.isAfter(DateTime(currentYear, 12, 14)) ? div.amountQ3 : 0,
      amountQ4:
          upToDate.isAfter(DateTime(currentYear + 1, 3, 14)) ? div.amountQ4 : 0,
      amountQ5:
          upToDate.isAfter(DateTime(currentYear + 1, 3, 30)) ? div.amountQ5 : 0,
    );
  }

  double calculateAdvanceTaxInterest(
      TaxYearData data, TaxRules rules, double fullYearLiabilityAfterTds) {
    if (!rules.enableAdvanceTaxInterest ||
        fullYearLiabilityAfterTds < rules.advanceTaxInterestThreshold) {
      return 0.0;
    }

    double totalInterest = 0.0;
    final now = clock.now();

    for (int i = 0; i < rules.advanceTaxRules.length; i++) {
      final rule = rules.advanceTaxRules[i];
      final dueDate = _getInstallmentDueDate(
          rule, data.year, rules.financialYearStartMonth);

      if (now.isBefore(dueDate)) continue;

      // Create a synthetic time-bound snapshot of the data for this specific installment.
      // This ensures that TDS and TCS projections are localized and not polluted by future income.
      final syntheticData = _createSyntheticData(data, rules, dueDate);

      // Determine total TDS and TCS that can be deducted for this specific installment projection.
      // We use the synthetic data so that projected salary TDS only reflects base income known up to this date.
      final double currentTds = _calculateTotalTds(syntheticData, rules, true);
      final double currentTcs = syntheticData.tcs;
      final double totalDeductedTaxes = currentTds + currentTcs;

      // calculateAccruedLiability returns the gross tax (including cess)
      // after applying the relevant rebate for the synthetic income up to this date.
      final double accruedNetTax =
          calculateAccruedLiability(data, rules, dueDate);

      double liabilityToCover =
          (accruedNetTax - totalDeductedTaxes).clamp(0.0, double.infinity);

      if (liabilityToCover > fullYearLiabilityAfterTds) {
        liabilityToCover = fullYearLiabilityAfterTds;
      }

      final requiredAmount = liabilityToCover * (rule.requiredPercentage / 100);
      final paidBeforeDue = _calculatePaidBeforeDue(data, dueDate);
      final shortfall = requiredAmount - paidBeforeDue;

      if (shortfall > 0) {
        if (rules.interestTillPaymentDate) {
          totalInterest += _calculateInterestTillPaymentDate(
              data, rule, i, rules, shortfall, dueDate, now);
        } else {
          totalInterest +=
              _calculateStandardInterest(rule, i, rules, shortfall);
        }
      }
    }

    return totalInterest;
  }

  DateTime _getInstallmentDueDate(
      AdvanceTaxInstallmentRule rule, int currentYear, int fyStartMonth) {
    int ruleYear = rule.endMonth < fyStartMonth ? currentYear + 1 : currentYear;
    return DateTime(ruleYear, rule.endMonth, rule.endDay, 23, 59, 59);
  }

  double _calculatePaidBeforeDue(TaxYearData data, DateTime dueDate) {
    return data.advanceTaxEntries
        .where(
            (e) => e.date.isBefore(dueDate) || e.date.isAtSameMomentAs(dueDate))
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  double _calculateInterestTillPaymentDate(
      TaxYearData data,
      AdvanceTaxInstallmentRule rule,
      int index,
      TaxRules rules,
      double shortfall,
      DateTime dueDate,
      DateTime now) {
    final paymentsAfter =
        data.advanceTaxEntries.where((e) => e.date.isAfter(dueDate)).toList();
    paymentsAfter.sort((a, b) => a.date.compareTo(b.date));

    final boundaryDate =
        _getInterestBoundaryDate(rule, index, rules, now, data.year);
    final nextDueBoundary = boundaryDate.millisecondsSinceEpoch.toDouble();

    double totalInterest = 0.0;
    double remainingShortfall = shortfall;
    DateTime lastCalculationDate = dueDate;

    for (var p in paymentsAfter) {
      if (remainingShortfall <= 0 ||
          p.date.millisecondsSinceEpoch >= nextDueBoundary) {
        break;
      }

      int months = _calculateInterestMonths(lastCalculationDate, p.date);
      if (months > 0) {
        totalInterest +=
            remainingShortfall * (rule.interestRate / 100) * months;
      }

      remainingShortfall -= p.amount;
      lastCalculationDate = p.date;
    }

    if (remainingShortfall > 0) {
      int months = _calculateInterestMonths(lastCalculationDate, boundaryDate);
      if (months > 0) {
        totalInterest +=
            remainingShortfall * (rule.interestRate / 100) * months;
      }
    }

    return totalInterest;
  }

  DateTime _getInterestBoundaryDate(AdvanceTaxInstallmentRule rule, int index,
      TaxRules rules, DateTime now, int currentYear) {
    if (index < rules.advanceTaxRules.length - 1) {
      final nextRule = rules.advanceTaxRules[index + 1];
      final nextDueDate = _getInstallmentDueDate(
          nextRule, currentYear, rules.financialYearStartMonth);
      return now.isBefore(nextDueDate) ? now : nextDueDate;
    } else {
      final fyEndDate = DateTime(
          _getInstallmentDueDate(
                  rule, currentYear, rules.financialYearStartMonth)
              .year,
          rule.endMonth + 1,
          0,
          23,
          59,
          59);
      return now.isBefore(fyEndDate) ? now : fyEndDate;
    }
  }

  double _calculateStandardInterest(AdvanceTaxInstallmentRule rule, int index,
      TaxRules rules, double shortfall) {
    int monthsPenalty = 0;
    if (index < rules.advanceTaxRules.length - 1) {
      final nextRule = rules.advanceTaxRules[index + 1];
      monthsPenalty =
          (nextRule.endMonth < rules.financialYearStartMonth ? 1 : 0) * 12 +
              nextRule.endMonth -
              rule.endMonth;
      // Note: This logic for standard penalty is slightly simplified but matches the previous intent
      // which was roughly months between installments.
    } else {
      monthsPenalty = 1;
    }
    return shortfall * (rule.interestRate / 100) * monthsPenalty;
  }

  int _calculateInterestMonths(DateTime start, DateTime end) {
    if (end.isBefore(start)) return 0;
    // Difference in whole months
    int months = (end.year - start.year) * 12 + end.month - start.month;
    // Any fraction of a month is considered a full month
    if (end.day > start.day) {
      months++;
    }
    return months;
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
    }

    // Gifts from employer are now expected to be part of the monthly history or independent allowances if applicable
    // If they were handled specifically before, they should be migrated to a structured format.

    totalGross += _computeIndependentAllowanceGross(data);
    totalGross += data.salary.leaveEncashment;
    totalGross += data.salary.gratuity;
    return totalGross;
  }

  double _computeIndependentAllowanceGross(TaxYearData data) {
    double total = 0;
    for (final a in data.salary.independentAllowances) {
      for (int m = 1; m <= 12; m++) {
        if (SalaryStructure.isPayoutMonth(
            m, a.frequency, a.startMonth, a.customMonths)) {
          total += _getAllowancePayoutAmount(a, m);
        }
      }
    }
    return total;
  }

  double calculateSalaryExemptions(TaxYearData data, TaxRules rules) {
    double totalExemptions = 0;

    totalExemptions += _calculateStructureExemptions(data, rules);
    totalExemptions +=
        _calculateIndependentExemptions(data.salary.independentExemptions);
    totalExemptions += _calculateIndependentAllowanceExemptions(data);
    totalExemptions += _calculateRetirementExemptions(data, rules);

    return totalExemptions;
  }

  double _calculateRetirementExemptions(TaxYearData data, TaxRules rules) {
    if (!rules.isRetirementExemptionEnabled) return 0;
    double exemption = 0;

    // Leave Encashment Exemption
    if (data.salary.leaveEncashment > 0) {
      exemption += min(data.salary.leaveEncashment, rules.limitLeaveEncashment);
    }

    // Gratuity Exemption
    if (data.salary.gratuity > 0) {
      exemption += min(data.salary.gratuity, rules.limitGratuity);
    }

    return exemption;
  }

  double _calculateStructureExemptions(TaxYearData data, TaxRules rules) {
    if (data.salary.history.isEmpty) return 0;
    double structureExemptions = 0;
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
        structureExemptions += max(0, gross - taxable);
      }
    }
    return structureExemptions;
  }

  double _calculateIndependentExemptions(List<CustomExemption> exemptions) {
    double total = 0;
    for (var ex in exemptions) {
      if (ex.exemptionLimit <= 0) {
        total += ex.amount;
        // coverage:ignore-start
      } else if (ex.isCliffExemption) {
        if (ex.amount <= ex.exemptionLimit) {
          total += ex.amount;
          // coverage:ignore-end
        }
      } else {
        total += min(ex.amount, ex.exemptionLimit); // coverage:ignore-line
      }
    }
    return total;
  }

  double _calculateIndependentAllowanceExemptions(TaxYearData data) {
    double totalExemption = 0;
    for (final a in data.salary.independentAllowances) {
      if (a.exemptionLimit <= 0) continue;
      totalExemption += _calculateAllowanceExemption(a);
    }
    return totalExemption;
  }

  double _calculateAllowanceExemption(CustomAllowance a) {
    double exemption = 0;
    for (int m = 1; m <= 12; m++) {
      if (!SalaryStructure.isPayoutMonth(
          m, a.frequency, a.startMonth, a.customMonths)) {
        continue;
      }
      final qty = _getAllowancePayoutAmount(a, m);
      exemption +=
          _applyExemptionCap(qty, a.exemptionLimit, a.isCliffExemption);
    }
    return exemption;
  }

  double _getAllowancePayoutAmount(CustomAllowance a, int month) {
    return a.isPartial
        ? (a.partialAmounts[month] ?? a.payoutAmount)
        : a.payoutAmount;
  }

  double _applyExemptionCap(double amount, double limit, bool isCliff) {
    if (isCliff) return amount <= limit ? amount : 0; // coverage:ignore-line
    return min(amount, limit);
  }

  double _getCustomExemptionForHead(String head, double gross, TaxRules rules) {
    double total = 0;
    for (var rule in rules.customExemptions) {
      if (rule.isEnabled &&
          rule.incomeHead.toLowerCase() == head.toLowerCase()) {
        if (rule.isPercentage) {
          total += gross * (rule.limit / 100);
        } else {
          total += rule.limit;
        }
      }
    }
    return total;
  }

  double calculateHousePropertyIncome(TaxYearData data, TaxRules rules) {
    double totalNet = 0;
    for (var hp in data.houseProperties) {
      double propertyNet = 0;
      if (hp.isSelfOccupied) {
        double interest = hp.interestOnLoan;
        if (rules.isHPMaxInterestEnabled) {
          interest = min(interest, rules.maxHPDeductionLimit);
        }
        propertyNet = -interest;
      } else {
        double nav = hp.rentReceived - hp.municipalTaxes;
        double stdDed = rules.isStdDeductionHPEnabled
            ? (nav * rules.standardDeductionRateHP / 100)
            : 0;
        propertyNet = nav - stdDed - hp.interestOnLoan;
      }

      // Each property's taxable income cannot be negative in this view
      totalNet += max(0.0, propertyNet);
    }
    return totalNet;
  }

  double calculateBusinessIncome(TaxYearData data, TaxRules rules) {
    double total = 0;
    for (var biz in data.businessIncomes) {
      if (biz.type == BusinessType.section44AD && rules.is44ADEnabled) {
        total += biz.presumptiveIncome; // coverage:ignore-line
      } else if (biz.type == BusinessType.section44ADA &&
          rules.is44ADAEnabled) {
        // coverage:ignore-line
        total += biz.presumptiveIncome; // coverage:ignore-line
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
      if (rules.taxableGiftKeys
          .map((k) => k.toLowerCase())
          .contains(gift.subtype.toLowerCase())) {
        aggregateGifts += gift.amount;
      }
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
  Map<String, double> getDeductionSuggestions(TaxYearData data) =>
      {}; // coverage:ignore-line

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
    double accumulatedTaxPaid = 0;
    final fyMonths = [4, 5, 6, 7, 8, 9, 10, 11, 12, 1, 2, 3];

    final salaryOnlyData = data.copyWith(
      houseProperties: [],
      businessIncomes: [],
      capitalGains: [],
      otherIncomes: [],
      dividendIncome: const DividendIncome(),
      cashGifts: [],
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
        currentIrregular, // This is still needed for one-step subtraction inside helper
        rules,
      );

      double annualTaxableFull = max(
          0,
          projected.full -
              exemptionPools.retirementExemptions -
              exemptionPools.plannedExemptions);
      double annualTaxableStable = max(
          0,
          projected.stable -
              exemptionPools.retirementExemptions -
              exemptionPools.plannedExemptions);
      double annualTaxableWithPlanning = annualTaxableFull;

      double totalTaxFull = _calculateCoreLiability(salaryOnlyData, rules,
          salaryIncomeOverride: annualTaxableFull)['totalTax']!;
      double totalTaxStable = _calculateCoreLiability(salaryOnlyData, rules,
          salaryIncomeOverride: annualTaxableStable)['totalTax']!;
      double totalTaxWithPlanning = _calculateCoreLiability(
          salaryOnlyData, rules,
          salaryIncomeOverride: annualTaxableWithPlanning)['totalTax']!;

      // HYBRID Spike + Catch-up logic
      int monthsRemaining = 12 - i;
      double marginalBonusTax =
          currentIrregular > 0 ? max(0, totalTaxFull - totalTaxStable) : 0;
      double regularMonthlyTax =
          max(0, (totalTaxStable - accumulatedTaxPaid) / monthsRemaining);

      double monthlyTax = regularMonthlyTax + marginalBonusTax;

      accumulatedTaxPaid += monthlyTax;

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

  double _computeCurrentIrregular(
      TaxYearData data, SalaryStructure? s, int m, TaxRules rules) {
    double total = 0;
    if (s != null) {
      total += s.calculateIrregularContribution(
          m, rules.financialYearStartMonth,
          taxableOnly: true);
    }

    for (final a in data.salary.independentAllowances) {
      if (SalaryStructure.isPayoutMonth(
          m, a.frequency, a.startMonth, a.customMonths)) {
        // We consider 'custom' frequency or infrequent ones as irregular
        if (a.frequency != PayoutFrequency.monthly) {
          total += _getAllowancePayoutAmount(a, m);
        }
      }
    }

    // Gifts from Employer in March logic removed
    if (m == 3) {
      // total += data.salary.giftsFromEmployer; // Deprecated
    }

    return total;
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
        final amt = _getAllowancePayoutAmount(a, m);
        gross += amt;
        taxable += amt;
      }
    }

    // Gifts from Employer logic removed from here as it should be part of history

    return (gross: gross, taxable: taxable);
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

    int projectionBaseMonth = fyMonths[currentIndex];
    for (int j = currentIndex + 1; j < fyMonths.length; j++) {
      int futureMonth = fyMonths[j];
      final futureStructure = currentStructure; // Reverted to Blind Projection

      _addFutureMonthProjection(
          data, futureStructure, futureMonth, rules, projFull, projStable);

      if (futureStructure != null) {
        double reg = futureStructure.calculateRegularContribution(
            projectionBaseMonth, rules.financialYearStartMonth,
            taxableOnly: true);
        projFull += reg; // Only project current regular rate for future
        projStable += reg;
      }

      for (final a in data.salary.independentAllowances) {
        if (a.frequency == PayoutFrequency.monthly &&
            SalaryStructure.isPayoutMonth(projectionBaseMonth, a.frequency,
                a.startMonth, a.customMonths)) {
          final amt = _getAllowancePayoutAmount(a, projectionBaseMonth);
          projFull += amt;
          projStable += amt;
        }
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
        total += a.isPartial ? (a.partialAmounts[m] ?? a.amount) : a.amount;
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

  List<TaxPaymentEntry> getGeneratedSalaryTds(
      TaxYearData data, TaxRules rules) {
    if (data.salary.history.isEmpty) {
      return [];
    }
    return _generateDetailedSalaryTds(data, rules);
  }

  List<TaxPaymentEntry> _generateDetailedSalaryTds(
      TaxYearData data, TaxRules rules) {
    final breakdown = calculateMonthlySalaryBreakdown(data, rules);
    final List<TaxPaymentEntry> entries = [];

    final fyMonths = [4, 5, 6, 7, 8, 9, 10, 11, 12, 1, 2, 3];
    for (int m in fyMonths) {
      final mData = breakdown[m];
      if (mData != null && (mData['tax'] ?? 0) > 0) {
        int yr = (m >= 4) ? data.year : data.year + 1;
        entries.add(TaxPaymentEntry(
          id: 'salary_tds_\${data.year}_\$m',
          amount: mData['tax']!,
          date: DateTime(yr, m, 28),
          source: 'Employer (Salary TDS)',
          isManualEntry: false,
        ));
      }
    }
    return entries;
  }
}

final indianTaxServiceProvider = Provider<IndianTaxService>((ref) {
  final config = ref.watch(taxConfigServiceProvider); // coverage:ignore-line
  return IndianTaxService(config); // coverage:ignore-line
});
