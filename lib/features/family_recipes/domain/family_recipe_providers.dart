import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/auth_providers.dart';
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
