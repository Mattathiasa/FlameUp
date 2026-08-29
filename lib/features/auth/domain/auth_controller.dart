import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failure.dart';
import '../../../core/result/result.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/crash_reporter.dart';
import '../data/auth_repository.dart';
import 'auth_user.dart';

/// What an auth screen needs to render.
class AuthFormState {
  const AuthFormState({
    this.submitting = false,
    this.failure,
    this.succeeded = false,
  });

  final bool submitting;

  /// Set when the last attempt failed. Screens resolve the message key
  /// through `failureMessage`; the raw provider error never reaches them.
  final Failure? failure;

  /// Set on success, for one-shot navigation or a confirmation message.
  final bool succeeded;

  bool get hasError => failure != null;
}

/// Drives the sign-in, sign-up and upgrade forms.
///
/// Keeps submission state and failures out of the widgets, so a screen is a
/// pure function of this state.
class AuthController extends AutoDisposeNotifier<AuthFormState> {
  @override
  AuthFormState build() => const AuthFormState();

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  Future<bool> signIn({required String email, required String password}) =>
      _run(() => _repo.signInWithEmail(email: email, password: password));

  Future<bool> signUp({
    required String email,
    required String password,
    required String displayName,
  }) =>
      _run(
        () => _repo.signUpWithEmail(
          email: email,
          password: password,
          displayName: displayName,
        ),
        event: AnalyticsService.appOpen,
      );

  Future<bool> continueAsGuest() => _run(_repo.signInAsGuest);

  Future<bool> signInWithGoogle() => _run(_repo.signInWithGoogle);

  Future<bool> signInWithApple() => _run(_repo.signInWithApple);

  /// Convert the current guest into a permanent account, keeping the uid and
  /// therefore every document already written under it.
  Future<bool> upgradeGuest({
    required SignInMethod method,
    String? email,
    String? password,
    String? displayName,
  }) =>
      _run(
        () => _repo.upgradeGuest(
          method: method,
          email: email,
          password: password,
          displayName: displayName,
        ),
      );

  Future<bool> sendPasswordReset(String email) =>
      _run(() => _repo.sendPasswordReset(email));

  Future<void> signOut() async {
    await _repo.signOut();
    state = const AuthFormState();
  }

  void clearError() {
    if (state.hasError) state = AuthFormState(submitting: state.submitting);
  }

  /// Runs an operation, mapping its [Result] into form state.
  ///
  /// A cancelled sign-in resets quietly: backing out of the Google or Apple
  /// sheet is a decision, not an error to be shown.
  Future<bool> _run<T>(
    Future<Result<T>> Function() operation, {
    String? event,
  }) async {
    state = const AuthFormState(submitting: true);

    final result = await operation();
    final failure = result.failureOrNull;

    if (failure == null) {
      state = const AuthFormState(succeeded: true);
      if (event != null) {
        await ref.read(analyticsServiceProvider).log(event);
      }
      return true;
    }

    if (failure is CancelledFailure) {
      state = const AuthFormState();
      return false;
    }

    await ref.read(crashReporterProvider).recordFailure(failure);
    state = AuthFormState(failure: failure);
    return false;
  }
}

final authControllerProvider =
    AutoDisposeNotifierProvider<AuthController, AuthFormState>(
  AuthController.new,
);
