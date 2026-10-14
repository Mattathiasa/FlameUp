import 'package:flameup/features/ai_assistant/domain/assistant_engine.dart';
import 'package:flameup/features/ai_assistant/domain/assistant_message.dart';
import 'package:flameup/features/recipes/domain/ingredient.dart';
import 'package:flameup/features/recipes/domain/recipe.dart';
import 'package:flutter_test/flutter_test.dart';

Recipe dish({
  String id = 'doro_wat',
  String title = 'Doro Wat',
  String titleAm = 'ዶሮ ወጥ',
  String subtitle = 'Ethiopia\'s celebration chicken stew',
  String story = '',
  int totalMinutes = 150,
  int servings = 4,
  List<Ingredient> ingredients = const [],
  List<RecipeStep> steps = const [],
}) =>
    Recipe(
      id: id,
      title: title,
      titleAm: titleAm,
      subtitle: subtitle,
      subtitleAm: '',
      regionId: 'addis',
      category: 'stew',
      difficulty: Difficulty.medium,
      totalMinutes: totalMinutes,
      servings: servings,
      xpReward: 50,
      ingredients: ingredients,
      steps: steps,
      gradientA: '#000',
      gradientB: '#111',
      story: story,
    );

Ingredient ing(String name, {String nameAm = '', double quantity = 1}) =>
    Ingredient(
      name: name,
      nameAm: nameAm,
      quantity: quantity,
      unit: '',
      unitAm: '',
    );

void main() {
  final engine = AssistantEngine([
    dish(
      ingredients: [
        ing('Chicken, jointed', nameAm: 'የተከፋፈለ ዶሮ', quantity: 1),
        ing('Onion', nameAm: 'ሽንኩርት', quantity: 2),
        ing('Berbere', nameAm: 'በርበሬ', quantity: 3),
        ing('Niter kibbeh', nameAm: 'ንጥር ቅቤ'),
      ],
      steps: [
        const RecipeStep(
          index: 0,
          text: 'Fry the onions until deep brown.',
          textAm: '',
          durationSeconds: 900,
          tip: 'Stir often so they do not catch.',
          tipAm: '',
        ),
        const RecipeStep(
          index: 1,
          text: 'Add berbere and the chicken.',
          textAm: '',
        ),
      ],
      story: 'In much of Ethiopia it is the dish that ends a fast.',
    ),
    dish(
      id: 'misir_wat',
      title: 'Misir Wat',
      titleAm: 'ምስር ወጥ',
      subtitle: 'Spiced red lentil stew',
      totalMinutes: 45,
      ingredients: [
        ing('Red lentils', nameAm: 'ቀይ ምስር', quantity: 2),
        ing('Onion', nameAm: 'ሽንኩርት', quantity: 1),
        ing('Berbere', nameAm: 'በርበሬ', quantity: 1),
      ],
      steps: const [
        RecipeStep(index: 0, text: 'Simmer until soft.', textAm: ''),
      ],
    ),
    dish(
      id: 'kinche',
      title: 'Kinche',
      titleAm: 'ቅንጫ',
      subtitle: 'Cracked wheat breakfast porridge',
      totalMinutes: 20,
      ingredients: [ing('Cracked wheat', nameAm: 'ስንዴ ፍርፍር', quantity: 1)],
      steps: const [
        RecipeStep(index: 0, text: 'Stir into boiling water.', textAm: ''),
      ],
    ),
  ]);

  String ask(
    String question, {
    bool amharic = false,
    String? recipeId,
    int? stepIndex,
  }) =>
      engine.answer(
        question: question,
        recipeId: recipeId,
        stepIndex: stepIndex,
        amharic: amharic,
      );

  group('pantry search', () {
    test('ranks dishes by how many of the asked ingredients they use', () {
      final answer = ask('what can I cook with onion and berbere');

      expect(answer, startsWith('[RECIPE]'));
      // Both stews use onion+berbere, kinche uses neither: the two matches
      // must be listed, and the porridge must not be.
      expect(answer, contains('Doro Wat'));
      expect(answer, contains('Misir Wat'));
      expect(answer, isNot(contains('Kinche')));
      // Both match onion+berbere, so the documented tie-break decides:
      // the faster dish the cook can act on tonight comes first.
      expect(answer.indexOf('Misir Wat'), lessThan(answer.indexOf('Doro Wat')));
    });

    test('matches plural forms and reports what is still missing', () {
      final answer = ask('I have onions and lentils');

      expect(answer, contains('Misir Wat'));
      expect(answer, contains('you have 2 of 3 ingredients'));
      expect(answer, contains('missing 1'));
    });

    test('matches Amharic ingredient names', () {
      final answer = ask('በርበሬ እና ሽንኩርት አለኝ ምን ማብሰል እችላለሁ', amharic: true);

      expect(answer, contains('ዶሮ ወጥ'));
      expect(answer, startsWith('[RECIPE]'));
    });

    test('an ingredient-less pantry question falls through honestly', () {
      final answer = ask('what can I cook with only air');

      expect(answer, startsWith('[SUGGESTION]'));
      expect(answer, contains('I can answer questions'));
    });
  });

  group('substitutions', () {
    test('are always suggestions, never recipe facts', () {
      final message = AssistantMessage.fromAnswer(
        ask('what can I use instead of niter kibbeh'),
      );

      expect(message.claims, hasLength(1));
      expect(message.claims.single.kind, ClaimKind.suggestion);
      expect(message.claims.single.text, contains('butter'));
    });

    test('say so when no honest substitute exists', () {
      final answer = ask('is there a substitute for berbere');

      expect(answer, startsWith('[SUGGESTION]'));
      expect(answer, contains('no true stand-in'));
    });

    test(
        'a substitution question naming a dish still answers the '
        'substitution', () {
      final answer = ask('what can I use instead of berbere in doro wat');

      expect(answer, startsWith('[SUGGESTION]'));
      expect(answer, contains('berbere'));
      // The dish fact list must not sneak in: the answer is one suggestion.
      expect(answer, isNot(contains('what you need')));
    });

    test(
        'a substitution question with no named ingredient asks instead '
        'of guessing', () {
      final answer = ask('can I substitute something');

      expect(answer, startsWith('[SUGGESTION]'));
      expect(answer, contains('Tell me which ingredient'));
    });
  });

  group('dish questions', () {
    test('lists ingredients with amounts under the recipe claim', () {
      final message = AssistantMessage.fromAnswer(
        ask('what are the ingredients for doro wat'),
      );

      expect(message.claims.single.kind, ClaimKind.recipe);
      expect(message.claims.single.text, contains('Doro Wat'));
      expect(message.claims.single.text, contains('Onion'));
      expect(message.claims.single.text, contains('Berbere'));
    });

    test('lists steps with their timers', () {
      final answer = ask('how do I make doro wat, step by step');

      expect(answer, startsWith('[RECIPE]'));
      expect(answer, contains('1. Fry the onions until deep brown.'));
      expect(answer, contains('15 min timer'));
      expect(answer, contains('2. Add berbere and the chicken.'));
    });

    test('answers total time from the catalogue', () {
      final answer = ask('how long does misir wat take');

      expect(answer, startsWith('[RECIPE]'));
      expect(answer, contains('45m'));
    });

    test('answers servings', () {
      final answer = ask('how many does doro wat serve');

      expect(answer, startsWith('[RECIPE]'));
      expect(answer, contains('4 servings'));
    });

    test('answers the story as tradition, not recipe', () {
      final message = AssistantMessage.fromAnswer(
        ask('what is the tradition behind doro wat'),
      );

      expect(message.claims.single.kind, ClaimKind.tradition);
      expect(message.claims.single.text, contains('ends a fast'));
    });

    test('an unknown dish question gets the honest fallback', () {
      final answer = ask('tell me about pizza');

      expect(answer, startsWith('[SUGGESTION]'));
      expect(answer, contains('I can answer questions'));
    });
  });

  group('cook-mode context', () {
    test('recipeId grounds the question when no dish is named', () {
      final answer = ask('what do I need', recipeId: 'misir_wat');

      expect(answer, contains('Misir Wat'));
      expect(answer, contains('Red lentils'));
    });

    test('stepIndex answers about the current step with its timer', () {
      final answer =
          ask('what now on this step', recipeId: 'doro_wat', stepIndex: 0);

      expect(answer, startsWith('[RECIPE]'));
      expect(answer, contains('Step 1: Fry the onions'));
      expect(answer, contains('15 min timer'));
      expect(answer, contains('Tip: Stir often'));
    });

    test('a step tip is a suggestion, not a recipe fact', () {
      final message = AssistantMessage.fromAnswer(
        ask('what now on this step', recipeId: 'doro_wat', stepIndex: 0),
      );

      final tip = message.claims.firstWhere((c) => c.text.startsWith('Tip:'));
      expect(tip.kind, ClaimKind.suggestion);
    });

    test('an out-of-range stepIndex falls back instead of throwing', () {
      final answer = ask('what now', recipeId: 'doro_wat', stepIndex: 99);

      expect(answer, startsWith('[SUGGESTION]'));
    });

    test('a step question without context still answers the named dish', () {
      final answer = ask('what is step 2 of doro wat');

      expect(answer, startsWith('[RECIPE]'));
      expect(answer, contains('2. Add berbere and the chicken.'));
    });
  });

  group('Amharic mode', () {
    test('answers dish questions in Amharic using catalogue fields', () {
      final answer = ask('የዶሮ ወጥ ንጥረ ነገሮች ምንድሆች?', amharic: true);

      expect(answer, contains('ዶሮ ወጥ'));
    });

    test('falls back to the English title when no Amharic title exists', () {
      final engineNoAm = AssistantEngine([
        dish(id: 'x', title: 'Plain Dish', titleAm: ''),
      ]);
      final answer = engineNoAm.answer(
        question: 'what is plain dish',
        amharic: true,
      );

      expect(answer, contains('Plain Dish'));
    });
  });

  group('claim honesty', () {
    test('every pantry answer parses into a recipe claim only', () {
      final message = AssistantMessage.fromAnswer(
        ask('what can I cook with onions'),
      );

      expect(message.claims, isNotEmpty);
      expect(
        message.claims.every((c) => c.kind == ClaimKind.recipe),
        isTrue,
        reason: 'catalogue-derived answers must read as recipe facts',
      );
    });

    test('the fallback never claims recipe authority', () {
      final message = AssistantMessage.fromAnswer(ask('zzz nothing matches'));

      expect(message.claims.single.kind, ClaimKind.suggestion);
    });
  });
}
