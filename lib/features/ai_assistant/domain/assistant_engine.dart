import '../../recipes/domain/ingredient.dart';
import '../../recipes/domain/recipe.dart';

/// Answers cooking questions from the bundled catalogue — on the device.
///
/// No network, no Cloud Functions, no provider key: every answer is derived
/// from the same recipe data the app already ships, so the assistant works
/// offline, costs nothing to run, and can never claim anything the recipes
/// themselves do not say. Answers are written as `[RECIPE]` / `[TRADITION]` /
/// `[SUGGESTION]` segments; `AssistantMessage.fromAnswer` splits them, so the
/// UI keeps its claim-labelling contract without change.
class AssistantEngine {
  AssistantEngine(this.recipes);

  final List<Recipe> recipes;

  /// Answers [question], optionally grounded in cook-mode context: the dish
  /// being cooked ([recipeId]) and the step the cook is on ([stepIndex]).
  String answer({
    required String question,
    String? recipeId,
    int? stepIndex,
    required bool amharic,
  }) {
    final q = _normalize(question);

    // Substitutions beat dish lookup: "what can I use instead of berbere in
    // doro wat" must answer the substitution even though it names a dish.
    if (_wantsSubstitution(q)) {
      final substitution = _substitutionAnswer(q, amharic: amharic);
      if (substitution != null) return substitution;
    }

    if (_wantsPantry(q)) {
      final pantry = _pantryAnswer(q, amharic: amharic);
      if (pantry != null) return pantry;
    }

    final focused = _findRecipe(q, recipeId);
    if (focused != null) {
      return _dishAnswer(focused, q, stepIndex: stepIndex, amharic: amharic);
    }

    return _fallback(amharic: amharic);
  }

  // ---------------------------------------------------------------- intents

  static const _substituteCues = [
    'substitute',
    'replace',
    'instead',
    "don't have",
    'dont have',
    'out of',
    'alternative',
    'መቀየር',
    'ምትኬ',
    'ቀይር',
  ];

  static const _pantryCues = [
    'what can i cook',
    'what can i make',
    'cook with',
    'make with',
    'i have',
    'in my fridge',
    'in my pantry',
    'ምን ማብሰል',
    'እችላለሁ',
    'ያለኝ',
  ];

  static const _ingredientCues = [
    'ingredient',
    'what do i need',
    'what goes in',
    'what is in',
    "what's in",
    'need for',
    'requires',
    'contain',
    'ንጥረ ነገር',
    'የሚያስፈልግ',
    'ምን ይገባል',
  ];

  static const _stepCues = [
    'step',
    'how do i make',
    'how to make',
    'how to cook',
    'method',
    'instructions',
    'prepare',
    'እንዴት',
    'አሠራር',
    'ረጃጃብ',
  ];

  static const _timeCues = [
    'how long',
    'time',
    'minute',
    'hour',
    'take',
    'quick',
    'fast',
    'ሰዓት',
    'ደቂቃ',
    'ጊዜ',
    'ፈጣን',
  ];

  static const _servingCues = [
    'serve',
    'serving',
    'yield',
    'portion',
    'how many people',
    'feeds',
    'አስተላልፎ',
    'ለሰው',
  ];

  static const _storyCues = [
    'story',
    'tradition',
    'history',
    'culture',
    'origin',
    'meaning',
    'ታሪክ',
    'ባህል',
    'ልድያ',
  ];

  static const _thisStepCues = [
    'this step',
    'current step',
    'what now',
    'next step',
    'right now',
    'ቀጣይ',
    'ይህ ደረጃ',
    'አሁን ምን',
  ];

  static bool _mentions(String q, List<String> cues) => cues.any(q.contains);

  static bool _wantsSubstitution(String q) => _mentions(q, _substituteCues);
  static bool _wantsPantry(String q) => _mentions(q, _pantryCues);
  static bool _wantsIngredients(String q) => _mentions(q, _ingredientCues);
  static bool _wantsSteps(String q) => _mentions(q, _stepCues);
  static bool _wantsTime(String q) => _mentions(q, _timeCues);
  static bool _wantsServings(String q) => _mentions(q, _servingCues);
  static bool _wantsStory(String q) => _mentions(q, _storyCues);
  static bool _wantsThisStep(String q) => _mentions(q, _thisStepCues);

  // ----------------------------------------------------------------- lookup

  /// The dish the question is about: the longest dish name mentioned in the
  /// question wins (so "kik alicha" beats "kik"); otherwise the cook-mode
  /// context dish, if any.
  Recipe? _findRecipe(String q, String? recipeId) {
    Recipe? best;
    var bestLength = 0;

    for (final recipe in recipes) {
      final en = _normalize(recipe.title);
      final am = _normalize(recipe.titleAm);
      final length =
          q.contains(en) ? en.length : (q.contains(am) ? am.length : 0);
      if (length > bestLength) {
        best = recipe;
        bestLength = length;
      }
    }

    if (best != null) return best;
    if (recipeId == null) return null;
    for (final recipe in recipes) {
      if (recipe.id == recipeId) return recipe;
    }
    return null;
  }

  // ------------------------------------------------------------ substitutions

  /// Curated stand-ins, keyed by normalized ingredient name → (English,
  /// Amharic). Every entry is an inference about cooking, never a fact about
  /// a dish — so every entry is delivered as a suggestion, and where no
  /// honest substitute exists the entry says so instead of inventing one.
  static const _substitutions = <String, (String, String)>{
    'niter kibbeh': (
      'Plain melted butter gets close; a neutral oil works in a pinch, '
          'though the dish loses the spiced aroma niter kibbeh carries.',
      'ቀላል ቅቤ በጣት ይመስላል፤ በፈጥነት ዘይትም ይሠራል፣ ግን የንጥር ቅቤ ጣዕም ይጎዳል።',
    ),
    'berbere': (
      'There is no true stand-in for berbere. In a pinch, mix mild chilli '
          'powder with a little paprika, fenugreek and coriander — it will be '
          'a different dish, and honestly a lesser one.',
      'ለበርበሬ ሙሉ በሙሉ የሚመስል ምትኬ የለም። በፈጥነት ቀይ ሩብ ቡና ከፓፓሪያ፣ '
          'ከሽፈራ እና ከኮሪያንደር ጋር ይቀላቀሉ — ልዩ ምግብ ይሆናል።',
    ),
    'mitmita': (
      'Cayenne with a little ground cardamom and black pepper approximates '
          'mitmita.',
      'ካይን ከካርዳሞም እና ከአፋ በርበሬ ጋር ይቀላቀል — እንደሚጥሚጣ ይሠራል።',
    ),
    'tej': (
      'In cooking, red wine does the same job as tej — the recipes '
          'themselves allow it. For drinking, there is no substitute worth '
          'the name.',
      'በምግብ ላይ ቀይ ወይን ከጠጅ በዛሬው ይሠራል — ደረሰኝዎቹም እንዲያው '
          'ይፈቀዳሉ። ለመጠጣት ግን ምትኬ የለም።',
    ),
    'teff flour': (
      'For injera there is no substitute for teff. Blending teff with '
          'barley or wheat flour makes an everyday flatbread — not an '
          'ersho-fermented injera.',
      'ለእንጀራ ጤፍ ምትኬ የለም። ጤፍ ከገብስ ወይም ከስንዴ ዱቄት ጋር '
          'የሚቀላቀለው በየቀኑ የሚበላው ኳስ ነው — እንጀራ አይደለም።',
    ),
    'ayib': (
      'Fresh cottage cheese or ricotta stands in for ayib almost exactly.',
      'ትኩስ ኮቲጅ አይብ ወይም ሪኮታ አይብን በትርስ ይተካል።',
    ),
    'gomen': (
      'Kale or chard cooks like gomen — same method, slightly different '
          'leaf.',
      'ኬል ወይም ሳዊድ ከጎመን ጋር በአንድ መንገድ ይቀላል።',
    ),
    'oil': (
      'Any oil will cook the dish; niter kibbeh is what makes it taste '
          'Ethiopian.',
      'ማንኛውም ዘይት ይሠራል፤ ንጥር ቅቤ ግን ጣዕሙን ያዘምናል።',
    ),
    'yeast': (
      'For a quick bread, baking powder; for injera nothing replaces a '
          'living ersho starter — keep or buy one.',
      'ለፈጣን ኳስ ቦዲንግ ፖውደር፤ ለእንጀራ ግን ንጥል እርሾ ያለ መፍትሔ የለም።',
    ),
  };

  String? _substitutionAnswer(String q, {required bool amharic}) {
    final hits = <MapEntry<String, (String, String)>>[];
    for (final entry in _substitutions.entries) {
      if (_containsKey(q, entry.key)) hits.add(entry);
    }

    if (hits.isEmpty) {
      // Honest about what it needs rather than guessing which ingredient
      // the cook meant.
      return '[SUGGESTION] ${amharic ? 'የት ንጥረ ነገር እንደሚቀይር ይንገሩን — ለምሳሌ ንጥር ቅቤ፣ በርበሬ፣ ጠጅ '
          'ወይም ጤፍ።' : 'Tell me which ingredient — for example niter kibbeh, berbere, '
          'tej or teff — and I will say what can stand in for it.'}';
    }

    final buffer = StringBuffer();
    for (final hit in hits) {
      final (en, am) = hit.value;
      if (buffer.isNotEmpty) buffer.writeln();
      buffer.write('[SUGGESTION] ${amharic ? am : en}');
    }
    return buffer.toString();
  }

  // ------------------------------------------------------------------ pantry

  String? _pantryAnswer(String q, {required bool amharic}) {
    final hits = <(Recipe, List<Ingredient>)>[];
    for (final recipe in recipes) {
      final matched =
          recipe.ingredients.where((i) => _ingredientMentioned(q, i)).toList();
      if (matched.isNotEmpty) hits.add((recipe, matched));
    }
    if (hits.isEmpty) return null;

    // Best-covered dish first; ties go to the faster dish, because a pantry
    // answer the cook can act on tonight is worth more than a perfect match
    // they cannot finish.
    hits.sort((a, b) {
      final byMatched = b.$2.length.compareTo(a.$2.length);
      if (byMatched != 0) return byMatched;
      return a.$1.totalMinutes.compareTo(b.$1.totalMinutes);
    });

    final buffer = StringBuffer()
      ..writeln(
        '[RECIPE] ${amharic ? 'ያለብዎትን በመጠቀም የሚሠሩት፦' : 'With what you have, you could cook:'}',
      );

    for (final (recipe, matched) in hits.take(3)) {
      final have = matched
          .map((i) => _localised(i.name, i.nameAm, amharic))
          .join(amharic ? '፣ ' : ', ');
      final missing = recipe.ingredients.length - matched.length;
      final title = _localised(recipe.title, recipe.titleAm, amharic);
      if (amharic) {
        buffer.writeln('• $title — ከ${recipe.ingredients.length} ንጥረ '
            'ነገሮች ${matched.length} አለዎት (ያለዎት፦ $have)'
            '${missing > 0 ? '፣ የሚጎዳው $missing' : ''}');
      } else {
        buffer.writeln('• $title — you have ${matched.length} of '
            '${recipe.ingredients.length} ingredients ($have)'
            '${missing > 0 ? ', missing $missing' : ''}');
      }
    }

    return buffer.toString().trimRight();
  }

  // ------------------------------------------------------------ dish answers

  String _dishAnswer(
    Recipe recipe,
    String q, {
    int? stepIndex,
    required bool amharic,
  }) {
    if (stepIndex != null && _wantsThisStep(q)) {
      return _stepAnswer(recipe, stepIndex, amharic: amharic);
    }
    if (_wantsIngredients(q)) {
      return _ingredientsAnswer(recipe, amharic: amharic);
    }
    if (_wantsSteps(q)) {
      return _stepsAnswer(recipe, amharic: amharic);
    }

    final title = _localised(recipe.title, recipe.titleAm, amharic);

    if (_wantsTime(q)) {
      return '[RECIPE] ${amharic ? '$title ከመጀመሪያ እስከ መጨረሽ '
          '${recipe.formattedTime(amharic: amharic)} ይወስዳል።' : '$title takes about '
          '${recipe.formattedTime(amharic: amharic)} start to finish.'}';
    }
    if (_wantsServings(q)) {
      return '[RECIPE] ${amharic ? '$title በመደበኛ ለ${recipe.servings} ሰው ያገለግላል። በደረሰኙ ላይ ያለውን '
          'አስተላልፎ ቁጥር ቀይረህ መጠኖች በራሳቸው ይስገኛሉ።' : '$title yields ${recipe.servings} servings by default — change '
          'the servings on the recipe screen and the amounts rescale '
          'themselves.'}';
    }
    if (_wantsStory(q)) {
      final story = _localised(recipe.story, recipe.storyAm, amharic);
      if (story.isEmpty) return _fallback(amharic: amharic);
      return '[TRADITION] $story';
    }

    // No specific intent: an honest overview — what the catalogue says,
    // nothing beyond it.
    final buffer = StringBuffer()
      ..write('[RECIPE] $title — '
          '${_localised(recipe.subtitle, recipe.subtitleAm, amharic)}. ')
      ..write(
        amharic
            ? 'ጊዜ ${recipe.formattedTime(amharic: amharic)}፣ ለ${recipe.servings} ሰው።'
            : 'About ${recipe.formattedTime(amharic: amharic)}, '
                'serves ${recipe.servings}.',
      );
    final story = _localised(recipe.story, recipe.storyAm, amharic);
    if (story.isNotEmpty) {
      buffer
        ..writeln()
        ..write('[TRADITION] $story');
    }
    return buffer.toString();
  }

  String _stepAnswer(Recipe recipe, int stepIndex, {required bool amharic}) {
    if (stepIndex < 0 || stepIndex >= recipe.steps.length) {
      return _fallback(amharic: amharic);
    }
    final step = recipe.steps[stepIndex];
    final buffer = StringBuffer()
      ..write(
        '[RECIPE] ${amharic ? 'ደረጃ ${stepIndex + 1}፦ ${step.localisedText(amharic: amharic)}' : 'Step ${stepIndex + 1}: ${step.localisedText(amharic: amharic)}'}',
      );
    if (step.hasTimer) {
      buffer.write(' — ${_timerText(step.durationSeconds!, amharic: amharic)}');
    }
    final tip = step.localisedTip(amharic: amharic);
    if (tip != null && tip.isNotEmpty) {
      buffer
        ..writeln()
        ..write('[SUGGESTION] ${amharic ? 'ጠቆም፦' : 'Tip:'} $tip');
    }
    return buffer.toString();
  }

  String _ingredientsAnswer(Recipe recipe, {required bool amharic}) {
    final title = _localised(recipe.title, recipe.titleAm, amharic);
    final buffer = StringBuffer()
      ..writeln(
        '[RECIPE] ${amharic ? '$title የሚያስፈልጉት (ለ${recipe.servings} ሰው)፦' : '$title — what you need for ${recipe.servings} servings:'}',
      );
    for (final ingredient in recipe.ingredients) {
      final name = _localised(ingredient.name, ingredient.nameAm, amharic);
      final amount = ingredient.displayAmount(amharic: amharic);
      buffer.writeln('• ${amount.isEmpty ? name : '$amount $name'}');
    }
    return buffer.toString().trimRight();
  }

  String _stepsAnswer(Recipe recipe, {required bool amharic}) {
    final title = _localised(recipe.title, recipe.titleAm, amharic);
    final buffer = StringBuffer()
      ..writeln('[RECIPE] $title — ${amharic ? 'ደረጃዎች፦' : 'the steps:'}');
    for (var i = 0; i < recipe.steps.length; i++) {
      final step = recipe.steps[i];
      final timer = step.hasTimer
          ? ' — ${_timerText(step.durationSeconds!, amharic: amharic)}'
          : '';
      buffer.writeln('${i + 1}. ${step.localisedText(amharic: amharic)}$timer');
    }
    return buffer.toString().trimRight();
  }

  // ---------------------------------------------------------------- fallback

  String _fallback({required bool amharic}) =>
      '[SUGGESTION] ${amharic ? 'ስለ እዚህ መተግበሪያ ውስጥ ያሉት ምግቦች — ንጥረ ነገሮች፣ ደረጃዎች፣ ጊዜ፣ '
          'አስተላልፎ እና ታሪክ — መልስ ማግኘት እችላለሁ። እንደ "ከሽንኩርት ጋር ምን ማብሰል '
          'እችላለሁ" ወይም "ዶሮ ወጥ ንጥረ ነገሮች" ይሞክሩ።' : 'I can answer questions about the dishes in this app — their '
          'ingredients, steps, timing, servings and story — and suggest '
          'substitutions. Try "what can I cook with onion", or ask about a '
          'dish like "Doro Wat".'}';

  // ----------------------------------------------------------------- helpers

  static String _localised(String en, String am, bool amharic) =>
      amharic && am.isNotEmpty ? am : en;

  static String _timerText(int seconds, {required bool amharic}) {
    final minutes = (seconds / 60).round();
    return amharic ? '$minutes ደቂቃ ማስቆሚያ' : '$minutes min timer';
  }

  static String _normalize(String input) => input
      .toLowerCase()
      .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// Whether [q] mentions the ingredient — by full name, by the head word of
  /// a qualified name ("Beef, cubed" → "beef"), with or without a plural s,
  /// or by the Amharic name.
  static bool _ingredientMentioned(String q, Ingredient ingredient) =>
      _searchKeys(ingredient).any((key) => _containsKey(q, key));

  static bool _containsKey(String q, String key) {
    if (key.isEmpty) return false;
    // Amharic has no reliable word boundary in JS-style regex, so plain
    // containment; ASCII words get a boundary so "pea" never matches
    // "peace".
    if (key.codeUnits.every((c) => c < 0x80)) {
      return RegExp(r'\b' + RegExp.escape(key) + r's?\b').hasMatch(q);
    }
    return q.contains(key);
  }

  static List<String> _searchKeys(Ingredient ingredient) {
    final keys = <String>[];
    if (ingredient.name.isNotEmpty) {
      keys.add(_normalize(ingredient.name));
      final head = ingredient.name.split(',').first.trim();
      keys.add(_normalize(head));
      if (head.toLowerCase().endsWith('s')) {
        keys.add(_normalize(head.substring(0, head.length - 1)));
      }
      final noun = _headNoun(_normalize(head));
      if (noun != null) keys.add(noun);
    }
    if (ingredient.nameAm.isNotEmpty) keys.add(_normalize(ingredient.nameAm));
    return keys;
  }

  /// The head noun of a compound ingredient name — "Red lentils" →
  /// "lentil", "Chicken thighs, diced" → "thigh" — so a pantry question
  /// that names the ingredient plainly ("I have lentils") still matches.
  ///
  /// Only the head noun, never the modifiers: having chicken must not claim
  /// chicken stock. Single-word names already match as full keys, and short
  /// nouns ("oil", "yam") are too generic to trust on their own.
  static String? _headNoun(String normalisedHead) {
    final words = normalisedHead.split(' ').where((w) => w.isNotEmpty).toList();
    if (words.length < 2) return null;
    final noun = words.last;
    if (noun.length < 4) return null;
    return noun.endsWith('s') ? noun.substring(0, noun.length - 1) : noun;
  }
}
