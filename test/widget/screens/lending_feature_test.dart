import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samriddhi_flow/screens/lending/lending_dashboard_screen.dart';
import 'package:samriddhi_flow/screens/lending/add_lending_screen.dart';
import 'package:samriddhi_flow/models/lending_record.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/services/storage_service.dart';

class MockStorageService extends Mock implements StorageService {}

void main() {
  late MockStorageService mockStorage;

  setUpAll(() {
    registerFallbackValue(LendingRecord(
      id: 'f',
      personName: 'f',
      amount: 0,
      reason: 'f',
      date: DateTime.now(),
      type: LendingType.lent,
    ));
  });

  setUp(() {
    mockStorage = MockStorageService();

    // Default stubs
    when(() => mockStorage.getLendingRecords()).thenReturn([]);
    when(() => mockStorage.getActiveProfileId()).thenReturn('default');
    when(() => mockStorage.getCurrencyLocale()).thenReturn('en_IN');
    // For the provider's watch(storageInitializerProvider)
    // storageInitializerProvider is a FutureProvider
  });

  Widget createTestWidget(Widget child) {
    return ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(mockStorage),
        storageInitializerProvider
            .overrideWith((ref) => const AsyncValue.data(true)),
      ],
      child: MaterialApp(
        home: child,
      ),
    );
  }

  group('LendingDashboardScreen', () {
    testWidgets('shows empty state when no records', (tester) async {
      await tester.pumpWidget(createTestWidget(const LendingDashboardScreen()));
      await tester.pumpAndSettle();

      expect(find.text('No records found.'), findsOneWidget);
    });

    testWidgets('shows list of records and summary cards', (tester) async {
      final records = [
        LendingRecord(
          id: '1',
          personName: 'Alice',
          amount: 1000,
          reason: 'Lunch',
          date: DateTime.now(),
          type: LendingType.lent,
        ),
        LendingRecord(
          id: '2',
          personName: 'Bob',
          amount: 500,
          reason: 'Ticket',
          date: DateTime.now(),
          type: LendingType.borrowed,
        ),
      ];

      when(() => mockStorage.getLendingRecords()).thenReturn(records);

      await tester.pumpWidget(createTestWidget(const LendingDashboardScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.textContaining('Lunch'), findsOneWidget);

      // Check summary cards and list items
      expect(find.textContaining('1,000'), findsNWidgets(2)); // Summary + List
      expect(find.textContaining('500'), findsNWidgets(2)); // Summary + List
    });

    testWidgets('opening settlement dialog', (tester) async {
      final record = LendingRecord(
        id: '1',
        personName: 'Alice',
        amount: 1000,
        reason: 'Lunch',
        date: DateTime.now(),
        type: LendingType.lent,
      );

      when(() => mockStorage.getLendingRecords()).thenReturn([record]);
      when(() => mockStorage.saveLendingRecord(any())).thenAnswer((_) async {});

      await tester.pumpWidget(createTestWidget(const LendingDashboardScreen()));
      await tester.pumpAndSettle();

      // Open popup menu
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      // Tap Settle
      await tester.tap(find.text('Settle'));
      await tester.pumpAndSettle();

      expect(find.text('Mark as Settled?'), findsOneWidget);

      await tester.tap(find.text('Yes, Settle'));
      await tester.pumpAndSettle();

      verify(() => mockStorage.saveLendingRecord(any())).called(1);
    });
  });

  group('AddLendingScreen', () {
    testWidgets('validates required fields', (tester) async {
      await tester.pumpWidget(createTestWidget(const AddLendingScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add Record'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a name'), findsOneWidget);
      expect(find.text('Enter amount'), findsOneWidget);
    });

    testWidgets('saves new record successfully', (tester) async {
      when(() => mockStorage.saveLendingRecord(any())).thenAnswer((_) async {});

      await tester.pumpWidget(createTestWidget(const AddLendingScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Person Name'), 'Charlie');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Amount'), '200');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Reason / Description'), 'Coffee');

      await tester.tap(find.text('Add Record'));
      await tester.pumpAndSettle();

      verify(() => mockStorage.saveLendingRecord(any())).called(1);
      expect(find.byType(AddLendingScreen), findsNothing); // Popped
    });

    testWidgets('edits existing record', (tester) async {
      final record = LendingRecord(
        id: '1',
        personName: 'Alice',
        amount: 1000,
        reason: 'Lunch',
        date: DateTime.now(),
        type: LendingType.lent,
      );

      when(() => mockStorage.saveLendingRecord(any())).thenAnswer((_) async {});

      await tester
          .pumpWidget(createTestWidget(AddLendingScreen(recordToEdit: record)));
      await tester.pumpAndSettle();

      expect(find.text('Alice'), findsOneWidget);
      expect(
          tester
              .widget<TextFormField>(
                  find.widgetWithText(TextFormField, 'Amount'))
              .controller
              ?.text,
          '1000');

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Amount'), '1200');
      await tester.tap(find.text('Edit Record'));
      await tester.pumpAndSettle();

      final captured = verify(() => mockStorage.saveLendingRecord(captureAny()))
          .captured
          .first as LendingRecord;
      expect(captured.amount, 1200);
      expect(captured.id, '1');
    });
    group('Lending Flows', () {
      testWidgets('swipe to delete', (tester) async {
        final record = LendingRecord(
          id: '1',
          personName: 'Alice',
          amount: 1000,
          reason: 'Lunch',
          date: DateTime.now(),
          type: LendingType.lent,
        );

        when(() => mockStorage.getLendingRecords()).thenReturn([record]);
        when(() => mockStorage.deleteLendingRecord('1'))
            .thenAnswer((_) async {});

        await tester
            .pumpWidget(createTestWidget(const LendingDashboardScreen()));
        await tester.pumpAndSettle();

        await tester.drag(find.byType(Dismissible), const Offset(-500.0, 0.0));
        await tester.pumpAndSettle();

        expect(find.text('Delete Record?'), findsOneWidget);
        await tester.tap(find.text('Delete').last);
        await tester.pumpAndSettle();

        verify(() => mockStorage.deleteLendingRecord('1')).called(1);
      });
    });
  });
}
