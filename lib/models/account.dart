import 'package:hive_ce/hive.dart';
import '../utils/currency_utils.dart';
import 'package:uuid/uuid.dart';
import 'transaction.dart';

part 'account.g.dart';

@HiveType(typeId: 0)
enum AccountType {
  @HiveField(0)
  savings,
  @HiveField(1)
  creditCard,
  @HiveField(2)
  wallet,
}

@HiveType(typeId: 1)
class Account extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  AccountType type;

  @HiveField(3)
  double balance;

  @HiveField(4)
  String currency;

  // Credit Card Specifics
  @HiveField(5)
  double? creditLimit;

  @HiveField(6)
  int? billingCycleDay; // e.g., 15 for 15th of the month

  @HiveField(7)
  int? paymentDueDateDay; // e.g., 5 for 5th of next month

  @HiveField(8)
  String? profileId;

  // Billing Cycle Freeze Fields
  @HiveField(9)
  DateTime? freezeDate;

  @HiveField(10)
  bool isFrozen;

  @HiveField(11)
  bool isFrozenCalculated;

  @HiveField(13)
  DateTime? firstStatementDate;

  @HiveField(12)
  bool isPinned;

  Account({
    required this.id,
    required this.name,
    required this.type,
    this.balance = 0.0,
    this.currency = '',
    this.creditLimit,
    this.billingCycleDay,
    this.paymentDueDateDay,
    this.profileId,
    this.freezeDate,
    this.isFrozen = false,
    this.isFrozenCalculated = false,
    this.isPinned = false,
    this.firstStatementDate,
  });

  factory Account.create({
    required String name,
    required AccountType type,
    double initialBalance = 0.0,
    String currency = '',
    double? creditLimit,
    int? billingCycleDay,
    int? paymentDueDateDay,
    String? profileId = 'default',
  }) {
    return Account(
      id: const Uuid().v4(),
      name: name,
      type: type,
      balance: initialBalance,
      currency: currency,
      creditLimit: creditLimit,
      billingCycleDay: billingCycleDay,
      paymentDueDateDay: paymentDueDateDay,
      profileId: profileId,
      freezeDate: null,
      isFrozen: false,
      isFrozenCalculated: false,
      isPinned: false,
      firstStatementDate: null,
    );
  }

  factory Account.empty() {
    return Account(
      id: '',
      name: '',
      type: AccountType.savings,
    );
  }

  double calculateBilledAmount(List<Transaction> allTransactions) {
    if (type != AccountType.creditCard || billingCycleDay == null) {
      return balance;
    }

    // In this application's architecture, for Credit Cards:
    // 1. Account.balance stores the "Billed Balance" (last statement minus payments).
    // 2. StorageService skips updating balance for new expenses AND payments until the cycle rolls over.
    // Therefore, the Outstanding Bill is simply the current balance.
    return CurrencyUtils.roundTo2Decimals(balance.clamp(0.0, double.infinity));
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'balance': balance,
      'type': type.index,
      'profileId': profileId,
      'billingCycleDay': billingCycleDay,
      'paymentDueDateDay': paymentDueDateDay,
      'creditLimit': creditLimit,
      'currency': currency,
      'freezeDate': freezeDate?.millisecondsSinceEpoch,
      'isFrozen': isFrozen,
      'isFrozenCalculated': isFrozenCalculated,
      'isPinned': isPinned,
      'firstStatementDate': firstStatementDate?.millisecondsSinceEpoch,
    };
  }

  Account copyWith({
    String? id,
    String? name,
    AccountType? type,
    double? balance,
    String? currency,
    double? creditLimit,
    int? billingCycleDay,
    int? paymentDueDateDay,
    String? profileId,
    DateTime? freezeDate,
    bool? isFrozen,
    bool? isFrozenCalculated,
    bool? isPinned,
    DateTime? firstStatementDate,
  }) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      balance: balance ?? this.balance,
      currency: currency ?? this.currency,
      creditLimit: creditLimit ?? this.creditLimit,
      billingCycleDay: billingCycleDay ?? this.billingCycleDay,
      paymentDueDateDay: paymentDueDateDay ?? this.paymentDueDateDay,
      profileId: profileId ?? this.profileId,
      freezeDate: freezeDate ?? this.freezeDate,
      isFrozen: isFrozen ?? this.isFrozen,
      isFrozenCalculated: isFrozenCalculated ?? this.isFrozenCalculated,
      isPinned: isPinned ?? this.isPinned,
      firstStatementDate: firstStatementDate ?? this.firstStatementDate,
    );
  }

  factory Account.fromMap(Map<String, dynamic> map) {
    double balance = (map['balance'] as num).toDouble();
    if (balance.isInfinite || balance.isNaN) balance = 0.0;

    double? creditLimit = (map['creditLimit'] as num?)?.toDouble();
    if (creditLimit != null && (creditLimit.isInfinite || creditLimit.isNaN)) {
      creditLimit = 0.0;
    }

    return Account(
      id: map['id'],
      name: map['name'],
      balance: balance,
      type: AccountType.values[map['type']],
      profileId: map['profileId'] as String?,
      billingCycleDay: map['billingCycleDay'] as int?,
      paymentDueDateDay: map['paymentDueDateDay'] as int?,
      creditLimit: creditLimit,
      currency: map['currency'] ?? '',
      freezeDate: map['freezeDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['freezeDate'] as int)
          : null,
      isFrozen: map['isFrozen'] as bool? ?? false,
      isFrozenCalculated: map['isFrozenCalculated'] as bool? ?? false,
      isPinned: map['isPinned'] as bool? ?? false,
      firstStatementDate: map['firstStatementDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(// coverage:ignore-line
              map['firstStatementDate'] as int) // coverage:ignore-line
          : null,
    );
  }
}
