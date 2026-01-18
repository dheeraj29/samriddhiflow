import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../feature_providers.dart';
import '../providers.dart';
import '../utils/debug_logger.dart';
import 'quick_sum_tracker.dart';

class GlobalOverlay extends ConsumerWidget {
  final Widget? child;

  const GlobalOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCalculatorVisible = ref.watch(calculatorVisibleProvider);
    final isLoggedIn = ref.watch(isLoggedInProvider);
    final isLogoutRequested = ref.watch(logoutRequestedProvider);

    if (isLogoutRequested) {
      DebugLogger().log("GlobalOverlay: Logout Detected. Snapping Shut.");
    }

    final showCalculator =
        isCalculatorVisible && isLoggedIn && !isLogoutRequested;

    return Stack(
      children: [
        if (child != null) child!,
        if (showCalculator)
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
