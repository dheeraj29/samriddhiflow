import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/models/loan.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/screens/loan/loan_rename_dialog.dart';
import '../test_mocks.dart';

void main() {
  late MockStorageService mockStorage;

  setUp(() {
    mockStorage = MockStorageService();
    setupStorageDefaults(mockStorage);
  });

  testWidgets('LoanRenameDialog renames loan', (tester) async {
    final loan = Loan(
      id: 'l1',
      name: 'Old Name',
      totalPrincipal: 1000,
      remainingPrincipal: 1000,
      interestRate: 10,
      tenureMonths: 12,
      startDate: DateTime.now(),
      emiAmount: 100,
      firstEmiDate: DateTime.now(),
      accountId: 'a1',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWithValue(mockStorage),
        ],
        child: MaterialApp(
          home: LoanRenameDialog(loan: loan),
        ),
      ),
    );

    expect(find.text('Rename Loan'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'New Name');

    when(() => mockStorage.saveLoan(any())).thenAnswer((_) async {});
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final captured =
        verify(() => mockStorage.saveLoan(captureAny())).captured.first as Loan;
    expect(captured.name, 'New Name');
  });
}
