import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/firestore_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/widgets.dart';
import '../../auth/domain/auth_providers.dart';
import '../../gamification/domain/progress_providers.dart';
import '../domain/community_providers.dart';

/// One row of a leaderboard.
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.uid,
    required this.displayName,
    required this.xp,
    required this.rank,
  });

  final String uid;
  final String displayName;
  final int xp;
  final int rank;
}

/// The global board.
///
/// A **single aggregated document**, written by a scheduled Cloud Function.
/// Rankings are never computed by pulling the users collection onto a device.
final globalLeaderboardProvider =
    StreamProvider.autoDispose<List<LeaderboardEntry>>((ref) {
  return FirebaseFirestore.instance
      .doc('${FirestorePaths.leaderboards}/global')
      .snapshots()
      .map((doc) {
    final entries = doc.data()?['entries'] as List?;
    if (entries == null) return const <LeaderboardEntry>[];

    return entries.map((raw) {
      final entry = (raw as Map).cast<String, dynamic>();
      return LeaderboardEntry(
        uid: entry['uid'] as String? ?? '',
        displayName: entry['displayName'] as String? ?? '',
        xp: entry['xp'] as int? ?? 0,
        rank: entry['rank'] as int? ?? 0,
      );
    }).toList();
  });
});

/// Which board is showing.
enum LeaderboardScope { friends, global }

/// 23-leader.
class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  LeaderboardScope _scope = LeaderboardScope.friends;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final uid = ref.watch(currentUidProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.lbH1)),
      body: Stack(
        children: [
          const AmbientBackground(),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.gutter,
                  vertical: AppSpacing.md,
                ),
                child: Row(
                  children: [
                    PillChip(
                      label: l10n.lbFriends,
                      selected: _scope == LeaderboardScope.friends,
                      onTap: () =>
                          setState(() => _scope = LeaderboardScope.friends),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    PillChip(
                      label: l10n.lbGlobal,
                      selected: _scope == LeaderboardScope.global,
                      onTap: () =>
                          setState(() => _scope = LeaderboardScope.global),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _scope == LeaderboardScope.friends
                    ? _FriendsBoard(uid: uid, l10n: l10n)
                    : _GlobalBoard(uid: uid, l10n: l10n),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Friends are assembled on the device — the set is small and already local,
/// so a server aggregate would be more machinery for no benefit.
class _FriendsBoard extends ConsumerWidget {
  const _FriendsBoard({required this.uid, required this.l10n});

  final String? uid;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friends = ref.watch(friendsProvider).valueOrNull ?? const [];
    final progress = ref.watch(userProgressProvider).valueOrNull?.value;

    if (friends.isEmpty) {
      return EmptyView(title: l10n.lbFriends, message: l10n.inviteSub);
    }

    final rows = <LeaderboardEntry>[
      if (progress != null && uid != null)
        LeaderboardEntry(
          uid: uid!,
          displayName: l10n.guestBadge,
          xp: progress.xp,
          rank: 0,
        ),
      for (final friend in friends)
        LeaderboardEntry(
          uid: friend.uid,
          displayName: friend.displayName,
          xp: 0,
          rank: 0,
        ),
    ]..sort((a, b) => b.xp.compareTo(a.xp));

    return _Board(
      entries: [
        for (var i = 0; i < rows.length; i++)
          LeaderboardEntry(
            uid: rows[i].uid,
            displayName: rows[i].displayName,
            xp: rows[i].xp,
            rank: i + 1,
          ),
      ],
      meUid: uid,
    );
  }
}

class _GlobalBoard extends ConsumerWidget {
  const _GlobalBoard({required this.uid, required this.l10n});

  final String? uid;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(globalLeaderboardProvider).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          // An empty or unreadable board is not an error worth alarming
          // anyone with: the aggregation runs hourly and needs Blaze.
          error: (_, __) =>
              EmptyView(title: l10n.lbGlobal, message: l10n.errorOffline),
          data: (entries) => entries.isEmpty
              ? EmptyView(title: l10n.lbGlobal, message: l10n.feedSub)
              : _Board(entries: entries, meUid: uid),
        );
  }
}

class _Board extends StatelessWidget {
  const _Board({required this.entries, required this.meUid});

  final List<LeaderboardEntry> entries;
  final String? meUid;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        0,
        AppSpacing.gutter,
        AppSpacing.screenBottom,
      ),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final isMe = entry.uid == meUid;

        return GlassPanel(
          blur: false,
          raised: isMe,
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Text(
                  '${entry.rank}',
                  style: AppTypography.titleSmall.copyWith(
                    color:
                        entry.rank <= 3 ? AppColors.gold : palette.textTertiary,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  entry.displayName,
                  style: AppTypography.bodyMedium.copyWith(
                    color: isMe ? AppColors.accent : palette.textPrimary,
                  ),
                ),
              ),
              Text(
                '${entry.xp}',
                style: AppTypography.titleSmall
                    .copyWith(color: palette.textSecondary),
              ),
            ],
          ),
        );
      },
    );
  }
}
