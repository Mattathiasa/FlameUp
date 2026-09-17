import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/cache_entry.dart';
import '../../../core/errors/failure.dart';
import '../../family_recipes/data/family_recipe_repository.dart';
import '../../family_recipes/domain/family_recipe_cookable.dart';
import '../../recipes/data/recipe_repository.dart';
import '../../recipes/domain/recipe.dart';

/// One cookable recipe by id, whatever archive it lives in.
///
/// Catalogue ids (slugs) resolve through the published cache-first stack;
/// family ids (uuids — see [FamilyRecipeAsCookable.isFamilyId]) resolve
/// through the household archive and bridge into the cookable shape. Cook
/// mode, the hub's resume card and anything else that needs to *cook* an id
/// read this, so no surface has to know which collection an id belongs to.
final cookableRecipeProvider =
    StreamProvider.autoDispose.family<Cached<Recipe>, String>((ref, id) {
  if (FamilyRecipeAsCookable.isFamilyId(id)) {
    return ref.watch(familyRecipeRepositoryProvider).watchOne(id).map(
      (family) {
        if (family == null) {
          throw const NotFoundFailure();
        }
        return Cached(value: family.asCookable(), origin: DataOrigin.network);
      },
    );
  }
  return ref.watch(recipeRepositoryProvider).watchRecipe(id);
});
