import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers.dart';

abstract class RefReader {
  T read<T>(dynamic provider);
}

// Extension to allow WidgetRef to act as RefReader
extension WidgetRefReader on WidgetRef {
  RefReader get reader => _WidgetRefReader(this);
}

class _WidgetRefReader implements RefReader {
  final WidgetRef ref;
  _WidgetRefReader(this.ref);
  @override
  T read<T>(dynamic provider) => ref.read(provider);
}

abstract class RepairJob {
  String get id;
  String get name;
  String get description;
  Future<int> run(RefReader ref);
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
  Future<int> run(RefReader ref) async {
    final storage = ref.read(storageServiceProvider);
    final defaultCurrency = ref.read(currencyProvider);
    return await storage.repairAccountCurrencies(defaultCurrency);
  }
}

class RepairCreditCardBalanceJob extends RepairJob {
  @override
  String get id => 'repair_cc_balances';
  @override
  String get name => 'Recalculate Credit Card Bills';
  @override
  String get description =>
      'Forces a recalculation of all Credit Card balances based on billing cycles. Use this if your billed amount looks incorrect.';

  @override
  Future<int> run(RefReader ref) async {
    final storage = ref.read(storageServiceProvider);
    return await storage.recalculateCCBalances();
  }
}

final repairServiceProvider = Provider((ref) => RepairService());

class RepairService {
  final List<RepairJob> jobs = [
    RepairAccountCurrencyJob(),
    RepairCreditCardBalanceJob(),
  ];

  RepairJob getJob(String id) {
    return jobs.firstWhere((j) => j.id == id,
        orElse: () => throw Exception('Job not found'));
  }
}
