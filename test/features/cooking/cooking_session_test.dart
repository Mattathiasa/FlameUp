import 'package:flameup/features/cooking/domain/cooking_session.dart';
import 'package:flutter_test/flutter_test.dart';

CookingSession session({
  int currentStep = 0,
  int totalSteps = 9,
  Map<int, DateTime> deadlines = const {},
  Map<int, int> paused = const {},
  SessionStatus status = SessionStatus.inProgress,
}) =>
    CookingSession(
      recipeId: 'doro',
      totalSteps: totalSteps,
      servings: 6,
      currentStep: currentStep,
      stepDeadlines: deadlines,
      pausedRemaining: paused,
      status: status,
    );

void main() {
  group('timers are wall-clock, not ticks', () {
    test('remaining time is measured against the clock', () {
      final now = DateTime(2026, 3, 1, 18);
      final s = session(deadlines: {2: now.add(const Duration(minutes: 5))});

      expect(s.remainingFor(2, now: now), const Duration(minutes: 5));
    });

    test('a timer keeps counting down while the app is closed', () {
      // The whole point: the app is killed at 18:00 with 15 minutes left and
      // reopened at 18:10. A Timer counting ticks would still say 15 minutes;
      // a deadline says 5, which is the truth.
      final start = DateTime(2026, 3, 1, 18);
      final s = session(deadlines: {3: start.add(const Duration(minutes: 15))});

      final reopened = start.add(const Duration(minutes: 10));
      expect(s.remainingFor(3, now: reopened), const Duration(minutes: 5));
    });

    test('a timer that expired while away reports zero, not a negative', () {
      final start = DateTime(2026, 3, 1, 18);
      final s = session(deadlines: {1: start.add(const Duration(minutes: 2))});

      final muchLater = start.add(const Duration(hours: 3));
      expect(s.remainingFor(1, now: muchLater), Duration.zero);
    });

    test('reports that a timer finished while nobody was watching', () {
      final start = DateTime(2026, 3, 1, 18);
      final s = session(deadlines: {1: start.add(const Duration(minutes: 2))});

      expect(s.hasExpiredTimer(1, now: start), isFalse);
      expect(
        s.hasExpiredTimer(1, now: start.add(const Duration(minutes: 3))),
        isTrue,
      );
    });

    test('a step with no timer has none', () {
      final s = session();
      expect(s.isTimerRunning(0), isFalse);
      expect(s.remainingFor(0), Duration.zero);
      expect(s.hasExpiredTimer(0), isFalse);
    });
  });

  group('pausing', () {
    test('a paused timer holds its remaining seconds and ignores the clock',
        () {
      // Pausing removes the deadline, because the clock is no longer running.
      final s = session(paused: {2: 300});

      expect(s.isTimerPaused(2), isTrue);
      expect(s.remainingFor(2), const Duration(seconds: 300));
      expect(
        s.remainingFor(2, now: DateTime(2030)),
        const Duration(seconds: 300),
        reason: 'a paused timer must not drain while paused',
      );
    });

    test('paused time takes precedence over a stale deadline', () {
      final s = session(
        deadlines: {2: DateTime(2020)},
        paused: {2: 120},
      );
      expect(s.remainingFor(2), const Duration(seconds: 120));
    });
  });

  group('idempotency', () {
    test('the key is minted once and survives every update', () {
      // Generated when the session starts, not when it completes, so a retry
      // after a crash carries the same key and cannot double-award XP.
      final s = session();
      final advanced = s.copyWith(currentStep: 4);
      final completed = advanced.copyWith(
        status: SessionStatus.completed,
        completedAt: DateTime.now(),
      );

      expect(advanced.idempotencyKey, s.idempotencyKey);
      expect(completed.idempotencyKey, s.idempotencyKey);
    });

    test('two sessions get different keys', () {
      expect(session().idempotencyKey, isNot(session().idempotencyKey));
    });

    test('the session id also survives updates', () {
      final s = session();
      expect(s.copyWith(currentStep: 3).id, s.id);
    });
  });

  group('progress', () {
    test('reports the fraction complete', () {
      expect(
        session(currentStep: 0, totalSteps: 9).progress,
        closeTo(0.111, 0.01),
      );
      expect(session(currentStep: 8, totalSteps: 9).progress, 1);
    });

    test('knows when it is on the last step', () {
      expect(session(currentStep: 7, totalSteps: 9).isOnLastStep, isFalse);
      expect(session(currentStep: 8, totalSteps: 9).isOnLastStep, isTrue);
    });

    test('a recipe with no steps does not divide by zero', () {
      expect(session(totalSteps: 0).progress, 0);
    });
  });

  group('serialisation', () {
    test('round trips, including deadlines and paused timers', () {
      final deadline = DateTime(2026, 3, 1, 18, 30);
      final original = session(
        currentStep: 4,
        deadlines: {4: deadline},
        paused: {2: 90},
      );

      final restored = CookingSession.fromJson(original.toJson());

      expect(restored, isNotNull);
      expect(restored!.id, original.id);
      expect(restored.idempotencyKey, original.idempotencyKey);
      expect(restored.currentStep, 4);
      expect(restored.stepDeadlines[4], deadline);
      expect(restored.pausedRemaining[2], 90);
    });

    test('a restored session still computes the right remaining time', () {
      // This is the resume path: the session is read back from disk after a
      // cold start, and its timer must still be correct.
      final start = DateTime(2026, 3, 1, 18);
      final original = session(
        deadlines: {1: start.add(const Duration(minutes: 20))},
      );

      final restored = CookingSession.fromJson(original.toJson())!;

      expect(
        restored.remainingFor(1, now: start.add(const Duration(minutes: 5))),
        const Duration(minutes: 15),
      );
    });

    test('a corrupt document decodes to null rather than throwing', () {
      expect(CookingSession.fromJson(null), isNull);
      expect(CookingSession.fromJson(const {}), isNull);
      expect(
        CookingSession.fromJson(const {'id': 'x', 'recipeId': 'doro'}),
        isNull,
      );
    });

    test('unparseable deadline entries are dropped, not fatal', () {
      final restored = CookingSession.fromJson({
        'id': 'a',
        'recipeId': 'doro',
        'idempotencyKey': 'k',
        'startedAt': DateTime(2026).toIso8601String(),
        'totalSteps': 9,
        'stepDeadlines': {'notanint': 'alsonotadate', '2': 'bad'},
      });

      expect(restored, isNotNull);
      expect(restored!.stepDeadlines, isEmpty);
    });
  });

  group('status', () {
    test('only an in-progress session is active', () {
      expect(session().isActive, isTrue);
      expect(session(status: SessionStatus.completed).isActive, isFalse);
      expect(session(status: SessionStatus.abandoned).isActive, isFalse);
    });

    test('an unknown status falls back to in-progress', () {
      expect(SessionStatus.fromName('somethingElse'), SessionStatus.inProgress);
      expect(SessionStatus.fromName(null), SessionStatus.inProgress);
    });
  });
}
