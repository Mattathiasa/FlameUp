import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/auth_providers.dart';
import '../../recipes/data/recipe_repository.dart';
import '../../recipes/domain/recipe.dart';
import '../data/family_recipe_repository.dart';
import 'family_recipe.dart';

/// The signed-in user's own submissions, any status, newest first.
///
/// Live so a publication flips the card from "in review" the moment a
/// moderator acts, without a pull-to-refresh.
final myFamilyRecipesProvider =
    StreamProvider.autoDispose<List<FamilyRecipe>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(familyRecipeRepositoryProvider).watchMine(uid);
});

/// Published recipes -- the public archive on the Grandma's Kitchen screen.
final publishedFamilyRecipesProvider =
    StreamProvider.autoDispose<List<FamilyRecipe>>((ref) {
  return ref.watch(familyRecipeRepositoryProvider).watchPublished();
});

/// Submissions in community review — the section on Grandma's Kitchen where
/// the community decides what earns its vouches.
final pendingFamilyRecipesProvider =
    StreamProvider.autoDispose<List<FamilyRecipe>>((ref) {
  return ref.watch(familyRecipeRepositoryProvider).watchPending();
});

/// One family recipe by id, live. Null when gone.
final familyRecipeByIdProvider =
    StreamProvider.autoDispose.family<FamilyRecipe?, String>((ref, id) {
  return ref.watch(familyRecipeRepositoryProvider).watchOne(id);
});

/// The published versions (variants) of [baseId], newest first.
///
/// Family variants are read straight from the archive; catalogue-dish variants
/// cannot come from that query — their base is a `recipes/{slug}` id — so the
/// watch is split: [familyVariantsOf] covers family bases, and the detail
/// screen of a catalogue dish asks [watchVariantsOfCatalogue] instead, which
/// the repository implements as a read of this same collection filtered in
/// memory (family_recipes is small; a second composite index is not worth it).
final familyVariantsOfProvider = StreamProvider.autoDispose
    .family<List<FamilyRecipe>, String>((ref, baseId) {
  return ref
      .watch(familyRecipeRepositoryProvider)
      .watchVariants(baseId, catalogueBase: false);
});

/// The versions of a catalogue dish — the detail screen shows them under a
/// "versions" heading, each one a household's take on the classic.
final catalogueVariantsOfProvider = StreamProvider.autoDispose
    .family<List<FamilyRecipe>, String>((ref, baseId) {
  return ref
      .watch(familyRecipeRepositoryProvider)
      .watchVariants(baseId, catalogueBase: true);
});

/// The catalogue dish a family variant is a version of, when it has one.
///
/// The detail screen needs the base's title to label the link; null means the
/// base is another family recipe (or the doc is gone), and the screen says so
/// without fetching further.
final catalogueRecipeByIdProvider =
    StreamProvider.autoDispose.family<Recipe?, String>((ref, id) {
  return ref
      .watch(recipeRepositoryProvider)
      .watchRecipe(id)
      .map((cached) => cached.value);
});
