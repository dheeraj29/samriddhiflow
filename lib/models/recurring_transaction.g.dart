// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recurring_transaction.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RecurringTransactionAdapter extends TypeAdapter<RecurringTransaction> {
  @override
  final typeId = 8;

  @override
  RecurringTransaction read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RecurringTransaction(
      id: fields[0] as String,
      title: fields[1] as String,
      amount: (fields[2] as num).toDouble(),
      category: fields[3] as String,
      accountId: fields[4] as String?,
      frequency: fields[5] as Frequency,
      interval: fields[6] == null ? 1 : (fields[6] as num).toInt(),
      byMonthDay: (fields[7] as num?)?.toInt(),
      byWeekDay: (fields[8] as num?)?.toInt(),
      nextExecutionDate: fields[9] as DateTime,
      isActive: fields[10] == null ? true : fields[10] as bool,
      scheduleType: fields[11] == null
          ? ScheduleType.fixedDate
          : fields[11] as ScheduleType,
      selectedWeekday: (fields[12] as num?)?.toInt(),
      adjustForHolidays: fields[13] == null ? false : fields[13] as bool,
      profileId: fields[14] == null ? 'default' : fields[14] as String,
    );
  }

  @override
  void write(BinaryWriter writer, RecurringTransaction obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.category)
      ..writeByte(4)
      ..write(obj.accountId)
      ..writeByte(5)
      ..write(obj.frequency)
      ..writeByte(6)
      ..write(obj.interval)
      ..writeByte(7)
      ..write(obj.byMonthDay)
      ..writeByte(8)
      ..write(obj.byWeekDay)
      ..writeByte(9)
      ..write(obj.nextExecutionDate)
      ..writeByte(10)
      ..write(obj.isActive)
      ..writeByte(11)
      ..write(obj.scheduleType)
      ..writeByte(12)
      ..write(obj.selectedWeekday)
      ..writeByte(13)
      ..write(obj.adjustForHolidays)
      ..writeByte(14)
      ..write(obj.profileId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecurringTransactionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class FrequencyAdapter extends TypeAdapter<Frequency> {
  @override
  final typeId = 7;

  @override
  Frequency read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return Frequency.daily;
      case 1:
        return Frequency.weekly;
      case 2:
        return Frequency.monthly;
      case 3:
        return Frequency.yearly;
      default:
        return Frequency.daily;
    }
  }

  @override
  void write(BinaryWriter writer, Frequency obj) {
    switch (obj) {
      case Frequency.daily:
        writer.writeByte(0);
      case Frequency.weekly:
        writer.writeByte(1);
      case Frequency.monthly:
        writer.writeByte(2);
      case Frequency.yearly:
        writer.writeByte(3);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FrequencyAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ScheduleTypeAdapter extends TypeAdapter<ScheduleType> {
  @override
  final typeId = 10;

  @override
  ScheduleType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ScheduleType.fixedDate;
      case 1:
        return ScheduleType.everyWeekend;
      case 2:
        return ScheduleType.lastWeekend;
      case 3:
        return ScheduleType.specificWeekday;
      case 4:
        return ScheduleType.lastDayOfMonth;
      case 5:
        return ScheduleType.lastWorkingDay;
      default:
        return ScheduleType.fixedDate;
    }
  }

  @override
  void write(BinaryWriter writer, ScheduleType obj) {
    switch (obj) {
      case ScheduleType.fixedDate:
        writer.writeByte(0);
      case ScheduleType.everyWeekend:
        writer.writeByte(1);
      case ScheduleType.lastWeekend:
        writer.writeByte(2);
      case ScheduleType.specificWeekday:
        writer.writeByte(3);
      case ScheduleType.lastDayOfMonth:
        writer.writeByte(4);
      case ScheduleType.lastWorkingDay:
        writer.writeByte(5);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScheduleTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
