import 'package:flameup/features/cooking/domain/cooking_session.dart';
import 'package:flameup/features/family_recipes/domain/family_recipe.dart';
import 'package:flameup/features/family_recipes/domain/family_recipe_cookable.dart';
import 'package:flutter_test/flutter_test.dart';

FamilyRecipe familyRecipe({
  String titleAm = '',
  String stepsText = 'Toast the spices.\nSimmer twenty minutes.\nServe hot.',
}) =>
    FamilyRecipe(
      id: '0b9e6c1e-1111-2222-3333-444455556666',
      authorId: 'author-1',
      status: FamilyRecipeStatus.published,
      title: 'Emahoy`s shiro',
      titleAm: titleAm,
      teacherName: 'Emahoy Tsehay',
      story: 'A Tuesday dish.',
      stepsText: stepsText,
      ingredientsText: 'chickpea flour\nberbere\nwater',
    );

void main() {
  group('isFamilyId discriminates by id shape', () {
    test('a uuid is family', () {
      expect(
        FamilyRecipeAsCookable.isFamilyId(
          '0b9e6c1e-1111-2222-3333-444455556666',
        ),
        isTrue,
      );
    });

    test('catalogue slugs are not family — even with underscores', () {
      expect(FamilyRecipeAsCookable.isFamilyId('doro_wat'), isFalse);
      expect(FamilyRecipeAsCookable.isFamilyId('kitfo'), isFalse);
    });
  });

  group('asCookable bridges honestly', () {
    test('steps become one untimed step per line', () {
      final cookable = familyRecipe().asCookable();

      expect(cookable.steps, hasLength(3));
      expect(cookable.steps[1].text, 'Simmer twenty minutes.');
      for (final step in cookable.steps) {
        expect(step.hasTimer, isFalse, reason: 'free text has no durations');
      }
    });

    test('blank lines are dropped, not turned into empty steps', () {
      final cookable = familyRecipe(
        stepsText: 'Step one.\n\n   \nStep two.',
      ).asCookable();

      expect(cookable.steps.map((s) => s.text), ['Step one.', 'Step two.']);
    });

    test('ingredient lines become to-taste lines, scaled as zero', () {
      final cookable = familyRecipe().asCookable();

      expect(cookable.ingredients, hasLength(3));
      expect(cookable.ingredients.every((i) => i.isToTaste), isTrue);
      // Scaling a free-text line is meaningless: quantity is zero, so the
      // scaled amount stays honest ("to taste") at any serving count.
      expect(
        cookable.ingredientsFor(8).every((i) => i.isToTaste),
        isTrue,
      );
    });

    test('the Amharic title falls back to the base line when absent', () {
      final cookable = familyRecipe(titleAm: '').asCookable();
      expect(cookable.localisedTitle(amharic: true), 'Emahoy`s shiro');
      expect(cookable.localisedTitle(amharic: false), 'Emahoy`s shiro');
    });

    test('a real Amharic title is kept and wins in Amharic mode', () {
      final cookable = familyRecipe(titleAm: 'ሽሮ').asCookable();
      expect(cookable.localisedTitle(amharic: true), 'ሽሮ');
    });

    test('the family flag and author ride along', () {
      final cookable = familyRecipe().asCookable();
      expect(cookable.isFamilyRecipe, isTrue);
      expect(cookable.authorId, 'author-1');
    });

    test('no steps yields a cookable recipe with zero steps', () {
      final cookable = familyRecipe(stepsText: '').asCookable();
      expect(cookable.steps, isEmpty);
    });
  });

  group('skipped steps survive the round trip', () {
    test('toJson/fromJson keeps the skipped step indexes', () {
      final session = CookingSession(
        recipeId: 'doro',
        totalSteps: 9,
        servings: 6,
      ).copyWith(skippedSteps: [2, 5]);

      final restored = CookingSession.fromJson(session.toJson())!;

      expect(restored.skippedSteps, [2, 5]);
    });

    test('older sessions without the field read as nothing skipped', () {
      final json = CookingSession(
        recipeId: 'doro',
        totalSteps: 9,
        servings: 6,
      ).toJson()
        ..remove('skippedSteps');

      expect(CookingSession.fromJson(json)!.skippedSteps, isEmpty);
    });

    test('non-int junk in the stored list is dropped', () {
      final json = CookingSession(
        recipeId: 'doro',
        totalSteps: 9,
        servings: 6,
      ).toJson();
      json['skippedSteps'] = [1, 'x', 2.5, 3];

      expect(CookingSession.fromJson(json)!.skippedSteps, [1, 3]);
    });
  });
}
