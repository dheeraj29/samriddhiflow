import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/feature_providers.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/models/account.dart';
import 'package:samriddhi_flow/services/storage_service.dart';

class MockStorageService extends Mock implements StorageService {}

void main() {
  late MockStorageService mockStorage;
  late ProviderContainer container;

  setUp(() {
    mockStorage = MockStorageService();
    container = ProviderContainer(
      overrides: [
        storageServiceProvider.overrideWithValue(mockStorage),
        accountsProvider.overrideWithValue(AsyncData([
          Account(
            id: 'cc1',
            name: 'Test CC',
            type: AccountType.creditCard,
            balance: 5000, // Billed balance
            billingCycleDay: 15,
          ),
        ])),
        transactionsProvider.overrideWithValue(const AsyncData([])),
        loansProvider.overrideWithValue(const AsyncData([])),
        recurringTransactionsProvider.overrideWithValue(const AsyncData([])),
      ],
    );

    when(() => mockStorage.getLastRollover(any())).thenReturn(null);
  });

  group('pendingRemindersProvider - Credit Card', () {
    test('Shows reminder when bill is unpaid', () {
      // Need to wait for the stream to emit
      final count = container.read(pendingRemindersProvider);
      expect(count, 1);
    });

    test('Still shows reminder when bill is partially paid', () {
      // With the fix, totalDue is what matters.
      // If balance is 5000 and we have 0 billed, totalDue is 5000.
      // If we pay 2000, technically in this app's architecture,
      // the payment doesn't reduce 'balance' immediately if it's in an open cycle,
      // OR if it does, it's reflected in totalDue.

      // Let's emulate a partial payment.
      // In feature_providers.dart, it calculates:
      // totalDue = acc.balance + billed
      // And we fixed it to: isFullyPaid = totalDue <= 0.01

      container = ProviderContainer(
        overrides: [
          storageServiceProvider.overrideWithValue(mockStorage),
          accountsProvider.overrideWithValue(AsyncData([
            Account(
              id: 'cc1',
              name: 'Test CC',
              type: AccountType.creditCard,
              balance: 3000, // Reduced from 5000 after 2000 payment
              billingCycleDay: 15,
            ),
          ])),
          transactionsProvider.overrideWithValue(const AsyncData([])),
          loansProvider.overrideWithValue(const AsyncData([])),
          recurringTransactionsProvider.overrideWithValue(const AsyncData([])),
        ],
      );

      final count = container.read(pendingRemindersProvider);
      expect(count, 1); // Still 1 because 3000 > 0.01
    });

    test('Clears reminder when bill is fully paid (balance <= 0.01)', () {
      container = ProviderContainer(
        overrides: [
          storageServiceProvider.overrideWithValue(mockStorage),
          accountsProvider.overrideWithValue(AsyncData([
            Account(
              id: 'cc1',
              name: 'Test CC',
              type: AccountType.creditCard,
              balance: 0,
              billingCycleDay: 15,
            ),
          ])),
          transactionsProvider.overrideWithValue(const AsyncData([])),
          loansProvider.overrideWithValue(const AsyncData([])),
          recurringTransactionsProvider.overrideWithValue(const AsyncData([])),
        ],
      );

      final count = container.read(pendingRemindersProvider);
      expect(count, 0);
    });
  });
}
