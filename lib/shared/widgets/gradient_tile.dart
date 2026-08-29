import 'package:flutter/material.dart';

import '../../core/theme/app_dimens.dart';

/// The two-colour tile the design uses wherever a photograph would go.
///
/// `linear-gradient(150deg, a, b)` with a radial sheen over the top left:
/// `radial-gradient(120% 80% at 24% 12%, rgba(255,255,255,.30), transparent)`.
///
/// There is no recipe photography, so every dish, region and collection carries
/// its own colour pair instead. These are real design elements, not
/// placeholders to be stripped later — when photography arrives it layers on
/// top via [image], and the gradient stays as the loading and error state.
class GradientTile extends StatelessWidget {
  const GradientTile({
    required this.colorA,
    required this.colorB,
    this.child,
    this.borderRadius = AppRadii.cardAll,
    this.width,
    this.height,
    this.image,
    this.sheen = true,
    this.scrim = false,
    super.key,
  });

  /// Builds from the `#RRGGBB` pair stored on a recipe or region document.
  factory GradientTile.fromHex({
    required String colorA,
    required String colorB,
    Widget? child,
    BorderRadius borderRadius = AppRadii.cardAll,
    double? width,
    double? height,
    ImageProvider? image,
    bool sheen = true,
    bool scrim = false,
    Key? key,
  }) =>
      GradientTile(
        colorA: _parseHex(colorA),
        colorB: _parseHex(colorB),
        borderRadius: borderRadius,
        width: width,
        height: height,
        image: image,
        sheen: sheen,
        scrim: scrim,
        key: key,
        child: child,
      );

  final Color colorA;
  final Color colorB;
  final Widget? child;
  final BorderRadius borderRadius;
  final double? width;
  final double? height;

  /// A real photograph, once one exists. Drawn over the gradient, so a slow or
  /// failed load reveals the tile rather than a grey box.
  final ImageProvider? image;

  /// The highlight sweep across the top left.
  final bool sheen;

  /// A bottom-up dark scrim, for tiles with text over them.
  final bool scrim;

  static Color _parseHex(String hex) {
    final digits = hex.replaceFirst('#', '');
    return Color(int.parse('FF$digits', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 150deg in CSS runs top-left to bottom-right, clockwise from the
            // vertical, which is this pair of alignments in Flutter.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: const Alignment(-0.5, -1),
                  end: const Alignment(0.5, 1),
                  colors: [colorA, colorB],
                ),
              ),
            ),
            if (image != null) Image(image: image!, fit: BoxFit.cover),
            if (sheen)
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(-0.52, -0.76), // 24% 12%
                    radius: 1.2,
                    colors: [Color(0x4DFFFFFF), Color(0x00FFFFFF)],
                    stops: [0, 0.58],
                  ),
                ),
              ),
            if (scrim)
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0x8C000000), Color(0x00000000)],
                    stops: [0, 0.62],
                  ),
                ),
              ),
            if (child != null) child!,
          ],
        ),
      ),
    );
  }
}
