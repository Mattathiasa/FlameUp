import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';

/// The design's glass surface, used on 73 elements across the 30 screens.
///
/// Every one of them is the same four things layered in the same order:
///
/// ```css
/// background: var(--g1);
/// backdrop-filter: blur(20px) saturate(1.7);
/// border: .5px solid var(--gl);
/// box-shadow: inset 0 1px 0 rgba(255,255,255,.06);
/// ```
///
/// Centralised so it is genuinely identical everywhere rather than
/// approximately so, and so the blur cost is paid in one place.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = AppRadii.cardAll,
    this.raised = false,
    this.onTap,
    this.blur = true,
    this.shadow = false,
    this.width,
    this.height,
    this.semanticLabel,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius borderRadius;

  /// Uses `--g2` instead of `--g1` — for a selected or elevated surface.
  final bool raised;

  final VoidCallback? onTap;

  /// A real backdrop blur is expensive. Long scrolling lists pass `false` and
  /// take the translucent fill without it; the difference is invisible when
  /// there is no vivid content behind, and the frame budget is not.
  final bool blur;

  final bool shadow;
  final double? width;
  final double? height;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    Widget surface = DecoratedBox(
      decoration: BoxDecoration(
        color: raised ? palette.glassRaised : palette.glass,
        borderRadius: borderRadius,
        border: Border.all(
          color: palette.glassBorder,
          width: AppGlass.hairline,
        ),
        // The inset top highlight, which is what makes the edge read as glass
        // rather than as flat translucency.
        boxShadow: const [
          BoxShadow(
            color: Color(0x0FFFFFFF),
            offset: Offset(0, AppGlass.insetHighlight),
            blurRadius: 0,
            spreadRadius: -0.5,
          ),
        ],
      ),
      child: Padding(
        padding: padding ?? EdgeInsets.zero,
        child: child,
      ),
    );

    if (blur) {
      surface = BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: AppGlass.blurSigma,
          sigmaY: AppGlass.blurSigma,
        ),
        child: surface,
      );
    }

    surface = ClipRRect(borderRadius: borderRadius, child: surface);

    if (shadow) {
      surface = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: Theme.of(context).brightness == Brightness.dark
              ? const [
                  BoxShadow(
                    color: Color(0x73000000),
                    offset: Offset(0, 14),
                    blurRadius: 34,
                  ),
                ]
              : const [
                  BoxShadow(
                    color: Color(0x21783C14),
                    offset: Offset(0, 14),
                    blurRadius: 34,
                  ),
                ],
        ),
        child: surface,
      );
    }

    if (onTap != null) {
      surface = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          child: surface,
        ),
      );
    }

    Widget result = SizedBox(width: width, height: height, child: surface);

    if (margin != null) {
      result = Padding(padding: margin!, child: result);
    }

    if (semanticLabel != null) {
      result = Semantics(
        label: semanticLabel,
        button: onTap != null,
        child: result,
      );
    }

    return result;
  }
}
