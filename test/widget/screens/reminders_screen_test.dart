import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:clock/clock.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/feature_providers.dart';
import 'package:samriddhi_flow/screens/reminders_screen.dart';
import 'package:samriddhi_flow/models/loan.dart';
import 'package:samriddhi_flow/models/account.dart';
import 'package:samriddhi_flow/models/transaction.dart' as model;
import 'package:samriddhi_flow/models/recurring_transaction.dart';
import 'package:samriddhi_flow/models/taxes/tax_data.dart';
import 'package:samriddhi_flow/models/taxes/tax_rules.dart';
import 'package:samriddhi_flow/services/taxes/tax_config_service.dart';
import 'package:samriddhi_flow/services/taxes/indian_tax_service.dart';

import '../test_mocks.dart';

class MockTaxConfigService extends Mock implements TaxConfigService {}

class MockIndianTaxService extends Mock implements IndianTaxService {}

void main() {
  late MockCalendarService mockCalendarService;
  late MockStorageService mockStorage;
  late MockTaxConfigService mockTaxConfigService;
  late MockIndianTaxService mockIndianTaxService;

  setUpAll(() {
    registerFallbackValue(const TaxYearData(year: 2026));
    registerFallbackValue(TaxRules());
  });

  setUp(() {
    mockCalendarService = MockCalendarService();
    mockStorage = MockStorageService();
    mockTaxConfigService = MockTaxConfigService();
    mockIndianTaxService = MockIndianTaxService();
    setupStorageDefaults(mockStorage);

    when(() => mockCalendarService.downloadExvent(
          title: any(named: 'title'),
          description: any(named: 'description'),
          startTime: any(named: 'startTime'),
          endTime: any(named: 'endTime'),
        )).thenAnswer((_) async {});

    when(() => mockCalendarService.downloadRecurringEvent(
          title: any(named: 'title'),
          description: any(named: 'description'),
          startDate: any(named: 'startDate'),
          occurrences: any(named: 'occurrences'),
        )).thenAnswer((_) async {});

    when(() => mockStorage.advanceRecurringTransactionDate(any()))
        .thenAnswer((_) async {});
  });

  Widget createWidgetUnderTest({
    List<Loan>? loans,
    List<Account>? accounts,
    List<RecurringTransaction>? recurring,
    List<model.Transaction>? transactions,
    TaxYearData? taxData,
  }) {
    try {
      when(() => mockTaxConfigService.getCurrentFinancialYear())
          .thenReturn(2026);
    } catch (_) {}

    return ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(mockStorage),
        loansProvider.overrideWith((ref) => Stream.value(loans ?? [])),
        accountsProvider.overrideWith((ref) => Stream.value(accounts ?? [])),
        transactionsProvider
            .overrideWith((ref) => Stream.value(transactions ?? [])),
        recurringTransactionsProvider
            .overrideWith((ref) => Stream.value(recurring ?? [])),
        currencyProvider.overrideWith(() => MockCurrencyNotifier('en_IN')),
        calendarServiceProvider.overrideWithValue(mockCalendarService),
        categoriesProvider.overrideWith(() => MockCategoriesNotifier([])),
        holidaysProvider.overrideWith(() => MockHolidaysNotifier([])),
        pendingRemindersProvider.overrideWithValue(0),
        taxConfigServiceProvider.overrideWithValue(mockTaxConfigService),
        indianTaxServiceProvider.overrideWithValue(mockIndianTaxService),
        taxYearDataProvider.overrideWith((ref, year) => Stream.value(taxData)),
      ],
      child: const MaterialApp(
        home: RemindersScreen(),
      ),
    );
  }

  Future<void> expandSection(WidgetTester tester, String title) async {
    await tester.tap(find.text(title));
    await tester.pumpAndSettle();
  }

  testWidgets('RemindersScreen shows empty states by default', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1080, 5000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(find.text('Upcoming Loan EMIs'), findsOneWidget);

    await expandSection(tester, 'Upcoming Loan EMIs');
    expect(find.text('No EMIs due within 7 days.'), findsOneWidget);

    await expandSection(tester, 'Credit Card Bills');
    expect(find.text('No pending credit card bills.'), findsOneWidget);

    await expandSection(tester, 'Recurring Payments');
    expect(find.text('No due recurring payments.'), findsOneWidget);

    await expandSection(tester, 'Upcoming Tax Installments');
    expect(find.text('No upcoming tax installments.'), findsOneWidget);
  });

  group('Loan Reminders', () {
    testWidgets('shows partially paid loan', (tester) async {
      await withClock(Clock.fixed(DateTime(2026, 3, 10)), () async {
        final loan = Loan.create(
          name: 'Home Loan',
          principal: 100000,
          rate: 8.0,
          tenureMonths: 120,
          startDate: DateTime(2026, 2, 1),
          emiAmount: 2000,
          emiDay: 10,
          firstEmiDate: DateTime(2026, 2, 1),
        );
        loan.transactions.add(LoanTransaction(
          id: '1',
          amount: 800,
          date: DateTime(2026, 3, 10),
          type: LoanTransactionType.emi,
          principalComponent: 600,
          interestComponent: 200,
          resultantPrincipal: 99400,
        ));

        await tester.pumpWidget(createWidgetUnderTest(loans: [loan]));
        await tester.pumpAndSettle();

        await expandSection(tester, 'Upcoming Loan EMIs');

        expect(find.text('Home Loan'), findsOneWidget);
        expect(find.text('Partial'), findsOneWidget);
        expect(find.textContaining('Paid:'), findsOneWidget);
      });
    });

    testWidgets('shows overdue loan', (tester) async {
      await withClock(Clock.fixed(DateTime(2026, 3, 10)), () async {
        final loan = Loan.create(
          name: 'Personal Loan',
          principal: 50000,
          rate: 12.0,
          tenureMonths: 24,
          startDate: DateTime(2026, 1, 1),
          emiAmount: 1500,
          emiDay: 5,
          firstEmiDate: DateTime(2026, 1, 1),
        );

        await tester.pumpWidget(createWidgetUnderTest(loans: [loan]));
        await tester.pumpAndSettle();

        await expandSection(tester, 'Upcoming Loan EMIs');

        expect(find.text('Personal Loan'), findsOneWidget);
        expect(find.text('Overdue'), findsOneWidget);
      });
    });

    testWidgets('triggers calendar download', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1080, 5000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final loan = Loan.create(
        name: 'Edu Loan',
        principal: 20000,
        rate: 5.0,
        tenureMonths: 12,
        startDate: DateTime.now().subtract(const Duration(days: 30)),
        emiAmount: 1000,
        emiDay: DateTime.now().add(const Duration(days: 2)).day,
        firstEmiDate: DateTime.now().subtract(const Duration(days: 30)),
      );

      await tester.pumpWidget(createWidgetUnderTest(loans: [loan]));
      await tester.pumpAndSettle();

      await expandSection(tester, 'Upcoming Loan EMIs');

      final calendarBtn = find.text('Add to Calendar');
      await tester.dragUntilVisible(
          calendarBtn.first, find.byType(Scrollable), const Offset(0, -100));
      await tester.pumpAndSettle();

      await tester.tap(calendarBtn.first);
      await tester.pumpAndSettle();

      verify(() => mockCalendarService.downloadExvent(
            title: any(named: 'title'),
            description: any(named: 'description'),
            startTime: any(named: 'startTime'),
            endTime: any(named: 'endTime'),
          )).called(1);
    });

    testWidgets('shows loan that has not yet started', (tester) async {
      await withClock(Clock.fixed(DateTime(2026, 3, 10)), () async {
        final loan = Loan.create(
          name: 'Future Loan',
          principal: 100000,
          rate: 8.0,
          tenureMonths: 120,
          startDate: DateTime(2026, 3, 13),
          emiAmount: 2000,
          emiDay: 13,
          firstEmiDate: DateTime(2026, 3, 13),
        );

        await tester.pumpWidget(createWidgetUnderTest(loans: [loan]));
        await tester.pumpAndSettle();

        await expandSection(tester, 'Upcoming Loan EMIs');

        expect(find.text('Wait for Start'), findsOneWidget);
      });
    });

    testWidgets('shows fully paid loan emi', (tester) async {
      await withClock(Clock.fixed(DateTime(2026, 3, 10)), () async {
        final loan = Loan.create(
          name: 'Closed EMI Loan',
          principal: 100000,
          rate: 8.0,
          tenureMonths: 120,
          startDate: DateTime(2026, 2, 1),
          emiAmount: 2000,
          emiDay: 10,
          firstEmiDate: DateTime(2026, 2, 1),
        );
        loan.transactions.add(LoanTransaction(
          id: 'paid-1',
          amount: 2000,
          date: DateTime(2026, 3, 5),
          type: LoanTransactionType.emi,
          principalComponent: 1500,
          interestComponent: 500,
          resultantPrincipal: 98500,
        ));

        await tester.pumpWidget(createWidgetUnderTest(loans: [loan]));
        await tester.pumpAndSettle();

        await expandSection(tester, 'Upcoming Loan EMIs');

        // Now filtered out if fully paid or outside 7-day window
        expect(find.text('Closed EMI Loan'), findsNothing);
        expect(find.text('No EMIs due within 7 days.'), findsOneWidget);
      });
    });
  });

  group('Credit Card Reminders', () {
    testWidgets('shows CC bill reminders (Overdue)', (tester) async {
      await withClock(Clock.fixed(DateTime(2026, 3, 10)), () async {
        final acc = Account(
          id: 'cc1',
          name: 'SBI Card',
          type: AccountType.creditCard,
          balance: 5000,
          billingCycleDay: 15,
          paymentDueDateDay: 20,
        );

        await tester.pumpWidget(createWidgetUnderTest(accounts: [acc]));
        await tester.pumpAndSettle();

        await expandSection(tester, 'Credit Card Bills');

        expect(find.text('SBI Card'), findsOneWidget);
        expect(find.text('Overdue'), findsOneWidget);
      });
    });

    testWidgets('shows CC bill reminders (Partially Paid)', (tester) async {
      await withClock(Clock.fixed(DateTime(2026, 3, 10)), () async {
        final acc = Account(
          id: 'cc3',
          name: 'Axis Card',
          type: AccountType.creditCard,
          balance: 2000,
          billingCycleDay: 15,
          paymentDueDateDay: 20,
        );

        final txn = model.Transaction.create(
          title: 'Partial Payment',
          amount: 500,
          date: DateTime(2026, 3, 1),
          type: model.TransactionType.transfer,
          category: 'Payment',
          toAccountId: 'cc3',
        );

        when(() => mockStorage.getLastRollover('cc3')).thenReturn(0);

        await tester.pumpWidget(
            createWidgetUnderTest(accounts: [acc], transactions: [txn]));
        await tester.pumpAndSettle();

        await expandSection(tester, 'Credit Card Bills');

        expect(find.text('Partial'), findsOneWidget);
      });
    });

    testWidgets('shows CC bill reminders (Fully Paid)', (tester) async {
      await withClock(Clock.fixed(DateTime(2026, 3, 10)), () async {
        final acc = Account(
          id: 'cc4',
          name: 'OneCard',
          type: AccountType.creditCard,
          balance: 0,
          billingCycleDay: 15,
          paymentDueDateDay: 20,
        );

        await tester.pumpWidget(createWidgetUnderTest(accounts: [acc]));
        await tester.pumpAndSettle();

        await expandSection(tester, 'Credit Card Bills');

        // Now filtered out if totalDue <= 0.01
        expect(find.text('OneCard'), findsNothing);
        expect(find.text('No pending credit card bills.'), findsOneWidget);
      });
    });
  });

  group('Recurring Reminders', () {
    testWidgets('shows recurring payment', (tester) async {
      final now = DateTime(2026, 3, 10);
      await withClock(Clock.fixed(now), () async {
        final recurring = RecurringTransaction(
          id: 'r1',
          title: 'Rent',
          amount: 15000,
          frequency: Frequency.monthly,
          isActive: true,
          category: 'Housing',
          nextExecutionDate: DateTime(2026, 3, 10),
        );

        await tester.pumpWidget(createWidgetUnderTest(recurring: [recurring]));
        await tester.pumpAndSettle();

        await expandSection(tester, 'Recurring Payments');

        expect(find.text('Rent'), findsOneWidget);
      });
    });

    testWidgets('handles SKIP action', (tester) async {
      final now = DateTime(2026, 3, 10);
      await withClock(Clock.fixed(now), () async {
        final recurring = RecurringTransaction(
          id: 'r_skip',
          title: 'Sub',
          amount: 100,
          frequency: Frequency.monthly,
          isActive: true,
          category: 'Services',
          nextExecutionDate: DateTime(2026, 3, 9),
        );

        await tester.pumpWidget(createWidgetUnderTest(recurring: [recurring]));
        await tester.pumpAndSettle();

        await expandSection(tester, 'Recurring Payments');

        await tester.tap(find.text('SKIP'));
        await tester.pumpAndSettle();

        expect(find.text('Skip Cycle?'), findsOneWidget);
        await tester.tap(find.text('SKIP').last);
        await tester.pumpAndSettle();

        verify(() => mockStorage.advanceRecurringTransactionDate('r_skip'))
            .called(1);
      });
    });
  });

  group('Tax Reminders', () {
    testWidgets('shows upcoming tax installment', (tester) async {
      final now = DateTime(2026, 3, 10);
      await withClock(Clock.fixed(now), () async {
        const taxData = TaxYearData(year: 2025);
        final rules = TaxRules();

        when(() => mockTaxConfigService.getCurrentFinancialYear())
            .thenReturn(2025);
        when(() => mockStorage.getTaxYearData(any())).thenReturn(taxData);
        when(() => mockTaxConfigService.getRulesForYear(any()))
            .thenReturn(rules);
        when(() =>
                mockIndianTaxService.calculateDetailedLiability(any(), any()))
            .thenReturn({
          'nextAdvanceTaxDueDate': DateTime(2026, 3, 15),
          'nextAdvanceTaxAmount': 15000.0,
          'daysUntilAdvanceTax': 5,
          'isRequirementMet': false,
        });

        await tester.pumpWidget(createWidgetUnderTest(taxData: taxData));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        await expandSection(tester, 'Upcoming Tax Installments');

        expect(find.textContaining('Tax'), findsWidgets);
      });
    });
  });
}
