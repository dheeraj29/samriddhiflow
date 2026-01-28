import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:samriddhi_flow/feature_providers.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/screens/transactions_screen.dart';
import 'package:samriddhi_flow/services/excel_service.dart';

import 'test_mocks.dart';

// We might need a dummy ExcelService since TransactionsScreen uses it for export
class MockExcelService extends Mock implements ExcelService {}

void main() {
  testWidgets('TransactionsScreen smoke test', (tester) async {
    final mockStorage = MockStorageService();
    final mockExcel = MockExcelService();

    await tester.pumpWidget(ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(mockStorage),
        storageInitializerProvider.overrideWith((ref) => Future.value()),
        excelServiceProvider.overrideWithValue(mockExcel),
      ],
      child: const MaterialApp(
        home: TransactionsScreen(),
      ),
    ));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    if (find.byType(ErrorWidget).evaluate().isNotEmpty) {
      final error = tester.widget<ErrorWidget>(find.byType(ErrorWidget));
      print('TRANSACTIONS ERROR: ${error.message}');
    }

    // Only verifying it builds and shows title
    expect(find.text('All Transactions'), findsOneWidget);
  });
}
