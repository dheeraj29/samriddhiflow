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
    );
  }

  @override
  void write(BinaryWriter writer, LendingRecord obj) {
    writer
      ..writeByte(9)
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
      ..write(obj.profileId);
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
