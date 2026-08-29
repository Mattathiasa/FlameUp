import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/local_store.dart';
import '../../auth/domain/auth_providers.dart';
import '../data/onboarding_repository.dart';
import 'onboarding_state.dart';

/// Whether onboarding has been completed on this device.
///
/// Held locally so routing can decide before any network read; the answers are
/// also mirrored to `users/{uid}` and reconciled on sign-in, so a reinstall
/// does not ask the same questions twice.
class OnboardingStatus extends Notifier<bool> {
  @override
  bool build() =>
      ref.watch(localStoreProvider).getBool(PrefKeys.onboardingComplete);

  Future<void> markComplete() async {
    await ref
        .read(localStoreProvider)
        .setBool(PrefKeys.onboardingComplete, value: true);
    state = true;
  }

  /// Used when a different account signs in on a device that had already
  /// onboarded someone else.
  Future<void> reset() async {
    await ref
        .read(localStoreProvider)
        .setBool(PrefKeys.onboardingComplete, value: false);
    state = false;
  }
}

final onboardingStatusProvider =
    NotifierProvider<OnboardingStatus, bool>(OnboardingStatus.new);

/// Drives the onboarding flow.
///
/// Every answer is written to disk as it is given, so closing the app halfway
/// through resumes rather than restarts.
class OnboardingController extends Notifier<OnboardingAnswers> {
  @override
  OnboardingAnswers build() =>
      ref.watch(onboardingRepositoryProvider).readLocal();

  OnboardingRepository get _repo => ref.read(onboardingRepositoryProvider);

  Future<void> setSkill(SkillLevel skill) async {
    state = state.copyWith(skill: skill);
    await _repo.saveLocal(state);
  }

  Future<void> setHeat(HeatTolerance heat) async {
    state = state.copyWith(heat: heat);
    await _repo.saveLocal(state);
  }

  Future<void> toggleDietary(DietaryFlag flag) async {
    final next = Set<DietaryFlag>.from(state.dietary);
    next.contains(flag) ? next.remove(flag) : next.add(flag);
    state = state.copyWith(dietary: next);
    await _repo.saveLocal(state);
  }

  /// Finish. Returns false only if there is no signed-in user, which the
  /// router prevents from happening.
  Future<bool> complete() async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) return false;

    final result = await _repo.complete(uid: uid, answers: state);
    if (result.isErr) return false;

    state = state.copyWith(completed: true);
    await ref.read(onboardingStatusProvider.notifier).markComplete();
    return true;
  }

  /// Skip the optional steps. The defaults are deliberately reasonable —
  /// beginner pace, medium heat, no restrictions — so skipping still produces
  /// a usable profile rather than an empty one.
  Future<bool> skip() => complete();
}

final onboardingControllerProvider =
    NotifierProvider<OnboardingController, OnboardingAnswers>(
  OnboardingController.new,
);
