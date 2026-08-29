import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Where the user stands with respect to having an identity.
///
/// [unknown] matters: on a cold start Firebase has not yet restored the
/// persisted session, and routing on that gap would bounce a signed-in user
/// through the welcome screen.
enum AuthStatus { unknown, signedOut, guest, signedIn }

final firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instance,
);

/// The live Firebase user, or null. Seeded with the already-restored user so
/// the first frame does not flash [AuthStatus.unknown] unnecessarily.
final authUserProvider = StreamProvider<User?>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  return auth.authStateChanges();
});

final authStatusProvider = Provider<AuthStatus>((ref) {
  return ref.watch(authUserProvider).when(
        loading: () => AuthStatus.unknown,
        error: (_, __) => AuthStatus.signedOut,
        data: (user) => switch (user) {
          null => AuthStatus.signedOut,
          final u when u.isAnonymous => AuthStatus.guest,
          _ => AuthStatus.signedIn,
        },
      );
});

/// True for both guests and full accounts — anyone with a uid.
final isAuthenticatedProvider = Provider<bool>((ref) {
  final status = ref.watch(authStatusProvider);
  return status == AuthStatus.guest || status == AuthStatus.signedIn;
});

final currentUidProvider = Provider<String?>((ref) {
  return ref.watch(authUserProvider).valueOrNull?.uid;
});
