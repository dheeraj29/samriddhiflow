import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/services/storage_service.dart';
import 'package:samriddhi_flow/models/loan.dart';
import 'package:samriddhi_flow/models/recurring_transaction.dart';
import 'package:samriddhi_flow/models/taxes/insurance_policy.dart';
import 'package:samriddhi_flow/models/taxes/tax_data.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import 'dart:io';
import 'package:path/path.dart' as p;

class MockStorageService extends Mock implements StorageService {}

class MockBox<T> extends Mock implements Box<T> {}

class MockProfileNotifier extends ProfileNotifier {
  final String initialValue;
  MockProfileNotifier(this.initialValue);

  @override
  String build() => initialValue;

  set stateValue(String v) => state = v;
}

void main() {
  late MockStorageService mockStorage;
  late String tempPath;

  setUpAll(() async {
    tempPath = p.join(
        Directory.current.path, '.dart_tool', 'test', 'profile_sync_test');
    final dir = Directory(tempPath);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    Hive.init(tempPath);

    // Open boxes used in providers.dart
    await Hive.openBox<Loan>('loans');
    await Hive.openBox<RecurringTransaction>('recurring');
    await Hive.openBox<InsurancePolicy>('insurance_policies');
    await Hive.openBox<TaxYearData>('tax_data');
    await Hive.openBox('settings'); // activeProfileIdProvider uses this
  });

  setUp(() {
    mockStorage = MockStorageService();
    registerFallbackValue(2025);

    when(() => mockStorage.getActiveProfileId()).thenReturn('p1');
    when(() => mockStorage.getLoans()).thenReturn([]);
    when(() => mockStorage.getRecurring()).thenReturn([]);
    when(() => mockStorage.getInsurancePolicies()).thenReturn([]);
    when(() => mockStorage.getTaxYearData(any())).thenReturn(null);
    when(() => mockStorage.getAllTaxYearData()).thenReturn([]);
    when(() => mockStorage.getMonthlyBudget()).thenReturn(0.0);
  });

  test('Providers rebuild when activeProfileId changes', () async {
    final container = ProviderContainer(
      overrides: [
        storageServiceProvider.overrideWithValue(mockStorage),
        storageInitializerProvider
            .overrideWithValue(const AsyncValue.data(null)),
        activeProfileIdProvider.overrideWith(() => MockProfileNotifier('p1')),
      ],
    );

    // Initial data for profile 'p1'
    when(() => mockStorage.getMonthlyBudget()).thenReturn(100.0);

    // Read the provider to start the watch
    expect(container.read(monthlyBudgetProvider), 100.0);

    // Change profile
    (container.read(activeProfileIdProvider.notifier) as MockProfileNotifier)
        .stateValue = 'p2';

    // New data for profile 'p2'
    when(() => mockStorage.getMonthlyBudget()).thenReturn(200.0);

    // Re-read. It should have rebuilt.
    expect(container.read(monthlyBudgetProvider), 200.0);
  });

  test('Stream providers rebuild when activeProfileId changes', () async {
    final container = ProviderContainer(
      overrides: [
        storageServiceProvider.overrideWithValue(mockStorage),
        storageInitializerProvider
            .overrideWithValue(const AsyncValue.data(null)),
        activeProfileIdProvider.overrideWith(() => MockProfileNotifier('p1')),
      ],
    );

    // Profile 1
    when(() => mockStorage.getLoans()).thenReturn([
      Loan(
          id: 'l1',
          name: 'Loan 1',
          totalPrincipal: 1000,
          remainingPrincipal: 1000,
          interestRate: 10,
          tenureMonths: 12,
          startDate: DateTime.now(),
          emiAmount: 100,
          firstEmiDate: DateTime.now())
    ]);

    // Profile 2
    final loan2 = Loan(
        id: 'l2',
        name: 'Loan 2',
        totalPrincipal: 2000,
        remainingPrincipal: 2000,
        interestRate: 12,
        tenureMonths: 24,
        startDate: DateTime.now(),
        emiAmount: 200,
        firstEmiDate: DateTime.now());

    // Listen to loansProvider
    final listener = container.listen(loansProvider, (previous, next) {},
        fireImmediately: true);

    // Wait for first emission
    await Future.delayed(Duration.zero);
    expect(container.read(loansProvider).value?.first.id, 'l1');

    // Change profile
    when(() => mockStorage.getLoans()).thenReturn([loan2]);
    (container.read(activeProfileIdProvider.notifier) as MockProfileNotifier)
        .stateValue = 'p2';

    // Wait for rebuild
    await Future.delayed(Duration.zero);
    expect(container.read(loansProvider).value?.first.id, 'l2');

    listener.close();
  });
}
