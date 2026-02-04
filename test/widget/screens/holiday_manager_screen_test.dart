import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samriddhi_flow/providers.dart';
import 'package:samriddhi_flow/screens/holiday_manager_screen.dart';

class MockHolidaysNotifier extends HolidaysNotifier {
  List<DateTime> _state = [];

  @override
  List<DateTime> build() => _state;

  @override
  Future<void> addHoliday(DateTime date) async {
    _state = [..._state, date];
    state = _state;
  }

  @override
  Future<void> removeHoliday(DateTime date) async {
    _state = _state.where((d) => d != date).toList();
    state = _state;
  }

  void setInitialState(List<DateTime> newState) {
    _state = newState;
  }
}

void main() {
  late MockHolidaysNotifier mockHolidaysNotifier;

  setUp(() {
    mockHolidaysNotifier = MockHolidaysNotifier();
  });

  Widget createWidgetUnderTest() {
    return ProviderScope(
      overrides: [
        holidaysProvider.overrideWith(() => mockHolidaysNotifier),
      ],
      child: const MaterialApp(
        home: HolidayManagerScreen(),
      ),
    );
  }

  testWidgets('HolidayManagerScreen shows empty state', (tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(find.text('No holidays added yet.'), findsOneWidget);
  });

  testWidgets('HolidayManagerScreen shows list and deletes', (tester) async {
    final date = DateTime(2025, 12, 25);
    mockHolidaysNotifier.setInitialState([date]);

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(find.text('December 25, 2025'), findsOneWidget);

    // Tap Delete
    final deleteButton = find.descendant(
      of: find.byType(ListTile),
      matching: find.byType(IconButton),
    );
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();

    expect(find.text('December 25, 2025'), findsNothing);
    expect(find.text('No holidays added yet.'), findsOneWidget);
  });

  testWidgets('HolidayManagerScreen adds holiday', (tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Tap Add
    await tester.tap(find.byType(IconButton).first); // Add button in App Bar
    await tester.pumpAndSettle();

    // Select Date (Simpler to just verify dialog interaction if date picker is standard)
    // DatePicker defaults to today. Tap OK.
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('No holidays added yet.'), findsNothing);
    expect(find.byType(ListTile), findsOneWidget);
  });
}
