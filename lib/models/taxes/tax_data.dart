import 'tax_data_models.dart';

class TaxYearData {
  final int year; // Assessment Year (e.g., 2025-2026)

  // Granular Data
  // Granular Data
  final SalaryDetails salary;
  final List<HouseProperty> houseProperties;
  final List<BusinessEntity> businessIncomes;
  final List<CapitalGainEntry> capitalGains;
  final List<OtherIncome> otherIncomes;
  final DividendIncome dividendIncome;

  final List<OtherIncome> cashGifts;
  final double agricultureIncome; // New field
  final double advanceTax;
  final List<TaxPaymentEntry> tdsEntries;
  final List<TaxPaymentEntry> tcsEntries;

  TaxYearData({
    required this.year,
    this.salary = const SalaryDetails(),
    this.houseProperties = const [],
    this.businessIncomes = const [],
    this.capitalGains = const [],
    this.otherIncomes = const [],
    this.dividendIncome = const DividendIncome(),
    this.cashGifts = const [],
    this.agricultureIncome = 0,
    this.advanceTax = 0,
    this.tdsEntries = const [],
    this.tcsEntries = const [],
  });

  // Getters for Summaries (Used by Dashboard)
  double get totalSalary => salary.grossSalary;

  double get totalHP =>
      houseProperties.fold(0, (sum, hp) => sum + hp.rentReceived);

  double get totalBusiness => businessIncomes.fold(
      0,
      (sum, b) =>
          sum +
          (b.type == BusinessType.regular ? b.netIncome : b.presumptiveIncome));

  double get totalLTCG => capitalGains
      .where((e) => e.isLTCG)
      .fold(0.0, (sum, e) => sum + e.capitalGainAmount);

  double get totalSTCG => capitalGains
      .where((e) => !e.isLTCG)
      .fold(0.0, (sum, e) => sum + e.capitalGainAmount);

  double get totalOther =>
      otherIncomes.fold(0.0, (sum, o) => sum + o.amount) +
      cashGifts.fold(0.0, (sum, c) => sum + c.amount) +
      agricultureIncome;

  // Backwards compatibility for single double fields (summing up lists)
  double get tds => tdsEntries.fold(0.0, (sum, e) => sum + e.amount);
  double get tcs => tcsEntries.fold(0.0, (sum, e) => sum + e.amount);

  TaxYearData copyWith({
    int? year,
    SalaryDetails? salary,
    List<HouseProperty>? houseProperties,
    List<BusinessEntity>? businessIncomes,
    List<CapitalGainEntry>? capitalGains,
    List<OtherIncome>? otherIncomes,
    DividendIncome? dividendIncome,
    List<OtherIncome>? cashGifts,
    double? agricultureIncome,
    double? advanceTax,
    List<TaxPaymentEntry>? tdsEntries,
    List<TaxPaymentEntry>? tcsEntries,
  }) {
    return TaxYearData(
      year: year ?? this.year,
      salary: salary ?? this.salary,
      houseProperties: houseProperties ?? this.houseProperties,
      businessIncomes: businessIncomes ?? this.businessIncomes,
      capitalGains: capitalGains ?? this.capitalGains,
      otherIncomes: otherIncomes ?? this.otherIncomes,
      dividendIncome: dividendIncome ?? this.dividendIncome,
      cashGifts: cashGifts ?? this.cashGifts,
      agricultureIncome: agricultureIncome ?? this.agricultureIncome,
      advanceTax: advanceTax ?? this.advanceTax,
      tdsEntries: tdsEntries ?? this.tdsEntries,
      tcsEntries: tcsEntries ?? this.tcsEntries,
    );
  }
}
