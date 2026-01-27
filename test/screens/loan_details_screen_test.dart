import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/screens/loan_details_screen.dart';
import 'package:samriddhi_flow/models/loan.dart';
import 'package:samriddhi_flow/models/account.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/models/category.dart';
import 'package:samriddhi_flow/services/storage_service.dart';

class MockStorageService extends Mock implements StorageService {}

class FakeCategoriesNotifier extends CategoriesNotifier {
  @override
  List<Category> build() => [];
}

void main() {
  late MockStorageService mockStorageService;
  late Loan testLoan;
  late List<Account> testAccounts;

  setUpAll(() {
    registerFallbackValue(Loan(
      id: 'fallback',
      name: 'Fallback',
      totalPrincipal: 0,
      remainingPrincipal: 0,
      interestRate: 0,
      tenureMonths: 0,
      startDate: DateTime.now(),
      firstEmiDate: DateTime.now(),
      emiAmount: 0,
    ));
  });

  setUp(() {
    mockStorageService = MockStorageService();
    testLoan = Loan(
      id: 'l1',
      name: 'Home Loan',
      totalPrincipal: 5000000,
      remainingPrincipal: 5000000,
      interestRate: 8.5,
      tenureMonths: 240,
      startDate: DateTime(2023, 1, 1),
      firstEmiDate: DateTime(2023, 2, 1),
      emiAmount: 43391,
      profileId: 'default',
    );
    testAccounts = [
      Account(
          id: 'a1',
          name: 'Savings',
          balance: 100000,
          profileId: 'default',
          type: AccountType.savings),
    ];

    // Default mocks
    when(() => mockStorageService.getAccounts()).thenReturn(testAccounts);
    when(() => mockStorageService.getTransactions()).thenReturn([]);
    when(() => mockStorageService.getLoans()).thenReturn([testLoan]);
    when(() => mockStorageService.getActiveProfileId()).thenReturn('default');
    when(() => mockStorageService.init()).thenAnswer((_) async => {});
    when(() => mockStorageService.getCurrencyLocale()).thenReturn('en_IN');
  });

  Widget createTestWidget() {
    return ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(mockStorageService),
        storageInitializerProvider.overrideWith((ref) => Future.value()),
        loansProvider.overrideWith((ref) => Stream.value([testLoan])),
        accountsProvider.overrideWith((ref) => Stream.value(testAccounts)),
        categoriesProvider.overrideWith(() => FakeCategoriesNotifier()),
        transactionsProvider.overrideWith((ref) => Stream.value([])),
      ],
      child: MaterialApp(
        home: LoanDetailsScreen(loan: testLoan),
      ),
    );
  }

  testWidgets('LoanDetailsScreen renders basic information', (tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('Home Loan'), findsOneWidget);
    // Smart format for 5,000,000 in en_IN is ₹50L
    expect(find.textContaining('50L'), findsOneWidget);
  });

  testWidgets('Pay dialog opens', (tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Find and tap the Pay button (it's an InkWell with Text)
    final payButton = find.text('Pay');
    expect(payButton, findsOneWidget);
    await tester.tap(payButton);
    await tester.pumpAndSettle();

    expect(find.text('Record Loan Payment'), findsOneWidget);
  });

  testWidgets('Switch to Simulator and update prepayment', (tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Tap Simulator in Nav row
    await tester.tap(find.text('Simulator'));
    await tester.pumpAndSettle();

    expect(find.text('Extra Payment Amount'), findsOneWidget);

    // Enter prepayment amount
    await tester.enterText(find.byType(TextFormField).first, '100000');
    await tester.pumpAndSettle();

    expect(find.text('Interest Saved'), findsOneWidget);
  });

  testWidgets('Switch to Ledger view', (tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Tap Ledger in Nav row
    final ledgerNav = find.widgetWithText(InkWell, 'Ledger');
    await tester.tap(ledgerNav);
    await tester.pumpAndSettle();

    expect(find.text('Loan Ledger'), findsOneWidget);
    expect(find.text('No transactions match the filters.'), findsOneWidget);
  });

  testWidgets('Dialog actions: Top-up, Rename, Delete', (tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Top-up
    await tester.tap(find.byTooltip('Top-up Loan'));
    await tester.pumpAndSettle();
    expect(find.text('Loan Top-up'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Rename
    await tester.tap(find.byTooltip('Rename Loan'));
    await tester.pumpAndSettle();
    expect(find.text('Rename Loan'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Delete
    await tester.tap(find.byTooltip('Delete Loan'));
    await tester.pumpAndSettle();
    expect(find.text('Delete Loan?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });
}
