import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samriddhi_flow/models/recurring_transaction.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/screens/recurring_manager_screen.dart';
import 'package:samriddhi_flow/feature_providers.dart';
import 'package:samriddhi_flow/services/calendar_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_mocks.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Recurring Manager - Render & Delete Interaction',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;

    final rule = RecurringTransaction(
        id: 'r1',
        title: 'Netflix',
        amount: 500,
        category: 'Entertainment',
        accountId: 'a1',
        profileId: 'default',
        frequency: Frequency.monthly,
        scheduleType: ScheduleType.fixedDate,
        nextExecutionDate: DateTime.now().add(const Duration(days: 5)),
        selectedWeekday: 1,
        adjustForHolidays: false);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storageServiceProvider.overrideWith((ref) => MockStorageService()),
          storageInitializerProvider.overrideWith((ref) => Future.value()),
          recurringTransactionsProvider
              .overrideWith((ref) => Stream.value([rule])),
          calendarServiceProvider.overrideWith((ref) => MockCalendarService()),
        ],
        child: const MaterialApp(
          home: RecurringManagerScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Title
    expect(find.text('Netflix'), findsOneWidget);

    // Verify Delete Button (Icon)
    final deleteButton = find.byIcon(Icons.delete_outline);
    expect(deleteButton, findsOneWidget);

    // Tap Delete
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();

    // Verify Dialog
    expect(find.text('Delete recurring rule?'), findsOneWidget);
    // Cancel
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });
}

class MockCalendarService extends CalendarService {
  MockCalendarService() : super(MockFileService());

  @override
  Future<void> downloadRecurringEvent(
      {required String title,
      required String description,
      required DateTime startDate,
      required int occurrences,
      int? dayOfMonth}) async {}
}
