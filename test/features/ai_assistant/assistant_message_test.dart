import 'package:flameup/features/ai_assistant/domain/assistant_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('claim labelling', () {
    test('splits a labelled answer into its claims', () {
      final message = AssistantMessage.fromAnswer(
        '[RECIPE] Cook the onions dry for fifteen minutes. '
        '[TRADITION] Many cooks judge this by smell rather than a timer. '
        '[SUGGESTION] If they catch, lower the heat rather than adding water.',
      );

      expect(message.claims, hasLength(3));
      expect(message.claims[0].kind, ClaimKind.recipe);
      expect(message.claims[1].kind, ClaimKind.tradition);
      expect(message.claims[2].kind, ClaimKind.suggestion);
      expect(message.claims[0].text, contains('fifteen minutes'));
    });

    test('an unlabelled answer stays plain rather than being promoted', () {
      // The failure that matters: silently treating a model's guess as a
      // recipe instruction would give it authority it has not earned.
      final message = AssistantMessage.fromAnswer(
        'Add a little more berbere.',
      );

      expect(message.claims, hasLength(1));
      expect(message.claims.single.kind, ClaimKind.plain);
      expect(message.claims.single.kind, isNot(ClaimKind.recipe));
      expect(message.claims.single.kind, isNot(ClaimKind.tradition));
    });

    test('text before the first marker is kept as plain prose', () {
      final message = AssistantMessage.fromAnswer(
        'Good question. [SUGGESTION] Try halving the mitmita.',
      );

      expect(message.claims, hasLength(2));
      expect(message.claims.first.kind, ClaimKind.plain);
      expect(message.claims.first.text, 'Good question.');
      expect(message.claims.last.kind, ClaimKind.suggestion);
    });

    test('markers are matched case-insensitively', () {
      final message =
          AssistantMessage.fromAnswer('[recipe] Simmer for 45 minutes.');
      expect(message.claims.single.kind, ClaimKind.recipe);
    });

    test('an empty claim body is dropped', () {
      final message = AssistantMessage.fromAnswer(
        '[RECIPE] [SUGGESTION] Lower the heat.',
      );

      expect(message.claims, hasLength(1));
      expect(message.claims.single.kind, ClaimKind.suggestion);
    });

    test('an unknown marker is not treated as authoritative', () {
      final message =
          AssistantMessage.fromAnswer('[FACT] Doro wat is ancient.');

      // [FACT] is not a marker the assistant is allowed to use; the text must
      // not acquire authority from an invented label.
      expect(message.claims.single.kind, ClaimKind.plain);
      expect(message.claims.single.text, contains('[FACT]'));
    });

    test('repeated markers each produce a claim', () {
      final message = AssistantMessage.fromAnswer(
        '[SUGGESTION] Use less oil. [SUGGESTION] Or a wider pan.',
      );

      expect(message.claims, hasLength(2));
      expect(
        message.claims.every((c) => c.kind == ClaimKind.suggestion),
        isTrue,
      );
    });
  });

  group('message kinds', () {
    test('a user message is marked as such', () {
      final message = AssistantMessage.user('Why did my shiro split?');
      expect(message.fromUser, isTrue);
      expect(message.failed, isFalse);
    });

    test('an error message is flagged and not styled as an answer', () {
      final message = AssistantMessage.error('The assistant is unavailable.');
      expect(message.failed, isTrue);
      expect(message.fromUser, isFalse);
      expect(message.claims.single.kind, ClaimKind.plain);
    });
  });
}
