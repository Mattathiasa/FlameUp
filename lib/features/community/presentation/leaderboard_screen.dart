import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/widgets.dart';

/// 23-leader.
///
/// Backed by real Firestore collections, which are empty until people use
/// them. The design's sample rows are not shipped as data: inventing users
/// would make the screen look finished while telling the user something false.
class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.lbH1)),
      body: Stack(
        children: [
          const AmbientBackground(),
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.screenBottom),
            child: EmptyView(
              title: l10n.lbH1,
              message: l10n.lbFriends,
            ),
          ),
        ],
      ),
    );
  }
}
