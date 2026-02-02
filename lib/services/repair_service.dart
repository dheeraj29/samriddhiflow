import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers.dart';

abstract class RepairJob {
  String get id;
  String get name;
  String get description;
  Future<int> run(WidgetRef ref);
}

class RepairAccountCurrencyJob extends RepairJob {
  @override
  String get id => 'repair_account_currency';
  @override
  String get name => 'Repair Account Currency';
  @override
  String get description =>
      'Fixes accounts with missing currency codes by setting them to your default currency.';

  @override
  Future<int> run(WidgetRef ref) async {
    final storage = ref.read(storageServiceProvider);
    final defaultCurrency = ref.read(currencyProvider);
    return await storage.repairAccountCurrencies(defaultCurrency);
  }
}

final repairServiceProvider = Provider((ref) => RepairService());

class RepairService {
  final List<RepairJob> jobs = [
    RepairAccountCurrencyJob(),
  ];

  RepairJob getJob(String id) {
    return jobs.firstWhere((j) => j.id == id,
        orElse: () => throw Exception('Job not found'));
  }
}
