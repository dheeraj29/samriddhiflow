import 'package:hive_ce/hive.dart';
import 'package:uuid/uuid.dart';

part 'insurance_policy.g.dart';

@HiveType(typeId: 225)
class InsurancePolicy {
  InsurancePolicy copyWith({
    String? policyName,
    String? policyNumber,
    double? annualPremium,
    double? sumAssured,
    DateTime? startDate,
    DateTime? maturityDate,
    bool? isUnitLinked,
    bool? isHandicapDependent,
    bool? isTaxExempt,
  }) {
    return InsurancePolicy(
      id: id,
      policyName: policyName ?? this.policyName,
      policyNumber: policyNumber ?? this.policyNumber,
      annualPremium: annualPremium ?? this.annualPremium,
      sumAssured: sumAssured ?? this.sumAssured,
      startDate: startDate ?? this.startDate,
      maturityDate: maturityDate ?? this.maturityDate,
      isUnitLinked: isUnitLinked ?? this.isUnitLinked,
      isHandicapDependent: isHandicapDependent ?? this.isHandicapDependent,
      isTaxExempt: isTaxExempt ?? this.isTaxExempt,
    );
  }

  @HiveField(0)
  final String id;

  @HiveField(1)
  final String policyName;

  @HiveField(2)
  final String policyNumber;

  @HiveField(3)
  final double annualPremium;

  @HiveField(4)
  final double sumAssured;

  @HiveField(5)
  final DateTime startDate;

  @HiveField(6)
  final DateTime maturityDate;

  @HiveField(7)
  final bool isUnitLinked; // ULIPs have different rules (2.5L limit)

  @HiveField(8)
  final bool isHandicapDependent; // Section 80DD/U considerations

  @HiveField(9)
  final bool? isTaxExempt; // Persisted Tax Status (null = not calculated)

  InsurancePolicy({
    required this.id,
    required this.policyName,
    required this.policyNumber,
    required this.annualPremium,
    required this.sumAssured,
    required this.startDate,
    required this.maturityDate,
    this.isUnitLinked = false,
    this.isHandicapDependent = false,
    this.isTaxExempt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'policyName': policyName,
        'policyNumber': policyNumber,
        'annualPremium': annualPremium,
        'sumAssured': sumAssured,
        'startDate': startDate.toIso8601String(),
        'maturityDate': maturityDate.toIso8601String(),
        'isUnitLinked': isUnitLinked,
        'isHandicapDependent': isHandicapDependent,
        'isTaxExempt': isTaxExempt,
      };

  factory InsurancePolicy.fromMap(Map<String, dynamic> m) => InsurancePolicy(
        id: m['id'],
        policyName: m['policyName'],
        policyNumber: m['policyNumber'],
        annualPremium: (m['annualPremium'] as num).toDouble(),
        sumAssured: (m['sumAssured'] as num).toDouble(),
        startDate: DateTime.parse(m['startDate']),
        maturityDate: DateTime.parse(m['maturityDate']),
        isUnitLinked: m['isUnitLinked'] ?? false,
        isHandicapDependent: m['isHandicapDependent'] ?? false,
        isTaxExempt: m['isTaxExempt'],
      );

  factory InsurancePolicy.create({
    required String name,
    required String number,
    required double premium,
    required double sumAssured,
    required DateTime start,
    required DateTime maturity,
    bool isUlip = false,
    bool? isTaxExempt,
  }) {
    return InsurancePolicy(
      id: const Uuid().v4(),
      policyName: name,
      policyNumber: number,
      annualPremium: premium,
      sumAssured: sumAssured,
      startDate: start,
      maturityDate: maturity,
      isUnitLinked: isUlip,
      isTaxExempt: isTaxExempt,
    );
  }
}
