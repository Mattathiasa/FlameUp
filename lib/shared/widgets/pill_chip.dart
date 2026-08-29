import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_typography.dart';

/// A selectable filter pill, as used on the search and leaderboard screens.
///
/// The selected state is a filled accent pill; unselected is glass. Touch
/// target is expanded to 48px without changing the visual height, because the
/// design's pills are 32px and that is below the accessible minimum.
class PillChip extends StatelessWidget {
  const PillChip({
    required this.label,
    this.selected = false,
    this.onTap,
    this.icon,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Semantics(
      button: onTap != null,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.pillAll,
        child: ConstrainedBox(
          // Visual height stays 32; the tappable box is 48.
          constraints: const BoxConstraints(minHeight: AppTouch.minTarget),
          child: Center(
            widthFactor: 1,
            child: AnimatedContainer(
              duration: AppMotion.fast,
              curve: AppMotion.standard,
              // A minimum rather than a fixed height, so scaled-up text grows
              // the pill instead of overflowing it.
              constraints: const BoxConstraints(minHeight: 32),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? AppColors.accent : palette.glass,
                borderRadius: AppRadii.pillAll,
                border: Border.all(
                  color: selected ? AppColors.accent : palette.glassBorder,
                  width: AppGlass.hairline,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    icon!,
                    const SizedBox(width: AppSpacing.xs),
                  ],
                  // Flexible with an ellipsis: Amharic labels run longer than
                  // their English counterparts, and at a large accessibility
                  // text size an unconstrained Text overflows its pill.
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.label.copyWith(
                        color: selected ? Colors.white : palette.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The gold XP pill: `+60 XP`.
///
/// `rgba(240,179,60,.16)` fill, `.36` border, gold text.
class XpBadge extends StatelessWidget {
  const XpBadge({required this.xp, this.compact = false, super.key});

  final int xp;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final text = compact ? '+$xp' : '+$xp XP';
    return Semantics(
      label: '$xp experience points',
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 9,
          vertical: 5,
        ),
        decoration: BoxDecoration(
          color: AppColors.gold.withOpacity(0.16),
          borderRadius: BorderRadius.circular(AppRadii.xs),
          border: Border.all(color: AppColors.gold.withOpacity(0.36)),
        ),
        child: Text(
          text,
          style: AppTypography.badge.copyWith(color: AppColors.gold),
        ),
      ),
    );
  }
}

/// An uppercase, letter-spaced section eyebrow.
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {this.color, super.key});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: AppTypography.eyebrow.copyWith(
        color: color ?? AppPalette.of(context).textTertiary,
      ),
    );
  }
}
