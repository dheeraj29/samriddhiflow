// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'insurance_policy.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class InsurancePolicyAdapter extends TypeAdapter<InsurancePolicy> {
  @override
  final typeId = 225;

  @override
  InsurancePolicy read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return InsurancePolicy(
      id: fields[0] as String,
      policyName: fields[1] as String,
      policyNumber: fields[2] as String,
      annualPremium: (fields[3] as num).toDouble(),
      sumAssured: (fields[4] as num).toDouble(),
      startDate: fields[5] as DateTime,
      maturityDate: fields[6] as DateTime,
      isUnitLinked: fields[7] == null ? false : fields[7] as bool,
      isHandicapDependent: fields[8] == null ? false : fields[8] as bool,
      isTaxExempt: fields[9] as bool?,
    );
  }

  @override
  void write(BinaryWriter writer, InsurancePolicy obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.policyName)
      ..writeByte(2)
      ..write(obj.policyNumber)
      ..writeByte(3)
      ..write(obj.annualPremium)
      ..writeByte(4)
      ..write(obj.sumAssured)
      ..writeByte(5)
      ..write(obj.startDate)
      ..writeByte(6)
      ..write(obj.maturityDate)
      ..writeByte(7)
      ..write(obj.isUnitLinked)
      ..writeByte(8)
      ..write(obj.isHandicapDependent)
      ..writeByte(9)
      ..write(obj.isTaxExempt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InsurancePolicyAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
