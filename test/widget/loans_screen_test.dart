import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/screens/loans_screen.dart';
import 'package:samriddhi_flow/screens/add_loan_screen.dart';
import 'package:samriddhi_flow/screens/loan_details_screen.dart';
import 'package:samriddhi_flow/models/loan.dart';
import 'package:samriddhi_flow/services/loan_service.dart';

// Mocks
class MockLoanService extends Mock implements LoanService {}

class MockCurrencyNotifier extends CurrencyNotifier {
  @override
  String build() => 'en_US';
}

class FakeLoan extends Fake implements Loan {}

void main() {
  late MockLoanService mockLoanService;

  setUpAll(() {
    registerFallbackValue(FakeLoan());
  });

  setUp(() {
    mockLoanService = MockLoanService();
    // Default Stub
    when(() => mockLoanService.calculateAmortizationSchedule(any())).thenReturn(
      List<Map<String, dynamic>>.empty(),
    );
  });

  Widget createWidgetUnderTest({AsyncValue<List<Loan>>? overrideValue}) {
    return ProviderScope(
      overrides: [
        storageInitializerProvider
            .overrideWithValue(const AsyncValue.data(null)),
        firebaseInitializerProvider
            .overrideWithValue(const AsyncValue.data(null)),
        loansProvider
            .overrideWith((ref) => Stream.value(overrideValue?.value ?? [])),
        currencyProvider.overrideWith(MockCurrencyNotifier.new),
        loanServiceProvider.overrideWithValue(mockLoanService),
      ],
      child: const MaterialApp(
        home: LoansScreen(),
      ),
    );
  }

  testWidgets('LoansScreen shows empty state when no loans', (tester) async {
    await tester.pumpWidget(
        createWidgetUnderTest(overrideValue: const AsyncValue.data([])));
    await tester.pumpAndSettle();

    expect(find.text('No active loans.'), findsOneWidget);
    expect(find.text('Add Loan'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('LoansScreen shows loan list and navigates to details',
      (tester) async {
    final loan = Loan.create(
      name: 'Detail Loan',
      principal: 200000,
      rate: 9.0,
      startDate: DateTime.now(),
      tenureMonths: 60,
      emiAmount: 5000.0,
      emiDay: 5,
      firstEmiDate: DateTime.now().add(const Duration(days: 30)),
    );

    when(() => mockLoanService.calculateAmortizationSchedule(any())).thenReturn(
      List.generate(
          60,
          (index) => <String, dynamic>{
                'month': index + 1,
                'date': DateTime.now(),
                'emi': 5000.0,
                'interest': 100.0,
                'principal': 4900.0,
                'balance': 200000.0 - (index * 4900.0),
              }),
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        storageInitializerProvider
            .overrideWithValue(const AsyncValue.data(null)),
        firebaseInitializerProvider
            .overrideWithValue(const AsyncValue.data(null)),
        loansProvider.overrideWith((ref) => Stream.value([loan])),
        currencyProvider.overrideWith(MockCurrencyNotifier.new),
        loanServiceProvider.overrideWithValue(mockLoanService),
      ],
      child: const MaterialApp(
        home: LoansScreen(),
      ),
    ));

    // Manual pumps for initial list load
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.text('Detail Loan'), findsOneWidget);
    expect(find.textContaining('60m Left'), findsOneWidget);

    // Test Navigation to Details
    await tester.tap(find.text('Detail Loan'));

    // Manual pumps for navigation and animation (FlChart)
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(LoanDetailsScreen), findsOneWidget);
    expect(find.text('Detail Loan'), findsOneWidget);
  });

  testWidgets('LoansScreen FAB opens AddLoanScreen', (tester) async {
    await tester.pumpWidget(
        createWidgetUnderTest(overrideValue: const AsyncValue.data([])));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.byType(AddLoanScreen), findsOneWidget);
  });
}
