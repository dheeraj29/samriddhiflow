import 'package:hive_ce/hive.dart';
import 'package:uuid/uuid.dart';

part 'profile.g.dart';

@HiveType(
    typeId: 20) // Using typeId 20 for Profile to avoid conflict with Loan (6)
class Profile extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String currencyLocale;

  @HiveField(3)
  double monthlyBudget;

  Profile({
    required this.id,
    required this.name,
    this.currencyLocale = 'en_IN',
    this.monthlyBudget = 0.0,
  });

  factory Profile.create(
      {required String name,
      String currencyLocale = 'en_IN',
      double monthlyBudget = 0.0}) {
    return Profile(
      id: const Uuid().v4(),
      name: name,
      currencyLocale: currencyLocale,
      monthlyBudget: monthlyBudget,
    );
  }
}
