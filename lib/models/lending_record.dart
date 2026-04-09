import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:uuid/uuid.dart';

part 'lending_record.g.dart';

@HiveType(typeId: 31)
enum LendingType {
  @HiveField(0)
  lent,
  @HiveField(1)
  borrowed
}

@HiveType(typeId: 30)
class LendingRecord extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String personName;

  @HiveField(2)
  double amount;

  @HiveField(3)
  String reason;

  @HiveField(4)
  DateTime date;

  @HiveField(5)
  LendingType type;

  @HiveField(6)
  bool isClosed;

  @HiveField(7)
  DateTime? closedDate;

  @HiveField(8)
  String? profileId;

  @HiveField(9)
  List<LendingPayment> payments;

  LendingRecord({
    required this.id,
    required this.personName,
    required this.amount,
    required this.reason,
    required this.date,
    required this.type,
    this.isClosed = false,
    this.closedDate,
    this.profileId,
    this.payments = const [],
  });

  double get totalPaid =>
      payments.fold(0.0, (sum, payment) => sum + payment.amount);

  double get remainingAmount => amount - totalPaid;

  factory LendingRecord.create({
    required String personName,
    required double amount,
    required String reason,
    required DateTime date,
    required LendingType type,
    String? profileId = 'default',
  }) {
    return LendingRecord(
      id: const Uuid().v4(),
      personName: personName,
      amount: amount,
      reason: reason,
      date: date,
      type: type,
      profileId: profileId,
      payments: [],
    );
  }
  LendingRecord copyWith({
    String? id,
    String? personName,
    double? amount,
    String? reason,
    DateTime? date,
    LendingType? type,
    bool? isClosed,
    DateTime? closedDate,
    String? profileId,
    List<LendingPayment>? payments,
  }) {
    return LendingRecord(
      id: id ?? this.id,
      personName: personName ?? this.personName,
      amount: amount ?? this.amount,
      reason: reason ?? this.reason,
      date: date ?? this.date,
      type: type ?? this.type,
      isClosed: isClosed ?? this.isClosed,
      closedDate: closedDate ?? this.closedDate,
      profileId: profileId ?? this.profileId,
      payments: payments ?? this.payments,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'personName': personName,
      'amount': amount,
      'reason': reason,
      'date': date.toIso8601String(),
      'type': type.index,
      'isClosed': isClosed,
      'closedDate': closedDate?.toIso8601String(),
      'profileId': profileId,
      'payments': payments.map((p) => p.toMap()).toList(),
    };
  }

  factory LendingRecord.fromMap(Map<String, dynamic> map) {
    return LendingRecord(
      id: map['id'],
      personName: map['personName'],
      amount: (map['amount'] as num).toDouble(),
      reason: map['reason'],
      date: DateTime.parse(map['date']),
      type: LendingType.values[map['type']],
      isClosed: map['isClosed'] ?? false,
      closedDate:
          map['closedDate'] != null ? DateTime.parse(map['closedDate']) : null,
      profileId: map['profileId'],
      payments: (map['payments'] as List?)
              ?.map((p) => LendingPayment.fromMap(Map<String, dynamic>.from(p)))
              .toList() ??
          [],
    );
  }
}

@HiveType(typeId: 32)
class LendingPayment extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final double amount;

  @HiveField(2)
  final DateTime date;

  @HiveField(3)
  final String? note;

  LendingPayment({
    required this.id,
    required this.amount,
    required this.date,
    this.note,
  });

  factory LendingPayment.create({
    required double amount,
    required DateTime date,
    String? note,
  }) {
    return LendingPayment(
      id: const Uuid().v4(),
      amount: amount,
      date: date,
      note: note,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'date': date.toIso8601String(),
      'note': note,
    };
  }

  factory LendingPayment.fromMap(Map<String, dynamic> map) {
    return LendingPayment(
      id: map['id'],
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.parse(map['date']),
      note: map['note'],
    );
  }
}
