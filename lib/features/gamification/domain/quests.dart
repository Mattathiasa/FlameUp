import '../../recipes/domain/recipe.dart';

/// When a quest resets.
enum QuestCadence {
  daily,
  weekly,
  seasonal;

  /// When a quest issued at [from] stops counting.
  ///
  /// Boundaries are local calendar dates, for the same reason streaks are:
  /// "today" means where the user is, not UTC.
  DateTime expiryFrom(DateTime from) => switch (this) {
        QuestCadence.daily => DateTime(from.year, from.month, from.day)
            .add(const Duration(days: 1)),
        QuestCadence.weekly => DateTime(from.year, from.month, from.day)
            .add(Duration(days: 8 - from.weekday)),
        // Fasting seasons run for weeks; 55 days covers the longest.
        QuestCadence.seasonal => DateTime(from.year, from.month, from.day)
            .add(const Duration(days: 55)),
      };
}

/// What a quest is counting.
enum QuestGoal {
  cookAnyDish,
  cookFastingDish,
  cookFromNewRegion,
  cookNewRecipe,
  photographDish,
  cookFamilyRecipe,
}

/// A quest definition. Data, so the set can change without a build.
class QuestRule {
  const QuestRule({
    required this.id,
    required this.cadence,
    required this.goal,
    required this.target,
    required this.name,
    required this.nameAm,
    this.xpReward = 60,
    this.colour = '#FF6A2B',
  });

  final String id;
  final QuestCadence cadence;
  final QuestGoal goal;
  final int target;
  final String name;
  final String nameAm;
  final int xpReward;
  final String colour;

  String localisedName({required bool amharic}) => amharic ? nameAm : name;

  /// Whether finishing [recipe] counts towards this quest.
  bool countsFor(
    Recipe recipe, {
    required Set<String> regionsAlreadyCooked,
    required Set<String> recipesAlreadyCooked,
    bool photographed = false,
  }) =>
      switch (goal) {
        QuestGoal.cookAnyDish => true,
        QuestGoal.cookFastingDish => recipe.isFasting,
        QuestGoal.cookFromNewRegion =>
          !regionsAlreadyCooked.contains(recipe.regionId),
        QuestGoal.cookNewRecipe => !recipesAlreadyCooked.contains(recipe.id),
        QuestGoal.photographDish => photographed,
        QuestGoal.cookFamilyRecipe => recipe.isFamilyRecipe,
      };
}

/// A user's progress on one quest.
class QuestProgress {
  const QuestProgress({
    required this.questId,
    required this.progress,
    required this.target,
    required this.expiresAt,
    this.completedAt,
    this.rewardedAt,
  });

  final String questId;
  final int progress;
  final int target;
  final DateTime expiresAt;
  final DateTime? completedAt;

  /// When the XP was actually granted. Separate from [completedAt] so a
  /// completion whose reward has not yet reached the server is not mistaken
  /// for one that has — which is what prevents paying twice.
  final DateTime? rewardedAt;

  bool get isComplete => progress >= target;
  bool get isRewarded => rewardedAt != null;
  double get fraction => target == 0 ? 0 : (progress / target).clamp(0.0, 1.0);

  bool hasExpired(DateTime now) => !now.isBefore(expiresAt);

  QuestProgress copyWith({
    int? progress,
    DateTime? completedAt,
    DateTime? rewardedAt,
  }) =>
      QuestProgress(
        questId: questId,
        progress: progress ?? this.progress,
        target: target,
        expiresAt: expiresAt,
        completedAt: completedAt ?? this.completedAt,
        rewardedAt: rewardedAt ?? this.rewardedAt,
      );

  Map<String, dynamic> toJson() => {
        'questId': questId,
        'progress': progress,
        'target': target,
        'expiresAt': expiresAt.toIso8601String(),
        if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
        if (rewardedAt != null) 'rewardedAt': rewardedAt!.toIso8601String(),
      };

  static QuestProgress? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final questId = json['questId'] as String?;
    final expiresAt = DateTime.tryParse(json['expiresAt'] as String? ?? '');
    if (questId == null || expiresAt == null) return null;

    return QuestProgress(
      questId: questId,
      progress: json['progress'] as int? ?? 0,
      target: json['target'] as int? ?? 1,
      expiresAt: expiresAt,
      completedAt: DateTime.tryParse(json['completedAt'] as String? ?? ''),
      rewardedAt: DateTime.tryParse(json['rewardedAt'] as String? ?? ''),
    );
  }
}

/// The quest catalogue, from the design's four plus the brief's examples.
abstract final class Quests {
  static const List<QuestRule> all = [
    QuestRule(
      id: 'daily_fasting',
      cadence: QuestCadence.daily,
      goal: QuestGoal.cookFastingDish,
      target: 1,
      name: 'Cook one fasting dish',
      nameAm: 'አንድ የጾም ምግብ ያብስሉ',
      colour: '#2E9E5B',
    ),
    QuestRule(
      id: 'daily_photo',
      cadence: QuestCadence.daily,
      goal: QuestGoal.photographDish,
      target: 1,
      name: 'Photograph what you made',
      nameAm: 'የሠሩትን ፎቶ ያንሱ',
      xpReward: 20,
      colour: '#F0B33C',
    ),
    QuestRule(
      id: 'weekly_regions',
      cadence: QuestCadence.weekly,
      goal: QuestGoal.cookFromNewRegion,
      target: 3,
      name: 'Three regions in seven days',
      nameAm: 'በሰባት ቀናት ሦስት ክልሎች',
      xpReward: 200,
      colour: '#FF6A2B',
    ),
    QuestRule(
      id: 'weekly_new',
      cadence: QuestCadence.weekly,
      goal: QuestGoal.cookNewRecipe,
      target: 3,
      name: "Cook three dishes you haven't tried",
      nameAm: 'ያልሞከሯቸውን ሦስት ምግቦች ያብስሉ',
      xpReward: 180,
      colour: '#E0522A',
    ),
    QuestRule(
      id: 'season_fasting_twelve',
      cadence: QuestCadence.seasonal,
      goal: QuestGoal.cookFastingDish,
      target: 12,
      name: 'Twelve fasting dishes',
      nameAm: 'አሥራ ሁለት የጾም ምግቦች',
      xpReward: 500,
      colour: '#8B5E3C',
    ),
  ];

  static QuestRule? byId(String id) =>
      all.where((rule) => rule.id == id).firstOrNull;
}

/// Advances quest progress when a dish is finished.
abstract final class QuestEvaluator {
  /// Progress after cooking [recipe].
  ///
  /// Expired quests are left untouched rather than advanced: a quest that ran
  /// out yesterday should not quietly accept today's cook.
  static List<QuestProgress> afterCook({
    required List<QuestProgress> active,
    required Recipe recipe,
    required Set<String> regionsAlreadyCooked,
    required Set<String> recipesAlreadyCooked,
    bool photographed = false,
    DateTime? now,
    List<QuestRule> rules = Quests.all,
  }) {
    final at = now ?? DateTime.now();

    return active.map((progress) {
      if (progress.hasExpired(at) || progress.isComplete) return progress;

      final rule = rules.where((r) => r.id == progress.questId).firstOrNull;
      if (rule == null) return progress;

      final counts = rule.countsFor(
        recipe,
        regionsAlreadyCooked: regionsAlreadyCooked,
        recipesAlreadyCooked: recipesAlreadyCooked,
        photographed: photographed,
      );
      if (!counts) return progress;

      final next = progress.progress + 1;
      return progress.copyWith(
        progress: next,
        completedAt: next >= progress.target ? at : null,
      );
    }).toList(growable: false);
  }

  /// Quests completed but not yet paid.
  ///
  /// The reward is claimed against this list, and `rewardedAt` is what stops
  /// it being claimed twice.
  static List<QuestProgress> awaitingReward(List<QuestProgress> quests) =>
      quests
          .where((q) => q.isComplete && !q.isRewarded)
          .toList(growable: false);

  /// Issue a fresh set for [cadence], replacing anything expired.
  static List<QuestProgress> issue({
    required QuestCadence cadence,
    required DateTime now,
    List<QuestRule> rules = Quests.all,
  }) =>
      rules
          .where((rule) => rule.cadence == cadence)
          .map(
            (rule) => QuestProgress(
              questId: rule.id,
              progress: 0,
              target: rule.target,
              expiresAt: cadence.expiryFrom(now),
            ),
          )
          .toList(growable: false);
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
