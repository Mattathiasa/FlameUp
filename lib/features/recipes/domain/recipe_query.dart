import 'recipe.dart';

/// How Discover is filtered and sorted.
///
/// A value type so it can be a cache key: `CacheStore.keyFor` turns it into a
/// stable string, and two identical queries share one cache entry rather than
/// fetching twice.
class RecipeQuery {
  const RecipeQuery({
    this.text,
    this.regionId,
    this.category,
    this.difficulty,
    this.maxMinutes,
    this.fastingOnly = false,
    this.veganOnly = false,
    this.glutenFreeOnly = false,
    this.dairyFreeOnly = false,
    this.maxHeat,
    this.sort = RecipeSort.recommended,
    this.excludeIds = const {},
  });

  final String? text;
  final String? regionId;
  final String? category;
  final Difficulty? difficulty;
  final int? maxMinutes;
  final bool fastingOnly;
  final bool veganOnly;
  final bool glutenFreeOnly;
  final bool dairyFreeOnly;

  /// Filters out anything hotter than the user can take.
  final int? maxHeat;

  final RecipeSort sort;

  /// Used by "new to me" — dishes already cooked are left out.
  final Set<String> excludeIds;

  bool get isEmpty =>
      text == null &&
      regionId == null &&
      category == null &&
      difficulty == null &&
      maxMinutes == null &&
      maxHeat == null &&
      !fastingOnly &&
      !veganOnly &&
      !glutenFreeOnly &&
      !dairyFreeOnly &&
      excludeIds.isEmpty;

  RecipeQuery copyWith({
    String? text,
    String? regionId,
    String? category,
    Difficulty? difficulty,
    int? maxMinutes,
    bool? fastingOnly,
    bool? veganOnly,
    bool? glutenFreeOnly,
    bool? dairyFreeOnly,
    int? maxHeat,
    RecipeSort? sort,
    Set<String>? excludeIds,
    bool clearText = false,
    bool clearRegion = false,
    bool clearCategory = false,
  }) =>
      RecipeQuery(
        text: clearText ? null : (text ?? this.text),
        regionId: clearRegion ? null : (regionId ?? this.regionId),
        category: clearCategory ? null : (category ?? this.category),
        difficulty: difficulty ?? this.difficulty,
        maxMinutes: maxMinutes ?? this.maxMinutes,
        fastingOnly: fastingOnly ?? this.fastingOnly,
        veganOnly: veganOnly ?? this.veganOnly,
        glutenFreeOnly: glutenFreeOnly ?? this.glutenFreeOnly,
        dairyFreeOnly: dairyFreeOnly ?? this.dairyFreeOnly,
        maxHeat: maxHeat ?? this.maxHeat,
        sort: sort ?? this.sort,
        excludeIds: excludeIds ?? this.excludeIds,
      );

  /// Stable parameters for a cache key.
  Map<String, Object?> toParams() => {
        if (text != null) 'q': text,
        if (regionId != null) 'region': regionId,
        if (category != null) 'category': category,
        if (difficulty != null) 'difficulty': difficulty!.value,
        if (maxMinutes != null) 'maxMin': maxMinutes,
        if (maxHeat != null) 'maxHeat': maxHeat,
        if (fastingOnly) 'fasting': true,
        if (veganOnly) 'vegan': true,
        if (glutenFreeOnly) 'gf': true,
        if (dairyFreeOnly) 'df': true,
        'sort': sort.name,
      };

  /// Applies the query to an in-memory list.
  ///
  /// Used against the bundled catalogue and the cache. The Firestore path
  /// pushes the same predicates into indexed server-side queries — this is not
  /// "download everything and filter", it is the offline half of the same
  /// contract.
  List<Recipe> apply(List<Recipe> source) {
    final needle = text?.trim().toLowerCase();

    final matched = source.where((recipe) {
      if (excludeIds.contains(recipe.id)) return false;
      if (regionId != null && recipe.regionId != regionId) return false;
      if (category != null && recipe.category != category) return false;
      if (difficulty != null && recipe.difficulty != difficulty) return false;
      if (maxMinutes != null && recipe.totalMinutes > maxMinutes!) return false;
      if (maxHeat != null && recipe.heatLevel > maxHeat!) return false;
      if (fastingOnly && !recipe.isFasting) return false;
      if (veganOnly && !recipe.isVegan) return false;
      if (glutenFreeOnly && !recipe.isGlutenFree) return false;
      if (dairyFreeOnly && !recipe.isDairyFree) return false;

      if (needle != null && needle.isNotEmpty) {
        final haystack = [
          recipe.title,
          recipe.titleAm,
          recipe.subtitle,
          recipe.subtitleAm,
          recipe.category,
          ...recipe.tags,
          ...recipe.ingredients.map((i) => i.name),
          ...recipe.ingredients.map((i) => i.nameAm),
        ].join(' ').toLowerCase();
        if (!haystack.contains(needle)) return false;
      }

      return true;
    }).toList();

    matched.sort(sort.comparator);
    return matched;
  }
}

/// Sort orders Discover offers.
enum RecipeSort {
  /// Highest rated first, then most cooked — what the design's default feed
  /// shows.
  recommended,
  quickest,
  mostCooked,
  highestRated,
  newest;

  int Function(Recipe, Recipe) get comparator => switch (this) {
        RecipeSort.recommended => (a, b) {
            final byRating = b.averageRating.compareTo(a.averageRating);
            if (byRating != 0) return byRating;
            return b.numberOfCooks.compareTo(a.numberOfCooks);
          },
        RecipeSort.quickest => (a, b) =>
            a.totalMinutes.compareTo(b.totalMinutes),
        RecipeSort.mostCooked => (a, b) =>
            b.numberOfCooks.compareTo(a.numberOfCooks),
        RecipeSort.highestRated => (a, b) =>
            b.averageRating.compareTo(a.averageRating),
        RecipeSort.newest => (a, b) => a.id.compareTo(b.id),
      };
}
