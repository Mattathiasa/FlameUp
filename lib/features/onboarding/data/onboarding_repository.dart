import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/outbox.dart';
import '../../../core/cache/pending_mutation.dart';
import '../../../core/constants/firestore_paths.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/result/result.dart';
import '../../../core/services/local_store.dart';
import '../domain/onboarding_state.dart';

/// Persists onboarding answers locally first, then to the user document.
///
/// Local-first because onboarding must work with no connection: someone who
/// installs the app on a bad signal should still reach the kitchen. The write
/// to Firestore goes through the outbox, so it lands whenever the device next
/// has a network without the user ever waiting on it.
class OnboardingRepository {
  OnboardingRepository({
    required LocalStore store,
    required Outbox outbox,
    FirebaseFirestore? firestore,
  })  : _store = store,
        _outbox = outbox,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final LocalStore _store;
  final Outbox _outbox;
  final FirebaseFirestore _firestore;

  static const String _cacheKey = 'onboarding.answers';

  /// The answers held on this device.
  OnboardingAnswers readLocal() => OnboardingAnswers.fromJson(
        _store.readJson(LocalStore.boxMisc, _cacheKey),
      );

  /// Save progress without finishing. Called on every answer so a mid-flow
  /// exit resumes rather than restarts.
  Future<void> saveLocal(OnboardingAnswers answers) =>
      _store.writeJson(LocalStore.boxMisc, _cacheKey, answers.toJson());

  /// Finish onboarding: mark it complete locally and queue the profile write.
  Future<Result<void>> complete({
    required String uid,
    required OnboardingAnswers answers,
  }) =>
      ErrorMapper.guard(() async {
        final finished = answers.copyWith(completed: true);
        await saveLocal(finished);
        await _store.setBool(PrefKeys.onboardingComplete, value: true);

        await _outbox.enqueue(
          PendingMutation(
            kind: MutationKind.userProfile,
            path: FirestorePaths.user(uid),
            payload: finished.toJson(),
          ),
        );
      });

  /// Reconcile with the server after sign-in.
  ///
  /// A returning user who reinstalled has answers on the server but not on the
  /// device; the server wins in that case, because the device has nothing.
  /// A device that answered offline keeps its own, because those answers are
  /// newer than anything the server holds.
  Future<Result<OnboardingAnswers>> syncFromServer(String uid) =>
      ErrorMapper.guard(() async {
        final local = readLocal();
        if (local.completed) return local;

        final snapshot = await _firestore.doc(FirestorePaths.user(uid)).get();
        if (!snapshot.exists) return local;

        final remote = OnboardingAnswers.fromJson(snapshot.data());
        if (!remote.completed) return local;

        await saveLocal(remote);
        await _store.setBool(PrefKeys.onboardingComplete, value: true);
        return remote;
      });

  /// Applies a queued profile write. Registered with the outbox at startup.
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

final onboardingRepositoryProvider = Provider<OnboardingRepository>((ref) {
  final repo = OnboardingRepository(
    store: ref.watch(localStoreProvider),
    outbox: ref.watch(outboxProvider),
  );
  // Registered here so a profile write queued offline drains on reconnect.
  ref.watch(outboxProvider).registerHandler(
        MutationKind.userProfile,
        repo.applyMutation,
      );
  return repo;
});
