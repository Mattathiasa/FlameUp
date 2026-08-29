import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/errors/failure.dart';
import '../../../core/result/result.dart';
import '../domain/auth_user.dart';

/// All authentication, behind one interface.
///
/// Every method returns a [Result] carrying a [Failure] with a localisation
/// key, so a `FirebaseAuthException` code never reaches a widget.
class AuthRepository {
  AuthRepository({
    FirebaseAuth? auth,
    GoogleSignIn? google,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _google = google ?? GoogleSignIn(scopes: const ['email']);

  final FirebaseAuth _auth;
  final GoogleSignIn _google;

  Stream<AuthUser?> authStateChanges() => _auth.authStateChanges().map(
        (user) => user == null ? null : AuthUser.fromFirebase(user),
      );

  AuthUser? get currentUser {
    final user = _auth.currentUser;
    return user == null ? null : AuthUser.fromFirebase(user);
  }

  // --- email and password ------------------------------------------------

  Future<Result<AuthUser>> signInWithEmail({
    required String email,
    required String password,
  }) =>
      ErrorMapper.guard(() async {
        final credential = await _auth.signInWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
        return AuthUser.fromFirebase(credential.user!);
      });

  Future<Result<AuthUser>> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) =>
      ErrorMapper.guard(() async {
        final credential = await _auth.createUserWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
        await credential.user!.updateDisplayName(displayName.trim());
        await credential.user!.reload();
        return AuthUser.fromFirebase(_auth.currentUser!);
      });

  Future<Result<void>> sendPasswordReset(String email) => ErrorMapper.guard(
        () => _auth.sendPasswordResetEmail(email: email.trim()),
      );

  // --- guest -------------------------------------------------------------

  /// Sign in anonymously.
  ///
  /// A guest is a real account with a real uid: progress, mastery, saved
  /// recipes and family recipes all attach to it, and [upgradeGuest] later
  /// converts it in place without losing any of that.
  Future<Result<AuthUser>> signInAsGuest() => ErrorMapper.guard(() async {
        final credential = await _auth.signInAnonymously();
        return AuthUser.fromFirebase(credential.user!);
      });

  // --- federated ---------------------------------------------------------

  Future<Result<AuthUser>> signInWithGoogle() => ErrorMapper.guard(() async {
        final credential = await _googleCredential();
        final result = await _auth.signInWithCredential(credential);
        return AuthUser.fromFirebase(result.user!);
      });

  Future<Result<AuthUser>> signInWithApple() => ErrorMapper.guard(() async {
        final (credential, _) = await _appleCredential();
        final result = await _auth.signInWithCredential(credential);
        return AuthUser.fromFirebase(result.user!);
      });

  // --- guest upgrade -----------------------------------------------------

  /// Turn the current guest into a permanent account **in place**.
  ///
  /// This is the single most important operation in the auth feature. It links
  /// a credential to the existing anonymous user, so the uid is unchanged and
  /// every document already written under it — XP, cooking history,
  /// achievements, mastery, saved recipes, family recipes — stays exactly where
  /// it is. Signing out and signing up instead would silently orphan all of it.
  Future<Result<AuthUser>> upgradeGuest({
    required SignInMethod method,
    String? email,
    String? password,
    String? displayName,
  }) =>
      ErrorMapper.guard(() async {
        final user = _auth.currentUser;
        if (user == null) {
          throw const AuthFailure(messageKey: 'authErrorSignedOut');
        }
        if (!user.isAnonymous) {
          throw const AuthFailure(messageKey: 'authErrorProviderAlreadyLinked');
        }

        final credential = switch (method) {
          SignInMethod.password => EmailAuthProvider.credential(
              email: email!.trim(),
              password: password!,
            ),
          SignInMethod.google => await _googleCredential(),
          SignInMethod.apple => (await _appleCredential()).$1,
          SignInMethod.guest =>
            throw const ValidationFailure(messageKey: 'errorInvalidRequest'),
        };

        final result = await user.linkWithCredential(credential);
        final linked = result.user!;

        final name = displayName?.trim();
        if (name != null && name.isNotEmpty) {
          await linked.updateDisplayName(name);
          await linked.reload();
        }
        return AuthUser.fromFirebase(_auth.currentUser!);
      });

  // --- session -----------------------------------------------------------

  Future<Result<void>> signOut() => ErrorMapper.guard(() async {
        // Google keeps its own session; without clearing it the next sign-in
        // silently reuses the previous account instead of offering the
        // chooser. But it must never block the Firebase sign-out: if tearing
        // down the Google session fails -- no session, no Play Services, an
        // offline device -- the user has still asked to be signed out, and
        // leaving them signed in would be the worse failure by far.
        try {
          await _google.signOut();
        } catch (error) {
          debugPrint('[auth] Google session teardown failed: $error');
        }
        await _auth.signOut();
      });

  /// Delete the account. Firestore data is removed by a Cloud Function trigger
  /// so it happens even if the app is killed mid-delete.
  Future<Result<void>> deleteAccount() => ErrorMapper.guard(() async {
        final user = _auth.currentUser;
        if (user == null) {
          throw const AuthFailure(messageKey: 'authErrorSignedOut');
        }
        await user.delete();
      });

  Future<Result<void>> sendEmailVerification() => ErrorMapper.guard(() async {
        await _auth.currentUser?.sendEmailVerification();
      });

  Future<Result<void>> reload() => ErrorMapper.guard(() async {
        await _auth.currentUser?.reload();
      });

  // --- provider credentials ----------------------------------------------

  Future<OAuthCredential> _googleCredential() async {
    final account = await _google.signIn();
    if (account == null) {
      // Backing out of the chooser is not an error worth reporting.
      throw const CancelledFailure();
    }
    final auth = await account.authentication;
    return GoogleAuthProvider.credential(
      accessToken: auth.accessToken,
      idToken: auth.idToken,
    );
  }

  /// Apple requires a nonce: a random string sent hashed, then echoed raw so
  /// Firebase can verify the token was minted for this request.
  Future<(OAuthCredential, String)> _appleCredential() async {
    final rawNonce = _randomNonce();
    final AuthorizationCredentialAppleID apple;
    try {
      apple = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: sha256.convert(utf8.encode(rawNonce)).toString(),
      );
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code == AuthorizationErrorCode.canceled) {
        throw const CancelledFailure();
      }
      rethrow;
    }

    return (
      OAuthProvider('apple.com').credential(
        idToken: apple.identityToken,
        rawNonce: rawNonce,
      ),
      // Apple sends the name only on the very first authorisation, so callers
      // must persist it now or lose it.
      [apple.givenName, apple.familyName].whereType<String>().join(' ').trim(),
    );
  }

  static String _randomNonce([int length = 32]) {
    const chars =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
  }

  /// Apple sign-in is only offered where it exists.
  static Future<bool> get isAppleAvailable async {
    if (defaultTargetPlatform == TargetPlatform.iOS) return true;
    return SignInWithApple.isAvailable();
  }
}

final authRepositoryProvider =
    Provider<AuthRepository>((ref) => AuthRepository());
