import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/widgets.dart';
import '../../recipes/data/recipe_seed_source.dart';
import '../../recipes/domain/recipe.dart';
import '../../recipes/domain/recipe_providers.dart';
import '../../recipes/presentation/dish_card.dart';
import '../../recipes/presentation/saved_screen.dart';
import '../domain/cooking_controller.dart';
import 'resume_card.dart';

/// `/cook` — the Cook tab.
///
/// Until now this tab mounted the same screen as Explore, which made the tab
/// bar one slot too expensive. This is what the slot promised: everything for
/// the meal you are about to make — the cook in progress, dishes quick enough
/// for tonight, what you saved, and what you last cooked.
class CookHubScreen extends ConsumerWidget {
  const CookHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final resumable = ref.watch(resumableSessionProvider);

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

                return ListView(
                  padding: const EdgeInsets.only(
                    top: AppSpacing.xl,
                    bottom: AppSpacing.screenBottom,
                  ),
                  children: [
                    if (resumable != null && byId[resumable.recipeId] != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.gutter,
                          0,
                          AppSpacing.gutter,
                          AppSpacing.sm,
                        ),
                        child: ResumeCard(
                          recipe: byId[resumable.recipeId]!,
                          step: resumable.currentStep + 1,
                          total: resumable.totalSteps,
                          progress: resumable.progress,
                          amharic: ref.watch(isAmharicProvider),
                          l10n: l10n,
                          onTap: () => context.push(
                            Routes.cookModeOf(resumable.recipeId),
                          ),
                        ),
                      ),
                    _QuickCooks(catalogue: catalogue, l10n: l10n),
                    _SavedForLater(catalogue: catalogue, l10n: l10n),
                    _CookedRecently(catalogue: catalogue, l10n: l10n),
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

/// Dishes that fit in a weeknight: [quickCookMaxMinutes] or less.
class _QuickCooks extends StatelessWidget {
  const _QuickCooks({required this.catalogue, required this.l10n});

  final List<Recipe> catalogue;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final picks = catalogue
        .where((r) => r.totalMinutes > 0 && r.totalMinutes <= 45)
        .toList()
      ..sort((a, b) => a.totalMinutes.compareTo(b.totalMinutes));

    return _Section(
      title: l10n.quickCooks,
      subtitle: l10n.quickCooksSub,
      child: SizedBox(
        height: 250,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: AppSpacing.screenH,
          itemCount: picks.length,
          separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
          itemBuilder: (context, index) => DishCard(recipe: picks[index]),
        ),
      ),
    );
  }
}

/// Bookmarked recipes — the same local, offline-friendly set the Favorites
/// screen reads, surfaced where the decision to actually cook happens.
class _SavedForLater extends ConsumerWidget {
  const _SavedForLater({required this.catalogue, required this.l10n});

  final List<Recipe> catalogue;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedRecipesProvider);
    final recipes = catalogue.where((r) => saved.contains(r.id)).toList();

    return _Section(
      title: l10n.savedH1,
      subtitle: l10n.savedCookSub,
      onMore: recipes.isEmpty ? null : () => context.push(Routes.saved),
      child: recipes.isEmpty
          ? const SizedBox.shrink()
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: AppSpacing.screenH,
              itemCount: recipes.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
              itemBuilder: (context, index) =>
                  DishListTile(recipe: recipes[index]),
            ),
    );
  }
}

/// The cooking history this device actually holds, aggregated per recipe.
class _CookedRecently extends ConsumerWidget {
  const _CookedRecently({required this.catalogue, required this.l10n});

  final List<Recipe> catalogue;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(cookingHistoryProvider);
    if (history.isEmpty) return const SizedBox.shrink();

    final byId = {for (final r in catalogue) r.id: r};
    final rows = <MapEntry<Recipe, int>>[
      for (final entry in history.entries)
        if (byId[entry.key] != null) MapEntry(byId[entry.key]!, entry.value),
    ]..sort((a, b) => b.value.compareTo(a.value));

    return _Section(
      title: l10n.cookedRecently,
      subtitle: l10n.cookedRecentlySub,
      child: Column(
        children: [
          for (final row in rows.take(4))
            _HistoryRow(
              recipe: row.key,
              times: row.value,
              amharic: ref.watch(isAmharicProvider),
              l10n: l10n,
            ),
        ],
      ),
    );
  }
}

/// One "cooked this n times" row.
class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.recipe,
    required this.times,
    required this.amharic,
    required this.l10n,
  });

  final Recipe recipe;
  final int times;
  final bool amharic;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        DishListTile(recipe: recipe),
        Positioned(
          top: AppSpacing.md,
          right: AppSpacing.lg,
          child: Text(
            l10n.cookedTimes(times),
            style: AppTypography.caption.copyWith(
              color: AppPalette.of(context).textTertiary,
            ),
          ),
        ),
      ],
    );
  }
}

/// Shared section chrome: header + subtitle + fixed-height body.
class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.subtitle,
    required this.child,
    this.onMore,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.xxxl,
            AppSpacing.gutter,
            AppSpacing.xxs,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.headlineSmall
                      .copyWith(color: palette.textPrimary),
                ),
              ),
              if (onMore != null)
                TextButton(onPressed: onMore, child: Text(l10n.seeAll)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            0,
            AppSpacing.gutter,
            AppSpacing.xs,
          ),
          child: Text(
            subtitle,
            style: AppTypography.caption.copyWith(color: palette.textTertiary),
          ),
        ),
        child,
      ],
    );
  }
}
