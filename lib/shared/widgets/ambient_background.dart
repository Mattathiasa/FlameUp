import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// The three radial glows the design paints behind the phone screen.
///
/// ```css
/// radial-gradient(420px 300px at 82%  2%, var(--pamb1), transparent 66%)
/// radial-gradient(360px 300px at 12% 46%, var(--pamb2), transparent 62%)
/// radial-gradient(320px 260px at 60% 96%, var(--pamb3), transparent 60%)
/// ```
///
/// Both themes define all three, so this is correct in light and dark without
/// a branch. Purely decorative, hence excluded from semantics.
class AmbientBackground extends StatelessWidget {
  const AmbientBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Positioned.fill(
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: Stack(
            children: [
              _Glow(
                colour: palette.phoneAmbient1,
                alignment: const Alignment(0.64, -0.96),
                radius: 1.1,
                stop: 0.66,
              ),
              _Glow(
                colour: palette.phoneAmbient2,
                alignment: const Alignment(-0.76, -0.08),
                radius: 1,
                stop: 0.62,
              ),
              _Glow(
                colour: palette.phoneAmbient3,
                alignment: const Alignment(0.2, 0.92),
                radius: 0.9,
                stop: 0.6,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({
    required this.colour,
    required this.alignment,
    required this.radius,
    required this.stop,
  });

  final Color colour;
  final Alignment alignment;
  final double radius;
  final double stop;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: alignment,
          radius: radius,
          colors: [colour, colour.withOpacity(0)],
          stops: [0, stop],
        ),
      ),
      child: const SizedBox.expand(),
    );
  }
}
