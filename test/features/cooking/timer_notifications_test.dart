import 'package:flameup/core/services/timer_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('notification ids', () {
    test('are stable for a session and step', () {
      // Rescheduling the same step must replace its alert, not stack a
      // second one, which requires the id to be deterministic.
      final first = TimerNotifications.idFor('session-abc', 3);
      final second = TimerNotifications.idFor('session-abc', 3);

      expect(first, second);
    });

    test('differ between steps of one session', () {
      expect(
        TimerNotifications.idFor('session-abc', 3),
        isNot(TimerNotifications.idFor('session-abc', 4)),
      );
    });

    test('differ between sessions', () {
      expect(
        TimerNotifications.idFor('session-abc', 1),
        isNot(TimerNotifications.idFor('session-xyz', 1)),
      );
    });

    test('fit in a 32-bit signed integer', () {
      // Platform notification ids are 32-bit; a raw hashCode would overflow
      // and be rejected at schedule time.
      for (final id in [
        TimerNotifications.idFor('a-very-long-session-identifier-uuid-v4', 99),
        TimerNotifications.idFor('', 0),
        TimerNotifications.idFor('ሰላም', 42),
      ]) {
        expect(id, greaterThanOrEqualTo(0));
        expect(id, lessThan(2147483647));
      }
    });
  });
}
