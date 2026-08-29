import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/widgets.dart';
import '../../recipes/domain/recipe_providers.dart';
import '../domain/progress_providers.dart';
import '../domain/quests.dart';

/// 14-quests.
class QuestsScreen extends ConsumerWidget {
  const QuestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final amharic = ref.watch(isAmharicProvider);
    final progress = ref.watch(userProgressProvider).valueOrNull?.value;
    final now = DateTime.now();

    // Anything the server has not issued yet is shown unstarted, so the list
    // is never empty on a first run.
    final active = <String, QuestProgress>{
      for (final quest in progress?.quests ?? const <QuestProgress>[])
        quest.questId: quest,
    };

    return Scaffold(
      appBar: AppBar(title: Text(l10n.questsH1)),
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
              for (final cadence in QuestCadence.values) ...[
                Eyebrow(_cadenceLabel(cadence, l10n)),
                const SizedBox(height: AppSpacing.md),
                for (final rule
                    in Quests.all.where((r) => r.cadence == cadence))
                  _QuestCard(
                    rule: rule,
                    progress: active[rule.id],
                    amharic: amharic,
                    now: now,
                  ),
                const SizedBox(height: AppSpacing.xxl),
              ],
            ],
          ),
        ],
      ),
    );
  }

  static String _cadenceLabel(QuestCadence cadence, AppLocalizations l10n) =>
      switch (cadence) {
        QuestCadence.daily => l10n.qDaily,
        QuestCadence.weekly => l10n.qWeekly,
        QuestCadence.seasonal => l10n.qSeason,
      };
}

class _QuestCard extends StatelessWidget {
  const _QuestCard({
    required this.rule,
    required this.progress,
    required this.amharic,
    required this.now,
  });

  final QuestRule rule;
  final QuestProgress? progress;
  final bool amharic;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final tint = Color(
      int.parse('FF${rule.colour.replaceFirst('#', '')}', radix: 16),
    );

    final done = progress?.progress ?? 0;
    final complete = progress?.isComplete ?? false;
    final expired = progress?.hasExpired(now) ?? false;

    return Semantics(
      label: '${rule.localisedName(amharic: amharic)}. '
          '$done of ${rule.target}',
      excludeSemantics: true,
      child: GlassPanel(
        blur: false,
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Opacity(
          opacity: expired ? 0.45 : 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      rule.localisedName(amharic: amharic),
                      style: AppTypography.titleSmall
                          .copyWith(color: palette.textPrimary),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  if (complete)
                    Icon(Icons.check_circle, size: 20, color: tint)
                  else
                    XpBadge(xp: rule.xpReward, compact: true),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              FlameProgressBar(
                value: rule.target == 0 ? 0 : done / rule.target,
                color: tint,
                animate: false,
                semanticLabel: rule.localisedName(amharic: amharic),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '$done / ${rule.target}',
                style:
                    AppTypography.caption.copyWith(color: palette.textTertiary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
