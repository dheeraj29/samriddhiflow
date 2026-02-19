import 'package:hive_ce/hive.dart';

part 'tax_rules.g.dart';

@HiveType(typeId: 203)
class TaxExemptionRule {
  @HiveField(0)
  final String name;
  @HiveField(1)
  final String incomeHead; // 'Salary', 'Business', 'Other', etc.
  @HiveField(2)
  final double limit;
  @HiveField(3)
  final bool
      isPercentage; // If true, limit is treated as % of Gross Income of that head
  @HiveField(4)
  final bool isEnabled;

  @HiveField(5)
  final String id; // Unique ID for mapping

  const TaxExemptionRule({
    required this.id,
    required this.name,
    required this.incomeHead,
    required this.limit,
    this.isPercentage = false,
    this.isEnabled = true,
  });
  TaxExemptionRule copyWith({
    String? id,
    String? name,
    String? incomeHead,
    double? limit,
    bool? isPercentage,
    bool? isEnabled,
  }) {
    return TaxExemptionRule(
      id: id ?? this.id,
      name: name ?? this.name,
      incomeHead: incomeHead ?? this.incomeHead,
      limit: limit ?? this.limit,
      isPercentage: isPercentage ?? this.isPercentage,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'incomeHead': incomeHead,
        'limit': limit,
        'isPercentage': isPercentage,
        'isEnabled': isEnabled,
      };

  factory TaxExemptionRule.fromMap(Map<String, dynamic> m) => TaxExemptionRule(
        id: m['id']?.toString() ??
            'rule_${DateTime.now().millisecondsSinceEpoch}', // Fallback for old data
        name: m['name'] ?? '',
        incomeHead: m['incomeHead'] ?? '',
        limit: (m['limit'] as num?)?.toDouble() ?? 0.0,
        isPercentage: m['isPercentage'] ?? false,
        isEnabled: m['isEnabled'] ?? true,
      );
}

@HiveType(typeId: 202)
class TaxSlab {
  @HiveField(0)
  final double
      upto; // Upper limit of this slab (use TaxRules.infinitySubstitute for last)

  @HiveField(1)
  final double rate; // Percentage (e.g. 5.0 for 5%)

  const TaxSlab(this.upto, this.rate);

  bool get isUnlimited => upto >= TaxRules.infinitySubstitute;

  Map<String, dynamic> toMap() => {
        'upto': upto,
        'rate': rate,
      };

  factory TaxSlab.fromMap(Map<String, dynamic> m) => TaxSlab(
        (m['upto'] as num).toDouble(),
        (m['rate'] as num).toDouble(),
      );
}

@HiveType(typeId: 204)
class InsurancePremiumRule {
  @HiveField(0)
  final DateTime startDate;
  @HiveField(1)
  final double limitPercentage; // e.g. 20.0 or 10.0

  const InsurancePremiumRule(this.startDate, this.limitPercentage);

  Map<String, dynamic> toMap() => {
        'startDate': startDate.toIso8601String(),
        'limitPercentage': limitPercentage,
      };

  factory InsurancePremiumRule.fromMap(Map<String, dynamic> m) =>
      InsurancePremiumRule(
        DateTime.parse(m['startDate']),
        (m['limitPercentage'] as num).toDouble(),
      );
}

@HiveType(typeId: 205)
class TaxMappingRule {
  @HiveField(0)
  final String categoryName;

  @HiveField(1)
  final String taxHead;

  @HiveField(2)
  final List<String> matchDescriptions;

  @HiveField(3)
  final int? minHoldingMonths;

  @HiveField(4)
  final List<String> excludeDescriptions;

  const TaxMappingRule({
    required this.categoryName,
    required this.taxHead,
    this.matchDescriptions = const [],
    this.excludeDescriptions = const [],
    this.minHoldingMonths,
  });

  TaxMappingRule copyWith({
    String? categoryName,
    String? taxHead,
    List<String>? matchDescriptions,
    List<String>? excludeDescriptions,
    int? minHoldingMonths,
  }) {
    return TaxMappingRule(
      categoryName: categoryName ?? this.categoryName,
      taxHead: taxHead ?? this.taxHead,
      matchDescriptions: matchDescriptions ?? this.matchDescriptions,
      excludeDescriptions: excludeDescriptions ?? this.excludeDescriptions,
      minHoldingMonths: minHoldingMonths ?? this.minHoldingMonths,
    );
  }

  Map<String, dynamic> toMap() => {
        'categoryName': categoryName,
        'taxHead': taxHead,
        'matchDescriptions': matchDescriptions,
        'excludeDescriptions': excludeDescriptions,
        'minHoldingMonths': minHoldingMonths,
      };

  factory TaxMappingRule.fromMap(Map<String, dynamic> m) => TaxMappingRule(
        categoryName: m['categoryName'] ?? '',
        taxHead: m['taxHead'] ?? '',
        matchDescriptions: List<String>.from(m['matchDescriptions'] ?? []),
        excludeDescriptions: List<String>.from(m['excludeDescriptions'] ?? []),
        minHoldingMonths: m['minHoldingMonths'],
      );
}

@HiveType(typeId: 227)
class TaxRules {
  static const double infinitySubstitute = 1e15;

  @HiveField(0)
  final double currencyLimit10_10D;

  @HiveField(1)
  final double stdDeductionSalary;

  @HiveField(2)
  final double stdExemption112A;

  // @HiveField(3) - Removed legacyReserved

  @HiveField(4)
  final double ltcgRateEquity;

  @HiveField(5)
  final double stcgRate;

  @HiveField(6)
  final double windowGainReinvest;

  // @HiveField(7) - Removed legacyReservedInt

  @HiveField(8)
  final Map<String, String> tagMappings;

  @HiveField(12)
  final double limitGratuity;

  @HiveField(13)
  final double limitLeaveEncashment;

  @HiveField(9)
  final List<TaxSlab> slabs; // Ordered list of slabs

  @HiveField(10)
  final double
      rebateLimit; // e.g. 7L or 12L (Income below this gets full rebate)

  @HiveField(11)
  final double cessRate; // e.g. 4.0

  @HiveField(14)
  final double maxCGReinvestLimit; // 10 Cr limit u/s 54/54F

  @HiveField(15)
  final double
      maxHPDeductionLimit; // Custom Rule: Max deduction for Municipal Tax + 30% Std

  @HiveField(16)
  final double standardDeductionRateHP; // Default 30.0

  // --- INSURANCE CUSTOMIZATION ---
  @HiveField(17)
  final double limitInsuranceULIP; // Default 2.5L
  @HiveField(18)
  final DateTime dateEffectiveULIP; // Default Feb 1, 2021

  @HiveField(19)
  final double limitInsuranceNonULIP; // Default 5.0L
  @HiveField(20)
  final DateTime dateEffectiveNonULIP; // Default Apr 1, 2023

  @HiveField(21)
  final List<TaxExemptionRule> customExemptions;

  @HiveField(22)
  final String jurisdiction; // 'India', 'USA', etc.

  @HiveField(23)
  final double cashGiftExemptionLimit; // Default 50000 for India

  // --- NEW INSURANCE PREMIUM LIMITS (Replacing single fields) ---
  @HiveField(24)
  final List<InsurancePremiumRule> insurancePremiumRules;

  // --- EXEMPTION TOGGLES ---
  // @HiveField(25) - Removed legacyToggle1
  @HiveField(26)
  final bool isCashGiftExemptionEnabled;

  @HiveField(27)
  final double agricultureIncomeThreshold; // Default 5000
  @HiveField(28)
  final double agricultureBasicExemptionLimit; // Default 400,000

  @HiveField(29)
  final String customJurisdictionName;
  @HiveField(30)
  final bool isStdDeductionSalaryEnabled;
  @HiveField(31)
  final bool isStdDeductionHPEnabled;
  @HiveField(32)
  final bool isCessEnabled;
  @HiveField(33)
  final bool isRebateEnabled;
  @HiveField(34)
  final bool isLTCGExemption112AEnabled;
  @HiveField(35)
  final bool isInsuranceExemptionEnabled;
  @HiveField(36)
  final bool isInsuranceAggregateLimitEnabled;
  @HiveField(37)
  final bool isInsurancePremiumPercentEnabled;
  @HiveField(38)
  final bool isRetirementExemptionEnabled;
  @HiveField(39)
  final bool isHPMaxInterestEnabled;
  @HiveField(40)
  final bool isCGReinvestmentEnabled;
  @HiveField(41)
  final bool isCGRatesEnabled;
  @HiveField(42)
  final bool isAgriIncomeEnabled;

  @HiveField(43)
  final List<TaxMappingRule> advancedTagMappings;

  @HiveField(44)
  final int financialYearStartMonth; // Default 4 (April)

  @HiveField(45)
  final double giftFromEmployerExemptionLimit; // Default 5000

  @HiveField(46)
  final bool isGiftFromEmployerEnabled;

  @HiveField(47)
  final bool is44ADEnabled;
  @HiveField(48)
  final double limit44AD;
  @HiveField(49)
  final double rate44AD;

  @HiveField(50)
  final bool is44ADAEnabled;
  @HiveField(51)
  final double limit44ADA;
  @HiveField(52)
  final double rate44ADA;

  TaxRules({
    this.currencyLimit10_10D = 500000,
    this.stdDeductionSalary = 75000,
    this.stdExemption112A = 125000,
    this.ltcgRateEquity = 12.5,
    this.stcgRate = 20.0,
    this.windowGainReinvest = 2.0,
    this.tagMappings = const {},
    this.limitGratuity = 2000000,
    this.limitLeaveEncashment = 2500000,
    this.slabs = const [
      TaxSlab(400000, 0),
      TaxSlab(800000, 5),
      TaxSlab(1200000, 10),
      TaxSlab(1600000, 15),
      TaxSlab(2000000, 20),
      TaxSlab(2400000, 25),
      TaxSlab(TaxRules.infinitySubstitute, 30),
    ],
    this.rebateLimit = 1200000,
    this.cessRate = 4.0,
    this.maxCGReinvestLimit = 100000000,
    this.maxHPDeductionLimit = 200000,
    this.standardDeductionRateHP = 30.0,
    this.limitInsuranceULIP = 250000,
    DateTime? dateEffectiveULIP,
    this.limitInsuranceNonULIP = 500000,
    DateTime? dateEffectiveNonULIP,
    this.customExemptions = const [],
    this.jurisdiction = 'India',
    this.cashGiftExemptionLimit = 50000,
    List<InsurancePremiumRule>? insurancePremiumRules,
    this.isCashGiftExemptionEnabled = true,
    this.agricultureIncomeThreshold = 5000,
    this.agricultureBasicExemptionLimit = 400000,
    this.customJurisdictionName = '',
    this.isStdDeductionSalaryEnabled = true,
    this.isStdDeductionHPEnabled = true,
    this.isCessEnabled = true,
    this.isRebateEnabled = true,
    this.isLTCGExemption112AEnabled = true,
    this.isInsuranceExemptionEnabled = true,
    this.isInsuranceAggregateLimitEnabled = true,
    this.isInsurancePremiumPercentEnabled = true,
    this.isRetirementExemptionEnabled = true,
    this.isHPMaxInterestEnabled = true,
    this.isCGReinvestmentEnabled = true,
    this.isCGRatesEnabled = true,
    this.isAgriIncomeEnabled = true,
    this.advancedTagMappings = const [],
    this.financialYearStartMonth = 4,
    this.giftFromEmployerExemptionLimit = 5000,
    this.isGiftFromEmployerEnabled = true,
    this.is44ADEnabled = true,
    this.limit44AD = 20000000,
    this.rate44AD = 6.0,
    this.is44ADAEnabled = true,
    this.limit44ADA = 5000000,
    this.rate44ADA = 50.0,
  })  : dateEffectiveULIP = dateEffectiveULIP ?? DateTime(2021, 2, 1),
        dateEffectiveNonULIP = dateEffectiveNonULIP ?? DateTime(2023, 4, 1),
        insurancePremiumRules = insurancePremiumRules ??
            [
              InsurancePremiumRule(
                  DateTime(2000, 1, 1), 100.0), // Using 2000 as far past
              InsurancePremiumRule(DateTime(2003, 4, 1), 20.0),
              InsurancePremiumRule(DateTime(2012, 4, 1), 10.0),
            ];

  TaxRules copyWith({
    double? currencyLimit10_10D,
    double? stdDeductionSalary,
    double? stdExemption112A,
    double? ltcgRateEquity,
    double? stcgRate,
    double? windowGainReinvest,
    Map<String, String>? tagMappings,
    List<TaxSlab>? slabs,
    double? limitGratuity,
    double? limitLeaveEncashment,
    double? rebateLimit,
    double? cessRate,
    double? maxCGReinvestLimit,
    double? maxHPDeductionLimit,
    double? standardDeductionRateHP,
    double? limitInsuranceULIP,
    DateTime? dateEffectiveULIP,
    double? limitInsuranceNonULIP,
    DateTime? dateEffectiveNonULIP,
    List<TaxExemptionRule>? customExemptions,
    String? jurisdiction,
    double? cashGiftExemptionLimit,
    List<InsurancePremiumRule>? insurancePremiumRules,
    bool? isCashGiftExemptionEnabled,
    double? agricultureIncomeThreshold,
    double? agricultureBasicExemptionLimit,
    String? customJurisdictionName,
    bool? isStdDeductionSalaryEnabled,
    bool? isStdDeductionHPEnabled,
    bool? isCessEnabled,
    bool? isRebateEnabled,
    bool? isLTCGExemption112AEnabled,
    bool? isInsuranceExemptionEnabled,
    bool? isInsuranceAggregateLimitEnabled,
    bool? isInsurancePremiumPercentEnabled,
    bool? isRetirementExemptionEnabled,
    bool? isHPMaxInterestEnabled,
    bool? isCGReinvestmentEnabled,
    bool? isCGRatesEnabled,
    bool? isAgriIncomeEnabled,
    List<TaxMappingRule>? advancedTagMappings,
    int? financialYearStartMonth,
    double? giftFromEmployerExemptionLimit,
    bool? isGiftFromEmployerEnabled,
    bool? is44ADEnabled,
    double? limit44AD,
    double? rate44AD,
    bool? is44ADAEnabled,
    double? limit44ADA,
    double? rate44ADA,
  }) {
    return TaxRules(
      currencyLimit10_10D: currencyLimit10_10D ?? this.currencyLimit10_10D,
      stdDeductionSalary: stdDeductionSalary ?? this.stdDeductionSalary,
      stdExemption112A: stdExemption112A ?? this.stdExemption112A,
      ltcgRateEquity: ltcgRateEquity ?? this.ltcgRateEquity,
      stcgRate: stcgRate ?? this.stcgRate,
      windowGainReinvest: windowGainReinvest ?? this.windowGainReinvest,
      tagMappings: tagMappings ?? this.tagMappings,
      limitGratuity: limitGratuity ?? this.limitGratuity,
      limitLeaveEncashment: limitLeaveEncashment ?? this.limitLeaveEncashment,
      slabs: slabs ?? this.slabs,
      rebateLimit: rebateLimit ?? this.rebateLimit,
      cessRate: cessRate ?? this.cessRate,
      maxCGReinvestLimit: maxCGReinvestLimit ?? this.maxCGReinvestLimit,
      maxHPDeductionLimit: maxHPDeductionLimit ?? this.maxHPDeductionLimit,
      standardDeductionRateHP:
          standardDeductionRateHP ?? this.standardDeductionRateHP,
      limitInsuranceULIP: limitInsuranceULIP ?? this.limitInsuranceULIP,
      dateEffectiveULIP: dateEffectiveULIP ?? this.dateEffectiveULIP,
      limitInsuranceNonULIP:
          limitInsuranceNonULIP ?? this.limitInsuranceNonULIP,
      dateEffectiveNonULIP: dateEffectiveNonULIP ?? this.dateEffectiveNonULIP,
      customExemptions: customExemptions ?? this.customExemptions,
      jurisdiction: jurisdiction ?? this.jurisdiction,
      cashGiftExemptionLimit:
          cashGiftExemptionLimit ?? this.cashGiftExemptionLimit,
      insurancePremiumRules:
          insurancePremiumRules ?? this.insurancePremiumRules,
      isCashGiftExemptionEnabled:
          isCashGiftExemptionEnabled ?? this.isCashGiftExemptionEnabled,
      agricultureIncomeThreshold:
          agricultureIncomeThreshold ?? this.agricultureIncomeThreshold,
      agricultureBasicExemptionLimit:
          agricultureBasicExemptionLimit ?? this.agricultureBasicExemptionLimit,
      customJurisdictionName:
          customJurisdictionName ?? this.customJurisdictionName,
      isStdDeductionSalaryEnabled:
          isStdDeductionSalaryEnabled ?? this.isStdDeductionSalaryEnabled,
      isStdDeductionHPEnabled:
          isStdDeductionHPEnabled ?? this.isStdDeductionHPEnabled,
      isCessEnabled: isCessEnabled ?? this.isCessEnabled,
      isRebateEnabled: isRebateEnabled ?? this.isRebateEnabled,
      isLTCGExemption112AEnabled:
          isLTCGExemption112AEnabled ?? this.isLTCGExemption112AEnabled,
      isInsuranceExemptionEnabled:
          isInsuranceExemptionEnabled ?? this.isInsuranceExemptionEnabled,
      isInsuranceAggregateLimitEnabled: isInsuranceAggregateLimitEnabled ??
          this.isInsuranceAggregateLimitEnabled,
      isInsurancePremiumPercentEnabled: isInsurancePremiumPercentEnabled ??
          this.isInsurancePremiumPercentEnabled,
      isRetirementExemptionEnabled:
          isRetirementExemptionEnabled ?? this.isRetirementExemptionEnabled,
      isHPMaxInterestEnabled:
          isHPMaxInterestEnabled ?? this.isHPMaxInterestEnabled,
      isCGReinvestmentEnabled:
          isCGReinvestmentEnabled ?? this.isCGReinvestmentEnabled,
      isCGRatesEnabled: isCGRatesEnabled ?? this.isCGRatesEnabled,
      isAgriIncomeEnabled: isAgriIncomeEnabled ?? this.isAgriIncomeEnabled,
      advancedTagMappings: advancedTagMappings ?? this.advancedTagMappings,
      financialYearStartMonth:
          financialYearStartMonth ?? this.financialYearStartMonth,
      giftFromEmployerExemptionLimit:
          giftFromEmployerExemptionLimit ?? this.giftFromEmployerExemptionLimit,
      isGiftFromEmployerEnabled:
          isGiftFromEmployerEnabled ?? this.isGiftFromEmployerEnabled,
      is44ADEnabled: is44ADEnabled ?? this.is44ADEnabled,
      limit44AD: limit44AD ?? this.limit44AD,
      rate44AD: rate44AD ?? this.rate44AD,
      is44ADAEnabled: is44ADAEnabled ?? this.is44ADAEnabled,
      limit44ADA: limit44ADA ?? this.limit44ADA,
      rate44ADA: rate44ADA ?? this.rate44ADA,
    );
  }

  Map<String, dynamic> toMap() => {
        'currencyLimit10_10D': currencyLimit10_10D,
        'stdDeductionSalary': stdDeductionSalary,
        'stdExemption112A': stdExemption112A,
        'ltcgRateEquity': ltcgRateEquity,
        'stcgRate': stcgRate,
        'windowGainReinvest': windowGainReinvest,
        'tagMappings': tagMappings,
        // ... (rest is same, no changes needed for toMap as dynamic handles double)
        'limitGratuity': limitGratuity,
        'limitLeaveEncashment': limitLeaveEncashment,
        'slabs': slabs.map((e) => e.toMap()).toList(),
        'rebateLimit': rebateLimit,
        'cessRate': cessRate,
        'maxCGReinvestLimit': maxCGReinvestLimit,
        'maxHPDeductionLimit': maxHPDeductionLimit,
        'standardDeductionRateHP': standardDeductionRateHP,
        'limitInsuranceULIP': limitInsuranceULIP,
        'dateEffectiveULIP': dateEffectiveULIP.toIso8601String(),
        'limitInsuranceNonULIP': limitInsuranceNonULIP,
        'dateEffectiveNonULIP': dateEffectiveNonULIP.toIso8601String(),
        'customExemptions': customExemptions.map((e) => e.toMap()).toList(),
        'jurisdiction': jurisdiction,
        'cashGiftExemptionLimit': cashGiftExemptionLimit,
        'insurancePremiumRules':
            insurancePremiumRules.map((e) => e.toMap()).toList(),
        'isCashGiftExemptionEnabled': isCashGiftExemptionEnabled,
        'agricultureIncomeThreshold': agricultureIncomeThreshold,
        'agricultureBasicExemptionLimit': agricultureBasicExemptionLimit,
        'customJurisdictionName': customJurisdictionName,
        'isStdDeductionSalaryEnabled': isStdDeductionSalaryEnabled,
        'isStdDeductionHPEnabled': isStdDeductionHPEnabled,
        'isCessEnabled': isCessEnabled,
        'isRebateEnabled': isRebateEnabled,
        'isLTCGExemption112AEnabled': isLTCGExemption112AEnabled,
        'isInsuranceExemptionEnabled': isInsuranceExemptionEnabled,
        'isInsuranceAggregateLimitEnabled': isInsuranceAggregateLimitEnabled,
        'isInsurancePremiumPercentEnabled': isInsurancePremiumPercentEnabled,
        'isRetirementExemptionEnabled': isRetirementExemptionEnabled,
        'isHPMaxInterestEnabled': isHPMaxInterestEnabled,
        'isCGReinvestmentEnabled': isCGReinvestmentEnabled,
        'isCGRatesEnabled': isCGRatesEnabled,
        'isAgriIncomeEnabled': isAgriIncomeEnabled,
        'advancedTagMappings':
            advancedTagMappings.map((e) => e.toMap()).toList(),
        'financialYearStartMonth': financialYearStartMonth,
        'giftFromEmployerExemptionLimit': giftFromEmployerExemptionLimit,
        'isGiftFromEmployerEnabled': isGiftFromEmployerEnabled,
        'is44ADEnabled': is44ADEnabled,
        'limit44AD': limit44AD,
        'rate44AD': rate44AD,
        'is44ADAEnabled': is44ADAEnabled,
        'limit44ADA': limit44ADA,
        'rate44ADA': rate44ADA,
      };

  factory TaxRules.fromMap(Map<String, dynamic> m) {
    return TaxRules(
      currencyLimit10_10D:
          (m['currencyLimit10_10D'] as num?)?.toDouble() ?? 500000,
      stdDeductionSalary:
          (m['stdDeductionSalary'] as num?)?.toDouble() ?? 75000,
      stdExemption112A: (m['stdExemption112A'] as num?)?.toDouble() ?? 125000,
      ltcgRateEquity: (m['ltcgRateEquity'] as num?)?.toDouble() ?? 12.5,
      stcgRate: (m['stcgRate'] as num?)?.toDouble() ?? 20.0,
      windowGainReinvest: (m['windowGainReinvest'] as num?)?.toDouble() ?? 2.0,
      tagMappings: Map<String, String>.from(m['tagMappings'] ?? {}),
      limitGratuity: (m['limitGratuity'] as num?)?.toDouble() ?? 2000000,
      limitLeaveEncashment:
          (m['limitLeaveEncashment'] as num?)?.toDouble() ?? 2500000,
      slabs: (m['slabs'] as List?)
              ?.map((e) => TaxSlab.fromMap(Map<String, dynamic>.from(e)))
              .toList() ??
          [],
      rebateLimit: (m['rebateLimit'] as num?)?.toDouble() ?? 1200000,
      cessRate: (m['cessRate'] as num?)?.toDouble() ?? 4.0,
      maxCGReinvestLimit:
          (m['maxCGReinvestLimit'] as num?)?.toDouble() ?? 100000000,
      maxHPDeductionLimit:
          (m['maxHPDeductionLimit'] as num?)?.toDouble() ?? 200000,
      standardDeductionRateHP:
          (m['standardDeductionRateHP'] as num?)?.toDouble() ?? 30.0,
      limitInsuranceULIP:
          (m['limitInsuranceULIP'] as num?)?.toDouble() ?? 250000,
      dateEffectiveULIP: m['dateEffectiveULIP'] != null
          ? DateTime.parse(m['dateEffectiveULIP'])
          : null,
      limitInsuranceNonULIP:
          (m['limitInsuranceNonULIP'] as num?)?.toDouble() ?? 500000,
      dateEffectiveNonULIP: m['dateEffectiveNonULIP'] != null
          ? DateTime.parse(m['dateEffectiveNonULIP'])
          : null,
      customExemptions: (m['customExemptions'] as List?)
              ?.map(
                  (e) => TaxExemptionRule.fromMap(Map<String, dynamic>.from(e)))
              .toList() ??
          [],
      jurisdiction: m['jurisdiction'] ?? 'India',
      cashGiftExemptionLimit:
          (m['cashGiftExemptionLimit'] as num?)?.toDouble() ?? 50000,
      insurancePremiumRules: (m['insurancePremiumRules'] as List?)
              ?.map((e) =>
                  InsurancePremiumRule.fromMap(Map<String, dynamic>.from(e)))
              .toList() ??
          [],
      isCashGiftExemptionEnabled: m['isCashGiftExemptionEnabled'] ?? true,
      agricultureIncomeThreshold:
          (m['agricultureIncomeThreshold'] as num?)?.toDouble() ?? 5000,
      agricultureBasicExemptionLimit:
          (m['agricultureBasicExemptionLimit'] as num?)?.toDouble() ?? 400000,
      customJurisdictionName: m['customJurisdictionName'] ?? '',
      isStdDeductionSalaryEnabled: m['isStdDeductionSalaryEnabled'] ?? true,
      isStdDeductionHPEnabled: m['isStdDeductionHPEnabled'] ?? true,
      isCessEnabled: m['isCessEnabled'] ?? true,
      isRebateEnabled: m['isRebateEnabled'] ?? true,
      isLTCGExemption112AEnabled: m['isLTCGExemption112AEnabled'] ?? true,
      isInsuranceExemptionEnabled: m['isInsuranceExemptionEnabled'] ?? true,
      isInsuranceAggregateLimitEnabled:
          m['isInsuranceAggregateLimitEnabled'] ?? true,
      isInsurancePremiumPercentEnabled:
          m['isInsurancePremiumPercentEnabled'] ?? true,
      isRetirementExemptionEnabled: m['isRetirementExemptionEnabled'] ?? true,
      isHPMaxInterestEnabled: m['isHPMaxInterestEnabled'] ?? true,
      isCGReinvestmentEnabled: m['isCGReinvestmentEnabled'] ?? true,
      isCGRatesEnabled: m['isCGRatesEnabled'] ?? true,
      isAgriIncomeEnabled: m['isAgriIncomeEnabled'] ?? true,
      advancedTagMappings: (m['advancedTagMappings'] as List?)
              ?.map((e) => TaxMappingRule.fromMap(Map<String, dynamic>.from(e)))
              .toList() ??
          [],
      is44ADEnabled: m['is44ADEnabled'] ?? true,
      limit44AD: (m['limit44AD'] as num?)?.toDouble() ?? 20000000,
      rate44AD: (m['rate44AD'] as num?)?.toDouble() ?? 6.0,
      is44ADAEnabled: m['is44ADAEnabled'] ?? true,
      limit44ADA: (m['limit44ADA'] as num?)?.toDouble() ?? 5000000,
      rate44ADA: (m['rate44ADA'] as num?)?.toDouble() ?? 50.0,
    );
  }
}
