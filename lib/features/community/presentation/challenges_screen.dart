import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/widgets.dart';
import '../../auth/domain/auth_providers.dart';
import '../data/community_repository.dart';
import '../domain/challenge.dart';
import '../domain/community_providers.dart';

/// 22-challenges — "Who Cooks Better?".
class ChallengesScreen extends ConsumerWidget {
  const ChallengesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final uid = ref.watch(currentUidProvider);
    final challenges = ref.watch(challengesProvider).valueOrNull ?? const [];
    final friends = ref.watch(friendsProvider).valueOrNull ?? const [];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.chH1)),
      body: Stack(
        children: [
          const AmbientBackground(),
          if (challenges.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.screenBottom),
              child: EmptyView(
                title: l10n.chH1,
                // A challenge needs an opponent, so the honest next step
                // depends on whether they have any friends yet.
                message: friends.isEmpty ? l10n.inviteSub : l10n.chBody,
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
                for (final challenge in challenges)
                  _ChallengeCard(
                    challenge: challenge,
                    uid: uid ?? '',
                    l10n: l10n,
                    repo: ref.read(communityRepositoryProvider),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  const _ChallengeCard({
    required this.challenge,
    required this.uid,
    required this.l10n,
    required this.repo,
  });

  final Challenge challenge;
  final String uid;
  final AppLocalizations l10n;
  final CommunityRepository repo;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final expired = challenge.hasExpired(DateTime.now());
    final awaitingAnswer = challenge.status == ChallengeStatus.invited &&
        challenge.opponentId == uid;

    return GlassPanel(
      blur: false,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Opacity(
        opacity: expired ? 0.5 : 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    challenge.recipeTitle,
                    style: AppTypography.titleMedium
                        .copyWith(color: palette.textPrimary),
                  ),
                ),
                Text(
                  expired ? l10n.chPast : challenge.status.name,
                  style: AppTypography.label.copyWith(
                    color: challenge.status == ChallengeStatus.complete
                        ? AppColors.green
                        : palette.textTertiary,
                  ),
                ),
              ],
            ),
            if (challenge.status == ChallengeStatus.complete) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                // The winner is decided server-side; the client only reports
                // what it was told.
                challenge.winnerId == uid ? l10n.doneH1 : l10n.chPast,
                style: AppTypography.bodySmall
                    .copyWith(color: palette.textSecondary),
              ),
            ] else if (challenge.bothSubmitted) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n.loading,
                style: AppTypography.bodySmall
                    .copyWith(color: palette.textSecondary),
              ),
            ] else if (challenge.hasSubmitted(uid)) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                // Deliberately not showing the opponent's entry yet: seeing it
                // first would let the second cook simply out-score it.
                l10n.joined,
                style: AppTypography.bodySmall
                    .copyWith(color: palette.textSecondary),
              ),
            ],
            if (awaitingAnswer && !expired) ...[
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => repo.respondToChallenge(
                        challengeId: challenge.id,
                        accept: false,
                      ),
                      child: Text(l10n.actionCancel),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => repo.respondToChallenge(
                        challengeId: challenge.id,
                        accept: true,
                      ),
                      child: Text(l10n.join),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
