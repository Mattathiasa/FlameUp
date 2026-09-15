import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The moment a step timer hits zero while the app is open.
///
/// The OS-level alert (see [TimerNotifications]) reaches a user who put the
/// phone down, but while FlameUp is on screen iOS and Android suppress their
/// own banners — so without this, a finished timer is silent. A cook with
/// hands in dough and the phone propped across the counter needs to be told
/// out loud that the berbere is done toasting.
///
/// Uses `SystemSound.play` and `HapticFeedback` — no asset to license, no
/// audio session to manage, and neither can fail hard. Best-effort by design.
class TimerCompletionAlert {
  TimerCompletionAlert();

  /// A short burst repeated a few times reads as "come look now" without
  /// needing an audio file — three rounds, ~1.5s, then it is up to the UI.
  static const int _bursts = 3;

  bool _running = false;

  /// Fire the completion signal. Never throws; a missing system sound is a
  /// degraded cue, not a broken step.
  Future<void> play() async {
    if (_running) return;
    _running = true;
    try {
      for (var i = 0; i < _bursts; i++) {
        // Guard against heavy feedback support quirks on some Android skins.
        try {
          await HapticFeedback.heavyImpact();
        } catch (error) {
          debugPrint('[timers] haptic unavailable: $error');
        }
        try {
          await SystemSound.play(SystemSoundType.alert);
        } catch (error) {
          debugPrint('[timers] system sound unavailable: $error');
        }
        if (i < _bursts - 1) {
          await Future<void>.delayed(const Duration(milliseconds: 600));
        }
      }
    } finally {
      _running = false;
    }
  }
}

final timerCompletionAlertProvider =
    Provider<TimerCompletionAlert>((ref) => TimerCompletionAlert());
