import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/screens/add_loan_screen.dart';
import 'package:samriddhi_flow/services/storage_service.dart';

import 'test_mocks.dart';

void main() {
  testWidgets('AddLoanScreen smoke test', (tester) async {
    final mockStorage = MockStorageService();

    await tester.pumpWidget(ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(mockStorage),
        storageInitializerProvider.overrideWith((ref) => Future.value()),
      ],
      child: const MaterialApp(
        home: AddLoanScreen(),
      ),
    ));

    await tester.pumpAndSettle();

    if (find.byType(ErrorWidget).evaluate().isNotEmpty) {
      final error = tester.widget<ErrorWidget>(find.byType(ErrorWidget));
      print('ADD LOAN ERROR: ${error.message}');
    }

    expect(find.text('Add Loan'), findsOneWidget);
    // Label is 'Interest Rate (Annual)'
    expect(find.text('Interest Rate (Annual)'), findsOneWidget);
  });
}
