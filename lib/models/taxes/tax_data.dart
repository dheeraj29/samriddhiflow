import 'package:hive_ce/hive.dart';
import 'tax_data_models.dart';

part 'tax_data.g.dart';

@HiveType(typeId: 226)
class TaxYearData {
  @HiveField(0)
  final int year; // Assessment Year (e.g., 2025-2026) -> Acts as Key

  // Granular Data
  @HiveField(1)
  final SalaryDetails salary;
  @HiveField(2)
  final List<HouseProperty> houseProperties;
  @HiveField(3)
  final List<BusinessEntity> businessIncomes;
  @HiveField(4)
  final List<CapitalGainEntry> capitalGains;
  @HiveField(5)
  final List<OtherIncome> otherIncomes;
  @HiveField(6)
  final DividendIncome dividendIncome;

  @HiveField(7)
  final List<OtherIncome> cashGifts;
  @HiveField(8)
  final double agricultureIncome; // New field
  @HiveField(9)
  final double advanceTax;
  @HiveField(10)
  final List<TaxPaymentEntry> tdsEntries;
  @HiveField(11)
  final List<TaxPaymentEntry> tcsEntries;

  // Smart Sync Fields
  @HiveField(12)
  final DateTime? lastSyncDate;
  @HiveField(13)
  final List<String> lockedFields; // List of field IDs manually edited by user

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
    this.lastSyncDate,
    this.lockedFields = const [],
  });

  // Getters for Summaries (Used by Dashboard)
  double get totalSalary =>
      salary.grossSalary +
      salary.independentAllowances.fold(0.0, (sum, a) => sum + a.payoutAmount);

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
    DateTime? lastSyncDate,
    List<String>? lockedFields,
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
      lastSyncDate: lastSyncDate ?? this.lastSyncDate,
      lockedFields: lockedFields ?? this.lockedFields,
    );
  }

  Map<String, dynamic> toMap() => {
        'year': year,
        'salary': salary.toMap(),
        'houseProperties': houseProperties.map((e) => e.toMap()).toList(),
        'businessIncomes': businessIncomes.map((e) => e.toMap()).toList(),
        'capitalGains': capitalGains.map((e) => e.toMap()).toList(),
        'otherIncomes': otherIncomes.map((e) => e.toMap()).toList(),
        'dividendIncome': dividendIncome.toMap(),
        'cashGifts': cashGifts.map((e) => e.toMap()).toList(),
        'agricultureIncome': agricultureIncome,
        'advanceTax': advanceTax,
        'tdsEntries': tdsEntries.map((e) => e.toMap()).toList(),
        'tcsEntries': tcsEntries.map((e) => e.toMap()).toList(),
        'lastSyncDate': lastSyncDate?.toIso8601String(),
        'lockedFields': lockedFields,
      };

  factory TaxYearData.fromMap(Map<String, dynamic> m) => TaxYearData(
        year: m['year'] ?? DateTime.now().year,
        salary:
            SalaryDetails.fromMap(Map<String, dynamic>.from(m['salary'] ?? {})),
        houseProperties: (m['houseProperties'] as List?)
                ?.map(
                    (e) => HouseProperty.fromMap(Map<String, dynamic>.from(e)))
                .toList() ??
            [],
        businessIncomes: (m['businessIncomes'] as List?)
                ?.map(
                    (e) => BusinessEntity.fromMap(Map<String, dynamic>.from(e)))
                .toList() ??
            [],
        capitalGains: (m['capitalGains'] as List?)
                ?.map((e) =>
                    CapitalGainEntry.fromMap(Map<String, dynamic>.from(e)))
                .toList() ??
            [],
        otherIncomes: (m['otherIncomes'] as List?)
                ?.map((e) => OtherIncome.fromMap(Map<String, dynamic>.from(e)))
                .toList() ??
            [],
        dividendIncome: DividendIncome.fromMap(
            Map<String, dynamic>.from(m['dividendIncome'] ?? {})),
        cashGifts: (m['cashGifts'] as List?)
                ?.map((e) => OtherIncome.fromMap(Map<String, dynamic>.from(e)))
                .toList() ??
            [],
        agricultureIncome: (m['agricultureIncome'] as num?)?.toDouble() ?? 0,
        advanceTax: (m['advanceTax'] as num?)?.toDouble() ?? 0,
        tdsEntries: (m['tdsEntries'] as List?)
                ?.map((e) =>
                    TaxPaymentEntry.fromMap(Map<String, dynamic>.from(e)))
                .toList() ??
            [],
        tcsEntries: (m['tcsEntries'] as List?)
                ?.map((e) =>
                    TaxPaymentEntry.fromMap(Map<String, dynamic>.from(e)))
                .toList() ??
            [],
        lastSyncDate: m['lastSyncDate'] != null
            ? DateTime.parse(m['lastSyncDate'])
            : null,
        lockedFields: (m['lockedFields'] as List?)?.cast<String>() ?? [],
      );
}
