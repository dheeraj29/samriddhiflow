import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers.dart';
import '../../models/account.dart';

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
  @override // coverage:ignore-line
  T read<T>(dynamic provider) => ref.read(provider); // coverage:ignore-line
}

abstract class RepairJob {
  String get id;
  String get name;
  String get description;
  bool get showInSettings => true; // coverage:ignore-line
  Future<int> run(RefReader ref, {Map<String, dynamic>? args});
}

class RecalculateBilledAmountJob extends RepairJob {
  @override
  String get id => 'recalculate_billed_amount';
  @override
  String get name => 'Recalculate Billed Amount';
  @override
  String get description =>
      'Refreshes the billing cycle dates to ensure the Billed Amount display is accurate based on transaction history.';
  @override
  bool get showInSettings => false;

  @override
  Future<int> run(RefReader ref, {Map<String, dynamic>? args}) async {
    final storage = ref.read(storageServiceProvider);
    final accountId = args?['accountId'] as String?;

    int count = 0;
    if (accountId != null) {
      await storage.recalculateBilledAmount(accountId);
      count++;
    } else {
      // Recalculate all accounts
      final accounts = storage.getAccounts();
      for (var acc in accounts) {
        if (acc.type == AccountType.creditCard) {
          await storage.recalculateBilledAmount(acc.id);
          count++;
        }
      }
    }
    return count;
  }
}

class RepairAccountCurrencyJob extends RepairJob {
  @override
  String get id => 'repair_account_currency';
  @override // coverage:ignore-line
  String get name => 'Repair Account Currency';
  @override // coverage:ignore-line
  String get description =>
      'Fixes accounts with missing currency codes by setting them to your default currency.';

  @override
  Future<int> run(RefReader ref, {Map<String, dynamic>? args}) async {
    final storage = ref.read(storageServiceProvider);
    final defaultCurrency = ref.read(currencyProvider);
    return await storage.repairAccountCurrencies(defaultCurrency);
  }
}

final repairServiceProvider = Provider((ref) => RepairService());

class RepairService {
  final List<RepairJob> jobs = [
    RepairAccountCurrencyJob(),
    RecalculateBilledAmountJob(),
  ];

  RepairJob getJob(String id) {
    return jobs.firstWhere((j) => j.id == id,
        orElse: () => throw Exception('Job not found'));
  }
}
