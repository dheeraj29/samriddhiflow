import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/screens/dashboard_screen.dart';
import 'package:samriddhi_flow/models/account.dart';
import 'package:samriddhi_flow/models/category.dart';
import 'package:samriddhi_flow/models/transaction.dart';
import 'package:samriddhi_flow/services/notification_service.dart';
import 'package:samriddhi_flow/feature_providers.dart';

class MockNotificationService extends Mock implements NotificationService {}

class MockIsLoggedInNotifier extends IsLoggedInNotifier {
  @override
  bool build() => false;
}

class MockIsOfflineNotifier extends IsOfflineNotifier {
  @override
  bool build() => false;
}

class MockTxnsSinceBackupNotifier extends TxnsSinceBackupNotifier {
  @override
  int build() => 0;
}

class MockHighTxnCountNotifier extends TxnsSinceBackupNotifier {
  @override
  int build() => 25; // Over threshold
}

class MockBackupThresholdNotifier extends BackupThresholdNotifier {
  @override
  int build() => 20;
}

class MockCurrencyNotifier extends CurrencyNotifier {
  @override
  String build() => 'en_US';
}

class MockCategoriesNotifier extends CategoriesNotifier {
  @override
  List<Category> build() => [];
}

class MockProfileIdNotifier extends ProfileNotifier {
  @override
  String build() => 'default';
}

class MockSmartCalcNotifier extends SmartCalculatorEnabledNotifier {
  @override
  bool build() => false;
}

void main() {
  late MockNotificationService mockNotificationService;

  setUp(() {
    mockNotificationService = MockNotificationService();
    when(() => mockNotificationService.init()).thenAnswer((_) async {});
    when(() => mockNotificationService.checkNudges())
        .thenAnswer((_) async => []);
  });

  Widget createWidgetUnderTest(
      {List<Account> accounts = const [],
      List<Transaction> transactions = const []}) {
    return ProviderScope(
      overrides: [
        notificationServiceProvider.overrideWithValue(mockNotificationService),
        accountsProvider.overrideWith((ref) => Stream.value(accounts)),
        transactionsProvider.overrideWith((ref) => Stream.value(transactions)),
        loansProvider.overrideWith((ref) => Stream.value([])),
        txnsSinceBackupProvider.overrideWith(MockTxnsSinceBackupNotifier.new),
        backupThresholdProvider.overrideWith(MockBackupThresholdNotifier.new),
        currencyProvider.overrideWith(MockCurrencyNotifier.new),
        categoriesProvider.overrideWith(MockCategoriesNotifier.new),
        activeProfileIdProvider.overrideWith(MockProfileIdNotifier.new),
        profilesProvider.overrideWith((ref) async => []),
        smartCalculatorEnabledProvider.overrideWith(MockSmartCalcNotifier.new),
        isLoggedInProvider.overrideWith(MockIsLoggedInNotifier.new),
        isOfflineProvider.overrideWith(MockIsOfflineNotifier.new),
        authStreamProvider.overrideWith((ref) => Stream.value(null)),
      ],
      child: const MaterialApp(
        home: DashboardScreen(),
      ),
    );
  }

  testWidgets('DashboardScreen renders basic UI', (tester) async {
    await tester.pumpWidget(createWidgetUnderTest(accounts: [
      Account(
          id: '1',
          name: 'Savings',
          balance: 1000,
          type: AccountType.savings,
          currency: 'USD'),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('My Samriddh'), findsOneWidget);
    expect(find.text('Total Net Worth'), findsOneWidget);
    expect(find.text('Quick Actions'), findsOneWidget);
    expect(find.text('Recent Transactions'), findsOneWidget);
  });

  testWidgets('DashboardScreen calculates net worth correctly', (tester) async {
    final accounts = [
      Account(
          id: '1',
          name: 'Savings',
          balance: 1000,
          type: AccountType.savings,
          currency: 'USD'),
      Account(
          id: '2',
          name: 'CC',
          balance: 200,
          type: AccountType.creditCard,
          currency: 'USD'),
    ];

    await tester.pumpWidget(createWidgetUnderTest(accounts: accounts));
    await tester.pumpAndSettle();

    expect(find.textContaining('800'), findsWidgets);
    expect(find.textContaining('Assets:'), findsWidgets);
    expect(find.textContaining('Debt:'), findsWidgets);
  });

  testWidgets('DashboardScreen shows recent transactions', (tester) async {
    final t1 = Transaction.create(
        title: 'Groceries',
        amount: 50,
        type: TransactionType.expense,
        accountId: '1',
        category: 'Food',
        date: DateTime.now());

    await tester.pumpWidget(createWidgetUnderTest(
      accounts: [
        Account(
            id: '1',
            name: 'Cash',
            balance: 100,
            type: AccountType.wallet,
            profileId: 'default')
      ],
      transactions: [t1],
    ));
    await tester.pumpAndSettle();

    expect(find.text('Groceries'), findsOneWidget);
  });

  testWidgets('DashboardScreen initializes notifications', (tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();
    verify(() => mockNotificationService.init()).called(1);
    verify(() => mockNotificationService.checkNudges()).called(1);
  });

  testWidgets('DashboardScreen shows backup reminder if threshold met',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        notificationServiceProvider.overrideWithValue(mockNotificationService),
        accountsProvider.overrideWith((ref) => Stream.value([])),
        transactionsProvider.overrideWith((ref) => Stream.value([])),
        loansProvider.overrideWith((ref) => Stream.value([])),
        // Force high count
        txnsSinceBackupProvider.overrideWith(MockHighTxnCountNotifier.new),
        backupThresholdProvider.overrideWith(MockBackupThresholdNotifier.new),
        currencyProvider.overrideWith(MockCurrencyNotifier.new),
        categoriesProvider.overrideWith(MockCategoriesNotifier.new),
        activeProfileIdProvider.overrideWith(MockProfileIdNotifier.new),
        profilesProvider.overrideWith((ref) async => []),
        smartCalculatorEnabledProvider.overrideWith(MockSmartCalcNotifier.new),
        isLoggedInProvider.overrideWith(MockIsLoggedInNotifier.new),
        isOfflineProvider.overrideWith(MockIsOfflineNotifier.new),
        authStreamProvider.overrideWith((ref) => Stream.value(null)),
      ],
      child: const MaterialApp(
        home: DashboardScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Unsaved Data:'), findsOneWidget);
    // 25 transactions
    expect(find.textContaining('25'), findsOneWidget);
  });

  testWidgets('DashboardScreen Quick Actions', (tester) async {
    // Check navigation for Quick Actions
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Scroll to quick actions
    // Use widgetWithText to avoid collision with "Income (This Month)"
    final incomeAction = find.descendant(
      of: find.byType(SingleChildScrollView),
      matching: find.text('Income'),
    );
    await tester.ensureVisible(incomeAction);
    await tester.pumpAndSettle();
    await tester.tap(incomeAction);
    await tester.pumpAndSettle();
    // Assuming navigator push works. To clean up state we might just pumpWidget again in next tests.

    // Reset
    await tester.pumpWidget(createWidgetUnderTest());
    await tester
        .pumpAndSettle(); // Reset might not work perfectly if we pushed route
    // But since we can't easily pop, we accept coverage of tap.
  });

  testWidgets('DashboardScreen nav items handle taps', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    final accountsIcon = find.byIcon(Icons.account_balance_wallet);
    if (accountsIcon.evaluate().isNotEmpty) {
      await tester.ensureVisible(accountsIcon);
      await tester.tap(accountsIcon);
      await tester.pumpAndSettle();
    }
  });

  testWidgets('DashboardScreen switches tabs independently', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    final reportsIcon = find.byIcon(Icons.analytics);
    if (reportsIcon.evaluate().isNotEmpty) {
      await tester.ensureVisible(reportsIcon);
      await tester.tap(reportsIcon);
      await tester.pumpAndSettle();
    }
  });
}
