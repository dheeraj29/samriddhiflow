import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/feature_providers.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/models/account.dart';
import 'package:samriddhi_flow/services/storage_service.dart';

import 'package:samriddhi_flow/services/taxes/tax_config_service.dart';

class MockStorageService extends Mock implements StorageService {}

class MockTaxConfigService extends Mock implements TaxConfigService {}

void main() {
  late MockStorageService mockStorage;
  late MockTaxConfigService mockTaxConfig;
  late ProviderContainer container;

  ProviderContainer createContainer({List<Account>? accounts}) {
    return ProviderContainer(
      overrides: [
        storageServiceProvider.overrideWithValue(mockStorage),
        taxConfigServiceProvider.overrideWithValue(mockTaxConfig),
        taxYearDataProvider.overrideWith((ref, year) => Stream.value(null)),
        accountsProvider.overrideWithValue(AsyncData(accounts ??
            [
              Account(
                id: 'cc1',
                name: 'Test CC',
                type: AccountType.creditCard,
                balance: 5000,
                billingCycleDay: 15,
              ),
            ])),
        transactionsProvider.overrideWithValue(const AsyncData([])),
        loansProvider.overrideWithValue(const AsyncData([])),
        recurringTransactionsProvider.overrideWithValue(const AsyncData([])),
      ],
    );
  }

  setUp(() {
    mockStorage = MockStorageService();
    mockTaxConfig = MockTaxConfigService();

    when(() => mockTaxConfig.getCurrentFinancialYear()).thenReturn(2025);
    when(() => mockStorage.getTaxYearData(any())).thenReturn(null);
    when(() => mockStorage.getLastRollover(any())).thenReturn(null);

    container = createContainer();
  });

  group('pendingRemindersProvider - Credit Card', () {
    test('Shows reminder when bill is unpaid', () {
      final count = container.read(pendingRemindersProvider);
      expect(count, 1);
    });

    test('Still shows reminder when bill is partially paid', () {
      container = createContainer(
        accounts: [
          Account(
            id: 'cc1',
            name: 'Test CC',
            type: AccountType.creditCard,
            balance: 3000,
            billingCycleDay: 15,
          ),
        ],
      );

      final count = container.read(pendingRemindersProvider);
      expect(count, 1);
    });

    test('Clears reminder when bill is fully paid (balance <= 0.01)', () {
      container = createContainer(
        accounts: [
          Account(
            id: 'cc1',
            name: 'Test CC',
            type: AccountType.creditCard,
            balance: 0,
            billingCycleDay: 15,
          ),
        ],
      );

      final count = container.read(pendingRemindersProvider);
      expect(count, 0);
    });
  });
}
