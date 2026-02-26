import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../theme/app_theme.dart';
import '../../utils/report_utils.dart';

class ReportsPieChart extends StatefulWidget {
  final List<MapEntry<String, double>> entries;
  final double total;

  const ReportsPieChart({
    super.key,
    required this.entries,
    required this.total,
  });

  @override
  State<ReportsPieChart> createState() => _ReportsPieChartState();
}

class _ReportsPieChartState extends State<ReportsPieChart> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    if (widget.total == 0) return const SizedBox();

    return SizedBox(
      height: 250,
      child: PieChart(
        PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 40,
          pieTouchData: PieTouchData(
            // coverage:ignore-start
            touchCallback: (FlTouchEvent event, pieTouchResponse) {
              setState(() {
                if (!event.isInterestedForInteractions ||
            // coverage:ignore-end
                    pieTouchResponse == null ||
                    pieTouchResponse.touchedSection == null) { // coverage:ignore-line
                  touchedIndex = -1; // coverage:ignore-line
                  return;
                }
                touchedIndex = // coverage:ignore-line
                    pieTouchResponse.touchedSection!.touchedSectionIndex; // coverage:ignore-line
              });
            },
          ),
          sections: widget.entries.indexed
              .map((entry) => _buildPieSection(context, entry.$1, entry.$2))
              .toList(),
        ),
      ),
    );
  }

  PieChartSectionData _buildPieSection(
      BuildContext context, int index, MapEntry<String, double> e) {
    final isTouched = index == touchedIndex;
    final isOthers = e.key == 'Others';
    final fontSize = isTouched ? 16.0 : 12.0;
    final radius = isTouched ? 60.0 : 50.0;
    final percentage = (e.value / widget.total) * 100;

    final isTopSlice = widget.entries.length <= 6 || index < 6;
    final showLabel =
        isTouched || percentage >= 10 || (isTopSlice && percentage > 5);

    return PieChartSectionData(
      value: e.value == 0 ? 0.01 : e.value,
      titlePositionPercentageOffset: 1.6,
      title: showLabel ? '${e.key} (${percentage.toStringAsFixed(0)}%)' : '',
      radius: radius,
      titleStyle: AppTheme.offlineSafeTextStyle.copyWith(
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      color: isOthers ? Colors.grey : ReportUtils.getChartColor(index),
    );
  }
}
