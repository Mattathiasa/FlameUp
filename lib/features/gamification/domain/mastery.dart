/// How well someone knows a dish.
///
/// Mastery climbs by **repeating** a dish, not by finishing a recipe once —
/// which is the design's own framing: "mastery climbs when you repeat a
/// technique, not when you finish a recipe".
enum MasteryLevel {
  none(0, 'Not tried', 'አልተሞከረም'),
  triedIt(1, 'Tried it', 'ተሞክሯል'),
  learning(2, 'Learning', 'በመማር ላይ'),
  cook(3, 'Cook', 'አብሳይ'),
  skilled(5, 'Skilled', 'ብቁ'),
  expert(8, 'Expert', 'ባለሙያ'),
  master(12, 'Master', 'ዋና');

  const MasteryLevel(this.cooksRequired, this.label, this.labelAm);

  /// Completed cooks needed to reach this level.
  final int cooksRequired;

  final String label;
  final String labelAm;

  String localised({required bool amharic}) => amharic ? labelAm : label;

  /// The next level up, or null at [master].
  MasteryLevel? get next {
    final index = MasteryLevel.values.indexOf(this);
    return index + 1 < MasteryLevel.values.length
        ? MasteryLevel.values[index + 1]
        : null;
  }
}

/// What the app knows about one person cooking one dish.
class RecipeMastery {
  const RecipeMastery({
    required this.recipeId,
    this.cookCount = 0,
    this.bestRating = 0,
    this.averageRating = 0,
    this.lastCookedAt,
  });

  final String recipeId;
  final int cookCount;
  final int bestRating;
  final double averageRating;
  final DateTime? lastCookedAt;

  MasteryLevel get level => MasteryCalculator.levelFor(cookCount);

  /// Progress towards the next level, 0–1. Full at [MasteryLevel.master].
  double get progress => MasteryCalculator.progressFor(cookCount);

  /// Cooks still needed to advance, or 0 at the top.
  int get cooksToNext => MasteryCalculator.cooksToNext(cookCount);

  RecipeMastery afterCook({int? rating, DateTime? at}) => RecipeMastery(
        recipeId: recipeId,
        cookCount: cookCount + 1,
        bestRating: (rating ?? 0) > bestRating ? rating! : bestRating,
        averageRating: rating == null
            ? averageRating
            : (averageRating * cookCount + rating) / (cookCount + 1),
        lastCookedAt: at ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'recipeId': recipeId,
        'cookCount': cookCount,
        'level': level.index,
        'bestRating': bestRating,
        'averageRating': averageRating,
        if (lastCookedAt != null)
          'lastCookedAt': lastCookedAt!.toIso8601String(),
      };

  static RecipeMastery fromJson(String recipeId, Map<String, dynamic>? json) =>
      RecipeMastery(
        recipeId: recipeId,
        cookCount: json?['cookCount'] as int? ?? 0,
        bestRating: json?['bestRating'] as int? ?? 0,
        averageRating: (json?['averageRating'] as num?)?.toDouble() ?? 0,
        lastCookedAt: DateTime.tryParse(json?['lastCookedAt'] as String? ?? ''),
      );
}

/// Turns a completed-cook count into a mastery level.
abstract final class MasteryCalculator {
  static MasteryLevel levelFor(int cookCount) {
    var result = MasteryLevel.none;
    for (final level in MasteryLevel.values) {
      if (cookCount >= level.cooksRequired) result = level;
    }
    return result;
  }

  static int cooksToNext(int cookCount) {
    final next = levelFor(cookCount).next;
    if (next == null) return 0;
    return (next.cooksRequired - cookCount).clamp(0, next.cooksRequired);
  }

  static double progressFor(int cookCount) {
    final current = levelFor(cookCount);
    final next = current.next;
    if (next == null) return 1;

    final span = next.cooksRequired - current.cooksRequired;
    if (span <= 0) return 1;

    return ((cookCount - current.cooksRequired) / span).clamp(0.0, 1.0);
  }
}
