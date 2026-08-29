import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/widgets.dart';
import '../../recipes/data/recipe_seed_source.dart';
import '../../recipes/domain/recipe_providers.dart';
import '../../recipes/presentation/dish_card.dart';
import 'taste_ethiopia_screen.dart';

/// 17-region — the dishes of one region.
class RegionScreen extends ConsumerWidget {
  const RegionScreen({required this.regionId, super.key});

  final String regionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);
    final amharic = ref.watch(isAmharicProvider);
    final regions = ref.watch(regionsProvider).valueOrNull ?? const <Region>[];
    final region = regions.where((r) => r.id == regionId).firstOrNull;

    return Scaffold(
      body: FutureBuilder(
        future: ref.watch(recipeSeedSourceProvider).load(),
        builder: (context, snapshot) {
          final catalogue = snapshot.data;
          if (catalogue == null || region == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final dishes =
              catalogue.where((r) => r.regionId == regionId).toList();

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                leading: const BackButton(),
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(region.localisedName(amharic: amharic)),
                  background: GradientTile.fromHex(
                    colorA: region.gradientA,
                    colorB: region.gradientB,
                    borderRadius: BorderRadius.zero,
                    scrim: true,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.gutter,
                  AppSpacing.xl,
                  AppSpacing.gutter,
                  AppSpacing.screenBottom,
                ),
                sliver: dishes.isEmpty
                    ? SliverToBoxAdapter(
                        child: EmptyView(
                          title: region.localisedName(amharic: amharic),
                          message: l10n.empSub,
                        ),
                      )
                    : SliverList.builder(
                        itemCount: dishes.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.xl,
                              ),
                              child: Text(
                                l10n.dishesFrom,
                                style: AppTypography.headlineSmall
                                    .copyWith(color: palette.textPrimary),
                              ),
                            );
                          }
                          return DishListTile(recipe: dishes[index - 1]);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
