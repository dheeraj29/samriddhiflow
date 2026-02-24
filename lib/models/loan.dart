import 'package:hive_ce/hive.dart';
import 'package:uuid/uuid.dart';

part 'loan.g.dart';

@HiveType(typeId: 4)
enum LoanTransactionType {
  @HiveField(0)
  emi,
  @HiveField(1)
  prepayment,
  @HiveField(2)
  rateChange,
  @HiveField(3)
  topup,
}

@HiveType(typeId: 5)
class LoanTransaction extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  DateTime date;

  @HiveField(2)
  double amount;

  @HiveField(3)
  LoanTransactionType type;

  @HiveField(4)
  double principalComponent;

  @HiveField(5)
  double interestComponent;

  @HiveField(6)
  double resultantPrincipal; // Balance after this txn

  LoanTransaction({
    required this.id,
    required this.date,
    required this.amount,
    required this.type,
    required this.principalComponent,
    required this.interestComponent,
    required this.resultantPrincipal,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'amount': amount,
      'type': type.index,
      'principalComponent': principalComponent,
      'interestComponent': interestComponent,
      'resultantPrincipal': resultantPrincipal,
    };
  }

  factory LoanTransaction.fromMap(Map<String, dynamic> map) {
    return LoanTransaction(
      id: map['id'],
      date: DateTime.parse(map['date']),
      amount: (map['amount'] as num).toDouble(),
      type: LoanTransactionType.values[map['type']],
      principalComponent: (map['principalComponent'] as num).toDouble(),
      interestComponent: (map['interestComponent'] as num).toDouble(),
      resultantPrincipal: (map['resultantPrincipal'] as num).toDouble(),
    );
  }
}

@HiveType(typeId: 9)
enum LoanType {
  @HiveField(0)
  personal,
  @HiveField(1)
  home,
  @HiveField(2)
  car,
  @HiveField(3)
  education,
  @HiveField(4)
  business,
  @HiveField(5)
  gold,
  @HiveField(6)
  other
}

@HiveType(typeId: 6)
class Loan extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  double totalPrincipal; // Initial Amount

  @HiveField(3)
  double remainingPrincipal;

  @HiveField(4)
  double interestRate; // Annual %

  @HiveField(5)
  int tenureMonths;

  @HiveField(6)
  DateTime startDate;

  @HiveField(7)
  double emiAmount;

  @HiveField(8)
  String? accountId; // For auto-deduction

  @HiveField(9)
  List<LoanTransaction> transactions;

  @HiveField(10)
  LoanType type;

  @HiveField(11)
  int emiDay; // Day of month for payment

  @HiveField(12)
  DateTime firstEmiDate;

  @HiveField(13)
  String? profileId;

  Loan({
    required this.id,
    required this.name,
    required this.totalPrincipal,
    required this.remainingPrincipal,
    required this.interestRate,
    required this.tenureMonths,
    required this.startDate,
    required this.emiAmount,
    this.accountId,
    this.transactions = const [],
    this.type = LoanType.personal,
    this.emiDay = 1,
    required this.firstEmiDate,
    this.profileId,
  });

  factory Loan.create({
    required String name,
    required double principal,
    required double rate,
    required int tenureMonths,
    required DateTime startDate,
    required double emiAmount,
    required int emiDay,
    required DateTime firstEmiDate,
    String? accountId,
    LoanType type = LoanType.personal,
    String? profileId = 'default',
  }) {
    return Loan(
      id: const Uuid().v4(),
      name: name,
      totalPrincipal: principal,
      remainingPrincipal: principal, // Initially same
      interestRate: rate,
      tenureMonths: tenureMonths,
      startDate: startDate,
      emiAmount: emiAmount,
      accountId: accountId,
      transactions: [],
      type: type,
      emiDay: emiDay,
      firstEmiDate: firstEmiDate,
      profileId: profileId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'totalPrincipal': totalPrincipal,
      'remainingPrincipal': remainingPrincipal,
      'interestRate': interestRate,
      'tenureMonths': tenureMonths,
      'startDate': startDate.toIso8601String(),
      'emiAmount': emiAmount,
      'accountId': accountId,
      'transactions': transactions.map((t) => t.toMap()).toList(),
      'type': type.index,
      'emiDay': emiDay,
      'firstEmiDate': firstEmiDate.toIso8601String(),
      'profileId': profileId,
    };
  }

  factory Loan.fromMap(Map<String, dynamic> map) {
    return Loan(
      id: map['id'],
      name: map['name'],
      totalPrincipal: (map['totalPrincipal'] as num).toDouble(),
      remainingPrincipal: (map['remainingPrincipal'] as num).toDouble(),
      interestRate: (map['interestRate'] as num).toDouble(),
      tenureMonths: map['tenureMonths'],
      startDate: DateTime.parse(map['startDate']),
      emiAmount: (map['emiAmount'] as num).toDouble(),
      accountId: map['accountId'],
      transactions: (map['transactions'] as List?)
              ?.map(
                  (t) => LoanTransaction.fromMap(Map<String, dynamic>.from(t)))
              .toList() ??
          [],
      type: LoanType.values[map['type'] ?? 0],
      emiDay: map['emiDay'] ?? 1,
      firstEmiDate: DateTime.parse(map['firstEmiDate']),
      profileId: map['profileId'],
    );
  }
}
