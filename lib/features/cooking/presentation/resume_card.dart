import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/widgets.dart';
import '../../recipes/domain/recipe.dart';

/// The "pick up where you left" card for a session still in progress.
///
/// Lives on Today and at the top of the Cook tab — the same situation in both
/// places, so the same widget serves both.
class ResumeCard extends StatelessWidget {
  const ResumeCard({
    required this.recipe,
    required this.step,
    required this.total,
    required this.progress,
    required this.amharic,
    required this.l10n,
    required this.onTap,
    super.key,
  });

  final Recipe recipe;
  final int step;
  final int total;
  final double progress;
  final bool amharic;
  final AppLocalizations l10n;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return GlassPanel(
      blur: false,
      padding: const EdgeInsets.all(AppSpacing.xl),
      onTap: onTap,
      child: Row(
        children: [
          GradientTile.fromHex(
            colorA: recipe.gradientA,
            colorB: recipe.gradientB,
            width: 56,
            height: 56,
            borderRadius: AppRadii.lgAll,
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Eyebrow(l10n.pickUp, color: AppColors.accent),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${recipe.localisedTitle(amharic: amharic)} · '
                  '${l10n.stepOf} $step ${l10n.ofWord} $total',
                  style: AppTypography.titleSmall
                      .copyWith(color: palette.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.sm),
                FlameProgressBar(value: progress, animate: false),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment(-0.34, -1),
                end: Alignment(0.34, 1),
                colors: [AppColors.accent, AppColors.accentDeep],
              ),
            ),
            child: const Icon(Icons.play_arrow, color: Colors.white, size: 22),
          ),
        ],
      ),
    );
  }
}
