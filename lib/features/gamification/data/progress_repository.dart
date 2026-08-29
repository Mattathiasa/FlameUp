import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/cache_entry.dart';
import '../../../core/cache/cache_store.dart';
import '../../../core/cache/offline_first.dart';
import '../../../core/constants/firestore_paths.dart';
import '../../../core/services/local_store.dart';
import '../../cooking/data/cooking_repository.dart';
import '../../cooking/domain/cooking_session.dart';
import '../domain/achievements.dart';
import '../domain/level_curve.dart';
import '../domain/mastery.dart';
import '../domain/quests.dart';
import '../domain/streak_calculator.dart';

/// Everything the progress screens read.
class UserProgress {
  const UserProgress({
    this.xp = 0,
    this.level = 1,
    this.streak = const StreakState(),
    this.mastery = const {},
    this.unlockedAchievements = const {},
    this.quests = const [],
    this.recipesCooked = 0,
    this.regionsTasted = 0,
  });

  final int xp;
  final int level;
  final StreakState streak;
  final Map<String, RecipeMastery> mastery;
  final Set<String> unlockedAchievements;
  final List<QuestProgress> quests;
  final int recipesCooked;
  final int regionsTasted;

  int get recipesMastered => mastery.values
      .where((m) => m.level.index >= MasteryLevel.skilled.index)
      .length;

  double progressWithinLevel(LevelCurve curve) => curve.progressWithinLevel(xp);
  int xpToNextLevel(LevelCurve curve) => curve.xpToNextLevel(xp);

  static UserProgress fromJson(Map<String, dynamic>? json) => UserProgress(
        xp: json?['xp'] as int? ?? 0,
        level: json?['level'] as int? ?? 1,
        streak: StreakState.fromJson(json),
        recipesCooked: json?['recipesCooked'] as int? ?? 0,
        regionsTasted: json?['regionsTasted'] as int? ?? 0,
      );

  UserProgress copyWith({
    Map<String, RecipeMastery>? mastery,
    Set<String>? unlockedAchievements,
    List<QuestProgress>? quests,
  }) =>
      UserProgress(
        xp: xp,
        level: level,
        streak: streak,
        mastery: mastery ?? this.mastery,
        unlockedAchievements: unlockedAchievements ?? this.unlockedAchievements,
        quests: quests ?? this.quests,
        recipesCooked: recipesCooked,
        regionsTasted: regionsTasted,
      );
}

/// Reads progression, offline-first.
///
/// The server owns these numbers, but they must still be *visible* with no
/// connection: a streak you cannot see is a streak you stop trusting.
class ProgressRepository {
  ProgressRepository({
    required CacheStore cache,
    required CookingRepository cooking,
    FirebaseFirestore? firestore,
  })  : _cache = cache,
        _cooking = cooking,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final CacheStore _cache;
  final CookingRepository _cooking;
  final FirebaseFirestore _firestore;

  static const String _box = LocalStore.boxMisc;

  Stream<Cached<UserProgress>> watch(String uid) {
    final key = 'progress.$uid';

    return OfflineFirst.read<UserProgress>(
      readCache: () {
        final entry = _cache.readDoc(_box, key);
        if (entry == null) return null;
        return CacheEntry(
          value: UserProgress.fromJson(entry.value),
          cachedAt: entry.cachedAt,
        );
      },
      fetch: () async {
        final snapshot = await _firestore.doc(FirestorePaths.user(uid)).get();
        final base = UserProgress.fromJson(snapshot.data());

        final mastery =
            await _firestore.collection(FirestorePaths.userMastery(uid)).get();
        final achievements = await _firestore
            .collection(FirestorePaths.userAchievementsOf(uid))
            .get();
        final quests =
            await _firestore.collection(FirestorePaths.userQuestsOf(uid)).get();

        return base.copyWith(
          mastery: {
            for (final doc in mastery.docs)
              doc.id: RecipeMastery.fromJson(doc.id, doc.data()),
          },
          unlockedAchievements: achievements.docs.map((d) => d.id).toSet(),
          quests: quests.docs
              .map((d) => QuestProgress.fromJson(d.data()))
              .whereType<QuestProgress>()
              .toList(),
        );
      },
      writeCache: (progress) => _cache.writeDoc(_box, key, {
        'xp': progress.xp,
        'level': progress.level,
        ...progress.streak.toJson(),
        'recipesCooked': progress.recipesCooked,
        'regionsTasted': progress.regionsTasted,
      }),
    );
  }

  /// Progress derived from what this device knows, with no network at all.
  ///
  /// A guest who has never synced still has a history worth showing, and it is
  /// built from their own completed sessions rather than left blank.
  ProgressSnapshot localSnapshot({
    required Map<String, String> recipeRegions,
    required Set<String> fastingRecipeIds,
  }) {
    final completed = _cooking
        .allLocal()
        .where((s) => s.status == SessionStatus.completed)
        .toList();

    final recipeIds = completed.map((s) => s.recipeId).toSet();

    return ProgressSnapshot(
      totalCooks: completed.length,
      distinctRecipeIds: recipeIds,
      distinctRegionIds:
          recipeIds.map((id) => recipeRegions[id]).whereType<String>().toSet(),
      fastingDishesCooked:
          completed.where((s) => fastingRecipeIds.contains(s.recipeId)).length,
    );
  }
}

final progressRepositoryProvider = Provider<ProgressRepository>((ref) {
  return ProgressRepository(
    cache: ref.watch(cacheStoreProvider),
    cooking: ref.watch(cookingRepositoryProvider),
  );
});
