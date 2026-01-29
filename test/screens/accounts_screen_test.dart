import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/models/account.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/screens/accounts_screen.dart';
import 'package:samriddhi_flow/services/storage_service.dart';
import 'package:samriddhi_flow/models/transaction.dart';
import 'package:samriddhi_flow/screens/transactions_screen.dart';

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

    when(() => mockStorageService.checkCreditCardRollovers())
        .thenAnswer((_) async {});
    when(() => mockStorageService.saveAccount(any())).thenAnswer((_) async {});
    when(() => mockStorageService.getCategories()).thenReturn([]);
    when(() => mockStorageService.getActiveProfileId()).thenReturn('default');
    when(() => mockStorageService.getCurrencyLocale()).thenReturn('en_IN');
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

  testWidgets('AccountsScreen renders account list', (tester) async {
    await tester.pumpWidget(createTestWidget(tester));
    await tester.pumpAndSettle();

    expect(find.text('Savings'), findsOneWidget);
    expect(find.text('Credit Card'), findsOneWidget);
    expect(find.text('Add New'), findsOneWidget);
  });

  testWidgets('Credit usage toggle works', (tester) async {
    await tester.pumpWidget(createTestWidget(tester));
    await tester.pumpAndSettle();

    // Initially usage summary should NOT be visible (CreditUsageVisibilityNotifier defaults to false)
    expect(find.text('Total Credit Usage'), findsNothing);

    // Toggle on (find by icon and tooltip)
    await tester.tap(find.byIcon(Icons.visibility_off));
    await tester.pumpAndSettle();

    expect(find.text('Total Credit Usage'), findsOneWidget);
    expect(find.textContaining('Limit'), findsWidgets);

    // Toggle off
    await tester.tap(find.byIcon(Icons.visibility));
    await tester.pumpAndSettle();

    expect(find.text('Total Credit Usage'), findsNothing);
  });

  testWidgets('Opening and closing Add Account sheet', (tester) async {
    await tester.pumpWidget(createTestWidget(tester));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add New'));
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

    await tester.tap(find.text('Add New'));
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

  testWidgets('AccountsScreen shows credit card usage summary', (tester) async {
    final creditCard = Account(
        id: 'acc2',
        name: 'My Card',
        type: AccountType.creditCard,
        balance: 1000,
        creditLimit: 5000,
        billingCycleDay: 1,
        profileId: 'p1');

    await tester.pumpWidget(createTestWidget(tester, accounts: [creditCard]));
    await tester.pumpAndSettle();

    // Summary is hidden by default
    expect(find.text('Total Credit Usage'), findsNothing);

    // Toggle visibility
    await tester.tap(find.byIcon(Icons.visibility_off));
    await tester.pumpAndSettle();

    expect(find.text('Total Credit Usage'), findsOneWidget);
    expect(find.text('20.0% Used'), findsOneWidget);
    expect(find.text('Available: ₹4,000.00'), findsOneWidget);
  });

  testWidgets('AccountsScreen can navigate to transactions', (tester) async {
    final account = Account(
        id: 'acc1',
        name: 'Savings',
        profileId: 'p1',
        type: AccountType.savings);
    await tester.pumpWidget(createTestWidget(tester, accounts: [account]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Savings'));
    await tester.pumpAndSettle();

    expect(find.text('View Transactions'), findsOneWidget);
    await tester.tap(find.text('View Transactions'));
    await tester.pumpAndSettle();

    // Should navigate to TransactionsScreen
    expect(find.byType(TransactionsScreen), findsOneWidget);
  });

  testWidgets('AccountsScreen handles credit card unbilled calculation',
      (tester) async {
    final now = DateTime.now();
    final card = Account(
        id: 'cc1',
        name: 'ICICI Credit',
        type: AccountType.creditCard,
        balance: 5000,
        creditLimit: 100000,
        billingCycleDay: 15,
        paymentDueDateDay: 20,
        profileId: 'default',
        currency: 'en_IN');

    final txn = Transaction(
      id: 't1',
      title: 'Amazon',
      amount: 2000,
      date: DateTime(now.year, now.month, now.day),
      type: TransactionType.expense,
      category: 'Shopping',
      accountId: card.id,
      profileId: 'default',
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(mockStorageService),
        storageInitializerProvider.overrideWith((ref) => Future.value()),
        accountsProvider.overrideWith((ref) => Stream.value([card])),
        transactionsProvider.overrideWith((ref) => Stream.value([txn])),
        currencyProvider.overrideWith(() => FakeCurrencyNotifier()),
        activeProfileIdProvider.overrideWith(() => FakeProfileNotifier()),
      ],
      child: const MaterialApp(home: AccountsScreen()),
    ));

    await tester.pumpAndSettle();

    // Toggle on
    await tester.tap(find.byIcon(Icons.visibility_off));
    await tester.pumpAndSettle();

    expect(find.text('Total Credit Usage'), findsOneWidget);
    // 5000 (billed) + 2000 (unbilled) = 7000
    expect(find.textContaining('7,000'), findsAny);
  });
}
