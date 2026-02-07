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
      grossSalary: fields[0] == null ? 0 : (fields[0] as num).toDouble(),
      npsEmployer: fields[1] == null ? 0 : (fields[1] as num).toDouble(),
      leaveEncashment: fields[2] == null ? 0 : (fields[2] as num).toDouble(),
      gratuity: fields[3] == null ? 0 : (fields[3] as num).toDouble(),
      monthlyGross:
          fields[4] == null ? const {} : (fields[4] as Map).cast<int, double>(),
    );
  }

  @override
  void write(BinaryWriter writer, SalaryDetails obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.grossSalary)
      ..writeByte(1)
      ..write(obj.npsEmployer)
      ..writeByte(2)
      ..write(obj.leaveEncashment)
      ..writeByte(3)
      ..write(obj.gratuity)
      ..writeByte(4)
      ..write(obj.monthlyGross);
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
    );
  }

  @override
  void write(BinaryWriter writer, HouseProperty obj) {
    writer
      ..writeByte(6)
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
      ..write(obj.loanId);
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
    );
  }

  @override
  void write(BinaryWriter writer, BusinessEntity obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.type)
      ..writeByte(2)
      ..write(obj.grossTurnover)
      ..writeByte(3)
      ..write(obj.netIncome)
      ..writeByte(4)
      ..write(obj.presumptiveIncome);
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
    );
  }

  @override
  void write(BinaryWriter writer, CapitalGainEntry obj) {
    writer
      ..writeByte(9)
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
      ..write(obj.reinvestDate);
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
    );
  }

  @override
  void write(BinaryWriter writer, OtherIncome obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.amount)
      ..writeByte(2)
      ..write(obj.type)
      ..writeByte(3)
      ..write(obj.subtype);
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
    );
  }

  @override
  void write(BinaryWriter writer, DividendIncome obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.amountQ1)
      ..writeByte(1)
      ..write(obj.amountQ2)
      ..writeByte(2)
      ..write(obj.amountQ3)
      ..writeByte(3)
      ..write(obj.amountQ4)
      ..writeByte(4)
      ..write(obj.amountQ5);
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
      amount: (fields[0] as num).toDouble(),
      date: fields[1] as DateTime,
      source: fields[2] == null ? '' : fields[2] as String,
    );
  }

  @override
  void write(BinaryWriter writer, TaxPaymentEntry obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.amount)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.source);
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
