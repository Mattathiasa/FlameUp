import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/widgets.dart';

/// Shared chrome for the onboarding steps.
///
/// The design gives both steps the same shape: a segmented progress rail, a
/// large question, a subtitle, the content, and a primary action pinned to the
/// bottom. Building it once keeps the two screens from drifting apart.
class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    required this.step,
    required this.totalSteps,
    required this.title,
    required this.subtitle,
    required this.children,
    required this.primaryLabel,
    required this.onPrimary,
    this.onSkip,
    this.onBack,
    this.primaryEnabled = true,
    super.key,
  });

  final int step;
  final int totalSteps;
  final String title;
  final String subtitle;
  final List<Widget> children;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final VoidCallback? onSkip;
  final VoidCallback? onBack;
  final bool primaryEnabled;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: Stack(
        children: [
          const AmbientBackground(),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                  child: Row(
                    children: [
                      if (onBack != null)
                        IconButton(
                          onPressed: onBack,
                          icon: const Icon(Icons.arrow_back, size: 20),
                          tooltip: l10n.back,
                        )
                      else
                        const SizedBox(width: 48),
                      const Spacer(),
                      if (onSkip != null)
                        TextButton(
                          onPressed: onSkip,
                          child: Text(l10n.skip),
                        )
                      else
                        const SizedBox(width: 48),
                    ],
                  ),
                ),
                // The segmented rail: one 3px bar per step, filled to here.
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 26),
                  child: Row(
                    children: [
                      for (var i = 0; i < totalSteps; i++) ...[
                        Expanded(
                          child: Container(
                            height: 3,
                            decoration: BoxDecoration(
                              color: i <= step
                                  ? AppColors.accent
                                  : palette.divider,
                              borderRadius: BorderRadius.circular(AppRadii.sm),
                            ),
                          ),
                        ),
                        if (i < totalSteps - 1) const SizedBox(width: 5),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppTypography.headlineLarge
                              .copyWith(color: palette.textPrimary),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          subtitle,
                          style: AppTypography.bodyMedium
                              .copyWith(color: palette.textSecondary),
                        ),
                        const SizedBox(height: AppSpacing.xxxl),
                        ...children,
                        const SizedBox(height: AppSpacing.xxxl),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: FlameButton(
                    label: primaryLabel,
                    onPressed: primaryEnabled ? onPrimary : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
