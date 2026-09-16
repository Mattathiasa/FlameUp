import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/cache/outbox.dart';
import '../../../core/cache/pending_mutation.dart';
import '../../../core/constants/firestore_paths.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/errors/failure.dart';
import '../../../core/result/result.dart';
import '../domain/family_recipe.dart';

/// Grandma's Kitchen data layer: submissions, my recipes, media.
///
/// Submissions go through the [Outbox] like every other offline-capable
/// write, so a recipe recorded at the family table with no signal still
/// reaches the archive. Reads use live snapshots -- status changes when a
/// moderator publishes, and the "my recipes" list should show it the moment
/// it happens.
class FamilyRecipeRepository {
  FamilyRecipeRepository({
    required Outbox outbox,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _outbox = outbox,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final Outbox _outbox;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  // --- submission ---------------------------------------------------------

  /// A stable id for a new submission, minted by the caller (the form) and
  /// persisted with the draft. Everything downstream -- the Firestore path,
  /// the outbox idempotency key, the eventual document -- derives from it, so
  /// a replayed drain merges into the same document instead of duplicating.
  static String newRecipeId() => const Uuid().v4();

  /// Queue a submission (or a later edit of a still-unpublished draft).
  ///
  /// [payload] must carry the [newRecipeId] under 'id'; the rules require the
  /// author to be the signer, which the form sets alongside.
  Future<Result<void>> submit({
    required Map<String, dynamic> payload,
  }) =>
      ErrorMapper.guard(() async {
        final id = payload['id'] as String?;
        if (id == null || id.isEmpty) {
          throw const ValidationFailure(
            messageKey: 'validationNameRequired',
            field: 'id',
          );
        }
        await _outbox.enqueue(
          PendingMutation(
            kind: MutationKind.familyRecipe,
            path: '${FirestorePaths.familyRecipes}/$id',
            payload: payload,
            // Same id, same key: a double tap overwrites this outbox slot
            // rather than queueing a second copy, and a replayed drain lands
            // on the same document.
            idempotencyKey: 'familyRecipe.$id',
          ),
        );
      });

  /// Applies a queued submission at drain time. Merge, so a re-run of the
  /// same content updates in place instead of duplicating.
  Future<void> applyMutation(PendingMutation mutation) async {
    await _firestore.doc(mutation.path).set(
      {
        ...mutation.payload,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  /// Remove one of your own submissions outright. Rules allow the author to
  /// delete; a published recipe needs a moderator, and the failure surfaces
  /// through the [Result].
  Future<Result<void>> delete({required String recipeId}) => ErrorMapper.guard(
        () => _firestore.doc(FirestorePaths.familyRecipe(recipeId)).delete(),
      );

  // --- reads --------------------------------------------------------------

  /// The signed-in author's own submissions, any status, newest first.
  ///
  /// Live on purpose: the moment a moderator publishes, the card flips from
  /// "in review" to "in the archive" without a refresh.
  Stream<List<FamilyRecipe>> watchMine(String uid) => _firestore
      .collection(FirestorePaths.familyRecipes)
      .where('authorId', isEqualTo: uid)
      .orderBy('updatedAt', descending: true)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map((doc) => FamilyRecipe.fromJson(doc.id, doc.data()))
            .whereType<FamilyRecipe>()
            .toList(),
      );

  /// Published recipes, newest first -- the public archive.
  Stream<List<FamilyRecipe>> watchPublished({int limit = 50}) => _firestore
      .collection(FirestorePaths.familyRecipes)
      .where('status', isEqualTo: FamilyRecipeStatus.published.name)
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map((doc) => FamilyRecipe.fromJson(doc.id, doc.data()))
            .whereType<FamilyRecipe>()
            .toList(),
      );

  // --- media --------------------------------------------------------------

  /// Upload a photo or video of the dish, returning its download URL.
  ///
  /// Files live under the author's own path -- the storage rules derive
  /// ownership from that path, so nothing else needs checking here. The id
  /// (uuid) prefixes the filename to keep re-uploads apart.
  Future<Result<String>> uploadMedia({
    required String uid,
    required File file,
  }) =>
      ErrorMapper.guard(() async {
        final extension = file.path.split('.').last.toLowerCase();
        final contentType = switch (extension) {
          'jpg' || 'jpeg' => 'image/jpeg',
          'png' => 'image/png',
          'webp' => 'image/webp',
          'gif' => 'image/gif',
          'heic' => 'image/heic',
          'mp4' => 'video/mp4',
          'mov' => 'video/quicktime',
          'm4v' => 'video/x-m4v',
          _ => throw const FormatException('unsupported_media_type'),
        };
        final ref = _storage.ref().child(
              'users/$uid/family_recipes/'
              '${const Uuid().v4()}.$extension',
            );
        await ref.putFile(file, SettableMetadata(contentType: contentType));
        return ref.getDownloadURL();
      });
}

final familyRecipeRepositoryProvider = Provider<FamilyRecipeRepository>((ref) {
  final repo = FamilyRecipeRepository(outbox: ref.watch(outboxProvider));
  // The registration that was missing: without this, every submission sat in
  // the outbox forever and the feature silently saved nothing.
  ref.watch(outboxProvider).registerHandler(
        MutationKind.familyRecipe,
        repo.applyMutation,
      );
  return repo;
});
