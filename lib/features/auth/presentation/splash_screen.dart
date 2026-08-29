import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/flame_icon.dart';

/// 01-splash.
///
/// Held until Firebase restores the persisted session; [RouteGuard] moves on
/// as soon as auth resolves, so this is not on a timer.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: Stack(
        children: [
          const AmbientBackground(),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 96px rounded square with the accent gradient.
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      gradient: const LinearGradient(
                        begin: Alignment(-0.34, -1),
                        end: Alignment(0.34, 1),
                        colors: [AppColors.accent, AppColors.accentDeep],
                      ),
                      boxShadow: AppShadows.accentGlow,
                    ),
                    child: const Center(
                      child: FlameIcon(
                        size: 52,
                        color: Colors.white,
                        animate: true,
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),
                  Text(
                    l10n.appName,
                    style: AppTypography.displayMedium
                        .copyWith(color: palette.textPrimary),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n.tagline,
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyLarge
                        .copyWith(color: palette.textSecondary),
                  ),
                  const SizedBox(height: 44),
                  SizedBox(
                    width: 132,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                      child: LinearProgressIndicator(
                        minHeight: 3,
                        backgroundColor: palette.divider,
                        valueColor:
                            const AlwaysStoppedAnimation(AppColors.accent),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    l10n.warming.toUpperCase(),
                    style: AppTypography.eyebrow
                        .copyWith(color: palette.textTertiary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
