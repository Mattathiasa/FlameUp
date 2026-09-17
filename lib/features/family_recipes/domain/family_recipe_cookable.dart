import '../../recipes/domain/ingredient.dart';
import '../../recipes/domain/recipe.dart';
import 'family_recipe.dart';

/// Bridge from a household recipe to the cooking pipeline.
///
/// Cook mode, timers, alerts and session history all speak `Recipe`. A family
/// recipe stores steps as free text and ingredients as lines, so this bridge
/// composes an honest equivalent rather than a fake one: no field is
/// invented, and missing optional structure degrades instead of crashing.
extension FamilyRecipeAsCookable on FamilyRecipe {
  /// True when [recipeId] names a family recipe rather than a catalogue one.
  ///
  /// Family ids are uuids; catalogue ids are slugs (`doro_wat`), so the shape
  /// is a reliable discriminator. Cook mode and the proof-of-cook gates use
  /// this to route resolution — the form's `_uuidShape` check is the same
  /// convention.
  static bool isFamilyId(String recipeId) => RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        caseSensitive: false,
      ).hasMatch(recipeId);

  /// The cookable equivalent of this family recipe.
  ///
  /// Steps become untimed steps (the free-text form has no duration field —
  /// inventing one would fake precision); the Amharic text falls back to the
  /// base line when a submitter wrote only one language, so no step renders
  /// blank in Amharic mode. Difficulty is derived from step count, and the
  /// recipe is flagged `isFamilyRecipe` so history rows can tell the two
  /// catalogues apart.
  Recipe asCookable() {
    final lines = stepLines;
    final hasAmharic = titleAm.isNotEmpty;

    return Recipe(
      id: id,
      title: displayName,
      // The detail screen's own fallback, mirrored: only claim Amharic when
      // the submitter actually wrote it.
      titleAm: hasAmharic ? titleAm : displayName,
      subtitle: teacherName.isNotEmpty ? teacherName : ' ',
      subtitleAm: ' ',
      regionId: regionId ?? 'unknown',
      category: 'family',
      difficulty: Difficulty.beginner,
      totalMinutes: 0,
      servings: 1,
      xpReward: 0,
      ingredients: [
        for (final line in ingredientLines)
          Ingredient(
            name: line,
            nameAm: line,
            quantity: 0,
            unit: '',
            unitAm: '',
          ),
      ],
      steps: [
        for (var i = 0; i < lines.length; i++)
          RecipeStep(
            index: i,
            text: lines[i],
            textAm: lines[i],
          ),
      ],
      story: story,
      storyAm: story,
      gradientA: '#C96F2E',
      gradientB: '#8C3B14',
      isFamilyRecipe: true,
      authorId: authorId,
    );
  }
}
