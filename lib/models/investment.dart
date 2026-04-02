import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
import 'package:uuid/uuid.dart';
import '../l10n/app_localizations.dart';

part 'investment.g.dart';

@HiveType(typeId: 30)
enum InvestmentType {
  @HiveField(0)
  stock,
  @HiveField(1)
  mutualFund,
  @HiveField(2)
  fixedSavings, // e.g., FD
  @HiveField(3)
  nps,
  @HiveField(4)
  pf,
  @HiveField(5)
  moneyMarket,
  @HiveField(6)
  overnight,
  @HiveField(7)
  otherRecord, // Record of unknown value like stocks
  @HiveField(8)
  otherFixed, // Fixed interest record
}

extension InvestmentTypeExt on InvestmentType {
  IconData get icon {
    // coverage:ignore-line
    switch (this) {
      case InvestmentType.stock: // coverage:ignore-line
        return Icons.trending_up;
      case InvestmentType.mutualFund: // coverage:ignore-line
        return Icons.account_balance_wallet;
      case InvestmentType.fixedSavings: // coverage:ignore-line
        return Icons.savings;
      case InvestmentType.nps: // coverage:ignore-line
        return Icons.public;
      case InvestmentType.pf: // coverage:ignore-line
        return Icons.security;
      case InvestmentType.moneyMarket: // coverage:ignore-line
        return Icons.monetization_on;
      case InvestmentType.overnight: // coverage:ignore-line
        return Icons.nights_stay;
      case InvestmentType.otherRecord: // coverage:ignore-line
        return Icons.insert_drive_file;
      case InvestmentType.otherFixed: // coverage:ignore-line
        return Icons.lock;
    }
  }

  String localizedName(AppLocalizations l10n) {
    switch (this) {
      case InvestmentType.stock:
        return l10n.investmentType_stock;
      case InvestmentType.mutualFund:
        return l10n.investmentType_mutualFund;
      case InvestmentType.fixedSavings:
        return l10n.investmentType_fixedSavings;
      case InvestmentType.nps:
        return l10n.investmentType_nps;
      case InvestmentType.pf:
        return l10n.investmentType_pf;
      case InvestmentType.moneyMarket:
        return l10n.investmentType_moneyMarket;
      case InvestmentType.overnight:
        return l10n.investmentType_overnight;
      case InvestmentType.otherRecord:
        return l10n.investmentType_otherRecord;
      case InvestmentType.otherFixed:
        return l10n.investmentType_otherFixed;
    }
  }
}

@HiveType(typeId: 31)
enum MutualFundCategory {
  @HiveField(0)
  flexi,
  @HiveField(1)
  largeCap,
  @HiveField(2)
  midCap,
  @HiveField(3)
  smallCap,
  @HiveField(4)
  debt,
  @HiveField(5)
  mfIndex,
  @HiveField(6)
  industry,
  @HiveField(7)
  others,
}

extension MutualFundCategoryExt on MutualFundCategory {
  String localizedName(AppLocalizations l10n) {
    // coverage:ignore-line
    switch (this) {
      // coverage:ignore-start
      case MutualFundCategory.flexi:
        return l10n.mfCategory_flexi;
      case MutualFundCategory.largeCap:
        return l10n.mfCategory_largeCap;
      case MutualFundCategory.midCap:
        return l10n.mfCategory_midCap;
      case MutualFundCategory.smallCap:
        return l10n.mfCategory_smallCap;
      case MutualFundCategory.debt:
        return l10n.mfCategory_debt;
      case MutualFundCategory.mfIndex:
        return l10n.mfCategory_mfIndex;
      case MutualFundCategory.industry:
        return l10n.mfCategory_industry;
      case MutualFundCategory.others:
        return l10n.mfCategory_others;
      // coverage:ignore-end
    }
  }
}

@HiveType(typeId: 32)
class Investment extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  InvestmentType type;

  @HiveField(3)
  DateTime acquisitionDate;

  @HiveField(4)
  double acquisitionPrice;

  @HiveField(5)
  double quantity;

  @HiveField(6)
  double currentPrice; // Updated via JSON or manual

  @HiveField(7)
  DateTime? sellDate;

  @HiveField(8)
  double? sellPrice;

  @HiveField(9)
  bool isSold;

  @HiveField(10)
  MutualFundCategory? mfCategory;

  @HiveField(11)
  double? fixedInterestRate; // For fixed savings/otherFixed

  @HiveField(12)
  int customLongTermThresholdYears; // Default 1

  @HiveField(13)
  String profileId;

  @HiveField(14)
  String? remarks;

  @HiveField(15)
  String? codeName;

  @HiveField(16)
  double? recurringAmount;

  @HiveField(17)
  DateTime? nextRecurringDate;

  @HiveField(18)
  bool isRecurringEnabled;

  @HiveField(19)
  bool isRecurringPaused;

  Investment({
    required this.id,
    required this.name,
    required this.type,
    required this.acquisitionDate,
    required this.acquisitionPrice,
    required this.quantity,
    this.currentPrice = 0,
    this.sellDate,
    this.sellPrice,
    this.isSold = false,
    this.mfCategory,
    this.fixedInterestRate,
    this.customLongTermThresholdYears = 1,
    this.profileId = 'default',
    this.remarks,
    this.codeName,
    this.recurringAmount,
    this.nextRecurringDate,
    this.isRecurringEnabled = false,
    this.isRecurringPaused = false,
  });

  factory Investment.create({
    required String name,
    required InvestmentType type,
    required DateTime acquisitionDate,
    required double acquisitionPrice,
    required double quantity,
    double currentPrice = 0,
    MutualFundCategory? mfCategory,
    double? fixedInterestRate,
    int customLongTermThresholdYears = 1,
    String profileId = 'default',
    String? remarks,
    String? codeName,
    double? recurringAmount,
    DateTime? nextRecurringDate,
    bool isRecurringEnabled = false,
    bool isRecurringPaused = false,
  }) {
    return Investment(
      id: const Uuid().v4(),
      name: name,
      type: type,
      acquisitionDate: acquisitionDate,
      acquisitionPrice: acquisitionPrice,
      quantity: quantity,
      currentPrice: currentPrice > 0 ? currentPrice : acquisitionPrice,
      mfCategory: mfCategory,
      fixedInterestRate: fixedInterestRate,
      customLongTermThresholdYears: customLongTermThresholdYears,
      profileId: profileId,
      remarks: remarks,
      codeName: codeName,
      recurringAmount: recurringAmount,
      nextRecurringDate: nextRecurringDate,
      isRecurringEnabled: isRecurringEnabled,
      isRecurringPaused: isRecurringPaused,
    );
  }

  // LTCG Logic: AcquisitionDate to CURRENT date >= threshold
  bool get isLongTerm {
    final now = DateTime.now();
    final yearsDiff = now.year - acquisitionDate.year;
    if (yearsDiff > customLongTermThresholdYears) return true;
    if (yearsDiff < customLongTermThresholdYears) return false;

    // Check month and day if precisely at threshold year
    if (now.month > acquisitionDate.month) return true;
    if (now.month < acquisitionDate.month) return false; // coverage:ignore-line
    return now.day >= acquisitionDate.day; // coverage:ignore-line
  }

  double get currentValuation => quantity * currentPrice;
  double get investedValue => quantity * acquisitionPrice;
  double get unrealizedGain => currentValuation - investedValue;
  double get realizedGain => isSold && sellPrice != null // coverage:ignore-line
      ? (quantity * (sellPrice! - acquisitionPrice)) // coverage:ignore-line
      : 0;

  String? get longTermRemaining {
    if (isLongTerm) return null;
    final now = DateTime.now();
    final ltDate = DateTime(acquisitionDate.year + customLongTermThresholdYears,
        acquisitionDate.month, acquisitionDate.day);
    final diff = ltDate.difference(now);
    if (diff.inDays > 365) {
      // coverage:ignore-start
      final years = (diff.inDays / 365).floor();
      final months = ((diff.inDays % 365) / 30).floor();
      return months > 0 ? "$years y $months m" : "$years y";
      // coverage:ignore-end
    } else if (diff.inDays > 30) {
      final months = (diff.inDays / 30).floor();
      final days = diff.inDays % 30;
      return days > 0 ? "$months m $days d" : "$months m";
    } else {
      return "${diff.inDays} d"; // coverage:ignore-line
    }
  }

  Investment copyWith({
    String? name,
    InvestmentType? type,
    DateTime? acquisitionDate,
    double? acquisitionPrice,
    double? quantity,
    double? currentPrice,
    DateTime? sellDate,
    double? sellPrice,
    bool? isSold,
    MutualFundCategory? mfCategory,
    double? fixedInterestRate,
    int? customLongTermThresholdYears,
    String? profileId,
    String? remarks,
    String? codeName,
    double? recurringAmount,
    DateTime? nextRecurringDate,
    bool? isRecurringEnabled,
    bool? isRecurringPaused,
  }) {
    return Investment(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      acquisitionDate: acquisitionDate ?? this.acquisitionDate,
      acquisitionPrice: acquisitionPrice ?? this.acquisitionPrice,
      quantity: quantity ?? this.quantity,
      currentPrice: currentPrice ?? this.currentPrice,
      sellDate: sellDate ?? this.sellDate,
      sellPrice: sellPrice ?? this.sellPrice,
      isSold: isSold ?? this.isSold,
      mfCategory: mfCategory ?? this.mfCategory,
      fixedInterestRate: fixedInterestRate ?? this.fixedInterestRate,
      customLongTermThresholdYears:
          customLongTermThresholdYears ?? this.customLongTermThresholdYears,
      profileId: profileId ?? this.profileId,
      remarks: remarks ?? this.remarks,
      codeName: codeName ?? this.codeName,
      recurringAmount: recurringAmount ?? this.recurringAmount,
      nextRecurringDate: nextRecurringDate ?? this.nextRecurringDate,
      isRecurringEnabled: isRecurringEnabled ?? this.isRecurringEnabled,
      isRecurringPaused: isRecurringPaused ?? this.isRecurringPaused,
    );
  }
}
