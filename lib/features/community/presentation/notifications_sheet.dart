import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/widgets.dart';
import '../../auth/domain/auth_providers.dart';
import '../data/community_repository.dart';
import '../domain/app_notification.dart';
import '../domain/community_providers.dart';

/// Social activity: friend requests, new friendships.
///
/// A sheet off the community tab -- activity is a glance, not a destination,
/// and the tab's own cards stay one swipe away.
class NotificationsSheet extends ConsumerWidget {
  const NotificationsSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => const NotificationsSheet(),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);
    final notifications =
        ref.watch(notificationsProvider).valueOrNull ?? const [];
    final user = ref.watch(authUserProvider).valueOrNull;
    final repo = ref.read(communityRepositoryProvider);

    Future<void> markRead(AppNotification n) async {
      final uid = user?.uid;
      if (uid == null || n.isRead) return;
      await repo.markNotificationRead(uid: uid, notificationId: n.id);
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (context, controller) => Container(
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadii.xl),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.lg,
          AppSpacing.gutter,
          AppSpacing.screenBottom,
        ),
        child: ListView(
          controller: controller,
          children: [
            Text(
              l10n.notificationsTitle,
              style: AppTypography.headlineSmall
                  .copyWith(color: palette.textPrimary),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (notifications.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xxxl),
                child: EmptyView(
                  title: l10n.notificationsTitle,
                  message: l10n.notifEmpty,
                ),
              )
            else
              for (final notification in notifications)
                _NotificationRow(
                  notification: notification,
                  l10n: l10n,
                  palette: palette,
                  onOpen: () async {
                    // Not awaited: closing the sheet is the visible action;
                    // the mark-read lands on its own.
                    unawaited(markRead(notification));
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      unawaited(
                        context.push(
                          switch (notification.type) {
                            AppNotificationType.recipePublished ||
                            AppNotificationType.recipeVouched ||
                            AppNotificationType.recipeVerified =>
                              Routes.grandmasKitchen,
                            _ => Routes.friends,
                          },
                        ),
                      );
                    }
                  },
                  onDismiss: () => markRead(notification),
                ),
          ],
        ),
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({
    required this.notification,
    required this.l10n,
    required this.palette,
    required this.onOpen,
    required this.onDismiss,
  });

  final AppNotification notification;
  final AppLocalizations l10n;
  final AppPalette palette;
  final VoidCallback onOpen;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final title = switch (notification.type) {
      AppNotificationType.friendRequest => l10n.notifFriendRequest,
      AppNotificationType.friendAdded => l10n.notifFriendAdded,
      AppNotificationType.recipePublished => l10n.notifRecipePublished,
      AppNotificationType.recipeVouched => l10n.notifRecipeVouched,
      AppNotificationType.recipeVerified => l10n.notifRecipeVerified,
    };
    final body = switch (notification.type) {
      AppNotificationType.friendRequest =>
        l10n.notifFriendRequestBody(notification.otherName),
      AppNotificationType.friendAdded =>
        l10n.notifFriendAddedBody(notification.otherName),
      AppNotificationType.recipePublished =>
        l10n.notifRecipePublishedBody(notification.otherName),
      // The vouch count is stored in otherUid's slot for these types — the
      // row's only free string field — rendered as a number.
      AppNotificationType.recipeVouched => l10n.notifRecipeVouchedBody(
          notification.otherUid,
          notification.otherName,
        ),
      AppNotificationType.recipeVerified =>
        l10n.notifRecipeVerifiedBody(notification.otherName),
    };

    return GlassPanel(
      blur: false,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: notification.isUnread
                ? AppColors.accent.withValues(alpha: 0.18)
                : palette.glassRaised,
            child: Icon(
              switch (notification.type) {
                AppNotificationType.friendRequest => Icons.person_add_alt_1,
                AppNotificationType.friendAdded => Icons.group,
                AppNotificationType.recipePublished ||
                AppNotificationType.recipeVouched ||
                AppNotificationType.recipeVerified =>
                  Icons.restaurant_menu,
              },
              size: 18,
              color: notification.isUnread
                  ? AppColors.accent
                  : palette.textSecondary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.titleSmall
                      .copyWith(color: palette.textPrimary),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  body,
                  style: AppTypography.bodyMedium
                      .copyWith(color: palette.textSecondary),
                ),
              ],
            ),
          ),
          if (notification.isUnread)
            TextButton(onPressed: onDismiss, child: Text(l10n.notifMarkRead)),
        ],
      ),
    );
  }
}

extension on AppNotification {
  bool get isRead => !isUnread;
}
