import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/widgets.dart';
import '../../recipes/data/recipe_seed_source.dart';
import '../../recipes/domain/recipe_providers.dart';

/// A region, as seeded alongside the recipes.
class Region {
  const Region({
    required this.id,
    required this.name,
    required this.nameAm,
    required this.gradientA,
    required this.gradientB,
  });

  final String id;
  final String name;
  final String nameAm;
  final String gradientA;
  final String gradientB;

  String localisedName({required bool amharic}) => amharic ? nameAm : name;
}

final regionsProvider = FutureProvider<List<Region>>((ref) async {
  final raw = await rootBundle.loadString('assets/seed/recipes.json');
  final json = jsonDecode(raw) as Map<String, dynamic>;
  return (json['regions'] as List).map((entry) {
    final data = (entry as Map).cast<String, dynamic>();
    return Region(
      id: data['id'] as String,
      name: data['name'] as String,
      nameAm: data['nameAm'] as String,
      gradientA: data['gradientA'] as String,
      gradientB: data['gradientB'] as String,
    );
  }).toList(growable: false);
});

/// 16-map — Taste Ethiopia.
///
/// A grid rather than a geographic map. A real map would need boundary data
/// this project has no authoritative source for, and drawing approximate
/// regional borders for a country is not a thing to guess at.
class TasteEthiopiaScreen extends ConsumerWidget {
  const TasteEthiopiaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);
    final amharic = ref.watch(isAmharicProvider);
    final regions = ref.watch(regionsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.mapH1)),
      body: Stack(
        children: [
          const AmbientBackground(),
          regions.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => EmptyView(
              title: l10n.mapH1,
              message: l10n.errorUnknown,
            ),
            data: (all) => FutureBuilder(
              future: ref.watch(recipeSeedSourceProvider).load(),
              builder: (context, snapshot) {
                final catalogue = snapshot.data ?? const [];

                return ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.gutter,
                    AppSpacing.md,
                    AppSpacing.gutter,
                    AppSpacing.screenBottom,
                  ),
                  children: [
                    Text(
                      l10n.mapSub,
                      style: AppTypography.bodyMedium
                          .copyWith(color: palette.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: AppSpacing.md,
                      crossAxisSpacing: AppSpacing.md,
                      childAspectRatio: 1.3,
                      children: [
                        for (final region in all)
                          _RegionTile(
                            region: region,
                            recipeCount: catalogue
                                .where((r) => r.regionId == region.id)
                                .length,
                            amharic: amharic,
                            l10n: l10n,
                          ),
                      ],
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

class _RegionTile extends StatelessWidget {
  const _RegionTile({
    required this.region,
    required this.recipeCount,
    required this.amharic,
    required this.l10n,
  });

  final Region region;
  final int recipeCount;
  final bool amharic;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${region.localisedName(amharic: amharic)}, '
          '$recipeCount recipes',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => context.push(Routes.regionOf(region.id)),
        child: Opacity(
          // A region with nothing to cook yet is dimmed rather than hidden:
          // the point of the screen is showing what is out there.
          opacity: recipeCount == 0 ? 0.45 : 1,
          child: GradientTile.fromHex(
            colorA: region.gradientA,
            colorB: region.gradientB,
            scrim: true,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    region.localisedName(amharic: amharic),
                    style:
                        AppTypography.titleMedium.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    '$recipeCount',
                    style: AppTypography.label.copyWith(color: Colors.white70),
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
