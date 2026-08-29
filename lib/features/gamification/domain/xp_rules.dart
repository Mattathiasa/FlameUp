import '../../recipes/domain/recipe.dart';
import 'mastery.dart';

/// Why XP was awarded. Every grant names its reason, so a total can always be
/// explained rather than merely displayed.
enum XpReason {
  recipeCompleted,
  firstTimeCooking,
  questCompleted,
  achievementUnlocked,
  challengeWon,
  familyRecipePublished,
  streakMilestone,
}

/// One XP grant.
class XpAward {
  const XpAward({
    required this.amount,
    required this.reason,
    this.detail,
  });

  final int amount;
  final XpReason reason;

  /// What it was for — a recipe id, a quest id — for the breakdown shown to
  /// the user and for auditing a total.
  final String? detail;

  Map<String, dynamic> toJson() => {
        'amount': amount,
        'reason': reason.name,
        if (detail != null) 'detail': detail,
      };
}

/// Works out what an action is worth.
///
/// Pure and config-driven. The same rules are mirrored in the Cloud Function
/// that actually writes XP — this side computes the *expected* award so the UI
/// can show a plausible figure, but the server's answer is the one that counts.
class XpRules {
  const XpRules({
    this.firstTimeBonus = 50,
    this.streakMilestoneBonus = 100,
    this.streakMilestones = const {7, 14, 30, 60, 100},
    this.repeatDecayFloor = 0.25,
  });

  /// Cooking a dish for the first time is worth more than the tenth time.
  final int firstTimeBonus;

  final int streakMilestoneBonus;
  final Set<int> streakMilestones;

  /// Repeat cooks are worth progressively less, down to this fraction.
  ///
  /// Without decay, the optimal strategy is to cook the highest-XP dish
  /// forever, which is the opposite of a discovery app. It never reaches zero,
  /// because repetition is how mastery is earned and should still count.
  final double repeatDecayFloor;

  /// What finishing [recipe] is worth, given how often it has been cooked.
  List<XpAward> forCompletedCook({
    required Recipe recipe,
    required RecipeMastery mastery,
    required int streakAfter,
  }) {
    final awards = <XpAward>[];

    final decayed = (recipe.xpReward * _decayFor(mastery.cookCount)).round();
    awards.add(
      XpAward(
        amount: decayed,
        reason: XpReason.recipeCompleted,
        detail: recipe.id,
      ),
    );

    if (mastery.cookCount == 0) {
      awards.add(
        XpAward(
          amount: firstTimeBonus,
          reason: XpReason.firstTimeCooking,
          detail: recipe.id,
        ),
      );
    }

    if (streakMilestones.contains(streakAfter)) {
      awards.add(
        XpAward(
          amount: streakMilestoneBonus,
          reason: XpReason.streakMilestone,
          detail: '$streakAfter',
        ),
      );
    }

    return awards;
  }

  /// Full value for the first three cooks, then a gentle decline to the floor.
  double _decayFor(int previousCooks) {
    if (previousCooks < 3) return 1;
    final decayed = 1 - (previousCooks - 2) * 0.1;
    return decayed < repeatDecayFloor ? repeatDecayFloor : decayed;
  }

  int totalOf(List<XpAward> awards) =>
      awards.fold(0, (sum, award) => sum + award.amount);

  static XpRules fromJson(Map<String, dynamic>? json) {
    if (json == null) return const XpRules();
    return XpRules(
      firstTimeBonus: json['firstTimeBonus'] as int? ?? 50,
      streakMilestoneBonus: json['streakMilestoneBonus'] as int? ?? 100,
      streakMilestones: (json['streakMilestones'] as List?)
              ?.map((e) => int.tryParse(e.toString()))
              .whereType<int>()
              .toSet() ??
          const {7, 14, 30, 60, 100},
      repeatDecayFloor: (json['repeatDecayFloor'] as num?)?.toDouble() ?? 0.25,
    );
  }
}
