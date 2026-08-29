import 'package:flameup/features/meal_planner/domain/meal_plan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('week identity', () {
    test('a plan belongs to a definite week', () {
      // Keyed by ISO week so "this week" does not change meaning on Sunday
      // night and silently adopt last week's plan.
      final id = MealPlan.weekIdFor(DateTime(2026, 3, 4));
      expect(id, matches(RegExp(r'^\d{4}-W\d{2}$')));
    });

    test('days in the same week share an id', () {
      final monday = MealPlan.weekIdFor(DateTime(2026, 3, 2));
      final friday = MealPlan.weekIdFor(DateTime(2026, 3, 6));
      expect(monday, friday);
    });

    test('different weeks differ', () {
      expect(
        MealPlan.weekIdFor(DateTime(2026, 3, 4)),
        isNot(MealPlan.weekIdFor(DateTime(2026, 3, 18))),
      );
    });
  });

  group('slots', () {
    test('assigns and reads back a meal', () {
      final plan = const MealPlan(weekId: '2026-W10')
          .withMeal(3, MealSlot.dinner, 'doro');

      expect(plan.recipeAt(3, MealSlot.dinner), 'doro');
      expect(plan.recipeAt(3, MealSlot.lunch), isNull);
      expect(plan.isEmpty, isFalse);
    });

    test('clearing a slot removes it', () {
      final plan = const MealPlan(weekId: '2026-W10')
          .withMeal(3, MealSlot.dinner, 'doro')
          .withMeal(3, MealSlot.dinner, null);

      expect(plan.recipeAt(3, MealSlot.dinner), isNull);
      expect(plan.isEmpty, isTrue);
    });

    test('a day with no meals left is dropped entirely', () {
      final plan = const MealPlan(weekId: '2026-W10')
          .withMeal(2, MealSlot.lunch, 'shiro')
          .withMeal(2, MealSlot.lunch, null);

      expect(plan.slots.containsKey(2), isFalse);
    });

    test('setting one slot does not disturb another', () {
      final plan = const MealPlan(weekId: '2026-W10')
          .withMeal(1, MealSlot.breakfast, 'genfo')
          .withMeal(1, MealSlot.dinner, 'doro');

      expect(plan.recipeAt(1, MealSlot.breakfast), 'genfo');
      expect(plan.recipeAt(1, MealSlot.dinner), 'doro');
    });
  });

  group('shopping input', () {
    test('keeps duplicates, because cooking twice means buying twice', () {
      final plan = const MealPlan(weekId: '2026-W10')
          .withMeal(1, MealSlot.dinner, 'doro')
          .withMeal(4, MealSlot.dinner, 'doro');

      expect(plan.allRecipeIds, ['doro', 'doro']);
    });
  });

  group('serialisation', () {
    test('round trips', () {
      final original = const MealPlan(weekId: '2026-W10')
          .withMeal(1, MealSlot.breakfast, 'genfo')
          .withMeal(5, MealSlot.dinner, 'beyay');

      final restored = MealPlan.fromJson(original.toJson());

      expect(restored.weekId, '2026-W10');
      expect(restored.recipeAt(1, MealSlot.breakfast), 'genfo');
      expect(restored.recipeAt(5, MealSlot.dinner), 'beyay');
    });

    test('a corrupt document decodes to an empty plan, not a crash', () {
      expect(MealPlan.fromJson(null).isEmpty, isTrue);
      expect(
        MealPlan.fromJson(const {'weekId': 'x', 'slots': 'not-a-map'}).isEmpty,
        isTrue,
      );
      expect(
        MealPlan.fromJson({
          'weekId': 'x',
          'slots': {
            'notanint': {'dinner': 'doro'},
          },
        }).isEmpty,
        isTrue,
      );
    });
  });
}
