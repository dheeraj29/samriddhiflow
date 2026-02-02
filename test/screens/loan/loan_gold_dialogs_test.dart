import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/models/account.dart';
import 'package:samriddhi_flow/models/loan.dart';
import 'package:samriddhi_flow/models/transaction.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/screens/loan/loan_gold_dialogs.dart';
import 'package:samriddhi_flow/services/storage_service.dart';

// Mocks
class MockStorageService extends Mock implements StorageService {}

class MockAccount extends Mock implements Account {}

class MockLoan extends Mock implements Loan {}

class FakeLoan extends Fake implements Loan {}

class FakeAccount extends Fake implements Account {}

class FakeTransaction extends Fake implements Transaction {}

void main() {
  late MockStorageService mockStorageService;
  late MockLoan mockLoan;
  late MockAccount mockAccount;

  setUpAll(() {
    registerFallbackValue(FakeLoan());
    registerFallbackValue(FakeAccount());
    registerFallbackValue(FakeTransaction());
    registerFallbackValue(Transaction.create(
      title: 'fallback',
      amount: 10.0,
      type: TransactionType.expense,
      category: 'fallback',
      accountId: 'id',
      date: DateTime.now(),
      loanId: 'lid',
    ));
    registerFallbackValue(Account.create(
      name: 'fallback',
      type: AccountType.savings,
      initialBalance: 0,
      currency: 'INR',
    )); // Fallback for Account
    // Need a concrete fallback for Loan if saveLoan is called with specific object
    // Or just use any()
  });

  setUp(() {
    mockStorageService = MockStorageService();
    mockLoan = MockLoan();
    mockAccount = MockAccount();

    // Stub Loan properties
    when(() => mockLoan.id).thenReturn('loan_1');
    when(() => mockLoan.name).thenReturn('Gold Loan 1');
    when(() => mockLoan.accountId).thenReturn('acc_1');
    when(() => mockLoan.remainingPrincipal).thenReturn(10000.0);
    when(() => mockLoan.transactions).thenReturn([]);
    // Setter stubbing for transactions (Assignment returns the value, which is List<LoanTransaction>)
    when(() => mockLoan.transactions = any()).thenAnswer((invocation) {
      return invocation.positionalArguments.first as List<LoanTransaction>;
    });
    // Setter stubbing for remainingPrincipal
    when(() => mockLoan.remainingPrincipal = any()).thenAnswer((invocation) {
      return invocation.positionalArguments.first as double;
    });

    // Stub Account properties
    when(() => mockAccount.id).thenReturn('acc_1');
    when(() => mockAccount.name).thenReturn('SBI');
    // Stub balance
    when(() => mockAccount.balance).thenReturn(50000.0);
    when(() => mockAccount.balance = any()).thenAnswer((invocation) {
      return invocation.positionalArguments.first as double;
    });

    // Stub StorageService
    when(() => mockStorageService.saveLoan(any())).thenAnswer((_) async {});
    when(() => mockStorageService.saveAccount(any())).thenAnswer((_) async {});
    when(() => mockStorageService.saveTransaction(any()))
        .thenAnswer((_) async {});
  });

  testWidgets('GoldLoanInterestPaymentDialog Renders and Submits',
      (tester) async {
    const accruedInterest = 500.0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(mockStorageService),
          accountsProvider.overrideWithValue(AsyncValue.data([mockAccount])),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: GoldLoanInterestPaymentDialog(
              loan: mockLoan,
              accruedInterest: accruedInterest,
            ),
          ),
        ),
      ),
    );

    await tester.pump(); // Ensure provider settles?

    // Verify Title and content
    expect(find.text('Pay Interest & Renew'), findsOneWidget);
    expect(find.text('500.00'), findsOneWidget); // Initial amount

    // Tap Pay
    await tester.tap(find.text('Pay & Renew'));
    await tester.pumpAndSettle(); // Dialog animation

    // Verify Storage interactions
    verify(() => mockStorageService.saveLoan(any())).called(1);
    verify(() => mockStorageService.saveAccount(any())).called(1);
    verify(() => mockStorageService.saveTransaction(any())).called(1);
  });

  testWidgets('GoldLoanCloseDialog Renders and Submits', (tester) async {
    const accruedInterest = 200.0;
    // Total due = 10000 + 200 = 10200

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(mockStorageService),
          accountsProvider.overrideWithValue(AsyncValue.data([mockAccount])),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: GoldLoanCloseDialog(
              loan: mockLoan,
              accruedInterest: accruedInterest,
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    // Verify Title
    expect(find.text('Close Gold Loan'), findsOneWidget);

    // Tap Close
    await tester.tap(find.text('Close Loan'));
    await tester.pumpAndSettle();

    // Verify logic
    verify(() => mockLoan.remainingPrincipal = 0).called(1);

    verify(() => mockStorageService.saveLoan(any())).called(1);
  });
}
