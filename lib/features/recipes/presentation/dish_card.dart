import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/widgets.dart';
import '../domain/recipe.dart';
import '../domain/recipe_providers.dart';

/// The dish card from the design — a gradient tile with the XP badge over it,
/// and title, subtitle and metadata beneath.
///
/// Two shapes: [DishCard] for the horizontal rails on Today (184px wide), and
/// [DishListTile] for vertical lists.
class DishCard extends ConsumerWidget {
  const DishCard({required this.recipe, this.width = 184, super.key});

  final Recipe recipe;
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final amharic = ref.watch(isAmharicProvider);

    return Semantics(
      button: true,
      label: '${recipe.localisedTitle(amharic: amharic)}. '
          '${recipe.formattedTime(amharic: amharic)}',
      excludeSemantics: true,
      child: SizedBox(
        width: width,
        child: GlassPanel(
          // No blur: these sit in a scrolling rail, and a BackdropFilter per
          // card is the most expensive thing on the screen.
          blur: false,
          onTap: () => context.push(Routes.recipeDetailOf(recipe.id)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                children: [
                  GradientTile.fromHex(
                    colorA: recipe.gradientA,
                    colorB: recipe.gradientB,
                    height: 124,
                    borderRadius: BorderRadius.zero,
                  ),
                  Positioned(
                    right: 10,
                    top: 10,
                    child: XpBadge(xp: recipe.xpReward, compact: true),
                  ),
                  if (recipe.isFasting)
                    Positioned(
                      left: 10,
                      top: 10,
                      child: _Tag(
                        label: amharic ? 'ጾም' : 'Fasting',
                        colour: AppColors.green,
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(13, 12, 13, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.localisedTitle(amharic: amharic),
                      style: AppTypography.titleMedium
                          .copyWith(color: palette.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      recipe.localisedSubtitle(amharic: amharic),
                      style: AppTypography.caption
                          .copyWith(color: palette.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 9),
                    _Meta(recipe: recipe, amharic: amharic, palette: palette),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A full-width row, for search results and saved lists.
class DishListTile extends ConsumerWidget {
  const DishListTile({required this.recipe, super.key});

  final Recipe recipe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final amharic = ref.watch(isAmharicProvider);

    return Semantics(
      button: true,
      label: recipe.localisedTitle(amharic: amharic),
      excludeSemantics: true,
      child: GlassPanel(
        blur: false,
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.md),
        onTap: () => context.push(Routes.recipeDetailOf(recipe.id)),
        child: Row(
          children: [
            GradientTile.fromHex(
              colorA: recipe.gradientA,
              colorB: recipe.gradientB,
              width: 64,
              height: 64,
              borderRadius: AppRadii.lgAll,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    recipe.localisedTitle(amharic: amharic),
                    style: AppTypography.titleSmall
                        .copyWith(color: palette.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    recipe.localisedSubtitle(amharic: amharic),
                    style: AppTypography.caption
                        .copyWith(color: palette.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 7),
                  _Meta(recipe: recipe, amharic: amharic, palette: palette),
                ],
              ),
            ),
            XpBadge(xp: recipe.xpReward, compact: true),
          ],
        ),
      ),
    );
  }
}

/// Time · difficulty, with a dot between, as the design has it.
class _Meta extends StatelessWidget {
  const _Meta({
    required this.recipe,
    required this.amharic,
    required this.palette,
  });

  final Recipe recipe;
  final bool amharic;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.label.copyWith(color: palette.textTertiary);

    return Row(
      children: [
        Text(recipe.formattedTime(amharic: amharic), style: style),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Container(
            width: 3,
            height: 3,
            decoration: BoxDecoration(
              color: palette.textTertiary,
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
          ),
        ),
        Flexible(
          child: Text(
            _difficultyLabel(recipe.difficulty, amharic: amharic),
            style: style,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  static String _difficultyLabel(
    Difficulty difficulty, {
    required bool amharic,
  }) =>
      switch (difficulty) {
        Difficulty.beginner => amharic ? 'ጀማሪ' : 'Beginner',
        Difficulty.medium => amharic ? 'መካከለኛ' : 'Medium',
        Difficulty.advanced => amharic ? 'ከፍተኛ' : 'Advanced',
      };
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.colour});

  final String label;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colour.withOpacity(0.9),
        borderRadius: BorderRadius.circular(AppRadii.xs),
      ),
      child: Text(
        label,
        style: AppTypography.badge.copyWith(color: Colors.white),
      ),
    );
  }
}
