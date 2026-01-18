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

  Account({
    required this.id,
    required this.name,
    required this.type,
    this.balance = 0.0,
    this.currency = 'USD',
    this.creditLimit,
    this.billingCycleDay,
    this.paymentDueDateDay,
    this.profileId,
  });

  factory Account.create({
    required String name,
    required AccountType type,
    double initialBalance = 0.0,
    String currency = 'USD',
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
    );
  }

  double calculateBilledAmount(List<Transaction> allTransactions) {
    if (type != AccountType.creditCard || billingCycleDay == null) {
      return balance;
    }

    // In this application's architecture, for Credit Cards:
    // 1. Account.balance stores the "Billed Balance" (last statement minus payments).
    // 2. StorageService skips updating balance for new expenses until the cycle rolls over.
    // Therefore, the Outstanding Bill is simply the current balance.
    return CurrencyUtils.roundTo2Decimals(balance.clamp(0.0, double.infinity));
  }
}
