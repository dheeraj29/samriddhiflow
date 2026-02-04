import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:samriddhi_flow/widgets/charts/reports_pie_chart.dart';
import 'package:fl_chart/fl_chart.dart';

void main() {
  testWidgets('ReportsPieChart renders nothing if total is 0', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: ReportsPieChart(entries: [], total: 0),
      ),
    ));

    expect(find.byType(PieChart), findsNothing);
    expect(find.byType(SizedBox), findsWidgets);
  });

  testWidgets('ReportsPieChart renders chart with data', (tester) async {
    final entries = [
      const MapEntry('Food', 500.0),
      const MapEntry('Travel', 500.0),
    ];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ReportsPieChart(entries: entries, total: 1000.0),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(PieChart), findsOneWidget);

    // Check data directly as text is painted
    final chart = tester.widget<PieChart>(find.byType(PieChart));
    final sections = chart.data.sections;
    expect(sections.length, 2);
    expect(sections[0].title, contains('Food'));
  });

  testWidgets('ReportsPieChart handles Others slice color', (tester) async {
    final entries = [
      const MapEntry('Others', 100.0),
    ];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ReportsPieChart(entries: entries, total: 100.0),
      ),
    ));

    final chart = tester.widget<PieChart>(find.byType(PieChart));
    final section = chart.data.sections.first;
    expect(section.color, Colors.grey);
  });
}
