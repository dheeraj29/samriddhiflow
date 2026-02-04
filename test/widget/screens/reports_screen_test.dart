import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/screens/reports_screen.dart';
import 'package:samriddhi_flow/screens/transactions_screen.dart';
import 'package:samriddhi_flow/models/transaction.dart';
import 'package:samriddhi_flow/models/category.dart';
import 'package:samriddhi_flow/models/loan.dart';
import 'package:samriddhi_flow/models/account.dart';
import '../test_mocks.dart';

void main() {
  late MockStorageService mockStorage;

  setUp(() {
    mockStorage = MockStorageService();
    setupStorageDefaults(mockStorage);
  });

  Widget createWidgetUnderTest({
    List<Transaction>? txns,
    List<Category>? cats,
    List<Loan>? loans,
    List<Account>? accounts,
  }) {
    // ReportsScreen returns early "No data available" if transactions list is empty.
    // We must provide at least one transaction to reach the report UI.
    final effectiveTxns = txns ??
        [
          Transaction.create(
            title: 'Initial',
            amount: 1,
            date: DateTime.now(),
            type: TransactionType.expense,
            category: 'Other',
          )
        ];

    return ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(mockStorage),
        accountsProvider.overrideWith((ref) => Stream.value(accounts ?? [])),
        loansProvider.overrideWith((ref) => Stream.value(loans ?? [])),
        transactionsProvider.overrideWith((ref) => Stream.value(effectiveTxns)),
        categoriesProvider
            .overrideWith(() => MockCategoriesNotifier(cats ?? [])),
        currencyProvider.overrideWith(() => MockCurrencyNotifier('en_IN')),
      ],
      child: const MaterialApp(
        home: ReportsScreen(),
      ),
    );
  }

  testWidgets('ReportsScreen renders default spending report', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    final now = DateTime.now();
    final txns = [
      Transaction.create(
          title: 'Lunch',
          amount: 200,
          date: now,
          type: TransactionType.expense,
          category: 'Food'),
    ];
    final cats = [
      Category(id: '1', name: 'Food', usage: CategoryUsage.expense),
    ];

    await tester.pumpWidget(createWidgetUnderTest(txns: txns, cats: cats));
    await tester.pumpAndSettle();

    expect(find.text('Financial Reports'), findsOneWidget);
    expect(find.text('Spending'), findsOneWidget);
    expect(find.textContaining('Food'), findsWidgets);
  });

  testWidgets('ReportsScreen handles period switching', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    final dropdown = find.byType(DropdownButtonFormField<String>).first;
    expect(dropdown, findsOneWidget);

    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('90 Days').last);
    await tester.pumpAndSettle();
  });

  testWidgets('ReportsScreen switching to Loan report', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    final loan = Loan.create(
      name: 'Car Loan',
      principal: 1000000,
      rate: 9.0,
      tenureMonths: 60,
      startDate: DateTime.now().subtract(const Duration(days: 365)),
      emiAmount: 20000,
      emiDay: 15,
      firstEmiDate: DateTime.now().subtract(const Duration(days: 365)),
    );
    loan.transactions.add(LoanTransaction(
      id: 'L1',
      amount: 20000,
      date: DateTime.now().subtract(const Duration(days: 30)),
      type: LoanTransactionType.emi,
      principalComponent: 15000,
      interestComponent: 5000,
      resultantPrincipal: 900000,
    ));

    // Must provide at least one TRANSACTON for the report screen to not return "No data available"
    await tester.pumpWidget(createWidgetUnderTest(loans: [loan]));
    await tester.pumpAndSettle();

    final loanChip = find.text('Loan');
    expect(loanChip, findsWidgets);
    await tester.tap(loanChip.first);
    await tester.pumpAndSettle();

    expect(find.text('Total Liability'), findsOneWidget);
    expect(find.text('EMI Paid'), findsOneWidget);

    final loanDropdown = find.text('All Loans');
    await tester.tap(loanDropdown);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Car Loan').last);
    await tester.pumpAndSettle();
  });

  testWidgets('ReportsScreen aggregations - Others slice', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    final now = DateTime.now();
    final cats = List.generate(
        8,
        (i) =>
            Category(id: 'c$i', name: 'Cat$i', usage: CategoryUsage.expense));
    final txns = List.generate(
        8,
        (i) => Transaction.create(
              title: 'T$i',
              amount: (i + 1) * 100.0,
              date: now,
              type: TransactionType.expense,
              category: 'Cat$i',
            ));

    await tester.pumpWidget(createWidgetUnderTest(txns: txns, cats: cats));
    await tester.pumpAndSettle();
  });

  testWidgets('ReportsScreen - Category Exclusion and Sorting',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final catA =
        Category(id: 'ca', name: 'Apple', usage: CategoryUsage.expense);
    final catZ =
        Category(id: 'cz', name: 'Zebra', usage: CategoryUsage.expense);

    final txns = [
      Transaction.create(
          title: 'T1',
          amount: 100,
          date: DateTime.now(),
          type: TransactionType.expense,
          category: 'Apple'),
      Transaction.create(
          title: 'T2',
          amount: 5000,
          date: DateTime.now(),
          type: TransactionType.expense,
          category: 'Zebra'),
    ];

    await tester
        .pumpWidget(createWidgetUnderTest(txns: txns, cats: [catA, catZ]));
    await tester.pumpAndSettle();

    final filterBtn = find.byType(ActionChip);
    await tester.tap(filterBtn);
    await tester.pumpAndSettle();

    final zebraInDialog = find.text('Zebra').last;
    final appleInDialog = find.text('Apple').last;

    final zebraPos = tester.getCenter(zebraInDialog);
    final applePos = tester.getCenter(appleInDialog);
    expect(zebraPos.dy, lessThan(applePos.dy));

    await tester.tap(appleInDialog);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text('Apple'), findsNothing);

    // Reset Exclusion
    await tester.tap(filterBtn);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text('Apple'), findsOneWidget);
  });

  testWidgets('ReportsScreen - Capital Gains', (tester) async {
    tester.view.physicalSize = const Size(2000, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    final txns = [
      Transaction.create(
          title: 'Stocks',
          amount: 5000,
          date: DateTime.now(),
          type: TransactionType.income,
          category: 'Stocks',
          gainAmount: 5000),
      Transaction.create(
          title: 'MF',
          amount: 2000,
          date: DateTime.now(),
          type: TransactionType.income,
          category: 'Mutual Funds',
          gainAmount: 2000),
    ];
    final cats = [
      Category(
          id: 'c1',
          name: 'Stocks',
          usage: CategoryUsage.income,
          tag: CategoryTag.capitalGain),
      Category(
          id: 'c2',
          name: 'Mutual Funds',
          usage: CategoryUsage.income,
          tag: CategoryTag.capitalGain),
    ];

    await tester.pumpWidget(createWidgetUnderTest(txns: txns, cats: cats));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Income'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500)); // Extra wait

    expect(find.text('Capital Gains (Realized)'), findsOneWidget);
    // 7000 total
    expect(find.textContaining('7K'), findsAny);
  });

  testWidgets('ReportsScreen - Chart Navigation', (tester) async {
    tester.view.physicalSize = const Size(2400, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final txns = [
      Transaction.create(
          title: 'T1',
          amount: 100,
          date: DateTime.now(),
          type: TransactionType.expense,
          category: 'Food'),
    ];
    final cats = [
      Category(id: 'c1', name: 'Food', usage: CategoryUsage.expense),
    ];

    await tester.pumpWidget(createWidgetUnderTest(txns: txns, cats: cats));
    await tester.pumpAndSettle();

    final item = find.text('Food').last;
    await tester.tap(item);
    await tester.pumpAndSettle();

    // Needs TransactionsScreen to be reachable.
    // Ensure we wait enough for the transition.
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(TransactionsScreen), findsOneWidget);
  });
}
