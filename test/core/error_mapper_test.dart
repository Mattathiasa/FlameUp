import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flameup/core/errors/error_mapper.dart';
import 'package:flameup/core/errors/failure.dart';
import 'package:flameup/core/result/result.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ErrorMapper.map — Firebase Auth', () {
    test('maps known codes to specific copy keys', () {
      final failure = ErrorMapper.map(
        FirebaseAuthException(code: 'email-already-in-use'),
      );

      expect(failure, isA<AuthFailure>());
      expect(failure.messageKey, 'authErrorEmailInUse');
      expect((failure as AuthFailure).code, 'email-already-in-use');
    });

    test('collapses both bad-credential codes onto one message', () {
      // Telling an attacker which half was wrong is a disclosure, so
      // wrong-password and user-not-found must read identically.
      final wrongPassword =
          ErrorMapper.map(FirebaseAuthException(code: 'wrong-password'));
      final noSuchUser =
          ErrorMapper.map(FirebaseAuthException(code: 'user-not-found'));

      expect(wrongPassword.messageKey, 'authErrorInvalidCredentials');
      expect(noSuchUser.messageKey, wrongPassword.messageKey);
    });

    test('falls back to generic copy for an unknown code', () {
      final failure =
          ErrorMapper.map(FirebaseAuthException(code: 'something-new'));

      expect(failure.messageKey, 'authErrorGeneric');
    });

    test('treats a failed auth network request as being offline', () {
      final failure = ErrorMapper.map(
        FirebaseAuthException(code: 'network-request-failed'),
      );

      expect(failure, isA<NetworkFailure>());
      expect(failure.isRetryable, isTrue);
    });
  });

  group('ErrorMapper.map — Firebase core exceptions', () {
    Failure mapCode(String code) => ErrorMapper.map(
          FirebaseException(plugin: 'cloud_firestore', code: code),
        );

    test('permission-denied becomes a PermissionFailure', () {
      expect(mapCode('permission-denied'), isA<PermissionFailure>());
    });

    test('not-found becomes a NotFoundFailure', () {
      expect(mapCode('not-found'), isA<NotFoundFailure>());
      expect(mapCode('object-not-found'), isA<NotFoundFailure>());
    });

    test('unavailable becomes a retryable NetworkFailure', () {
      final failure = mapCode('unavailable');
      expect(failure, isA<NetworkFailure>());
      expect(failure.isRetryable, isTrue);
    });

    test('an unrecognised code keeps its code on a ServerFailure', () {
      final failure = mapCode('internal');
      expect(failure, isA<ServerFailure>());
      expect((failure as ServerFailure).code, 'internal');
    });
  });

  group('ErrorMapper.map — platform and IO', () {
    test('a socket error is a network failure', () {
      expect(
        ErrorMapper.map(const SocketException('no route')),
        isA<NetworkFailure>(),
      );
    });

    test('a timeout gets its own copy key', () {
      final failure = ErrorMapper.map(TimeoutException('slow'));
      expect(failure, isA<NetworkFailure>());
      expect(failure.messageKey, 'errorTimeout');
    });

    test('a malformed payload is a server failure', () {
      final failure = ErrorMapper.map(const FormatException('bad json'));
      expect(failure, isA<ServerFailure>());
      expect(failure.messageKey, 'errorBadResponse');
    });

    test('a PlatformException keeps its code', () {
      final failure =
          ErrorMapper.map(PlatformException(code: 'sign_in_failed'));
      expect((failure as ServerFailure).code, 'sign_in_failed');
    });

    test('anything else is an UnknownFailure that keeps the cause', () {
      final cause = StateError('boom');
      final failure = ErrorMapper.map(cause);

      expect(failure, isA<UnknownFailure>());
      expect(failure.cause, same(cause));
    });

    test('an existing Failure passes through unchanged', () {
      const original = PermissionFailure();
      expect(ErrorMapper.map(original), same(original));
    });
  });

  group('ErrorMapper.guard', () {
    test('wraps a value in Ok', () async {
      final result = await ErrorMapper.guard(() async => 42);
      expect(result.valueOrNull, 42);
    });

    test('converts a thrown error into a mapped Err', () async {
      final result = await ErrorMapper.guard<int>(
        () async => throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
        ),
      );

      expect(result, isA<Err<int>>());
      expect(result.failureOrNull, isA<PermissionFailure>());
    });

    test('guardSync does the same for synchronous work', () {
      final result = ErrorMapper.guardSync<int>(
        () => throw const FormatException('bad'),
      );

      expect(result.failureOrNull, isA<ServerFailure>());
    });
  });
}
