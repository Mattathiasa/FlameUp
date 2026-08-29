import 'package:flameup/features/gamification/domain/quests.dart';
import 'package:flameup/features/recipes/domain/recipe.dart';
import 'package:flutter_test/flutter_test.dart';

Recipe recipe({
  String id = 'doro',
  bool fasting = false,
  String region = 'amhara',
  bool family = false,
}) =>
    Recipe(
      id: id,
      title: id,
      titleAm: id,
      subtitle: '',
      subtitleAm: '',
      regionId: region,
      category: 'wat',
      difficulty: Difficulty.beginner,
      totalMinutes: 60,
      servings: 4,
      xpReward: 100,
      ingredients: const [],
      steps: const [],
      gradientA: '#000000',
      gradientB: '#FFFFFF',
      isFasting: fasting,
      isFamilyRecipe: family,
    );

QuestProgress progress(
  String questId, {
  int done = 0,
  int target = 1,
  DateTime? expiresAt,
  DateTime? rewardedAt,
}) =>
    QuestProgress(
      questId: questId,
      progress: done,
      target: target,
      expiresAt: expiresAt ?? DateTime(2030),
      completedAt: done >= target ? DateTime(2026) : null,
      rewardedAt: rewardedAt,
    );

void main() {
  final now = DateTime(2026, 3, 4, 12); // a Wednesday

  group('cadence boundaries are local dates', () {
    test('daily expires at the next midnight', () {
      expect(QuestCadence.daily.expiryFrom(now), DateTime(2026, 3, 5));
    });

    test('weekly expires at the end of the week', () {
      // Wednesday is weekday 3, so it runs to the following Monday.
      expect(QuestCadence.weekly.expiryFrom(now), DateTime(2026, 3, 9));
    });

    test('a late-evening quest still expires the next day, not immediately',
        () {
      final evening = DateTime(2026, 3, 4, 23, 55);
      expect(QuestCadence.daily.expiryFrom(evening), DateTime(2026, 3, 5));
    });
  });

  group('progress', () {
    test('a matching cook advances the quest', () {
      final result = QuestEvaluator.afterCook(
        active: [progress('daily_fasting')],
        recipe: recipe(fasting: true),
        regionsAlreadyCooked: const {},
        recipesAlreadyCooked: const {},
        now: now,
      );

      expect(result.single.progress, 1);
      expect(result.single.isComplete, isTrue);
      expect(result.single.completedAt, isNotNull);
    });

    test('a non-matching cook does not', () {
      final result = QuestEvaluator.afterCook(
        active: [progress('daily_fasting')],
        recipe: recipe(),
        regionsAlreadyCooked: const {},
        recipesAlreadyCooked: const {},
        now: now,
      );

      expect(result.single.progress, 0);
    });

    test('an expired quest is left alone', () {
      // A quest that ran out yesterday must not quietly accept today's cook.
      final result = QuestEvaluator.afterCook(
        active: [
          progress('daily_fasting', expiresAt: DateTime(2026, 3, 3)),
        ],
        recipe: recipe(fasting: true),
        regionsAlreadyCooked: const {},
        recipesAlreadyCooked: const {},
        now: now,
      );

      expect(result.single.progress, 0);
    });

    test('a completed quest does not keep counting', () {
      final result = QuestEvaluator.afterCook(
        active: [progress('daily_fasting', done: 1)],
        recipe: recipe(fasting: true),
        regionsAlreadyCooked: const {},
        recipesAlreadyCooked: const {},
        now: now,
      );

      expect(result.single.progress, 1);
    });

    test('a multi-target quest counts up', () {
      var quests = [progress('weekly_regions', target: 3)];

      quests = QuestEvaluator.afterCook(
        active: quests,
        recipe: recipe(region: 'gurage'),
        regionsAlreadyCooked: const {'amhara'},
        recipesAlreadyCooked: const {},
        now: now,
      );
      expect(quests.single.progress, 1);
      expect(quests.single.isComplete, isFalse);

      quests = QuestEvaluator.afterCook(
        active: quests,
        recipe: recipe(region: 'tigray'),
        regionsAlreadyCooked: const {'amhara', 'gurage'},
        recipesAlreadyCooked: const {},
        now: now,
      );
      expect(quests.single.progress, 2);
    });

    test('a region already cooked does not advance the region quest', () {
      final result = QuestEvaluator.afterCook(
        active: [progress('weekly_regions', target: 3)],
        recipe: recipe(region: 'amhara'),
        regionsAlreadyCooked: const {'amhara'},
        recipesAlreadyCooked: const {},
        now: now,
      );

      expect(result.single.progress, 0);
    });

    test('a repeat dish does not advance the new-recipe quest', () {
      final result = QuestEvaluator.afterCook(
        active: [progress('weekly_new', target: 3)],
        recipe: recipe(id: 'doro'),
        regionsAlreadyCooked: const {},
        recipesAlreadyCooked: const {'doro'},
        now: now,
      );

      expect(result.single.progress, 0);
    });

    test('an unknown quest id is ignored rather than fatal', () {
      final result = QuestEvaluator.afterCook(
        active: [progress('a_quest_that_was_removed')],
        recipe: recipe(fasting: true),
        regionsAlreadyCooked: const {},
        recipesAlreadyCooked: const {},
        now: now,
      );

      expect(result.single.progress, 0);
    });
  });

  group('rewards are paid once', () {
    test('a completed but unpaid quest is awaiting reward', () {
      final awaiting = QuestEvaluator.awaitingReward([
        progress('daily_fasting', done: 1),
      ]);

      expect(awaiting, hasLength(1));
    });

    test('an already-paid quest is not', () {
      // rewardedAt is what stops a completion being paid twice.
      final awaiting = QuestEvaluator.awaitingReward([
        progress('daily_fasting', done: 1, rewardedAt: DateTime(2026, 3, 4)),
      ]);

      expect(awaiting, isEmpty);
    });

    test('an incomplete quest is not', () {
      final awaiting = QuestEvaluator.awaitingReward([
        progress('weekly_regions', done: 2, target: 3),
      ]);

      expect(awaiting, isEmpty);
    });
  });

  group('issuing', () {
    test('produces the quests for a cadence, unstarted', () {
      final daily = QuestEvaluator.issue(
        cadence: QuestCadence.daily,
        now: now,
      );

      expect(daily, isNotEmpty);
      expect(daily.every((q) => q.progress == 0), isTrue);
      expect(daily.every((q) => q.expiresAt == DateTime(2026, 3, 5)), isTrue);
    });

    test('each cadence issues only its own quests', () {
      final weekly =
          QuestEvaluator.issue(cadence: QuestCadence.weekly, now: now);
      final ids = weekly.map((q) => q.questId).toSet();

      for (final id in ids) {
        expect(Quests.byId(id)!.cadence, QuestCadence.weekly);
      }
    });
  });

  group('the catalogue', () {
    test('every quest is named in both languages with a positive target', () {
      for (final rule in Quests.all) {
        expect(rule.localisedName(amharic: false), isNotEmpty);
        expect(rule.localisedName(amharic: true), isNotEmpty);
        expect(rule.target, greaterThan(0));
        expect(rule.xpReward, greaterThan(0));
      }
    });

    test('ids are unique', () {
      final ids = Quests.all.map((r) => r.id).toList();
      expect(ids.length, ids.toSet().length);
    });

    test('covers all three cadences', () {
      expect(
        Quests.all.map((r) => r.cadence).toSet(),
        QuestCadence.values.toSet(),
      );
    });
  });

  group('serialisation', () {
    test('round trips', () {
      final original = progress('daily_fasting', done: 1);
      final restored = QuestProgress.fromJson(original.toJson())!;

      expect(restored.questId, 'daily_fasting');
      expect(restored.progress, 1);
      expect(restored.isComplete, isTrue);
    });

    test('a corrupt document decodes to null', () {
      expect(QuestProgress.fromJson(null), isNull);
      expect(QuestProgress.fromJson(const {}), isNull);
      expect(
        QuestProgress.fromJson(const {'questId': 'x', 'expiresAt': 'nope'}),
        isNull,
      );
    });
  });
}
