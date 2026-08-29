import 'package:flameup/features/recipes/domain/ingredient.dart';
import 'package:flameup/features/recipes/domain/recipe.dart';
import 'package:flutter_test/flutter_test.dart';

Ingredient onions(double quantity) => Ingredient(
      name: 'Red onions',
      nameAm: 'ቀይ ሽንኩርት',
      quantity: quantity,
      unit: 'large',
      unitAm: 'ትልቅ',
      aisle: Aisle.fresh,
    );

Recipe recipeServing(int servings, List<Ingredient> ingredients) => Recipe(
      id: 'doro',
      title: 'Doro Wat',
      titleAm: 'ዶሮ ወጥ',
      subtitle: '',
      subtitleAm: '',
      regionId: 'amhara',
      category: 'wat',
      difficulty: Difficulty.advanced,
      totalMinutes: 120,
      servings: servings,
      xpReward: 240,
      ingredients: ingredients,
      steps: const [],
      gradientA: '#8E1B0F',
      gradientB: '#E0522A',
    );

void main() {
  group('serving-size scaling', () {
    test('doubling servings doubles every quantity', () {
      final recipe = recipeServing(6, [onions(4), onions(1.5)]);

      final scaled = recipe.ingredientsFor(12);

      expect(scaled[0].quantity, 8);
      expect(scaled[1].quantity, 3);
    });

    test('halving works too', () {
      final recipe = recipeServing(6, [onions(4)]);
      expect(recipe.ingredientsFor(3).single.quantity, 2);
    });

    test('the same serving count returns the list untouched', () {
      final recipe = recipeServing(6, [onions(4)]);
      expect(recipe.ingredientsFor(6), same(recipe.ingredients));
    });

    test('a recipe with no stated servings is not divided by zero', () {
      final recipe = recipeServing(0, [onions(4)]);
      expect(recipe.ingredientsFor(4).single.quantity, 4);
    });

    test('scaling leaves units, aisle and optionality alone', () {
      final recipe = recipeServing(
        4,
        [
          const Ingredient(
            name: 'Berbere',
            nameAm: 'በርበሬ',
            quantity: 0.75,
            unit: 'cup',
            unitAm: 'ኩባያ',
            aisle: Aisle.spice,
            optional: true,
          ),
        ],
      );

      final scaled = recipe.ingredientsFor(8).single;

      expect(scaled.quantity, 1.5);
      expect(scaled.unit, 'cup');
      expect(scaled.aisle, Aisle.spice);
      expect(scaled.optional, isTrue);
    });
  });

  group('quantity formatting', () {
    test('renders common fractions, not decimals', () {
      // A cook reads "¾ cup", not "0.75 cup".
      expect(onions(0.75).formattedQuantity, '¾');
      expect(onions(0.5).formattedQuantity, '½');
      expect(onions(0.25).formattedQuantity, '¼');
      expect(onions(0.333).formattedQuantity, '⅓');
    });

    test('mixes whole numbers with fractions', () {
      expect(onions(1.5).formattedQuantity, '1½');
      expect(onions(2.25).formattedQuantity, '2¼');
    });

    test('keeps whole numbers whole', () {
      expect(onions(4).formattedQuantity, '4');
      expect(onions(12).formattedQuantity, '12');
    });

    test('falls back to one decimal for awkward amounts', () {
      expect(onions(1.4).formattedQuantity, '1.4');
    });

    test('a zero quantity means "to taste" and renders nothing', () {
      const salt = Ingredient(
        name: 'Salt',
        nameAm: 'ጨው',
        quantity: 0,
        unit: 'to taste',
        unitAm: 'እንደ አስፈላጊነቱ',
      );

      expect(salt.isToTaste, isTrue);
      expect(salt.formattedQuantity, isEmpty);
      expect(salt.displayAmount(amharic: false), 'to taste');
      expect(salt.displayAmount(amharic: true), 'እንደ አስፈላጊነቱ');
    });

    test('scaling a to-taste ingredient keeps it to taste', () {
      // Doubling "to taste" must not produce "0 to taste".
      const salt = Ingredient(
        name: 'Salt',
        nameAm: 'ጨው',
        quantity: 0,
        unit: 'to taste',
        unitAm: 'እንደ አስፈላጊነቱ',
      );

      expect(salt.scaled(2).isToTaste, isTrue);
    });

    test('display amount joins quantity and unit in both languages', () {
      expect(onions(4).displayAmount(amharic: false), '4 large');
      expect(onions(4).displayAmount(amharic: true), '4 ትልቅ');
    });

    test('a unitless ingredient shows just the number', () {
      const eggs = Ingredient(
        name: 'Eggs',
        nameAm: 'እንቁላል',
        quantity: 6,
        unit: '',
        unitAm: '',
      );
      expect(eggs.displayAmount(amharic: false), '6');
    });
  });

  group('time formatting', () {
    Recipe withMinutes(int minutes) => Recipe(
          id: 'x',
          title: '',
          titleAm: '',
          subtitle: '',
          subtitleAm: '',
          regionId: 'amhara',
          category: 'wat',
          difficulty: Difficulty.beginner,
          totalMinutes: minutes,
          servings: 4,
          xpReward: 0,
          ingredients: const [],
          steps: const [],
          gradientA: '#000000',
          gradientB: '#FFFFFF',
        );

    test('minutes under an hour', () {
      expect(withMinutes(45).formattedTime(amharic: false), '45m');
    });

    test('hours and minutes', () {
      expect(withMinutes(120).formattedTime(amharic: false), '2h');
      expect(withMinutes(150).formattedTime(amharic: false), '2h 30m');
    });

    test('a multi-day ferment reads in days, in both languages', () {
      // Injera ferments for three days; "4320m" would be useless.
      expect(withMinutes(4320).formattedTime(amharic: false), '3d');
      expect(withMinutes(4320).formattedTime(amharic: true), '3 ቀን');
    });
  });

  group('search tokens', () {
    test('include the dish, ingredients and both languages', () {
      final recipe = recipeServing(6, [onions(4)]).copyTokens();

      expect(recipe, contains('doro'));
      expect(recipe, contains('wat'));
      expect(recipe, contains('ቀይ'));
      expect(recipe, contains('ሽንኩርት'));
    });

    test('drop single characters and duplicates', () {
      final tokens = recipeServing(6, [onions(4)]).copyTokens();
      expect(tokens.every((t) => t.length >= 2), isTrue);
      expect(tokens.length, tokens.toSet().length);
    });
  });
}

extension on Recipe {
  /// The generated token list, for readability in the tests above.
  List<String> copyTokens() => searchTokens;
}
