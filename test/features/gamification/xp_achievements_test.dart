import 'package:flameup/features/gamification/domain/achievements.dart';
import 'package:flameup/features/gamification/domain/mastery.dart';
import 'package:flameup/features/gamification/domain/xp_rules.dart';
import 'package:flameup/features/recipes/domain/recipe.dart';
import 'package:flutter_test/flutter_test.dart';

Recipe recipe({
  String id = 'doro',
  int xp = 240,
  bool fasting = false,
  String region = 'amhara',
}) =>
    Recipe(
      id: id,
      title: id,
      titleAm: id,
      subtitle: '',
      subtitleAm: '',
      regionId: region,
      category: 'wat',
      difficulty: Difficulty.advanced,
      totalMinutes: 120,
      servings: 6,
      xpReward: xp,
      ingredients: const [],
      steps: const [],
      gradientA: '#000000',
      gradientB: '#FFFFFF',
      isFasting: fasting,
    );

void main() {
  const rules = XpRules();

  group('XP for a completed cook', () {
    test('a first cook pays full value plus the first-time bonus', () {
      final awards = rules.forCompletedCook(
        recipe: recipe(xp: 240),
        mastery: const RecipeMastery(recipeId: 'doro'),
        streakAfter: 1,
      );

      expect(rules.totalOf(awards), 290); // 240 + 50
      expect(awards.map((a) => a.reason), contains(XpReason.firstTimeCooking));
    });

    test('the first-time bonus is paid once', () {
      final awards = rules.forCompletedCook(
        recipe: recipe(),
        mastery: const RecipeMastery(recipeId: 'doro', cookCount: 1),
        streakAfter: 2,
      );

      expect(
        awards.map((a) => a.reason),
        isNot(contains(XpReason.firstTimeCooking)),
      );
    });

    test('repeat cooks are worth progressively less', () {
      // Without decay the optimal strategy is to cook one high-XP dish
      // forever, which is the opposite of a discovery app.
      int totalAfter(int previousCooks) => rules.totalOf(
            rules.forCompletedCook(
              recipe: recipe(xp: 240),
              mastery:
                  RecipeMastery(recipeId: 'doro', cookCount: previousCooks),
              streakAfter: 5,
            ),
          );

      expect(totalAfter(3), lessThan(totalAfter(2)));
      expect(totalAfter(6), lessThan(totalAfter(3)));
    });

    test('decay never reaches zero, because repetition earns mastery', () {
      final total = rules.totalOf(
        rules.forCompletedCook(
          recipe: recipe(xp: 240),
          mastery: const RecipeMastery(recipeId: 'doro', cookCount: 50),
          streakAfter: 5,
        ),
      );

      expect(total, greaterThanOrEqualTo((240 * 0.25).round()));
    });

    test('the first three cooks pay full value', () {
      for (final count in [0, 1, 2]) {
        final awards = rules.forCompletedCook(
          recipe: recipe(xp: 100),
          mastery: RecipeMastery(recipeId: 'doro', cookCount: count),
          streakAfter: 5,
        );
        final base = awards
            .firstWhere((a) => a.reason == XpReason.recipeCompleted)
            .amount;
        expect(base, 100);
      }
    });

    test('streak milestones pay a bonus, other days do not', () {
      bool hasMilestone(int streak) => rules
          .forCompletedCook(
            recipe: recipe(),
            mastery: const RecipeMastery(recipeId: 'doro', cookCount: 5),
            streakAfter: streak,
          )
          .any((a) => a.reason == XpReason.streakMilestone);

      expect(hasMilestone(7), isTrue);
      expect(hasMilestone(30), isTrue);
      expect(hasMilestone(8), isFalse);
    });

    test('every award names its reason, so a total can be explained', () {
      final awards = rules.forCompletedCook(
        recipe: recipe(),
        mastery: const RecipeMastery(recipeId: 'doro'),
        streakAfter: 7,
      );

      for (final award in awards) {
        expect(award.amount, greaterThan(0));
        expect(award.toJson()['reason'], isNotEmpty);
      }
    });

    test('rules load from config with sane fallbacks', () {
      expect(XpRules.fromJson(null).firstTimeBonus, 50);

      final custom = XpRules.fromJson(const {
        'firstTimeBonus': 25,
        'streakMilestones': [3, 5],
      });
      expect(custom.firstTimeBonus, 25);
      expect(custom.streakMilestones, {3, 5});
    });
  });

  group('achievements are data, not branches', () {
    test('every rule has a name in both languages and a positive threshold',
        () {
      for (final rule in Achievements.all) {
        expect(rule.localisedName(amharic: false), isNotEmpty);
        expect(rule.localisedName(amharic: true), isNotEmpty);
        expect(rule.threshold, greaterThan(0));
        expect(rule.colour, matches(RegExp(r'^#[0-9A-Fa-f]{6}$')));
      }
    });

    test('ids are unique', () {
      final ids = Achievements.all.map((r) => r.id).toList();
      expect(ids.length, ids.toSet().length);
    });

    test('a recipe-specific rule names a recipe', () {
      for (final rule in Achievements.all
          .where((r) => r.metric == AchievementMetric.specificRecipe)) {
        expect(
          rule.recipeId,
          isNotNull,
          reason: '${rule.id} targets a recipe but names none',
        );
      }
    });
  });

  group('AchievementEvaluator', () {
    test('a first cook earns First Flame', () {
      final earned = AchievementEvaluator.newlyEarned(
        snapshot: const ProgressSnapshot(
          totalCooks: 1,
          distinctRecipeIds: {'shiro'},
        ),
        alreadyUnlocked: const {},
      );

      expect(earned.map((r) => r.id), contains('first_flame'));
    });

    test('an already-unlocked badge is not earned twice', () {
      // This is what stops a badge being announced -- and rewarded -- again.
      final earned = AchievementEvaluator.newlyEarned(
        snapshot: const ProgressSnapshot(totalCooks: 5),
        alreadyUnlocked: const {'first_flame'},
      );

      expect(earned.map((r) => r.id), isNot(contains('first_flame')));
    });

    test('a threshold badge waits until the threshold', () {
      List<String> earnedWith(int regions) => AchievementEvaluator.newlyEarned(
            snapshot: ProgressSnapshot(
              totalCooks: regions,
              distinctRegionIds: {
                for (var i = 0; i < regions; i++) 'region$i',
              },
            ),
            alreadyUnlocked: const {},
          ).map((r) => r.id).toList();

      expect(earnedWith(3), isNot(contains('region_runner')));
      expect(earnedWith(4), contains('region_runner'));
    });

    test('a recipe-specific badge needs that recipe', () {
      final withoutInjera = AchievementEvaluator.newlyEarned(
        snapshot: const ProgressSnapshot(
          totalCooks: 20,
          distinctRecipeIds: {'doro', 'shiro'},
        ),
        alreadyUnlocked: const {},
      );
      expect(
        withoutInjera.map((r) => r.id),
        isNot(contains('three_day_ferment')),
      );

      final withInjera = AchievementEvaluator.newlyEarned(
        snapshot: const ProgressSnapshot(
          totalCooks: 20,
          distinctRecipeIds: {'doro', 'injera'},
        ),
        alreadyUnlocked: const {},
      );
      expect(withInjera.map((r) => r.id), contains('three_day_ferment'));
    });

    test('a mastery badge counts dishes at or above the level', () {
      final earned = AchievementEvaluator.newlyEarned(
        snapshot: const ProgressSnapshot(
          totalCooks: 30,
          masteryByRecipe: {
            'doro': MasteryLevel.expert,
            'shiro': MasteryLevel.triedIt,
          },
        ),
        alreadyUnlocked: const {},
      );

      expect(earned.map((r) => r.id), contains('wot_warrior'));
    });

    test('progress is reported for locked badges too', () {
      final all = AchievementEvaluator.allWithProgress(
        snapshot: const ProgressSnapshot(totalCooks: 5, fastingDishesCooked: 6),
        unlocked: const {},
      );

      final fasting = all.firstWhere((entry) => entry.$1.id == 'fasting_table');
      expect(fasting.$2, closeTo(0.5, 0.01)); // 6 of 12
      expect(fasting.$3, isFalse);
    });

    test('the whole catalogue is returned, earned or not', () {
      final all = AchievementEvaluator.allWithProgress(
        snapshot: const ProgressSnapshot(),
        unlocked: const {},
      );
      expect(all.length, Achievements.all.length);
    });
  });

  group('ProgressSnapshot', () {
    test('a cook updates every counter it should', () {
      const before = ProgressSnapshot();
      final after = before.afterCook(
        recipe(id: 'shiro', fasting: true, region: 'gurage'),
        timedStepsCompleted: 2,
      );

      expect(after.totalCooks, 1);
      expect(after.distinctRecipeIds, {'shiro'});
      expect(after.distinctRegionIds, {'gurage'});
      expect(after.fastingDishesCooked, 1);
      expect(after.timedStepsHeld, 2);
    });

    test('cooking the same dish twice counts once as distinct', () {
      final after = const ProgressSnapshot()
          .afterCook(recipe(id: 'doro'))
          .afterCook(recipe(id: 'doro'));

      expect(after.totalCooks, 2);
      expect(after.distinctRecipeIds, {'doro'});
    });
  });
}
