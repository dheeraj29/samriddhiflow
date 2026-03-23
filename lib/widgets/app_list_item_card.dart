import 'package:flutter/material.dart';

class AppListItemCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;
  final double elevation;
  final double borderRadius;
  final VoidCallback? onTap;

  const AppListItemCard({
    super.key,
    required this.child,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    this.elevation = 0,
    this.borderRadius = 12,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: margin,
      elevation: elevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        side: BorderSide(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.2) // coverage:ignore-line
              : Colors.black.withValues(alpha: 0.1),
        ),
      ),
      child: onTap != null
          // coverage:ignore-start
          ? InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(borderRadius),
              child: child,
              // coverage:ignore-end
            )
          : child,
    );
  }
}
