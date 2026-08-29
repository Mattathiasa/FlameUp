import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/widgets.dart';
import '../../recipes/data/recipe_seed_source.dart';
import '../../recipes/domain/recipe_providers.dart';
import '../domain/mastery.dart';
import '../domain/progress_providers.dart';

/// 12-mastery — "What your hands know".
class MasteryScreen extends ConsumerWidget {
  const MasteryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);
    final amharic = ref.watch(isAmharicProvider);
    final progress = ref.watch(userProgressProvider).valueOrNull?.value;
    final recipes = ref.watch(recipeSeedSourceProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.masteryH1)),
      body: Stack(
        children: [
          const AmbientBackground(),
          FutureBuilder(
            future: recipes.load(),
            builder: (context, snapshot) {
              final all = snapshot.data;
              if (all == null) {
                return const Center(child: CircularProgressIndicator());
              }

              final mastery = progress?.mastery ?? const {};
              // Only dishes actually attempted; an untouched catalogue would
              // be a list of zeroes, which tells the user nothing.
              final tracked =
                  all.where((r) => (mastery[r.id]?.cookCount ?? 0) > 0).toList()
                    ..sort(
                      (a, b) => (mastery[b.id]?.cookCount ?? 0)
                          .compareTo(mastery[a.id]?.cookCount ?? 0),
                    );

              if (tracked.isEmpty) {
                return EmptyView(
                  title: l10n.masteryH1,
                  message: l10n.masterySub,
                );
              }

              return ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.gutter,
                  AppSpacing.md,
                  AppSpacing.gutter,
                  AppSpacing.screenBottom,
                ),
                children: [
                  Text(
                    l10n.masterySub,
                    style: AppTypography.bodyMedium
                        .copyWith(color: palette.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  for (final recipe in tracked)
                    _MasteryRow(
                      title: recipe.localisedTitle(amharic: amharic),
                      mastery: mastery[recipe.id]!,
                      colour: recipe.gradientB,
                      amharic: amharic,
                      l10n: l10n,
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MasteryRow extends StatelessWidget {
  const _MasteryRow({
    required this.title,
    required this.mastery,
    required this.colour,
    required this.amharic,
    required this.l10n,
  });

  final String title;
  final RecipeMastery mastery;
  final String colour;
  final bool amharic;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final tint =
        Color(int.parse('FF${colour.replaceFirst('#', '')}', radix: 16));

    return GlassPanel(
      blur: false,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.titleSmall
                      .copyWith(color: palette.textPrimary),
                ),
              ),
              Text(
                mastery.level.localised(amharic: amharic),
                style: AppTypography.label.copyWith(color: tint),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          FlameProgressBar(
            value: mastery.progress,
            color: tint,
            semanticLabel: title,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            mastery.cooksToNext == 0
                ? '${mastery.cookCount}×'
                : '${mastery.cookCount}× · ${mastery.cooksToNext} to '
                    '${mastery.level.next?.localised(amharic: amharic) ?? ''}',
            style: AppTypography.caption.copyWith(color: palette.textTertiary),
          ),
        ],
      ),
    );
  }
}
