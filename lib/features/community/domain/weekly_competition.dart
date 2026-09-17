import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/firestore_date.dart';

// ---------------------------------------------------------------------------
// Week math
// ---------------------------------------------------------------------------

/// Monday 00:00 UTC of the week containing [date].
///
/// Weeks bucket on UTC, not local time: a leaderboard that resets at a
/// different moment on every device is not a leaderboard, and a week id
/// derived from local midnight would disagree with the server's `request.time`
/// checks by up to a whole day. The cost — the week flips at 3am in Addis —
/// is the honest version of "weekly".
DateTime weekStart(DateTime date) {
  final utc = DateTime.utc(date.year, date.month, date.day);
  // DateTime.weekday: Monday = 1 ... Sunday = 7.
  return utc.subtract(Duration(days: utc.weekday - 1));
}

/// Stable document id for the week containing [date], e.g. `w2026w38`.
///
/// ISO 8601 week numbering: the year is the year of the week's Thursday, and
/// week 1 is the week containing the first Thursday of January. Encoded here
/// once because every surface — rules, rows, entries, seeds — must agree on
/// the id, and three implementations of it would eventually disagree.
String weekIdFor(DateTime date) {
  final start = weekStart(date);
  final thursday = start.add(const Duration(days: 3));
  final year = thursday.year;

  // Week 1's Monday is the Monday of the week containing 4 January (whose
  // week always holds the first Thursday).
  final jan4 = DateTime.utc(year, 1, 4);
  final firstMonday = weekStart(jan4);
  final week = start.difference(firstMonday).inDays ~/ 7 + 1;

  return 'w${year}w$week';
}

// ---------------------------------------------------------------------------
// The weekly challenge
// ---------------------------------------------------------------------------

/// One week's community cook-off, written by a moderator (or the seeder).
///
/// Deliberately shallow: the recipe id is the contract, the titles are copies
/// for the card, and the deadline is what the rules enforce — an entry
/// submitted after it is refused server-side.
class WeeklyChallenge {
  const WeeklyChallenge({
    required this.id,
    required this.recipeId,
    required this.recipeTitle,
    required this.recipeTitleAm,
    required this.deadline,
    this.note,
    this.noteAm,
    this.publishedAt,
  });

  /// Equals the week id — the document key is the calendar position.
  final String id;
  final String recipeId;
  final String recipeTitle;
  final String recipeTitleAm;

  /// Entries after this instant are refused by the rules, not by the client.
  final DateTime deadline;
  final String? note;
  final String? noteAm;
  final DateTime? publishedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'recipeId': recipeId,
        'recipeTitle': recipeTitle,
        'recipeTitleAm': recipeTitleAm,
        // A Timestamp, not an ISO string: the rules compare this field
        // against request.time, which only works on real timestamps.
        'deadline': Timestamp.fromDate(deadline),
        if (note != null) 'note': note,
        if (noteAm != null) 'noteAm': noteAm,
        'publishedAt': firestoreDate(publishedAt) != null
            ? Timestamp.fromDate(publishedAt!)
            : FieldValue.serverTimestamp(),
      };

  static WeeklyChallenge? fromJson(String id, Map<String, dynamic>? json) {
    if (json == null) return null;
    final recipeId = json['recipeId'] as String?;
    if (recipeId == null || recipeId.isEmpty) return null;

    return WeeklyChallenge(
      id: id,
      recipeId: recipeId,
      recipeTitle: json['recipeTitle'] as String? ?? '',
      recipeTitleAm: json['recipeTitleAm'] as String? ?? '',
      deadline: firestoreDate(json['deadline']) ??
          DateTime.now().add(const Duration(days: 7)),
      note: json['note'] as String?,
      noteAm: json['noteAm'] as String?,
      publishedAt: firestoreDate(json['publishedAt']),
    );
  }
}

// ---------------------------------------------------------------------------
// Weekly XP rows
// ---------------------------------------------------------------------------

/// One person's week: XP earned from completed cooks, Monday to Monday.
///
/// This is a **client-maintained** aggregate — the one compromise Spark makes
/// us accept while progression on the user document stays server-only. The
/// rules bound what a client can claim (own row only, never decreasing,
/// bounded), and honest numbers come from the same `recipe.xpReward` the
/// reward function would grant. It is self-reported by design; a paid Blaze
/// deployment can replace the writer with a Cloud Function without touching
/// the readers.
class WeeklyXpRow {
  const WeeklyXpRow({
    required this.uid,
    required this.weekId,
    required this.displayName,
    required this.xp,
    required this.cooks,
    this.updatedAt,
  });

  final String uid;
  final String weekId;
  final String displayName;
  final int xp;

  /// Completed cooks behind [xp] — the context that makes a number a story.
  final int cooks;
  final DateTime? updatedAt;

  /// `{weekId}_{uid}` — the deterministic key that makes a row idempotent
  /// and lets the rules tie it to its owner.
  static String docId(String weekId, String uid) => '${weekId}_$uid';

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'weekId': weekId,
        'displayName': displayName,
        'xp': xp,
        'cooks': cooks,
        'updatedAt': updatedAt != null
            ? Timestamp.fromDate(updatedAt!)
            : FieldValue.serverTimestamp(),
      };

  static WeeklyXpRow? fromJson(String id, Map<String, dynamic>? json) {
    if (json == null) return null;
    final uid = json['uid'] as String?;
    if (uid == null || uid.isEmpty) return null;

    return WeeklyXpRow(
      uid: uid,
      weekId: json['weekId'] as String? ?? id.split('_').first,
      displayName: json['displayName'] as String? ?? '',
      xp: json['xp'] as int? ?? 0,
      cooks: json['cooks'] as int? ?? 0,
      updatedAt: firestoreDate(json['updatedAt']),
    );
  }
}

// ---------------------------------------------------------------------------
// Challenge entries
// ---------------------------------------------------------------------------

/// One person's proof of cooking the week's dish.
///
/// The rules refuse a create whose session doc does not exist in the
/// entrant's own cooking_sessions, is not completed, and does not match the
/// week's recipe — so an entry is a claim the backend can check, not a
/// number the client made up.
class WeeklyChallengeEntry {
  const WeeklyChallengeEntry({
    required this.uid,
    required this.sessionId,
    required this.displayName,
    required this.xp,
    this.photoUrl,
    this.completedAt,
  });

  final String uid;
  final String sessionId;
  final String displayName;
  final int xp;
  final String? photoUrl;
  final DateTime? completedAt;

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'sessionId': sessionId,
        'displayName': displayName,
        'xp': xp,
        if (photoUrl != null) 'photoUrl': photoUrl,
        'completedAt': completedAt != null
            ? Timestamp.fromDate(completedAt!)
            : FieldValue.serverTimestamp(),
      };

  static WeeklyChallengeEntry? fromJson(
    String uid,
    Map<String, dynamic>? json,
  ) {
    if (json == null) return null;
    final sessionId = json['sessionId'] as String?;
    if (sessionId == null) return null;

    return WeeklyChallengeEntry(
      uid: uid,
      sessionId: sessionId,
      displayName: json['displayName'] as String? ?? '',
      xp: json['xp'] as int? ?? 0,
      photoUrl: json['photoUrl'] as String?,
      completedAt: firestoreDate(json['completedAt']),
    );
  }
}
