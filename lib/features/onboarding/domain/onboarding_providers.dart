import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/local_store.dart';

/// Whether onboarding has been completed on this device.
///
/// Held locally so routing can decide before any network read. Phase 4 also
/// mirrors the answers to `users/{uid}` so they survive a reinstall, and
/// reconciles the two on sign-in.
class OnboardingStatus extends Notifier<bool> {
  @override
  bool build() {
    final store = ref.watch(localStoreProvider);
    return store.getBool(PrefKeys.onboardingComplete);
  }

  Future<void> markComplete() async {
    await ref.read(localStoreProvider).setBool(
          PrefKeys.onboardingComplete,
          value: true,
        );
    state = true;
  }

  /// Used when a fresh account signs in on a device that had already onboarded
  /// a different user.
  Future<void> reset() async {
    await ref.read(localStoreProvider).setBool(
          PrefKeys.onboardingComplete,
          value: false,
        );
    state = false;
  }
}

final onboardingStatusProvider =
    NotifierProvider<OnboardingStatus, bool>(OnboardingStatus.new);
