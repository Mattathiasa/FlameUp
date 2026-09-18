import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/cache/outbox.dart';
import '../../../core/cache/pending_mutation.dart';
import '../../../core/constants/firestore_paths.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/errors/failure.dart';
import '../../../core/result/result.dart';
import '../../../core/services/cloudinary_service.dart';
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
  })  : _outbox = outbox,
        _firestore = firestore;

  final Outbox _outbox;

  /// Resolved lazily: constructing the repository must not require Firebase
  /// to be initialised — the outbox registration happens at startup, and a
  /// test (or a fully offline moment) only ever touches the local store.
  FirebaseFirestore? _firestore;

  FirebaseFirestore get _fs => _firestore ??= FirebaseFirestore.instance;

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
    await _fs.doc(mutation.path).set(
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
        () => _fs.doc(FirestorePaths.familyRecipe(recipeId)).delete(),
      );

  // --- reads --------------------------------------------------------------

  /// The signed-in author's own submissions, any status, newest first.
  ///
  /// Live on purpose: the moment a moderator publishes, the card flips from
  /// "in review" to "in the archive" without a refresh.
  Stream<List<FamilyRecipe>> watchMine(String uid) => _fs
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
  Stream<List<FamilyRecipe>> watchPublished({int limit = 50}) => _fs
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

  /// Submissions in community review, newest first — the queue behind the
  /// review section on Grandma's Kitchen. Any signed-in user reads pending
  /// recipes (the rules say so); vouching happens on the detail screen.
  Stream<List<FamilyRecipe>> watchPending({int limit = 20}) => _fs
      .collection(FirestorePaths.familyRecipes)
      .where('status', isEqualTo: FamilyRecipeStatus.pending.name)
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map((doc) => FamilyRecipe.fromJson(doc.id, doc.data()))
            .whereType<FamilyRecipe>()
            .toList(),
      );

  /// The published variants whose [baseId] is the given recipe, newest first.
  ///
  /// A base can live in either world — the archive's own ids, or a catalogue
  /// `recipes/{slug}` id — but both are plain equality filters against this
  /// one collection, so one query shape serves them both. [catalogueBase]
  /// exists only to keep the two call sites self-documenting.
  Stream<List<FamilyRecipe>> watchVariants(
    String baseId, {
    required bool catalogueBase,
  }) =>
      _fs
          .collection(FirestorePaths.familyRecipes)
          .where('baseId', isEqualTo: baseId)
          .where('status', isEqualTo: FamilyRecipeStatus.published.name)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs
                .map((doc) => FamilyRecipe.fromJson(doc.id, doc.data()))
                .whereType<FamilyRecipe>()
                .toList(),
          );

  /// One family recipe by id, live. Null once deleted — the detail view
  /// treats that as "gone", not as an error.
  Stream<FamilyRecipe?> watchOne(String recipeId) => _fs
      .doc(FirestorePaths.familyRecipe(recipeId))
      .snapshots()
      .map((snapshot) => FamilyRecipe.fromJson(snapshot.id, snapshot.data()));

  // --- community verification ---------------------------------------------

  /// The number of independent vouches a recipe needs to publish itself.
  /// Deliberately small: the archive is young, and a threshold no submission
  /// ever reaches is a gate, not a community.
  static const int publishThreshold = 3;

  /// Record that the signed-in cook vouches for this recipe: they have made
  /// it themselves and can say it works.
  ///
  /// One transaction, two writes: the append-only vouch on the recipe, and —
  /// same commit — the notification into the author's collection, so a
  /// vouch and the "someone cooked your recipe" note can never drift apart.
  /// The rules re-verify everything server-side: the append shape, the
  /// threshold, the author exclusion, and the notification's shape and its
  /// deterministic id.
  ///
  /// [vouchingName] is the vouching cook's display name for the
  /// notification; the caller resolves it from the profile.
  Future<Result<void>> verify({
    required String recipeId,
    required String uid,
    required String vouchingName,
  }) =>
      ErrorMapper.guard(() async {
        final docRef = _fs.doc(FirestorePaths.familyRecipe(recipeId));

        try {
          await _fs.runTransaction((tx) async {
            final snapshot = await tx.get(docRef);
            if (!snapshot.exists) {
              throw const NotFoundFailure();
            }
            final authorId = snapshot.data()!['authorId'] as String? ?? '';
            final verified = [
              for (final v
                  in (snapshot.data()!['verifiedBy'] as List? ?? const []))
                if (v is String) v,
            ];
            if (verified.contains(uid)) {
              throw const ValidationFailure(
                messageKey: 'verifyAlready',
              );
            }
            verified.add(uid);
            final publishes = verified.length >= publishThreshold;
            tx.update(docRef, {
              'verifiedBy': verified,
              if (publishes) 'status': FamilyRecipeStatus.published.name,
            });

            // The author's note, written in the same commit. The id is
            // deterministic (vouch_{recipeId}_{vouchingUid}) so a retried
            // transaction overwrites the same slot instead of stacking
            // copies — and the rules re-check the vouch is real before
            // letting it land. recipeId rides in the payload: the rules
            // verify the id by concatenation, never by splitting, so ids
            // with underscores work.
            tx.set(
              _fs.doc(
                '${FirestorePaths.userNotifications(authorId)}'
                '/vouch_${recipeId}_$uid',
              ),
              {
                'type': publishes ? 'recipeVerified' : 'recipeVouched',
                'recipeId': recipeId,
                // For vouched notes the count rides in otherUid's slot —
                // the row model's only spare string field.
                'otherUid': '${verified.length}',
                'otherName': vouchingName,
                'count': verified.length,
                'createdAt': FieldValue.serverTimestamp(),
                'readAt': null,
              },
            );
          });
        } on FirebaseException catch (error) {
          // The rules rejected the update — re-map as a permission failure so
          // the UI can say "you cannot vouch for your own" rather than a
          // generic server error.
          if (error.code == 'permission-denied') {
            throw const PermissionFailure();
          }
          rethrow;
        }
      });

  // --- media --------------------------------------------------------------

  /// Upload a photo or clip of the dish, returning its delivery URL.
  ///
  /// Cloudinary carries all family-recipe media — the project keeps no
  /// Firebase Storage bucket at all, so [file] goes to the unsigned preset
  /// tagged with the author's uid. The extension is validated upstream in
  /// [CloudinaryService.uploadMedia]; here only the hand-off happens.
  Future<Result<String>> uploadMedia({
    required String uid,
    required File file,
  }) =>
      _cloudinary.uploadMedia(file: file, uid: uid);

  /// Injectable so tests can stub uploads without any network.
  CloudinaryService _cloudinary = const CloudinaryService();

  set cloudinary(CloudinaryService value) => _cloudinary = value;
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
