import 'package:flameup/core/errors/failure.dart';
import 'package:flameup/core/result/result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Result', () {
    test('Ok carries its value and reports success', () {
      const result = Result<int>.ok(7);

      expect(result.isOk, isTrue);
      expect(result.isErr, isFalse);
      expect(result.valueOrNull, 7);
      expect(result.failureOrNull, isNull);
    });

    test('Err carries its failure and reports failure', () {
      const failure = NetworkFailure();
      const result = Result<int>.err(failure);

      expect(result.isErr, isTrue);
      expect(result.valueOrNull, isNull);
      expect(result.failureOrNull, same(failure));
    });

    test('fold collapses both branches', () {
      const ok = Result<int>.ok(2);
      const err = Result<int>.err(NetworkFailure());

      expect(ok.fold((v) => 'ok $v', (f) => 'err'), 'ok 2');
      expect(
        err.fold((v) => 'ok $v', (f) => 'err ${f.messageKey}'),
        'err errorOffline',
      );
    });

    test('map transforms the value and leaves a failure untouched', () {
      expect(const Result<int>.ok(3).map((v) => v * 2).valueOrNull, 6);

      const failure = NotFoundFailure();
      final mapped = const Result<int>.err(failure).map((v) => v * 2);
      expect(mapped.failureOrNull, same(failure));
    });

    test('flatMapAsync short-circuits on the first failure', () async {
      var ran = false;
      final result = await const Result<int>.err(NetworkFailure())
          .flatMapAsync<String>((value) async {
        ran = true;
        return const Result.ok('never');
      });

      expect(ran, isFalse, reason: 'the second step must not run');
      expect(result.isErr, isTrue);
    });

    test('flatMapAsync chains through a success', () async {
      final result = await const Result<int>.ok(4)
          .flatMapAsync<String>((value) async => Result.ok('v$value'));

      expect(result.valueOrNull, 'v4');
    });
  });

  group('Failure.isRetryable', () {
    test('transient conditions offer a retry', () {
      expect(const NetworkFailure().isRetryable, isTrue);
      expect(const ServerFailure().isRetryable, isTrue);
      expect(const CacheFailure().isRetryable, isTrue);
      expect(const UnknownFailure().isRetryable, isTrue);
    });

    test('conditions a retry cannot fix do not', () {
      expect(const PermissionFailure().isRetryable, isFalse);
      expect(const NotFoundFailure().isRetryable, isFalse);
      expect(const CancelledFailure().isRetryable, isFalse);
      expect(
        const ValidationFailure(messageKey: 'errorInvalidRequest').isRetryable,
        isFalse,
      );
      expect(
        const AuthFailure(messageKey: 'authErrorGeneric').isRetryable,
        isFalse,
      );
    });
  });
}
