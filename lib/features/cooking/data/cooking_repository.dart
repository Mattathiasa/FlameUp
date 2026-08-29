import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/outbox.dart';
import '../../../core/cache/pending_mutation.dart';
import '../../../core/constants/firestore_paths.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/result/result.dart';
import '../../../core/services/local_store.dart';
import '../domain/cooking_session.dart';

/// Stores cooking sessions locally first.
///
/// Cooking is the case that must work with no connection at all: someone in a
/// kitchen with no signal still needs their steps and their timers. Every
/// write lands on disk immediately and is queued for the server, never the
/// other way round.
class CookingRepository {
  CookingRepository({
    required LocalStore store,
    required Outbox outbox,
    FirebaseFirestore? firestore,
  })  : _store = store,
        _outbox = outbox,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final LocalStore _store;
  final Outbox _outbox;
  final FirebaseFirestore _firestore;

  static const String _box = LocalStore.boxSessions;

  /// The session currently being cooked, if any.
  ///
  /// Read on launch so the app can offer to resume rather than losing a cook
  /// that was halfway through when the process died.
  CookingSession? activeSession() {
    final id = _store.getString(PrefKeys.activeSessionId);
    if (id == null) return null;

    final session = CookingSession.fromJson(_store.readJson(_box, id));
    if (session == null || !session.isActive) return null;
    return session;
  }

  CookingSession? byId(String id) =>
      CookingSession.fromJson(_store.readJson(_box, id));

  /// All sessions held on this device, newest first — the cooking history.
  List<CookingSession> allLocal() {
    final sessions = <CookingSession>[];
    for (final key in _store.keys(_box)) {
      final session = CookingSession.fromJson(_store.readJson(_box, key));
      if (session != null) sessions.add(session);
    }
    sessions.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return sessions;
  }

  /// Persist a session locally and mark it active.
  ///
  /// Deliberately synchronous-feeling: the disk write is awaited but the
  /// server write is queued, so advancing a step never waits on a network.
  Future<void> save(CookingSession session, {required String uid}) async {
    await _store.writeJson(_box, session.id, session.toJson());

    if (session.isActive) {
      await _store.setString(PrefKeys.activeSessionId, session.id);
    } else {
      await _store.remove(PrefKeys.activeSessionId);
    }

    await _outbox.enqueue(
      PendingMutation(
        kind: MutationKind.cookingSession,
        path: '${FirestorePaths.userCookingSessions(uid)}/${session.id}',
        payload: session.toJson(),
        // The session's own key, so every write for this cook -- including the
        // completion that awards XP -- is deduplicated server-side.
        idempotencyKey: '${session.idempotencyKey}.${session.currentStep}'
            '.${session.status.name}',
      ),
    );
  }

  /// Mark a session complete and queue the reward claim.
  ///
  /// XP is not applied here. The client is not trusted with progression: this
  /// records what happened and the server decides what it is worth. See
  /// docs/FIREBASE_SETUP.md for the Blaze requirement on that function.
  Future<Result<CookingSession>> complete(
    CookingSession session, {
    required String uid,
  }) =>
      ErrorMapper.guard(() async {
        final completed = session.copyWith(
          status: SessionStatus.completed,
          completedAt: DateTime.now(),
          currentStep: session.totalSteps - 1,
        );

        await save(completed, uid: uid);
        return completed;
      });

  Future<Result<CookingSession>> abandon(
    CookingSession session, {
    required String uid,
  }) =>
      ErrorMapper.guard(() async {
        final abandoned = session.copyWith(status: SessionStatus.abandoned);
        await save(abandoned, uid: uid);
        return abandoned;
      });

  /// Applies a queued session write. Registered with the outbox at startup.
  Future<void> applyMutation(PendingMutation mutation) async {
    await _firestore.doc(mutation.path).set(
      {
        ...mutation.payload,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}

final cookingRepositoryProvider = Provider<CookingRepository>((ref) {
  final repo = CookingRepository(
    store: ref.watch(localStoreProvider),
    outbox: ref.watch(outboxProvider),
  );
  ref.watch(outboxProvider).registerHandler(
        MutationKind.cookingSession,
        repo.applyMutation,
      );
  return repo;
});
