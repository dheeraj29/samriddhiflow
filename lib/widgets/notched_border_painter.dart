import 'package:flutter/material.dart';

/// A custom painter that draws a border along a notched shape.
class NotchedBorderPainter extends CustomPainter {
  final NotchedShape shape;
  final Rect fabRect;
  final Color color;
  final double borderWidth;

  NotchedBorderPainter({
    required this.shape,
    required this.fabRect,
    required this.color,
    this.borderWidth = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Get the outer path of the notched shape
    final Path path = shape.getOuterPath(Offset.zero & size, fabRect);

    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    // We only want to draw the top edge of the path (the part that contains the notch).
    // CircularNotchedRectangle.getOuterPath returns a closed path around the rectangle.
    // To only draw the top edge, we could try to segment the path, but drawing the
    // full border might be acceptable and even better for consistency.
    // However, if we only want the 'top' line with the notch:
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant NotchedBorderPainter oldDelegate) {
    return oldDelegate.fabRect != fabRect ||
        oldDelegate.color != color ||
        oldDelegate.borderWidth != borderWidth;
  }
}
