import 'ingredient.dart';

/// How hard a dish is, matching the design's three levels.
enum Difficulty {
  beginner,
  medium,
  advanced;

  int get value => index;

  static Difficulty fromValue(int? value) =>
      value != null && value >= 0 && value < Difficulty.values.length
          ? Difficulty.values[value]
          : Difficulty.beginner;
}

/// One step of a recipe.
class RecipeStep {
  const RecipeStep({
    required this.index,
    required this.text,
    required this.textAm,
    this.durationSeconds,
    this.tip,
    this.tipAm,
    this.imageUrl,
    this.videoUrl,
    this.optional = false,
  });

  final int index;
  final String text;
  final String textAm;

  /// Null when the step is not timed. A step with a duration gets a real
  /// timer in cook mode, and its deadline is stored as wall-clock time so it
  /// survives the app being backgrounded.
  final int? durationSeconds;

  final String? tip;
  final String? tipAm;
  final String? imageUrl;
  final String? videoUrl;
  final bool optional;

  bool get hasTimer => durationSeconds != null && durationSeconds! > 0;

  Duration? get duration =>
      hasTimer ? Duration(seconds: durationSeconds!) : null;

  String localisedText({required bool amharic}) => amharic ? textAm : text;
  String? localisedTip({required bool amharic}) => amharic ? tipAm : tip;

  Map<String, dynamic> toJson() => {
        'index': index,
        'text': text,
        'textAm': textAm,
        if (durationSeconds != null) 'durationSeconds': durationSeconds,
        if (tip != null) 'tip': tip,
        if (tipAm != null) 'tipAm': tipAm,
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (videoUrl != null) 'videoUrl': videoUrl,
        'optional': optional,
      };

  static RecipeStep fromJson(Map<String, dynamic> json) => RecipeStep(
        index: json['index'] as int? ?? 0,
        text: json['text'] as String? ?? '',
        textAm: json['textAm'] as String? ?? '',
        durationSeconds: json['durationSeconds'] as int?,
        tip: json['tip'] as String?,
        tipAm: json['tipAm'] as String?,
        imageUrl: json['imageUrl'] as String?,
        videoUrl: json['videoUrl'] as String?,
        optional: json['optional'] as bool? ?? false,
      );
}

/// A dish.
class Recipe {
  const Recipe({
    required this.id,
    required this.title,
    required this.titleAm,
    required this.subtitle,
    required this.subtitleAm,
    required this.regionId,
    required this.category,
    required this.difficulty,
    required this.totalMinutes,
    required this.servings,
    required this.xpReward,
    required this.ingredients,
    required this.steps,
    required this.gradientA,
    required this.gradientB,
    this.story = '',
    this.storyAm = '',
    this.heatLevel = 2,
    this.tags = const [],
    this.equipment = const [],
    this.isFasting = false,
    this.isVegan = false,
    this.isGlutenFree = false,
    this.isDairyFree = false,
    this.isTraditional = true,
    this.isFamilyRecipe = false,
    this.imageUrl,
    this.authorId,
    this.averageRating = 0,
    this.ratingCount = 0,
    this.numberOfCooks = 0,
  });

  final String id;
  final String title;
  final String titleAm;
  final String subtitle;
  final String subtitleAm;

  /// The cultural note. Written as tradition rather than asserted history —
  /// "in much of Ethiopia it is the dish that ends a fast", not a dated claim.
  final String story;
  final String storyAm;

  final String regionId;
  final String category;
  final Difficulty difficulty;
  final int totalMinutes;
  final int servings;
  final int xpReward;
  final int heatLevel;
  final List<String> tags;
  final List<Ingredient> ingredients;
  final List<String> equipment;
  final List<RecipeStep> steps;
  final String gradientA;
  final String gradientB;
  final bool isFasting;
  final bool isVegan;
  final bool isGlutenFree;
  final bool isDairyFree;
  final bool isTraditional;
  final bool isFamilyRecipe;
  final String? imageUrl;
  final String? authorId;

  /// Maintained server-side; the client never writes these.
  final double averageRating;
  final int ratingCount;
  final int numberOfCooks;

  String localisedTitle({required bool amharic}) => amharic ? titleAm : title;
  String localisedSubtitle({required bool amharic}) =>
      amharic ? subtitleAm : subtitle;
  String localisedStory({required bool amharic}) => amharic ? storyAm : story;

  /// `2h 30m`, `45m`, or `3d` for a multi-day ferment like injera.
  String formattedTime({required bool amharic}) {
    if (totalMinutes >= 1440) {
      final days = (totalMinutes / 1440).round();
      return amharic ? '$days ቀን' : '${days}d';
    }
    if (totalMinutes >= 60) {
      final hours = totalMinutes ~/ 60;
      final minutes = totalMinutes % 60;
      return minutes == 0 ? '${hours}h' : '${hours}h ${minutes}m';
    }
    return '${totalMinutes}m';
  }

  /// Ingredients rescaled for [servings]. The core of serving-size adjustment.
  List<Ingredient> ingredientsFor(int targetServings) {
    if (targetServings == servings || servings == 0) return ingredients;
    final factor = targetServings / servings;
    return ingredients.map((i) => i.scaled(factor)).toList(growable: false);
  }

  /// Steps that run a timer, used to estimate active cooking time.
  Iterable<RecipeStep> get timedSteps => steps.where((s) => s.hasTimer);

  Map<String, dynamic> toJson() => {
        'title': title,
        'titleAm': titleAm,
        'subtitle': subtitle,
        'subtitleAm': subtitleAm,
        'story': story,
        'storyAm': storyAm,
        'regionId': regionId,
        'category': category,
        'difficulty': difficulty.value,
        'totalMinutes': totalMinutes,
        'servings': servings,
        'xpReward': xpReward,
        'heatLevel': heatLevel,
        'tags': tags,
        'ingredients': ingredients.map((i) => i.toJson()).toList(),
        'equipment': equipment,
        'steps': steps.map((s) => s.toJson()).toList(),
        'gradientA': gradientA,
        'gradientB': gradientB,
        'isFasting': isFasting,
        'isVegan': isVegan,
        'isGlutenFree': isGlutenFree,
        'isDairyFree': isDairyFree,
        'isTraditional': isTraditional,
        'isFamilyRecipe': isFamilyRecipe,
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (authorId != null) 'authorId': authorId,
        'averageRating': averageRating,
        'ratingCount': ratingCount,
        'numberOfCooks': numberOfCooks,
        'searchTokens': searchTokens,
        'status': 'published',
      };

  /// Normalised tokens for `array-contains-any` search.
  ///
  /// Firestore has no full-text search, and downloading the collection to
  /// filter locally is exactly what the brief forbids. This handles
  /// single-word lookups; a dedicated search backend slots in behind
  /// `SearchService` when the catalogue outgrows it.
  List<String> get searchTokens {
    final source = <String>[
      title,
      titleAm,
      subtitle,
      subtitleAm,
      category,
      regionId,
      ...tags,
      ...ingredients.map((i) => i.name),
      ...ingredients.map((i) => i.nameAm),
    ];

    final tokens = <String>{};
    for (final text in source) {
      for (final word in text.toLowerCase().split(RegExp(r'[^\wሀ-፿]+'))) {
        if (word.length >= 2) tokens.add(word);
      }
    }
    // Firestore caps array-contains-any at 30 values per query, but the stored
    // array may be longer; 60 keeps documents small without losing much.
    return tokens.take(60).toList(growable: false);
  }

  static Recipe fromJson(String id, Map<String, dynamic> json) => Recipe(
        id: id,
        title: json['title'] as String? ?? '',
        titleAm: json['titleAm'] as String? ?? '',
        subtitle: json['subtitle'] as String? ?? '',
        subtitleAm: json['subtitleAm'] as String? ?? '',
        story: json['story'] as String? ?? '',
        storyAm: json['storyAm'] as String? ?? '',
        regionId: json['regionId'] as String? ?? '',
        category: json['category'] as String? ?? '',
        difficulty: Difficulty.fromValue(json['difficulty'] as int?),
        totalMinutes: json['totalMinutes'] as int? ?? 0,
        servings: json['servings'] as int? ?? 4,
        xpReward: json['xpReward'] as int? ?? 0,
        heatLevel: json['heatLevel'] as int? ?? 2,
        tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ??
            const [],
        ingredients: (json['ingredients'] as List?)
                ?.map((e) => Ingredient.fromJson((e as Map).cast()))
                .toList() ??
            const [],
        equipment:
            (json['equipment'] as List?)?.map((e) => e.toString()).toList() ??
                const [],
        steps: (json['steps'] as List?)
                ?.map((e) => RecipeStep.fromJson((e as Map).cast()))
                .toList() ??
            const [],
        gradientA: json['gradientA'] as String? ?? '#8E1B0F',
        gradientB: json['gradientB'] as String? ?? '#E0522A',
        isFasting: json['isFasting'] as bool? ?? false,
        isVegan: json['isVegan'] as bool? ?? false,
        isGlutenFree: json['isGlutenFree'] as bool? ?? false,
        isDairyFree: json['isDairyFree'] as bool? ?? false,
        isTraditional: json['isTraditional'] as bool? ?? true,
        isFamilyRecipe: json['isFamilyRecipe'] as bool? ?? false,
        imageUrl: json['imageUrl'] as String?,
        authorId: json['authorId'] as String?,
        averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0,
        ratingCount: json['ratingCount'] as int? ?? 0,
        numberOfCooks: json['numberOfCooks'] as int? ?? 0,
      );
}
