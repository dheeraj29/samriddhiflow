import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/services/repair_service.dart';
import '../../widget/test_mocks.dart';

class MockRefReader extends Mock implements RefReader {}

void main() {
  late MockStorageService mockStorage;
  late RepairService repairService;
  late MockRefReader mockRef;

  setUp(() {
    mockStorage = MockStorageService();
    repairService = RepairService();
    mockRef = MockRefReader();

    when(() => mockRef.read(storageServiceProvider)).thenReturn(mockStorage);
  });

  group('RepairService', () {
    test('jobs list is not empty', () {
      expect(repairService.jobs, isNotEmpty);
      expect(repairService.jobs.length, 2);
    });

    test('getJob returns correct job', () {
      final job = repairService.getJob('repair_account_currency');
      expect(job, isA<RepairAccountCurrencyJob>());
      expect(job.name, 'Repair Account Currency');
    });

    test('getJob throws on invalid id', () {
      expect(() => repairService.getJob('invalid_id'), throwsException);
    });
  });

  group('RepairAccountCurrencyJob', () {
    test('run calls storage.repairAccountCurrencies', () async {
      final job = RepairAccountCurrencyJob();

      when(() => mockStorage.repairAccountCurrencies(any()))
          .thenAnswer((_) async => 5);
      when(() => mockRef.read(currencyProvider)).thenReturn('en_IN');

      final count = await job.run(mockRef);

      verify(() => mockStorage.repairAccountCurrencies('en_IN')).called(1);
      expect(count, 5);
    });
  });
}
