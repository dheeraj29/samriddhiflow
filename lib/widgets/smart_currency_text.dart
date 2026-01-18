import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/currency_utils.dart';
import '../providers.dart';
import '../theme/app_theme.dart';

class SmartCurrencyText extends ConsumerStatefulWidget {
  final double value;
  final String locale;
  final TextStyle? style;
  final bool?
      initialCompact; // Changed to nullable to defer to provider if null

  final String? prefix;
  final String? suffix;

  const SmartCurrencyText({
    super.key,
    required this.value,
    required this.locale,
    this.style,
    this.initialCompact,
    this.prefix,
    this.suffix,
  });

  @override
  ConsumerState<SmartCurrencyText> createState() => _SmartCurrencyTextState();
}

class _SmartCurrencyTextState extends ConsumerState<SmartCurrencyText> {
  bool? _localCompact; // If null, use global

  @override
  void didUpdateWidget(SmartCurrencyText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialCompact != oldWidget.initialCompact) {
      _localCompact = widget.initialCompact;
    }
  }

  @override
  Widget build(BuildContext context) {
    final globalCompact = ref.watch(currencyFormatProvider);
    final isCompact = _localCompact ?? widget.initialCompact ?? globalCompact;

    final displayText =
        '${widget.prefix ?? ""}${isCompact ? CurrencyUtils.getSmartFormat(widget.value, widget.locale) : CurrencyUtils.getFormatter(widget.locale).format(widget.value)}${widget.suffix ?? ""}';

    return GestureDetector(
      onTap: () => setState(() => _localCompact = !isCompact),
      behavior: HitTestBehavior.opaque,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Text(
          displayText,
          key: ValueKey(displayText),
          style: widget.style?.merge(AppTheme.offlineSafeTextStyle) ??
              AppTheme.offlineSafeTextStyle,
        ),
      ),
    );
  }
}
