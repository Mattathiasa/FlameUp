import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/outbox.dart';
import '../../../core/cache/pending_mutation.dart';
import '../../../core/constants/firestore_paths.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/result/result.dart';
import '../domain/review.dart';

/// Submits reviews.
///
/// Queued through the outbox rather than written directly, so a rating left
/// on a phone with no signal is not lost — and carries the session's own
/// idempotency key, so replaying it cannot produce two reviews.
class ReviewRepository {
  ReviewRepository({required Outbox outbox, FirebaseFirestore? firestore})
      : _outbox = outbox,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final Outbox _outbox;
  final FirebaseFirestore _firestore;

  Future<Result<void>> submit(Review review) => ErrorMapper.guard(() async {
        await _outbox.enqueue(
          PendingMutation(
            kind: MutationKind.review,
            // The document id is the reviewer's uid, so one review per person
            // per recipe is structural rather than enforced by a query.
            path:
                '${FirestorePaths.recipeReviews(review.recipeId)}/${review.uid}',
            payload: review.toJson(),
            idempotencyKey: 'review.${review.sessionId}',
          ),
        );
      });

  /// Applies a queued review write. Registered with the outbox at startup.
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

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  final repo = ReviewRepository(outbox: ref.watch(outboxProvider));
  ref.watch(outboxProvider).registerHandler(
        MutationKind.review,
        repo.applyMutation,
      );
  return repo;
});
