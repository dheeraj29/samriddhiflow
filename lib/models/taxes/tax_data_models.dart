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

  const SalaryDetails({
    this.grossSalary = 0,
    this.npsEmployer = 0,
    this.leaveEncashment = 0,
    this.gratuity = 0,
    this.monthlyGross = const {},
  });

  SalaryDetails copyWith({
    double? grossSalary,
    double? npsEmployer,
    double? leaveEncashment,
    double? gratuity,
    Map<int, double>? monthlyGross,
  }) {
    return SalaryDetails(
      grossSalary: grossSalary ?? this.grossSalary,
      npsEmployer: npsEmployer ?? this.npsEmployer,
      leaveEncashment: leaveEncashment ?? this.leaveEncashment,
      gratuity: gratuity ?? this.gratuity,
      monthlyGross: monthlyGross ?? this.monthlyGross,
    );
  }
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
  });
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

  const OtherIncome({
    required this.name,
    required this.amount,
    this.type = 'Other',
    this.subtype = 'other',
  });
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
}

@HiveType(typeId: 219)
class TaxPaymentEntry {
  @HiveField(0)
  final double amount;
  @HiveField(1)
  final DateTime date;
  @HiveField(2)
  final String source; // e.g. 'Payroll', 'Bank', 'Car Dealer'

  const TaxPaymentEntry({
    required this.amount,
    required this.date,
    this.source = '',
  });
}
