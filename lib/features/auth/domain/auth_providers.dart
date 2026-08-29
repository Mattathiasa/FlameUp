import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';
import 'auth_user.dart';

/// Where the user stands with respect to having an identity.
///
/// [unknown] matters: on a cold start Firebase has not yet restored the
/// persisted session, and routing on that gap would bounce a signed-in user
/// through the welcome screen.
enum AuthStatus { unknown, signedOut, guest, signedIn }

/// The live user, or null.
final authUserProvider = StreamProvider<AuthUser?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

final authStatusProvider = Provider<AuthStatus>((ref) {
  return ref.watch(authUserProvider).when(
        loading: () => AuthStatus.unknown,
        error: (_, __) => AuthStatus.signedOut,
        data: (user) => switch (user) {
          null => AuthStatus.signedOut,
          final u when u.isGuest => AuthStatus.guest,
          _ => AuthStatus.signedIn,
        },
      );
});

/// True for guests and full accounts alike — anyone with a uid.
final isAuthenticatedProvider = Provider<bool>((ref) {
  final status = ref.watch(authStatusProvider);
  return status == AuthStatus.guest || status == AuthStatus.signedIn;
});

final currentUidProvider = Provider<String?>((ref) {
  return ref.watch(authUserProvider).valueOrNull?.uid;
});

/// Whether the signed-in user is still a guest.
///
/// Drives the "save your progress" prompt: a guest's work exists but is lost
/// with the app until the account is upgraded.
final isGuestProvider = Provider<bool>((ref) {
  return ref.watch(authStatusProvider) == AuthStatus.guest;
});

/// Whether to offer Apple sign-in on this device.
final appleSignInAvailableProvider = FutureProvider<bool>((ref) {
  return AuthRepository.isAppleAvailable;
});
