import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/widgets.dart';
import '../../recipes/domain/recipe_providers.dart';
import '../domain/achievements.dart';
import '../domain/progress_providers.dart';

/// 13-achv — the badge grid.
///
/// Locked badges are shown, not hidden: knowing what is available is the point
/// of an achievement list.
class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);
    final amharic = ref.watch(isAmharicProvider);
    final badges = ref.watch(achievementProgressProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.achvH1)),
      body: Stack(
        children: [
          const AmbientBackground(),
          badges.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => EmptyView(
              title: l10n.achvH1,
              message: l10n.errorUnknown,
            ),
            data: (entries) {
              final earned = entries.where((e) => e.$3).length;

              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.gutter,
                  AppSpacing.md,
                  AppSpacing.gutter,
                  AppSpacing.screenBottom,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: AppSpacing.md,
                  crossAxisSpacing: AppSpacing.md,
                  childAspectRatio: 0.78,
                ),
                itemCount: entries.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _Header(
                      earned: earned,
                      total: entries.length,
                      palette: palette,
                    );
                  }
                  final (rule, progress, unlocked) = entries[index - 1];
                  return _Badge(
                    rule: rule,
                    progress: progress,
                    unlocked: unlocked,
                    amharic: amharic,
                    l10n: l10n,
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.earned,
    required this.total,
    required this.palette,
  });

  final int earned;
  final int total;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '$earned / $total',
        style: AppTypography.headlineSmall.copyWith(color: palette.textPrimary),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.rule,
    required this.progress,
    required this.unlocked,
    required this.amharic,
    required this.l10n,
  });

  final AchievementRule rule;
  final double progress;
  final bool unlocked;
  final bool amharic;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final tint = Color(
      int.parse('FF${rule.colour.replaceFirst('#', '')}', radix: 16),
    );

    return Semantics(
      label: '${rule.localisedName(amharic: amharic)}. '
          '${unlocked ? 'earned' : '${(progress * 100).round()}%'}',
      excludeSemantics: true,
      child: GlassPanel(
        blur: false,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Opacity(
              // Locked badges are dimmed rather than blanked, so the shape is
              // still legible and the goal still reads as reachable.
              opacity: unlocked ? 1 : 0.32,
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  gradient: unlocked
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [tint, tint.withOpacity(0.35)],
                        )
                      : null,
                  color: unlocked ? null : palette.fieldFill,
                ),
                child: Center(
                  child: FlameIcon(
                    size: 22,
                    color: unlocked ? Colors.white : palette.textTertiary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              rule.localisedName(amharic: amharic),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.label.copyWith(
                color: unlocked ? palette.textPrimary : palette.textTertiary,
              ),
            ),
            if (!unlocked && progress > 0) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${(progress * 100).round()}%',
                style: AppTypography.badge.copyWith(color: tint),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
