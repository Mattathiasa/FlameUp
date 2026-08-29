import '../../recipes/domain/recipe.dart';
import 'mastery.dart';

/// What an achievement rule looks at.
///
/// A closed set, evaluated by data rather than by a branch per badge: adding a
/// badge is a row in a table, not a new code path (brief §27).
enum AchievementMetric {
  totalCooks,
  distinctRecipes,
  distinctRegions,
  fastingDishes,
  currentStreak,
  longestStreak,
  masteryAtOrAbove,
  familyRecipesPublished,
  specificRecipe,
  timedStepsHeld,
}

/// A snapshot of everything the rules can be evaluated against.
class ProgressSnapshot {
  const ProgressSnapshot({
    this.totalCooks = 0,
    this.distinctRecipeIds = const {},
    this.distinctRegionIds = const {},
    this.fastingDishesCooked = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.masteryByRecipe = const {},
    this.familyRecipesPublished = 0,
    this.timedStepsHeld = 0,
  });

  final int totalCooks;
  final Set<String> distinctRecipeIds;
  final Set<String> distinctRegionIds;
  final int fastingDishesCooked;
  final int currentStreak;
  final int longestStreak;
  final Map<String, MasteryLevel> masteryByRecipe;
  final int familyRecipesPublished;

  /// Timed steps run to completion without skipping — what "Onion Patience"
  /// is actually measuring.
  final int timedStepsHeld;

  ProgressSnapshot afterCook(Recipe recipe, {int timedStepsCompleted = 0}) =>
      ProgressSnapshot(
        totalCooks: totalCooks + 1,
        distinctRecipeIds: {...distinctRecipeIds, recipe.id},
        distinctRegionIds: {...distinctRegionIds, recipe.regionId},
        fastingDishesCooked: fastingDishesCooked + (recipe.isFasting ? 1 : 0),
        currentStreak: currentStreak,
        longestStreak: longestStreak,
        masteryByRecipe: masteryByRecipe,
        familyRecipesPublished: familyRecipesPublished,
        timedStepsHeld: timedStepsHeld + timedStepsCompleted,
      );
}

/// A badge and the condition that earns it.
class AchievementRule {
  const AchievementRule({
    required this.id,
    required this.name,
    required this.nameAm,
    required this.metric,
    required this.threshold,
    this.colour = '#FF6A2B',
    this.recipeId,
    this.masteryLevel,
    this.xpReward = 100,
  });

  final String id;
  final String name;
  final String nameAm;
  final AchievementMetric metric;
  final int threshold;
  final String colour;

  /// For [AchievementMetric.specificRecipe].
  final String? recipeId;

  /// For [AchievementMetric.masteryAtOrAbove]: the level a dish must reach.
  ///
  /// Separate from [threshold], which counts *how many* dishes must reach it.
  /// Conflating the two made the comparison unsatisfiable -- "1 dish at
  /// Skilled" would have been read as "4 dishes".
  final MasteryLevel? masteryLevel;

  final int xpReward;

  String localisedName({required bool amharic}) => amharic ? nameAm : name;

  /// How far along this badge is, 0–1.
  double progressWith(ProgressSnapshot snapshot) {
    if (threshold <= 0) return 1;
    return (valueIn(snapshot) / threshold).clamp(0.0, 1.0);
  }

  bool isEarnedBy(ProgressSnapshot snapshot) => valueIn(snapshot) >= threshold;

  /// The snapshot value this rule measures.
  int valueIn(ProgressSnapshot snapshot) => switch (metric) {
        AchievementMetric.totalCooks => snapshot.totalCooks,
        AchievementMetric.distinctRecipes => snapshot.distinctRecipeIds.length,
        AchievementMetric.distinctRegions => snapshot.distinctRegionIds.length,
        AchievementMetric.fastingDishes => snapshot.fastingDishesCooked,
        AchievementMetric.currentStreak => snapshot.currentStreak,
        AchievementMetric.longestStreak => snapshot.longestStreak,
        AchievementMetric.familyRecipesPublished =>
          snapshot.familyRecipesPublished,
        AchievementMetric.timedStepsHeld => snapshot.timedStepsHeld,
        AchievementMetric.specificRecipe =>
          snapshot.distinctRecipeIds.contains(recipeId) ? 1 : 0,
        AchievementMetric.masteryAtOrAbove => _masteryValue(snapshot),
      };

  int _masteryValue(ProgressSnapshot snapshot) {
    final id = recipeId;
    if (id != null) {
      return (snapshot.masteryByRecipe[id]?.index ?? 0) >= threshold
          ? threshold
          : 0;
    }
    // No recipe named: count how many dishes reached the level.
    return snapshot.masteryByRecipe.values
        .where((level) => level.index >= threshold)
        .length;
  }
}

/// The badge catalogue, from the design's nine plus the brief's list.
abstract final class Achievements {
  static const List<AchievementRule> all = [
    AchievementRule(
      id: 'first_flame',
      name: 'First Flame',
      nameAm: 'የመጀመሪያ እሳት',
      metric: AchievementMetric.totalCooks,
      threshold: 1,
      colour: '#FF6A2B',
      xpReward: 50,
    ),
    AchievementRule(
      id: 'onion_patience',
      name: 'Onion Patience',
      nameAm: 'የሽንኩርት ትዕግሥት',
      metric: AchievementMetric.timedStepsHeld,
      threshold: 1,
      colour: '#F0B33C',
    ),
    AchievementRule(
      id: 'seven_on_a_plate',
      name: 'Seven on a Plate',
      nameAm: 'ሰባት በአንድ ሰሃን',
      metric: AchievementMetric.specificRecipe,
      threshold: 1,
      recipeId: 'beyay',
      colour: '#4FA766',
      xpReward: 200,
    ),
    AchievementRule(
      id: 'mitmita_survivor',
      name: 'Mitmita Survivor',
      nameAm: 'የሚጥሚጣ ተራፊ',
      metric: AchievementMetric.specificRecipe,
      threshold: 1,
      recipeId: 'kitfo',
      colour: '#C0301C',
    ),
    AchievementRule(
      id: 'region_runner',
      name: 'Region Runner',
      nameAm: 'የክልል ሯጭ',
      metric: AchievementMetric.distinctRegions,
      threshold: 4,
      colour: '#8B5E3C',
      xpReward: 150,
    ),
    AchievementRule(
      id: 'three_day_ferment',
      name: 'Three-Day Ferment',
      nameAm: 'የሦስት ቀን ማሸት',
      metric: AchievementMetric.specificRecipe,
      threshold: 1,
      recipeId: 'injera',
      colour: '#C7A56A',
      xpReward: 300,
    ),
    AchievementRule(
      id: 'three_rounds',
      name: 'Three Rounds',
      nameAm: 'ሦስት ዙር ቡና',
      metric: AchievementMetric.specificRecipe,
      threshold: 1,
      recipeId: 'buna',
      colour: '#6B4B2A',
    ),
    AchievementRule(
      id: 'grandma_approved',
      name: 'Grandma Approved',
      nameAm: 'አያት አጸደቀችው',
      metric: AchievementMetric.familyRecipesPublished,
      threshold: 1,
      colour: '#93304A',
      xpReward: 250,
    ),
    AchievementRule(
      id: 'thirty_day_fire',
      name: 'Thirty-Day Fire',
      nameAm: 'የ30 ቀን እሳት',
      metric: AchievementMetric.longestStreak,
      threshold: 30,
      colour: '#DE3A18',
      xpReward: 500,
    ),
    AchievementRule(
      id: 'fasting_table',
      name: 'Fasting Table',
      nameAm: 'የጾም ማዕድ',
      metric: AchievementMetric.fastingDishes,
      threshold: 12,
      colour: '#2E9E5B',
      xpReward: 300,
    ),
    AchievementRule(
      id: 'home_chef',
      name: 'Home Chef',
      nameAm: 'የቤት ሼፍ',
      metric: AchievementMetric.distinctRecipes,
      threshold: 10,
      colour: '#E0522A',
      xpReward: 200,
    ),
    AchievementRule(
      id: 'wot_warrior',
      name: 'Wot Warrior',
      nameAm: 'የወጥ ተዋጊ',
      metric: AchievementMetric.masteryAtOrAbove,
      masteryLevel: MasteryLevel.skilled,
      threshold: 1, // one dish at Skilled or above
      colour: '#8E1B0F',
      xpReward: 250,
    ),
  ];

  static AchievementRule? byId(String id) =>
      all.where((rule) => rule.id == id).firstOrNull;
}

/// Decides which badges a snapshot has newly earned.
abstract final class AchievementEvaluator {
  /// Badges earned by [snapshot] that are not in [alreadyUnlocked].
  ///
  /// Returning only the *new* ones is what stops a badge being announced —
  /// and rewarded — twice.
  static List<AchievementRule> newlyEarned({
    required ProgressSnapshot snapshot,
    required Set<String> alreadyUnlocked,
    List<AchievementRule> rules = Achievements.all,
  }) =>
      rules
          .where(
            (rule) =>
                !alreadyUnlocked.contains(rule.id) && rule.isEarnedBy(snapshot),
          )
          .toList(growable: false);

  /// Everything, with its progress — for the achievements screen, which shows
  /// locked badges as well as earned ones.
  static List<(AchievementRule, double, bool)> allWithProgress({
    required ProgressSnapshot snapshot,
    required Set<String> unlocked,
    List<AchievementRule> rules = Achievements.all,
  }) =>
      rules
          .map(
            (rule) => (
              rule,
              rule.progressWith(snapshot),
              unlocked.contains(rule.id) || rule.isEarnedBy(snapshot),
            ),
          )
          .toList(growable: false);
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
