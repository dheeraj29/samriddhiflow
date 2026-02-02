import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/services/repair_service.dart';
import 'package:samriddhi_flow/services/storage_service.dart';
import 'package:samriddhi_flow/providers.dart';

class MockStorageService extends Mock implements StorageService {}

// Fake Currency Notifier
class FakeCurrencyNotifier extends CurrencyNotifier {
  @override
  String build() => 'USD';
}

void main() {
  late MockStorageService mockStorage;

  setUp(() {
    mockStorage = MockStorageService();
    // Default behaviors
    when(() => mockStorage.repairAccountCurrencies(any()))
        .thenAnswer((_) async => 5); // Return 5 repaired
  });

  group('RepairJob Logic Tests', () {
    testWidgets('RepairAccountCurrencyJob calls storage properly',
        (tester) async {
      final job = RepairAccountCurrencyJob();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storageServiceProvider.overrideWithValue(mockStorage),
            currencyProvider.overrideWith(FakeCurrencyNotifier.new),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(builder: (context, ref, _) {
                return ElevatedButton(
                  onPressed: () async {
                    await job.run(ref);
                  },
                  child: const Text('Run Job'),
                );
              }),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Run Job'));
      // Pump to process the tap event
      await tester.pump();
      // Pump to allow the async microtasks (job.run) to execute
      // Since job.run interacts with storage which is mocked to return Future.value(5),
      // simple pump might be enough, but pumpAndSettle is safer for "eventually".
      await tester.pumpAndSettle();

      verify(() => mockStorage.repairAccountCurrencies('USD')).called(1);
    });
  });

  group('RepairService Tests', () {
    test('Service initializes with default jobs', () {
      final service = RepairService();
      expect(service.jobs.length, greaterThanOrEqualTo(1));
      expect(service.jobs.first, isA<RepairAccountCurrencyJob>());
    });

    test('getJob returns correct job', () {
      final service = RepairService();
      final job = service.getJob('repair_account_currency');
      expect(job, isNotNull);
      expect(job.name, 'Repair Account Currency');
    });
  });
}
