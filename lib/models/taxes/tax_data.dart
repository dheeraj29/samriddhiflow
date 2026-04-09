import 'package:hive_ce_flutter/hive_ce_flutter.dart';
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
  final List<TaxPaymentEntry> tdsEntries;
  @HiveField(9)
  final List<TaxPaymentEntry> tcsEntries;

  // Smart Sync Fields
  @HiveField(10)
  final DateTime? lastSyncDate;
  @HiveField(11)
  final List<String> lockedFields; // List of field IDs manually edited by user

  // Added for dynamic advance tax tracking
  @HiveField(12)
  final List<TaxPaymentEntry> advanceTaxEntries;
  @HiveField(13)
  final String profileId;
  @HiveField(14)
  final List<AgriIncomeEntry> agriIncomeHistory;

  const TaxYearData({
    required this.year,
    this.salary = const SalaryDetails(),
    this.houseProperties = const [],
    this.businessIncomes = const [],
    this.capitalGains = const [],
    this.otherIncomes = const [],
    this.dividendIncome = const DividendIncome(),
    this.cashGifts = const [],
    this.tdsEntries = const [],
    this.tcsEntries = const [],
    this.lastSyncDate,
    this.lockedFields = const [],
    this.advanceTaxEntries = const [],
    this.profileId = 'default',
    this.agriIncomeHistory = const [],
  });

  // Getters for Summaries (Used by Dashboard)
  double get totalSalary {
    // Salary is now primarily history-based. Dashboard now uses IndianTaxService to calculate gross.
    return 0;
  }

  double get totalHP =>
      houseProperties.fold(0, (sum, hp) => sum + hp.rentReceived);

  double get totalBusiness => businessIncomes.fold(
      // coverage:ignore-line
      0,
      // coverage:ignore-start
      (sum, b) =>
          sum +
          (b.type == BusinessType.regular ? b.netIncome : b.presumptiveIncome));
  // coverage:ignore-end

  // coverage:ignore-start
  double get totalLTCG => capitalGains
      .where((e) => e.isLTCG)
      .fold(0.0, (sum, e) => sum + e.capitalGainAmount);
  // coverage:ignore-end

  // coverage:ignore-start
  double get totalSTCG => capitalGains
      .where((e) => !e.isLTCG)
      .fold(0.0, (sum, e) => sum + e.capitalGainAmount);
  // coverage:ignore-end

  // coverage:ignore-start
  double get totalOther =>
      otherIncomes.fold(0.0, (sum, o) => sum + o.amount) +
      cashGifts.fold(0.0, (sum, c) => sum + c.amount) +
      agriIncomeHistory.fold(0.0, (sum, a) => sum + a.amount);
  // coverage:ignore-end

  // Backwards compatibility for single double fields (summing up lists)
  double get totalAdvanceTax =>
      advanceTaxEntries.fold(0.0, (sum, e) => sum + e.amount);
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
    List<TaxPaymentEntry>? tdsEntries,
    List<TaxPaymentEntry>? tcsEntries,
    DateTime? lastSyncDate,
    List<String>? lockedFields,
    List<TaxPaymentEntry>? advanceTaxEntries,
    String? profileId,
    List<AgriIncomeEntry>? agriIncomeHistory,
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
      tdsEntries: tdsEntries ?? this.tdsEntries,
      tcsEntries: tcsEntries ?? this.tcsEntries,
      lastSyncDate: lastSyncDate ?? this.lastSyncDate,
      lockedFields: lockedFields ?? this.lockedFields,
      advanceTaxEntries: advanceTaxEntries ?? this.advanceTaxEntries,
      profileId: profileId ?? this.profileId,
      agriIncomeHistory: agriIncomeHistory ?? this.agriIncomeHistory,
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
        'tdsEntries': tdsEntries.map((e) => e.toMap()).toList(),
        'tcsEntries': tcsEntries.map((e) => e.toMap()).toList(),
        'advanceTaxEntries': advanceTaxEntries.map((e) => e.toMap()).toList(),
        'lastSyncDate': lastSyncDate?.toIso8601String(),
        'lockedFields': lockedFields,
        'profileId': profileId,
        'agriIncomeHistory': agriIncomeHistory.map((e) => e.toMap()).toList(),
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
        tdsEntries: (m['tdsEntries'] as List?)
                ?.map((e) =>
                    TaxPaymentEntry.fromMap(Map<String, dynamic>.from(e)))
                .toList() ??
            [],
        tcsEntries: (m['tcsEntries'] as List?)
                ?.map((e) => TaxPaymentEntry.fromMap(
                    Map<String, dynamic>.from(e))) // coverage:ignore-line
                .toList() ??
            [],
        lastSyncDate: m['lastSyncDate'] != null
            ? DateTime.parse(m['lastSyncDate']) // coverage:ignore-line
            : null,
        lockedFields: (m['lockedFields'] as List?)?.cast<String>() ?? [],
        advanceTaxEntries: (m['advanceTaxEntries'] as List?)
                ?.map((e) => TaxPaymentEntry.fromMap(
                    Map<String, dynamic>.from(e))) // coverage:ignore-line
                .toList() ??
            const [],
        profileId: m['profileId'] ?? 'default',
        agriIncomeHistory: (m['agriIncomeHistory'] as List?)
                ?.map((e) => AgriIncomeEntry.fromMap(
                    Map<String, dynamic>.from(e))) // coverage:ignore-line
                .toList() ??
            [],
      );
}
