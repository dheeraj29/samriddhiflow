import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/feature_providers.dart';
import 'package:samriddhi_flow/screens/recurring_manager_screen.dart';
import 'package:samriddhi_flow/models/recurring_transaction.dart';
import 'package:samriddhi_flow/services/storage_service.dart';
import 'package:samriddhi_flow/services/calendar_service.dart';

class MockStorageService extends Mock implements StorageService {}

class MockCalendarService extends Mock implements CalendarService {}

class MockCurrencyNotifier extends CurrencyNotifier {
  @override
  String build() => 'en_US';
}

void main() {
  late MockStorageService mockStorageService;
  late MockCalendarService mockCalendarService;

  setUp(() {
    mockStorageService = MockStorageService();
    mockCalendarService = MockCalendarService();
  });

  Widget createWidgetUnderTest({List<RecurringTransaction> rules = const []}) {
    return ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(mockStorageService),
        calendarServiceProvider.overrideWithValue(mockCalendarService),
        recurringTransactionsProvider
            .overrideWith((ref) => Stream.value(rules)),
        currencyProvider.overrideWith(MockCurrencyNotifier.new),
      ],
      child: const MaterialApp(
        home: RecurringManagerScreen(),
      ),
    );
  }

  testWidgets('RecurringManagerScreen renders list of rules', (tester) async {
    final rules = [
      RecurringTransaction(
        id: '1',
        title: 'Rent',
        amount: 1000,
        category: 'Housing',
        frequency: Frequency.monthly,
        scheduleType: ScheduleType.fixedDate,
        nextExecutionDate: DateTime(2025, 2, 1),
      ),
    ];

    await tester.pumpWidget(createWidgetUnderTest(rules: rules));
    await tester.pumpAndSettle();

    expect(find.text('Rent'), findsOneWidget);
    expect(find.textContaining('Housing'), findsOneWidget);
    expect(find.textContaining('MONTHLY'), findsOneWidget);
  });

  testWidgets('RecurringManagerScreen shows edit dialog', (tester) async {
    final rules = [
      RecurringTransaction(
        id: '1',
        title: 'Rent',
        amount: 1000,
        category: 'Housing',
        frequency: Frequency.monthly,
        scheduleType: ScheduleType.fixedDate,
        nextExecutionDate: DateTime(2025, 2, 1),
      ),
    ];

    await tester.pumpWidget(createWidgetUnderTest(rules: rules));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Edit Recurring Amount'), findsOneWidget);
    expect(find.text('1000.00'), findsOneWidget);
  });

  testWidgets('RecurringManagerScreen confirms delete', (tester) async {
    final rules = [
      RecurringTransaction(
        id: '1',
        title: 'Rent',
        amount: 1000,
        category: 'Housing',
        frequency: Frequency.monthly,
        scheduleType: ScheduleType.fixedDate,
        nextExecutionDate: DateTime(2025, 2, 1),
      ),
    ];

    await tester.pumpWidget(createWidgetUnderTest(rules: rules));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.text('Delete recurring rule?'), findsOneWidget);

    when(() => mockStorageService.deleteRecurringTransaction('1'))
        .thenAnswer((_) async {});

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    verify(() => mockStorageService.deleteRecurringTransaction('1')).called(1);
  });
}
