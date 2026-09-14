import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/widgets.dart';
import '../domain/family_recipe.dart';
import '../domain/family_recipe_providers.dart';

/// 18-grandma — Grandma's Kitchen.
///
/// The design shows recorded sessions with named elders. Those recordings do
/// not exist, and inventing people to fill the screen would be fabricating
/// sources for cultural knowledge -- exactly what this project must not do. So
/// the screen leads with the contribution route instead: the archive is built
/// by the people using it, and this screen shows what has been contributed --
/// the public archive, then the visitor's own submissions with their review
/// status.
class GrandmaScreen extends ConsumerWidget {
  const GrandmaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);
    final published = ref.watch(publishedFamilyRecipesProvider).valueOrNull;
    final mine = ref.watch(myFamilyRecipesProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.grandmaH1)),
      body: Stack(
        children: [
          const AmbientBackground(),
          ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.md,
              AppSpacing.gutter,
              AppSpacing.screenBottom,
            ),
            children: [
              Text(
                l10n.grandmaSub,
                style: AppTypography.bodyLarge
                    .copyWith(color: palette.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xxxl),
              GradientTile(
                colorA: const Color(0xFF6B4B2A),
                colorB: const Color(0xFFC79A5E),
                height: 180,
                scrim: true,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.uploadH1,
                        style: AppTypography.headlineMedium
                            .copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        l10n.uploadSub,
                        style: AppTypography.bodySmall
                            .copyWith(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              FlameButton(
                label: l10n.uploadCta,
                onPressed: () => context.push(Routes.familyRecipeNew),
              ),

              // --- the public archive -----------------------------------
              const SizedBox(height: AppSpacing.xxxl),
              Text(
                l10n.archiveTitle,
                style: AppTypography.titleMedium
                    .copyWith(color: palette.textPrimary),
              ),
              const SizedBox(height: AppSpacing.md),
              if (published == null)
                const Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (published.isEmpty)
                EmptyView(title: l10n.archiveTitle, message: l10n.archiveEmpty)
              else
                for (final recipe in published)
                  _RecipeCard(recipe: recipe, l10n: l10n, palette: palette),

              // --- the visitor's own submissions ------------------------
              const SizedBox(height: AppSpacing.xxxl),
              Text(
                l10n.myRecipesTitle,
                style: AppTypography.titleMedium
                    .copyWith(color: palette.textPrimary),
              ),
              const SizedBox(height: AppSpacing.md),
              if (mine == null)
                const Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (mine.isEmpty)
                EmptyView(
                  title: l10n.myRecipesTitle,
                  message: l10n.myRecipesEmpty,
                )
              else
                for (final recipe in mine)
                  _RecipeCard(
                    recipe: recipe,
                    l10n: l10n,
                    palette: palette,
                    showStatus: true,
                  ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  const _RecipeCard({
    required this.recipe,
    required this.l10n,
    required this.palette,
    this.showStatus = false,
  });

  final FamilyRecipe recipe;
  final AppLocalizations l10n;
  final AppPalette palette;
  final bool showStatus;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      blur: false,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recipe.displayName,
                  style: AppTypography.titleSmall
                      .copyWith(color: palette.textPrimary),
                ),
                if (recipe.teacherName.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    recipe.teacherName,
                    style: AppTypography.bodySmall
                        .copyWith(color: palette.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          if (showStatus) ...[
            const SizedBox(width: AppSpacing.sm),
            _StatusChip(status: recipe.status, l10n: l10n),
          ],
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.l10n});

  final FamilyRecipeStatus status;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      FamilyRecipeStatus.draft => (l10n.statusDraft, AppColors.accent),
      FamilyRecipeStatus.pending => (
          l10n.statusPending,
          const Color(0xFFC79A5E),
        ),
      FamilyRecipeStatus.published => (
          l10n.statusPublished,
          const Color(0xFF6B8E4E),
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadii.xs),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(color: color),
      ),
    );
  }
}
