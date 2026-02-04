import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/models/loan.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/screens/loan/loan_update_rate_dialog.dart';
import 'package:samriddhi_flow/services/loan_service.dart';
import 'package:samriddhi_flow/services/storage_service.dart';

class MockStorageService extends Mock implements StorageService {}

class MockLoanService extends Mock implements LoanService {}

void main() {
  late MockStorageService mockStorageService;
  late MockLoanService mockLoanService;

  setUpAll(() {
    registerFallbackValue(Loan(
      id: 'fallback',
      name: 'fallback',
      accountId: 'acc1',
      totalPrincipal: 1000,
      remainingPrincipal: 1000,
      interestRate: 10,
      tenureMonths: 12,
      emiAmount: 100,
      startDate: DateTime.now(),
      firstEmiDate: DateTime.now().add(const Duration(days: 30)),
      type: LoanType.personal,
    ));
    registerFallbackValue(DateTime.now());
  });

  setUp(() {
    mockStorageService = MockStorageService();
    mockLoanService = MockLoanService();

    // Default stubs
    when(() => mockStorageService.saveLoan(any())).thenAnswer((_) async {});
  });

  Widget createSubject(Loan loan) {
    return ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(mockStorageService),
        loanServiceProvider.overrideWithValue(mockLoanService),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(builder: (context) {
            return ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => LoanUpdateRateDialog(loan: loan),
                );
              },
              child: const Text('Open Dialog'),
            );
          }),
        ),
      ),
    );
  }

  group('LoanUpdateRateDialog', () {
    testWidgets('renders correctly', (tester) async {
      final loan = Loan(
        id: 'L1',
        name: 'Car Loan',
        accountId: 'A1',
        totalPrincipal: 500000,
        remainingPrincipal: 400000,
        interestRate: 8.5,
        tenureMonths: 48,
        emiAmount: 12000,
        startDate: DateTime(2023, 1, 1),
        firstEmiDate: DateTime(2023, 2, 1),
        type: LoanType.car,
      );

      await tester.pumpWidget(createSubject(loan));
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Update Interest Rate'), findsOneWidget);
      expect(find.text('Enter new annual interest rate.'), findsOneWidget);
      expect(find.text('New Annual Rate (%)'), findsOneWidget);
      expect(find.text('8.5'), findsOneWidget); // Pre-filled
      expect(find.text('Effective Date'), findsOneWidget);
      expect(find.text('Adjust EMI'), findsOneWidget);
      expect(find.text('Adjust Tenure'), findsOneWidget);
      expect(find.text('Update'), findsOneWidget);
    });

    testWidgets('updates rate and adjusts EMI (default)', (tester) async {
      final loan = Loan(
        id: 'L1',
        name: 'Car Loan',
        accountId: 'A1',
        totalPrincipal: 500000,
        remainingPrincipal: 400000,
        interestRate: 8.5,
        tenureMonths: 48,
        emiAmount: 12000,
        startDate: DateTime(2023, 1, 1),
        firstEmiDate: DateTime(2023, 2, 1),
        type: LoanType.car,
      );

      // Stubs
      when(() => mockLoanService.calculateAccruedInterest(
          principal: any(named: 'principal'),
          annualRate: any(named: 'annualRate'),
          fromDate: any(named: 'fromDate'),
          toDate: any(named: 'toDate'))).thenReturn(500.0);

      when(() => mockLoanService.calculateEMI(
          principal: any(named: 'principal'),
          annualRate: any(named: 'annualRate'),
          tenureMonths: any(named: 'tenureMonths'))).thenReturn(11500.0);

      await tester.pumpWidget(createSubject(loan));
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Enter new rate
      await tester.enterText(
          find.widgetWithText(TextField, 'New Annual Rate (%)'), '7.5');
      await tester.pump();

      // Tap Update
      await tester.tap(find.text('Update'));
      await tester.pumpAndSettle();

      // Verify logic
      verify(() => mockLoanService.calculateAccruedInterest(
            principal: 400000,
            annualRate: 8.5,
            fromDate: any(named: 'fromDate'),
            toDate: any(named: 'toDate'),
          )).called(1);

      verify(() => mockLoanService.calculateEMI(
            principal: 400000,
            annualRate: 7.5,
            tenureMonths: any(named: 'tenureMonths'),
          )).called(1);

      verify(() => mockStorageService.saveLoan(any())).called(1);
      expect(find.text('Update Interest Rate'), findsNothing); // Dialog closed
      expect(find.text('Rate updated and loan recalibrated.'), findsOneWidget);
    });

    testWidgets('updates rate and adjusts Tenure', (tester) async {
      final loan = Loan(
        id: 'L1',
        name: 'Car Loan',
        accountId: 'A1',
        totalPrincipal: 500000,
        remainingPrincipal: 400000,
        interestRate: 8.5,
        tenureMonths: 48,
        emiAmount: 12000,
        startDate: DateTime(2023, 1, 1),
        firstEmiDate: DateTime(2023, 2, 1),
        type: LoanType.car,
      );

      // Stubs
      when(() => mockLoanService.calculateAccruedInterest(
          principal: any(named: 'principal'),
          annualRate: any(named: 'annualRate'),
          fromDate: any(named: 'fromDate'),
          toDate: any(named: 'toDate'))).thenReturn(500.0);

      when(() => mockLoanService.calculateTenureForEMI(
          principal: any(named: 'principal'),
          annualRate: any(named: 'annualRate'),
          emi: any(named: 'emi'))).thenReturn(45);

      await tester.pumpWidget(createSubject(loan));
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Enter new rate
      await tester.enterText(
          find.widgetWithText(TextField, 'New Annual Rate (%)'), '7.5');
      await tester.pump();

      // Switch to Adjust Tenure
      await tester.tap(find.text('Adjust Tenure'));
      await tester.pumpAndSettle();

      // Tap Update
      await tester.tap(find.text('Update'));
      await tester.pumpAndSettle();

      // Verify logic
      verify(() => mockLoanService.calculateTenureForEMI(
            principal: 400000,
            annualRate: 7.5,
            emi: 12000,
          )).called(1);

      verify(() => mockStorageService.saveLoan(any())).called(1);
    });
    group('LoanUpdateRateDialog - User Input Validation', () {
      testWidgets('does not update if rate is null or <= 0', (tester) async {
        final loan = Loan(
          id: 'L1',
          name: 'Car Loan',
          accountId: 'A1',
          totalPrincipal: 500000,
          remainingPrincipal: 400000,
          interestRate: 8.5,
          tenureMonths: 48,
          emiAmount: 12000,
          startDate: DateTime(2023, 1, 1),
          firstEmiDate: DateTime(2023, 2, 1),
          type: LoanType.car,
        );

        await tester.pumpWidget(createSubject(loan));
        await tester.tap(find.text('Open Dialog'));
        await tester.pumpAndSettle();

        // Enter invalid rate
        await tester.enterText(
            find.widgetWithText(TextField, 'New Annual Rate (%)'), '-1');
        await tester.pump();
        await tester.tap(find.text('Update'));
        await tester.pumpAndSettle();

        // Verify saveLoan NOT called
        verifyNever(() => mockStorageService.saveLoan(any()));
        expect(find.text('Update Interest Rate'),
            findsOneWidget); // Dialog stays open

        // Enter empty rate
        await tester.enterText(
            find.widgetWithText(TextField, 'New Annual Rate (%)'), '');
        await tester.pump();
        await tester.tap(find.text('Update'));
        await tester.pumpAndSettle();

        verifyNever(() => mockStorageService.saveLoan(any()));
        expect(find.text('Update Interest Rate'), findsOneWidget);
      });
    });
  });
}
