import 'package:uuid/uuid.dart';

/// Where a cooking session stands.
enum SessionStatus {
  inProgress,
  completed,
  abandoned;

  static SessionStatus fromName(String? name) =>
      SessionStatus.values.where((s) => s.name == name).firstOrNull ??
      SessionStatus.inProgress;
}

/// One attempt at cooking one recipe.
///
/// Written locally first and mirrored to Firestore, so a session survives the
/// app being killed, the device restarting, and having no network throughout.
class CookingSession {
  CookingSession({
    required this.recipeId,
    required this.totalSteps,
    required this.servings,
    String? id,
    String? idempotencyKey,
    this.currentStep = 0,
    this.status = SessionStatus.inProgress,
    DateTime? startedAt,
    this.completedAt,
    DateTime? lastActiveAt,
    this.stepDeadlines = const {},
    this.pausedRemaining = const {},
    this.offlineCreated = false,
  })  : id = id ?? const Uuid().v4(),
        // Minted when the session starts, not when it completes, so a retry
        // after a crash carries the same key and cannot double-award XP.
        idempotencyKey = idempotencyKey ?? const Uuid().v4(),
        startedAt = startedAt ?? DateTime.now(),
        lastActiveAt = lastActiveAt ?? DateTime.now();

  final String id;
  final String recipeId;
  final int totalSteps;
  final int servings;
  final int currentStep;
  final SessionStatus status;
  final DateTime startedAt;
  final DateTime? completedAt;
  final DateTime lastActiveAt;

  /// Absolute wall-clock deadlines, keyed by step index.
  ///
  /// **Not remaining seconds.** A timer is then a subtraction against the
  /// clock, which stays correct whether the app was backgrounded, killed, or
  /// the phone was asleep — the thing a `Timer` counting ticks cannot do.
  final Map<int, DateTime> stepDeadlines;

  /// Seconds left on a paused step, keyed by step index. A paused timer has no
  /// deadline, because the clock is not running.
  final Map<int, int> pausedRemaining;

  /// One reward grant per session, ever.
  final String idempotencyKey;

  final bool offlineCreated;

  bool get isActive => status == SessionStatus.inProgress;
  bool get isOnLastStep => currentStep >= totalSteps - 1;
  double get progress => totalSteps == 0 ? 0 : (currentStep + 1) / totalSteps;

  /// Whether [step] has a running timer.
  bool isTimerRunning(int step) => stepDeadlines.containsKey(step);

  bool isTimerPaused(int step) => pausedRemaining.containsKey(step);

  /// Time left on [step], computed from the clock.
  ///
  /// Returns [Duration.zero] once the deadline has passed — which is how a
  /// timer that expired while the app was closed reports itself on reopening.
  Duration remainingFor(int step, {DateTime? now}) {
    final paused = pausedRemaining[step];
    if (paused != null) return Duration(seconds: paused);

    final deadline = stepDeadlines[step];
    if (deadline == null) return Duration.zero;

    final left = deadline.difference(now ?? DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  /// Whether a timer finished while nobody was watching.
  bool hasExpiredTimer(int step, {DateTime? now}) {
    final deadline = stepDeadlines[step];
    if (deadline == null) return false;
    return !(now ?? DateTime.now()).isBefore(deadline);
  }

  CookingSession copyWith({
    int? currentStep,
    SessionStatus? status,
    DateTime? completedAt,
    DateTime? lastActiveAt,
    Map<int, DateTime>? stepDeadlines,
    Map<int, int>? pausedRemaining,
    int? servings,
  }) =>
      CookingSession(
        id: id,
        recipeId: recipeId,
        totalSteps: totalSteps,
        servings: servings ?? this.servings,
        currentStep: currentStep ?? this.currentStep,
        status: status ?? this.status,
        startedAt: startedAt,
        completedAt: completedAt ?? this.completedAt,
        lastActiveAt: lastActiveAt ?? DateTime.now(),
        stepDeadlines: stepDeadlines ?? this.stepDeadlines,
        pausedRemaining: pausedRemaining ?? this.pausedRemaining,
        idempotencyKey: idempotencyKey,
        offlineCreated: offlineCreated,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'recipeId': recipeId,
        'totalSteps': totalSteps,
        'servings': servings,
        'currentStep': currentStep,
        'status': status.name,
        'startedAt': startedAt.toIso8601String(),
        if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
        'lastActiveAt': lastActiveAt.toIso8601String(),
        'stepDeadlines': {
          for (final entry in stepDeadlines.entries)
            entry.key.toString(): entry.value.toIso8601String(),
        },
        'pausedRemaining': {
          for (final entry in pausedRemaining.entries)
            entry.key.toString(): entry.value,
        },
        'idempotencyKey': idempotencyKey,
        'offlineCreated': offlineCreated,
      };

  static CookingSession? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final id = json['id'] as String?;
    final recipeId = json['recipeId'] as String?;
    final key = json['idempotencyKey'] as String?;
    final startedAt = DateTime.tryParse(json['startedAt'] as String? ?? '');
    if (id == null || recipeId == null || key == null || startedAt == null) {
      return null;
    }

    return CookingSession(
      id: id,
      recipeId: recipeId,
      totalSteps: json['totalSteps'] as int? ?? 0,
      servings: json['servings'] as int? ?? 4,
      currentStep: json['currentStep'] as int? ?? 0,
      status: SessionStatus.fromName(json['status'] as String?),
      startedAt: startedAt,
      completedAt: DateTime.tryParse(json['completedAt'] as String? ?? ''),
      lastActiveAt:
          DateTime.tryParse(json['lastActiveAt'] as String? ?? '') ?? startedAt,
      stepDeadlines: {
        for (final entry in (json['stepDeadlines'] as Map?)?.entries ??
            const <dynamic, dynamic>{}.entries)
          if (int.tryParse(entry.key.toString()) != null &&
              DateTime.tryParse(entry.value.toString()) != null)
            int.parse(entry.key.toString()):
                DateTime.parse(entry.value.toString()),
      },
      pausedRemaining: {
        for (final entry in (json['pausedRemaining'] as Map?)?.entries ??
            const <dynamic, dynamic>{}.entries)
          if (int.tryParse(entry.key.toString()) != null)
            int.parse(entry.key.toString()):
                int.tryParse(entry.value.toString()) ?? 0,
      },
      idempotencyKey: key,
      offlineCreated: json['offlineCreated'] as bool? ?? false,
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
