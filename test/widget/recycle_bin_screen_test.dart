import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/screens/recycle_bin_screen.dart';
import 'package:samriddhi_flow/services/storage_service.dart';

import 'test_mocks.dart';

void main() {
  testWidgets('RecycleBinScreen smoke test', (tester) async {
    final mockStorage = MockStorageService();
    // Assuming delete transactions are stored; if getAllDeleted isn't mocked, create it if needed
    // or checks deleted flag on normal transactions.
    // Assuming getTransactions(includeDeleted: true) is used.

    await tester.pumpWidget(ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(mockStorage),
        storageInitializerProvider.overrideWith((ref) => Future.value()),
      ],
      child: const MaterialApp(
        home: RecycleBinScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    if (find.byType(ErrorWidget).evaluate().isNotEmpty) {
      final error = tester.widget<ErrorWidget>(find.byType(ErrorWidget));
      print('ERROR WIDGET FOUND: ${error.message}');
    }

    expect(find.text('Recycle Bin'), findsOneWidget);
  });
}
