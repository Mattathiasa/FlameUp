import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/cache/sync_status.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/widgets.dart';

/// 29-offline.
///
/// Rarely reached by design. Being offline is a normal state in this app, not
/// an error: cached recipes, in-flight sessions and timers all keep working,
/// so there is usually nothing to interrupt. This exists for the case where a
/// user asks what is going on.
class OfflineScreen extends ConsumerWidget {
  const OfflineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);
    final sync = ref.watch(syncStatusProvider);

    return Scaffold(
      body: Stack(
        children: [
          const AmbientBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xxxl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.cloud_off,
                    size: 44,
                    color: palette.textTertiary,
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  Text(
                    l10n.offH1,
                    textAlign: TextAlign.center,
                    style: AppTypography.headlineSmall
                        .copyWith(color: palette.textPrimary),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    l10n.offSub,
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMedium
                        .copyWith(color: palette.textSecondary),
                  ),
                  if (sync.hasPendingWork) ...[
                    const SizedBox(height: AppSpacing.xxl),
                    Text(
                      '${sync.pendingCount}',
                      style: AppTypography.displayMedium
                          .copyWith(color: AppColors.accent),
                    ),
                    Text(
                      l10n.offBanner,
                      style: AppTypography.caption
                          .copyWith(color: palette.textTertiary),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xxxl),
                  FlameButton(
                    label: l10n.offCta,
                    expand: false,
                    onPressed: () => context.go(Routes.discover),
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
