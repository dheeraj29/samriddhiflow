import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/screens/holiday_manager_screen.dart';
import 'package:samriddhi_flow/services/storage_service.dart';

import 'test_mocks.dart';

class MockHolidaysNotifier extends Notifier<List<DateTime>>
    implements HolidaysNotifier {
  @override
  List<DateTime> build() => [];

  @override
  Future<void> addHoliday(DateTime date) async {}

  @override
  Future<void> removeHoliday(DateTime date) async {}
}

void main() {
  testWidgets('HolidayManagerScreen smoke test', (tester) async {
    final mockStorage = MockStorageService();

    await tester.pumpWidget(ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(mockStorage),
        storageInitializerProvider.overrideWith((ref) => Future.value()),
        holidaysProvider.overrideWith(MockHolidaysNotifier.new),
      ],
      child: const MaterialApp(
        home: HolidayManagerScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    if (find.byType(ErrorWidget).evaluate().isNotEmpty) {
      final error = tester.widget<ErrorWidget>(find.byType(ErrorWidget));
      print('HOLIDAY ERROR: ${error.message}');
    }

    expect(find.text('Holiday Manager'), findsOneWidget);
  });
}
