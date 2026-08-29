/// Where an ingredient lives in a shop, so the shopping list can group itself.
enum Aisle {
  spice('aisleSpice'),
  fresh('aisleFresh'),
  meatDairy('aisleMeat'),
  pantry('aislePantry');

  const Aisle(this.labelKey);

  /// Matches the design's own key, so the heading comes from the generated
  /// localisations rather than a second table.
  final String labelKey;

  static Aisle fromName(String? name) =>
      Aisle.values.where((a) => a.name == name).firstOrNull ?? Aisle.pantry;
}

/// One line of a recipe's ingredient list.
///
/// [quantity] is a **number**, not `"4 large"`. Serving-size scaling has to
/// multiply it, and the display string is composed at render time — storing
/// the formatted text would make scaling impossible.
class Ingredient {
  const Ingredient({
    required this.name,
    required this.nameAm,
    required this.quantity,
    required this.unit,
    required this.unitAm,
    this.aisle = Aisle.pantry,
    this.optional = false,
    this.note,
  });

  final String name;
  final String nameAm;

  /// Zero means "to taste" — an amount the recipe deliberately leaves open.
  final double quantity;

  final String unit;
  final String unitAm;
  final Aisle aisle;
  final bool optional;
  final String? note;

  bool get isToTaste => quantity == 0;

  /// Scale for a different number of servings.
  Ingredient scaled(double factor) => Ingredient(
        name: name,
        nameAm: nameAm,
        quantity: quantity * factor,
        unit: unit,
        unitAm: unitAm,
        aisle: aisle,
        optional: optional,
        note: note,
      );

  /// A human amount: `4`, `1.5`, `¾`, or empty when it is to taste.
  ///
  /// Cooks read fractions, not decimals — "0.75 cup" is a spreadsheet, "¾ cup"
  /// is a recipe.
  String get formattedQuantity {
    if (isToTaste) return '';

    // A list of pairs rather than a map: doubles are a poor map key, and the
    // lookup below is a nearest-match scan anyway.
    const fractions = <(double, String)>[
      (0.125, '⅛'),
      (0.25, '¼'),
      (0.333, '⅓'),
      (0.375, '⅜'),
      (0.5, '½'),
      (0.625, '⅝'),
      (0.666, '⅔'),
      (0.75, '¾'),
      (0.875, '⅞'),
    ];

    final whole = quantity.floor();
    final remainder = quantity - whole;

    // Snap to the nearest common fraction when close enough that the
    // difference cannot be measured in a kitchen.
    for (final (value, glyph) in fractions) {
      if ((remainder - value).abs() < 0.02) {
        return whole == 0 ? glyph : '$whole$glyph';
      }
    }

    if (remainder < 0.02) return '$whole';
    // Otherwise one decimal: 1.5 kg reads fine, 1.4732 does not.
    return quantity.toStringAsFixed(1);
  }

  String displayAmount({required bool amharic}) {
    final unitText = amharic ? unitAm : unit;
    final quantityText = formattedQuantity;
    if (quantityText.isEmpty) return unitText;
    return unitText.isEmpty ? quantityText : '$quantityText $unitText';
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'nameAm': nameAm,
        'quantity': quantity,
        'unit': unit,
        'unitAm': unitAm,
        'aisle': aisle.name,
        'optional': optional,
        if (note != null) 'note': note,
      };

  static Ingredient fromJson(Map<String, dynamic> json) => Ingredient(
        name: json['name'] as String? ?? '',
        nameAm: json['nameAm'] as String? ?? '',
        quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
        unit: json['unit'] as String? ?? '',
        unitAm: json['unitAm'] as String? ?? '',
        aisle: Aisle.fromName(json['aisle'] as String?),
        optional: json['optional'] as bool? ?? false,
        note: json['note'] as String?,
      );
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
