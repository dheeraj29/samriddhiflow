import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/models/account.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/screens/accounts_screen.dart';
import 'package:samriddhi_flow/services/storage_service.dart';
import 'package:samriddhi_flow/models/transaction.dart';

class MockStorageService extends Mock implements StorageService {}

class FakeCurrencyNotifier extends CurrencyNotifier {
  @override
  String build() => 'en_IN';
}

class FakeProfileNotifier extends ProfileNotifier {
  @override
  String build() => 'default';
}

void main() {
  late MockStorageService mockStorageService;
  late List<Account> testAccounts;

  setUpAll(() {
    registerFallbackValue(Account.create(
      name: 'Fallback',
      type: AccountType.savings,
      initialBalance: 0,
    ));
    registerFallbackValue(Transaction.create(
      title: 'Fallback',
      amount: 0,
      type: TransactionType.expense,
      category: 'Food',
      accountId: 'acc1',
      date: DateTime.now(),
    ));
  });

  setUp(() {
    mockStorageService = MockStorageService();
    testAccounts = [
      Account(
        id: 'acc1',
        name: 'Savings',
        type: AccountType.savings,
        balance: 1000,
        currency: 'en_IN',
        profileId: 'default',
      ),
      Account(
        id: 'acc2',
        name: 'Credit Card',
        type: AccountType.creditCard,
        balance: 500,
        currency: 'en_IN',
        creditLimit: 2000,
        billingCycleDay: 15,
        paymentDueDateDay: 20,
        profileId: 'default',
      ),
    ];

    when(() => mockStorageService.toggleAccountPin(any()))
        .thenAnswer((_) async {});
    when(() => mockStorageService.checkCreditCardRollovers())
        .thenAnswer((_) async {});
    when(() => mockStorageService.saveAccount(any())).thenAnswer((_) async {});
    when(() => mockStorageService.getCategories()).thenReturn([]);
    when(() => mockStorageService.getActiveProfileId()).thenReturn('default');
    when(() => mockStorageService.getCurrencyLocale()).thenReturn('en_IN');
    when(() => mockStorageService.isBilledAmountPaid(any())).thenReturn(false);
    when(() => mockStorageService.getLastRollover(any())).thenReturn(null);
  });

  Widget createTestWidget(WidgetTester tester, {List<Account>? accounts}) {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    return ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(mockStorageService),
        storageInitializerProvider.overrideWith((ref) => Future.value()),
        accountsProvider
            .overrideWith((ref) => Stream.value(accounts ?? testAccounts)),
        transactionsProvider.overrideWith((ref) => Stream.value([])),
        currencyProvider.overrideWith(() => FakeCurrencyNotifier()),
        activeProfileIdProvider.overrideWith(() => FakeProfileNotifier()),
      ],
      child: const MaterialApp(
        home: AccountsScreen(),
      ),
    );
  }

  testWidgets('AccountsScreen shows empty state', (tester) async {
    await tester.pumpWidget(createTestWidget(tester, accounts: []));
    await tester.pumpAndSettle();

    expect(find.text('No accounts found.'), findsOneWidget);
    expect(find.text('Add Account'), findsOneWidget);
  });

  testWidgets('AccountsScreen renders account sections', (tester) async {
    await tester.pumpWidget(createTestWidget(tester));
    await tester.pumpAndSettle();

    expect(find.text('Pinned Accounts'), findsOneWidget);
    expect(find.text('Savings Accounts'), findsOneWidget);
    expect(find.text('Credit Cards'), findsOneWidget);
    expect(find.text('Wallets'), findsOneWidget);
    expect(find.text('Add New Account'), findsOneWidget);
  });

  testWidgets('Expandable sections show items when expanded', (tester) async {
    await tester.pumpWidget(createTestWidget(tester));
    await tester.pumpAndSettle();

    // Items are hidden by default
    expect(find.text('Savings'), findsNothing);
    expect(find.text('Credit Card'), findsNothing);

    // Expand Savings section
    await tester.tap(find.text('Savings Accounts'));
    await tester.pumpAndSettle();
    expect(find.text('Savings'), findsOneWidget);

    // Expand Credit Cards section
    await tester.tap(find.text('Credit Cards'));
    await tester.pumpAndSettle();
    expect(find.text('Credit Card'), findsOneWidget);
  });

  testWidgets('Account pinning works', (tester) async {
    await tester.pumpWidget(createTestWidget(tester));
    await tester.pumpAndSettle();

    // Expand Savings
    await tester.tap(find.text('Savings Accounts'));
    await tester.pumpAndSettle();

    // Tap on Savings to open options
    await tester.tap(find.text('Savings'));
    await tester.pumpAndSettle();

    expect(find.text('Pin Account'), findsOneWidget);
    await tester.tap(find.text('Pin Account'));
    await tester.pumpAndSettle();

    verify(() => mockStorageService.toggleAccountPin('acc1')).called(1);
  });

  testWidgets('Opening and closing Add Account sheet', (tester) async {
    await tester.pumpWidget(createTestWidget(tester));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add New Account'));
    await tester.pumpAndSettle();

    expect(find.text('New Account'), findsOneWidget);
    expect(find.text('Create Account'), findsOneWidget);

    // Tap outside or close
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Account Name'), 'New Bank');
    await tester.pumpAndSettle();
  });

  testWidgets('Creating a new account works', (tester) async {
    await tester.pumpWidget(createTestWidget(tester));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add New Account'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Account Name'), 'New Savings');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Current Balance'), '500');

    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();

    verify(() => mockStorageService.saveAccount(any())).called(1);
    expect(find.text('New Account'), findsNothing); // Sheet closed
  });

  testWidgets('Edit account options show up', (tester) async {
    await tester.pumpWidget(createTestWidget(tester));
    await tester.pumpAndSettle();

    // Expand Savings
    await tester.tap(find.text('Savings Accounts'));
    await tester.pumpAndSettle();

    // Tap on Savings card
    await tester.tap(find.text('Savings'));
    await tester.pumpAndSettle();

    expect(find.text('View Transactions'), findsOneWidget);
    expect(find.text('Edit Account'), findsOneWidget);

    // Open edit sheet
    await tester.tap(find.text('Edit Account'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Account'), findsOneWidget);
    expect(find.text('Update Account'), findsOneWidget);
  });

  testWidgets('AccountsScreen account deletion flow', (tester) async {
    final account = Account(
        id: 'del1',
        name: 'DeleteMe',
        type: AccountType.savings,
        profileId: 'default');
    when(() => mockStorageService.deleteAccount(any()))
        .thenAnswer((_) async {});

    await tester.pumpWidget(createTestWidget(tester, accounts: [account]));
    await tester.pumpAndSettle();

    // Expand Savings
    await tester.tap(find.text('Savings Accounts'));
    await tester.pumpAndSettle();

    // Open options
    await tester.tap(find.text('DeleteMe'));
    await tester.pumpAndSettle();

    final deleteOption = find.text('Delete Account');
    expect(deleteOption, findsOneWidget);
    await tester.tap(deleteOption);
    await tester.pumpAndSettle();

    // Confirm dialog
    expect(find.text('Delete Account?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    verify(() => mockStorageService.deleteAccount('del1')).called(1);
  });

  testWidgets('AccountsScreen credit card payment dialog flow', (tester) async {
    final card = Account(
        id: 'cc_pay',
        name: 'Chase Card',
        type: AccountType.creditCard,
        balance: 1000,
        billingCycleDay: 15,
        profileId: 'default');

    when(() => mockStorageService.getLastRollover(any())).thenReturn(null);

    await tester.pumpWidget(createTestWidget(tester, accounts: [card]));
    await tester.pumpAndSettle();

    // Expand CC
    await tester.tap(find.text('Credit Cards'));
    await tester.pumpAndSettle();

    // Open options
    await tester.tap(find.text('Chase Card'));
    await tester.pumpAndSettle();

    final payOption = find.text('Pay Bill');
    expect(payOption, findsOneWidget);
    await tester.tap(payOption);
    await tester.pumpAndSettle();

    // Check if RecordCCPaymentDialog appeared
    expect(find.text('Pay Chase Card Bill'), findsOneWidget);
  });

  testWidgets('AccountsScreen clear billed amount flow', (tester) async {
    final card = Account(
        id: 'cc_clear',
        name: 'Amex',
        type: AccountType.creditCard,
        balance: 1000,
        profileId: 'default');

    when(() => mockStorageService.clearBilledAmount(any()))
        .thenAnswer((_) async {});

    await tester.pumpWidget(createTestWidget(tester, accounts: [card]));
    await tester.pumpAndSettle();

    // Expand CC
    await tester.tap(find.text('Credit Cards'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Amex'));
    await tester.pumpAndSettle();

    final clearOption = find.text('Clear Billed Amount');
    await tester.tap(clearOption);
    await tester.pumpAndSettle();

    // Confirm dialog
    expect(find.text('Clear Billed Amount?'), findsOneWidget);
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    verify(() => mockStorageService.clearBilledAmount('cc_clear')).called(1);
  });
}
