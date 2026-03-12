import 'package:flutter/material.dart';

class BellAnimation extends StatefulWidget {
  final Widget child;
  final bool animate;

  const BellAnimation({
    super.key,
    required this.child,
    required this.animate,
  });

  @override
  State<BellAnimation> createState() => _BellAnimationState();
}

class _BellAnimationState extends State<BellAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000), // 2 seconds total loop
      vsync: this,
    );

    // Ring for 40% of time, pause for 60% with a slight resting tilt
    _animation = TweenSequence<double>([
      // Swing left from resting tilt
      TweenSequenceItem(tween: Tween(begin: 0.15, end: -0.3), weight: 2),
      // Swing right
      TweenSequenceItem(tween: Tween(begin: -0.3, end: 0.35), weight: 2),
      // Swing left
      TweenSequenceItem(tween: Tween(begin: 0.35, end: -0.2), weight: 2),
      // Swing right
      TweenSequenceItem(tween: Tween(begin: -0.2, end: 0.25), weight: 2),
      // Return to resting tilt
      TweenSequenceItem(tween: Tween(begin: 0.25, end: 0.15), weight: 2),
      // Pause at a slight tilt to show it needs attention
      TweenSequenceItem(tween: ConstantTween(0.15), weight: 15),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    if (widget.animate) {
      _controller.repeat(); // coverage:ignore-line
    }
  }

  @override
  void didUpdateWidget(BellAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate != oldWidget.animate) {
      if (widget.animate) {
        // coverage:ignore-line
        _controller.repeat(); // coverage:ignore-line
      } else {
        _controller.stop(); // coverage:ignore-line
        _controller.reset(); // coverage:ignore-line
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        // If not animating, ensure it's perfectly straight (0.0)
        final double angle = widget.animate ? _animation.value : 0.0;
        return Transform.rotate(
          angle: angle,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
