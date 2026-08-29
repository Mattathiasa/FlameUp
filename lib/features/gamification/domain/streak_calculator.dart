/// Streak state, as the server holds it.
class StreakState {
  const StreakState({
    this.current = 0,
    this.longest = 0,
    this.lastCookedOn,
    this.freezeDaysLeft = 2,
  });

  final int current;
  final int longest;

  /// The last day a dish was finished, as a **local calendar date** in the
  /// user's own timezone — `YYYY-MM-DD`, not a timestamp.
  ///
  /// A streak is a question about days where the user is. Storing an instant
  /// and converting later gets it wrong for anyone who cooks near midnight or
  /// crosses a timezone.
  final String? lastCookedOn;

  /// Missed days that can be forgiven. The design's streak screen shows two.
  final int freezeDaysLeft;

  StreakState copyWith({
    int? current,
    int? longest,
    String? lastCookedOn,
    int? freezeDaysLeft,
  }) =>
      StreakState(
        current: current ?? this.current,
        longest: longest ?? this.longest,
        lastCookedOn: lastCookedOn ?? this.lastCookedOn,
        freezeDaysLeft: freezeDaysLeft ?? this.freezeDaysLeft,
      );

  Map<String, dynamic> toJson() => {
        'flames': current,
        'longestStreak': longest,
        if (lastCookedOn != null) 'lastCookedOn': lastCookedOn,
        'freezeDaysLeft': freezeDaysLeft,
      };

  static StreakState fromJson(Map<String, dynamic>? json) => StreakState(
        current: json?['flames'] as int? ?? 0,
        longest: json?['longestStreak'] as int? ?? 0,
        lastCookedOn: json?['lastCookedOn'] as String?,
        freezeDaysLeft: json?['freezeDaysLeft'] as int? ?? 2,
      );
}

/// Works out what finishing a dish does to a streak.
///
/// Pure, timezone-aware and total: every branch is decided from two calendar
/// dates, so the same inputs always give the same answer and the logic can be
/// mirrored exactly in the Cloud Function that actually writes it.
abstract final class StreakCalculator {
  /// `YYYY-MM-DD` for [date] as a local calendar day.
  static String dayKey(DateTime date) {
    final local = date.isUtc ? date.toLocal() : date;
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }

  /// Whole days between two `YYYY-MM-DD` keys, or null if either is malformed.
  static int? daysBetween(String from, String to) {
    final start = DateTime.tryParse(from);
    final end = DateTime.tryParse(to);
    if (start == null || end == null) return null;
    return DateTime(end.year, end.month, end.day)
        .difference(DateTime(start.year, start.month, start.day))
        .inDays;
  }

  /// The streak after finishing a dish on [on].
  ///
  /// - same day → unchanged; cooking twice in a day is not two days
  /// - next day → extended
  /// - one missed day with a freeze left → extended, freeze spent
  /// - otherwise → reset to 1, because the streak really did end
  static StreakState afterCook(StreakState state, {required DateTime on}) {
    final today = dayKey(on);
    final last = state.lastCookedOn;

    if (last == null) {
      return state.copyWith(
        current: 1,
        longest: state.longest < 1 ? 1 : state.longest,
        lastCookedOn: today,
      );
    }

    final gap = daysBetween(last, today);

    // Unreadable stored date, or a clock that went backwards. Treat it as a
    // fresh start rather than trusting arithmetic on nonsense.
    if (gap == null || gap < 0) {
      return state.copyWith(
        current: 1,
        longest: state.longest < 1 ? 1 : state.longest,
        lastCookedOn: today,
      );
    }

    if (gap == 0) return state;

    if (gap == 1) {
      final next = state.current + 1;
      return state.copyWith(
        current: next,
        longest: next > state.longest ? next : state.longest,
        lastCookedOn: today,
      );
    }

    // Exactly one missed day can be forgiven if a freeze is available.
    if (gap == 2 && state.freezeDaysLeft > 0) {
      final next = state.current + 1;
      return state.copyWith(
        current: next,
        longest: next > state.longest ? next : state.longest,
        lastCookedOn: today,
        freezeDaysLeft: state.freezeDaysLeft - 1,
      );
    }

    return state.copyWith(
      current: 1,
      longest: state.longest < 1 ? 1 : state.longest,
      lastCookedOn: today,
    );
  }

  /// The streak as it stands on [asOf], without cooking anything.
  ///
  /// Used for display: a streak shown as 12 when the user last cooked a week
  /// ago is a lie the app tells itself.
  static int currentAsOf(StreakState state, {required DateTime asOf}) {
    final last = state.lastCookedOn;
    if (last == null) return 0;

    final gap = daysBetween(last, dayKey(asOf));
    if (gap == null || gap < 0) return state.current;

    // Today or yesterday: still alive — the day is not over yet.
    if (gap <= 1) return state.current;

    // One missed day, with a freeze in hand.
    if (gap == 2 && state.freezeDaysLeft > 0) return state.current;

    return 0;
  }

  /// Whether the streak will lapse unless something is cooked today.
  static bool isAtRisk(StreakState state, {required DateTime asOf}) {
    final last = state.lastCookedOn;
    if (last == null || state.current == 0) return false;

    final gap = daysBetween(last, dayKey(asOf));
    return gap != null && gap >= 1;
  }
}
