import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Keeps the screen awake for the duration of cook mode.
///
/// A simmering pot is read glances, not active touch — the default screen
/// timeout would put the phone to sleep mid-step. Timers survive that (they
/// are wall-clock deadlines), but a dark screen is a worse kitchen companion
/// than a bright one, so cook mode holds the display while it is open and
/// releases it the moment it closes. All calls are best-effort: a simulator
/// or an unsupported platform just refuses, and the app is unaffected.
class CookWakelock {
  CookWakelock();

  Future<void> enable() async {
    try {
      await WakelockPlus.enable();
    } catch (error) {
      // e.g. unsupported platform — the screen simply times out as usual.
    }
  }

  Future<void> disable() async {
    try {
      await WakelockPlus.disable();
    } catch (error) {
      // Nothing to fall back to; the wakelock was never held.
    }
  }
}

final cookWakelockProvider = Provider<CookWakelock>((ref) => CookWakelock());
