import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/cache_entry.dart';
import '../../auth/domain/auth_providers.dart';
import '../../recipes/data/recipe_seed_source.dart';
import '../data/progress_repository.dart';
import 'achievements.dart';
import 'level_curve.dart';
import 'streak_calculator.dart';

/// The signed-in user's progression, cache-first.
final userProgressProvider =
    StreamProvider.autoDispose<Cached<UserProgress>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return const Stream.empty();
  return ref.watch(progressRepositoryProvider).watch(uid);
});

/// The XP curve. Config-driven, with the standard curve as the fallback.
final levelCurveProvider = Provider<LevelCurve>((ref) => LevelCurve.standard);

/// The streak as it stands *today*, not the number last written.
///
/// A streak that lapsed while the app was closed must read as lapsed; showing
/// the stored figure would have the app lying to itself.
final liveStreakProvider = Provider<int>((ref) {
  final progress = ref.watch(userProgressProvider).valueOrNull?.value;
  if (progress == null) return 0;
  return StreakCalculator.currentAsOf(progress.streak, asOf: DateTime.now());
});

/// Whether the streak lapses unless something is cooked today.
final streakAtRiskProvider = Provider<bool>((ref) {
  final progress = ref.watch(userProgressProvider).valueOrNull?.value;
  if (progress == null) return false;
  return StreakCalculator.isAtRisk(progress.streak, asOf: DateTime.now());
});

/// Achievement progress, built from what this device knows.
///
/// Uses local completed sessions rather than waiting on a sync, so a guest who
/// has never been online still sees a real record of what they have cooked.
final achievementProgressProvider =
    FutureProvider.autoDispose<List<(AchievementRule, double, bool)>>(
        (ref) async {
  final recipes = await ref.watch(recipeSeedSourceProvider).load();
  final progress = ref.watch(userProgressProvider).valueOrNull?.value;

  final snapshot = ref.watch(progressRepositoryProvider).localSnapshot(
    recipeRegions: {for (final r in recipes) r.id: r.regionId},
    fastingRecipeIds:
        recipes.where((r) => r.isFasting).map((r) => r.id).toSet(),
  );

  // Server-held figures win where they exist; local counts fill the rest.
  final merged = ProgressSnapshot(
    totalCooks: snapshot.totalCooks,
    distinctRecipeIds: snapshot.distinctRecipeIds,
    distinctRegionIds: snapshot.distinctRegionIds,
    fastingDishesCooked: snapshot.fastingDishesCooked,
    currentStreak: ref.watch(liveStreakProvider),
    longestStreak: progress?.streak.longest ?? 0,
    masteryByRecipe: {
      for (final entry in (progress?.mastery ?? {}).entries)
        entry.key: entry.value.level,
    },
  );

  return AchievementEvaluator.allWithProgress(
    snapshot: merged,
    unlocked: progress?.unlockedAchievements ?? const {},
  );
});
