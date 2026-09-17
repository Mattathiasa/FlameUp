import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/widgets.dart';
import '../../family_recipes/domain/family_recipe_cookable.dart';
import '../../recipes/domain/recipe_providers.dart';
import '../data/cooking_repository.dart';

/// 09-done — the finished screen.
///
/// Shows what was earned. The numbers come from the server once the reward
/// function has run; until then this reports the dish as finished without
/// inventing an XP figure, because the client does not decide rewards.
class CookDoneScreen extends ConsumerWidget {
  const CookDoneScreen({required this.sessionId, super.key});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);
    final amharic = ref.watch(isAmharicProvider);
    final session = ref.watch(cookingRepositoryProvider).byId(sessionId);
    final isFamilyCook =
        FamilyRecipeAsCookable.isFamilyId(session?.recipeId ?? '');

    if (session == null) {
      return Scaffold(
        body: EmptyView(
          title: l10n.errH1,
          message: l10n.errSub,
          actionLabel: l10n.errBack,
          onAction: () => context.go(Routes.home),
        ),
      );
    }

    final recipe =
        ref.watch(recipeProvider(session.recipeId)).valueOrNull?.value;

    return Scaffold(
      body: Stack(
        children: [
          const AmbientBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const Spacer(),
                  const FlameIcon(size: 72, animate: true),
                  const SizedBox(height: AppSpacing.xxl),
                  Text(
                    recipe == null
                        ? l10n.doneH1
                        : '${recipe.localisedTitle(amharic: amharic)}.',
                    textAlign: TextAlign.center,
                    style: AppTypography.displaySmall
                        .copyWith(color: palette.textPrimary),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    l10n.doneSub,
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMedium
                        .copyWith(color: palette.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.xxxl),

                  // The reward is granted server-side. Showing a figure the
                  // client made up would be a lie the moment the two
                  // disagreed, so this states what is pending instead.
                  // A family recipe carries no reward (xpReward 0): its cooks
                  // are not earning XP, they are proving a dish — so the
                  // panel hides rather than promising a fake zero.
                  if (recipe != null && recipe.xpReward > 0)
                    GlassPanel(
                      blur: false,
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          XpBadge(xp: recipe.xpReward),
                          const SizedBox(width: AppSpacing.md),
                          Flexible(
                            child: Text(
                              l10n.toNext,
                              style: AppTypography.caption
                                  .copyWith(color: palette.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const Spacer(),
                  // Family dishes are rated by VOUCHES, not stars — the
                  // catalogue rating flow has no meaning here and would
                  // strand reviews under a recipe id the catalogue does not
                  // know. A family cook heads home; the completed session
                  // still counts for history and for proof-of-cook.
                  FlameButton(
                    label: isFamilyCook ? l10n.errBack : l10n.rateIt,
                    onPressed: isFamilyCook
                        ? () => context.go(Routes.home)
                        : () => context
                            .pushReplacement(Routes.cookRateOf(sessionId)),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (!isFamilyCook)
                    SizedBox(
                      height: 50,
                      child: OutlinedButton(
                        onPressed: () => context.go(Routes.home),
                        child: Text(l10n.errBack),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
