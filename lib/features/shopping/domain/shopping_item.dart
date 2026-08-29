import 'package:uuid/uuid.dart';

import '../../recipes/domain/ingredient.dart';

/// One line on the shopping list.
class ShoppingItem {
  ShoppingItem({
    required this.name,
    required this.nameAm,
    this.quantity = 0,
    this.unit = '',
    this.unitAm = '',
    this.aisle = Aisle.pantry,
    this.checked = false,
    this.recipeId,
    this.manual = false,
    String? id,
    DateTime? addedAt,
  })  : id = id ?? const Uuid().v4(),
        addedAt = addedAt ?? DateTime.now();

  factory ShoppingItem.fromIngredient(
    Ingredient ingredient, {
    String? recipeId,
  }) =>
      ShoppingItem(
        name: ingredient.name,
        nameAm: ingredient.nameAm,
        quantity: ingredient.quantity,
        unit: ingredient.unit,
        unitAm: ingredient.unitAm,
        aisle: ingredient.aisle,
        recipeId: recipeId,
      );

  final String id;
  final String name;
  final String nameAm;
  final double quantity;
  final String unit;
  final String unitAm;
  final Aisle aisle;
  final bool checked;

  /// Which recipe put it here, if any. Null for a hand-added item.
  final String? recipeId;

  final bool manual;
  final DateTime addedAt;

  /// Whether two lines are the same shopping item and can be merged.
  ///
  /// Matching on name and unit is what stops "4 large onions" and "2 large
  /// onions" from both appearing when two recipes are added.
  bool mergesWith(ShoppingItem other) =>
      name.toLowerCase() == other.name.toLowerCase() &&
      unit.toLowerCase() == other.unit.toLowerCase();

  ShoppingItem mergedWith(ShoppingItem other) => copyWith(
        quantity: quantity + other.quantity,
        // A merged line belongs to no single recipe any more.
        recipeId: recipeId == other.recipeId ? recipeId : null,
      );

  ShoppingItem copyWith({
    double? quantity,
    bool? checked,
    String? recipeId,
    Aisle? aisle,
  }) =>
      ShoppingItem(
        id: id,
        name: name,
        nameAm: nameAm,
        quantity: quantity ?? this.quantity,
        unit: unit,
        unitAm: unitAm,
        aisle: aisle ?? this.aisle,
        checked: checked ?? this.checked,
        recipeId: recipeId,
        manual: manual,
        addedAt: addedAt,
      );

  String displayAmount({required bool amharic}) => Ingredient(
        name: name,
        nameAm: nameAm,
        quantity: quantity,
        unit: unit,
        unitAm: unitAm,
      ).displayAmount(amharic: amharic);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'nameAm': nameAm,
        'quantity': quantity,
        'unit': unit,
        'unitAm': unitAm,
        'aisle': aisle.name,
        'checked': checked,
        if (recipeId != null) 'recipeId': recipeId,
        'manual': manual,
        'addedAt': addedAt.toIso8601String(),
      };

  static ShoppingItem? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final name = json['name'] as String?;
    if (name == null) return null;

    return ShoppingItem(
      id: json['id'] as String?,
      name: name,
      nameAm: json['nameAm'] as String? ?? name,
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      unit: json['unit'] as String? ?? '',
      unitAm: json['unitAm'] as String? ?? '',
      aisle: Aisle.fromName(json['aisle'] as String?),
      checked: json['checked'] as bool? ?? false,
      recipeId: json['recipeId'] as String?,
      manual: json['manual'] as bool? ?? false,
      addedAt: DateTime.tryParse(json['addedAt'] as String? ?? ''),
    );
  }
}

/// Merges ingredient lines into a shopping list.
abstract final class ShoppingListBuilder {
  /// Adds [items] to [existing], combining quantities where they match.
  ///
  /// Two recipes that both want onions produce one line, not two — which is
  /// the difference between a usable list and a transcript.
  static List<ShoppingItem> merge(
    List<ShoppingItem> existing,
    List<ShoppingItem> items,
  ) {
    final result = List<ShoppingItem>.from(existing);

    for (final item in items) {
      final index = result.indexWhere(
        (candidate) => candidate.mergesWith(item) && !candidate.checked,
      );

      if (index == -1) {
        result.add(item);
      } else {
        result[index] = result[index].mergedWith(item);
      }
    }

    return result;
  }

  /// Grouped by aisle, in shopping order, with checked items last.
  static Map<Aisle, List<ShoppingItem>> byAisle(List<ShoppingItem> items) {
    final grouped = <Aisle, List<ShoppingItem>>{};

    for (final aisle in Aisle.values) {
      final inAisle = items.where((i) => i.aisle == aisle).toList()
        ..sort((a, b) {
          if (a.checked != b.checked) return a.checked ? 1 : -1;
          return a.name.compareTo(b.name);
        });
      if (inAisle.isNotEmpty) grouped[aisle] = inAisle;
    }

    return grouped;
  }
}
