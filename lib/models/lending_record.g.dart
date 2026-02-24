// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lending_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LendingRecordAdapter extends TypeAdapter<LendingRecord> {
  @override
  final typeId = 30;

  @override
  LendingRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LendingRecord(
      id: fields[0] as String,
      personName: fields[1] as String,
      amount: (fields[2] as num).toDouble(),
      reason: fields[3] as String,
      date: fields[4] as DateTime,
      type: fields[5] as LendingType,
      isClosed: fields[6] == null ? false : fields[6] as bool,
      closedDate: fields[7] as DateTime?,
      profileId: fields[8] as String?,
      payments: fields[9] == null
          ? const []
          : (fields[9] as List).cast<LendingPayment>(),
    );
  }

  @override
  void write(BinaryWriter writer, LendingRecord obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.personName)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.reason)
      ..writeByte(4)
      ..write(obj.date)
      ..writeByte(5)
      ..write(obj.type)
      ..writeByte(6)
      ..write(obj.isClosed)
      ..writeByte(7)
      ..write(obj.closedDate)
      ..writeByte(8)
      ..write(obj.profileId)
      ..writeByte(9)
      ..write(obj.payments);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LendingRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class LendingPaymentAdapter extends TypeAdapter<LendingPayment> {
  @override
  final typeId = 32;

  @override
  LendingPayment read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LendingPayment(
      id: fields[0] as String,
      amount: (fields[1] as num).toDouble(),
      date: fields[2] as DateTime,
      note: fields[3] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, LendingPayment obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.amount)
      ..writeByte(2)
      ..write(obj.date)
      ..writeByte(3)
      ..write(obj.note);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LendingPaymentAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class LendingTypeAdapter extends TypeAdapter<LendingType> {
  @override
  final typeId = 31;

  @override
  LendingType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return LendingType.lent;
      case 1:
        return LendingType.borrowed;
      default:
        return LendingType.lent;
    }
  }

  @override
  void write(BinaryWriter writer, LendingType obj) {
    switch (obj) {
      case LendingType.lent:
        writer.writeByte(0);
      case LendingType.borrowed:
        writer.writeByte(1);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LendingTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
