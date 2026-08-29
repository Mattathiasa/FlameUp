import 'dart:async';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
// firebase_auth re-exports FirebaseException from firebase_core, which is
// what the generic Firestore/Storage branch below matches on.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

import '../result/result.dart';
import 'failure.dart';

/// Translates provider-specific errors into [Failure]s.
///
/// Every repository funnels through [guard] so no `FirebaseException` code ever
/// reaches a widget, and so the retryable/non-retryable distinction is decided
/// in exactly one place.
abstract final class ErrorMapper {
  /// Firebase Auth codes we have specific, human copy for. Anything else falls
  /// through to a generic auth message rather than showing the raw code.
  static const Map<String, String> _authMessageKeys = {
    'invalid-email': 'authErrorInvalidEmail',
    'user-disabled': 'authErrorUserDisabled',
    'user-not-found': 'authErrorInvalidCredentials',
    'wrong-password': 'authErrorInvalidCredentials',
    'invalid-credential': 'authErrorInvalidCredentials',
    'email-already-in-use': 'authErrorEmailInUse',
    'weak-password': 'authErrorWeakPassword',
    'operation-not-allowed': 'authErrorOperationNotAllowed',
    'requires-recent-login': 'authErrorRequiresRecentLogin',
    'too-many-requests': 'authErrorTooManyRequests',
    'account-exists-with-different-credential':
        'authErrorAccountExistsDifferentCredential',
    'credential-already-in-use': 'authErrorCredentialInUse',
    'provider-already-linked': 'authErrorProviderAlreadyLinked',
    'network-request-failed': 'errorOffline',
  };

  static Failure map(Object error, [StackTrace? stackTrace]) {
    if (error is Failure) return error;

    if (error is FirebaseAuthException) {
      if (error.code == 'network-request-failed') {
        return NetworkFailure(cause: error, stackTrace: stackTrace);
      }
      return AuthFailure(
        messageKey: _authMessageKeys[error.code] ?? 'authErrorGeneric',
        code: error.code,
        cause: error,
        stackTrace: stackTrace,
      );
    }

    if (error is FirebaseFunctionsException) {
      return switch (error.code) {
        'unauthenticated' => AuthFailure(
            messageKey: 'authErrorSignedOut',
            cause: error,
            stackTrace: stackTrace,
          ),
        'permission-denied' =>
          PermissionFailure(cause: error, stackTrace: stackTrace),
        'not-found' => NotFoundFailure(cause: error, stackTrace: stackTrace),
        'invalid-argument' || 'failed-precondition' => ValidationFailure(
            messageKey: 'errorInvalidRequest',
            cause: error,
            stackTrace: stackTrace,
          ),
        'unavailable' ||
        'deadline-exceeded' =>
          NetworkFailure(cause: error, stackTrace: stackTrace),
        'cancelled' => CancelledFailure(cause: error, stackTrace: stackTrace),
        _ =>
          ServerFailure(code: error.code, cause: error, stackTrace: stackTrace),
      };
    }

    if (error is FirebaseException) {
      return switch (error.code) {
        'permission-denied' ||
        'unauthorized' =>
          PermissionFailure(cause: error, stackTrace: stackTrace),
        'not-found' ||
        'object-not-found' =>
          NotFoundFailure(cause: error, stackTrace: stackTrace),
        'unavailable' ||
        'deadline-exceeded' ||
        'retry-limit-exceeded' =>
          NetworkFailure(cause: error, stackTrace: stackTrace),
        'cancelled' ||
        'canceled' =>
          CancelledFailure(cause: error, stackTrace: stackTrace),
        'aborted' || 'already-exists' => ValidationFailure(
            messageKey: 'errorConflict',
            cause: error,
            stackTrace: stackTrace,
          ),
        _ =>
          ServerFailure(code: error.code, cause: error, stackTrace: stackTrace),
      };
    }

    if (error is SocketException || error is HttpException) {
      return NetworkFailure(cause: error, stackTrace: stackTrace);
    }
    if (error is TimeoutException) {
      return NetworkFailure(
        messageKey: 'errorTimeout',
        cause: error,
        stackTrace: stackTrace,
      );
    }
    if (error is FormatException) {
      return ServerFailure(
        messageKey: 'errorBadResponse',
        cause: error,
        stackTrace: stackTrace,
      );
    }
    if (error is PlatformException) {
      return ServerFailure(
        code: error.code,
        cause: error,
        stackTrace: stackTrace,
      );
    }

    return UnknownFailure(cause: error, stackTrace: stackTrace);
  }

  /// Run [action], returning [Ok] or a mapped [Err]. The one wrapper every
  /// repository method uses.
  static Future<Result<T>> guard<T>(Future<T> Function() action) async {
    try {
      return Ok(await action());
    } catch (error, stackTrace) {
      return Err(map(error, stackTrace));
    }
  }

  /// Synchronous counterpart, for cache and pure-computation boundaries.
  static Result<T> guardSync<T>(T Function() action) {
    try {
      return Ok(action());
    } catch (error, stackTrace) {
      return Err(map(error, stackTrace));
    }
  }
}
