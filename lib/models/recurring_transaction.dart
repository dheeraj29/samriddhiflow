import 'package:hive_ce/hive.dart';
import 'package:uuid/uuid.dart';
import 'transaction.dart';

part 'recurring_transaction.g.dart';

@HiveType(typeId: 7)
enum Frequency {
  @HiveField(0)
  daily,
  @HiveField(1)
  weekly,
  @HiveField(2)
  monthly,
  @HiveField(3)
  yearly,
}

@HiveType(typeId: 10)
enum ScheduleType {
  @HiveField(0)
  fixedDate,
  @HiveField(1)
  everyWeekend,
  @HiveField(2)
  lastWeekend,
  @HiveField(3)
  specificWeekday,
  @HiveField(4)
  lastDayOfMonth,
  @HiveField(5)
  lastWorkingDay,
  @HiveField(6)
  firstWorkingDay,
}

@HiveType(typeId: 8)
class RecurringTransaction extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  double amount;

  @HiveField(3)
  String category;

  @HiveField(4)
  String? accountId;

  @HiveField(5)
  Frequency frequency;

  @HiveField(6)
  int interval;

  @HiveField(7)
  int? byMonthDay;

  @HiveField(8)
  int? byWeekDay;

  @HiveField(9)
  DateTime nextExecutionDate;

  @HiveField(10)
  bool isActive;

  @HiveField(11)
  ScheduleType scheduleType;

  @HiveField(12)
  int? selectedWeekday; // 1 (Mon) - 7 (Sun)

  @HiveField(13)
  bool adjustForHolidays;

  @HiveField(14)
  String profileId;

  @HiveField(15)
  TransactionType type;

  RecurringTransaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    this.accountId,
    required this.frequency,
    this.interval = 1,
    this.byMonthDay,
    this.byWeekDay,
    required this.nextExecutionDate,
    this.isActive = true,
    this.scheduleType = ScheduleType.fixedDate,
    this.selectedWeekday,
    this.adjustForHolidays = false,
    this.profileId = 'default',
    this.type = TransactionType.expense,
  });

  factory RecurringTransaction.create({
    required String title,
    required double amount,
    required String category,
    String? accountId,
    required Frequency frequency,
    int interval = 1,
    int? byMonthDay,
    int? byWeekDay,
    required DateTime startDate,
    ScheduleType scheduleType = ScheduleType.fixedDate,
    int? selectedWeekday,
    bool adjustForHolidays = false,
    String profileId = 'default',
    TransactionType type = TransactionType.expense,
  }) {
    return RecurringTransaction(
      id: const Uuid().v4(),
      title: title,
      amount: amount,
      category: category,
      accountId: accountId,
      frequency: frequency,
      interval: interval,
      byMonthDay: byMonthDay,
      byWeekDay: byWeekDay,
      nextExecutionDate: startDate,
      isActive: true,
      scheduleType: scheduleType,
      selectedWeekday: selectedWeekday,
      adjustForHolidays: adjustForHolidays,
      profileId: profileId,
      type: type,
    );
  }

  DateTime calculateNextOccurrence(DateTime fromDate) {
    DateTime next = fromDate;

    // Basic increment based on frequency
    if (frequency == Frequency.daily) {
      next = fromDate.add(Duration(days: interval));
    } else if (frequency == Frequency.weekly) {
      next = fromDate.add(Duration(days: 7 * interval));
    } else if (frequency == Frequency.monthly) {
      next = DateTime(fromDate.year, fromDate.month + interval, fromDate.day);
    } else if (frequency == Frequency.yearly) {
      next = DateTime(fromDate.year + interval, fromDate.month, fromDate.day);
    }

    // Apply schedule type specific logic if needed (e.g. last day of month)
    if (scheduleType == ScheduleType.lastDayOfMonth) {
      next = DateTime(next.year, next.month + 1, 0); // Last day of that month
    } else if (scheduleType == ScheduleType.specificWeekday &&
        selectedWeekday != null) {
      // Ensure it falls on the correct weekday
      while (next.weekday != selectedWeekday) {
        next = next.add(const Duration(days: 1));
      }
    }

    return next;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'category': category,
      'accountId': accountId,
      'frequency': frequency.index,
      'interval': interval,
      'byMonthDay': byMonthDay,
      'byWeekDay': byWeekDay,
      'nextExecutionDate': nextExecutionDate.toIso8601String(),
      'isActive': isActive,
      'scheduleType': scheduleType.index,
      'selectedWeekday': selectedWeekday,
      'adjustForHolidays': adjustForHolidays,
      'profileId': profileId,
      'type': type.index,
    };
  }

  factory RecurringTransaction.fromMap(Map<String, dynamic> map) {
    return RecurringTransaction(
      id: map['id'],
      title: map['title'],
      amount: (map['amount'] as num).toDouble(),
      category: map['category'],
      accountId: map['accountId'],
      frequency: Frequency.values[map['frequency']],
      interval: map['interval'] ?? 1,
      byMonthDay: map['byMonthDay'],
      byWeekDay: map['byWeekDay'],
      nextExecutionDate: DateTime.parse(map['nextExecutionDate']),
      isActive: map['isActive'] ?? true,
      scheduleType: ScheduleType.values[map['scheduleType'] ?? 0],
      selectedWeekday: map['selectedWeekday'],
      adjustForHolidays: map['adjustForHolidays'] ?? false,
      profileId: map['profileId'] ?? 'default',
      type:
          TransactionType.values[map['type'] ?? TransactionType.expense.index],
    );
  }
}
