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

/// 04-taste — heat tolerance and dietary preferences.
class TasteScreen extends ConsumerWidget {
  const TasteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);
    final answers = ref.watch(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);

    final heatLabels = [l10n.h1, l10n.h2, l10n.h3, l10n.h4, l10n.h5];
    final dietLabels = {
      DietaryFlag.fasting: l10n.dFast,
      DietaryFlag.glutenFree: l10n.dGluten,
      DietaryFlag.dairyFree: l10n.dDairy,
      DietaryFlag.meatLover: l10n.dMeat,
      DietaryFlag.raw: l10n.dRaw,
      DietaryFlag.quick: l10n.dQuick,
    };

    return OnboardingScaffold(
      step: 1,
      totalSteps: 3,
      title: l10n.tasteH1,
      subtitle: l10n.tasteSub,
      onBack: () => context.pop(),
      primaryLabel: l10n.startCooking,
      onPrimary: () async {
        if (await controller.complete() && context.mounted) {
          context.go(Routes.home);
        }
      },
      children: [
        Eyebrow(l10n.heatLevel),
        const SizedBox(height: AppSpacing.md),
        _HeatScale(
          value: answers.heat,
          label: heatLabels[answers.heat.value],
          onChanged: controller.setHeat,
          palette: palette,
        ),
        const SizedBox(height: AppSpacing.xxxl),
        Eyebrow(l10n.dietary),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final entry in dietLabels.entries)
              PillChip(
                label: entry.value,
                selected: answers.dietary.contains(entry.key),
                onTap: () => controller.toggleDietary(entry.key),
              ),
          ],
        ),
      ],
    );
  }
}

/// Five flames, filled to the chosen tolerance.
///
/// A row of discrete steps rather than a Slider: the design shows five named
/// levels, and "Mitmita" is a different thing from "80% of the way along a
/// continuum".
class _HeatScale extends StatelessWidget {
  const _HeatScale({
    required this.value,
    required this.label,
    required this.onChanged,
    required this.palette,
  });

  final HeatTolerance value;
  final String label;
  final ValueChanged<HeatTolerance> onChanged;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Heat tolerance',
      value: label,
      slider: true,
      child: GlassPanel(
        borderRadius: AppRadii.xxlAll,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final level in HeatTolerance.values)
                  Expanded(
                    child: GestureDetector(
                      onTap: () => onChanged(level),
                      behavior: HitTestBehavior.opaque,
                      child: ExcludeSemantics(
                        child: SizedBox(
                          height: AppTouch.minTarget,
                          child: Center(
                            child: AnimatedScale(
                              duration: AppMotion.fast,
                              scale: level == value ? 1.15 : 1,
                              child: FlameIcon(
                                size: 26,
                                color: level.value <= value.value
                                    ? AppColors.accent
                                    : palette.textTertiary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              label,
              style:
                  AppTypography.titleSmall.copyWith(color: palette.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}
