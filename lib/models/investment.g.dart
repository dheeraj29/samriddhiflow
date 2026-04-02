// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'investment.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class InvestmentAdapter extends TypeAdapter<Investment> {
  @override
  final typeId = 32;

  @override
  Investment read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Investment(
      id: fields[0] as String,
      name: fields[1] as String,
      type: fields[2] as InvestmentType,
      acquisitionDate: fields[3] as DateTime,
      acquisitionPrice: (fields[4] as num).toDouble(),
      quantity: (fields[5] as num).toDouble(),
      currentPrice: fields[6] == null ? 0 : (fields[6] as num).toDouble(),
      sellDate: fields[7] as DateTime?,
      sellPrice: (fields[8] as num?)?.toDouble(),
      isSold: fields[9] == null ? false : fields[9] as bool,
      mfCategory: fields[10] as MutualFundCategory?,
      fixedInterestRate: (fields[11] as num?)?.toDouble(),
      customLongTermThresholdYears:
          fields[12] == null ? 1 : (fields[12] as num).toInt(),
      profileId: fields[13] == null ? 'default' : fields[13] as String,
      remarks: fields[14] as String?,
      codeName: fields[15] as String?,
      recurringAmount: (fields[16] as num?)?.toDouble(),
      nextRecurringDate: fields[17] as DateTime?,
      isRecurringEnabled: fields[18] == null ? false : fields[18] as bool,
      isRecurringPaused: fields[19] == null ? false : fields[19] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Investment obj) {
    writer
      ..writeByte(20)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.type)
      ..writeByte(3)
      ..write(obj.acquisitionDate)
      ..writeByte(4)
      ..write(obj.acquisitionPrice)
      ..writeByte(5)
      ..write(obj.quantity)
      ..writeByte(6)
      ..write(obj.currentPrice)
      ..writeByte(7)
      ..write(obj.sellDate)
      ..writeByte(8)
      ..write(obj.sellPrice)
      ..writeByte(9)
      ..write(obj.isSold)
      ..writeByte(10)
      ..write(obj.mfCategory)
      ..writeByte(11)
      ..write(obj.fixedInterestRate)
      ..writeByte(12)
      ..write(obj.customLongTermThresholdYears)
      ..writeByte(13)
      ..write(obj.profileId)
      ..writeByte(14)
      ..write(obj.remarks)
      ..writeByte(15)
      ..write(obj.codeName)
      ..writeByte(16)
      ..write(obj.recurringAmount)
      ..writeByte(17)
      ..write(obj.nextRecurringDate)
      ..writeByte(18)
      ..write(obj.isRecurringEnabled)
      ..writeByte(19)
      ..write(obj.isRecurringPaused);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InvestmentAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class InvestmentTypeAdapter extends TypeAdapter<InvestmentType> {
  @override
  final typeId = 30;

  @override
  InvestmentType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return InvestmentType.stock;
      case 1:
        return InvestmentType.mutualFund;
      case 2:
        return InvestmentType.fixedSavings;
      case 3:
        return InvestmentType.nps;
      case 4:
        return InvestmentType.pf;
      case 5:
        return InvestmentType.moneyMarket;
      case 6:
        return InvestmentType.overnight;
      case 7:
        return InvestmentType.otherRecord;
      case 8:
        return InvestmentType.otherFixed;
      default:
        return InvestmentType.stock;
    }
  }

  @override
  void write(BinaryWriter writer, InvestmentType obj) {
    switch (obj) {
      case InvestmentType.stock:
        writer.writeByte(0);
      case InvestmentType.mutualFund:
        writer.writeByte(1);
      case InvestmentType.fixedSavings:
        writer.writeByte(2);
      case InvestmentType.nps:
        writer.writeByte(3);
      case InvestmentType.pf:
        writer.writeByte(4);
      case InvestmentType.moneyMarket:
        writer.writeByte(5);
      case InvestmentType.overnight:
        writer.writeByte(6);
      case InvestmentType.otherRecord:
        writer.writeByte(7);
      case InvestmentType.otherFixed:
        writer.writeByte(8);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InvestmentTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class MutualFundCategoryAdapter extends TypeAdapter<MutualFundCategory> {
  @override
  final typeId = 31;

  @override
  MutualFundCategory read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return MutualFundCategory.flexi;
      case 1:
        return MutualFundCategory.largeCap;
      case 2:
        return MutualFundCategory.midCap;
      case 3:
        return MutualFundCategory.smallCap;
      case 4:
        return MutualFundCategory.debt;
      case 5:
        return MutualFundCategory.mfIndex;
      case 6:
        return MutualFundCategory.industry;
      case 7:
        return MutualFundCategory.others;
      default:
        return MutualFundCategory.flexi;
    }
  }

  @override
  void write(BinaryWriter writer, MutualFundCategory obj) {
    switch (obj) {
      case MutualFundCategory.flexi:
        writer.writeByte(0);
      case MutualFundCategory.largeCap:
        writer.writeByte(1);
      case MutualFundCategory.midCap:
        writer.writeByte(2);
      case MutualFundCategory.smallCap:
        writer.writeByte(3);
      case MutualFundCategory.debt:
        writer.writeByte(4);
      case MutualFundCategory.mfIndex:
        writer.writeByte(5);
      case MutualFundCategory.industry:
        writer.writeByte(6);
      case MutualFundCategory.others:
        writer.writeByte(7);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MutualFundCategoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
