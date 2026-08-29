import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_typography.dart';

/// A horizontal progress bar.
///
/// The design animates these in with `fu-grow` — a left-anchored scaleX from
/// zero over 1s — so a bar reads as filling rather than appearing.
class FlameProgressBar extends StatelessWidget {
  const FlameProgressBar({
    required this.value,
    this.height = 4,
    this.color,
    this.animate = true,
    this.semanticLabel,
    super.key,
  });

  /// 0.0 to 1.0. Clamped, so bad data cannot overflow the track.
  final double value;

  final double height;

  /// Defaults to the accent-to-gold gradient the design uses.
  final Color? color;

  final bool animate;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final clamped = value.clamp(0.0, 1.0);

    return Semantics(
      label: semanticLabel,
      value: '${(clamped * 100).round()}%',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.sm),
        child: SizedBox(
          height: height,
          child: Stack(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(color: palette.divider),
                child: const SizedBox.expand(),
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth * clamped;
                  final fill = DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                      gradient: color == null
                          ? const LinearGradient(
                              colors: [AppColors.accent, AppColors.gold],
                            )
                          : null,
                      color: color,
                    ),
                    child: SizedBox(width: width, height: height),
                  );

                  if (!animate) return fill;

                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: AppMotion.grow,
                    curve: AppMotion.growCurve,
                    builder: (context, t, child) => Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(width: width * t, child: child),
                    ),
                    child: fill,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A circular progress ring, used by mastery tracks and the cook-mode timer.
class RingProgress extends StatelessWidget {
  const RingProgress({
    required this.value,
    this.size = 56,
    this.strokeWidth = 4,
    this.color = AppColors.accent,
    this.child,
    this.semanticLabel,
    super.key,
  });

  final double value;
  final double size;
  final double strokeWidth;
  final Color color;
  final Widget? child;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0.0, 1.0);

    return Semantics(
      label: semanticLabel,
      value: '${(clamped * 100).round()}%',
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size.square(size),
              painter: _RingPainter(
                value: clamped,
                color: color,
                track: AppPalette.of(context).divider,
                strokeWidth: strokeWidth,
              ),
            ),
            if (child != null) child!,
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.value,
    required this.color,
    required this.track,
    required this.strokeWidth,
  });

  final double value;
  final Color color;
  final Color track;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final radius = (size.width - strokeWidth) / 2;

    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final valuePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(centre, radius, trackPaint);

    if (value > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: centre, radius: radius),
        -math.pi / 2, // twelve o'clock
        2 * math.pi * value,
        false,
        valuePaint,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.color != color || old.track != track;
}

/// A titled section header with an optional trailing action.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.xxxl,
        AppSpacing.gutter,
        AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text(
              title,
              style: AppTypography.headlineSmall
                  .copyWith(color: palette.textPrimary),
            ),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}
