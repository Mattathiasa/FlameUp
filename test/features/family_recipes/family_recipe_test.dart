import 'package:flameup/core/cache/pending_mutation.dart';
import 'package:flameup/core/errors/failure.dart';
import 'package:flameup/features/family_recipes/domain/family_recipe.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FamilyRecipe.fromJson', () {
    test('parses a full document', () {
      final recipe = FamilyRecipe.fromJson('r1', {
        'authorId': 'u1',
        'status': 'published',
        'title': 'Doro Wat',
        'titleAm': 'ዶሮ ወጥ',
        'teacherName': 'Emahoy Tsehay',
        'regionId': 'amhara',
        'story': 'Learned at her table.',
        'stepsText': '1. ...',
        'mediaUrl': 'https://example.com/a.jpg',
        'createdAt': '2026-01-02T03:04:05.000',
      });

      expect(recipe, isNotNull);
      expect(recipe!.id, 'r1');
      expect(recipe.status, FamilyRecipeStatus.published);
      expect(recipe.displayName, 'ዶሮ ወጥ');
      expect(recipe.createdAt, isNotNull);
    });

    test('falls back to the English title when no Amharic title exists', () {
      final recipe = FamilyRecipe.fromJson('r2', {
        'authorId': 'u1',
        'status': 'pending',
        'title': 'Kitfo',
      });
      expect(recipe!.displayName, 'Kitfo');
    });

    test('an unknown status yields null rather than crashing the list', () {
      expect(
        FamilyRecipe.fromJson('r3', {
          'authorId': 'u1',
          'status': 'mystery-status',
        }),
        isNull,
      );
    });

    test('a null document yields null', () {
      expect(FamilyRecipe.fromJson('r4', null), isNull);
    });

    test('missing fields become empty, not errors', () {
      final recipe = FamilyRecipe.fromJson('r5', {
        'status': 'draft',
        'authorId': 'u1',
      });
      expect(recipe!.title, isEmpty);
      expect(recipe.story, isEmpty);
      expect(recipe.regionId, isNull);
      expect(recipe.mediaUrl, isNull);
    });
  });

  group('submission payloads', () {
    test('the pending payload carries the id the rules and outbox key on', () {
      // Mirrors what the form builds: the id minted with the draft flows into
      // both the document path and the idempotency key, so a double tap or a
      // replayed drain merges onto one document.
      final payload = {
        'id': 'abc-123',
        'title': 'Shiro',
        'authorId': 'u1',
        'status': FamilyRecipeStatus.pending.name,
      };

      final mutation = PendingMutation(
        kind: MutationKind.familyRecipe,
        path: 'family_recipes/${payload['id']}',
        payload: payload,
        idempotencyKey: 'familyRecipe.${payload['id']}',
      );

      expect(mutation.kind, MutationKind.familyRecipe);
      expect(mutation.idempotencyKey, 'familyRecipe.abc-123');

      final restored = PendingMutation.fromJson(mutation.toJson());
      expect(restored, isNotNull);
      expect(restored!.path, mutation.path);
      expect(restored.payload['id'], 'abc-123');
    });

    test('status is round-tripped through the enum name', () {
      expect(
        FamilyRecipeStatus.values.map((s) => s.name),
        containsAll(['draft', 'pending', 'published']),
      );
    });
  });

  group('failure mapping contract', () {
    test('ValidationFailure stays non-retryable', () {
      // A submission without an id is a bug, not a network blip; the outbox
      // must not spin on it.
      const failure = ValidationFailure(messageKey: 'validationNameRequired');
      expect(failure.isRetryable, isFalse);
    });
  });
}
