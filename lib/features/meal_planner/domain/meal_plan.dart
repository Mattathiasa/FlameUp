/// Which meal of the day a slot is.
enum MealSlot {
  breakfast,
  lunch,
  dinner;

  static MealSlot fromName(String? name) =>
      MealSlot.values.where((s) => s.name == name).firstOrNull ??
      MealSlot.dinner;
}

/// A week of planned meals.
///
/// Keyed by ISO week (`2026-W10`) so a plan belongs to a definite seven days
/// rather than to a floating "this week" that changes meaning on Sunday night.
class MealPlan {
  const MealPlan({required this.weekId, this.slots = const {}});

  final String weekId;

  /// `weekday(1-7) -> slot -> recipeId`.
  final Map<int, Map<MealSlot, String>> slots;

  /// The ISO week key for [date].
  static String weekIdFor(DateTime date) {
    // ISO weeks start on Monday and week 1 contains the first Thursday.
    final thursday = date.add(Duration(days: 4 - (date.weekday)));
    final firstDay = DateTime(thursday.year);
    final week = ((thursday.difference(firstDay).inDays) / 7).floor() + 1;
    return '${thursday.year}-W${week.toString().padLeft(2, '0')}';
  }

  String? recipeAt(int weekday, MealSlot slot) => slots[weekday]?[slot];

  bool get isEmpty => slots.values.every((day) => day.isEmpty);

  /// Every recipe in the plan, with duplicates kept — cooking a dish twice
  /// means buying for it twice.
  List<String> get allRecipeIds => [
        for (final day in slots.values) ...day.values,
      ];

  MealPlan withMeal(int weekday, MealSlot slot, String? recipeId) {
    final next = {
      for (final entry in slots.entries) entry.key: {...entry.value},
    };

    final day = next.putIfAbsent(weekday, () => {});
    if (recipeId == null) {
      day.remove(slot);
    } else {
      day[slot] = recipeId;
    }
    if (day.isEmpty) next.remove(weekday);

    return MealPlan(weekId: weekId, slots: next);
  }

  Map<String, dynamic> toJson() => {
        'weekId': weekId,
        'slots': {
          for (final entry in slots.entries)
            entry.key.toString(): {
              for (final meal in entry.value.entries) meal.key.name: meal.value,
            },
        },
      };

  static MealPlan fromJson(Map<String, dynamic>? json) {
    final weekId = json?['weekId'] as String? ?? weekIdFor(DateTime.now());
    // A cast would throw on a malformed document; a corrupt plan should cost
    // the user their plan, not the screen.
    final rawSlots = json?['slots'];
    if (rawSlots is! Map) return MealPlan(weekId: weekId);
    final raw = rawSlots;

    final slots = <int, Map<MealSlot, String>>{};
    raw.forEach((dayKey, dayValue) {
      final weekday = int.tryParse(dayKey.toString());
      if (weekday == null || dayValue is! Map) return;

      final meals = <MealSlot, String>{};
      dayValue.forEach((slotKey, recipeId) {
        if (recipeId is String && recipeId.isNotEmpty) {
          meals[MealSlot.fromName(slotKey.toString())] = recipeId;
        }
      });
      if (meals.isNotEmpty) slots[weekday] = meals;
    });

    return MealPlan(weekId: weekId, slots: slots);
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
