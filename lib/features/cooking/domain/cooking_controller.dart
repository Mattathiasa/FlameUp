import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/timer_notifications.dart';
import '../../auth/domain/auth_providers.dart';
import '../../community/domain/weekly_providers.dart';
import '../../recipes/domain/recipe.dart';
import '../../recipes/domain/recipe_providers.dart';
import '../data/cooking_repository.dart';
import 'cooking_session.dart';

/// Drives cook mode.
///
/// Holds the session and a one-second ticker for the display. The ticker only
/// triggers a repaint — it never *is* the timer. The remaining time is always
/// recomputed from [CookingSession.stepDeadlines] against the wall clock, so a
/// missed tick, a backgrounded app or a killed process cannot make a timer
/// wrong.
class CookingController extends AutoDisposeNotifier<CookingSession?> {
  Timer? _ticker;
  _LifecycleWatcher? _lifecycle;

  @override
  CookingSession? build() {
    ref.onDispose(() {
      _ticker?.cancel();
      final watcher = _lifecycle;
      if (watcher != null) WidgetsBinding.instance.removeObserver(watcher);
    });

    // A separate observer rather than mixing WidgetsBindingObserver into the
    // Notifier: its didChangeAppLifecycleState parameter is named `state`,
    // which would shadow the Notifier's own `state`.
    _lifecycle = _LifecycleWatcher(onResumed: _onResumed, onPaused: _onPaused);
    WidgetsBinding.instance.addObserver(_lifecycle!);
    _startTicker();

    // Resume whatever was in progress when the app last closed.
    return ref.watch(cookingRepositoryProvider).activeSession();
  }

  CookingRepository get _repo => ref.read(cookingRepositoryProvider);
  TimerNotifications get _alerts => ref.read(timerNotificationsProvider);
  String? get _uid => ref.read(currentUidProvider);

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final session = state;
      if (session == null || !session.isActive) return;
      // Reassigning the same object is enough to repaint; the values shown are
      // derived from the clock, not accumulated here.
      state = session.copyWith();
    });
  }

  /// Coming back from the background: recompute immediately rather than
  /// waiting up to a second for the next tick, so the timer is right on the
  /// first frame the user sees.
  void _onResumed() {
    final session = state;
    if (session != null) state = session.copyWith();
    _startTicker();
  }

  /// No point ticking a display nobody is looking at. The timers themselves
  /// are unaffected -- they are deadlines, not counters.
  void _onPaused() => _ticker?.cancel();

  /// Begin cooking [recipe], or resume an existing session for it.
  Future<CookingSession?> start(Recipe recipe, {int? servings}) async {
    final uid = _uid;
    if (uid == null) return null;

    // Resuming beats starting over: a session already in flight for this
    // recipe keeps its progress, its timers and its idempotency key.
    final existing = _repo.activeSession();
    if (existing != null && existing.recipeId == recipe.id) {
      state = existing;
      return existing;
    }

    final session = CookingSession(
      recipeId: recipe.id,
      totalSteps: recipe.steps.length,
      servings: servings ?? recipe.servings,
    );

    await _repo.save(session, uid: uid);
    state = session;
    return session;
  }

  /// Move to [step], starting its timer if it has one.
  Future<void> goToStep(int step, {required Recipe recipe}) async {
    final session = state;
    final uid = _uid;
    if (session == null || uid == null) return;
    if (step < 0 || step >= session.totalSteps) return;

    final recipeStep = recipe.steps[step];
    final deadlines = Map<int, DateTime>.from(session.stepDeadlines);
    final paused = Map<int, int>.from(session.pausedRemaining);

    // Arriving at a timed step starts its clock, unless it already ran.
    if (recipeStep.hasTimer &&
        !deadlines.containsKey(step) &&
        !paused.containsKey(step)) {
      final deadline = DateTime.now().add(recipeStep.duration!);
      deadlines[step] = deadline;

      // The OS alert is what reaches a user who has put the phone down. The
      // on-screen countdown does not depend on it, so a refused permission
      // degrades the reminder rather than breaking the timer.
      unawaited(
        _alerts.scheduleStepAlert(
          id: TimerNotifications.idFor(session.id, step),
          deadline: deadline,
          title: recipe.title,
          body: recipeStep.text,
        ),
      );
    }

    final next = session.copyWith(
      currentStep: step,
      stepDeadlines: deadlines,
      pausedRemaining: paused,
    );

    state = next;
    await _repo.save(next, uid: uid);
  }

  Future<void> nextStep(Recipe recipe) =>
      goToStep(state!.currentStep + 1, recipe: recipe);

  /// Advance past an optional step without completing it.
  ///
  /// "Optional" is a promise the pipeline has to keep everywhere: the detail
  /// screen marks the step, so cook mode must let a cook decline it. The
  /// skipped step is recorded on the session (an honest history — "I made
  /// this without the berbere bullion") and any running timer for it is
  /// cancelled, since leaving one alive would fire an alert for a step the
  /// cook stepped over.
  Future<void> skipStep(Recipe recipe) async {
    final session = state;
    final uid = _uid;
    if (session == null || uid == null) return;

    final step = session.currentStep;
    if (!recipe.steps[step].optional) return;

    final deadlines = Map<int, DateTime>.from(session.stepDeadlines)
      ..remove(step);
    final paused = Map<int, int>.from(session.pausedRemaining)..remove(step);
    await _alerts.cancel(TimerNotifications.idFor(session.id, step));

    final next = session.copyWith(
      skippedSteps: [...session.skippedSteps, step],
      stepDeadlines: deadlines,
      pausedRemaining: paused,
    );
    state = next;
    await _repo.save(next, uid: uid);

    await nextStep(recipe);
  }

  Future<void> previousStep(Recipe recipe) =>
      goToStep(state!.currentStep - 1, recipe: recipe);

  /// Pause the current step's timer, banking the remaining seconds.
  Future<void> pauseTimer() async {
    final session = state;
    final uid = _uid;
    if (session == null || uid == null) return;

    final step = session.currentStep;
    if (!session.isTimerRunning(step)) return;

    final remaining = session.remainingFor(step);
    final deadlines = Map<int, DateTime>.from(session.stepDeadlines)
      ..remove(step);
    final paused = Map<int, int>.from(session.pausedRemaining)
      ..[step] = remaining.inSeconds;

    final next = session.copyWith(
      stepDeadlines: deadlines,
      pausedRemaining: paused,
    );

    // A paused timer must not fire.
    unawaited(_alerts.cancel(TimerNotifications.idFor(session.id, step)));

    state = next;
    await _repo.save(next, uid: uid);
  }

  /// Resume a paused timer, setting a new deadline from the banked seconds.
  Future<void> resumeTimer() async {
    final session = state;
    final uid = _uid;
    if (session == null || uid == null) return;

    final step = session.currentStep;
    final remaining = session.pausedRemaining[step];
    if (remaining == null) return;

    final paused = Map<int, int>.from(session.pausedRemaining)..remove(step);
    final deadline = DateTime.now().add(Duration(seconds: remaining));
    final deadlines = Map<int, DateTime>.from(session.stepDeadlines)
      ..[step] = deadline;

    final next = session.copyWith(
      stepDeadlines: deadlines,
      pausedRemaining: paused,
    );

    unawaited(
      _alerts.scheduleStepAlert(
        id: TimerNotifications.idFor(session.id, step),
        deadline: deadline,
        title: 'FlameUp',
        body: 'Your timer is running again.',
      ),
    );

    state = next;
    await _repo.save(next, uid: uid);
  }

  /// Restart the current step's timer from the top.
  Future<void> restartTimer(Recipe recipe) async {
    final session = state;
    final uid = _uid;
    if (session == null || uid == null) return;

    final step = session.currentStep;
    final recipeStep = recipe.steps[step];
    if (!recipeStep.hasTimer) return;

    final deadline = DateTime.now().add(recipeStep.duration!);
    final deadlines = Map<int, DateTime>.from(session.stepDeadlines)
      ..[step] = deadline;
    final paused = Map<int, int>.from(session.pausedRemaining)..remove(step);

    final next = session.copyWith(
      stepDeadlines: deadlines,
      pausedRemaining: paused,
    );

    unawaited(
      _alerts.scheduleStepAlert(
        id: TimerNotifications.idFor(session.id, step),
        deadline: deadline,
        title: recipe.title,
        body: recipeStep.text,
      ),
    );

    state = next;
    await _repo.save(next, uid: uid);
  }

  /// Finish. Records completion; the server decides the reward.
  ///
  /// The completed cook is also folded into this week's XP row — the
  /// Spark-safe aggregate behind the weekly leaderboard (see WeeklyRepository).
  /// Best-effort and unawaited-with-guard: a leaderboard row must never be
  /// able to fail a cook, only miss it.
  Future<CookingSession?> finish() async {
    final session = state;
    final uid = _uid;
    if (session == null || uid == null) return null;

    // The dish is done; no step alert should still be pending.
    unawaited(_alerts.cancelAll());

    final result = await _repo.complete(session, uid: uid);
    final completed = result.valueOrNull;
    if (completed != null) {
      state = completed;
      unawaited(_recordWeeklyXp(completed, uid));
    }
    return completed;
  }

  /// Report the week's XP. Fire-and-forget with the error swallowed: the
  /// weekly board is a bonus surface, and a failed write here (offline, for
  /// instance) must not surface as a cook failure.
  Future<void> _recordWeeklyXp(CookingSession completed, String uid) async {
    try {
      final recipe = await _recipeFor(completed.recipeId);
      final user = FirebaseAuth.instance.currentUser;
      await ref.read(weeklyRepositoryProvider).recordCookCompletion(
            session: completed,
            uid: uid,
            displayName: user?.displayName ?? 'Cook',
            xpEarned: recipe?.xpReward ?? 0,
          );
    } catch (_) {
      // Deliberately silent — see the doc comment above.
    }
  }

  /// The recipe behind a session, resolved through the cache-first provider
  /// stack so an offline finish still finds it.
  Future<Recipe?> _recipeFor(String recipeId) async {
    try {
      return await ref.read(recipeProvider(recipeId).future).then(
            (cached) => cached.value,
          );
    } catch (_) {
      return null;
    }
  }

  /// Give up on this cook. Kept rather than deleted, so the history is honest
  /// and a half-finished dish is not silently erased.
  Future<void> abandon() async {
    final session = state;
    final uid = _uid;
    if (session == null || uid == null) return;

    unawaited(_alerts.cancelAll());
    await _repo.abandon(session, uid: uid);
    state = null;
  }
}

final cookingControllerProvider =
    AutoDisposeNotifierProvider<CookingController, CookingSession?>(
  CookingController.new,
);

/// The session waiting to be resumed, if any. Drives the "pick up where you
/// left" card on Today and at the top of the Cook tab.
final resumableSessionProvider = Provider<CookingSession?>((ref) {
  // Watching the version counter is what makes this reactive: the card
  // disappears the moment a session completes, without any manual
  // invalidate from the screens.
  ref.watch(sessionStoreVersionProvider);
  return ref.watch(cookingRepositoryProvider).activeSession();
});

/// Completed cooks on this device, aggregated per recipe: recipe id -> number
/// of times cooked. Newest sessions carry the most weight in ordering.
final cookingHistoryProvider = Provider<Map<String, int>>((ref) {
  ref.watch(sessionStoreVersionProvider);
  final counts = <String, int>{};
  for (final session in ref.watch(cookingRepositoryProvider).allLocal()) {
    if (session.status != SessionStatus.completed) continue;
    counts[session.recipeId] = (counts[session.recipeId] ?? 0) + 1;
  }
  return counts;
});

/// Forwards app lifecycle changes to callbacks.
///
/// Exists so [CookingController] does not have to mix in
/// [WidgetsBindingObserver], whose `didChangeAppLifecycleState` parameter is
/// named `state` and would shadow the Notifier's own `state`.
class _LifecycleWatcher with WidgetsBindingObserver {
  _LifecycleWatcher({required this.onResumed, required this.onPaused});

  final VoidCallback onResumed;
  final VoidCallback onPaused;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        onResumed();
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        onPaused();
    }
  }
}
