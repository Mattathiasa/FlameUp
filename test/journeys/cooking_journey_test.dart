// Journey tests: the paths where a bug costs the user something real -- a lost
// cooking session, a double-awarded reward, a timer that lies.
//
// These run as ordinary tests rather than under integration_test, because
// every property here is about domain state surviving serialisation, and none
// of it needs a running app. Requiring a device binding for pure logic buys
// nothing and costs twelve minutes on an emulator.
//
// The genuine device test -- does the app actually launch and render -- lives
// in integration_test/app_launch_test.dart.

import 'package:flameup/features/cooking/domain/cooking_session.dart';
import 'package:flameup/features/gamification/domain/level_curve.dart';
import 'package:flameup/features/gamification/domain/mastery.dart';
import 'package:flameup/features/gamification/domain/streak_calculator.dart';
import 'package:flameup/features/gamification/domain/xp_rules.dart';
import 'package:flameup/features/recipes/domain/recipe.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/recipes/recipe_query_test.dart' show loadSeed;

void main() {
  late List<Recipe> catalogue;

  setUpAll(() => catalogue = loadSeed());

  group('the cooking journey', () {
    test('a session survives being serialised and restored mid-cook', () {
      // The kill-and-resume path: the app dies at step 4 with a timer
      // running, and comes back with both intact.
      final recipe = catalogue.firstWhere((r) => r.id == 'doro');
      final started = DateTime(2026, 3, 1, 18);

      var session = CookingSession(
        recipeId: recipe.id,
        totalSteps: recipe.steps.length,
        servings: recipe.servings,
        startedAt: started,
      );

      session = session.copyWith(
        currentStep: 4,
        stepDeadlines: {4: started.add(const Duration(minutes: 45))},
      );

      final restored = CookingSession.fromJson(session.toJson())!;

      expect(restored.currentStep, 4);
      expect(restored.idempotencyKey, session.idempotencyKey);
      expect(
        restored.remainingFor(4, now: started.add(const Duration(minutes: 30))),
        const Duration(minutes: 15),
        reason: 'the timer must be measured against the clock, not ticks',
      );
    });

    test('a timer that expired while the app was closed reports zero', () {
      final started = DateTime(2026, 3, 1, 18);
      final session = CookingSession(
        recipeId: 'doro',
        totalSteps: 9,
        servings: 6,
        stepDeadlines: {2: started.add(const Duration(minutes: 8))},
      );

      final reopened = started.add(const Duration(hours: 2));

      expect(session.remainingFor(2, now: reopened), Duration.zero);
      expect(session.hasExpiredTimer(2, now: reopened), isTrue);
    });

    test('completing a cook produces one reward key, not one per attempt', () {
      // The property that stops XP doubling when the outbox replays.
      final session = CookingSession(
        recipeId: 'doro',
        totalSteps: 9,
        servings: 6,
      );

      final advanced = session.copyWith(currentStep: 8);
      final completed = advanced.copyWith(
        status: SessionStatus.completed,
        completedAt: DateTime.now(),
      );
      final retried = CookingSession.fromJson(completed.toJson())!;

      expect(
        {session, advanced, completed, retried}
            .map((s) => s.idempotencyKey)
            .toSet(),
        hasLength(1),
      );
    });
  });

  group('progression after a cook', () {
    test('first cook: XP, level, mastery and streak all move together', () {
      const rules = XpRules();
      final curve = LevelCurve.standard;
      final recipe = catalogue.firstWhere((r) => r.id == 'shiro');

      const mastery = RecipeMastery(recipeId: 'shiro');
      final streakAfter = StreakCalculator.afterCook(
        const StreakState(),
        on: DateTime(2026, 3, 1),
      );

      final awards = rules.forCompletedCook(
        recipe: recipe,
        mastery: mastery,
        streakAfter: streakAfter.current,
      );
      final xp = rules.totalOf(awards);

      expect(
        xp,
        greaterThan(recipe.xpReward),
        reason: 'a first cook should include the first-time bonus',
      );
      expect(curve.levelFor(xp), greaterThanOrEqualTo(1));
      expect(mastery.afterCook().level, MasteryLevel.triedIt);
      expect(streakAfter.current, 1);
    });

    test('a week of daily cooking reaches the streak milestone', () {
      var streak = const StreakState();

      for (var day = 1; day <= 7; day++) {
        streak = StreakCalculator.afterCook(
          streak,
          on: DateTime(2026, 3, day),
        );
      }

      expect(streak.current, 7);
      expect(streak.longest, 7);

      const rules = XpRules();
      final awards = rules.forCompletedCook(
        recipe: catalogue.first,
        mastery: const RecipeMastery(recipeId: 'x', cookCount: 4),
        streakAfter: streak.current,
      );

      expect(
        awards.map((a) => a.reason),
        contains(XpReason.streakMilestone),
      );
    });

    test('cooking one dish twelve times reaches Master', () {
      var mastery = const RecipeMastery(recipeId: 'shiro');
      for (var i = 0; i < 12; i++) {
        mastery = mastery.afterCook(rating: 4);
      }

      expect(mastery.level, MasteryLevel.master);
      expect(mastery.cooksToNext, 0);
    });

    test('grinding one dish pays less than cooking twelve different ones', () {
      // The decay exists so the optimal strategy is discovery, not repetition.
      const rules = XpRules();
      final recipe = catalogue.firstWhere((r) => r.id == 'doro');

      var grindTotal = 0;
      for (var cooks = 0; cooks < 12; cooks++) {
        grindTotal += rules.totalOf(
          rules.forCompletedCook(
            recipe: recipe,
            mastery: RecipeMastery(recipeId: recipe.id, cookCount: cooks),
            streakAfter: 3,
          ),
        );
      }

      var varietyTotal = 0;
      for (final dish in catalogue.take(12)) {
        varietyTotal += rules.totalOf(
          rules.forCompletedCook(
            recipe: dish,
            mastery: RecipeMastery(recipeId: dish.id),
            streakAfter: 3,
          ),
        );
      }

      expect(varietyTotal, greaterThan(grindTotal));
    });
  });

  group('serving-size scaling end to end', () {
    test('scaling a real recipe keeps every ingredient proportional', () {
      final recipe = catalogue.firstWhere((r) => r.id == 'doro');
      final doubled = recipe.ingredientsFor(recipe.servings * 2);

      for (var i = 0; i < recipe.ingredients.length; i++) {
        expect(
          doubled[i].quantity,
          recipe.ingredients[i].quantity * 2,
          reason: '${recipe.ingredients[i].name} did not scale',
        );
      }
    });
  });
}
