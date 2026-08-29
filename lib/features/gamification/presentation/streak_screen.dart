import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/widgets.dart';
import '../domain/progress_providers.dart';
import '../domain/streak_calculator.dart';

/// 15-streak.
class StreakScreen extends ConsumerWidget {
  const StreakScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);
    final progress = ref.watch(userProgressProvider).valueOrNull?.value;
    final streak = ref.watch(liveStreakProvider);
    final atRisk = ref.watch(streakAtRiskProvider);

    final state = progress?.streak ?? const StreakState();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.streakH1)),
      body: Stack(
        children: [
          const AmbientBackground(),
          ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.xl,
              AppSpacing.gutter,
              AppSpacing.screenBottom,
            ),
            children: [
              Center(
                child: Column(
                  children: [
                    FlameIcon(
                      size: 84,
                      animate: streak > 0,
                      color:
                          streak > 0 ? AppColors.accent : palette.textTertiary,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      '$streak',
                      style: AppTypography.displayLarge
                          .copyWith(color: palette.textPrimary),
                    ),
                    Text(
                      l10n.stStreak,
                      style: AppTypography.bodyMedium
                          .copyWith(color: palette.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxxl),

              // Said plainly rather than left to be discovered by losing it.
              if (atRisk)
                GlassPanel(
                  blur: false,
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        size: 18,
                        color: AppColors.gold,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          l10n.freezeSub,
                          style: AppTypography.caption
                              .copyWith(color: palette.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),

              GlassPanel(
                blur: false,
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Row(
                      label: l10n.streakSub.split(':').first,
                      value: '${state.longest}',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _Row(
                      label: l10n.freeze,
                      value: '${state.freezeDaysLeft}',
                    ),
                    if (state.lastCookedOn != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      _Row(
                        label: l10n.stDishes,
                        value: state.lastCookedOn!,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style:
                AppTypography.bodyMedium.copyWith(color: palette.textSecondary),
          ),
        ),
        Text(
          value,
          style: AppTypography.titleSmall.copyWith(color: palette.textPrimary),
        ),
      ],
    );
  }
}
