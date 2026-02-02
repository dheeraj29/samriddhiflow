import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:samriddhi_flow/models/loan.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/screens/loan/loan_ledger_view.dart';
import 'package:samriddhi_flow/services/storage_service.dart';

// Mocks
class MockStorageService extends Mock implements StorageService {}

// Fake Notifier
class FakeCurrencyNotifier extends CurrencyNotifier {
  @override
  String build() => 'en_IN';
}

// Fake Loan
class FakeLoan extends Fake implements Loan {}

void main() {
  late MockStorageService mockStorage;

  setUpAll(() {
    registerFallbackValue(FakeLoan());
  });

  setUp(() {
    mockStorage = MockStorageService();
    when(() => mockStorage.saveLoan(any())).thenAnswer((_) async {});
  });

  testWidgets('LoanLedgerView Renders and Filters', (tester) async {
    final txns = [
      LoanTransaction(
          id: 't1',
          date: DateTime(2024, 1, 1),
          amount: 1000,
          type: LoanTransactionType.emi,
          principalComponent: 800,
          interestComponent: 200,
          resultantPrincipal: 9200),
      LoanTransaction(
          id: 't2',
          date: DateTime(2024, 2, 1),
          amount: 500,
          type: LoanTransactionType.prepayment,
          principalComponent: 500,
          interestComponent: 0,
          resultantPrincipal: 8700)
    ];

    final loan = Loan(
        id: 'l1',
        name: 'Test Loan',
        type: LoanType.personal,
        totalPrincipal: 10000,
        remainingPrincipal: 8700,
        interestRate: 10,
        tenureMonths: 12,
        emiAmount: 1000,
        emiDay: 5,
        startDate: DateTime(2024, 1, 1),
        firstEmiDate: DateTime(2024, 2, 5),
        transactions: txns);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(mockStorage),
          currencyProvider.overrideWith(FakeCurrencyNotifier.new)
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: LoanLedgerView(loan: loan)),
          ),
        ),
      ),
    );

    // Verify Render
    expect(find.text('Loan Ledger'), findsOneWidget);
    expect(find.text('EMI Payment'), findsOneWidget);
    expect(find.text('Prepayment'), findsOneWidget);

    // Test Compact Mode
    // Default is extended? Code: _compactLedger = false.
    // Button icon: Icons.format_align_center.
    await tester.tap(find.byIcon(Icons.format_align_center));
    await tester.pump();
    // Verify icon changed (not easily verified unless we check Icon data)

    // Test Type Filter
    await tester.tap(find.byIcon(Icons.filter_list));
    await tester.pumpAndSettle();

    // Select Prepayment
    await tester.tap(find.text('PREPAYMENT'));
    await tester.pumpAndSettle();

    // Verify Filtering
    expect(find.text('Prepayment'), findsOneWidget);
    expect(find.text('EMI Payment'), findsNothing);

    // Clear Filter
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text('EMI Payment'), findsOneWidget);
  });

  testWidgets('LoanLedgerView Deletion Interaction', (tester) async {
    final txn = LoanTransaction(
        id: 't1',
        date: DateTime(2024, 1, 1),
        amount: 1000,
        type: LoanTransactionType.emi,
        principalComponent: 800,
        interestComponent: 200,
        resultantPrincipal: 9200);

    final loan = Loan(
        id: 'l1',
        name: 'Test Loan',
        type: LoanType.personal,
        totalPrincipal: 10000,
        remainingPrincipal: 9200, // Matches txn end state
        interestRate: 10,
        tenureMonths: 12,
        emiAmount: 1000,
        emiDay: 5,
        startDate: DateTime(2024, 1, 1),
        firstEmiDate: DateTime(2024, 1, 5),
        transactions: [txn].toList() // Mutable list
        );

    // We need to register fallback for saveLoan
    registerFallbackValue(loan);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(mockStorage),
          currencyProvider.overrideWith(FakeCurrencyNotifier.new)
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: LoanLedgerView(loan: loan)),
          ),
        ),
      ),
    );

    // Open Menu
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();

    // Tap Delete
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    // Verify Dialog
    expect(find.text('Delete Entry?'), findsOneWidget);

    // Confirm
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    // Verify Logic
    // 1. Storage saveLoan called
    verify(() => mockStorage.saveLoan(any())).called(1);
    // 2. Loan object mutated (Remaining Principal should increase by prin component 800)
    // 9200 + 800 = 10000?
    // Logic: remainingPrincipal += txn.principalComponent.
    // 9200 + 800 = 10000.
    expect(loan.remainingPrincipal, 10000.0);
    expect(loan.transactions, isEmpty);
  });
}
