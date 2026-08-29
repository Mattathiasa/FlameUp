import 'dart:convert';
import 'dart:io';

import 'package:flameup/features/recipes/domain/recipe.dart';
import 'package:flameup/features/recipes/domain/recipe_query.dart';
import 'package:flutter_test/flutter_test.dart';

/// The catalogue the app actually ships, so these tests exercise real data
/// rather than fixtures that could drift from it.
List<Recipe> loadSeed() {
  final raw = File('assets/seed/recipes.json').readAsStringSync();
  final json = jsonDecode(raw) as Map<String, dynamic>;
  return (json['recipes'] as Map<String, dynamic>)
      .entries
      .map((e) => Recipe.fromJson(e.key, (e.value as Map).cast()))
      .toList();
}

void main() {
  late List<Recipe> catalogue;

  setUpAll(() => catalogue = loadSeed());

  group('the bundled catalogue', () {
    test('meets the brief\'s 25-recipe floor', () {
      expect(catalogue.length, greaterThanOrEqualTo(25));
    });

    test('every recipe has steps and ingredients in both languages', () {
      for (final recipe in catalogue) {
        expect(recipe.steps, isNotEmpty, reason: '${recipe.id} has no steps');
        expect(
          recipe.ingredients,
          isNotEmpty,
          reason: '${recipe.id} has no ingredients',
        );

        for (final step in recipe.steps) {
          expect(step.text, isNotEmpty);
          expect(
            step.textAm,
            isNotEmpty,
            reason: '${recipe.id} step ${step.index} has no Amharic',
          );
        }
        for (final ingredient in recipe.ingredients) {
          expect(
            ingredient.nameAm,
            isNotEmpty,
            reason: '${recipe.id}: "${ingredient.name}" has no Amharic',
          );
        }
      }
    });

    test('every recipe has a cultural note in both languages', () {
      for (final recipe in catalogue) {
        expect(recipe.story, isNotEmpty, reason: '${recipe.id} has no story');
        expect(
          recipe.storyAm,
          isNotEmpty,
          reason: '${recipe.id} has no Amharic story',
        );
      }
    });

    test('carries gradient colours, since there is no photography', () {
      for (final recipe in catalogue) {
        expect(recipe.gradientA, matches(RegExp(r'^#[0-9A-Fa-f]{6}$')));
        expect(recipe.gradientB, matches(RegExp(r'^#[0-9A-Fa-f]{6}$')));
      }
    });

    test('fasting dishes are also dairy-free, which is what fasting means', () {
      for (final recipe in catalogue.where((r) => r.isFasting)) {
        expect(
          recipe.isDairyFree,
          isTrue,
          reason: '${recipe.id} is fasting but not dairy-free',
        );
        expect(
          recipe.isVegan,
          isTrue,
          reason: '${recipe.id} is fasting but not vegan',
        );
      }
    });

    test('covers a spread of regions and categories', () {
      expect(
        catalogue.map((r) => r.regionId).toSet().length,
        greaterThanOrEqualTo(5),
      );
      expect(
        catalogue.map((r) => r.category).toSet().length,
        greaterThanOrEqualTo(8),
      );
    });

    test('most steps carry a duration, so cook mode can time them', () {
      final timed = catalogue.expand((r) => r.steps).where((s) => s.hasTimer);
      final total = catalogue.expand((r) => r.steps).length;
      expect(timed.length / total, greaterThan(0.7));
    });
  });

  group('filtering', () {
    test('an empty query returns everything', () {
      expect(const RecipeQuery().apply(catalogue).length, catalogue.length);
    });

    test('fasting filter returns only fasting dishes', () {
      final results = const RecipeQuery(fastingOnly: true).apply(catalogue);

      expect(results, isNotEmpty);
      expect(results.every((r) => r.isFasting), isTrue);
    });

    test('time filter respects the ceiling', () {
      final results = const RecipeQuery(maxMinutes: 30).apply(catalogue);

      expect(results, isNotEmpty);
      expect(results.every((r) => r.totalMinutes <= 30), isTrue);
    });

    test('heat filter keeps out anything hotter than asked for', () {
      // Someone who set "mild" in onboarding should not be shown kitfo.
      final results = const RecipeQuery(maxHeat: 1).apply(catalogue);

      expect(results, isNotEmpty);
      expect(results.every((r) => r.heatLevel <= 1), isTrue);
      expect(results.map((r) => r.id), isNot(contains('kitfo')));
    });

    test('region filter narrows to that region', () {
      final results = const RecipeQuery(regionId: 'gurage').apply(catalogue);

      expect(results, isNotEmpty);
      expect(results.every((r) => r.regionId == 'gurage'), isTrue);
    });

    test('filters combine', () {
      final results = const RecipeQuery(
        fastingOnly: true,
        maxMinutes: 40,
      ).apply(catalogue);

      expect(results.every((r) => r.isFasting && r.totalMinutes <= 40), isTrue);
    });

    test('excludeIds drops dishes already cooked', () {
      final results =
          const RecipeQuery(excludeIds: {'doro', 'shiro'}).apply(catalogue);

      expect(results.map((r) => r.id), isNot(contains('doro')));
      expect(results.map((r) => r.id), isNot(contains('shiro')));
    });
  });

  group('text search', () {
    test('finds a dish by its English name', () {
      final results = const RecipeQuery(text: 'doro').apply(catalogue);
      expect(results.map((r) => r.id), contains('doro'));
    });

    test('finds a dish by its Amharic name', () {
      final results = const RecipeQuery(text: 'ሽሮ').apply(catalogue);
      expect(results.map((r) => r.id), contains('shiro'));
    });

    test('finds dishes by an ingredient', () {
      // Searching "berbere" should surface the dishes that use it.
      final results = const RecipeQuery(text: 'berbere').apply(catalogue);
      expect(results, isNotEmpty);
      expect(results.map((r) => r.id), contains('doro'));
    });

    test('is case insensitive', () {
      expect(
        const RecipeQuery(text: 'KITFO').apply(catalogue).map((r) => r.id),
        contains('kitfo'),
      );
    });

    test('a search matching nothing returns empty, not everything', () {
      expect(
        const RecipeQuery(text: 'zzzznotadish').apply(catalogue),
        isEmpty,
      );
    });
  });

  group('sorting', () {
    test('quickest puts the fastest dish first', () {
      final results =
          const RecipeQuery(sort: RecipeSort.quickest).apply(catalogue);

      expect(
        results.first.totalMinutes,
        lessThanOrEqualTo(results.last.totalMinutes),
      );
    });
  });

  group('cache keys', () {
    test('identical queries produce identical parameters', () {
      const a = RecipeQuery(fastingOnly: true, maxMinutes: 30);
      const b = RecipeQuery(maxMinutes: 30, fastingOnly: true);

      expect(a.toParams(), b.toParams());
    });

    test('different queries produce different parameters', () {
      expect(
        const RecipeQuery(fastingOnly: true).toParams(),
        isNot(const RecipeQuery(veganOnly: true).toParams()),
      );
    });

    test('isEmpty is true only for an unfiltered query', () {
      expect(const RecipeQuery().isEmpty, isTrue);
      expect(const RecipeQuery(fastingOnly: true).isEmpty, isFalse);
      expect(const RecipeQuery(text: 'doro').isEmpty, isFalse);
    });
  });
}
