import 'package:flutter_test/flutter_test.dart';

import 'package:mockito/mockito.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samriddhi_flow/models/lending_record.dart';
import 'package:samriddhi_flow/services/lending/lending_provider.dart';
import 'package:samriddhi_flow/services/storage_service.dart';
import 'package:samriddhi_flow/providers.dart';

// Mock StorageService
class MockStorageService extends Mock implements StorageService {
  final List<LendingRecord> _records = [];

  @override
  List<LendingRecord> getLendingRecords() => List.from(_records);

  @override
  Future<void> saveLendingRecord(LendingRecord record) async {
    final index = _records.indexWhere((r) => r.id == record.id);
    if (index >= 0) {
      _records[index] = record;
    } else {
      _records.add(record);
    }
  }

  @override
  Future<void> deleteLendingRecord(String id) async {
    _records.removeWhere((r) => r.id == id);
  }

  @override
  String getActiveProfileId() => 'default';
}

void main() {
  late MockStorageService mockStorage;
  late ProviderContainer container;

  setUp(() {
    mockStorage = MockStorageService();
    container = ProviderContainer(
      overrides: [
        storageServiceProvider.overrideWithValue(mockStorage),
        storageInitializerProvider.overrideWith((ref) => Future.value()),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('Lending Feature Verification', () {
    test('Add Lending Record updates state and totals', () async {
      final notifier = container.read(lendingProvider.notifier);

      // 1. Add Lent Record
      final lendRecord = LendingRecord.create(
        personName: 'John Doe',
        amount: 5000,
        reason: 'Emergency',
        date: DateTime.now(),
        type: LendingType.lent,
      );
      await notifier.addRecord(lendRecord);

      expect(container.read(lendingProvider).length, 1);
      expect(container.read(totalLentProvider), 5000);
      expect(container.read(totalBorrowedProvider), 0);

      // 2. Add Borrowed Record
      final borrowRecord = LendingRecord.create(
        personName: 'Jane Smith',
        amount: 2000,
        reason: 'Lunch',
        date: DateTime.now(),
        type: LendingType.borrowed,
      );
      await notifier.addRecord(borrowRecord);

      expect(container.read(lendingProvider).length, 2);
      expect(container.read(totalLentProvider), 5000);
      expect(container.read(totalBorrowedProvider), 2000);
    });

    test('Closing a record removes it from totals', () async {
      final notifier = container.read(lendingProvider.notifier);
      final record = LendingRecord.create(
        personName: 'Alice',
        amount: 1000,
        reason: 'Test',
        date: DateTime.now(),
        type: LendingType.lent,
      );
      await notifier.addRecord(record);

      // Verify Initial
      expect(container.read(totalLentProvider), 1000);

      // Close Record
      final closedRecord =
          record.copyWith(isClosed: true, closedDate: DateTime.now());
      await notifier.updateRecord(closedRecord);

      // Verify Updated
      expect(container.read(lendingProvider).length, 1); // Still exists
      expect(container.read(lendingProvider).first.isClosed, true);
      expect(container.read(totalLentProvider), 0); // Removed from total
    });

    test('Deleting a record removes it completely', () async {
      final notifier = container.read(lendingProvider.notifier);
      final record = LendingRecord.create(
        personName: 'Bob',
        amount: 500,
        reason: 'Test',
        date: DateTime.now(),
        type: LendingType.borrowed,
      );
      await notifier.addRecord(record);

      expect(container.read(lendingProvider).length, 1);

      await notifier.deleteRecord(record.id);

      expect(container.read(lendingProvider).isEmpty, true);
      expect(container.read(totalBorrowedProvider), 0);
    });
  });
}
