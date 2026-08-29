import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/widgets.dart';
import '../domain/onboarding_providers.dart';
import '../domain/onboarding_state.dart';
import 'onboarding_scaffold.dart';

/// 03-skill — "How well do you know the kitchen?"
class SkillScreen extends ConsumerWidget {
  const SkillScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);
    final answers = ref.watch(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);

    // (title, subtitle, filled pips) per level, matching the design's three
    // cards and their 1/2/3 signal-strength indicator.
    final options = <(SkillLevel, String, String, int)>[
      (SkillLevel.beginner, l10n.beginner, l10n.beginnerS, 1),
      (SkillLevel.gettingThere, l10n.inter, l10n.interS, 2),
      (SkillLevel.grewUpOnThis, l10n.adv, l10n.advS, 3),
    ];

    return OnboardingScaffold(
      step: 0,
      totalSteps: 3,
      title: l10n.skillH1,
      subtitle: l10n.skillSub,
      onSkip: () async {
        if (await controller.skip() && context.mounted) {
          context.go(Routes.home);
        }
      },
      primaryLabel: l10n.continueLabel,
      onPrimary: () => context.push(Routes.onboardingTaste),
      children: [
        for (final (level, title, subtitle, pips) in options) ...[
          _SkillCard(
            title: title,
            subtitle: subtitle,
            pips: pips,
            selected: answers.skill == level,
            onTap: () => controller.setSkill(level),
            palette: palette,
          ),
          const SizedBox(height: 11),
        ],
      ],
    );
  }
}

class _SkillCard extends StatelessWidget {
  const _SkillCard({
    required this.title,
    required this.subtitle,
    required this.pips,
    required this.selected,
    required this.onTap,
    required this.palette,
  });

  final String title;
  final String subtitle;
  final int pips;
  final bool selected;
  final VoidCallback onTap;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$title. $subtitle',
      excludeSemantics: true,
      child: GlassPanel(
        onTap: onTap,
        borderRadius: AppRadii.xxlAll,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
        child: AnimatedContainer(
          duration: AppMotion.fast,
          decoration: BoxDecoration(
            borderRadius: AppRadii.xxlAll,
            border: Border.all(
              color: selected ? AppColors.accent : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              // Three ascending bars, filled to the level's strength.
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: palette.glassRaised,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    for (var p = 1; p <= 3; p++) ...[
                      Container(
                        width: 3,
                        height: 6 + p * 4,
                        decoration: BoxDecoration(
                          color: p <= pips
                              ? AppColors.accent
                              : palette.textTertiary,
                          borderRadius: BorderRadius.circular(AppRadii.sm),
                        ),
                      ),
                      if (p < 3) const SizedBox(width: 2),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.titleSmall
                          .copyWith(color: palette.textPrimary),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: AppTypography.caption
                          .copyWith(color: palette.textSecondary),
                    ),
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
