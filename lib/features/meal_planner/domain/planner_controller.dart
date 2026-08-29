import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/outbox.dart';
import '../../../core/cache/pending_mutation.dart';
import '../../../core/constants/firestore_paths.dart';
import '../../../core/services/local_store.dart';
import '../../auth/domain/auth_providers.dart';
import '../../recipes/data/recipe_seed_source.dart';
import '../../shopping/domain/shopping_controller.dart';
import 'meal_plan.dart';

/// The weekly meal plan.
class PlannerController extends Notifier<MealPlan> {
  static const String _key = 'planner.week';

  @override
  MealPlan build() {
    final stored =
        ref.watch(localStoreProvider).readJson(LocalStore.boxMisc, _key);
    final plan = MealPlan.fromJson(stored);

    // A plan from a previous week is not this week's plan.
    final thisWeek = MealPlan.weekIdFor(DateTime.now());
    return plan.weekId == thisWeek ? plan : MealPlan(weekId: thisWeek);
  }

  Future<void> _persist(MealPlan plan) async {
    state = plan;
    await ref
        .read(localStoreProvider)
        .writeJson(LocalStore.boxMisc, _key, plan.toJson());

    final uid = ref.read(currentUidProvider);
    if (uid == null) return;

    await ref.read(outboxProvider).enqueue(
          PendingMutation(
            kind: MutationKind.mealPlan,
            path: '${FirestorePaths.userMealPlans(uid)}/${plan.weekId}',
            payload: plan.toJson(),
          ),
        );
  }

  Future<void> setMeal(int weekday, MealSlot slot, String? recipeId) =>
      _persist(state.withMeal(weekday, slot, recipeId));

  Future<void> clear() => _persist(MealPlan(weekId: state.weekId));

  /// Build a shopping list from everything planned.
  ///
  /// Ingredients are merged across dishes, so a week with three recipes that
  /// each need onions produces one onion line rather than three.
  Future<int> buildShoppingList() async {
    final recipeIds = state.allRecipeIds;
    if (recipeIds.isEmpty) return 0;

    final catalogue = await ref.read(recipeSeedSourceProvider).load();
    final byId = {for (final recipe in catalogue) recipe.id: recipe};
    final shopping = ref.read(shoppingControllerProvider.notifier);

    var added = 0;
    for (final id in recipeIds) {
      final recipe = byId[id];
      if (recipe == null) continue;
      await shopping.addRecipe(recipe);
      added++;
    }
    return added;
  }
}

final plannerControllerProvider =
    NotifierProvider<PlannerController, MealPlan>(PlannerController.new);
