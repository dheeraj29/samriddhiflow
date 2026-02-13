// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tax_rules.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TaxExemptionRuleAdapter extends TypeAdapter<TaxExemptionRule> {
  @override
  final typeId = 203;

  @override
  TaxExemptionRule read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TaxExemptionRule(
      id: fields[5] as String,
      name: fields[0] as String,
      incomeHead: fields[1] as String,
      limit: (fields[2] as num).toDouble(),
      isPercentage: fields[3] == null ? false : fields[3] as bool,
      isEnabled: fields[4] == null ? true : fields[4] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, TaxExemptionRule obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.incomeHead)
      ..writeByte(2)
      ..write(obj.limit)
      ..writeByte(3)
      ..write(obj.isPercentage)
      ..writeByte(4)
      ..write(obj.isEnabled)
      ..writeByte(5)
      ..write(obj.id);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaxExemptionRuleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TaxSlabAdapter extends TypeAdapter<TaxSlab> {
  @override
  final typeId = 202;

  @override
  TaxSlab read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TaxSlab(
      (fields[0] as num).toDouble(),
      (fields[1] as num).toDouble(),
    );
  }

  @override
  void write(BinaryWriter writer, TaxSlab obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.upto)
      ..writeByte(1)
      ..write(obj.rate);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaxSlabAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class InsurancePremiumRuleAdapter extends TypeAdapter<InsurancePremiumRule> {
  @override
  final typeId = 204;

  @override
  InsurancePremiumRule read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return InsurancePremiumRule(
      fields[0] as DateTime,
      (fields[1] as num).toDouble(),
    );
  }

  @override
  void write(BinaryWriter writer, InsurancePremiumRule obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.startDate)
      ..writeByte(1)
      ..write(obj.limitPercentage);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InsurancePremiumRuleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TaxMappingRuleAdapter extends TypeAdapter<TaxMappingRule> {
  @override
  final typeId = 205;

  @override
  TaxMappingRule read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TaxMappingRule(
      categoryName: fields[0] as String,
      taxHead: fields[1] as String,
      matchDescriptions:
          fields[2] == null ? const [] : (fields[2] as List).cast<String>(),
      excludeDescriptions:
          fields[4] == null ? const [] : (fields[4] as List).cast<String>(),
      minHoldingMonths: (fields[3] as num?)?.toInt(),
    );
  }

  @override
  void write(BinaryWriter writer, TaxMappingRule obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.categoryName)
      ..writeByte(1)
      ..write(obj.taxHead)
      ..writeByte(2)
      ..write(obj.matchDescriptions)
      ..writeByte(3)
      ..write(obj.minHoldingMonths)
      ..writeByte(4)
      ..write(obj.excludeDescriptions);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaxMappingRuleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TaxRulesAdapter extends TypeAdapter<TaxRules> {
  @override
  final typeId = 224;

  @override
  TaxRules read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TaxRules(
      currencyLimit10_10D:
          fields[0] == null ? 500000 : (fields[0] as num).toDouble(),
      stdDeductionSalary:
          fields[1] == null ? 75000 : (fields[1] as num).toDouble(),
      stdExemption112A:
          fields[2] == null ? 125000 : (fields[2] as num).toDouble(),
      ltcgRateEquity: fields[4] == null ? 12.5 : (fields[4] as num).toDouble(),
      stcgRate: fields[5] == null ? 20.0 : (fields[5] as num).toDouble(),
      windowGainReinvest:
          fields[6] == null ? 2.0 : (fields[6] as num).toDouble(),
      tagMappings: fields[8] == null
          ? const {}
          : (fields[8] as Map).cast<String, String>(),
      limitGratuity:
          fields[12] == null ? 2000000 : (fields[12] as num).toDouble(),
      limitLeaveEncashment:
          fields[13] == null ? 2500000 : (fields[13] as num).toDouble(),
      slabs: fields[9] == null
          ? const [
              TaxSlab(400000, 0),
              TaxSlab(800000, 5),
              TaxSlab(1200000, 10),
              TaxSlab(1600000, 15),
              TaxSlab(2000000, 20),
              TaxSlab(2400000, 25),
              TaxSlab(double.infinity, 30)
            ]
          : (fields[9] as List).cast<TaxSlab>(),
      rebateLimit:
          fields[10] == null ? 1200000 : (fields[10] as num).toDouble(),
      cessRate: fields[11] == null ? 4.0 : (fields[11] as num).toDouble(),
      maxCGReinvestLimit:
          fields[14] == null ? 100000000 : (fields[14] as num).toDouble(),
      maxHPDeductionLimit:
          fields[15] == null ? 200000 : (fields[15] as num).toDouble(),
      standardDeductionRateHP:
          fields[16] == null ? 30.0 : (fields[16] as num).toDouble(),
      limitInsuranceULIP:
          fields[17] == null ? 250000 : (fields[17] as num).toDouble(),
      dateEffectiveULIP: fields[18] as DateTime?,
      limitInsuranceNonULIP:
          fields[19] == null ? 500000 : (fields[19] as num).toDouble(),
      dateEffectiveNonULIP: fields[20] as DateTime?,
      customExemptions: fields[21] == null
          ? const []
          : (fields[21] as List).cast<TaxExemptionRule>(),
      jurisdiction: fields[22] == null ? 'India' : fields[22] as String,
      cashGiftExemptionLimit:
          fields[23] == null ? 50000 : (fields[23] as num).toDouble(),
      insurancePremiumRules:
          (fields[24] as List?)?.cast<InsurancePremiumRule>(),
      isCashGiftExemptionEnabled:
          fields[26] == null ? true : fields[26] as bool,
      agricultureIncomeThreshold:
          fields[27] == null ? 5000 : (fields[27] as num).toDouble(),
      agricultureBasicExemptionLimit:
          fields[28] == null ? 400000 : (fields[28] as num).toDouble(),
      customJurisdictionName: fields[29] == null ? '' : fields[29] as String,
      isStdDeductionSalaryEnabled:
          fields[30] == null ? true : fields[30] as bool,
      isStdDeductionHPEnabled: fields[31] == null ? true : fields[31] as bool,
      isCessEnabled: fields[32] == null ? true : fields[32] as bool,
      isRebateEnabled: fields[33] == null ? true : fields[33] as bool,
      isLTCGExemption112AEnabled:
          fields[34] == null ? true : fields[34] as bool,
      isInsuranceExemptionEnabled:
          fields[35] == null ? true : fields[35] as bool,
      isInsuranceAggregateLimitEnabled:
          fields[36] == null ? true : fields[36] as bool,
      isInsurancePremiumPercentEnabled:
          fields[37] == null ? true : fields[37] as bool,
      isRetirementExemptionEnabled:
          fields[38] == null ? true : fields[38] as bool,
      isHPMaxInterestEnabled: fields[39] == null ? true : fields[39] as bool,
      isCGReinvestmentEnabled: fields[40] == null ? true : fields[40] as bool,
      isCGRatesEnabled: fields[41] == null ? true : fields[41] as bool,
      isAgriIncomeEnabled: fields[42] == null ? true : fields[42] as bool,
      advancedTagMappings: fields[43] == null
          ? const []
          : (fields[43] as List).cast<TaxMappingRule>(),
      financialYearStartMonth:
          fields[44] == null ? 4 : (fields[44] as num).toInt(),
      giftFromEmployerExemptionLimit:
          fields[45] == null ? 5000 : (fields[45] as num).toDouble(),
      isGiftFromEmployerEnabled: fields[46] == null ? true : fields[46] as bool,
      is44ADEnabled: fields[47] == null ? true : fields[47] as bool,
      limit44AD: fields[48] == null ? 20000000 : (fields[48] as num).toDouble(),
      rate44AD: fields[49] == null ? 6.0 : (fields[49] as num).toDouble(),
      is44ADAEnabled: fields[50] == null ? true : fields[50] as bool,
      limit44ADA: fields[51] == null ? 5000000 : (fields[51] as num).toDouble(),
      rate44ADA: fields[52] == null ? 50.0 : (fields[52] as num).toDouble(),
    );
  }

  @override
  void write(BinaryWriter writer, TaxRules obj) {
    writer
      ..writeByte(53)
      ..writeByte(0)
      ..write(obj.currencyLimit10_10D)
      ..writeByte(1)
      ..write(obj.stdDeductionSalary)
      ..writeByte(2)
      ..write(obj.stdExemption112A)
      ..writeByte(4)
      ..write(obj.ltcgRateEquity)
      ..writeByte(5)
      ..write(obj.stcgRate)
      ..writeByte(6)
      ..write(obj.windowGainReinvest)
      ..writeByte(8)
      ..write(obj.tagMappings)
      ..writeByte(9)
      ..write(obj.slabs)
      ..writeByte(10)
      ..write(obj.rebateLimit)
      ..writeByte(11)
      ..write(obj.cessRate)
      ..writeByte(12)
      ..write(obj.limitGratuity)
      ..writeByte(13)
      ..write(obj.limitLeaveEncashment)
      ..writeByte(14)
      ..write(obj.maxCGReinvestLimit)
      ..writeByte(15)
      ..write(obj.maxHPDeductionLimit)
      ..writeByte(16)
      ..write(obj.standardDeductionRateHP)
      ..writeByte(17)
      ..write(obj.limitInsuranceULIP)
      ..writeByte(18)
      ..write(obj.dateEffectiveULIP)
      ..writeByte(19)
      ..write(obj.limitInsuranceNonULIP)
      ..writeByte(20)
      ..write(obj.dateEffectiveNonULIP)
      ..writeByte(21)
      ..write(obj.customExemptions)
      ..writeByte(22)
      ..write(obj.jurisdiction)
      ..writeByte(23)
      ..write(obj.cashGiftExemptionLimit)
      ..writeByte(24)
      ..write(obj.insurancePremiumRules)
      ..writeByte(26)
      ..write(obj.isCashGiftExemptionEnabled)
      ..writeByte(27)
      ..write(obj.agricultureIncomeThreshold)
      ..writeByte(28)
      ..write(obj.agricultureBasicExemptionLimit)
      ..writeByte(29)
      ..write(obj.customJurisdictionName)
      ..writeByte(30)
      ..write(obj.isStdDeductionSalaryEnabled)
      ..writeByte(31)
      ..write(obj.isStdDeductionHPEnabled)
      ..writeByte(32)
      ..write(obj.isCessEnabled)
      ..writeByte(33)
      ..write(obj.isRebateEnabled)
      ..writeByte(34)
      ..write(obj.isLTCGExemption112AEnabled)
      ..writeByte(35)
      ..write(obj.isInsuranceExemptionEnabled)
      ..writeByte(36)
      ..write(obj.isInsuranceAggregateLimitEnabled)
      ..writeByte(37)
      ..write(obj.isInsurancePremiumPercentEnabled)
      ..writeByte(38)
      ..write(obj.isRetirementExemptionEnabled)
      ..writeByte(39)
      ..write(obj.isHPMaxInterestEnabled)
      ..writeByte(40)
      ..write(obj.isCGReinvestmentEnabled)
      ..writeByte(41)
      ..write(obj.isCGRatesEnabled)
      ..writeByte(42)
      ..write(obj.isAgriIncomeEnabled)
      ..writeByte(43)
      ..write(obj.advancedTagMappings)
      ..writeByte(44)
      ..write(obj.financialYearStartMonth)
      ..writeByte(45)
      ..write(obj.giftFromEmployerExemptionLimit)
      ..writeByte(46)
      ..write(obj.isGiftFromEmployerEnabled)
      ..writeByte(47)
      ..write(obj.is44ADEnabled)
      ..writeByte(48)
      ..write(obj.limit44AD)
      ..writeByte(49)
      ..write(obj.rate44AD)
      ..writeByte(50)
      ..write(obj.is44ADAEnabled)
      ..writeByte(51)
      ..write(obj.limit44ADA)
      ..writeByte(52)
      ..write(obj.rate44ADA);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaxRulesAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
