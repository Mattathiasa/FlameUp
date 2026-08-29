import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/failure.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/widgets.dart';
import '../domain/recipe.dart';
import '../domain/recipe_providers.dart';

/// 07-recipe — the detail screen, with ingredients, steps and the story.
class RecipeDetailScreen extends ConsumerWidget {
  const RecipeDetailScreen({required this.recipeId, super.key});

  final String recipeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipe = ref.watch(recipeProvider(recipeId));

    return Scaffold(
      body: recipe.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(
          failure: error is Failure ? error : const UnknownFailure(),
          onRetry: () => ref.invalidate(recipeProvider(recipeId)),
        ),
        data: (cached) =>
            _Content(recipe: cached.value, stale: cached.refreshFailed),
      ),
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({required this.recipe, required this.stale});

  final Recipe recipe;
  final bool stale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);
    final amharic = ref.watch(isAmharicProvider);
    final servings = ref.watch(servingsProvider(recipe.servings));

    return DefaultTabController(
      length: 3,
      child: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            leading: const BackButton(),
            flexibleSpace: FlexibleSpaceBar(
              background: GradientTile.fromHex(
                colorA: recipe.gradientA,
                colorB: recipe.gradientB,
                borderRadius: BorderRadius.zero,
                scrim: true,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (stale) StaleBanner(message: l10n.offBanner),
                  Text(
                    recipe.localisedTitle(amharic: amharic),
                    style: AppTypography.displaySmall
                        .copyWith(color: palette.textPrimary),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    recipe.localisedSubtitle(amharic: amharic),
                    style: AppTypography.bodyMedium
                        .copyWith(color: palette.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  _StatRow(recipe: recipe, amharic: amharic, l10n: l10n),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: TabBar(
              labelColor: AppColors.accent,
              unselectedLabelColor: palette.textSecondary,
              indicatorColor: AppColors.accent,
              tabs: [
                Tab(text: l10n.ingredients),
                Tab(text: l10n.steps),
                Tab(text: l10n.story),
              ],
            ),
          ),
        ],
        body: Column(
          children: [
            Expanded(
              child: TabBarView(
                children: [
                  _IngredientsTab(
                    recipe: recipe,
                    servings: servings,
                    amharic: amharic,
                  ),
                  _StepsTab(recipe: recipe, amharic: amharic),
                  _StoryTab(recipe: recipe, amharic: amharic),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: FlameButton(
                label: l10n.startCooking,
                onPressed: () => context.push(Routes.cookModeOf(recipe.id)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.recipe,
    required this.amharic,
    required this.l10n,
  });

  final Recipe recipe;
  final bool amharic;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Stat(
          label: l10n.timeLbl,
          value: recipe.formattedTime(amharic: amharic),
        ),
        _Stat(label: l10n.heatLbl, value: '${recipe.heatLevel + 1}/5'),
        _Stat(label: l10n.yieldLbl, value: '${recipe.servings}'),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow(label),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            value,
            style:
                AppTypography.titleMedium.copyWith(color: palette.textPrimary),
          ),
        ],
      ),
    );
  }
}

/// Ingredients, rescaled live as the serving count changes.
class _IngredientsTab extends ConsumerWidget {
  const _IngredientsTab({
    required this.recipe,
    required this.servings,
    required this.amharic,
  });

  final Recipe recipe;
  final int servings;
  final bool amharic;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);
    final scaled = recipe.ingredientsFor(servings);
    final controller = ref.read(servingsProvider(recipe.servings).notifier);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, AppSpacing.screenBottom),
      children: [
        GlassPanel(
          blur: false,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.serves.replaceAll(RegExp(r'\d+'), '$servings'),
                  style: AppTypography.titleSmall
                      .copyWith(color: palette.textPrimary),
                ),
              ),
              IconButton(
                onPressed: servings > 1 ? controller.decrement : null,
                icon: const Icon(Icons.remove_circle_outline),
                tooltip: 'Fewer servings',
              ),
              Text(
                '$servings',
                style: AppTypography.titleMedium
                    .copyWith(color: palette.textPrimary),
              ),
              IconButton(
                onPressed: servings < 20 ? controller.increment : null,
                icon: const Icon(Icons.add_circle_outline),
                tooltip: 'More servings',
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        for (final ingredient in scaled)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    amharic ? ingredient.nameAm : ingredient.name,
                    style: AppTypography.bodyMedium
                        .copyWith(color: palette.textPrimary),
                  ),
                ),
                Text(
                  ingredient.displayAmount(amharic: amharic),
                  style: AppTypography.bodyMedium
                      .copyWith(color: palette.textSecondary),
                ),
                if (ingredient.optional)
                  Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.xs),
                    child: Text(
                      '·',
                      style: AppTypography.caption
                          .copyWith(color: palette.textTertiary),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _StepsTab extends StatelessWidget {
  const _StepsTab({required this.recipe, required this.amharic});

  final Recipe recipe;
  final bool amharic;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, AppSpacing.screenBottom),
      itemCount: recipe.steps.length,
      itemBuilder: (context, index) {
        final step = recipe.steps[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xl),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: palette.glassRaised,
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: AppTypography.label
                        .copyWith(color: palette.textSecondary),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.localisedText(amharic: amharic),
                      style: AppTypography.bodyMedium
                          .copyWith(color: palette.textPrimary),
                    ),
                    if (step.hasTimer) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            size: 13,
                            color: palette.textTertiary,
                          ),
                          const SizedBox(width: AppSpacing.xxs),
                          Text(
                            _formatDuration(step.duration!),
                            style: AppTypography.label
                                .copyWith(color: palette.textTertiary),
                          ),
                        ],
                      ),
                    ],
                    if (step.localisedTip(amharic: amharic) != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        step.localisedTip(amharic: amharic)!,
                        style: AppTypography.caption
                            .copyWith(color: AppColors.accent),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static String _formatDuration(Duration duration) {
    if (duration.inMinutes >= 60) {
      final hours = duration.inHours;
      final minutes = duration.inMinutes % 60;
      return minutes == 0 ? '${hours}h' : '${hours}h ${minutes}m';
    }
    return '${duration.inMinutes}m';
  }
}

class _StoryTab extends StatelessWidget {
  const _StoryTab({required this.recipe, required this.amharic});

  final Recipe recipe;
  final bool amharic;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, AppSpacing.screenBottom),
      children: [
        Text(
          recipe.localisedStory(amharic: amharic),
          style: AppTypography.bodyLarge.copyWith(color: palette.textSecondary),
        ),
      ],
    );
  }
}
