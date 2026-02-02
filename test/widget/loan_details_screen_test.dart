import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/screens/loan_details_screen.dart';
import 'package:samriddhi_flow/models/loan.dart';
import 'package:samriddhi_flow/services/loan_service.dart';
import 'package:samriddhi_flow/services/storage_service.dart';

class MockLoanService extends Mock implements LoanService {}

class MockStorageService extends Mock implements StorageService {}

class MockCurrencyNotifier extends CurrencyNotifier {
  @override
  String build() => 'en_US';
}

class FakeLoan extends Fake implements Loan {
  @override
  String get name => 'Fake Loan';
  @override
  double get remainingPrincipal => 1000;
  @override
  double get totalPrincipal => 1000;
}

void main() {
  late MockLoanService mockLoanService;
  late MockStorageService mockStorageService;

  setUpAll(() {
    registerFallbackValue(FakeLoan());
  });

  setUp(() {
    mockLoanService = MockLoanService();
    mockStorageService = MockStorageService();

    when(() => mockLoanService.calculateAmortizationSchedule(any()))
        .thenReturn([]);
    when(() => mockLoanService.calculateRemainingTenure(any()))
        .thenReturn((months: 0.0, days: 0));
  });

  Widget createWidgetUnderTest(Loan loan) {
    return ProviderScope(
      overrides: [
        loanServiceProvider.overrideWithValue(mockLoanService),
        storageServiceProvider.overrideWithValue(mockStorageService),
        currencyProvider.overrideWith(MockCurrencyNotifier.new),
        loansProvider.overrideWith((ref) => Stream.value([loan])),
        accountsProvider.overrideWith((ref) => Stream.value([])),
      ],
      child: MaterialApp(
        home: LoanDetailsScreen(loan: loan),
      ),
    );
  }

  testWidgets('LoanDetailsScreen renders details', (tester) async {
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Home Loan'), findsOneWidget);
  });

  testWidgets('LoanDetailsScreen shows Delete option', (tester) async {
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Tap Delete Button (Tooltip)
    await tester.tap(find.byTooltip('Delete Loan'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Delete Loan?'), findsOneWidget);

    // Trigger Delete
    when(() => mockStorageService.deleteLoan(any())).thenAnswer((_) async {});

    await tester.tap(find.text('Delete'));
    await tester.pump(const Duration(milliseconds: 500));

    verify(() => mockStorageService.deleteLoan(loan.id)).called(1);
  });
}
