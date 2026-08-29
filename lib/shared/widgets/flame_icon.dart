import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_shadows.dart';

/// The FlameUp mark, drawn from the design's SVG path.
///
/// Taken verbatim from the prototype (`viewBox="0 0 13 16"`) so the logo, the
/// streak counter and the splash all render the same shape at any size,
/// without shipping a raster asset per density.
class FlameIcon extends StatelessWidget {
  const FlameIcon({
    this.size = 16,
    this.color = AppColors.accent,
    this.animate = false,
    super.key,
  });

  final double size;
  final Color color;

  /// The design's `fu-flick` keyframe: a slow scale-and-lift, as if the flame
  /// is breathing. Used on the splash and the streak screen.
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final flame = CustomPaint(
      size: Size(size * 13 / 16, size),
      painter: _FlamePainter(color),
    );

    if (!animate) {
      return ExcludeSemantics(child: flame);
    }

    return ExcludeSemantics(
      child: _Flicker(child: flame),
    );
  }
}

class _FlamePainter extends CustomPainter {
  const _FlamePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // M6.5 0C7.9 3 6.6 4.4 5.7 5.5c-.9 1.1-1 2.4-.1 3.2.5.4.4-1 .9-1.9
    //   .5.9 1.2 1.3 1.3 2.6.9-.6 1-1.6.9-2.4 1.5 1.1 2.3 2.7 2.3 4.3
    //   0 2.5-2 4.7-4.5 4.7S2 13.8 2 11.3C2 7.7 6.1 6.6 6.5 0Z
    final sx = size.width / 13;
    final sy = size.height / 16;

    final path = Path()
      ..moveTo(6.5 * sx, 0)
      ..cubicTo(7.9 * sx, 3 * sy, 6.6 * sx, 4.4 * sy, 5.7 * sx, 5.5 * sy)
      ..cubicTo(4.8 * sx, 6.6 * sy, 4.7 * sx, 7.9 * sy, 5.6 * sx, 8.7 * sy)
      ..cubicTo(6.1 * sx, 9.1 * sy, 6.0 * sx, 7.7 * sy, 6.5 * sx, 6.8 * sy)
      ..cubicTo(7.0 * sx, 7.7 * sy, 7.7 * sx, 8.1 * sy, 7.8 * sx, 9.4 * sy)
      ..cubicTo(8.7 * sx, 8.8 * sy, 8.8 * sx, 7.8 * sy, 8.7 * sx, 7.0 * sy)
      ..cubicTo(10.2 * sx, 8.1 * sy, 11.0 * sx, 9.7 * sy, 11.0 * sx, 11.3 * sy)
      ..cubicTo(11.0 * sx, 13.8 * sy, 9.0 * sx, 16.0 * sy, 6.5 * sx, 16.0 * sy)
      ..cubicTo(4.0 * sx, 16.0 * sy, 2.0 * sx, 13.8 * sy, 2.0 * sx, 11.3 * sy)
      ..cubicTo(2.0 * sx, 7.7 * sy, 6.1 * sx, 6.6 * sy, 6.5 * sx, 0)
      ..close();

    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_FlamePainter oldDelegate) => oldDelegate.color != color;
}

/// `@keyframes fu-flick` — 45% scale(1.07) translateY(-2px), opacity .92 to 1.
class _Flicker extends StatefulWidget {
  const _Flicker({required this.child});

  final Widget child;

  @override
  State<_Flicker> createState() => _FlickerState();
}

class _FlickerState extends State<_Flicker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.flicker,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_controller.value);
        return Transform.translate(
          offset: Offset(0, -2 * t),
          child: Transform.scale(
            scale: 1 + 0.07 * t,
            child: Opacity(opacity: 0.92 + 0.08 * t, child: child),
          ),
        );
      },
      child: widget.child,
    );
  }
}
