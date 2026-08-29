import '../../settings/domain/settings_providers.dart';

/// How well someone knows the kitchen. Sets the pace of their first ten dishes.
enum SkillLevel {
  beginner,
  gettingThere,
  grewUpOnThis;

  /// Stored as an int so the Firestore document stays stable if the enum is
  /// ever reordered.
  int get value => index;

  static SkillLevel fromValue(int? value) =>
      SkillLevel.values.elementAtOrNull(value ?? 0) ?? SkillLevel.beginner;
}

/// Berbere is a spectrum, not a switch — five steps from mild to mitmita.
enum HeatTolerance {
  mild,
  warm,
  medium,
  hot,
  mitmita;

  int get value => index;

  static HeatTolerance fromValue(int? value) =>
      HeatTolerance.values.elementAtOrNull(value ?? 2) ?? HeatTolerance.medium;
}

/// Dietary preferences. Stored as string keys rather than a bitfield so the
/// set can grow without a migration.
enum DietaryFlag {
  fasting('dFast'),
  glutenFree('dGluten'),
  dairyFree('dDairy'),
  meatLover('dMeat'),
  raw('dRaw'),
  quick('dQuick');

  const DietaryFlag(this.key);

  /// Matches the design's own key, so the label comes straight from the
  /// generated localisations.
  final String key;

  static DietaryFlag? fromKey(String key) =>
      DietaryFlag.values.where((f) => f.key == key).firstOrNull;
}

/// Everything onboarding collects.
///
/// Persisted locally as it is answered, so closing the app mid-flow resumes
/// where it stopped rather than starting over, and mirrored to `users/{uid}`
/// on completion so it survives a reinstall.
class OnboardingAnswers {
  const OnboardingAnswers({
    this.skill = SkillLevel.beginner,
    this.heat = HeatTolerance.medium,
    this.dietary = const {},
    this.language,
    this.completed = false,
  });

  final SkillLevel skill;
  final HeatTolerance heat;
  final Set<DietaryFlag> dietary;

  /// Null until the user changes it; the device locale is used meanwhile.
  final AppLanguage? language;

  final bool completed;

  OnboardingAnswers copyWith({
    SkillLevel? skill,
    HeatTolerance? heat,
    Set<DietaryFlag>? dietary,
    AppLanguage? language,
    bool? completed,
  }) =>
      OnboardingAnswers(
        skill: skill ?? this.skill,
        heat: heat ?? this.heat,
        dietary: dietary ?? this.dietary,
        language: language ?? this.language,
        completed: completed ?? this.completed,
      );

  Map<String, dynamic> toJson() => {
        'skillLevel': skill.value,
        'heatTolerance': heat.value,
        'dietary': dietary.map((f) => f.key).toList(),
        if (language != null) 'preferredLanguage': language!.code,
        'onboardingComplete': completed,
      };

  static OnboardingAnswers fromJson(Map<String, dynamic>? json) {
    if (json == null) return const OnboardingAnswers();
    final flags = (json['dietary'] as List?)
            ?.map((e) => DietaryFlag.fromKey(e.toString()))
            .whereType<DietaryFlag>()
            .toSet() ??
        <DietaryFlag>{};
    return OnboardingAnswers(
      skill: SkillLevel.fromValue(json['skillLevel'] as int?),
      heat: HeatTolerance.fromValue(json['heatTolerance'] as int?),
      dietary: flags,
      language: json['preferredLanguage'] == null
          ? null
          : AppLanguage.fromCode(json['preferredLanguage'] as String?),
      completed: json['onboardingComplete'] as bool? ?? false,
    );
  }
}

extension _ElementAtOrNull<T> on List<T> {
  T? elementAtOrNull(int index) =>
      index >= 0 && index < length ? this[index] : null;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
