import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/screens/reminders_screen.dart';
import 'package:samriddhi_flow/services/storage_service.dart';

import 'test_mocks.dart';

void main() {
  testWidgets('RemindersScreen smoke test', (tester) async {
    final mockStorage = MockStorageService();

    await tester.pumpWidget(ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(mockStorage),
        storageInitializerProvider.overrideWith((ref) => Future.value()),
      ],
      child: const MaterialApp(
        home: RemindersScreen(),
      ),
    ));
    // Use manual pumps to avoid potential timeouts with indeterminate loaders
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.text('Reminders & Notifications'), findsOneWidget);
  });
}
