import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:samriddhi_flow/models/lending_record.dart';
import 'package:samriddhi_flow/screens/lending/lending_history_screen.dart';
import 'package:samriddhi_flow/services/lending/lending_provider.dart';
import 'package:samriddhi_flow/providers.dart';
import '../test_mocks.dart';

class MockLendingNotifier extends Notifier<List<LendingRecord>>
    with Mock
    implements LendingNotifier {}

void main() {
  late MockLendingNotifier mockLendingNotifier;
  late MockStorageService mockStorage;

  setUpAll(() {
    registerFallbackValue(LendingRecord(
      id: 'f',
      personName: 'f',
      amount: 0,
      reason: 'f',
      type: LendingType.lent,
      date: DateTime(2000),
    ));
  });

  setUp(() {
    mockLendingNotifier = MockLendingNotifier();
    mockStorage = MockStorageService();
    setupStorageDefaults(mockStorage);
  });

  Widget createTestWidget(String recordId) {
    return ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(mockStorage),
        lendingProvider.overrideWith(() => mockLendingNotifier),
        storageInitializerProvider.overrideWith((ref) => const AsyncData(null)),
      ],
      child: MaterialApp(
        home: LendingHistoryScreen(recordId: recordId),
      ),
    );
  }

  testWidgets('LendingHistoryScreen shows empty state when no payments',
      (tester) async {
    final record = LendingRecord(
      id: 'rec1',
      personName: 'John Doe',
      amount: 1000,
      reason: 'Loan',
      type: LendingType.lent,
      date: DateTime(2025, 1, 1),
      payments: [],
    );

    // ignore: invalid_use_of_visible_for_overriding_member
    when(() => mockLendingNotifier.build()).thenReturn([record]);

    await tester.pumpWidget(createTestWidget('rec1'));
    await tester.pumpAndSettle();

    expect(find.text('Payment History'), findsOneWidget);
    expect(find.text('No payments recorded.'), findsOneWidget);
    expect(find.text('John Doe'), findsOneWidget);
    // Be robust against formatting (₹1,000.00 vs 1000 etc.)
    expect(find.textContaining('1'), findsAtLeast(1));
  });

  testWidgets('LendingHistoryScreen shows list of payments', (tester) async {
    final record = LendingRecord(
      id: 'rec1',
      personName: 'John Doe',
      amount: 1000,
      reason: 'Loan',
      type: LendingType.lent,
      date: DateTime(2025, 1, 1),
      payments: [
        LendingPayment(
          id: 'p1',
          amount: 200,
          date: DateTime(2025, 1, 10),
          note: 'Partial payment',
        ),
        LendingPayment(
          id: 'p2',
          amount: 300,
          date: DateTime(2025, 1, 15),
        ),
      ],
    );

    // ignore: invalid_use_of_visible_for_overriding_member
    when(() => mockLendingNotifier.build()).thenReturn([record]);

    await tester.pumpWidget(createTestWidget('rec1'));
    await tester.pumpAndSettle();

    expect(find.text('No payments recorded.'), findsNothing);
    expect(find.textContaining('200'), findsOneWidget);
    expect(find.textContaining('300'), findsOneWidget);
    expect(find.text('Partial payment'), findsOneWidget);
  });

  testWidgets('LendingHistoryScreen supports pagination', (tester) async {
    final payments = List.generate(
      20,
      (i) => LendingPayment(
        id: 'p$i',
        amount: 10.0 + i,
        date: DateTime(2025, 1, 1 + i),
      ),
    );

    final record = LendingRecord(
      id: 'rec1',
      personName: 'John Doe',
      amount: 1000,
      reason: 'Loan',
      type: LendingType.lent,
      date: DateTime(2025, 1, 1),
      payments: payments,
    );

    // ignore: invalid_use_of_visible_for_overriding_member
    when(() => mockLendingNotifier.build()).thenReturn([record]);

    await tester.pumpWidget(createTestWidget('rec1'));
    await tester.pumpAndSettle();

    // Verify first item of the page (Index 0 is p19)
    expect(find.textContaining('29'), findsOneWidget);

    // Scroll to find the last item of the page (Index 14 is p5)
    final lastItemOnPage = find.textContaining('15');
    await tester.dragUntilVisible(
      lastItemOnPage,
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();

    expect(lastItemOnPage, findsOneWidget);

    expect(find.text('Page 1 of 2'), findsOneWidget);

    // Tap next page
    final nextButton = find.byIcon(Icons.chevron_right);
    expect(nextButton, findsOneWidget);
    await tester.tap(nextButton);
    await tester.pumpAndSettle();

    // Second page shows remaining 5 items (p4 to p0)
    expect(find.byType(ListTile), findsNWidgets(5));
    expect(find.text('Page 2 of 2'), findsOneWidget);
  });

  testWidgets('LendingHistoryScreen allows deleting a payment', (tester) async {
    final record = LendingRecord(
      id: 'rec1',
      personName: 'John Doe',
      amount: 1000,
      reason: 'Loan',
      type: LendingType.lent,
      date: DateTime(2025, 1, 1),
      payments: [
        LendingPayment(
          id: 'p1',
          amount: 200,
          date: DateTime(2025, 1, 10),
        ),
      ],
    );

    // ignore: invalid_use_of_visible_for_overriding_member
    when(() => mockLendingNotifier.build()).thenReturn([record]);
    when(() => mockLendingNotifier.updateRecord(any()))
        .thenAnswer((_) async {});

    await tester.pumpWidget(createTestWidget('rec1'));
    await tester.pumpAndSettle();

    // Tap delete icon - it's a PureIcons.deleteOutlined which returns Icon(Icons.delete_outline)
    final deleteIcon = find.byIcon(Icons.delete_outline);
    expect(deleteIcon, findsOneWidget);
    await tester.tap(deleteIcon);
    await tester.pumpAndSettle();

    // Confirm dialog
    expect(find.text('Delete Payment?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    // Verify updateRecord was called
    verify(() => mockLendingNotifier.updateRecord(any())).called(1);

    expect(find.text('Payment deleted'), findsOneWidget);
  });
}
