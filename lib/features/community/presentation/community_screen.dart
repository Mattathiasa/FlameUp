import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/widgets.dart';

/// 20-feed — Community.
///
/// The feed is empty until real people post. The design shows sample posts
/// from named users; shipping those as if they were real would be fabricating
/// content, so the screen states the position plainly and points at the ways
/// in.
class CommunityScreen extends ConsumerWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: Stack(
        children: [
          const AmbientBackground(),
          SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.xl,
                AppSpacing.gutter,
                AppSpacing.screenBottom,
              ),
              children: [
                Text(
                  l10n.feedH1,
                  style: AppTypography.displaySmall
                      .copyWith(color: palette.textPrimary),
                ),
                const SizedBox(height: AppSpacing.xxl),
                _NavCard(
                  title: l10n.friendsH1,
                  subtitle: l10n.inviteSub,
                  onTap: () => context.push(Routes.friends),
                ),
                _NavCard(
                  title: l10n.chH1,
                  subtitle: l10n.chBody,
                  onTap: () => context.push(Routes.challenges),
                ),
                _NavCard(
                  title: l10n.lbH1,
                  subtitle: l10n.lbGlobal,
                  onTap: () => context.push(Routes.leaderboard),
                ),
                const SizedBox(height: AppSpacing.xxxl),
                EmptyView(
                  title: l10n.empH1,
                  message: l10n.feedSub,
                  actionLabel: l10n.empCta,
                  onAction: () => context.go(Routes.discover),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavCard extends StatelessWidget {
  const _NavCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return GlassPanel(
      blur: false,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.xl),
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.titleMedium
                      .copyWith(color: palette.textPrimary),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  subtitle,
                  style: AppTypography.caption
                      .copyWith(color: palette.textSecondary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, size: 18, color: palette.textTertiary),
        ],
      ),
    );
  }
}
