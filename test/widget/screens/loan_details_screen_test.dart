import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/feature_providers.dart';
import 'package:samriddhi_flow/screens/loan_details_screen.dart';
import 'package:samriddhi_flow/models/loan.dart';
import 'package:samriddhi_flow/models/transaction.dart';
import 'package:samriddhi_flow/services/loan_service.dart';
import 'package:samriddhi_flow/services/storage_service.dart';
import 'package:samriddhi_flow/services/calendar_service.dart';

class MockLoanService extends Mock implements LoanService {}

class MockStorageService extends Mock implements StorageService {}

class MockCalendarService extends Mock implements CalendarService {}

class MockCurrencyNotifier extends CurrencyNotifier {
  @override
  String build() => 'en_US';
}

class FakeLoan extends Fake implements Loan {
  @override
  String get name => 'Fake Loan';
  @override
  String get id => '1';
  @override
  double get remainingPrincipal => 1000;
  @override
  double get totalPrincipal => 1000;
  @override
  List<LoanTransaction> get transactions => [];
  @override
  LoanType get type => LoanType.personal;
  @override
  DateTime get startDate => DateTime(2023, 1, 1);
  @override
  double get emiAmount => 100;
  @override
  int get emiDay => 1;
  @override
  double get interestRate => 10;
  @override
  int get tenureMonths => 12;
}

class FakeTransaction extends Fake implements Transaction {}

void main() {
  late MockLoanService mockLoanService;
  late MockStorageService mockStorageService;
  late MockCalendarService mockCalendarService;

  setUpAll(() {
    registerFallbackValue(FakeLoan());
    registerFallbackValue(FakeTransaction());
    registerFallbackValue(LoanTransaction(
        id: '1',
        date: DateTime.now(),
        amount: 100,
        type: LoanTransactionType.emi,
        principalComponent: 50,
        interestComponent: 50,
        resultantPrincipal: 950));
  });

  setUp(() {
    mockLoanService = MockLoanService();
    mockStorageService = MockStorageService();
    mockCalendarService = MockCalendarService();

    when(() => mockLoanService.calculateAmortizationSchedule(any()))
        .thenReturn([
      {'month': 1, 'balance': 900.0},
      {'month': 2, 'balance': 800.0},
    ]);

    when(() => mockLoanService.calculateRemainingTenure(any()))
        .thenReturn((months: 12.0, days: 0));

    when(() => mockStorageService.saveLoan(any())).thenAnswer((_) async {});
    when(() => mockStorageService.saveTransaction(any()))
        .thenAnswer((_) async {});
  });

  Widget createWidgetUnderTest(Loan loan, {List<Loan>? allLoans}) {
    return ProviderScope(
      overrides: [
        loanServiceProvider.overrideWithValue(mockLoanService),
        storageServiceProvider.overrideWithValue(mockStorageService),
        calendarServiceProvider.overrideWithValue(mockCalendarService),
        currencyProvider.overrideWith(MockCurrencyNotifier.new),
        loansProvider.overrideWith((ref) => Stream.value(allLoans ?? [loan])),
        accountsProvider.overrideWith((ref) => Stream.value([])),
        transactionsProvider.overrideWith((ref) => Stream.value([])),
      ],
      child: MaterialApp(
        home: LoanDetailsScreen(loan: loan),
        localizationsDelegates: const [
          DefaultMaterialLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
        ],
      ),
    );
  }

  testWidgets('Standard Loan - renders details and amortization',
      (tester) async {
    final loan = Loan.create(
      name: 'Home Loan',
      principal: 5000000,
      rate: 8.5,
      tenureMonths: 240,
      startDate: DateTime(2023, 1, 1),
      emiAmount: 43000,
      emiDay: 5,
      firstEmiDate: DateTime(2023, 2, 5),
    );

    await tester.pumpWidget(createWidgetUnderTest(loan));
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Home Loan'), findsOneWidget);
    expect(find.text('Amortization Curve (Yearly)'), findsOneWidget);
  });

  testWidgets('Standard Loan - Simulator interaction', (tester) async {
    final loan = Loan.create(
      name: 'Car Loan',
      principal: 500000,
      rate: 9,
      tenureMonths: 60,
      startDate: DateTime(2023, 1, 1),
      emiAmount: 10000,
      emiDay: 5,
      firstEmiDate: DateTime(2023, 2, 5),
    );

    when(() => mockLoanService.calculatePrepaymentImpact(
        loan: any(named: 'loan'),
        prepaymentAmount: any(named: 'prepaymentAmount'),
        reduceTenure: any(named: 'reduceTenure'))).thenReturn({
      'newTenure': 50,
      'newEMI': 10000.0,
      'interestSaved': 5000.0,
      'tenureSaved': 10
    });

    await tester.pumpWidget(createWidgetUnderTest(loan));
    await tester.pump(const Duration(seconds: 2));

    // Navigate to Simulator
    await tester.scrollUntilVisible(find.text('Simulator'), 100);
    await tester.tap(find.text('Simulator'));
    await tester.pumpAndSettle();

    expect(find.text('Extra Payment Amount'), findsOneWidget);

    // Enter amount
    await tester.enterText(find.byType(TextFormField), '50000');
    await tester.pumpAndSettle();

    // Verify results shown
    expect(find.text('Interest Saved'), findsOneWidget);
    expect(find.text('Tenure Reduced'), findsOneWidget);
  });

  testWidgets('Standard Loan - Ledger View', (tester) async {
    final loan = Loan.create(
      name: 'Ledger Test',
      principal: 1000,
      rate: 10,
      tenureMonths: 12,
      startDate: DateTime(2023, 1, 1),
      emiAmount: 100,
      emiDay: 5,
      firstEmiDate: DateTime(2023, 2, 5),
    );

    await tester.pumpWidget(createWidgetUnderTest(loan));
    await tester.pump(const Duration(seconds: 2));

    await tester.scrollUntilVisible(find.text('Ledger'), 100);
    await tester.tap(find.text('Ledger'));
    await tester.pumpAndSettle();

    expect(find.byType(ListView), findsWidgets);
  });

  testWidgets('Standard Loan - Actions (Delete)', (tester) async {
    final loan = Loan.create(
      name: 'Delete Me',
      principal: 10000,
      rate: 10,
      tenureMonths: 12,
      startDate: DateTime.now(),
      emiAmount: 1000,
      emiDay: 1,
      firstEmiDate: DateTime.now(),
    );

    await tester.pumpWidget(createWidgetUnderTest(loan));
    await tester.pump(const Duration(seconds: 2));

    await tester.tap(find.byTooltip('Delete Loan'));
    await tester.pumpAndSettle();

    expect(find.text('Delete Loan?'), findsOneWidget);

    when(() => mockStorageService.deleteLoan(any())).thenAnswer((_) async {});
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    verify(() => mockStorageService.deleteLoan(loan.id)).called(1);
  });

  testWidgets('Gold Loan - Renders Gold specific view', (tester) async {
    final loan = Loan.create(
      name: 'Gold Loan',
      principal: 100000,
      rate: 12,
      tenureMonths: 12,
      startDate: DateTime.now().subtract(const Duration(days: 30)),
      emiAmount: 0,
      type: LoanType.gold,
      emiDay: 1,
      firstEmiDate: DateTime.now(),
    );

    await tester.pumpWidget(createWidgetUnderTest(loan));
    await tester.pumpAndSettle();

    // Verify Gold Actions present
    expect(find.text('Renew'), findsOneWidget);
    expect(find.text('Part Pay'), findsOneWidget);
    expect(find.text('Rate'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);

    expect(find.text('Amortization Curve (Yearly)'), findsNothing);

    // Test Rate Dialog trigger (Tap the Icon Button, not the text)
    await tester.tap(find.byIcon(Icons.percent));
    await tester.pumpAndSettle();
    expect(find.text('Update Interest Rate'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets('Standard Loan - Bulk Pay Dialog', (tester) async {
    final loan = Loan.create(
      name: 'Bulk Test',
      principal: 50000,
      rate: 10,
      tenureMonths: 24,
      startDate: DateTime(2023, 1, 1),
      emiAmount: 2500,
      emiDay: 1,
      firstEmiDate: DateTime(2023, 2, 5),
    );

    await tester.pumpWidget(createWidgetUnderTest(loan));
    await tester.pump(const Duration(seconds: 2));

    // Check Manual Pay Dialog First
    await tester.scrollUntilVisible(find.text('Pay'), 100);
    await tester.tap(find.text('Pay'));
    await tester.pumpAndSettle();
    expect(find.text('Record Loan Payment'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Just check Bulk Pay button exists for coverage of rendering
    expect(find.text('Bulk Pay'), findsOneWidget);
  });

  testWidgets('Standard Loan - Top Up Trigger', (tester) async {
    final loan = Loan.create(
      name: 'TopUp Test',
      principal: 10000,
      rate: 10,
      tenureMonths: 12,
      startDate: DateTime.now(),
      emiAmount: 1000,
      emiDay: 1,
      firstEmiDate: DateTime.now(),
    );
    await tester.pumpWidget(createWidgetUnderTest(loan));
    await tester.pump(const Duration(seconds: 2));

    await tester.tap(find.byTooltip('Top-up Loan'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
  });
}
