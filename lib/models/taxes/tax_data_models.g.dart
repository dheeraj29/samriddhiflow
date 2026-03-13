// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tax_data_models.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SalaryDetailsAdapter extends TypeAdapter<SalaryDetails> {
  @override
  final typeId = 210;

  @override
  SalaryDetails read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SalaryDetails(
      npsEmployer: fields[0] == null ? 0 : (fields[0] as num).toDouble(),
      leaveEncashment: fields[1] == null ? 0 : (fields[1] as num).toDouble(),
      gratuity: fields[2] == null ? 0 : (fields[2] as num).toDouble(),
      history: fields[3] == null
          ? const []
          : (fields[3] as List).cast<SalaryStructure>(),
      netSalaryReceived:
          fields[4] == null ? const {} : (fields[4] as Map).cast<int, double>(),
      independentAllowances: fields[5] == null
          ? const []
          : (fields[5] as List).cast<CustomAllowance>(),
      independentExemptions: fields[6] == null
          ? const []
          : (fields[6] as List).cast<CustomExemption>(),
      independentDeductions: fields[7] == null
          ? const []
          : (fields[7] as List).cast<CustomDeduction>(),
    );
  }

  @override
  void write(BinaryWriter writer, SalaryDetails obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.npsEmployer)
      ..writeByte(1)
      ..write(obj.leaveEncashment)
      ..writeByte(2)
      ..write(obj.gratuity)
      ..writeByte(3)
      ..write(obj.history)
      ..writeByte(4)
      ..write(obj.netSalaryReceived)
      ..writeByte(5)
      ..write(obj.independentAllowances)
      ..writeByte(6)
      ..write(obj.independentExemptions)
      ..writeByte(7)
      ..write(obj.independentDeductions);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SalaryDetailsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class HousePropertyAdapter extends TypeAdapter<HouseProperty> {
  @override
  final typeId = 211;

  @override
  HouseProperty read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HouseProperty(
      name: fields[0] as String,
      isSelfOccupied: fields[1] == null ? true : fields[1] as bool,
      rentReceived: fields[2] == null ? 0 : (fields[2] as num).toDouble(),
      municipalTaxes: fields[3] == null ? 0 : (fields[3] as num).toDouble(),
      interestOnLoan: fields[4] == null ? 0 : (fields[4] as num).toDouble(),
      loanId: fields[5] as String?,
      lastUpdated: fields[6] as DateTime?,
      isManualEntry: fields[7] == null ? true : fields[7] as bool,
      transactionDate: fields[8] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, HouseProperty obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.isSelfOccupied)
      ..writeByte(2)
      ..write(obj.rentReceived)
      ..writeByte(3)
      ..write(obj.municipalTaxes)
      ..writeByte(4)
      ..write(obj.interestOnLoan)
      ..writeByte(5)
      ..write(obj.loanId)
      ..writeByte(6)
      ..write(obj.lastUpdated)
      ..writeByte(7)
      ..write(obj.isManualEntry)
      ..writeByte(8)
      ..write(obj.transactionDate);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HousePropertyAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class BusinessEntityAdapter extends TypeAdapter<BusinessEntity> {
  @override
  final typeId = 213;

  @override
  BusinessEntity read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BusinessEntity(
      name: fields[0] as String,
      type:
          fields[1] == null ? BusinessType.regular : fields[1] as BusinessType,
      grossTurnover: fields[2] == null ? 0 : (fields[2] as num).toDouble(),
      netIncome: fields[3] == null ? 0 : (fields[3] as num).toDouble(),
      presumptiveIncome: fields[4] == null ? 0 : (fields[4] as num).toDouble(),
      lastUpdated: fields[5] as DateTime?,
      isManualEntry: fields[6] == null ? true : fields[6] as bool,
      transactionDate: fields[7] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, BusinessEntity obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.type)
      ..writeByte(2)
      ..write(obj.grossTurnover)
      ..writeByte(3)
      ..write(obj.netIncome)
      ..writeByte(4)
      ..write(obj.presumptiveIncome)
      ..writeByte(5)
      ..write(obj.lastUpdated)
      ..writeByte(6)
      ..write(obj.isManualEntry)
      ..writeByte(7)
      ..write(obj.transactionDate);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BusinessEntityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CapitalGainEntryAdapter extends TypeAdapter<CapitalGainEntry> {
  @override
  final typeId = 216;

  @override
  CapitalGainEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CapitalGainEntry(
      description: fields[0] == null ? '' : fields[0] as String,
      matchAssetType:
          fields[1] == null ? AssetType.other : fields[1] as AssetType,
      isLTCG: fields[2] == null ? false : fields[2] as bool,
      saleAmount: fields[3] == null ? 0 : (fields[3] as num).toDouble(),
      costOfAcquisition: fields[4] == null ? 0 : (fields[4] as num).toDouble(),
      gainDate: fields[5] as DateTime,
      reinvestedAmount: fields[6] == null ? 0 : (fields[6] as num).toDouble(),
      matchReinvestType: fields[7] == null
          ? ReinvestmentType.none
          : fields[7] as ReinvestmentType,
      reinvestDate: fields[8] as DateTime?,
      intendToReinvest: fields[9] == null ? false : fields[9] as bool,
      lastUpdated: fields[10] as DateTime?,
      isManualEntry: fields[11] == null ? true : fields[11] as bool,
      transactionDate: fields[12] as DateTime?,
      isLongTerm: fields[13] == null ? false : fields[13] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, CapitalGainEntry obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.description)
      ..writeByte(1)
      ..write(obj.matchAssetType)
      ..writeByte(2)
      ..write(obj.isLTCG)
      ..writeByte(3)
      ..write(obj.saleAmount)
      ..writeByte(4)
      ..write(obj.costOfAcquisition)
      ..writeByte(5)
      ..write(obj.gainDate)
      ..writeByte(6)
      ..write(obj.reinvestedAmount)
      ..writeByte(7)
      ..write(obj.matchReinvestType)
      ..writeByte(8)
      ..write(obj.reinvestDate)
      ..writeByte(9)
      ..write(obj.intendToReinvest)
      ..writeByte(10)
      ..write(obj.lastUpdated)
      ..writeByte(11)
      ..write(obj.isManualEntry)
      ..writeByte(12)
      ..write(obj.transactionDate)
      ..writeByte(13)
      ..write(obj.isLongTerm);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CapitalGainEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class OtherIncomeAdapter extends TypeAdapter<OtherIncome> {
  @override
  final typeId = 217;

  @override
  OtherIncome read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return OtherIncome(
      name: fields[0] as String,
      amount: (fields[1] as num).toDouble(),
      type: fields[2] == null ? 'Other' : fields[2] as String,
      subtype: fields[3] == null ? 'other' : fields[3] as String,
      linkedExemptionId: fields[4] as String?,
      lastUpdated: fields[5] as DateTime?,
      isManualEntry: fields[6] == null ? true : fields[6] as bool,
      transactionDate: fields[7] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, OtherIncome obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.amount)
      ..writeByte(2)
      ..write(obj.type)
      ..writeByte(3)
      ..write(obj.subtype)
      ..writeByte(4)
      ..write(obj.linkedExemptionId)
      ..writeByte(5)
      ..write(obj.lastUpdated)
      ..writeByte(6)
      ..write(obj.isManualEntry)
      ..writeByte(7)
      ..write(obj.transactionDate);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OtherIncomeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AgriIncomeEntryAdapter extends TypeAdapter<AgriIncomeEntry> {
  @override
  final typeId = 231;

  @override
  AgriIncomeEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AgriIncomeEntry(
      id: fields[0] as String,
      amount: (fields[1] as num).toDouble(),
      date: fields[2] as DateTime,
      description: fields[3] == null ? '' : fields[3] as String,
      isManualEntry: fields[4] == null ? true : fields[4] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, AgriIncomeEntry obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.amount)
      ..writeByte(2)
      ..write(obj.date)
      ..writeByte(3)
      ..write(obj.description)
      ..writeByte(4)
      ..write(obj.isManualEntry);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AgriIncomeEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SalaryStructureAdapter extends TypeAdapter<SalaryStructure> {
  @override
  final typeId = 220;

  @override
  SalaryStructure read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SalaryStructure(
      id: fields[0] as String,
      effectiveDate: fields[1] as DateTime,
      monthlyBasic: fields[2] == null ? 0 : (fields[2] as num).toDouble(),
      monthlyFixedAllowances:
          fields[3] == null ? 0 : (fields[3] as num).toDouble(),
      monthlyPerformancePay:
          fields[4] == null ? 0 : (fields[4] as num).toDouble(),
      annualVariablePay: fields[5] == null ? 0 : (fields[5] as num).toDouble(),
      customAllowances: fields[6] == null
          ? const []
          : (fields[6] as List).cast<CustomAllowance>(),
      performancePayFrequency: fields[11] == null
          ? PayoutFrequency.monthly
          : fields[11] as PayoutFrequency,
      performancePayStartMonth: (fields[12] as num?)?.toInt(),
      performancePayCustomMonths: (fields[13] as List?)?.cast<int>(),
      variablePayFrequency: fields[14] == null
          ? PayoutFrequency.annually
          : fields[14] as PayoutFrequency,
      variablePayStartMonth:
          fields[15] == null ? 3 : (fields[15] as num?)?.toInt(),
      variablePayCustomMonths: (fields[16] as List?)?.cast<int>(),
      isPerformancePayPartial: fields[17] == null ? false : fields[17] as bool,
      performancePayAmounts: fields[18] == null
          ? const {}
          : (fields[18] as Map).cast<int, double>(),
      isVariablePayPartial: fields[19] == null ? false : fields[19] as bool,
      variablePayAmounts: fields[20] == null
          ? const {}
          : (fields[20] as Map).cast<int, double>(),
      stoppedMonths:
          fields[21] == null ? const [] : (fields[21] as List).cast<int>(),
      monthlyEmployeePF: fields[7] == null ? 0 : (fields[7] as num).toDouble(),
      monthlyGratuity: fields[9] == null ? 0 : (fields[9] as num).toDouble(),
    );
  }

  @override
  void write(BinaryWriter writer, SalaryStructure obj) {
    writer
      ..writeByte(20)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.effectiveDate)
      ..writeByte(2)
      ..write(obj.monthlyBasic)
      ..writeByte(3)
      ..write(obj.monthlyFixedAllowances)
      ..writeByte(4)
      ..write(obj.monthlyPerformancePay)
      ..writeByte(5)
      ..write(obj.annualVariablePay)
      ..writeByte(6)
      ..write(obj.customAllowances)
      ..writeByte(7)
      ..write(obj.monthlyEmployeePF)
      ..writeByte(9)
      ..write(obj.monthlyGratuity)
      ..writeByte(11)
      ..write(obj.performancePayFrequency)
      ..writeByte(12)
      ..write(obj.performancePayStartMonth)
      ..writeByte(13)
      ..write(obj.performancePayCustomMonths)
      ..writeByte(14)
      ..write(obj.variablePayFrequency)
      ..writeByte(15)
      ..write(obj.variablePayStartMonth)
      ..writeByte(16)
      ..write(obj.variablePayCustomMonths)
      ..writeByte(17)
      ..write(obj.isPerformancePayPartial)
      ..writeByte(18)
      ..write(obj.performancePayAmounts)
      ..writeByte(19)
      ..write(obj.isVariablePayPartial)
      ..writeByte(20)
      ..write(obj.variablePayAmounts)
      ..writeByte(21)
      ..write(obj.stoppedMonths);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SalaryStructureAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CustomDeductionAdapter extends TypeAdapter<CustomDeduction> {
  @override
  final typeId = 222;

  @override
  CustomDeduction read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CustomDeduction(
      id: fields[0] as String,
      name: fields[1] as String,
      amount: (fields[2] as num).toDouble(),
      isTaxable: fields[3] == null ? true : fields[3] as bool,
      frequency: fields[4] == null
          ? PayoutFrequency.monthly
          : fields[4] as PayoutFrequency,
      startMonth: (fields[5] as num?)?.toInt(),
      customMonths: (fields[6] as List?)?.cast<int>(),
      isPartial: fields[7] == null ? false : fields[7] as bool,
      partialAmounts:
          fields[8] == null ? const {} : (fields[8] as Map).cast<int, double>(),
    );
  }

  @override
  void write(BinaryWriter writer, CustomDeduction obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.isTaxable)
      ..writeByte(4)
      ..write(obj.frequency)
      ..writeByte(5)
      ..write(obj.startMonth)
      ..writeByte(6)
      ..write(obj.customMonths)
      ..writeByte(7)
      ..write(obj.isPartial)
      ..writeByte(8)
      ..write(obj.partialAmounts);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomDeductionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CustomAllowanceAdapter extends TypeAdapter<CustomAllowance> {
  @override
  final typeId = 221;

  @override
  CustomAllowance read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CustomAllowance(
      id: fields[0] as String,
      name: fields[1] as String,
      payoutAmount: (fields[2] as num).toDouble(),
      isPartial: fields[3] == null ? false : fields[3] as bool,
      frequency: fields[4] == null
          ? PayoutFrequency.monthly
          : fields[4] as PayoutFrequency,
      startMonth: (fields[5] as num?)?.toInt(),
      customMonths: (fields[6] as List?)?.cast<int>(),
      partialAmounts:
          fields[7] == null ? const {} : (fields[7] as Map).cast<int, double>(),
      isCliffExemption: fields[8] == null ? false : fields[8] as bool,
      exemptionLimit: fields[9] == null ? 0 : (fields[9] as num).toDouble(),
    );
  }

  @override
  void write(BinaryWriter writer, CustomAllowance obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.payoutAmount)
      ..writeByte(3)
      ..write(obj.isPartial)
      ..writeByte(4)
      ..write(obj.frequency)
      ..writeByte(5)
      ..write(obj.startMonth)
      ..writeByte(6)
      ..write(obj.customMonths)
      ..writeByte(7)
      ..write(obj.partialAmounts)
      ..writeByte(8)
      ..write(obj.isCliffExemption)
      ..writeByte(9)
      ..write(obj.exemptionLimit);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomAllowanceAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DividendIncomeAdapter extends TypeAdapter<DividendIncome> {
  @override
  final typeId = 218;

  @override
  DividendIncome read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DividendIncome(
      amountQ1: fields[0] == null ? 0 : (fields[0] as num).toDouble(),
      amountQ2: fields[1] == null ? 0 : (fields[1] as num).toDouble(),
      amountQ3: fields[2] == null ? 0 : (fields[2] as num).toDouble(),
      amountQ4: fields[3] == null ? 0 : (fields[3] as num).toDouble(),
      amountQ5: fields[4] == null ? 0 : (fields[4] as num).toDouble(),
      lastUpdated: fields[5] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, DividendIncome obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.amountQ1)
      ..writeByte(1)
      ..write(obj.amountQ2)
      ..writeByte(2)
      ..write(obj.amountQ3)
      ..writeByte(3)
      ..write(obj.amountQ4)
      ..writeByte(4)
      ..write(obj.amountQ5)
      ..writeByte(5)
      ..write(obj.lastUpdated);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DividendIncomeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TaxPaymentEntryAdapter extends TypeAdapter<TaxPaymentEntry> {
  @override
  final typeId = 219;

  @override
  TaxPaymentEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TaxPaymentEntry(
      id: fields[4] as String,
      amount: (fields[0] as num).toDouble(),
      date: fields[1] as DateTime,
      source: fields[2] == null ? '' : fields[2] as String,
      description: fields[3] == null ? '' : fields[3] as String,
      isManualEntry: fields[5] == null ? true : fields[5] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, TaxPaymentEntry obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.amount)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.source)
      ..writeByte(3)
      ..write(obj.description)
      ..writeByte(4)
      ..write(obj.id)
      ..writeByte(5)
      ..write(obj.isManualEntry);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaxPaymentEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CustomExemptionAdapter extends TypeAdapter<CustomExemption> {
  @override
  final typeId = 224;

  @override
  CustomExemption read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CustomExemption(
      id: fields[0] as String,
      name: fields[1] as String,
      amount: (fields[2] as num).toDouble(),
      isCliffExemption: fields[3] == null ? false : fields[3] as bool,
      exemptionLimit: fields[4] == null ? 0 : (fields[4] as num).toDouble(),
    );
  }

  @override
  void write(BinaryWriter writer, CustomExemption obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.isCliffExemption)
      ..writeByte(4)
      ..write(obj.exemptionLimit);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomExemptionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class BusinessTypeAdapter extends TypeAdapter<BusinessType> {
  @override
  final typeId = 212;

  @override
  BusinessType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return BusinessType.regular;
      case 1:
        return BusinessType.section44AD;
      case 2:
        return BusinessType.section44ADA;
      default:
        return BusinessType.regular;
    }
  }

  @override
  void write(BinaryWriter writer, BusinessType obj) {
    switch (obj) {
      case BusinessType.regular:
        writer.writeByte(0);
      case BusinessType.section44AD:
        writer.writeByte(1);
      case BusinessType.section44ADA:
        writer.writeByte(2);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BusinessTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AssetTypeAdapter extends TypeAdapter<AssetType> {
  @override
  final typeId = 214;

  @override
  AssetType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return AssetType.equityShares;
      case 1:
        return AssetType.residentialProperty;
      case 2:
        return AssetType.agriculturalLand;
      case 3:
        return AssetType.other;
      default:
        return AssetType.equityShares;
    }
  }

  @override
  void write(BinaryWriter writer, AssetType obj) {
    switch (obj) {
      case AssetType.equityShares:
        writer.writeByte(0);
      case AssetType.residentialProperty:
        writer.writeByte(1);
      case AssetType.agriculturalLand:
        writer.writeByte(2);
      case AssetType.other:
        writer.writeByte(3);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AssetTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ReinvestmentTypeAdapter extends TypeAdapter<ReinvestmentType> {
  @override
  final typeId = 215;

  @override
  ReinvestmentType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ReinvestmentType.none;
      case 1:
        return ReinvestmentType.residentialProperty;
      case 2:
        return ReinvestmentType.agriculturalLand;
      case 3:
        return ReinvestmentType.bonds54EC;
      default:
        return ReinvestmentType.none;
    }
  }

  @override
  void write(BinaryWriter writer, ReinvestmentType obj) {
    switch (obj) {
      case ReinvestmentType.none:
        writer.writeByte(0);
      case ReinvestmentType.residentialProperty:
        writer.writeByte(1);
      case ReinvestmentType.agriculturalLand:
        writer.writeByte(2);
      case ReinvestmentType.bonds54EC:
        writer.writeByte(3);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReinvestmentTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PayoutFrequencyAdapter extends TypeAdapter<PayoutFrequency> {
  @override
  final typeId = 223;

  @override
  PayoutFrequency read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return PayoutFrequency.monthly;
      case 1:
        return PayoutFrequency.quarterly;
      case 2:
        return PayoutFrequency.trimester;
      case 3:
        return PayoutFrequency.halfYearly;
      case 4:
        return PayoutFrequency.annually;
      case 5:
        return PayoutFrequency.custom;
      default:
        return PayoutFrequency.monthly;
    }
  }

  @override
  void write(BinaryWriter writer, PayoutFrequency obj) {
    switch (obj) {
      case PayoutFrequency.monthly:
        writer.writeByte(0);
      case PayoutFrequency.quarterly:
        writer.writeByte(1);
      case PayoutFrequency.trimester:
        writer.writeByte(2);
      case PayoutFrequency.halfYearly:
        writer.writeByte(3);
      case PayoutFrequency.annually:
        writer.writeByte(4);
      case PayoutFrequency.custom:
        writer.writeByte(5);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PayoutFrequencyAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
