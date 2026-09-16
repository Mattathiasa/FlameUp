import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/widgets.dart';
import '../../auth/domain/auth_providers.dart';
import '../domain/community_providers.dart';
import '../domain/weekly_providers.dart';

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

/// The global board is the weekly XP aggregate — see WeeklyRepository.
/// Ranks are computed here from the ordered query, not read from a field,
/// so the number on screen and the order on screen can never disagree.
List<LeaderboardEntry> ranked(Iterable<LeaderboardEntry> rows) {
  final sorted = rows.toList()..sort((a, b) => b.xp.compareTo(a.xp));
  return [
    for (var i = 0; i < sorted.length; i++)
      LeaderboardEntry(
        uid: sorted[i].uid,
        displayName: sorted[i].displayName,
        xp: sorted[i].xp,
        rank: i + 1,
      ),
  ];
}

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
/// Friends and the user, ranked by **this week's** XP — the same rows the
/// global board reads, filtered to the friend set on the device.
class _FriendsBoard extends ConsumerWidget {
  const _FriendsBoard({required this.uid, required this.l10n});

  final String? uid;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friends = ref.watch(friendsProvider).valueOrNull ?? const [];
    final board = ref.watch(weeklyLeaderboardProvider).valueOrNull ?? const [];

    if (friends.isEmpty) {
      return EmptyView(title: l10n.lbFriends, message: l10n.inviteSub);
    }

    // Everyone on this board is on the weekly scale — mine included. A row
    // that does not exist yet means no cook this week, which is a zero, not
    // an absence: hiding it would flatter me with silence.
    final friendUids = {for (final f in friends) f.uid};
    final myRow = board.where((row) => row.uid == uid).firstOrNull;

    return _Board(
      entries: ranked([
        if (uid != null)
          LeaderboardEntry(
            uid: uid!,
            displayName: l10n.guestBadge,
            xp: myRow?.xp ?? 0,
            rank: 0,
          ),
        for (final row in board)
          if (friendUids.contains(row.uid))
            LeaderboardEntry(
              uid: row.uid,
              displayName: row.displayName,
              xp: row.xp,
              rank: 0,
            ),
      ]),
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
    return ref.watch(weeklyLeaderboardProvider).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          // An empty or unreadable board is not an error worth alarming
          // anyone with: rows appear as people cook.
          error: (_, __) =>
              EmptyView(title: l10n.lbGlobal, message: l10n.errorOffline),
          data: (rows) => rows.isEmpty
              ? EmptyView(title: l10n.lbGlobal, message: l10n.feedSub)
              : _Board(
                  entries: ranked([
                    for (final row in rows)
                      LeaderboardEntry(
                        uid: row.uid,
                        displayName: row.displayName,
                        xp: row.xp,
                        rank: 0,
                      ),
                  ]),
                  meUid: uid,
                ),
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
