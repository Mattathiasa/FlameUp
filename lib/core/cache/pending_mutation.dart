import 'package:uuid/uuid.dart';

/// What a queued write is trying to do.
///
/// The set is closed on purpose: every offline-capable write in the app maps
/// to one of these, and the drain logic switches over them exhaustively.
enum MutationKind {
  /// Cooking session created, advanced or completed.
  cookingSession,

  /// A recipe rating. Server-side rules require a completed session.
  review,

  /// Saved / unsaved a recipe.
  savedRecipe,

  /// Shopping list item added, checked or removed.
  shoppingItem,

  /// Meal planner assignment.
  mealPlan,

  /// Profile or settings change.
  userProfile,

  /// Family recipe draft or submission.
  familyRecipe,

  /// Community post, like or comment.
  socialAction,
}

/// A write made while offline, waiting to reach the server.
///
/// The [idempotencyKey] is the whole point. It is generated once, on the
/// device, when the user acts — not when the request is sent. A retry, an app
/// restart mid-drain, or the same mutation queued twice by a double tap all
/// carry the same key, and the server refuses the second grant. That is what
/// stops a cook finished on a plane from awarding XP twice on landing.
class PendingMutation {
  PendingMutation({
    required this.kind,
    required this.path,
    required this.payload,
    String? idempotencyKey,
    DateTime? createdAt,
    this.attempts = 0,
    this.lastError,
  })  : idempotencyKey = idempotencyKey ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  final MutationKind kind;

  /// Firestore path or callable-function name the write targets.
  final String path;

  final Map<String, dynamic> payload;
  final String idempotencyKey;
  final DateTime createdAt;
  final int attempts;

  /// Message key of the last failure, for diagnostics. Never shown raw.
  final String? lastError;

  /// Given up on after this many tries, so a permanently rejected write
  /// cannot block the queue behind it forever.
  static const int maxAttempts = 8;

  bool get isExhausted => attempts >= maxAttempts;

  /// Exponential backoff, capped. Keyed off [attempts] rather than wall time
  /// so a device that was offline for a week does not hammer on reconnect.
  Duration get retryAfter => Duration(
        seconds: switch (attempts) {
          0 => 0,
          1 => 2,
          2 => 8,
          3 => 30,
          4 => 120,
          5 => 600,
          _ => 1800,
        },
      );

  bool get isReadyToRetry =>
      DateTime.now().difference(createdAt) >= retryAfter || attempts == 0;

  PendingMutation copyWith({int? attempts, String? lastError}) =>
      PendingMutation(
        kind: kind,
        path: path,
        payload: payload,
        idempotencyKey: idempotencyKey,
        createdAt: createdAt,
        attempts: attempts ?? this.attempts,
        lastError: lastError ?? this.lastError,
      );

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'path': path,
        'payload': payload,
        'idempotencyKey': idempotencyKey,
        'createdAt': createdAt.toIso8601String(),
        'attempts': attempts,
        if (lastError != null) 'lastError': lastError,
      };

  /// Returns null for an unreadable entry rather than throwing — one corrupt
  /// row must not stop the rest of the queue draining.
  static PendingMutation? fromJson(Map<String, dynamic> json) {
    final kindName = json['kind'] as String?;
    final kind =
        MutationKind.values.where((k) => k.name == kindName).firstOrNull;
    final path = json['path'] as String?;
    final key = json['idempotencyKey'] as String?;
    final createdAt = DateTime.tryParse(json['createdAt'] as String? ?? '');
    if (kind == null || path == null || key == null || createdAt == null) {
      return null;
    }
    return PendingMutation(
      kind: kind,
      path: path,
      payload: (json['payload'] as Map?)?.cast<String, dynamic>() ?? const {},
      idempotencyKey: key,
      createdAt: createdAt,
      attempts: json['attempts'] as int? ?? 0,
      lastError: json['lastError'] as String?,
    );
  }

  @override
  String toString() =>
      'PendingMutation(${kind.name} $path attempts=$attempts key=$idempotencyKey)';
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
