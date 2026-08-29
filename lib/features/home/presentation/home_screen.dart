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
import '../../cooking/domain/cooking_controller.dart';
import '../../gamification/domain/progress_providers.dart';
import '../../onboarding/domain/onboarding_providers.dart';
import '../../recipes/data/recipe_seed_source.dart';
import '../../recipes/domain/recipe.dart';
import '../../recipes/domain/recipe_providers.dart';
import '../../recipes/presentation/dish_card.dart';

/// 05-home — Today.
///
/// Everything here is derived from real state: the greeting from the signed-in
/// user, the resume card from an actual in-flight session, the suggestions
/// from the user's own heat tolerance and dietary answers.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);
    final amharic = ref.watch(isAmharicProvider);
    final user = ref.watch(authUserProvider).valueOrNull;
    final streak = ref.watch(liveStreakProvider);
    final resumable = ref.watch(resumableSessionProvider);
    final answers = ref.watch(onboardingControllerProvider);

    return Scaffold(
      body: Stack(
        children: [
          const AmbientBackground(),
          SafeArea(
            bottom: false,
            child: FutureBuilder(
              future: ref.watch(recipeSeedSourceProvider).load(),
              builder: (context, snapshot) {
                final catalogue = snapshot.data ?? const <Recipe>[];
                final byId = {for (final r in catalogue) r.id: r};

                // Suggestions honour what onboarding was told: nothing hotter
                // than the user said they could take, and fasting dishes if
                // they said they fast.
                final suggestions = catalogue
                    .where((r) => r.heatLevel <= answers.heat.value)
                    .where(
                      (r) =>
                          !answers.dietary
                              .map((d) => d.key)
                              .contains('dFast') ||
                          r.isFasting,
                    )
                    .take(6)
                    .toList();

                return ListView(
                  padding: const EdgeInsets.only(
                    top: AppSpacing.xl,
                    bottom: AppSpacing.screenBottom,
                  ),
                  children: [
                    Padding(
                      padding: AppSpacing.screenH,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.greeting,
                                  style: AppTypography.bodySmall
                                      .copyWith(color: palette.textSecondary),
                                ),
                                const SizedBox(height: AppSpacing.xxs),
                                Text(
                                  user?.shortName.isNotEmpty ?? false
                                      ? user!.shortName
                                      : l10n.guestBadge,
                                  style: AppTypography.displaySmall
                                      .copyWith(color: palette.textPrimary),
                                ),
                              ],
                            ),
                          ),
                          _StreakPill(
                            streak: streak,
                            onTap: () => context.push(Routes.streak),
                          ),
                        ],
                      ),
                    ),
                    if (resumable != null && byId[resumable.recipeId] != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.gutter,
                          AppSpacing.xl,
                          AppSpacing.gutter,
                          0,
                        ),
                        child: _ResumeCard(
                          recipe: byId[resumable.recipeId]!,
                          step: resumable.currentStep + 1,
                          total: resumable.totalSteps,
                          progress: resumable.progress,
                          amharic: amharic,
                          l10n: l10n,
                          onTap: () => context.push(
                            Routes.cookModeOf(resumable.recipeId),
                          ),
                        ),
                      ),
                    SectionHeader(
                      title: l10n.cookTonight,
                      actionLabel: l10n.seeAll,
                      onAction: () => context.go(Routes.discover),
                    ),
                    SizedBox(
                      height: 250,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: AppSpacing.screenH,
                        itemCount: suggestions.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: AppSpacing.md),
                        itemBuilder: (context, index) =>
                            DishCard(recipe: suggestions[index]),
                      ),
                    ),
                    SectionHeader(title: l10n.fromRegion),
                    Padding(
                      padding: AppSpacing.screenH,
                      child: GestureDetector(
                        onTap: () => context.go(Routes.tasteEthiopia),
                        child: GradientTile(
                          colorA: const Color(0xFF1E5A34),
                          colorB: const Color(0xFF4FA766),
                          height: 140,
                          scrim: true,
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.xl),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Eyebrow(l10n.thisWeek, color: Colors.white70),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  l10n.gurageTitle,
                                  style: AppTypography.headlineMedium
                                      .copyWith(color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StreakPill extends StatelessWidget {
  const _StreakPill({required this.streak, required this.onTap});

  final int streak;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Semantics(
      button: true,
      label: '$streak day streak',
      excludeSemantics: true,
      child: GlassPanel(
        blur: false,
        borderRadius: AppRadii.pillAll,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        onTap: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FlameIcon(
              size: 15,
              color: streak > 0 ? AppColors.accent : palette.textTertiary,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              '$streak',
              style:
                  AppTypography.titleSmall.copyWith(color: palette.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResumeCard extends StatelessWidget {
  const _ResumeCard({
    required this.recipe,
    required this.step,
    required this.total,
    required this.progress,
    required this.amharic,
    required this.l10n,
    required this.onTap,
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
