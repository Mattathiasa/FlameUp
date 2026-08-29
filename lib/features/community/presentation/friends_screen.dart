import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/widgets.dart';
import '../../auth/domain/auth_providers.dart';
import '../data/community_repository.dart';
import '../domain/community_providers.dart';
import '../domain/post.dart';

/// 21-friends.
class FriendsScreen extends ConsumerWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);
    final friends = ref.watch(friendsProvider).valueOrNull ?? const <Friend>[];
    final incoming = ref.watch(incomingRequestsProvider);
    final user = ref.watch(authUserProvider).valueOrNull;
    final repo = ref.read(communityRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.friendsH1)),
      body: Stack(
        children: [
          const AmbientBackground(),
          if (friends.isEmpty && incoming.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.screenBottom),
              child: EmptyView(
                title: l10n.friendsH1,
                message: l10n.inviteSub,
              ),
            )
          else
            ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.md,
                AppSpacing.gutter,
                AppSpacing.screenBottom,
              ),
              children: [
                // Requests first: they are the only thing here that needs an
                // answer, and burying them under a friend list hides them.
                if (incoming.isNotEmpty) ...[
                  Eyebrow(l10n.add),
                  const SizedBox(height: AppSpacing.sm),
                  for (final request in incoming)
                    _RequestRow(
                      request: request,
                      l10n: l10n,
                      onAccept: () => repo.acceptFriendRequest(
                        uid: user!.uid,
                        uidName: user.displayName ?? '',
                        otherUid: request.otherUid,
                        otherName: request.displayName,
                      ),
                      onDecline: () => repo.declineFriendRequest(
                        uid: user!.uid,
                        otherUid: request.otherUid,
                      ),
                    ),
                  const SizedBox(height: AppSpacing.xxl),
                ],
                if (friends.isNotEmpty) ...[
                  Eyebrow(l10n.following),
                  const SizedBox(height: AppSpacing.sm),
                  for (final friend in friends)
                    _FriendRow(friend: friend, palette: palette),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _RequestRow extends StatelessWidget {
  const _RequestRow({
    required this.request,
    required this.l10n,
    required this.onAccept,
    required this.onDecline,
  });

  final FriendRequest request;
  final AppLocalizations l10n;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return GlassPanel(
      blur: false,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Row(
        children: [
          Expanded(
            child: Text(
              request.displayName.isEmpty
                  ? request.otherUid
                  : request.displayName,
              style:
                  AppTypography.titleSmall.copyWith(color: palette.textPrimary),
            ),
          ),
          TextButton(onPressed: onDecline, child: Text(l10n.actionCancel)),
          const SizedBox(width: AppSpacing.xs),
          FilledButton(onPressed: onAccept, child: Text(l10n.add)),
        ],
      ),
    );
  }
}

class _FriendRow extends StatelessWidget {
  const _FriendRow({required this.friend, required this.palette});

  final Friend friend;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      blur: false,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: palette.glassRaised,
            child: Text(
              friend.displayName.isEmpty
                  ? '?'
                  : friend.displayName.characters.first.toUpperCase(),
              style: AppTypography.label.copyWith(color: palette.textPrimary),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              friend.displayName,
              style:
                  AppTypography.titleSmall.copyWith(color: palette.textPrimary),
            ),
          ),
          if (friend.streak > 0) ...[
            const FlameIcon(size: 13),
            const SizedBox(width: AppSpacing.xxs),
            Text(
              '${friend.streak}',
              style: AppTypography.label.copyWith(color: AppColors.accent),
            ),
          ],
        ],
      ),
    );
  }
}
