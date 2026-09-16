import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/weekly_repository.dart';
import 'weekly_competition.dart';

/// The week everyone is looking at. One definition, so the board, the
/// cook-off card and the entries never disagree about what "this week" is.
final currentWeekIdProvider =
    Provider<String>((ref) => weekIdFor(DateTime.now()));

final weeklyRepositoryProvider =
    Provider<WeeklyRepository>((ref) => WeeklyRepository());

/// This week's community cook-off, or null when none was published yet.
final weeklyChallengeProvider =
    StreamProvider.autoDispose<WeeklyChallenge?>((ref) {
  return ref
      .watch(weeklyRepositoryProvider)
      .watchChallenge(ref.watch(currentWeekIdProvider));
});

/// The global weekly XP board, highest first.
final weeklyLeaderboardProvider =
    StreamProvider.autoDispose<List<WeeklyXpRow>>((ref) {
  return ref.watch(weeklyRepositoryProvider).watchLeaderboard();
});

/// This week's cook-off entrants, in finish order.
final weeklyEntriesProvider =
    StreamProvider.autoDispose<List<WeeklyChallengeEntry>>((ref) {
  return ref
      .watch(weeklyRepositoryProvider)
      .watchEntries(ref.watch(currentWeekIdProvider));
});
