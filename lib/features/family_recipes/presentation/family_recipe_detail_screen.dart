import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/failure.dart';
import '../../../core/result/result.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/widgets.dart';
import '../../auth/domain/auth_providers.dart';
import '../../community/data/community_repository.dart';
import '../../recipes/domain/recipe_providers.dart' show isAmharicProvider;
import '../data/family_recipe_repository.dart';
import '../domain/family_recipe.dart';
import '../domain/family_recipe_providers.dart';

/// The detail view for one recipe in Grandma's Kitchen.
///
/// This is where community verification lives: the vouch state is the first
/// thing under the title, and the "I cooked this" button is the one action
/// the screen exists to offer. A pending recipe shows its progress toward
/// the three vouches that publish it; a draft shows only to its author.
class FamilyRecipeDetailScreen extends ConsumerWidget {
  const FamilyRecipeDetailScreen({super.key, required this.recipeId});

  final String recipeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipeAsync = ref.watch(familyRecipeByIdProvider(recipeId));

    return Scaffold(
      appBar: AppBar(),
      body: recipeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => ErrorView(
          failure: const UnknownFailure(),
          onRetry: () => ref.invalidate(familyRecipeByIdProvider(recipeId)),
        ),
        data: (recipe) {
          if (recipe == null) {
            return ErrorView(
              failure: const NotFoundFailure(),
              onRetry: () => context.pop(),
            );
          }
          return _Content(recipe: recipe);
        },
      ),
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({required this.recipe});

  final FamilyRecipe recipe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);
    final amharic = ref.watch(isAmharicProvider);
    final uid = ref.watch(currentUidProvider);
    final isAuthor = uid != null && uid == recipe.authorId;
    final steps = recipe.stepLines;
    final ingredients = recipe.ingredientsText
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.md,
        AppSpacing.gutter,
        AppSpacing.screenBottom,
      ),
      children: [
        if (recipe.mediaUrl != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            child: Image.network(
              recipe.mediaUrl!,
              height: 220,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                (amharic && recipe.titleAm.isNotEmpty)
                    ? recipe.titleAm
                    : recipe.displayName,
                style: AppTypography.headlineMedium
                    .copyWith(color: palette.textPrimary),
              ),
            ),
            if (recipe.status == FamilyRecipeStatus.published)
              _VouchBadge(recipe: recipe, uid: uid)
            else if (isAuthor)
              _StatusChip(status: recipe.status, l10n: l10n),
          ],
        ),
        if (recipe.teacherName.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            recipe.teacherName,
            style:
                AppTypography.bodyMedium.copyWith(color: palette.textSecondary),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),

        // --- verification -------------------------------------------------
        _VerificationPanel(recipe: recipe, isAuthor: isAuthor),

        // --- ingredients ---------------------------------------------------
        if (ingredients.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xxl),
          Eyebrow(l10n.fIngredients),
          const SizedBox(height: AppSpacing.sm),
          for (final ingredient in ingredients)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Text(
                ingredient,
                style: AppTypography.bodyMedium
                    .copyWith(color: palette.textPrimary),
              ),
            ),
        ],

        // --- steps ---------------------------------------------------------
        if (steps.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          Eyebrow(l10n.fSteps),
          const SizedBox(height: AppSpacing.sm),
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
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
                        '${i + 1}',
                        style: AppTypography.label
                            .copyWith(color: palette.textSecondary),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      steps[i],
                      style: AppTypography.bodyMedium
                          .copyWith(color: palette.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
        ],

        // --- story ---------------------------------------------------------
        if (recipe.story.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          Eyebrow(l10n.story),
          const SizedBox(height: AppSpacing.sm),
          Text(
            recipe.story,
            style:
                AppTypography.bodyLarge.copyWith(color: palette.textSecondary),
          ),
        ],

        // --- versions of this recipe ---------------------------------------
        const SizedBox(height: AppSpacing.xxl),
        _VersionsSection(recipe: recipe),
      ],
    );
  }
}

/// The published household takes on this recipe, each linking to its detail,
/// with the one-tap path to add your own.
class _VersionsSection extends ConsumerWidget {
  const _VersionsSection({required this.recipe});

  final FamilyRecipe recipe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);
    final variants = ref.watch(familyVariantsOfProvider(recipe.id)).valueOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.versionsTitle,
                style: AppTypography.titleMedium
                    .copyWith(color: palette.textPrimary),
              ),
            ),
            TextButton.icon(
              onPressed: () =>
                  context.push(Routes.familyRecipeVersionOf(recipe.id)),
              icon: const Icon(Icons.add, size: 18),
              label: Text(l10n.addYourVersion),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (variants == null)
          const Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (variants.isEmpty)
          Text(
            l10n.versionsEmpty,
            style:
                AppTypography.bodyMedium.copyWith(color: palette.textSecondary),
          )
        else
          for (final variant in variants)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: GlassPanel(
                blur: false,
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: InkWell(
                  onTap: () =>
                      context.push(Routes.familyRecipeDetailOf(variant.id)),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              variant.displayName,
                              style: AppTypography.titleSmall.copyWith(
                                color: palette.textPrimary,
                              ),
                            ),
                            if (variant.variantLabel != null &&
                                variant.variantLabel!.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.xxs),
                              Text(
                                variant.variantLabel!,
                                style: AppTypography.bodySmall.copyWith(
                                  color: palette.textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (variant.verificationCount >=
                          FamilyRecipeRepository.publishThreshold)
                        const Icon(
                          Icons.verified,
                          size: 18,
                          color: AppColors.green,
                        ),
                      const Icon(
                        Icons.chevron_right,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
      ],
    );
  }
}

/// The vouch state under the title: count + badge for a published recipe.
class _VouchBadge extends StatelessWidget {
  const _VouchBadge({required this.recipe, required this.uid});

  final FamilyRecipe recipe;
  final String? uid;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final vouched = recipe.verifiedByUser(uid);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: AppColors.green.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadii.xs),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            vouched ? Icons.verified : Icons.workspace_premium_outlined,
            size: 14,
            color: AppColors.green,
          ),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            recipe.verificationCount >= FamilyRecipeRepository.publishThreshold
                ? l10n.verifiedBadge
                : l10n.verifyCount.replaceAll(
                    '3',
                    '${recipe.verificationCount}',
                  ),
            style: AppTypography.caption.copyWith(color: AppColors.green),
          ),
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
      FamilyRecipeStatus.pending => (l10n.statusPending, AppColors.gold),
      FamilyRecipeStatus.published => (l10n.statusPublished, AppColors.green),
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
      child: Text(label, style: AppTypography.caption.copyWith(color: color)),
    );
  }
}

/// The verification panel: for everyone but the author it offers the vouch;
/// for the author it shows the same progress honestly — who backs the recipe
/// and how far it is from publishing itself.
class _VerificationPanel extends ConsumerWidget {
  const _VerificationPanel({required this.recipe, required this.isAuthor});

  final FamilyRecipe recipe;
  final bool isAuthor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);
    final uid = ref.watch(currentUidProvider);
    const threshold = FamilyRecipeRepository.publishThreshold;
    final count = recipe.verificationCount;

    return GlassPanel(
      blur: false,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.workspace_premium_outlined,
                size: 18,
                color: AppColors.gold,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  recipe.status == FamilyRecipeStatus.published
                      ? l10n.verifyCount.replaceAll('3', '$count')
                      : l10n.reviewTitle,
                  style: AppTypography.titleSmall
                      .copyWith(color: palette.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // Progress toward the threshold, vouch by vouch.
          Row(
            children: [
              for (var i = 0; i < threshold; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.xxs),
                Icon(
                  i < count ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 16,
                  color: i < count ? AppColors.green : palette.textTertiary,
                ),
              ],
              const SizedBox(width: AppSpacing.sm),
              Text(
                count >= threshold ? l10n.verifiedBadge : '$count / $threshold',
                style: AppTypography.label.copyWith(
                  color: count >= threshold
                      ? AppColors.green
                      : palette.textSecondary,
                ),
              ),
            ],
          ),
          if (!isAuthor && recipe.status != FamilyRecipeStatus.draft) ...[
            const SizedBox(height: AppSpacing.lg),
            FlameButton(
              label: recipe.verifiedByUser(uid)
                  ? l10n.verifiedBadge
                  : l10n.verifyCta,
              onPressed: recipe.verifiedByUser(uid)
                  ? null
                  : () => _vouch(context, ref),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _vouch(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.verifyConfirmTitle),
        content: Text(l10n.verifyConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.verifyCta),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false)) return;

    final uid = ref.read(currentUidProvider);
    if (uid == null) return;

    // Resolve the vouching cook's name for the notification. A missing
    // directory card (guests, fresh accounts) degrades to a generic label
    // rather than blocking the vouch.
    final directory =
        await ref.read(communityRepositoryProvider).directoryEntry(uid);
    final name = directory?.displayName ?? l10n.genericCookName;

    final result = await ref
        .read(familyRecipeRepositoryProvider)
        .verify(recipeId: recipe.id, uid: uid, vouchingName: name);

    if (!context.mounted) return;
    final message = switch (result) {
      Ok() => null,
      Err(:final failure) => failureMessage(context, failure),
    };
    if (message != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }
}
