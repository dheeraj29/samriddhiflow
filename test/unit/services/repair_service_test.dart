import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/models/account.dart';
import 'package:samriddhi_flow/services/repair_service.dart';
import 'package:samriddhi_flow/services/storage_service.dart';
import 'package:samriddhi_flow/providers.dart';

class MockRefReader extends Mock implements RefReader {}

class MockStorageService extends Mock implements StorageService {}

void main() {
  late RepairService repairService;
  late MockRefReader mockRef;
  late MockStorageService mockStorage;

  setUp(() {
    repairService = RepairService();
    mockRef = MockRefReader();
    mockStorage = MockStorageService();

    when(() => mockRef.read(storageServiceProvider)).thenReturn(mockStorage);
    when(() => mockRef.read(currencyProvider)).thenReturn('INR');
  });

  test('RepairService contains all jobs', () {
    expect(repairService.jobs.any((j) => j is RepairAccountCurrencyJob), true);
    expect(
        repairService.jobs.any((j) => j is RecalculateBilledAmountJob), true);
  });

  test('getJob returns job by id or throws', () {
    final job = repairService.getJob('repair_account_currency');
    expect(job, isA<RepairAccountCurrencyJob>());
    expect(() => repairService.getJob('non_existent'), throwsException);
  });

  group('RecalculateBilledAmountJob', () {
    final job = RecalculateBilledAmountJob();

    test('runs for specific accountId', () async {
      when(() => mockStorage.recalculateBilledAmount(any()))
          .thenAnswer((_) async {});

      final count = await job.run(mockRef, args: {'accountId': 'acc1'});

      expect(count, 1);
      verify(() => mockStorage.recalculateBilledAmount('acc1')).called(1);
    });

    test('runs for all credit cards if no accountId provided', () async {
      final acc1 = Account(
          id: 'c1', name: 'C1', type: AccountType.creditCard, balance: 0);
      final acc2 =
          Account(id: 's1', name: 'S1', type: AccountType.savings, balance: 0);

      when(() => mockStorage.getAccounts()).thenReturn([acc1, acc2]);
      when(() => mockStorage.recalculateBilledAmount(any()))
          .thenAnswer((_) async {});

      final count = await job.run(mockRef);

      expect(count, 1); // Only c1
      verify(() => mockStorage.recalculateBilledAmount('c1')).called(1);
      verifyNever(() => mockStorage.recalculateBilledAmount('s1'));
    });
  });

  group('RepairAccountCurrencyJob', () {
    final job = RepairAccountCurrencyJob();

    test('calls repairAccountCurrencies with default currency', () async {
      when(() => mockStorage.repairAccountCurrencies(any()))
          .thenAnswer((_) async => 5);

      final count = await job.run(mockRef);

      expect(count, 5);
      verify(() => mockStorage.repairAccountCurrencies('INR')).called(1);
    });
  });

  test('RepairJob properties check', () {
    final job = RecalculateBilledAmountJob();
    expect(job.name, isNotEmpty);
    expect(job.description, isNotEmpty);
    expect(job.showInSettings, false);
  });
}
