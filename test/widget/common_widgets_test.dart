import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samriddhi_flow/widgets/stat_card.dart';
import 'package:samriddhi_flow/widgets/period_selector.dart';
import 'package:samriddhi_flow/widgets/common_dialogs.dart';

void main() {
  group('StatCard Widget Tests', () {
    testWidgets('renders correctly with given parameters',
        (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: StatCard(
            label: 'Total Income',
            value: '\$5,000',
            icon: Icons.trending_up,
            color: Colors.green,
          ),
        ),
      ));

      expect(find.text('Total Income'), findsOneWidget);
      expect(find.text('\$5,000'), findsOneWidget);
      expect(find.byIcon(Icons.trending_up), findsOneWidget);
    });

    testWidgets('calls onTap when clicked', (WidgetTester tester) async {
      bool tapped = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StatCard(
            label: 'Test',
            value: '0',
            icon: Icons.abc,
            color: Colors.blue,
            onTap: () => tapped = true,
          ),
        ),
      ));

      await tester.tap(find.byType(StatCard));
      expect(tapped, true);
    });
  });

  group('PeriodSelector Widget Tests', () {
    testWidgets('renders all periods and handles selection',
        (WidgetTester tester) async {
      AnalysisPeriod? lastPeriod;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PeriodSelector(
            selectedPeriod: AnalysisPeriod.month,
            selectedDate: DateTime(2023, 5),
            onPeriodChanged: (p) => lastPeriod = p,
            onDateChanged: (_) {},
          ),
        ),
      ));

      expect(find.text('MONTH'), findsOneWidget);
      expect(find.text('YEAR'), findsOneWidget);
      expect(find.text('ALL'), findsOneWidget);
      expect(find.text('May 2023'), findsOneWidget);

      await tester.tap(find.text('YEAR'));
      expect(lastPeriod, AnalysisPeriod.year);
    });

    testWidgets('advances and regresses date correctly',
        (WidgetTester tester) async {
      DateTime? lastDate;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PeriodSelector(
            selectedPeriod: AnalysisPeriod.month,
            selectedDate: DateTime(2023, 5),
            onPeriodChanged: (_) {},
            onDateChanged: (d) => lastDate = d,
          ),
        ),
      ));

      await tester.tap(find.byIcon(Icons.chevron_left));
      expect(lastDate!.month, 4);
      expect(lastDate!.year, 2023);

      await tester.tap(find.byIcon(Icons.chevron_right));
      expect(lastDate!.month, 6);
      expect(lastDate!.year, 2023);
    });
  });

  group('CommonDialogs Tests', () {
    testWidgets('showTextFieldDialog renders and saves',
        (WidgetTester tester) async {
      String savedValue = '';
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => CommonDialogs.showTextFieldDialog(
              context: context,
              title: 'Edit Name',
              labelText: 'Name',
              initialValue: 'Original',
              onSave: (val) => savedValue = val,
            ),
            child: const Text('Open'),
          ),
        ),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Name'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Updated');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(savedValue, 'Updated');
    });

    testWidgets('showConfirmationDialog renders and confirms',
        (WidgetTester tester) async {
      bool confirmed = false;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              confirmed = await CommonDialogs.showConfirmationDialog(
                context: context,
                title: 'Delete?',
                content: 'Are you sure?',
              );
            },
            child: const Text('Open'),
          ),
        ),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Delete?'), findsOneWidget);
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(confirmed, true);
    });
  });
}
