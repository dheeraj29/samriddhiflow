import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/lending_record.dart';
import '../../providers.dart';

class LendingNotifier extends Notifier<List<LendingRecord>> {
  @override
  List<LendingRecord> build() {
    // Watch activeProfileId to refresh on switch
    ref.watch(activeProfileIdProvider);

    // Watch storage init
    final init = ref.watch(storageInitializerProvider);
    if (!init.hasValue) return [];

    final storage = ref.watch(storageServiceProvider);
    return storage.getLendingRecords();
  }

  Future<void> addRecord(LendingRecord record) async {
    final storage = ref.read(storageServiceProvider);
    await storage.saveLendingRecord(record);
    state = storage.getLendingRecords();
  }

  Future<void> updateRecord(LendingRecord record) async {
    final storage = ref.read(storageServiceProvider);
    await storage.saveLendingRecord(record);
    state = storage.getLendingRecords();
  }

  Future<void> deleteRecord(String id) async {
    final storage = ref.read(storageServiceProvider);
    await storage.deleteLendingRecord(id);
    state = storage.getLendingRecords();
  }
}

final lendingProvider =
    NotifierProvider<LendingNotifier, List<LendingRecord>>(LendingNotifier.new);

final totalLentProvider = Provider<double>((ref) {
  final records = ref.watch(lendingProvider);
  return records
      .where((r) => r.type == LendingType.lent && !r.isClosed)
      .fold(0.0, (sum, r) => sum + r.amount);
});

final totalBorrowedProvider = Provider<double>((ref) {
  final records = ref.watch(lendingProvider);
  return records
      .where((r) => r.type == LendingType.borrowed && !r.isClosed)
      .fold(0.0, (sum, r) => sum + r.amount);
});
