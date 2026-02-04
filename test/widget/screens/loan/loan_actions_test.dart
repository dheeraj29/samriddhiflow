import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/models/account.dart';
import 'package:samriddhi_flow/models/loan.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/screens/loan/loan_topup_dialog.dart';
import 'package:samriddhi_flow/screens/loan/loan_part_payment_dialog.dart';
import 'package:samriddhi_flow/screens/loan/loan_recalculate_dialog.dart';
import 'package:samriddhi_flow/services/loan_service.dart';
import 'package:samriddhi_flow/services/storage_service.dart';

import 'package:samriddhi_flow/models/transaction.dart';

// Mocks
class MockStorageService extends Mock implements StorageService {}

class MockLoanService extends Mock implements LoanService {}

// Fake Currency Notifier
class FakeCurrencyNotifier extends CurrencyNotifier {
  @override
  String build() => 'en_US';
}

// Fake Loan (if needed, but we can use real one)
class FakeLoan extends Fake implements Loan {}

// Fake Transaction
class FakeTransaction extends Fake implements Transaction {}

void main() {
  late MockStorageService mockStorage;
  late MockLoanService mockLoanService;
  late Loan testLoan;
  late List<Account> testAccounts;

  setUpAll(() {
    registerFallbackValue(FakeLoan());
    registerFallbackValue(FakeTransaction());
    registerFallbackValue(
        Account(id: 'fb', name: 'FB', type: AccountType.wallet));
    registerFallbackValue(Loan(
        id: 'fallback',
        name: 'FB',
        totalPrincipal: 0,
        remainingPrincipal: 0,
        interestRate: 0,
        tenureMonths: 0,
        startDate: DateTime.now(),
        firstEmiDate: DateTime.now(),
        emiAmount: 0));
  });

  setUp(() {
    mockStorage = MockStorageService();
    mockLoanService = MockLoanService();

    testLoan = Loan(
      id: 'l1',
      name: 'Test Loan',
      totalPrincipal: 100000,
      remainingPrincipal: 80000,
      interestRate: 10,
      tenureMonths: 60,
      emiAmount: 2000,
      startDate: DateTime(2023, 1, 1),
      firstEmiDate: DateTime(2023, 2, 1),
      transactions: [],
      accountId: 'a1',
    );

    testAccounts = [
      Account(
          id: 'a1',
          name: 'Savings',
          balance: 50000,
          type: AccountType.savings,
          profileId: 'default')
    ];

    // Default Storage answers
    when(() => mockStorage.saveLoan(any())).thenAnswer((_) async {});
    when(() => mockStorage.saveAccount(any())).thenAnswer((_) async {});
    when(() => mockStorage.saveTransaction(any())).thenAnswer((_) async {});

    // Default LoanService answers
    when(() => mockLoanService.calculateAccruedInterest(
        principal: any(named: 'principal'),
        annualRate: any(named: 'annualRate'),
        fromDate: any(named: 'fromDate'),
        toDate: any(named: 'toDate'))).thenReturn(50.0);

    when(() => mockLoanService.calculateEMI(
        principal: any(named: 'principal'),
        annualRate: any(named: 'annualRate'),
        tenureMonths: any(named: 'tenureMonths'))).thenReturn(2500.0);

    when(() => mockLoanService.calculateTenureForEMI(
        principal: any(named: 'principal'),
        annualRate: any(named: 'annualRate'),
        emi: any(named: 'emi'))).thenReturn(70);
  });

  Widget createTestWidget(Widget child) {
    return ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(mockStorage),
        loanServiceProvider.overrideWithValue(mockLoanService),
        currencyProvider.overrideWith(FakeCurrencyNotifier.new),
        accountsProvider.overrideWith((ref) => Stream.value(testAccounts)),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    );
  }

  group('Loan Topup Dialog', () {
    testWidgets('Renders and submits topup', (tester) async {
      await tester
          .pumpWidget(createTestWidget(LoanTopupDialog(loan: testLoan)));
      await tester.pumpAndSettle();

      expect(find.text('Loan Top-up'), findsOneWidget);
      expect(find.text('Borrow more money on this loan.'), findsOneWidget);

      // Enter Amount
      await tester.enterText(find.byType(TextField).first, '10000');
      await tester.pumpAndSettle();

      // Tap Borrow
      await tester.tap(find.text('Borrow'));
      await tester.pumpAndSettle();

      // Verification
      // 1. Accrue Interest called
      verify(() => mockLoanService.calculateAccruedInterest(
          principal: 80000,
          annualRate: 10,
          fromDate: any(named: 'fromDate'),
          toDate: any(named: 'toDate'))).called(1);

      // 2. Save Loan called
      verify(() => mockStorage.saveLoan(any())).called(1);

      // 3. Save Account (Income) called
      verify(() => mockStorage.saveAccount(any())).called(1);
    });
  });

  group('Loan Part Payment Dialog', () {
    testWidgets('Renders and submits payment', (tester) async {
      await tester
          .pumpWidget(createTestWidget(LoanPartPaymentDialog(loan: testLoan)));
      await tester.pumpAndSettle();

      expect(find.text('Part Principal Payment'), findsOneWidget);

      // Enter Amount
      await tester.enterText(find.byType(TextField).first, '5000');
      await tester.pumpAndSettle();

      // Tap Pay
      await tester.tap(find.text('Pay Principal'));
      await tester.pumpAndSettle();

      verify(() => mockStorage.saveLoan(any())).called(1);
      verify(() => mockStorage.saveAccount(any()))
          .called(1); // Expense recorded
    });
  });

  group('Loan Recalculate Dialog', () {
    testWidgets('Renders and submits EMI update', (tester) async {
      await tester
          .pumpWidget(createTestWidget(LoanRecalculateDialog(loan: testLoan)));
      await tester.pumpAndSettle();

      expect(find.text('Recalculate Loan'), findsOneWidget);

      // Change EMI (TextField index 0 is EMI from logic reading)
      // wait, build has: Text(Outstanding), SizedBox, TextField(EMI)...
      // Let's find by label "New EMI Amount"
      final emiField = find.widgetWithText(TextField, 'New EMI Amount');
      await tester.enterText(emiField, '3000');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Update'));
      await tester.pumpAndSettle();

      // Verify logic: calculateTenure should be called
      verify(() => mockLoanService.calculateTenureForEMI(
          principal: 80000, annualRate: 10, emi: 3000)).called(1);

      verify(() => mockStorage.saveLoan(any())).called(1);
    });
  });
}
