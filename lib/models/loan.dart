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
}
