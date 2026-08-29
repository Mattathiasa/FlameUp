import 'package:firebase_auth/firebase_auth.dart' as fb;

/// How someone signed in.
///
/// Named [SignInMethod] rather than `AuthProvider` because firebase_auth
/// exports a type of that name, and an ambiguous import at every call site is
/// not worth the tidier word.
enum SignInMethod {
  password,
  google,
  apple,
  guest;

  static SignInMethod fromProviderId(String id) => switch (id) {
        'password' => SignInMethod.password,
        'google.com' => SignInMethod.google,
        'apple.com' => SignInMethod.apple,
        _ => SignInMethod.guest,
      };
}

/// The app's own view of the signed-in user.
///
/// Wrapping [fb.User] keeps `firebase_auth` out of the widget layer and makes
/// the guest/permanent distinction explicit rather than something every caller
/// re-derives from `isAnonymous`.
class AuthUser {
  const AuthUser({
    required this.uid,
    required this.isGuest,
    required this.methods,
    this.email,
    this.displayName,
    this.photoUrl,
    this.emailVerified = false,
  });

  factory AuthUser.fromFirebase(fb.User user) => AuthUser(
        uid: user.uid,
        isGuest: user.isAnonymous,
        email: user.email,
        displayName: user.displayName,
        photoUrl: user.photoURL,
        emailVerified: user.emailVerified,
        methods: user.providerData
            .map((info) => SignInMethod.fromProviderId(info.providerId))
            .toList(growable: false),
      );

  final String uid;

  /// Anonymous. Has a uid and full progress, but no credentials — so the
  /// account is lost if the app is uninstalled until it is upgraded.
  final bool isGuest;

  final String? email;
  final String? displayName;
  final String? photoUrl;
  final bool emailVerified;
  final List<SignInMethod> methods;

  /// Whether this account can be recovered on another device.
  bool get isPermanent => !isGuest;

  /// What to greet them with before a profile exists.
  String get shortName {
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) return name.split(' ').first;
    final address = email;
    if (address != null && address.contains('@')) {
      return address.split('@').first;
    }
    return '';
  }
}
