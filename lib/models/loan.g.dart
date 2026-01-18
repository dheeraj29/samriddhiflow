// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'loan.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LoanTransactionAdapter extends TypeAdapter<LoanTransaction> {
  @override
  final typeId = 5;

  @override
  LoanTransaction read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LoanTransaction(
      id: fields[0] as String,
      date: fields[1] as DateTime,
      amount: (fields[2] as num).toDouble(),
      type: fields[3] as LoanTransactionType,
      principalComponent: (fields[4] as num).toDouble(),
      interestComponent: (fields[5] as num).toDouble(),
      resultantPrincipal: (fields[6] as num).toDouble(),
    );
  }

  @override
  void write(BinaryWriter writer, LoanTransaction obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.amount)
      ..writeByte(3)
      ..write(obj.type)
      ..writeByte(4)
      ..write(obj.principalComponent)
      ..writeByte(5)
      ..write(obj.interestComponent)
      ..writeByte(6)
      ..write(obj.resultantPrincipal);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoanTransactionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class LoanAdapter extends TypeAdapter<Loan> {
  @override
  final typeId = 6;

  @override
  Loan read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Loan(
      id: fields[0] as String,
      name: fields[1] as String,
      totalPrincipal: (fields[2] as num).toDouble(),
      remainingPrincipal: (fields[3] as num).toDouble(),
      interestRate: (fields[4] as num).toDouble(),
      tenureMonths: (fields[5] as num).toInt(),
      startDate: fields[6] as DateTime,
      emiAmount: (fields[7] as num).toDouble(),
      accountId: fields[8] as String?,
      transactions: fields[9] == null
          ? const []
          : (fields[9] as List).cast<LoanTransaction>(),
      type: fields[10] == null ? LoanType.personal : fields[10] as LoanType,
      emiDay: fields[11] == null ? 1 : (fields[11] as num).toInt(),
      firstEmiDate: fields[12] as DateTime,
      profileId: fields[13] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Loan obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.totalPrincipal)
      ..writeByte(3)
      ..write(obj.remainingPrincipal)
      ..writeByte(4)
      ..write(obj.interestRate)
      ..writeByte(5)
      ..write(obj.tenureMonths)
      ..writeByte(6)
      ..write(obj.startDate)
      ..writeByte(7)
      ..write(obj.emiAmount)
      ..writeByte(8)
      ..write(obj.accountId)
      ..writeByte(9)
      ..write(obj.transactions)
      ..writeByte(10)
      ..write(obj.type)
      ..writeByte(11)
      ..write(obj.emiDay)
      ..writeByte(12)
      ..write(obj.firstEmiDate)
      ..writeByte(13)
      ..write(obj.profileId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoanAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class LoanTransactionTypeAdapter extends TypeAdapter<LoanTransactionType> {
  @override
  final typeId = 4;

  @override
  LoanTransactionType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return LoanTransactionType.emi;
      case 1:
        return LoanTransactionType.prepayment;
      case 2:
        return LoanTransactionType.rateChange;
      case 3:
        return LoanTransactionType.topup;
      default:
        return LoanTransactionType.emi;
    }
  }

  @override
  void write(BinaryWriter writer, LoanTransactionType obj) {
    switch (obj) {
      case LoanTransactionType.emi:
        writer.writeByte(0);
      case LoanTransactionType.prepayment:
        writer.writeByte(1);
      case LoanTransactionType.rateChange:
        writer.writeByte(2);
      case LoanTransactionType.topup:
        writer.writeByte(3);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoanTransactionTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class LoanTypeAdapter extends TypeAdapter<LoanType> {
  @override
  final typeId = 9;

  @override
  LoanType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return LoanType.personal;
      case 1:
        return LoanType.home;
      case 2:
        return LoanType.car;
      case 3:
        return LoanType.education;
      case 4:
        return LoanType.business;
      case 5:
        return LoanType.gold;
      case 6:
        return LoanType.other;
      default:
        return LoanType.personal;
    }
  }

  @override
  void write(BinaryWriter writer, LoanType obj) {
    switch (obj) {
      case LoanType.personal:
        writer.writeByte(0);
      case LoanType.home:
        writer.writeByte(1);
      case LoanType.car:
        writer.writeByte(2);
      case LoanType.education:
        writer.writeByte(3);
      case LoanType.business:
        writer.writeByte(4);
      case LoanType.gold:
        writer.writeByte(5);
      case LoanType.other:
        writer.writeByte(6);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoanTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
