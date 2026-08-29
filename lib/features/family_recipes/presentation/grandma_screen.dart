import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/widgets.dart';

/// 18-grandma — Grandma's Kitchen.
///
/// The design shows recorded sessions with named elders. Those recordings do
/// not exist, and inventing people to fill the screen would be fabricating
/// sources for cultural knowledge -- exactly what this project must not do. So
/// the screen leads with the contribution route instead: the archive is built
/// by the people using it.
class GrandmaScreen extends ConsumerWidget {
  const GrandmaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);

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
              const SizedBox(height: AppSpacing.xxxl),
              EmptyView(
                title: l10n.empH1,
                message: l10n.uploadNote,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
