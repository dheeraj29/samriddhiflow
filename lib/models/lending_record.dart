import 'package:hive_ce/hive.dart';
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
  });

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
    );
  }
}
