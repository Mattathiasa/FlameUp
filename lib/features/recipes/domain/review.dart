import 'package:uuid/uuid.dart';

/// A rating left after cooking a dish.
///
/// Four dimensions rather than one star count, because "hard but delicious"
/// and "easy but bland" are different reports and a single number loses both.
class Review {
  Review({
    required this.recipeId,
    required this.sessionId,
    required this.uid,
    required this.taste,
    this.difficulty = 3,
    this.instructions = 3,
    this.authenticity = 3,
    this.wouldCookAgain = true,
    this.body,
    this.photoUrl,
    this.shareToCommunity = false,
    String? id,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  final String id;
  final String recipeId;

  /// The cooking session this rates.
  ///
  /// Required, and checked server-side: a review must reference a completed
  /// session owned by the writer, which is how "you can only rate what you
  /// actually cooked" is enforced where it matters.
  final String sessionId;

  final String uid;

  /// 1–5. How it tasted — the only dimension the design's screen collects
  /// directly; the rest default to neutral and can be refined later.
  final int taste;

  final int difficulty;
  final int instructions;
  final int authenticity;
  final bool wouldCookAgain;
  final String? body;
  final String? photoUrl;

  /// Whether to post this to the community feed as well.
  final bool shareToCommunity;

  final DateTime createdAt;

  Review copyWith({
    int? taste,
    int? difficulty,
    int? instructions,
    int? authenticity,
    bool? wouldCookAgain,
    String? body,
    String? photoUrl,
    bool? shareToCommunity,
  }) =>
      Review(
        id: id,
        recipeId: recipeId,
        sessionId: sessionId,
        uid: uid,
        taste: taste ?? this.taste,
        difficulty: difficulty ?? this.difficulty,
        instructions: instructions ?? this.instructions,
        authenticity: authenticity ?? this.authenticity,
        wouldCookAgain: wouldCookAgain ?? this.wouldCookAgain,
        body: body ?? this.body,
        photoUrl: photoUrl ?? this.photoUrl,
        shareToCommunity: shareToCommunity ?? this.shareToCommunity,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'recipeId': recipeId,
        'sessionId': sessionId,
        'uid': uid,
        'taste': taste,
        'difficulty': difficulty,
        'instructions': instructions,
        'authenticity': authenticity,
        'wouldCookAgain': wouldCookAgain,
        if (body != null && body!.trim().isNotEmpty) 'body': body!.trim(),
        if (photoUrl != null) 'photoUrl': photoUrl,
        'shareToCommunity': shareToCommunity,
        'createdAt': createdAt.toIso8601String(),
      };

  static Review? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final recipeId = json['recipeId'] as String?;
    final sessionId = json['sessionId'] as String?;
    final uid = json['uid'] as String?;
    if (recipeId == null || sessionId == null || uid == null) return null;

    return Review(
      id: json['id'] as String?,
      recipeId: recipeId,
      sessionId: sessionId,
      uid: uid,
      taste: json['taste'] as int? ?? 3,
      difficulty: json['difficulty'] as int? ?? 3,
      instructions: json['instructions'] as int? ?? 3,
      authenticity: json['authenticity'] as int? ?? 3,
      wouldCookAgain: json['wouldCookAgain'] as bool? ?? true,
      body: json['body'] as String?,
      photoUrl: json['photoUrl'] as String?,
      shareToCommunity: json['shareToCommunity'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
    );
  }
}
