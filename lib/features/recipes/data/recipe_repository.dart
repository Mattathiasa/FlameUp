import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/cache_entry.dart';
import '../../../core/cache/cache_store.dart';
import '../../../core/cache/offline_first.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/firestore_paths.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/errors/failure.dart';
import '../../../core/result/result.dart';
import '../../../core/services/local_store.dart';
import '../domain/recipe.dart';
import '../domain/recipe_query.dart';
import 'recipe_seed_source.dart';

/// Reads recipes offline-first.
///
/// Three layers, in order: the bundled catalogue (always present), the cache
/// (what has been seen), and Firestore (what is current). A screen gets
/// something to render immediately in every case, including a first run with
/// no network.
class RecipeRepository {
  RecipeRepository({
    required CacheStore cache,
    required RecipeSeedSource seed,
    FirebaseFirestore? firestore,
  })  : _cache = cache,
        _seed = seed,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final CacheStore _cache;
  final RecipeSeedSource _seed;
  final FirebaseFirestore _firestore;

  static const String _box = LocalStore.boxRecipes;

  /// A list of recipes for [query], cache-first.
  Stream<Cached<List<Recipe>>> watchRecipes(
    RecipeQuery query, {
    bool forceRefresh = false,
  }) async* {
    final key = CacheStore.keyFor('recipes', query.toParams());

    // The bundled catalogue means a first run is never empty, even offline.
    final seeded = query.apply(await _seed.load());

    yield* OfflineFirst.read<List<Recipe>>(
      readCache: () {
        final entry = _cache.readList(_box, key);
        if (entry == null) {
          // No cache yet: the bundle stands in, marked as cached so the UI
          // knows it is not live.
          return seeded.isEmpty
              ? null
              : CacheEntry(value: seeded, cachedAt: DateTime.now());
        }
        return CacheEntry(
          value: entry.value
              .map((json) => Recipe.fromJson(json['id'] as String, json))
              .toList(growable: false),
          cachedAt: entry.cachedAt,
        );
      },
      fetch: () => _fetchRecipes(query),
      writeCache: (recipes) => _cache.writeList(
        _box,
        key,
        recipes.map((r) => {'id': r.id, ...r.toJson()}).toList(),
      ),
      forceRefresh: forceRefresh,
      // Re-emitting an identical list would rebuild the screen for nothing.
      hasChanged: (cached, fresh) => !_sameIds(cached, fresh),
    );
  }

  /// One recipe. Falls back to the bundle so a deep link works offline.
  Stream<Cached<Recipe>> watchRecipe(String id) async* {
    final key = 'recipe.$id';

    yield* OfflineFirst.read<Recipe>(
      readCache: () {
        final entry = _cache.readDoc(_box, key);
        if (entry != null) {
          return CacheEntry(
            value: Recipe.fromJson(id, entry.value),
            cachedAt: entry.cachedAt,
          );
        }
        return null;
      },
      fetch: () async {
        final snapshot = await _firestore.doc(FirestorePaths.recipe(id)).get();
        final data = snapshot.data();
        if (data == null) {
          final bundled = await _seed.byId(id);
          if (bundled != null) return bundled;
          // Throwing the Failure directly: ErrorMapper passes an existing
          // Failure through untouched, so this stays a NotFoundFailure
          // rather than being flattened into UnknownFailure.
          throw const NotFoundFailure();
        }
        return Recipe.fromJson(id, data);
      },
      writeCache: (recipe) => _cache.writeDoc(_box, key, recipe.toJson()),
    );
  }

  /// Server-side query. Predicates are pushed into indexed Firestore queries
  /// rather than filtered on the device.
  Future<List<Recipe>> _fetchRecipes(RecipeQuery query) async {
    Query<Map<String, dynamic>> q = _firestore
        .collection(FirestorePaths.recipes)
        .where('status', isEqualTo: 'published');

    if (query.regionId != null) {
      q = q.where('regionId', isEqualTo: query.regionId);
    }
    if (query.category != null) {
      q = q.where('category', isEqualTo: query.category);
    }
    if (query.fastingOnly) q = q.where('isFasting', isEqualTo: true);
    if (query.veganOnly) q = q.where('isVegan', isEqualTo: true);
    if (query.glutenFreeOnly) q = q.where('isGlutenFree', isEqualTo: true);
    if (query.dairyFreeOnly) q = q.where('isDairyFree', isEqualTo: true);
    if (query.difficulty != null) {
      q = q.where('difficulty', isEqualTo: query.difficulty!.value);
    }
    if (query.maxMinutes != null) {
      q = q.where('totalMinutes', isLessThanOrEqualTo: query.maxMinutes);
    }

    // Text search uses the stored token array, so the collection is never
    // pulled down to be filtered here. Firestore caps this at 30 values.
    final needle = query.text?.trim().toLowerCase();
    if (needle != null && needle.isNotEmpty) {
      final tokens = needle
          .split(RegExp(r'[^\wሀ-፿]+'))
          .where((t) => t.length >= 2)
          .take(10)
          .toList();
      if (tokens.isNotEmpty) {
        q = q.where('searchTokens', arrayContainsAny: tokens);
      }
    }

    final snapshot = await q.limit(AppConstants.pageSize * 3).get();
    final recipes = snapshot.docs
        .map((doc) => Recipe.fromJson(doc.id, doc.data()))
        .toList();

    // An empty backend is not an error: the bundled catalogue is the answer
    // until the seeder has run.
    if (recipes.isEmpty) return query.apply(await _seed.load());

    recipes.sort(query.sort.comparator);
    return recipes;
  }

  /// Whether two result lists hold the same recipes in the same order.
  static bool _sameIds(List<Recipe> a, List<Recipe> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  /// Everything in the bundle, for the offline browse case.
  Future<Result<List<Recipe>>> allBundled() =>
      ErrorMapper.guard(() => _seed.load());
}

final recipeRepositoryProvider = Provider<RecipeRepository>((ref) {
  return RecipeRepository(
    cache: ref.watch(cacheStoreProvider),
    seed: ref.watch(recipeSeedSourceProvider),
  );
});
