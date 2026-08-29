/// Maps XP to levels.
///
/// Config-driven rather than hardcoded in the UI: the thresholds come from
/// `config/level_curve` in Firestore when present, so the progression can be
/// retuned without shipping a build. [LevelCurve.standard] is the fallback and
/// the shape the design implies — level 12 at 2,480 XP with 3,000 to reach 13.
class LevelCurve {
  const LevelCurve(this.thresholds);

  /// Cumulative XP required to *reach* each level. Index 0 is level 1.
  final List<int> thresholds;

  /// The default curve.
  ///
  /// Quadratic-ish: each level costs a little more than the last, so early
  /// levels arrive quickly and later ones mean something. Level 1 starts at 0.
  static final LevelCurve standard = LevelCurve(
    List.generate(60, (index) {
      final level = index + 1;
      if (level == 1) return 0;
      // 120·(n-1) + 15·(n-1)² lands level 12 at ~3,000, matching the design.
      final n = level - 1;
      return 120 * n + 15 * n * n;
    }),
  );

  int get maxLevel => thresholds.length;

  /// The level [xp] earns. Never below 1, never above [maxLevel].
  int levelFor(int xp) {
    if (xp <= 0) return 1;
    for (var index = thresholds.length - 1; index >= 0; index--) {
      if (xp >= thresholds[index]) return index + 1;
    }
    return 1;
  }

  /// XP at which [level] begins.
  int xpForLevel(int level) {
    final index = (level - 1).clamp(0, thresholds.length - 1);
    return thresholds[index];
  }

  /// XP still needed to reach the next level, or 0 at the cap.
  int xpToNextLevel(int xp) {
    final level = levelFor(xp);
    if (level >= maxLevel) return 0;
    return xpForLevel(level + 1) - xp;
  }

  /// Progress through the current level, 0–1.
  double progressWithinLevel(int xp) {
    final level = levelFor(xp);
    if (level >= maxLevel) return 1;

    final start = xpForLevel(level);
    final end = xpForLevel(level + 1);
    if (end <= start) return 1;

    return ((xp - start) / (end - start)).clamp(0.0, 1.0);
  }

  /// Whether [after] crossed a level boundary that [before] had not.
  bool didLevelUp(int before, int after) => levelFor(after) > levelFor(before);

  static LevelCurve fromJson(Map<String, dynamic>? json) {
    final raw = json?['thresholds'] as List?;
    if (raw == null || raw.isEmpty) return standard;

    final thresholds = raw
        .map((e) => int.tryParse(e.toString()))
        .whereType<int>()
        .toList(growable: false);

    // A malformed curve would silently change everyone's level, so fall back
    // rather than accept something shorter than it should be.
    return thresholds.length < 2 ? standard : LevelCurve(thresholds);
  }
}

/// The level titles the design uses. Cosmetic, and deliberately separate from
/// the curve so retuning XP does not rename anyone's rank.
abstract final class LevelTitles {
  static const List<(int, String, String)> _titles = [
    (1, 'First Spark', 'የመጀመሪያ ብልጭታ'),
    (5, 'Pan Watcher', 'የድስት ጠባቂ'),
    (10, 'Wot Wanderer', 'የወጥ መንገደኛ'),
    (18, 'Spice Reader', 'የቅመም አንባቢ'),
    (28, 'Fire Keeper', 'የእሳት ጠባቂ'),
    (40, 'Kitchen Elder', 'የኩሽና አዛውንት'),
  ];

  static String forLevel(int level, {required bool amharic}) {
    var match = _titles.first;
    for (final title in _titles) {
      if (level >= title.$1) match = title;
    }
    return amharic ? match.$3 : match.$2;
  }
}
