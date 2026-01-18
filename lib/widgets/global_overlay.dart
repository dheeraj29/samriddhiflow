import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../feature_providers.dart';
import 'quick_sum_tracker.dart';

class GlobalOverlay extends ConsumerWidget {
  final Widget? child;

  const GlobalOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      children: [
        if (child != null) child!,
        // Only show calculator overlay if explicitly enabled (e.g. on Dashboard)
        if (ref.watch(calculatorVisibleProvider))
          Positioned.fill(
            child: Overlay(
              initialEntries: [
                OverlayEntry(
                  builder: (context) => const QuickSumTracker(),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
