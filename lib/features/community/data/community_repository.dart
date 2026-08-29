import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/outbox.dart';
import '../../../core/cache/pending_mutation.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/firestore_paths.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/result/result.dart';
import '../domain/challenge.dart';
import '../domain/post.dart';

/// The community: feed, friends and challenges.
///
/// Reads are paginated queries, never whole-collection pulls. Writes go
/// through the outbox, so a post made with no signal still lands.
class CommunityRepository {
  CommunityRepository({required Outbox outbox, FirebaseFirestore? firestore})
      : _outbox = outbox,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final Outbox _outbox;
  final FirebaseFirestore _firestore;

  // --- feed --------------------------------------------------------------

  /// One page of the feed, newest first.
  ///
  /// [after] is the last document of the previous page, so paging uses a
  /// cursor rather than an offset — offsets re-read everything skipped.
  Future<Result<(List<Post>, DocumentSnapshot<Map<String, dynamic>>?)>>
      feedPage({
    DocumentSnapshot<Map<String, dynamic>>? after,
  }) =>
          ErrorMapper.guard(() async {
            var query = _firestore
                .collection(FirestorePaths.posts)
                .where('visibility', isEqualTo: PostVisibility.public.name)
                .orderBy('createdAt', descending: true)
                .limit(AppConstants.pageSize);

            if (after != null) query = query.startAfterDocument(after);

            final snapshot = await query.get();
            final posts = snapshot.docs
                .map((doc) => Post.fromJson(doc.id, doc.data()))
                .whereType<Post>()
                .toList();

            return (posts, snapshot.docs.isEmpty ? null : snapshot.docs.last);
          });

  Future<Result<void>> createPost(Post post) => ErrorMapper.guard(() async {
        await _outbox.enqueue(
          PendingMutation(
            kind: MutationKind.socialAction,
            path: '${FirestorePaths.posts}/${post.id}',
            payload: post.toJson(),
            // Keyed by the session, so one cook cannot become two posts if the
            // outbox replays.
            idempotencyKey: 'post.${post.sessionId}',
          ),
        );
      });

  /// Like or unlike. The document id is the liker's uid, so a double tap
  /// cannot double-count and the counter trigger stays correct.
  Future<Result<void>> setLike({
    required String postId,
    required String uid,
    required bool liked,
  }) =>
      ErrorMapper.guard(() async {
        final ref =
            _firestore.doc('${FirestorePaths.posts}/$postId/likes/$uid');
        if (liked) {
          await ref.set({'createdAt': FieldValue.serverTimestamp()});
        } else {
          await ref.delete();
        }
      });

  Stream<bool> watchLiked({required String postId, required String uid}) =>
      _firestore
          .doc('${FirestorePaths.posts}/$postId/likes/$uid')
          .snapshots()
          .map((doc) => doc.exists);

  // --- friends -----------------------------------------------------------

  Stream<List<Friend>> watchFriends(String uid) =>
      _firestore.collection(FirestorePaths.userFriends(uid)).snapshots().map(
            (snapshot) => snapshot.docs
                .map((doc) => Friend.fromJson(doc.id, doc.data()))
                .whereType<Friend>()
                .toList(),
          );

  Stream<List<FriendRequest>> watchRequests(String uid) => _firestore
      .collection(FirestorePaths.userFriendRequests(uid))
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map((doc) => FriendRequest.fromJson(doc.id, doc.data()))
            .whereType<FriendRequest>()
            .toList(),
      );

  /// Send a request.
  ///
  /// Written to both sides in one batch: the sender's outgoing record and the
  /// recipient's incoming one. Half a request is worse than none.
  Future<Result<void>> sendFriendRequest({
    required String fromUid,
    required String fromName,
    required String toUid,
  }) =>
      ErrorMapper.guard(() async {
        final batch = _firestore.batch();

        batch.set(
          _firestore
              .doc('${FirestorePaths.userFriendRequests(fromUid)}/$toUid'),
          const FriendRequest(
            otherUid: '',
            direction: RequestDirection.outgoing,
            status: RequestStatus.pending,
          ).toJson()
            ..['otherUid'] = toUid,
        );

        batch.set(
          _firestore
              .doc('${FirestorePaths.userFriendRequests(toUid)}/$fromUid'),
          FriendRequest(
            otherUid: fromUid,
            direction: RequestDirection.incoming,
            status: RequestStatus.pending,
            displayName: fromName,
          ).toJson(),
        );

        await batch.commit();
      });

  /// Accept a request, creating the friendship on both sides.
  Future<Result<void>> acceptFriendRequest({
    required String uid,
    required String uidName,
    required String otherUid,
    required String otherName,
  }) =>
      ErrorMapper.guard(() async {
        final batch = _firestore.batch();
        final now = DateTime.now().toIso8601String();

        batch.set(
          _firestore.doc('${FirestorePaths.userFriends(uid)}/$otherUid'),
          {'displayName': otherName, 'since': now},
        );
        batch.set(
          _firestore.doc('${FirestorePaths.userFriends(otherUid)}/$uid'),
          {'displayName': uidName, 'since': now},
        );

        batch.delete(
          _firestore.doc('${FirestorePaths.userFriendRequests(uid)}/$otherUid'),
        );
        batch.delete(
          _firestore.doc('${FirestorePaths.userFriendRequests(otherUid)}/$uid'),
        );

        await batch.commit();
      });

  Future<Result<void>> declineFriendRequest({
    required String uid,
    required String otherUid,
  }) =>
      ErrorMapper.guard(() async {
        await _firestore
            .doc('${FirestorePaths.userFriendRequests(uid)}/$otherUid')
            .delete();
      });

  /// Remove a friend from both sides.
  Future<Result<void>> removeFriend({
    required String uid,
    required String otherUid,
  }) =>
      ErrorMapper.guard(() async {
        final batch = _firestore.batch()
          ..delete(
            _firestore.doc('${FirestorePaths.userFriends(uid)}/$otherUid'),
          )
          ..delete(
            _firestore.doc('${FirestorePaths.userFriends(otherUid)}/$uid'),
          );
        await batch.commit();
      });

  // --- challenges --------------------------------------------------------

  Stream<List<Challenge>> watchChallenges(String uid) => _firestore
          .collection(FirestorePaths.challenges)
          .where('createdBy', isEqualTo: uid)
          .snapshots()
          .asyncMap((mine) async {
        // Two queries because Firestore has no OR across fields; the union is
        // still bounded and indexed, unlike scanning the collection.
        final theirs = await _firestore
            .collection(FirestorePaths.challenges)
            .where('opponentId', isEqualTo: uid)
            .get();

        return [...mine.docs, ...theirs.docs]
            .map((doc) => Challenge.fromJson(doc.id, doc.data()))
            .whereType<Challenge>()
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      });

  Future<Result<void>> createChallenge(Challenge challenge) =>
      ErrorMapper.guard(() async {
        await _firestore
            .doc(FirestorePaths.challenge(challenge.id))
            .set(challenge.toJson());
      });

  Future<Result<void>> respondToChallenge({
    required String challengeId,
    required bool accept,
  }) =>
      ErrorMapper.guard(() async {
        await _firestore.doc(FirestorePaths.challenge(challengeId)).update({
          'status': accept
              ? ChallengeStatus.accepted.name
              : ChallengeStatus.declined.name,
        });
      });

  Future<Result<void>> submitToChallenge({
    required String challengeId,
    required ChallengeSubmission submission,
  }) =>
      ErrorMapper.guard(() async {
        await _firestore
            .doc('${FirestorePaths.challenge(challengeId)}'
                '/${FirestorePaths.submissions}/${submission.uid}')
            .set(submission.toJson());
      });

  /// The other participant's entry, if it may be seen.
  ///
  /// The rules enforce this too; checking here as well means the UI does not
  /// have to render a permission error to say "not yet".
  Future<Result<ChallengeSubmission?>> opponentSubmission({
    required Challenge challenge,
    required String uid,
  }) =>
      ErrorMapper.guard(() async {
        if (!challenge.hasSubmitted(uid)) return null;

        final otherUid = challenge.otherParticipant(uid);
        final doc = await _firestore
            .doc('${FirestorePaths.challenge(challenge.id)}'
                '/${FirestorePaths.submissions}/$otherUid')
            .get();

        return ChallengeSubmission.fromJson(otherUid, doc.data());
      });

  /// Applies a queued social write.
  Future<void> applyMutation(PendingMutation mutation) async {
    await _firestore.doc(mutation.path).set(
      {
        ...mutation.payload,
        'createdAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}

final communityRepositoryProvider = Provider<CommunityRepository>((ref) {
  final repo = CommunityRepository(outbox: ref.watch(outboxProvider));
  ref.watch(outboxProvider).registerHandler(
        MutationKind.socialAction,
        repo.applyMutation,
      );
  return repo;
});
