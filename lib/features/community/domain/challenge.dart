import 'package:uuid/uuid.dart';

/// Where a "Who Cooks Better?" challenge stands.
enum ChallengeStatus {
  invited,
  accepted,
  cooking,
  judging,
  complete,
  declined;

  static ChallengeStatus fromName(String? name) =>
      ChallengeStatus.values.where((s) => s.name == name).firstOrNull ??
      ChallengeStatus.invited;
}

/// How a submission is scored. Four dimensions, because "it looked better but
/// tasted worse" is a real outcome that one number cannot express.
class ChallengeScores {
  const ChallengeScores({
    this.taste = 3,
    this.presentation = 3,
    this.difficulty = 3,
    this.authenticity = 3,
  });

  final int taste;
  final int presentation;
  final int difficulty;
  final int authenticity;

  int get total => taste + presentation + difficulty + authenticity;

  Map<String, dynamic> toJson() => {
        'taste': taste,
        'presentation': presentation,
        'difficulty': difficulty,
        'authenticity': authenticity,
      };

  static ChallengeScores fromJson(Map<String, dynamic>? json) =>
      ChallengeScores(
        taste: json?['taste'] as int? ?? 3,
        presentation: json?['presentation'] as int? ?? 3,
        difficulty: json?['difficulty'] as int? ?? 3,
        authenticity: json?['authenticity'] as int? ?? 3,
      );
}

/// One person's entry in a challenge.
class ChallengeSubmission {
  const ChallengeSubmission({
    required this.uid,
    required this.sessionId,
    required this.scores,
    this.photoUrl,
    this.submittedAt,
  });

  final String uid;

  /// The cooking session behind it. A challenge entry has to be a dish that
  /// was actually cooked, not a claim.
  final String sessionId;

  final ChallengeScores scores;
  final String? photoUrl;
  final DateTime? submittedAt;

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'sessionId': sessionId,
        'scores': scores.toJson(),
        if (photoUrl != null) 'photoUrl': photoUrl,
        'submittedAt': (submittedAt ?? DateTime.now()).toIso8601String(),
      };

  static ChallengeSubmission? fromJson(String uid, Map<String, dynamic>? json) {
    if (json == null) return null;
    final sessionId = json['sessionId'] as String?;
    if (sessionId == null) return null;

    return ChallengeSubmission(
      uid: uid,
      sessionId: sessionId,
      scores: ChallengeScores.fromJson(
        (json['scores'] as Map?)?.cast<String, dynamic>(),
      ),
      photoUrl: json['photoUrl'] as String?,
      submittedAt: DateTime.tryParse(json['submittedAt'] as String? ?? ''),
    );
  }
}

/// Two people cooking the same dish, compared.
class Challenge {
  Challenge({
    required this.createdBy,
    required this.opponentId,
    required this.recipeId,
    required this.recipeTitle,
    this.status = ChallengeStatus.invited,
    this.winnerId,
    this.submissions = const {},
    String? id,
    DateTime? createdAt,
    DateTime? deadline,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        // A challenge with no end never resolves, and an open invitation
        // sitting forever is worse than one that lapses.
        deadline = deadline ?? DateTime.now().add(const Duration(days: 7));

  final String id;
  final String createdBy;
  final String opponentId;
  final String recipeId;
  final String recipeTitle;
  final ChallengeStatus status;

  /// Decided server-side. The rules forbid a client writing it, so neither
  /// participant can declare themselves the winner.
  final String? winnerId;

  final Map<String, ChallengeSubmission> submissions;
  final DateTime createdAt;
  final DateTime deadline;

  bool get bothSubmitted => submissions.length >= 2;

  bool hasSubmitted(String uid) => submissions.containsKey(uid);

  bool hasExpired(DateTime now) => now.isAfter(deadline);

  /// Whether [uid] may see the other person's entry.
  ///
  /// Only once they have submitted their own — otherwise the second cook could
  /// simply out-score what they had already seen.
  bool canSeeOpponent(String uid) => hasSubmitted(uid) && bothSubmitted;

  String otherParticipant(String uid) =>
      uid == createdBy ? opponentId : createdBy;

  Challenge copyWith({
    ChallengeStatus? status,
    String? winnerId,
    Map<String, ChallengeSubmission>? submissions,
  }) =>
      Challenge(
        id: id,
        createdBy: createdBy,
        opponentId: opponentId,
        recipeId: recipeId,
        recipeTitle: recipeTitle,
        status: status ?? this.status,
        winnerId: winnerId ?? this.winnerId,
        submissions: submissions ?? this.submissions,
        createdAt: createdAt,
        deadline: deadline,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdBy': createdBy,
        'opponentId': opponentId,
        'recipeId': recipeId,
        'recipeTitle': recipeTitle,
        'status': status.name,
        if (winnerId != null) 'winnerId': winnerId,
        'createdAt': createdAt.toIso8601String(),
        'deadline': deadline.toIso8601String(),
      };

  static Challenge? fromJson(String id, Map<String, dynamic>? json) {
    if (json == null) return null;
    final createdBy = json['createdBy'] as String?;
    final opponentId = json['opponentId'] as String?;
    if (createdBy == null || opponentId == null) return null;

    return Challenge(
      id: id,
      createdBy: createdBy,
      opponentId: opponentId,
      recipeId: json['recipeId'] as String? ?? '',
      recipeTitle: json['recipeTitle'] as String? ?? '',
      status: ChallengeStatus.fromName(json['status'] as String?),
      winnerId: json['winnerId'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      deadline: DateTime.tryParse(json['deadline'] as String? ?? ''),
    );
  }
}
