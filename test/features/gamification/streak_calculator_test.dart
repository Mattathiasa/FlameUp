import 'package:flameup/features/gamification/domain/streak_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

StreakState state({
  int current = 0,
  int longest = 0,
  String? lastCookedOn,
  int freezeDaysLeft = 2,
}) =>
    StreakState(
      current: current,
      longest: longest,
      lastCookedOn: lastCookedOn,
      freezeDaysLeft: freezeDaysLeft,
    );

void main() {
  group('day keys are local calendar dates', () {
    test('formats as YYYY-MM-DD', () {
      expect(StreakCalculator.dayKey(DateTime(2026, 3, 1)), '2026-03-01');
      expect(StreakCalculator.dayKey(DateTime(2026, 12, 25)), '2026-12-25');
    });

    test('a late-night cook counts as that day, not the next', () {
      // Someone finishing doro wat at 23:50 has cooked today. Storing an
      // instant and converting later is what gets this wrong.
      expect(
        StreakCalculator.dayKey(DateTime(2026, 3, 1, 23, 50)),
        '2026-03-01',
      );
      expect(
        StreakCalculator.dayKey(DateTime(2026, 3, 1, 0, 5)),
        '2026-03-01',
      );
    });

    test('a UTC instant is converted to local before the date is taken', () {
      final utc = DateTime.utc(2026, 3, 1, 12);
      expect(
        StreakCalculator.dayKey(utc),
        StreakCalculator.dayKey(utc.toLocal()),
      );
    });
  });

  group('first cook', () {
    test('starts a streak at one', () {
      final result =
          StreakCalculator.afterCook(state(), on: DateTime(2026, 3, 1));

      expect(result.current, 1);
      expect(result.longest, 1);
      expect(result.lastCookedOn, '2026-03-01');
    });
  });

  group('consecutive days', () {
    test('extend the streak', () {
      final result = StreakCalculator.afterCook(
        state(current: 11, longest: 11, lastCookedOn: '2026-02-28'),
        on: DateTime(2026, 3, 1),
      );

      expect(result.current, 12);
      expect(result.longest, 12);
    });

    test('do not spend a freeze day', () {
      final result = StreakCalculator.afterCook(
        state(current: 3, lastCookedOn: '2026-02-28'),
        on: DateTime(2026, 3, 1),
      );

      expect(result.freezeDaysLeft, 2);
    });

    test('keep the record when the current streak is shorter', () {
      final result = StreakCalculator.afterCook(
        state(current: 3, longest: 21, lastCookedOn: '2026-02-28'),
        on: DateTime(2026, 3, 1),
      );

      expect(result.current, 4);
      expect(result.longest, 21, reason: 'the best run must not be lowered');
    });
  });

  group('cooking twice in one day', () {
    test('does not count as two days', () {
      final before = state(current: 5, longest: 5, lastCookedOn: '2026-03-01');
      final after =
          StreakCalculator.afterCook(before, on: DateTime(2026, 3, 1));

      expect(after.current, 5);
      expect(after.lastCookedOn, '2026-03-01');
    });
  });

  group('freeze days', () {
    test('forgive exactly one missed day', () {
      // Cooked on the 1st, missed the 2nd, cooked the 3rd.
      final result = StreakCalculator.afterCook(
        state(current: 8, longest: 8, lastCookedOn: '2026-03-01'),
        on: DateTime(2026, 3, 3),
      );

      expect(result.current, 9);
      expect(result.freezeDaysLeft, 1, reason: 'a freeze should be spent');
    });

    test('do not apply once they run out', () {
      final result = StreakCalculator.afterCook(
        state(
          current: 8,
          longest: 8,
          lastCookedOn: '2026-03-01',
          freezeDaysLeft: 0,
        ),
        on: DateTime(2026, 3, 3),
      );

      expect(result.current, 1, reason: 'without a freeze the streak resets');
      expect(result.longest, 8);
    });

    test('do not cover two missed days', () {
      final result = StreakCalculator.afterCook(
        state(current: 8, longest: 8, lastCookedOn: '2026-03-01'),
        on: DateTime(2026, 3, 4),
      );

      expect(result.current, 1);
      expect(result.freezeDaysLeft, 2, reason: 'no freeze is spent on a reset');
    });
  });

  group('breaking a streak', () {
    test('resets to one and preserves the record', () {
      final result = StreakCalculator.afterCook(
        state(current: 12, longest: 21, lastCookedOn: '2026-02-01'),
        on: DateTime(2026, 3, 1),
      );

      expect(result.current, 1);
      expect(result.longest, 21);
    });
  });

  group('bad data', () {
    test('an unreadable stored date starts fresh instead of crashing', () {
      final result = StreakCalculator.afterCook(
        state(current: 5, lastCookedOn: 'not-a-date'),
        on: DateTime(2026, 3, 1),
      );

      expect(result.current, 1);
      expect(result.lastCookedOn, '2026-03-01');
    });

    test('a clock that went backwards does not inflate the streak', () {
      // Device clock set back, or a stored date in the future.
      final result = StreakCalculator.afterCook(
        state(current: 5, longest: 9, lastCookedOn: '2026-06-01'),
        on: DateTime(2026, 3, 1),
      );

      expect(result.current, 1);
      expect(result.longest, 9);
    });
  });

  group('the streak as displayed', () {
    test('survives the day after cooking', () {
      // Cooked yesterday, today is not over -- the streak still stands.
      final live = StreakCalculator.currentAsOf(
        state(current: 12, lastCookedOn: '2026-02-28'),
        asOf: DateTime(2026, 3, 1),
      );

      expect(live, 12);
    });

    test('is zero once it has genuinely lapsed', () {
      // Showing 12 when the user last cooked a week ago is a lie.
      final live = StreakCalculator.currentAsOf(
        state(current: 12, lastCookedOn: '2026-02-20'),
        asOf: DateTime(2026, 3, 1),
      );

      expect(live, 0);
    });

    test('holds while a freeze could still save it', () {
      final live = StreakCalculator.currentAsOf(
        state(current: 12, lastCookedOn: '2026-02-27'),
        asOf: DateTime(2026, 3, 1),
      );

      expect(live, 12);
    });

    test('is zero when nothing has ever been cooked', () {
      expect(
        StreakCalculator.currentAsOf(state(), asOf: DateTime(2026, 3, 1)),
        0,
      );
    });
  });

  group('at risk', () {
    test('true the day after the last cook', () {
      expect(
        StreakCalculator.isAtRisk(
          state(current: 5, lastCookedOn: '2026-02-28'),
          asOf: DateTime(2026, 3, 1),
        ),
        isTrue,
      );
    });

    test('false if something was already cooked today', () {
      expect(
        StreakCalculator.isAtRisk(
          state(current: 5, lastCookedOn: '2026-03-01'),
          asOf: DateTime(2026, 3, 1),
        ),
        isFalse,
      );
    });

    test('false when there is no streak to lose', () {
      expect(
        StreakCalculator.isAtRisk(state(), asOf: DateTime(2026, 3, 1)),
        isFalse,
      );
    });
  });

  group('serialisation', () {
    test('round trips', () {
      const original = StreakState(
        current: 12,
        longest: 21,
        lastCookedOn: '2026-03-01',
        freezeDaysLeft: 1,
      );

      final restored = StreakState.fromJson(original.toJson());

      expect(restored.current, 12);
      expect(restored.longest, 21);
      expect(restored.lastCookedOn, '2026-03-01');
      expect(restored.freezeDaysLeft, 1);
    });

    test('a missing document decodes to an empty streak', () {
      final restored = StreakState.fromJson(null);
      expect(restored.current, 0);
      expect(restored.freezeDaysLeft, 2);
    });
  });
}
