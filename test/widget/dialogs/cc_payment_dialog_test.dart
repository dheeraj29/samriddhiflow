import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/models/account.dart';
import 'package:samriddhi_flow/models/transaction.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/screens/cc_payment_dialog.dart';
import 'package:samriddhi_flow/services/storage_service.dart';

// local mock
class LocalMockStorageService extends Mock implements StorageService {}

class MockCurrencyNotifier extends CurrencyNotifier {
  @override
  String build() => 'en_US';
}

void main() {
  late LocalMockStorageService mockStorage;

  setUpAll(() {
    registerFallbackValue(Transaction(
      id: 'fallback',
      title: 'fallback',
      amount: 0,
      date: DateTime.now(),
      type: TransactionType.expense,
      category: 'fallback',
    ));
    registerFallbackValue(Account(
      id: 'fallback',
      name: 'fallback',
      type: AccountType.wallet,
      balance: 0,
      profileId: 'fallback',
    ));
  });

  setUp(() {
    mockStorage = LocalMockStorageService();
    when(() => mockStorage.saveTransaction(any())).thenAnswer((_) async {});
    when(() => mockStorage.getLastRollover(any())).thenReturn(null);
    when(() =>
            mockStorage.resetCreditCardRollover(any(), keepBilledStatus: true))
        .thenAnswer((_) async {});
  });

  testWidgets('RecordCCPaymentDialog renders and submits payment',
      (tester) async {
    final ccAccount = Account(
      id: 'cc_1',
      name: 'Test CC',
      type: AccountType.creditCard,
      balance: 1000,
      profileId: 'p1',
      billingCycleDay: 1,
      paymentDueDateDay: 20,
    );

    final savingsAccount = Account(
      id: 'sav_1',
      name: 'Savings',
      type: AccountType.savings,
      balance: 5000,
      profileId: 'p1',
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(mockStorage),
        storageInitializerProvider.overrideWith((ref) => Future.value()),
        accountsProvider
            .overrideWith((ref) => Stream.value([ccAccount, savingsAccount])),
        transactionsProvider.overrideWith((ref) => Stream.value([])),
        currencyProvider.overrideWith(MockCurrencyNotifier.new),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(builder: (context) {
            return ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => RecordCCPaymentDialog(
                    creditCardAccount: ccAccount,
                    isFullyPaid: false,
                  ),
                );
              },
              child: const Text('Open Dialog'),
            );
          }),
        ),
      ),
    ));

    await tester.pumpAndSettle();

    // Open Dialog
    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    // Verify Title
    expect(find.text('Pay Test CC Bill'), findsOneWidget);

    // Enter Amount
    await tester.enterText(find.byType(TextField), '500.00');

    // Select Source Account
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Savings').last);
    await tester.pumpAndSettle();

    // Tap Confirm
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    // Verify Storage Call
    verify(() => mockStorage.saveTransaction(any(
            that: isA<Transaction>().having((t) => t.amount, 'amount', 500.0))))
        .called(1);

    // Verify SnackBar
    expect(find.text('Payment Recorded'), findsOneWidget);

    // Verify Dialog Closed (Title not found)
    expect(find.text('Pay Test CC Bill'), findsNothing);
  });

  testWidgets('RecordCCPaymentDialog auto-advances cycle on full payment',
      (tester) async {
    final ccAccount = Account(
      id: 'cc_2',
      name: 'Test CC 2',
      type: AccountType.creditCard,
      balance: 100.20, // Balance
      profileId: 'p1',
      billingCycleDay: 1,
      paymentDueDateDay: 20,
    );

    // Mock storage to return last rollover
    when(() => mockStorage.getLastRollover('cc_2')).thenReturn(DateTime.now()
        .subtract(const Duration(days: 40))
        .millisecondsSinceEpoch);

    // Mock reset call
    when(() =>
            mockStorage.resetCreditCardRollover(any(), keepBilledStatus: true))
        .thenAnswer((_) async {});

    // Mock transactions to return some billable txns
    final txn = Transaction(
        id: 't1',
        title: 'Expense',
        amount: 50.0,
        date: DateTime.now().subtract(const Duration(days: 15)),
        type: TransactionType.expense,
        category: 'Food',
        accountId: 'cc_2');

    await tester.pumpWidget(ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(mockStorage),
        storageInitializerProvider.overrideWith((ref) => Future.value()),
        accountsProvider.overrideWith((ref) => Stream.value([ccAccount])),
        transactionsProvider.overrideWith((ref) => Stream.value([txn])),
        currencyProvider.overrideWith(MockCurrencyNotifier.new),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(builder: (context) {
            return ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => RecordCCPaymentDialog(
                    creditCardAccount: ccAccount,
                    isFullyPaid: false,
                  ),
                );
              },
              child: const Text('Open Dialog'),
            );
          }),
        ),
      ),
    ));

    await tester.pumpAndSettle();
    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    // Dialog should auto-calculate due amount.
    // Bill = 50. Balance = 100.20. Total Due = 150.20.
    // We pay full amount.
    await tester.enterText(find.byType(TextField), '150.20');
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    // Verify transaction saved
    verify(() => mockStorage.saveTransaction(any())).called(1);

    // Verify auto-advance cycle (reset Rollover) called!
    verify(() =>
            mockStorage.resetCreditCardRollover(any(), keepBilledStatus: true))
        .called(1);
  });

  testWidgets('RecordCCPaymentDialog does NOT advance cycle on partial payment',
      (tester) async {
    final ccAccount = Account(
      id: 'cc_3',
      name: 'Test CC 3',
      type: AccountType.creditCard,
      balance: 1000.00,
      profileId: 'p1',
      billingCycleDay: 1,
      paymentDueDateDay: 20,
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(mockStorage),
        storageInitializerProvider.overrideWith((ref) => Future.value()),
        accountsProvider.overrideWith((ref) => Stream.value([ccAccount])),
        transactionsProvider.overrideWith((ref) => Stream.value([])),
        currencyProvider.overrideWith(MockCurrencyNotifier.new),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(builder: (context) {
            return ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => RecordCCPaymentDialog(
                    creditCardAccount: ccAccount,
                    isFullyPaid: false,
                  ),
                );
              },
              child: const Text('Open Dialog'),
            );
          }),
        ),
      ),
    ));

    await tester.pumpAndSettle();
    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    // Pay 500 (Partial)
    await tester.enterText(find.byType(TextField), '500.00');
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    // Verify transaction saved
    verify(() => mockStorage.saveTransaction(any())).called(1);

    // Verify reset Rollover NOT called
    verifyNever(() =>
        mockStorage.resetCreditCardRollover(any(), keepBilledStatus: true));
  });

  testWidgets('RecordCCPaymentDialog advances cycle within 0.01 threshold',
      (tester) async {
    final ccAccount = Account(
      id: 'cc_4',
      name: 'Test CC 4',
      type: AccountType.creditCard,
      balance: 1000.00,
      profileId: 'p1',
      billingCycleDay: 1,
      paymentDueDateDay: 20,
    );

    when(() =>
            mockStorage.resetCreditCardRollover(any(), keepBilledStatus: true))
        .thenAnswer((_) async {});

    await tester.pumpWidget(ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(mockStorage),
        storageInitializerProvider.overrideWith((ref) => Future.value()),
        accountsProvider.overrideWith((ref) => Stream.value([ccAccount])),
        transactionsProvider.overrideWith((ref) => Stream.value([])),
        currencyProvider.overrideWith(MockCurrencyNotifier.new),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(builder: (context) {
            return ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => RecordCCPaymentDialog(
                      creditCardAccount: ccAccount,
                      isFullyPaid: false,
                    ),
                  );
                },
                child: const Text('Open Dialog'));
          }),
        ),
      ),
    ));

    await tester.pumpAndSettle();
    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    // Pay 999.99 (matches 1000.0 - 0.01 threshold exactly)
    await tester.enterText(find.byType(TextField), '999.99');
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    // Verify main transaction was saved
    verify(() => mockStorage.saveTransaction(any())).called(1);

    verify(() =>
            mockStorage.resetCreditCardRollover(any(), keepBilledStatus: true))
        .called(1);
  });

  testWidgets('RecordCCPaymentDialog creates adjustment when Round Off is used',
      (tester) async {
    final ccAccount = Account(
      id: 'cc_5',
      name: 'Test CC 5',
      type: AccountType.creditCard,
      balance: 1000.56,
      profileId: 'p1',
      billingCycleDay: 1,
      paymentDueDateDay: 20,
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(mockStorage),
        storageInitializerProvider.overrideWith((ref) => Future.value()),
        accountsProvider.overrideWith((ref) => Stream.value([ccAccount])),
        transactionsProvider.overrideWith((ref) => Stream.value([])),
        currencyProvider.overrideWith(MockCurrencyNotifier.new),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(builder: (context) {
            return ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => RecordCCPaymentDialog(
                      creditCardAccount: ccAccount,
                      isFullyPaid: false,
                    ),
                  );
                },
                child: const Text('Open Dialog'));
          }),
        ),
      ),
    ));

    when(() =>
            mockStorage.resetCreditCardRollover(any(), keepBilledStatus: true))
        .thenAnswer((_) async {});

    await tester.pumpAndSettle();
    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    // Verify initial value is 1000.56
    expect(find.text('1000.56'), findsOneWidget);

    // Toggle Round Off
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();

    // Value should become 1001.00
    expect(find.text('1001.00'), findsOneWidget);

    // Tap Confirm
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    // Verify TWO transactions saved: 1001.00 transfer and 0.44 adjustment
    // 1000.56 -> 1001.00 is a diff of 0.44.
    // Amount increased, so it's a "gain" adjustment to the credit card (it covers more balance).
    // Or rather, in `_createRoundingAdjustment`: diff = 1000.56 - 1001.00 = -0.44.
    // adjustmentType = expense (since diff < 0). Wait, let's check code logic.
    // diffRow = _originalAmount! - amount; (1000.56 - 1001.00 = -0.44)
    // if diff > 0 -> income, else expense.
    // So expense of 0.44 to CC account.
    verify(() => mockStorage.saveTransaction(any(
        that: isA<Transaction>()
            .having((t) => t.type, 'type', TransactionType.transfer)
            .having((t) => t.amount, 'amount', 1001.0)))).called(1);

    verify(() => mockStorage.saveTransaction(any(
        that: isA<Transaction>()
            .having((t) => t.type, 'type', TransactionType.expense)
            .having((t) => t.amount, 'amount', 0.44)))).called(1);
  });
}
