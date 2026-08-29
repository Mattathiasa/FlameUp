import 'package:flameup/features/onboarding/domain/onboarding_state.dart';
import 'package:flameup/features/settings/domain/settings_providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('defaults', () {
    test('skipping still produces a usable profile', () {
      // Skipping must not leave an empty profile: the defaults are a beginner
      // pace, medium heat and no restrictions, which is a reasonable starting
      // point rather than an absence of one.
      const answers = OnboardingAnswers();

      expect(answers.skill, SkillLevel.beginner);
      expect(answers.heat, HeatTolerance.medium);
      expect(answers.dietary, isEmpty);
      expect(answers.completed, isFalse);
    });
  });

  group('serialisation', () {
    test('round trips every answer', () {
      const original = OnboardingAnswers(
        skill: SkillLevel.grewUpOnThis,
        heat: HeatTolerance.mitmita,
        dietary: {DietaryFlag.fasting, DietaryFlag.quick},
        language: AppLanguage.amharic,
        completed: true,
      );

      final restored = OnboardingAnswers.fromJson(original.toJson());

      expect(restored.skill, SkillLevel.grewUpOnThis);
      expect(restored.heat, HeatTolerance.mitmita);
      expect(
        restored.dietary,
        {DietaryFlag.fasting, DietaryFlag.quick},
      );
      expect(restored.language, AppLanguage.amharic);
      expect(restored.completed, isTrue);
    });

    test('stores enums as ints so reordering cannot corrupt saved profiles',
        () {
      const answers = OnboardingAnswers(
        skill: SkillLevel.gettingThere,
        heat: HeatTolerance.hot,
      );
      final json = answers.toJson();

      expect(json['skillLevel'], 1);
      expect(json['heatTolerance'], 3);
    });

    test('dietary flags serialise as the design keys', () {
      const answers = OnboardingAnswers(
        dietary: {DietaryFlag.fasting, DietaryFlag.glutenFree},
      );

      expect(answers.toJson()['dietary'], containsAll(['dFast', 'dGluten']));
    });

    test('a null document decodes to defaults', () {
      final answers = OnboardingAnswers.fromJson(null);
      expect(answers.skill, SkillLevel.beginner);
      expect(answers.completed, isFalse);
    });

    test('an unknown dietary key is dropped, not crashed on', () {
      // Forward compatibility: an older build reading a newer profile must
      // not fail because it does not recognise a flag.
      final answers = OnboardingAnswers.fromJson({
        'dietary': ['dFast', 'dSomethingNew'],
      });

      expect(answers.dietary, {DietaryFlag.fasting});
    });

    test('an out-of-range enum value falls back rather than throwing', () {
      final answers = OnboardingAnswers.fromJson({
        'skillLevel': 99,
        'heatTolerance': -1,
      });

      expect(answers.skill, SkillLevel.beginner);
      expect(answers.heat, HeatTolerance.medium);
    });
  });

  group('copyWith', () {
    test('changes one field and leaves the rest', () {
      const original = OnboardingAnswers(
        skill: SkillLevel.gettingThere,
        dietary: {DietaryFlag.raw},
      );

      final updated = original.copyWith(heat: HeatTolerance.hot);

      expect(updated.heat, HeatTolerance.hot);
      expect(updated.skill, SkillLevel.gettingThere);
      expect(updated.dietary, {DietaryFlag.raw});
    });
  });

  group('heat tolerance', () {
    test('has the five levels the design names', () {
      expect(HeatTolerance.values, hasLength(5));
      expect(HeatTolerance.values.first, HeatTolerance.mild);
      expect(HeatTolerance.values.last, HeatTolerance.mitmita);
    });
  });
}
