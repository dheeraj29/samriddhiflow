import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:clock/clock.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/feature_providers.dart';
import 'package:samriddhi_flow/screens/reminders_screen.dart';
import 'package:samriddhi_flow/screens/add_transaction_screen.dart';

import 'package:samriddhi_flow/models/loan.dart';
import 'package:samriddhi_flow/models/account.dart';
import 'package:samriddhi_flow/models/transaction.dart' as model;
import 'package:samriddhi_flow/models/recurring_transaction.dart';

import '../test_mocks.dart';

void main() {
  late MockCalendarService mockCalendarService;
  late MockStorageService mockStorage;

  setUp(() {
    mockCalendarService = MockCalendarService();
    mockStorage = MockStorageService();
    setupStorageDefaults(mockStorage);

    // Default stubs for calendar
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
  }) {
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
      ],
      child: const MaterialApp(
        home: RemindersScreen(),
      ),
    );
  }

  testWidgets('RemindersScreen shows empty states by default', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1080, 5000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(find.text('Upcoming Loan EMIs'), findsOneWidget);
    expect(find.text('No active loans.'), findsOneWidget);
    expect(find.text('No credit cards.'), findsOneWidget);
    expect(find.text('No active recurring payments.'), findsOneWidget);
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
        loan.remainingPrincipal = 100000;
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

        expect(find.text('Home Loan'), findsOneWidget);
        expect(find.text('Partial'), findsOneWidget);
        expect(
            find.textContaining('Paid: ₹800.00 / ₹2,000.00'), findsOneWidget);
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
          emiDay: 5, // Due on 5th. 10th > 5th, so overdue.
          firstEmiDate: DateTime(2026, 1, 1),
        );
        loan.remainingPrincipal = 50000;

        await tester.pumpWidget(createWidgetUnderTest(loans: [loan]));
        await tester.pumpAndSettle();

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
        emiDay: DateTime.now().add(const Duration(days: 2)).day, // Future day
        firstEmiDate: DateTime.now().subtract(const Duration(days: 30)),
      );
      loan.remainingPrincipal = 20000;

      await tester.pumpWidget(createWidgetUnderTest(loans: [loan]));
      await tester.pumpAndSettle();

      final calendarBtn = find.text('Add to Calendar');
      await tester.dragUntilVisible(
          calendarBtn.first, find.byType(ListView), const Offset(0, -100));
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
  });

  group('Credit Card Reminders', () {
    testWidgets('shows CC bill reminders (Overdue) and triggers PAY NOW',
        (tester) async {
      await withClock(Clock.fixed(DateTime(2026, 3, 10)), () async {
        await tester.binding.setSurfaceSize(const Size(1080, 5000));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final acc = Account(
          id: 'cc1',
          name: 'SBI Card',
          type: AccountType.creditCard,
          balance: 5000,
          billingCycleDay: 15, // Last bill on Feb 15
          paymentDueDateDay:
              20, // Due 20 days after = Mar 7. Overdue on Mar 10.
        );

        await tester.pumpWidget(createWidgetUnderTest(
          accounts: [acc],
          transactions: [],
        ));
        await tester.pumpAndSettle();

        expect(find.text('SBI Card'), findsOneWidget);
        expect(find.text('Overdue'), findsOneWidget);

        final payNowBtn = find.text('PAY NOW');
        await tester.dragUntilVisible(
            payNowBtn, find.byType(ListView), const Offset(0, -100));
        await tester.pumpAndSettle();

        await tester.tap(payNowBtn);
        await tester.pumpAndSettle();

        // Should show CC Payment Dialog
        expect(find.textContaining('Pay'), findsWidgets);
        expect(find.text('Confirm'), findsOneWidget);
      });
    });

    testWidgets('shows CC bill reminders (Upcoming)', (tester) async {
      await withClock(Clock.fixed(DateTime(2026, 3, 10)), () async {
        await tester.binding.setSurfaceSize(const Size(1080, 5000));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final acc = Account(
          id: 'cc2',
          name: 'HDFC Card',
          type: AccountType.creditCard,
          balance: 3000,
          billingCycleDay: 15, // Last bill on Feb 15.
          paymentDueDateDay: 25, // Due Mar 12. Mar 10 < Mar 12, so Upcoming.
        );

        await tester.pumpWidget(createWidgetUnderTest(
          accounts: [acc],
          transactions: [],
        ));
        await tester.pumpAndSettle();

        expect(find.text('HDFC Card'), findsOneWidget);
        expect(find.text('Upcoming'), findsOneWidget);
      });
    });
  });

  group('Recurring Reminders', () {
    testWidgets('handles PAY NOW action', (tester) async {
      await withClock(Clock.fixed(DateTime(2026, 3, 10)), () async {
        await tester.binding.setSurfaceSize(const Size(1080, 5000));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final recurring = RecurringTransaction(
          id: 'r_pay',
          title: 'Subscription',
          amount: 500,
          frequency: Frequency.monthly,
          isActive: true,
          category: 'Services',
          nextExecutionDate: DateTime(2026, 3, 11),
        );

        await tester.pumpWidget(createWidgetUnderTest(recurring: [recurring]));
        await tester.pumpAndSettle();

        final payNowBtn = find.text('PAY NOW');
        await tester.dragUntilVisible(
            payNowBtn, find.byType(Scrollable), const Offset(0, -100));
        await tester.pumpAndSettle();

        await tester.tap(payNowBtn);
        await tester.pumpAndSettle();

        expect(find.byType(AddTransactionScreen), findsOneWidget);
        expect(find.text('Update Transaction'), findsOneWidget);
      });
    });
    testWidgets('handles SKIP action', (tester) async {
      await withClock(Clock.fixed(DateTime(2026, 3, 10)), () async {
        await tester.binding.setSurfaceSize(const Size(1080, 5000));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final recurring = RecurringTransaction(
          id: 'r1',
          title: 'Rent',
          amount: 15000,
          frequency: Frequency.monthly,
          isActive: true,
          category: 'Housing',
          nextExecutionDate: DateTime(2026, 3, 12),
        );

        await tester.pumpWidget(createWidgetUnderTest(recurring: [recurring]));
        await tester.pumpAndSettle();

        final skipBtn = find.text('SKIP');
        await tester.dragUntilVisible(
            skipBtn, find.byType(Scrollable), const Offset(0, -100));
        await tester.pumpAndSettle();

        await tester.tap(skipBtn);
        await tester.pumpAndSettle();

        // Confirm dialog
        expect(find.text('Skip Cycle?'), findsOneWidget);
        await tester.tap(find.text('SKIP').last);
        await tester.pumpAndSettle();

        verify(() => mockStorage.advanceRecurringTransactionDate('r1'))
            .called(1);
      });
    });

    testWidgets('triggers recurring calendar download', (tester) async {
      final recurring = RecurringTransaction(
        id: 'r2',
        title: 'Gym',
        amount: 2000,
        frequency: Frequency.monthly,
        isActive: true,
        category: 'Health',
        nextExecutionDate: DateTime.now().add(const Duration(days: 5)),
      );

      await tester.pumpWidget(createWidgetUnderTest(recurring: [recurring]));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add to Calendar').last);
      await tester.pumpAndSettle();

      verify(() => mockCalendarService.downloadRecurringEvent(
            title: any(named: 'title'),
            description: any(named: 'description'),
            startDate: any(named: 'startDate'),
            occurrences: any(named: 'occurrences'),
          )).called(1);
    });
  });
}
