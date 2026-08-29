import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_typography.dart';

/// The primary action button.
///
/// `linear-gradient(160deg, --acc, #DE3A18)` at 56px with an 18px radius, an
/// accent glow beneath, and the `fu-sheen` highlight sweeping across it every
/// 3.4s. Twenty elements in the design use this treatment.
class FlameButton extends StatelessWidget {
  const FlameButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 56,
    this.sheen = true,
    this.loading = false,
    this.expand = true,
    super.key,
  });

  final String label;

  /// Null disables the button, which also stops the sheen — an inert control
  /// should not look like it is inviting a tap.
  final VoidCallback? onPressed;

  final Widget? icon;
  final double height;
  final bool sheen;
  final bool loading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;

    final content = loading
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(Colors.white),
            ),
          )
        : Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                icon!,
                const SizedBox(width: AppSpacing.sm),
              ],
              Flexible(
                child: Text(
                  label,
                  style: AppTypography.button.copyWith(color: Colors.white),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: AppRadii.xlAll,
            boxShadow: enabled ? AppShadows.accentGlow : null,
          ),
          child: ClipRRect(
            borderRadius: AppRadii.xlAll,
            child: Stack(
              children: [
                DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(-0.34, -1),
                      end: Alignment(0.34, 1),
                      colors: [AppColors.accent, AppColors.accentDeep],
                    ),
                  ),
                  child: SizedBox(
                    height: height,
                    width: expand ? double.infinity : null,
                    child: Center(child: content),
                  ),
                ),
                if (sheen && enabled) const Positioned.fill(child: _Sheen()),
                Positioned.fill(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: enabled ? onPressed : null,
                      splashColor: Colors.white24,
                      highlightColor: Colors.white10,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// `@keyframes fu-sheen` — a 60px highlight travelling left to right.
class _Sheen extends StatefulWidget {
  const _Sheen();

  @override
  State<_Sheen> createState() => _SheenState();
}

class _SheenState extends State<_Sheen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.sheen,
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          // -120% to 220%, as in the keyframe.
          final x = -1.2 + _controller.value * 3.4;
          return FractionalTranslation(
            translation: Offset(x, 0),
            child: const FractionallySizedBox(
              widthFactor: 0.3,
              heightFactor: 1,
              alignment: Alignment.centerLeft,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0x00FFFFFF),
                      Color(0x57FFFFFF),
                      Color(0x00FFFFFF),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
