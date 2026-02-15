// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tax_data.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TaxYearDataAdapter extends TypeAdapter<TaxYearData> {
  @override
  final typeId = 226;

  @override
  TaxYearData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TaxYearData(
      year: (fields[0] as num).toInt(),
      salary: fields[1] == null
          ? const SalaryDetails()
          : fields[1] as SalaryDetails,
      houseProperties: fields[2] == null
          ? const []
          : (fields[2] as List).cast<HouseProperty>(),
      businessIncomes: fields[3] == null
          ? const []
          : (fields[3] as List).cast<BusinessEntity>(),
      capitalGains: fields[4] == null
          ? const []
          : (fields[4] as List).cast<CapitalGainEntry>(),
      otherIncomes: fields[5] == null
          ? const []
          : (fields[5] as List).cast<OtherIncome>(),
      dividendIncome: fields[6] == null
          ? const DividendIncome()
          : fields[6] as DividendIncome,
      cashGifts: fields[7] == null
          ? const []
          : (fields[7] as List).cast<OtherIncome>(),
      agricultureIncome: fields[8] == null ? 0 : (fields[8] as num).toDouble(),
      advanceTax: fields[9] == null ? 0 : (fields[9] as num).toDouble(),
      tdsEntries: fields[10] == null
          ? const []
          : (fields[10] as List).cast<TaxPaymentEntry>(),
      tcsEntries: fields[11] == null
          ? const []
          : (fields[11] as List).cast<TaxPaymentEntry>(),
      lastSyncDate: fields[12] as DateTime?,
      lockedFields:
          fields[13] == null ? const [] : (fields[13] as List).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, TaxYearData obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.year)
      ..writeByte(1)
      ..write(obj.salary)
      ..writeByte(2)
      ..write(obj.houseProperties)
      ..writeByte(3)
      ..write(obj.businessIncomes)
      ..writeByte(4)
      ..write(obj.capitalGains)
      ..writeByte(5)
      ..write(obj.otherIncomes)
      ..writeByte(6)
      ..write(obj.dividendIncome)
      ..writeByte(7)
      ..write(obj.cashGifts)
      ..writeByte(8)
      ..write(obj.agricultureIncome)
      ..writeByte(9)
      ..write(obj.advanceTax)
      ..writeByte(10)
      ..write(obj.tdsEntries)
      ..writeByte(11)
      ..write(obj.tcsEntries)
      ..writeByte(12)
      ..write(obj.lastSyncDate)
      ..writeByte(13)
      ..write(obj.lockedFields);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaxYearDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
