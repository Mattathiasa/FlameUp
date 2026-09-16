import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../domain/recipe.dart';

/// The dish's photo, or its gradient when there is no photo or it fails.
///
/// Every recipe has gradient colors, so the fallback is always the design's
/// own look rather than a broken-image glyph — a dead link degrades to
/// "as it was", never to something uglier.
class DishPhoto extends StatelessWidget {
  const DishPhoto({
    required this.recipe,
    super.key,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  final Recipe recipe;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final url = recipe.imageUrl;
    final fallback = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_parseHex(recipe.gradientA), _parseHex(recipe.gradientB)],
        ),
        borderRadius: borderRadius,
      ),
    );

    if (url == null || url.isEmpty) return fallback;

    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: CachedNetworkImage(
        imageUrl: url,
        fit: fit,
        // A slow load shows the gradient, not an empty box or a spinner:
        // the card keeps its shape and color while the photo arrives.
        fadeInDuration: const Duration(milliseconds: 250),
        errorWidget: (_, __, ___) => fallback,
        placeholder: (_, __) => fallback,
      ),
    );
  }

  /// Same hex convention as GradientTile's seeds (#RRGGBB).
  static Color _parseHex(String hex) {
    final digits = hex.replaceFirst('#', '');
    return Color(int.parse('FF$digits', radix: 16));
  }
}
