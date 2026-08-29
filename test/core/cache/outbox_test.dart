import 'package:flameup/core/cache/pending_mutation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('idempotency', () {
    test('a key is generated once and survives retries', () {
      // This is what stops a cook finished offline awarding XP twice when the
      // device reconnects: the key is minted when the user acts, not when the
      // request is sent, so every retry carries the same one.
      final mutation = PendingMutation(
        kind: MutationKind.cookingSession,
        path: 'users/u1/cooking_sessions/s1',
        payload: const {'status': 'completed'},
      );

      final retried = mutation.copyWith(attempts: 1, lastError: 'errorOffline');
      final retriedAgain = retried.copyWith(attempts: 2);

      expect(retried.idempotencyKey, mutation.idempotencyKey);
      expect(retriedAgain.idempotencyKey, mutation.idempotencyKey);
    });

    test('separate actions get separate keys', () {
      final a = PendingMutation(
        kind: MutationKind.review,
        path: 'recipes/doro/reviews/u1',
        payload: const {},
      );
      final b = PendingMutation(
        kind: MutationKind.review,
        path: 'recipes/doro/reviews/u1',
        payload: const {},
      );

      expect(a.idempotencyKey, isNot(b.idempotencyKey));
    });

    test('creation time is preserved across retries so ordering holds', () {
      final mutation = PendingMutation(
        kind: MutationKind.shoppingItem,
        path: 'users/u1/shopping_items/i1',
        payload: const {},
      );

      expect(mutation.copyWith(attempts: 3).createdAt, mutation.createdAt);
    });
  });

  group('retry policy', () {
    PendingMutation withAttempts(int n) => PendingMutation(
          kind: MutationKind.savedRecipe,
          path: 'users/u1/saved_recipes/r1',
          payload: const {},
          attempts: n,
        );

    test('backs off exponentially, then caps', () {
      expect(withAttempts(0).retryAfter, Duration.zero);
      expect(withAttempts(1).retryAfter, const Duration(seconds: 2));
      expect(withAttempts(3).retryAfter, const Duration(seconds: 30));
      expect(withAttempts(5).retryAfter, const Duration(minutes: 10));
      expect(withAttempts(7).retryAfter, const Duration(minutes: 30));
      expect(
        withAttempts(20).retryAfter,
        const Duration(minutes: 30),
        reason: 'backoff must be capped, not unbounded',
      );
    });

    test('gives up after the attempt limit', () {
      expect(
        withAttempts(PendingMutation.maxAttempts - 1).isExhausted,
        isFalse,
      );
      expect(withAttempts(PendingMutation.maxAttempts).isExhausted, isTrue);
    });

    test('a first attempt is always ready', () {
      expect(withAttempts(0).isReadyToRetry, isTrue);
    });
  });

  group('serialisation', () {
    test('round trips through JSON', () {
      final original = PendingMutation(
        kind: MutationKind.cookingSession,
        path: 'users/u1/cooking_sessions/s1',
        payload: const {'currentStep': 4, 'status': 'in_progress'},
        attempts: 2,
        lastError: 'errorOffline',
      );

      final restored = PendingMutation.fromJson(original.toJson());

      expect(restored, isNotNull);
      expect(restored!.kind, MutationKind.cookingSession);
      expect(restored.path, original.path);
      expect(restored.payload['currentStep'], 4);
      expect(restored.idempotencyKey, original.idempotencyKey);
      expect(restored.attempts, 2);
      expect(restored.lastError, 'errorOffline');
    });

    test('a corrupt row decodes to null instead of throwing', () {
      // One unreadable entry must not stop the rest of the queue draining.
      expect(PendingMutation.fromJson(const {}), isNull);
      expect(
        PendingMutation.fromJson(const {'kind': 'notARealKind', 'path': 'p'}),
        isNull,
      );
      expect(
        PendingMutation.fromJson({
          'kind': MutationKind.review.name,
          'path': 'p',
          'idempotencyKey': 'k',
          'createdAt': 'not-a-date',
        }),
        isNull,
      );
    });

    test('a missing payload decodes as empty rather than failing', () {
      final restored = PendingMutation.fromJson({
        'kind': MutationKind.userProfile.name,
        'path': 'users/u1',
        'idempotencyKey': 'k',
        'createdAt': DateTime.now().toIso8601String(),
      });

      expect(restored, isNotNull);
      expect(restored!.payload, isEmpty);
    });
  });

  group('mutation kinds', () {
    test('every offline-capable write has a kind', () {
      // The drain switches exhaustively over this set; adding an offline write
      // without a kind here would leave it unhandled.
      expect(MutationKind.values, hasLength(8));
      expect(
        MutationKind.values.map((k) => k.name),
        containsAll(<String>[
          'cookingSession',
          'review',
          'savedRecipe',
          'shoppingItem',
          'mealPlan',
          'userProfile',
          'familyRecipe',
          'socialAction',
        ]),
      );
    });
  });
}
