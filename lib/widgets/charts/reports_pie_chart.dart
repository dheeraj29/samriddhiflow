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
            touchCallback: (FlTouchEvent event, pieTouchResponse) {
              setState(() {
                if (!event.isInterestedForInteractions ||
                    pieTouchResponse == null ||
                    pieTouchResponse.touchedSection == null) {
                  touchedIndex = -1;
                  return;
                }
                touchedIndex =
                    pieTouchResponse.touchedSection!.touchedSectionIndex;
              });
            },
          ),
          sections: widget.entries.indexed.map((entry) {
            final index = entry.$1;
            final e = entry.$2;
            final isTouched = index == touchedIndex;
            final isOthers = e.key == 'Others';
            final fontSize = isTouched ? 16.0 : 12.0;
            final radius = isTouched ? 60.0 : 50.0;
            final percentage = (e.value / widget.total) * 100;

            // Logic for top slice label visibility
            final isTopSlice = widget.entries.length <= 6 || index < 6;
            final showLabel =
                isTouched || percentage >= 10 || (isTopSlice && percentage > 5);

            return PieChartSectionData(
              value: e.value == 0 ? 0.01 : e.value,
              titlePositionPercentageOffset: 1.6,
              title: showLabel
                  ? '${e.key} (${percentage.toStringAsFixed(0)}%)'
                  : '',
              radius: radius,
              titleStyle: AppTheme.offlineSafeTextStyle.copyWith(
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              color: isOthers ? Colors.grey : ReportUtils.getChartColor(index),
            );
          }).toList(),
        ),
      ),
    );
  }
}
