import 'package:hive_ce/hive.dart';
import 'package:uuid/uuid.dart';

part 'transaction.g.dart';

@HiveType(typeId: 2)
enum TransactionType {
  @HiveField(0)
  income,
  @HiveField(1)
  expense,
  @HiveField(2)
  transfer,
}

@HiveType(typeId: 3)
class Transaction extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String title; // Description

  @HiveField(2)
  double amount;

  @HiveField(3)
  DateTime date;

  @HiveField(4)
  TransactionType type;

  @HiveField(5)
  String category;

  @HiveField(6)
  String? accountId; // Source Account

  @HiveField(7)
  String? toAccountId; // Destination for transfers

  @HiveField(8)
  String? loanId; // Linked Loan if applicable

  @HiveField(9)
  final bool isRecurringInstance;

  @HiveField(10)
  bool isDeleted;

  @HiveField(11)
  int? holdingTenureMonths; // For capital gain tracking

  @HiveField(12)
  double? gainAmount;

  @HiveField(13)
  String? profileId;

  Transaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.type,
    required this.category,
    this.accountId,
    this.toAccountId,
    this.loanId,
    this.isRecurringInstance = false,
    this.isDeleted = false,
    this.holdingTenureMonths,
    this.gainAmount,
    this.profileId,
  });

  factory Transaction.create({
    required String title,
    required double amount,
    required DateTime date,
    required TransactionType type,
    required String category,
    String? accountId,
    String? toAccountId,
    String? loanId,
    bool isRecurringInstance = false,
    int? holdingTenureMonths,
    double? gainAmount,
    String? profileId = 'default',
  }) {
    return Transaction(
      id: const Uuid().v4(),
      title: title,
      amount: amount,
      date: date,
      type: type,
      category: category,
      accountId: accountId,
      toAccountId: toAccountId,
      loanId: loanId,
      isRecurringInstance: isRecurringInstance,
      isDeleted: false,
      holdingTenureMonths: holdingTenureMonths,
      gainAmount: gainAmount,
      profileId: profileId,
    );
  }

  Transaction copyWith({
    String? id,
    String? title,
    double? amount,
    DateTime? date,
    TransactionType? type,
    String? category,
    String? accountId,
    String? toAccountId,
    String? loanId,
    bool? isRecurringInstance,
    bool? isDeleted,
    int? holdingTenureMonths,
    double? gainAmount,
    String? profileId,
  }) {
    return Transaction(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      type: type ?? this.type,
      category: category ?? this.category,
      accountId: accountId ?? this.accountId,
      toAccountId: toAccountId ?? this.toAccountId,
      loanId: loanId ?? this.loanId,
      isRecurringInstance: isRecurringInstance ?? this.isRecurringInstance,
      isDeleted: isDeleted ?? this.isDeleted,
      holdingTenureMonths: holdingTenureMonths ?? this.holdingTenureMonths,
      gainAmount: gainAmount ?? this.gainAmount,
      profileId: profileId ?? this.profileId,
    );
  }
}
