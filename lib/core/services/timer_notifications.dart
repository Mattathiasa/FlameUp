import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Local notifications for cooking timers.
///
/// A step timer has to fire when the step ends, not when the user next opens
/// the app. Scheduling at the OS level is what makes a timer real: the phone
/// wakes and tells you the onions are done whether or not FlameUp is running.
///
/// Permission may be refused, and the app must stay fully usable if it is —
/// the on-screen countdown is still correct because it is computed from a
/// deadline, not from notifications having fired.
class TimerNotifications {
  TimerNotifications([FlutterLocalNotificationsPlugin? plugin])
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  bool _ready = false;
  bool _permitted = false;

  /// Cooking timers get their own channel so a user can silence reminders
  /// without silencing the thing that says a dish is about to burn.
  static const AndroidNotificationDetails _android = AndroidNotificationDetails(
    'cooking_timers',
    'Cooking timers',
    channelDescription: 'Fires when a cooking step finishes.',
    importance: Importance.max,
    priority: Priority.high,
    category: AndroidNotificationCategory.alarm,
    playSound: true,
  );

  static const DarwinNotificationDetails _apple = DarwinNotificationDetails(
    presentAlert: true,
    presentSound: true,
    interruptionLevel: InterruptionLevel.timeSensitive,
  );

  static const NotificationDetails _details =
      NotificationDetails(android: _android, iOS: _apple);

  Future<void> initialise() async {
    if (_ready) return;

    tz.initializeTimeZones();

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        // Requested when a timer is first scheduled instead, so the prompt
        // arrives with a reason attached rather than at launch.
        requestAlertPermission: false,
        requestSoundPermission: false,
      ),
    );

    await _plugin.initialize(settings);
    _ready = true;
  }

  /// Ask for permission. Called when the user starts their first timer, so the
  /// prompt has obvious context.
  Future<bool> requestPermission() async {
    await initialise();

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      _permitted = await android.requestNotificationsPermission() ?? false;
      return _permitted;
    }

    final apple = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (apple != null) {
      _permitted =
          await apple.requestPermissions(alert: true, sound: true) ?? false;
      return _permitted;
    }

    return false;
  }

  /// Schedule an alert for when a step's timer runs out.
  ///
  /// [id] is derived from the session and step, so re-scheduling the same step
  /// replaces its alert rather than stacking a second one.
  Future<void> scheduleStepAlert({
    required int id,
    required DateTime deadline,
    required String title,
    required String body,
  }) async {
    await initialise();
    if (deadline.isBefore(DateTime.now())) return;

    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(deadline, tz.local),
        _details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (error) {
      // Exact alarms can be refused by the OS. The countdown on screen is
      // unaffected, so this is a degraded reminder, not a broken timer.
      debugPrint('[timers] could not schedule alert: $error');
    }
  }

  Future<void> cancel(int id) async {
    await initialise();
    await _plugin.cancel(id);
  }

  /// Clear every pending alert — on finishing or abandoning a cook.
  Future<void> cancelAll() async {
    await initialise();
    await _plugin.cancelAll();
  }

  /// A stable notification id for a session step.
  ///
  /// Notification ids are 32-bit, so the session id is hashed rather than used
  /// directly.
  static int idFor(String sessionId, int step) =>
      (sessionId.hashCode & 0x7FFFFF) * 100 + (step % 100);
}

final timerNotificationsProvider =
    Provider<TimerNotifications>((ref) => TimerNotifications());
