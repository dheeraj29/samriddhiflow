// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'category.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CategoryAdapter extends TypeAdapter<Category> {
  @override
  final typeId = 17;

  @override
  Category read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Category(
      id: fields[0] as String,
      name: fields[1] as String,
      usage: fields[2] as CategoryUsage,
      tag: fields[3] == null ? CategoryTag.none : fields[3] as CategoryTag,
      iconCode: fields[4] == null ? 0 : (fields[4] as num).toInt(),
      profileId: fields[5] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Category obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.usage)
      ..writeByte(3)
      ..write(obj.tag)
      ..writeByte(4)
      ..write(obj.iconCode)
      ..writeByte(5)
      ..write(obj.profileId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CategoryUsageAdapter extends TypeAdapter<CategoryUsage> {
  @override
  final typeId = 15;

  @override
  CategoryUsage read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return CategoryUsage.income;
      case 1:
        return CategoryUsage.expense;
      case 2:
        return CategoryUsage.both;
      default:
        return CategoryUsage.income;
    }
  }

  @override
  void write(BinaryWriter writer, CategoryUsage obj) {
    switch (obj) {
      case CategoryUsage.income:
        writer.writeByte(0);
      case CategoryUsage.expense:
        writer.writeByte(1);
      case CategoryUsage.both:
        writer.writeByte(2);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoryUsageAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CategoryTagAdapter extends TypeAdapter<CategoryTag> {
  @override
  final typeId = 16;

  @override
  CategoryTag read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return CategoryTag.none;
      case 1:
        return CategoryTag.capitalGain;
      case 3:
        return CategoryTag.directTax;
      case 4:
        return CategoryTag.budgetFree;
      case 5:
        return CategoryTag.taxFree;
      default:
        return CategoryTag.none;
    }
  }

  @override
  void write(BinaryWriter writer, CategoryTag obj) {
    switch (obj) {
      case CategoryTag.none:
        writer.writeByte(0);
      case CategoryTag.capitalGain:
        writer.writeByte(1);
      case CategoryTag.directTax:
        writer.writeByte(3);
      case CategoryTag.budgetFree:
        writer.writeByte(4);
      case CategoryTag.taxFree:
        writer.writeByte(5);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoryTagAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
