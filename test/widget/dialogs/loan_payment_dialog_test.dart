import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/screens/loan_payment_dialog.dart';
import 'package:samriddhi_flow/models/loan.dart';
import 'package:samriddhi_flow/models/transaction.dart';
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

class FakeTransaction extends Fake implements Transaction {}

void main() {
  late MockLoanService mockLoanService;
  late MockStorageService mockStorageService;

  setUpAll(() {
    registerFallbackValue(FakeLoan());
    registerFallbackValue(FakeTransaction());
    registerFallbackValue(Transaction.create(
        title: 't',
        amount: 0,
        date: DateTime.now(),
        type: TransactionType.expense,
        category: 'fake'));
  });

  setUp(() {
    mockLoanService = MockLoanService();
    mockStorageService = MockStorageService();
  });

  Widget createWidgetUnderTest(Loan loan) {
    return ProviderScope(
      overrides: [
        loanServiceProvider.overrideWithValue(mockLoanService),
        storageServiceProvider.overrideWithValue(mockStorageService),
        currencyProvider.overrideWith(MockCurrencyNotifier.new),
        accountsProvider.overrideWith((ref) => Stream.value([])),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDialog(
                  context: context,
                  builder: (_) => RecordLoanPaymentDialog(loan: loan)),
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('RecordLoanPaymentDialog records EMI', (tester) async {
    final loan = Loan.create(
      name: 'Test Loan',
      principal: 10000,
      rate: 10,
      tenureMonths: 12,
      startDate: DateTime.now().subtract(const Duration(days: 30)),
      emiAmount: 1000,
      emiDay: 1,
      firstEmiDate: DateTime.now(),
    );

    // Mock Calculations
    when(() => mockLoanService.calculateAccruedInterest(
        principal: any(named: 'principal'),
        annualRate: any(named: 'annualRate'),
        fromDate: any(named: 'fromDate'),
        toDate: any(named: 'toDate'))).thenReturn(50.0); // Interest Component

    when(() => mockStorageService.saveTransaction(any()))
        .thenAnswer((_) async {});
    when(() => mockStorageService.saveLoan(any())).thenAnswer((_) async {});

    await tester.pumpWidget(createWidgetUnderTest(loan));
    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    // Verify Default State (EMI selected, Amount filled)
    expect(find.text('EMI'), findsOneWidget);
    expect(find.text('1000.00'), findsOneWidget);

    // Confirm Payment
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    // Verify Save calls
    verify(() => mockStorageService.saveTransaction(any())).called(1);

    // Verify Loan Updated (Principal reduced by 1000 - 50 = 950)
    // 10000 - 950 = 9050.
    final capturedLoan = verify(() => mockStorageService.saveLoan(captureAny()))
        .captured
        .first as Loan;
    expect(capturedLoan.remainingPrincipal, 9050.0);
    expect(capturedLoan.transactions.length, 1);
  });

  testWidgets('RecordLoanPaymentDialog records Prepayment', (tester) async {
    final loan = Loan.create(
      name: 'Test Loan',
      principal: 10000,
      rate: 10,
      tenureMonths: 12,
      startDate: DateTime.now(),
      emiAmount: 1000,
      emiDay: 1,
      firstEmiDate: DateTime.now(),
    );

    when(() => mockStorageService.saveTransaction(any()))
        .thenAnswer((_) async {});
    when(() => mockStorageService.saveLoan(any())).thenAnswer((_) async {});
    when(() => mockLoanService.calculateTenureForEMI(
        principal: any(named: 'principal'),
        annualRate: any(named: 'annualRate'),
        emi: any(named: 'emi'))).thenReturn(10);

    await tester.pumpWidget(createWidgetUnderTest(loan));
    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    // Switch to Prepayment
    await tester.tap(find.text('Prepayment'));
    await tester.pumpAndSettle();

    // Enter Amount
    await tester.enterText(find.byType(TextField), '2000');
    await tester.pump();

    // Confirm
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    // Verify Principal reduced by full amount (2000) -> 8000
    final capturedLoan = verify(() => mockStorageService.saveLoan(captureAny()))
        .captured
        .first as Loan;
    expect(capturedLoan.remainingPrincipal, 8000.0);

    // Verify Tenure recalculation called (since default is Reduce Tenure)
    verify(() => mockLoanService.calculateTenureForEMI(
        principal: 8000.0, annualRate: 10.0, emi: 1000.0)).called(1);
  });
}
