import 'package:flameup/features/recipes/domain/ingredient.dart';
import 'package:flameup/features/shopping/domain/shopping_item.dart';
import 'package:flutter_test/flutter_test.dart';

ShoppingItem item(
  String name,
  double qty, {
  String unit = 'large',
  Aisle aisle = Aisle.fresh,
}) =>
    ShoppingItem(
      name: name,
      nameAm: name,
      quantity: qty,
      unit: unit,
      unitAm: unit,
      aisle: aisle,
    );

void main() {
  group('merging', () {
    test('two recipes needing onions produce one line, not two', () {
      // The difference between a usable list and a transcript.
      final merged = ShoppingListBuilder.merge(
        [item('Red onions', 4)],
        [item('Red onions', 2)],
      );

      expect(merged, hasLength(1));
      expect(merged.single.quantity, 6);
    });

    test('different units are kept apart', () {
      final merged = ShoppingListBuilder.merge(
        [item('Onions', 4)],
        [item('Onions', 2, unit: 'cups')],
      );

      expect(merged, hasLength(2));
    });

    test('matching ignores case', () {
      final merged = ShoppingListBuilder.merge(
        [item('Red Onions', 4)],
        [item('red onions', 2)],
      );

      expect(merged, hasLength(1));
      expect(merged.single.quantity, 6);
    });

    test('an already-checked line is not merged into', () {
      // Ticking something off then adding another recipe should produce a
      // fresh line, not silently un-buy what was bought.
      final checked = item('Onions', 4).copyWith(checked: true);
      final merged = ShoppingListBuilder.merge([checked], [item('Onions', 2)]);

      expect(merged, hasLength(2));
    });
  });

  group('grouping', () {
    test('groups by aisle and puts checked items last', () {
      final grouped = ShoppingListBuilder.byAisle([
        item('Berbere', 1, aisle: Aisle.spice),
        item('Onions', 4).copyWith(checked: true),
        item('Garlic', 2),
      ]);

      expect(grouped[Aisle.spice], hasLength(1));
      expect(grouped[Aisle.fresh], hasLength(2));
      expect(grouped[Aisle.fresh]!.first.name, 'Garlic');
      expect(grouped[Aisle.fresh]!.last.checked, isTrue);
    });

    test('empty aisles are omitted', () {
      final grouped = ShoppingListBuilder.byAisle([
        item('Berbere', 1, aisle: Aisle.spice),
      ]);

      expect(grouped.keys, [Aisle.spice]);
    });
  });

  group('from an ingredient', () {
    test('carries the aisle and quantity through', () {
      const ingredient = Ingredient(
        name: 'Berbere',
        nameAm: 'በርበሬ',
        quantity: 0.75,
        unit: 'cup',
        unitAm: 'ኩባያ',
        aisle: Aisle.spice,
      );

      final shopping =
          ShoppingItem.fromIngredient(ingredient, recipeId: 'doro');

      expect(shopping.aisle, Aisle.spice);
      expect(shopping.quantity, 0.75);
      expect(shopping.recipeId, 'doro');
      expect(shopping.displayAmount(amharic: false), '¾ cup');
    });
  });

  group('serialisation', () {
    test('round trips', () {
      final original = item('Onions', 4).copyWith(checked: true);
      final restored = ShoppingItem.fromJson(original.toJson())!;

      expect(restored.id, original.id);
      expect(restored.name, 'Onions');
      expect(restored.quantity, 4);
      expect(restored.checked, isTrue);
    });

    test('a corrupt row decodes to null', () {
      expect(ShoppingItem.fromJson(null), isNull);
      expect(ShoppingItem.fromJson(const {}), isNull);
    });
  });
}
