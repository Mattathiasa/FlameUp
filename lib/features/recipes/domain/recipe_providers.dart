import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/cache_entry.dart';
import '../../settings/domain/settings_providers.dart';
import '../data/recipe_repository.dart';
import 'recipe.dart';
import 'recipe_query.dart';

/// The active Discover query. Held here so the filter chips, the search field
/// and the results list all read one source.
class RecipeQueryController extends Notifier<RecipeQuery> {
  @override
  RecipeQuery build() => const RecipeQuery();

  void setText(String? text) => state = (text == null || text.trim().isEmpty)
      ? state.copyWith(clearText: true)
      : state.copyWith(text: text);

  void setRegion(String? regionId) => state = regionId == null
      ? state.copyWith(clearRegion: true)
      : state.copyWith(regionId: regionId);

  void setCategory(String? category) => state = category == null
      ? state.copyWith(clearCategory: true)
      : state.copyWith(category: category);

  void setSort(RecipeSort sort) => state = state.copyWith(sort: sort);

  void toggleFasting() =>
      state = state.copyWith(fastingOnly: !state.fastingOnly);

  void setMaxMinutes(int? minutes) =>
      state = state.copyWith(maxMinutes: minutes);

  void clear() => state = const RecipeQuery();
}

final recipeQueryProvider =
    NotifierProvider<RecipeQueryController, RecipeQuery>(
  RecipeQueryController.new,
);

/// Results for the active query, cache-first.
final recipeListProvider =
    StreamProvider.autoDispose<Cached<List<Recipe>>>((ref) {
  final query = ref.watch(recipeQueryProvider);
  return ref.watch(recipeRepositoryProvider).watchRecipes(query);
});

/// Results for an explicit query — used by Today's rails, which each show a
/// different slice without touching the Discover filters.
final recipesForProvider = StreamProvider.autoDispose
    .family<Cached<List<Recipe>>, RecipeQuery>((ref, query) {
  return ref.watch(recipeRepositoryProvider).watchRecipes(query);
});

/// One recipe by id.
final recipeProvider =
    StreamProvider.autoDispose.family<Cached<Recipe>, String>((ref, id) {
  return ref.watch(recipeRepositoryProvider).watchRecipe(id);
});

/// The serving count the detail screen is currently showing.
///
/// Per-recipe and auto-disposed, so adjusting servings on one dish does not
/// leak into the next.
class ServingsController extends AutoDisposeFamilyNotifier<int, int> {
  /// [arg] is the recipe's own default serving count.
  @override
  int build(int arg) => arg;

  /// Clamped: half a serving is meaningless, and twenty is a different recipe.
  void set(int servings) => state = servings.clamp(1, 20);

  void increment() => set(state + 1);
  void decrement() => set(state - 1);
}

final servingsProvider =
    AutoDisposeNotifierProvider.family<ServingsController, int, int>(
  ServingsController.new,
);

/// Whether the app is currently rendering Amharic. Read by every widget that
/// has to choose between a field and its `...Am` twin.
final isAmharicProvider = Provider<bool>((ref) {
  return ref.watch(languageProvider) == AppLanguage.amharic;
});
