import 'package:hive_ce/hive.dart';

part 'tax_data_models.g.dart';

@HiveType(typeId: 210)
class SalaryDetails {
  @HiveField(0)
  final double grossSalary;
  @HiveField(1)
  final double npsEmployer; // 80CCD(2)
  @HiveField(2)
  final double leaveEncashment; // 10(10AA)
  @HiveField(3)
  final double gratuity; // 10(10)

  @HiveField(4)
  final Map<int, double>
      monthlyGross; // 1=Jan, 12=Dec (or 4=Apr? Let's use 1-12 calendar month)

  @HiveField(5)
  final double giftsFromEmployer;

  @HiveField(6)
  final Map<String, double> customExemptions;

  @HiveField(7)
  final List<SalaryStructure> history;

  @HiveField(8)
  final Map<int, double> netSalaryReceived;

  @HiveField(9)
  final List<CustomDeduction> independentDeductions;

  @HiveField(10)
  final List<CustomAllowance> independentAllowances;

  @HiveField(11)
  final List<CustomExemption> independentExemptions;

  const SalaryDetails({
    this.grossSalary = 0,
    this.npsEmployer = 0,
    this.leaveEncashment = 0,
    this.gratuity = 0,
    this.monthlyGross = const {},
    this.giftsFromEmployer = 0,
    this.customExemptions = const {},
    this.history = const [],
    this.netSalaryReceived = const {},
    this.independentDeductions = const [],
    this.independentAllowances = const [],
    this.independentExemptions = const [],
  });

  SalaryDetails copyWith({
    double? grossSalary,
    double? npsEmployer,
    double? leaveEncashment,
    double? gratuity,
    Map<int, double>? monthlyGross,
    double? giftsFromEmployer,
    Map<String, double>? customExemptions,
    List<SalaryStructure>? history,
    Map<int, double>? netSalaryReceived,
    List<CustomDeduction>? independentDeductions,
    List<CustomAllowance>? independentAllowances,
    List<CustomExemption>? independentExemptions,
  }) {
    return SalaryDetails(
      grossSalary: grossSalary ?? this.grossSalary,
      npsEmployer: npsEmployer ?? this.npsEmployer,
      leaveEncashment: leaveEncashment ?? this.leaveEncashment,
      gratuity: gratuity ?? this.gratuity,
      monthlyGross: monthlyGross ?? this.monthlyGross,
      giftsFromEmployer: giftsFromEmployer ?? this.giftsFromEmployer,
      customExemptions: customExemptions ?? this.customExemptions,
      history: history ?? this.history,
      netSalaryReceived: netSalaryReceived ?? this.netSalaryReceived,
      independentDeductions:
          independentDeductions ?? this.independentDeductions,
      independentAllowances:
          independentAllowances ?? this.independentAllowances,
      independentExemptions:
          independentExemptions ?? this.independentExemptions,
    );
  }

  Map<String, dynamic> toMap() => {
        'grossSalary': grossSalary,
        'npsEmployer': npsEmployer,
        'leaveEncashment': leaveEncashment,
        'gratuity': gratuity,
        'monthlyGross': monthlyGross.map((k, v) => MapEntry(k.toString(), v)),
        'giftsFromEmployer': giftsFromEmployer,
        'customExemptions': customExemptions,
        'history': history.map((e) => e.toMap()).toList(),
        'netSalaryReceived':
            netSalaryReceived.map((k, v) => MapEntry(k.toString(), v)),
        'independentDeductions':
            independentDeductions.map((e) => e.toMap()).toList(),
        'independentAllowances':
            independentAllowances.map((e) => e.toMap()).toList(),
        'independentExemptions':
            independentExemptions.map((e) => e.toMap()).toList(),
      };

  factory SalaryDetails.fromMap(Map<String, dynamic> m) => SalaryDetails(
        grossSalary: (m['grossSalary'] as num?)?.toDouble() ?? 0,
        npsEmployer: (m['npsEmployer'] as num?)?.toDouble() ?? 0,
        leaveEncashment: (m['leaveEncashment'] as num?)?.toDouble() ?? 0,
        gratuity: (m['gratuity'] as num?)?.toDouble() ?? 0,
        monthlyGross: (m['monthlyGross'] as Map?)?.map((k, v) =>
                MapEntry(int.parse(k.toString()), (v as num).toDouble())) ??
            {},
        giftsFromEmployer: (m['giftsFromEmployer'] as num?)?.toDouble() ?? 0,
        customExemptions: Map<String, double>.from(m['customExemptions'] ?? {}),
        history: (m['history'] as List?)
                ?.map((e) =>
                    SalaryStructure.fromMap(Map<String, dynamic>.from(e)))
                .toList() ??
            [],
        netSalaryReceived: (m['netSalaryReceived'] as Map?)?.map((k, v) =>
                MapEntry(int.parse(k.toString()), (v as num).toDouble())) ??
            {},
        independentDeductions: (m['independentDeductions'] as List?)
                ?.map((e) =>
                    CustomDeduction.fromMap(Map<String, dynamic>.from(e)))
                .toList() ??
            [],
        independentAllowances: (m['independentAllowances'] as List?)
                ?.map((e) =>
                    CustomAllowance.fromMap(Map<String, dynamic>.from(e)))
                .toList() ??
            [],
        independentExemptions: (m['independentExemptions'] as List?)
                ?.map((e) =>
                    CustomExemption.fromMap(Map<String, dynamic>.from(e)))
                .toList() ??
            [],
      );
}

@HiveType(typeId: 211)
class HouseProperty {
  @HiveField(0)
  final String name;
  @HiveField(1)
  final bool isSelfOccupied;
  @HiveField(2)
  final double rentReceived;
  @HiveField(3)
  final double municipalTaxes;
  @HiveField(4)
  final double interestOnLoan;
  @HiveField(5)
  final String? loanId; // ID of the Loan object to sync interest from

  const HouseProperty({
    required this.name,
    this.isSelfOccupied = true,
    this.rentReceived = 0,
    this.municipalTaxes = 0,
    this.interestOnLoan = 0,
    this.loanId,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'isSelfOccupied': isSelfOccupied,
        'rentReceived': rentReceived,
        'municipalTaxes': municipalTaxes,
        'interestOnLoan': interestOnLoan,
        'loanId': loanId,
      };

  factory HouseProperty.fromMap(Map<String, dynamic> m) => HouseProperty(
        name: m['name'] ?? '',
        isSelfOccupied: m['isSelfOccupied'] ?? true,
        rentReceived: (m['rentReceived'] as num?)?.toDouble() ?? 0,
        municipalTaxes: (m['municipalTaxes'] as num?)?.toDouble() ?? 0,
        interestOnLoan: (m['interestOnLoan'] as num?)?.toDouble() ?? 0,
        loanId: m['loanId'],
      );
}

@HiveType(typeId: 212)
enum BusinessType {
  @HiveField(0)
  regular,
  @HiveField(1)
  section44AD,
  @HiveField(2)
  section44ADA,
}

extension BusinessTypeExt on BusinessType {
  String toHumanReadable() {
    switch (this) {
      case BusinessType.regular:
        return 'Regular (Actual Profit)';
      case BusinessType.section44AD:
        return 'Section 44AD (Presumptive - 6%)';
      case BusinessType.section44ADA:
        return 'Section 44ADA (Presumptive - 50%)';
    }
  }
}

@HiveType(typeId: 213)
class BusinessEntity {
  @HiveField(0)
  final String name;
  @HiveField(1)
  final BusinessType type;
  @HiveField(2)
  final double grossTurnover;
  @HiveField(3)
  final double netIncome;
  @HiveField(4)
  final double presumptiveIncome;

  const BusinessEntity({
    required this.name,
    this.type = BusinessType.regular,
    this.grossTurnover = 0,
    this.netIncome = 0,
    this.presumptiveIncome = 0,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'type': type.index,
        'grossTurnover': grossTurnover,
        'netIncome': netIncome,
        'presumptiveIncome': presumptiveIncome,
      };

  factory BusinessEntity.fromMap(Map<String, dynamic> m) => BusinessEntity(
        name: m['name'] ?? '',
        type: BusinessType.values[m['type'] ?? 0],
        grossTurnover: (m['grossTurnover'] as num?)?.toDouble() ?? 0,
        netIncome: (m['netIncome'] as num?)?.toDouble() ?? 0,
        presumptiveIncome: (m['presumptiveIncome'] as num?)?.toDouble() ?? 0,
      );
}

@HiveType(typeId: 214)
enum AssetType {
  @HiveField(0)
  equityShares, // STCG 15%, LTCG 12.5% (112A)
  @HiveField(1)
  residentialProperty, // LTCG 20% indexation removed? New rules.
  @HiveField(2)
  agriculturalLand,
  @HiveField(3)
  other // Gold, Debt Funds etc
}

extension AssetTypeExtension on AssetType {
  String toHumanReadable() {
    switch (this) {
      case AssetType.equityShares:
        return 'Equity Shares / Eq. MFs (112A)';
      case AssetType.residentialProperty:
        return 'Residential Property';
      case AssetType.agriculturalLand:
        return 'Agricultural Land';
      case AssetType.other:
        return 'Other Assets';
    }
  }
}

@HiveType(typeId: 215)
enum ReinvestmentType {
  @HiveField(0)
  none,
  @HiveField(1)
  residentialProperty, // Section 54 / 54F
  @HiveField(2)
  agriculturalLand, // Section 54B
  @HiveField(3)
  bonds54EC // Section 54EC
}

extension ReinvestmentTypeExtension on ReinvestmentType {
  String toHumanReadable() {
    switch (this) {
      case ReinvestmentType.none:
        return 'None';
      case ReinvestmentType.residentialProperty:
        return 'Residential Property (Sec 54/54F)';
      case ReinvestmentType.agriculturalLand:
        return 'Agricultural Land (Sec 54B)';
      case ReinvestmentType.bonds54EC:
        return 'Capital Gains Bonds (Sec 54EC)';
    }
  }
}

@HiveType(typeId: 216)
class CapitalGainEntry {
  @HiveField(0)
  final String description;
  @HiveField(1)
  final AssetType matchAssetType;
  @HiveField(2)
  final bool isLTCG;
  @HiveField(3)
  final double saleAmount;
  @HiveField(4)
  final double costOfAcquisition; // Or Indexed Cost
  @HiveField(5)
  final DateTime gainDate;

  // Reinvestment
  @HiveField(6)
  final double reinvestedAmount;
  @HiveField(7)
  final ReinvestmentType matchReinvestType;
  @HiveField(8)
  final DateTime? reinvestDate;

  @HiveField(9)
  final bool intendToReinvest;

  // Computed helpers
  double get capitalGainAmount => saleAmount - costOfAcquisition;

  const CapitalGainEntry({
    this.description = '',
    this.matchAssetType = AssetType.other,
    this.isLTCG = false,
    this.saleAmount = 0,
    this.costOfAcquisition = 0,
    required this.gainDate,
    this.reinvestedAmount = 0,
    this.matchReinvestType = ReinvestmentType.none,
    this.reinvestDate,
    this.intendToReinvest = false,
  });

  Map<String, dynamic> toMap() => {
        'description': description,
        'matchAssetType': matchAssetType.index,
        'isLTCG': isLTCG,
        'saleAmount': saleAmount,
        'costOfAcquisition': costOfAcquisition,
        'gainDate': gainDate.toIso8601String(),
        'reinvestedAmount': reinvestedAmount,
        'matchReinvestType': matchReinvestType.index,
        'reinvestDate': reinvestDate?.toIso8601String(),
        'intendToReinvest': intendToReinvest,
      };

  factory CapitalGainEntry.fromMap(Map<String, dynamic> m) => CapitalGainEntry(
        description: m['description'] ?? '',
        matchAssetType: AssetType.values[m['matchAssetType'] ?? 0],
        isLTCG: m['isLTCG'] ?? false,
        saleAmount: (m['saleAmount'] as num?)?.toDouble() ?? 0,
        costOfAcquisition: (m['costOfAcquisition'] as num?)?.toDouble() ?? 0,
        gainDate: DateTime.parse(m['gainDate']),
        reinvestedAmount: (m['reinvestedAmount'] as num?)?.toDouble() ?? 0,
        matchReinvestType: ReinvestmentType.values[m['matchReinvestType'] ?? 0],
        reinvestDate: m['reinvestDate'] != null
            ? DateTime.parse(m['reinvestDate'])
            : null,
        intendToReinvest: m['intendToReinvest'] ?? false,
      );
}

@HiveType(typeId: 217)
class OtherIncome {
  @HiveField(0)
  final String name;
  @HiveField(1)
  final double amount;
  @HiveField(2)
  final String type; // e.g., 'Dividend', 'Interest'
  @HiveField(3)
  final String subtype; // 'interest', 'gain', 'other'
  @HiveField(4)
  final String? linkedExemptionId;

  const OtherIncome({
    required this.name,
    required this.amount,
    this.type = 'Other',
    this.subtype = 'other',
    this.linkedExemptionId,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'amount': amount,
        'type': type,
        'subtype': subtype,
        'linkedExemptionId': linkedExemptionId,
      };

  factory OtherIncome.fromMap(Map<String, dynamic> m) => OtherIncome(
        name: m['name'] ?? '',
        amount: (m['amount'] as num?)?.toDouble() ?? 0,
        type: m['type'] ?? 'Other',
        subtype: m['subtype'] ?? 'other',
        linkedExemptionId: m['linkedExemptionId'],
      );
}

@HiveType(typeId: 223)
enum PayoutFrequency {
  @HiveField(0)
  monthly,
  @HiveField(1)
  quarterly,
  @HiveField(2)
  trimester, // Every 4 months
  @HiveField(3)
  halfYearly,
  @HiveField(4)
  annually,
  @HiveField(5)
  custom,
}

@HiveType(typeId: 220)
class SalaryStructure {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final DateTime effectiveDate;
  @HiveField(2)
  final double monthlyBasic;
  @HiveField(3)
  final double monthlyFixedAllowances;
  @HiveField(4)
  final double monthlyPerformancePay;
  @HiveField(5)
  final double annualVariablePay;
  @HiveField(6)
  final List<CustomAllowance> customAllowances;

  @HiveField(7)
  final double monthlyEmployeePF;
  @HiveField(9)
  final double monthlyGratuity;
  @HiveField(10)
  final List<CustomDeduction> customDeductions;

  // Performance/Variable Pay Config
  @HiveField(11)
  final PayoutFrequency performancePayFrequency;
  @HiveField(12)
  final int? performancePayStartMonth; // 1-12
  @HiveField(13)
  final List<int>? performancePayCustomMonths;

  @HiveField(14)
  final PayoutFrequency variablePayFrequency;
  @HiveField(15)
  final int? variablePayStartMonth;
  @HiveField(16)
  final List<int>? variablePayCustomMonths;

  @HiveField(17)
  final bool isPerformancePayPartial;
  @HiveField(18)
  final Map<int, double> performancePayAmounts; // 1-12 calendar month

  @HiveField(19)
  final bool isVariablePayPartial;
  @HiveField(20)
  final Map<int, double> variablePayAmounts; // 1-12 calendar month
  @HiveField(21)
  final List<int> stoppedMonths;

  const SalaryStructure({
    required this.id,
    required this.effectiveDate,
    this.monthlyBasic = 0,
    this.monthlyFixedAllowances = 0,
    this.monthlyPerformancePay = 0,
    this.annualVariablePay = 0,
    this.customAllowances = const [],
    this.performancePayFrequency = PayoutFrequency.monthly,
    this.performancePayStartMonth,
    this.performancePayCustomMonths,
    this.variablePayFrequency = PayoutFrequency.annually,
    this.variablePayStartMonth = 3, // Default March
    this.variablePayCustomMonths,
    this.isPerformancePayPartial = false,
    this.performancePayAmounts = const {},
    this.isVariablePayPartial = false,
    this.variablePayAmounts = const {},
    this.stoppedMonths = const [],
    this.monthlyEmployeePF = 0,
    this.monthlyGratuity = 0,
    this.customDeductions = const [],
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'effectiveDate': effectiveDate.toIso8601String(),
        'monthlyBasic': monthlyBasic,
        'monthlyFixedAllowances': monthlyFixedAllowances,
        'monthlyPerformancePay': monthlyPerformancePay,
        'annualVariablePay': annualVariablePay,
        'customAllowances': customAllowances.map((e) => e.toMap()).toList(),
        'monthlyEmployeePF': monthlyEmployeePF,
        'monthlyGratuity': monthlyGratuity,
        'customDeductions': customDeductions.map((e) => e.toMap()).toList(),
        'performancePayFrequency': performancePayFrequency.index,
        'performancePayStartMonth': performancePayStartMonth,
        'performancePayCustomMonths': performancePayCustomMonths,
        'variablePayFrequency': variablePayFrequency.index,
        'variablePayStartMonth': variablePayStartMonth,
        'variablePayCustomMonths': variablePayCustomMonths,
        'isPerformancePayPartial': isPerformancePayPartial,
        'performancePayAmounts':
            performancePayAmounts.map((k, v) => MapEntry(k.toString(), v)),
        'isVariablePayPartial': isVariablePayPartial,
        'variablePayAmounts':
            variablePayAmounts.map((k, v) => MapEntry(k.toString(), v)),
        'stoppedMonths': stoppedMonths,
      };

  factory SalaryStructure.fromMap(Map<String, dynamic> m) => SalaryStructure(
        id: m['id'] ?? '',
        effectiveDate: DateTime.parse(m['effectiveDate']),
        monthlyBasic: (m['monthlyBasic'] as num?)?.toDouble() ?? 0,
        monthlyFixedAllowances:
            (m['monthlyFixedAllowances'] as num?)?.toDouble() ?? 0,
        monthlyPerformancePay:
            (m['monthlyPerformancePay'] as num?)?.toDouble() ?? 0,
        annualVariablePay: (m['annualVariablePay'] as num?)?.toDouble() ?? 0,
        customAllowances: (m['customAllowances'] as List?)
                ?.map((e) =>
                    CustomAllowance.fromMap(Map<String, dynamic>.from(e)))
                .toList() ??
            [],
        monthlyEmployeePF: (m['monthlyEmployeePF'] as num?)?.toDouble() ?? 0,
        monthlyGratuity: (m['monthlyGratuity'] as num?)?.toDouble() ?? 0,
        customDeductions: (m['customDeductions'] as List?)
                ?.map((e) =>
                    CustomDeduction.fromMap(Map<String, dynamic>.from(e)))
                .toList() ??
            [],
        performancePayFrequency: PayoutFrequency
            .values[m['performancePayFrequency'] ?? m['payoutFrequency'] ?? 0],
        performancePayStartMonth: m['performancePayStartMonth'],
        performancePayCustomMonths:
            (m['performancePayCustomMonths'] as List?)?.cast<int>(),
        variablePayFrequency:
            PayoutFrequency.values[m['variablePayFrequency'] ?? 0],
        variablePayStartMonth: m['variablePayStartMonth'],
        variablePayCustomMonths:
            (m['variablePayCustomMonths'] as List?)?.cast<int>(),
        isPerformancePayPartial: m['isPerformancePayPartial'] ?? false,
        performancePayAmounts: (m['performancePayAmounts'] as Map?)?.map(
                (k, v) =>
                    MapEntry(int.parse(k.toString()), (v as num).toDouble())) ??
            {},
        isVariablePayPartial: m['isVariablePayPartial'] ?? false,
        variablePayAmounts: (m['variablePayAmounts'] as Map?)?.map((k, v) =>
                MapEntry(int.parse(k.toString()), (v as num).toDouble())) ??
            {},
        stoppedMonths: (m['stoppedMonths'] as List?)?.cast<int>() ?? [],
      );

  double get estimatedMonthlyGross {
    double total = monthlyBasic + monthlyFixedAllowances;
    final now = DateTime.now();
    final m = now.month;
    if (stoppedMonths.contains(m)) return 0;

    // Performance Pay Estimator
    if (isPerformancePayPartial) {
      total += (performancePayAmounts[m] ?? 0.0);
    } else {
      total += monthlyPerformancePay;
    }

    // Variable Pay (Annual Input)
    if (isVariablePayPartial) {
      total += (variablePayAmounts[m] ?? 0.0);
    } else {
      total += (annualVariablePay / 12);
    }

    total += customAllowances.fold(0.0, (sum, item) => sum + item.payoutAmount);

    return total;
  }

  double calculateContribution(int month, int fyStartMonth) {
    if (stoppedMonths.contains(month)) return 0;
    double monthlyGross = monthlyBasic + monthlyFixedAllowances;

    if (SalaryStructure.isPayoutMonth(month, performancePayFrequency,
        performancePayStartMonth, performancePayCustomMonths)) {
      if (isPerformancePayPartial) {
        monthlyGross += (performancePayAmounts[month] ?? 0.0);
      } else {
        monthlyGross += monthlyPerformancePay;
      }
    }

    if (SalaryStructure.isPayoutMonth(month, variablePayFrequency,
        variablePayStartMonth, variablePayCustomMonths)) {
      if (isVariablePayPartial) {
        monthlyGross += (variablePayAmounts[month] ?? 0.0);
      } else {
        double annualVar = annualVariablePay;
        if (variablePayFrequency == PayoutFrequency.monthly) {
          monthlyGross += annualVar / 12;
        } else if (variablePayFrequency == PayoutFrequency.annually) {
          monthlyGross += annualVar;
        } else if (variablePayFrequency == PayoutFrequency.halfYearly) {
          monthlyGross += annualVar / 2;
        } else if (variablePayFrequency == PayoutFrequency.quarterly) {
          monthlyGross += annualVar / 4;
        } else if (variablePayFrequency == PayoutFrequency.trimester) {
          monthlyGross += annualVar / 3;
        } else if (variablePayFrequency == PayoutFrequency.custom) {
          int count = variablePayCustomMonths?.length ?? 1;
          if (count == 0) count = 1;
          monthlyGross += annualVar / count;
        }
      }
    }

    // Custom Allowances
    for (final allowance in customAllowances) {
      if (SalaryStructure.isPayoutMonth(month, allowance.frequency,
          allowance.startMonth, allowance.customMonths)) {
        double amount = allowance.payoutAmount;
        if (allowance.isPartial) {
          amount = allowance.partialAmounts[month] ?? 0.0;
        }
        monthlyGross += amount;
      }
    }

    return monthlyGross;
  }

  static bool isPayoutMonth(int currentMonth, PayoutFrequency freq,
      int? startMonth, List<int>? customMonths) {
    if (freq == PayoutFrequency.monthly) return true;
    if (freq == PayoutFrequency.annually) {
      return currentMonth == (startMonth ?? 3);
    }
    if (freq == PayoutFrequency.halfYearly) {
      int sVal = startMonth ?? 3;
      int second = (sVal + 6) > 12 ? (sVal + 6 - 12) : (sVal + 6);
      return currentMonth == sVal || currentMonth == second;
    }
    if (freq == PayoutFrequency.quarterly) {
      int sVal = startMonth ?? 3;
      List<int> months = [
        sVal,
        (sVal + 3) > 12 ? (sVal + 3 - 12) : (sVal + 3),
        (sVal + 6) > 12 ? (sVal + 6 - 12) : (sVal + 6),
        (sVal + 9) > 12 ? (sVal + 9 - 12) : (sVal + 9),
      ];
      return months.contains(currentMonth);
    }
    if (freq == PayoutFrequency.trimester) {
      int sVal = startMonth ?? 3;
      List<int> months = [
        sVal,
        (sVal + 4) > 12 ? (sVal + 4 - 12) : (sVal + 4),
        (sVal + 8) > 12 ? (sVal + 8 - 12) : (sVal + 8),
      ];
      return months.contains(currentMonth);
    }
    if (freq == PayoutFrequency.custom) {
      return customMonths?.contains(currentMonth) ?? false;
    }
    return false;
  }

  SalaryStructure copyWith({
    String? id,
    DateTime? effectiveDate,
    double? monthlyBasic,
    double? monthlyFixedAllowances,
    double? monthlyPerformancePay,
    double? annualVariablePay,
    List<CustomAllowance>? customAllowances,
    PayoutFrequency? performancePayFrequency,
    int? performancePayStartMonth,
    List<int>? performancePayCustomMonths,
    PayoutFrequency? variablePayFrequency,
    int? variablePayStartMonth,
    List<int>? variablePayCustomMonths,
    bool? isPerformancePayPartial,
    Map<int, double>? performancePayAmounts,
    bool? isVariablePayPartial,
    Map<int, double>? variablePayAmounts,
    List<int>? stoppedMonths,
    double? monthlyEmployeePF,
    double? monthlyGratuity,
    List<CustomDeduction>? customDeductions,
  }) {
    return SalaryStructure(
      id: id ?? this.id,
      effectiveDate: effectiveDate ?? this.effectiveDate,
      monthlyBasic: monthlyBasic ?? this.monthlyBasic,
      monthlyFixedAllowances:
          monthlyFixedAllowances ?? this.monthlyFixedAllowances,
      monthlyPerformancePay:
          monthlyPerformancePay ?? this.monthlyPerformancePay,
      annualVariablePay: annualVariablePay ?? this.annualVariablePay,
      customAllowances: customAllowances ?? this.customAllowances,
      performancePayFrequency:
          performancePayFrequency ?? this.performancePayFrequency,
      performancePayStartMonth:
          performancePayStartMonth ?? this.performancePayStartMonth,
      performancePayCustomMonths:
          performancePayCustomMonths ?? this.performancePayCustomMonths,
      variablePayFrequency: variablePayFrequency ?? this.variablePayFrequency,
      variablePayStartMonth:
          variablePayStartMonth ?? this.variablePayStartMonth,
      variablePayCustomMonths:
          variablePayCustomMonths ?? this.variablePayCustomMonths,
      isPerformancePayPartial:
          isPerformancePayPartial ?? this.isPerformancePayPartial,
      performancePayAmounts:
          performancePayAmounts ?? this.performancePayAmounts,
      isVariablePayPartial: isVariablePayPartial ?? this.isVariablePayPartial,
      variablePayAmounts: variablePayAmounts ?? this.variablePayAmounts,
      stoppedMonths: stoppedMonths ?? this.stoppedMonths,
      monthlyEmployeePF: monthlyEmployeePF ?? this.monthlyEmployeePF,
      monthlyGratuity: monthlyGratuity ?? this.monthlyGratuity,
      customDeductions: customDeductions ?? this.customDeductions,
    );
  }
}

@HiveType(typeId: 222)
class CustomDeduction {
  @HiveField(0)
  final String name;
  @HiveField(1)
  final double amount;
  @HiveField(2)
  final bool isTaxable; // If true, reduces taxable gross income

  @HiveField(3)
  final PayoutFrequency frequency;
  @HiveField(4)
  final int? startMonth;
  @HiveField(5)
  final List<int>? customMonths;
  @HiveField(6)
  final bool isPartial;
  @HiveField(7)
  final Map<int, double> partialAmounts;

  const CustomDeduction({
    required this.name,
    required this.amount,
    this.isTaxable = false,
    this.frequency = PayoutFrequency.monthly,
    this.startMonth,
    this.customMonths,
    this.isPartial = false,
    this.partialAmounts = const {},
  });

  CustomDeduction copyWith({
    String? name,
    double? amount,
    bool? isTaxable,
    PayoutFrequency? frequency,
    int? startMonth,
    List<int>? customMonths,
    bool? isPartial,
    Map<int, double>? partialAmounts,
  }) {
    return CustomDeduction(
      name: name ?? this.name,
      amount: amount ?? this.amount,
      isTaxable: isTaxable ?? this.isTaxable,
      frequency: frequency ?? this.frequency,
      startMonth: startMonth ?? this.startMonth,
      customMonths: customMonths ?? this.customMonths,
      isPartial: isPartial ?? this.isPartial,
      partialAmounts: partialAmounts ?? this.partialAmounts,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'amount': amount,
        'isTaxable': isTaxable,
        'frequency': frequency.index,
        'startMonth': startMonth,
        'customMonths': customMonths,
        'isPartial': isPartial,
        'partialAmounts':
            partialAmounts.map((k, v) => MapEntry(k.toString(), v)),
      };

  factory CustomDeduction.fromMap(Map<String, dynamic> m) => CustomDeduction(
        name: m['name'] ?? '',
        amount: (m['amount'] as num?)?.toDouble() ?? 0,
        isTaxable: m['isTaxable'] ?? false,
        frequency: PayoutFrequency.values[m['frequency'] ?? 0],
        startMonth: m['startMonth'],
        customMonths: (m['customMonths'] as List?)?.cast<int>(),
        isPartial: m['isPartial'] ?? false,
        partialAmounts: (m['partialAmounts'] as Map?)?.map((k, v) =>
                MapEntry(int.parse(k.toString()), (v as num).toDouble())) ??
            {},
      );
}

@HiveType(typeId: 221)
class CustomAllowance {
  @HiveField(0)
  final String name;
  @HiveField(1)
  final double payoutAmount; // Amount paid in the payout month
  @HiveField(2)
  final bool isPartial;

  @HiveField(3)
  final PayoutFrequency frequency;
  @HiveField(4)
  final int? startMonth;
  @HiveField(5)
  final List<int>? customMonths;
  @HiveField(6)
  final Map<int, double> partialAmounts;

  const CustomAllowance({
    required this.name,
    required this.payoutAmount,
    this.isPartial = false,
    this.frequency = PayoutFrequency.monthly,
    this.startMonth,
    this.customMonths,
    this.partialAmounts = const {},
  });

  CustomAllowance copyWith({
    String? name,
    double? payoutAmount,
    bool? isPartial,
    PayoutFrequency? frequency,
    int? startMonth,
    List<int>? customMonths,
    Map<int, double>? partialAmounts,
  }) {
    return CustomAllowance(
      name: name ?? this.name,
      payoutAmount: payoutAmount ?? this.payoutAmount,
      isPartial: isPartial ?? this.isPartial,
      frequency: frequency ?? this.frequency,
      startMonth: startMonth ?? this.startMonth,
      customMonths: customMonths ?? this.customMonths,
      partialAmounts: partialAmounts ?? this.partialAmounts,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'payoutAmount': payoutAmount,
        'isPartial': isPartial,
        'frequency': frequency.index,
        'startMonth': startMonth,
        'customMonths': customMonths,
        'partialAmounts':
            partialAmounts.map((k, v) => MapEntry(k.toString(), v)),
      };

  factory CustomAllowance.fromMap(Map<String, dynamic> m) => CustomAllowance(
        name: m['name'] ?? '',
        payoutAmount: (m['payoutAmount'] as num?)?.toDouble() ??
            (m['monthlyAmount'] as num?)?.toDouble() ??
            0,
        isPartial: m['isPartial'] ?? false,
        frequency: PayoutFrequency.values[m['frequency'] ?? 0],
        startMonth: m['startMonth'],
        customMonths: (m['customMonths'] as List?)?.cast<int>(),
        partialAmounts: (m['partialAmounts'] as Map?)?.map((k, v) =>
                MapEntry(int.parse(k.toString()), (v as num).toDouble())) ??
            {},
      );
}

@HiveType(typeId: 218)
class DividendIncome {
  @HiveField(0)
  final double amountQ1; // Apr - Jun 15
  @HiveField(1)
  final double amountQ2; // Jun 16 - Sep 15
  @HiveField(2)
  final double amountQ3; // Sep 16 - Dec 15
  @HiveField(3)
  final double amountQ4; // Dec 16 - Mar 15
  @HiveField(4)
  final double amountQ5; // Mar 16 - Mar 31

  double get grossDividend =>
      amountQ1 + amountQ2 + amountQ3 + amountQ4 + amountQ5;

  const DividendIncome({
    this.amountQ1 = 0,
    this.amountQ2 = 0,
    this.amountQ3 = 0,
    this.amountQ4 = 0,
    this.amountQ5 = 0,
  });

  Map<String, dynamic> toMap() => {
        'amountQ1': amountQ1,
        'amountQ2': amountQ2,
        'amountQ3': amountQ3,
        'amountQ4': amountQ4,
        'amountQ5': amountQ5,
      };

  factory DividendIncome.fromMap(Map<String, dynamic> m) => DividendIncome(
        amountQ1: (m['amountQ1'] as num?)?.toDouble() ?? 0,
        amountQ2: (m['amountQ2'] as num?)?.toDouble() ?? 0,
        amountQ3: (m['amountQ3'] as num?)?.toDouble() ?? 0,
        amountQ4: (m['amountQ4'] as num?)?.toDouble() ?? 0,
        amountQ5: (m['amountQ5'] as num?)?.toDouble() ?? 0,
      );
}

@HiveType(typeId: 219)
class TaxPaymentEntry {
  @HiveField(0)
  final double amount;
  @HiveField(1)
  final DateTime date;
  @HiveField(2)
  final String source; // e.g. 'Payroll', 'Bank', 'Car Dealer'
  @HiveField(3)
  final String description;

  const TaxPaymentEntry({
    required this.amount,
    required this.date,
    this.source = '',
    this.description = '',
  });

  Map<String, dynamic> toMap() => {
        'date': date.toIso8601String(),
        'amount': amount,
        'description': description,
        'source': source,
      };

  factory TaxPaymentEntry.fromMap(Map<String, dynamic> m) => TaxPaymentEntry(
        date: DateTime.parse(m['date']),
        amount: (m['amount'] as num?)?.toDouble() ?? 0,
        description: m['description'] ?? '',
        source: m['source'] ?? '',
      );
}

extension TaxStringHelpers on String {
  String toHumanReadable() {
    if (isEmpty) return '';

    // Specialized mappings for tax heads/tags
    switch (this) {
      case 'salary':
        return 'Salary';
      case 'houseProp':
        return 'House Property';
      case 'business':
        return 'Business / Profession';
      case 'capitalGain':
        return 'Capital Gain';
      case 'otherIncome':
        return 'Other Sources';
      case 'ltcg':
        return 'LTCG';
      case 'stcg':
        return 'STCG';
      case 'taxSaving':
        return 'Tax Saving';
      case 'directTax':
        return 'Direct Tax';
      case 'budgetFree':
        return 'Budget Free';
      case 'taxFree':
        return 'Tax Free';
    }

    // Handle camelCase: 'equityShares' -> 'Equity Shares'
    final exp = RegExp(r'(?<=[a-z])[A-Z]');
    String result = replaceAllMapped(exp, (m) => ' ${m.group(0)}');
    // Capitalize first letter
    result = result[0].toUpperCase() + result.substring(1);
    return result;
  }
}

@HiveType(typeId: 224)
class CustomExemption {
  @HiveField(0)
  final String name;
  @HiveField(1)
  final double amount;

  const CustomExemption({required this.name, required this.amount});

  CustomExemption copyWith({String? name, double? amount}) {
    return CustomExemption(
      name: name ?? this.name,
      amount: amount ?? this.amount,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'amount': amount,
      };

  factory CustomExemption.fromMap(Map<String, dynamic> m) => CustomExemption(
        name: m['name'] ?? '',
        amount: (m['amount'] as num?)?.toDouble() ?? 0,
      );
}
