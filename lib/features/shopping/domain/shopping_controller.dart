import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/outbox.dart';
import '../../../core/cache/pending_mutation.dart';
import '../../../core/constants/firestore_paths.dart';
import '../../../core/services/local_store.dart';
import '../../auth/domain/auth_providers.dart';
import '../../recipes/domain/ingredient.dart';
import '../../recipes/domain/recipe.dart';
import 'shopping_item.dart';

/// The shopping list.
///
/// Local-first without qualification: a shopping list is used *in a shop*,
/// which is exactly where signal fails. Every change writes to disk
/// immediately and syncs when it can.
class ShoppingController extends Notifier<List<ShoppingItem>> {
  static const String _key = 'shopping.items';

  @override
  List<ShoppingItem> build() {
    final stored =
        ref.watch(localStoreProvider).readJsonList(LocalStore.boxMisc, _key);
    return stored
            ?.map(ShoppingItem.fromJson)
            .whereType<ShoppingItem>()
            .toList() ??
        [];
  }

  Future<void> _persist(List<ShoppingItem> items) async {
    state = items;
    await ref.read(localStoreProvider).writeJson(
          LocalStore.boxMisc,
          _key,
          items.map((i) => i.toJson()).toList(),
        );

    final uid = ref.read(currentUidProvider);
    if (uid == null) return;

    await ref.read(outboxProvider).enqueue(
          PendingMutation(
            kind: MutationKind.shoppingItem,
            path: FirestorePaths.userShoppingItems(uid),
            payload: {'items': items.map((i) => i.toJson()).toList()},
          ),
        );
  }

  /// Add a recipe's ingredients, scaled to [servings].
  ///
  /// Merges with what is already there, so adding two recipes that both need
  /// onions produces one line rather than two.
  Future<void> addRecipe(Recipe recipe, {int? servings}) async {
    final ingredients = recipe.ingredientsFor(servings ?? recipe.servings);
    final items = ingredients
        // "Salt to taste" on a shopping list is noise.
        .where((i) => !i.isToTaste)
        .map((i) => ShoppingItem.fromIngredient(i, recipeId: recipe.id))
        .toList();

    await _persist(ShoppingListBuilder.merge(state, items));
  }

  Future<void> addManual(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    await _persist([
      ...state,
      ShoppingItem(name: trimmed, nameAm: trimmed, manual: true),
    ]);
  }

  Future<void> toggle(String id) async {
    await _persist([
      for (final item in state)
        if (item.id == id) item.copyWith(checked: !item.checked) else item,
    ]);
  }

  Future<void> remove(String id) async {
    await _persist(state.where((item) => item.id != id).toList());
  }

  Future<void> clearChecked() async {
    await _persist(state.where((item) => !item.checked).toList());
  }

  Map<Aisle, List<ShoppingItem>> get grouped =>
      ShoppingListBuilder.byAisle(state);

  int get remainingCount => state.where((i) => !i.checked).length;
}

final shoppingControllerProvider =
    NotifierProvider<ShoppingController, List<ShoppingItem>>(
  ShoppingController.new,
);
