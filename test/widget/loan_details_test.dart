import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samriddhi_flow/models/account.dart';
import 'package:samriddhi_flow/models/loan.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/screens/loan_details_screen.dart';
import 'package:samriddhi_flow/services/loan_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_mocks.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Loan Details - Render & Pay Interaction',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;

    final loan = Loan(
      id: 'l1',
      name: 'Car Loan',
      totalPrincipal: 100000,
      remainingPrincipal: 90000,
      interestRate: 10,
      startDate: DateTime.now().subtract(const Duration(days: 30)),
      tenureMonths: 24,
      emiAmount: 5000,
      accountId: 'a1',
      type: LoanType.personal, // Standard loan
      firstEmiDate: DateTime.now(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountsProvider.overrideWith((ref) => Stream.value([
                Account(
                    id: 'a1',
                    name: 'Bank',
                    type: AccountType.savings,
                    balance: 50000)
              ])),
          storageServiceProvider.overrideWith((ref) => MockStorageService()),
          storageInitializerProvider.overrideWith((ref) => Future.value()),
          loanServiceProvider.overrideWith((ref) => LoanService()),
          loansProvider.overrideWith((ref) => Stream.value([loan])),
          transactionsProvider.overrideWith((ref) => Stream.value([])),
        ],
        child: MaterialApp(
          home: LoanDetailsScreen(loan: loan),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Title
    expect(find.text('Car Loan'), findsOneWidget);

    // Verify Outstanding Principal (90000 formatted as 90K)
    expect(find.textContaining('90K'), findsOneWidget);

    // Find "Pay" button
    final payButton = find.text('Pay');
    expect(payButton, findsOneWidget);

    // Tap Pay
    await tester.tap(payButton);
    await tester.pumpAndSettle();

    // Verify Payment Dialog
    expect(find.text('Record Loan Payment'), findsOneWidget);
    // Cancel dialog
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets('Loan Details - Bulk Pay Button', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;

    final loan = Loan(
      id: 'l1',
      name: 'Home Loan',
      totalPrincipal: 500000,
      remainingPrincipal: 400000,
      interestRate: 8,
      startDate: DateTime.now().subtract(const Duration(days: 60)),
      tenureMonths: 60,
      emiAmount: 10000,
      accountId: 'a1',
      type: LoanType.home,
      firstEmiDate: DateTime.now(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountsProvider.overrideWith((ref) => Stream.value([])),
          storageServiceProvider.overrideWith((ref) => MockStorageService()),
          storageInitializerProvider.overrideWith((ref) => Future.value()),
          loanServiceProvider.overrideWith((ref) => LoanService()),
          loansProvider.overrideWith((ref) => Stream.value([loan])),
          transactionsProvider.overrideWith((ref) => Stream.value([])),
        ],
        child: MaterialApp(
          home: LoanDetailsScreen(loan: loan),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Bulk Pay button exists
    expect(find.text('Bulk Pay'), findsOneWidget);
  });
}
