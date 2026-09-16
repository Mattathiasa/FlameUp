import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/firestore_paths.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/result/result.dart';
import '../../cooking/domain/cooking_session.dart';
import '../domain/weekly_competition.dart';

/// Reads and writes the weekly competition: the week's cook-off, the XP rows
/// behind the leaderboard, and the entrants' proof-of-cook.
///
/// The shape of this class is the Spark compromise made explicit: writes are
/// client-side and rules-bounded (the seeder/moderator curates the challenge;
/// cooks report their own week), while every claim the rules can check is
/// checked there. When a paid tier replaces the row writer with a scheduled
/// function, only [recordCookCompletion] disappears — the readers survive.
class WeeklyRepository {
  WeeklyRepository({FirebaseFirestore? firestore}) : _injected = firestore;

  final FirebaseFirestore? _injected;

  /// Resolved lazily: the repository must be constructible without Firebase
  /// (tests, offline-first construction) — see CookingRepository.
  FirebaseFirestore get _fs => _injected ?? FirebaseFirestore.instance;

  // --- reads --------------------------------------------------------------

  /// The cook-off for [weekId], if one was published.
  Stream<WeeklyChallenge?> watchChallenge(String weekId) => _fs
      .doc('${FirestorePaths.weeklyChallenges}/$weekId')
      .snapshots()
      .map((doc) => WeeklyChallenge.fromJson(doc.id, doc.data()));

  /// The global weekly board: highest XP first, capped at 50 rows.
  Stream<List<WeeklyXpRow>> watchLeaderboard({int limit = 50}) => _fs
      .collection(FirestorePaths.weeklyXp)
      .where('weekId', isEqualTo: weekIdFor(DateTime.now()))
      .orderBy('xp', descending: true)
      .limit(limit)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => WeeklyXpRow.fromJson(doc.id, doc.data()))
          .whereType<WeeklyXpRow>()
          .toList(),);

  /// The week's entrants, joined earliest first — the leaderboard of the
  /// cook-off. Ordered by the entry's XP, which the rules tie to a real
  /// session's recipe reward.
  Stream<List<WeeklyChallengeEntry>> watchEntries(String weekId,
          {int limit = 50,}) =>
      _fs
          .collection(FirestorePaths.weeklyChallengeEntries(weekId))
          .orderBy('completedAt', descending: false)
          .limit(limit)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => WeeklyChallengeEntry.fromJson(doc.id, doc.data()))
              .whereType<WeeklyChallengeEntry>()
              .toList(),);

  /// The signed-in user's row for [weekId], so the UI can show their rank.
  Future<WeeklyXpRow?> rowFor(String weekId, String uid) async {
    final doc = await _fs.doc(FirestorePaths.weeklyXpRow(weekId, uid)).get();
    return WeeklyXpRow.fromJson(doc.id, doc.data());
  }

  // --- writes -------------------------------------------------------------

  /// Fold a completed cook into the user's week.
  ///
  /// Called from the cook flow once per completion with the recipe's own XP
  /// reward — the same figure the (future, paid-tier) reward function would
  /// grant. The row id is deterministic, so a retried write merges instead
  /// of duplicating, and the rules refuse any write that would lower the
  /// total or forge someone else's name onto it.
  Future<Result<void>> recordCookCompletion({
    required CookingSession session,
    required String uid,
    required String displayName,
    required int xpEarned,
  }) =>
      ErrorMapper.guard(() async {
        final weekId = weekIdFor(session.completedAt ?? DateTime.now());
        final ref = _fs.doc(FirestorePaths.weeklyXpRow(weekId, uid));

        await _fs.runTransaction((transaction) async {
          final snapshot = await transaction.get(ref);
          final existing = WeeklyXpRow.fromJson(snapshot.id, snapshot.data());

          transaction.set(
            ref,
            WeeklyXpRow(
              uid: uid,
              weekId: weekId,
              displayName: displayName,
              xp: (existing?.xp ?? 0) + xpEarned,
              cooks: (existing?.cooks ?? 0) + 1,
            ).toJson(),
          );
        });
      });

  /// Enter the week's cook-off with a completed session.
  ///
  /// The rules verify the session exists, is completed, belongs to the
  /// entrant, and matches the week's recipe before this write lands — the
  /// client only assembles the claim.
  Future<Result<void>> enterChallenge({
    required String weekId,
    required WeeklyChallengeEntry entry,
  }) =>
      ErrorMapper.guard(() => _fs
          .doc('${FirestorePaths.weeklyChallengeEntries(weekId)}/${entry.uid}')
          .set(entry.toJson()),);
}
