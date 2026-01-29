import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/feature_providers.dart';
import 'package:samriddhi_flow/screens/reminders_screen.dart';
import 'package:samriddhi_flow/services/calendar_service.dart';
import 'package:samriddhi_flow/models/loan.dart';
import 'package:samriddhi_flow/models/account.dart';
import 'package:samriddhi_flow/models/recurring_transaction.dart';

// Mocks
class MockCalendarService extends Mock implements CalendarService {}

class MockCurrencyNotifier extends CurrencyNotifier {
  @override
  String build() => 'en_US';
}

void main() {
  late MockCalendarService mockCalendarService;

  setUp(() {
    mockCalendarService = MockCalendarService();
  });

  Widget createWidgetUnderTest({
    List<Loan>? loans,
    List<Account>? accounts,
    List<RecurringTransaction>? recurring,
  }) {
    return ProviderScope(
      overrides: [
        loansProvider.overrideWith((ref) => Stream.value(loans ?? [])),
        accountsProvider.overrideWith((ref) => Stream.value(accounts ?? [])),
        transactionsProvider.overrideWith((ref) => Stream.value([])),
        recurringTransactionsProvider
            .overrideWith((ref) => Stream.value(recurring ?? [])),
        currencyProvider.overrideWith(MockCurrencyNotifier.new),
        calendarServiceProvider.overrideWithValue(mockCalendarService),
      ],
      child: const MaterialApp(
        home: RemindersScreen(),
      ),
    );
  }

  testWidgets('RemindersScreen shows empty states by default', (tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(find.text('Upcoming Loan EMIs'), findsOneWidget);
    expect(find.text('No active loans.'), findsOneWidget);

    expect(find.text('Credit Card Bills'), findsOneWidget);
    // Accounts list empty means "No credit cards." text?
    // accounts.where(type == CreditCard).
    expect(find.text('No credit cards.'), findsOneWidget);

    expect(find.text('Recurring Payments'), findsOneWidget);
    expect(find.text('No active recurring payments.'), findsOneWidget);
  });

  testWidgets('RemindersScreen shows active loan reminder', (tester) async {
    final loan = Loan.create(
      name: 'Car Loan',
      principal: 50000,
      rate: 9.0,
      tenureMonths: 60,
      startDate: DateTime.now().subtract(const Duration(days: 30)),
      emiAmount: 1000,
      emiDay: DateTime.now().day, // Upcoming (Due Today)
      firstEmiDate: DateTime.now().subtract(const Duration(days: 30)),
    );

    // Ensure it's active
    loan.remainingPrincipal = 50000;

    await tester.pumpWidget(createWidgetUnderTest(loans: [loan]));
    await tester.pumpAndSettle();

    expect(find.text('Car Loan'), findsOneWidget);
    expect(find.text('Upcoming'), findsOneWidget);
    expect(find.text('PAY NOW'), findsOneWidget);
  });

  testWidgets('RemindersScreen shows recurring payment reminder',
      (tester) async {
    final recurring = RecurringTransaction(
      id: '1',
      title: 'Netflix',
      amount: 500,
      frequency: Frequency.monthly,
      isActive: true,
      category: 'Entertainment',
      nextExecutionDate: DateTime.now().add(const Duration(days: 20)),
    );

    await tester.pumpWidget(createWidgetUnderTest(recurring: [recurring]));
    await tester.pumpAndSettle();

    expect(find.text('Netflix'), findsOneWidget);
    expect(find.text('PAY NOW'), findsOneWidget);
  });
}
