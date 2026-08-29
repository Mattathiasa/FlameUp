import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/cache_entry.dart';
import '../../../core/errors/failure.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/widgets.dart';
import '../domain/recipe.dart';
import '../domain/recipe_providers.dart';
import '../domain/recipe_query.dart';
import 'dish_card.dart';

/// 06-search — Explore.
class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);
    final query = ref.watch(recipeQueryProvider);
    final controller = ref.read(recipeQueryProvider.notifier);
    final results = ref.watch(recipeListProvider);

    return Scaffold(
      body: Stack(
        children: [
          const AmbientBackground(),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: TextField(
                    controller: _search,
                    onChanged: controller.setText,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: l10n.searchPh,
                      prefixIcon:
                          Icon(Icons.search, color: palette.textTertiary),
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () {
                                _search.clear();
                                controller.setText(null);
                              },
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _FilterRow(query: query, controller: controller, l10n: l10n),
                Expanded(
                  child: results.when(
                    loading: () => const _LoadingGrid(),
                    error: (error, _) => ErrorView(
                      failure:
                          error is Failure ? error : const UnknownFailure(),
                      onRetry: () => ref.invalidate(recipeListProvider),
                    ),
                    data: (cached) => _Results(
                      cached: cached,
                      onRetry: () => ref.invalidate(recipeListProvider),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.query,
    required this.controller,
    required this.l10n,
  });

  final RecipeQuery query;
  final RecipeQueryController controller;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
        children: [
          PillChip(
            label: l10n.fAll,
            selected: query.isEmpty,
            onTap: controller.clear,
          ),
          const SizedBox(width: AppSpacing.sm),
          PillChip(
            label: l10n.fFast,
            selected: query.fastingOnly,
            onTap: controller.toggleFasting,
          ),
          const SizedBox(width: AppSpacing.sm),
          PillChip(
            label: l10n.fQuick,
            selected: query.maxMinutes == 30,
            onTap: () =>
                controller.setMaxMinutes(query.maxMinutes == 30 ? null : 30),
          ),
          const SizedBox(width: AppSpacing.sm),
          PillChip(
            label: l10n.fTigray,
            selected: query.regionId == 'tigray',
            onTap: () => controller
                .setRegion(query.regionId == 'tigray' ? null : 'tigray'),
          ),
          const SizedBox(width: AppSpacing.sm),
          PillChip(
            label: l10n.fHot,
            selected: query.sort == RecipeSort.highestRated,
            onTap: () => controller.setSort(
              query.sort == RecipeSort.highestRated
                  ? RecipeSort.recommended
                  : RecipeSort.highestRated,
            ),
          ),
        ],
      ),
    );
  }
}

class _Results extends ConsumerWidget {
  const _Results({required this.cached, required this.onRetry});

  final Cached<List<Recipe>> cached;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);
    final recipes = cached.value;

    if (recipes.isEmpty) {
      return EmptyView(
        title: l10n.empH1,
        message: l10n.empSub,
        actionLabel: l10n.empCta,
        onAction: () => ref.read(recipeQueryProvider.notifier).clear(),
      );
    }

    return Column(
      children: [
        // Cached content is shown, and said to be cached, rather than hidden
        // behind a spinner or presented as live.
        if (cached.refreshFailed)
          StaleBanner(message: l10n.offBanner, onRetry: onRetry),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Row(
            children: [
              Text(
                '${recipes.length} ${l10n.results.replaceAll(RegExp(r'^\d+\s*'), '')}',
                style:
                    AppTypography.label.copyWith(color: palette.textTertiary),
              ),
              const Spacer(),
              if (cached.isRefreshing)
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    valueColor: AlwaysStoppedAnimation(palette.textTertiary),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              0,
              AppSpacing.gutter,
              AppSpacing.screenBottom,
            ),
            itemCount: recipes.length,
            itemBuilder: (context, index) =>
                DishListTile(recipe: recipes[index]),
          ),
        ),
      ],
    );
  }
}

/// Shown only on a genuinely cold cache — rare, because the bundled catalogue
/// means there is almost always something to render.
class _LoadingGrid extends StatelessWidget {
  const _LoadingGrid();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      itemCount: 6,
      itemBuilder: (context, index) => const Padding(
        padding: EdgeInsets.only(bottom: AppSpacing.md),
        child: ShimmerBox(height: 88, borderRadius: AppRadii.cardAll),
      ),
    );
  }
}
