import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/widgets.dart';
import '../../auth/domain/auth_providers.dart';
import '../../recipes/domain/recipe_providers.dart';
import '../domain/level_curve.dart';
import '../domain/progress_providers.dart';

/// 11-progress — "Your kitchen".
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);
    final amharic = ref.watch(isAmharicProvider);
    final curve = ref.watch(levelCurveProvider);
    final cached = ref.watch(userProgressProvider).valueOrNull;
    final progress = cached?.value;
    final streak = ref.watch(liveStreakProvider);
    final isGuest = ref.watch(isGuestProvider);

    final xp = progress?.xp ?? 0;
    final level = curve.levelFor(xp);

    return Scaffold(
      body: Stack(
        children: [
          const AmbientBackground(),
          SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.xl,
                AppSpacing.gutter,
                AppSpacing.screenBottom,
              ),
              children: [
                if (cached?.refreshFailed ?? false)
                  StaleBanner(message: l10n.offBanner),

                // A guest's progress is real but only on this device, and
                // saying so is more useful than letting them find out by
                // losing it.
                if (isGuest)
                  GlassPanel(
                    blur: false,
                    margin: const EdgeInsets.only(bottom: AppSpacing.xl),
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    onTap: () => context.push(Routes.upgradeAccount),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          size: 18,
                          color: AppColors.gold,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            l10n.upgradeSubtitle,
                            style: AppTypography.caption
                                .copyWith(color: palette.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),

                _LevelCard(
                  level: level,
                  xp: xp,
                  curve: curve,
                  amharic: amharic,
                  l10n: l10n,
                ),
                const SizedBox(height: AppSpacing.xl),

                Row(
                  children: [
                    _StatTile(
                      value: '${progress?.recipesCooked ?? 0}',
                      label: l10n.stDishes,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    _StatTile(value: '$streak', label: l10n.stStreak),
                    const SizedBox(width: AppSpacing.md),
                    _StatTile(
                      value: '${progress?.regionsTasted ?? 0}',
                      label: l10n.stRegions,
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.xxxl),
                _NavRow(
                  label: l10n.masteryH,
                  onTap: () => context.push(Routes.mastery),
                ),
                _NavRow(
                  label: l10n.achvH1,
                  onTap: () => context.push(Routes.achievements),
                ),
                _NavRow(
                  label: l10n.questsH1,
                  onTap: () => context.push(Routes.quests),
                ),
                _NavRow(
                  label: l10n.streakH1,
                  onTap: () => context.push(Routes.streak),
                ),
                const SizedBox(height: AppSpacing.xl),
                _NavRow(
                  label: l10n.savedH1,
                  onTap: () => context.push(Routes.saved),
                ),
                _NavRow(
                  label: l10n.shopH1,
                  onTap: () => context.push(Routes.shopping),
                ),
                _NavRow(
                  label: l10n.planH1,
                  onTap: () => context.push(Routes.planner),
                ),
                _NavRow(
                  label: l10n.setH1,
                  onTap: () => context.push(Routes.settings),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({
    required this.level,
    required this.xp,
    required this.curve,
    required this.amharic,
    required this.l10n,
  });

  final int level;
  final int xp;
  final LevelCurve curve;
  final bool amharic;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final toNext = curve.xpToNextLevel(xp);

    return GlassPanel(
      blur: false,
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              RingProgress(
                value: curve.progressWithinLevel(xp),
                size: 64,
                strokeWidth: 5,
                semanticLabel: 'Level $level',
                child: Text(
                  '$level',
                  style: AppTypography.titleLarge
                      .copyWith(color: palette.textPrimary),
                ),
              ),
              const SizedBox(width: AppSpacing.xl),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Eyebrow('${l10n.lvlNo.split(' ').first} $level'),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      LevelTitles.forLevel(level, amharic: amharic),
                      style: AppTypography.titleLarge
                          .copyWith(color: palette.textPrimary),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      toNext == 0 ? '$xp XP' : '$toNext XP → ${level + 1}',
                      style: AppTypography.caption
                          .copyWith(color: palette.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Expanded(
      child: GlassPanel(
        blur: false,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Column(
          children: [
            Text(
              value,
              style: AppTypography.headlineSmall
                  .copyWith(color: palette.textPrimary),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              label,
              textAlign: TextAlign.center,
              style: AppTypography.label.copyWith(color: palette.textTertiary),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return GlassPanel(
      blur: false,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.lg,
      ),
      borderRadius: AppRadii.lgAll,
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style:
                  AppTypography.titleSmall.copyWith(color: palette.textPrimary),
            ),
          ),
          Icon(Icons.chevron_right, size: 18, color: palette.textTertiary),
        ],
      ),
    );
  }
}
