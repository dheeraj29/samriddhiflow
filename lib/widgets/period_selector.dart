import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum AnalysisPeriod { month, year, all }

class PeriodSelector extends StatelessWidget {
  final AnalysisPeriod selectedPeriod;
  final DateTime selectedDate;
  final Function(AnalysisPeriod) onPeriodChanged;
  final Function(DateTime) onDateChanged;

  const PeriodSelector({
    super.key,
    required this.selectedPeriod,
    required this.selectedDate,
    required this.onPeriodChanged,
    required this.onDateChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: AnalysisPeriod.values.map((period) {
              final isSelected = selectedPeriod == period;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(period.name.toUpperCase()),
                  selected: isSelected,
                  onSelected: (_) => onPeriodChanged(period),
                ),
              );
            }).toList(),
          ),
        ),
        if (selectedPeriod != AnalysisPeriod.all)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    final newDate = selectedPeriod == AnalysisPeriod.month
                        ? DateTime(selectedDate.year, selectedDate.month - 1)
                        : DateTime(selectedDate.year - 1);
                    onDateChanged(newDate);
                  },
                ),
                Text(
                  selectedPeriod == AnalysisPeriod.month
                      ? DateFormat('MMMM yyyy').format(selectedDate)
                      : DateFormat('yyyy').format(selectedDate),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    final newDate = selectedPeriod == AnalysisPeriod.month
                        ? DateTime(selectedDate.year, selectedDate.month + 1)
                        : DateTime(selectedDate.year + 1);
                    onDateChanged(newDate);
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }
}
