import 'package:flameup/features/gamification/domain/level_curve.dart';
import 'package:flameup/features/gamification/domain/mastery.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LevelCurve', () {
    final curve = LevelCurve.standard;

    test('starts everyone at level 1', () {
      expect(curve.levelFor(0), 1);
      expect(
        curve.levelFor(-50),
        1,
        reason: 'negative XP cannot demote below 1',
      );
    });

    test('rises monotonically with XP', () {
      var previous = 1;
      for (var xp = 0; xp < 50000; xp += 250) {
        final level = curve.levelFor(xp);
        expect(
          level,
          greaterThanOrEqualTo(previous),
          reason: 'level fell going from ${xp - 250} to $xp XP',
        );
        previous = level;
      }
    });

    test('each level costs more than the last', () {
      // Early levels should arrive quickly and later ones mean something.
      var previousCost = 0;
      for (var level = 2; level <= 20; level++) {
        final cost = curve.xpForLevel(level) - curve.xpForLevel(level - 1);
        expect(
          cost,
          greaterThan(previousCost),
          reason: 'level $level cost no more than the one before',
        );
        previousCost = cost;
      }
    });

    test('reports XP remaining to the next level', () {
      final level12Start = curve.xpForLevel(12);
      final level13Start = curve.xpForLevel(13);

      expect(curve.xpToNextLevel(level12Start), level13Start - level12Start);
      expect(curve.xpToNextLevel(level13Start - 1), 1);
    });

    test('progress within a level runs 0 to 1', () {
      final start = curve.xpForLevel(10);
      final end = curve.xpForLevel(11);

      expect(curve.progressWithinLevel(start), 0);
      expect(curve.progressWithinLevel((start + end) ~/ 2), closeTo(0.5, 0.05));
      expect(curve.progressWithinLevel(end - 1), lessThan(1));
    });

    test('caps cleanly at the top level', () {
      final beyond = curve.xpForLevel(curve.maxLevel) + 100000;

      expect(curve.levelFor(beyond), curve.maxLevel);
      expect(curve.xpToNextLevel(beyond), 0);
      expect(curve.progressWithinLevel(beyond), 1);
    });

    test('detects a level-up across a boundary', () {
      final boundary = curve.xpForLevel(6);

      expect(curve.didLevelUp(boundary - 10, boundary), isTrue);
      expect(curve.didLevelUp(boundary, boundary + 10), isFalse);
    });

    test('is loaded from config, falling back when malformed', () {
      // A bad curve would silently change everyone's level, so it must not be
      // accepted.
      expect(LevelCurve.fromJson(null).thresholds, curve.thresholds);
      expect(LevelCurve.fromJson(const {}).thresholds, curve.thresholds);
      expect(
        LevelCurve.fromJson(const {'thresholds': <int>[]}).thresholds,
        curve.thresholds,
      );
      expect(
        LevelCurve.fromJson(const {
          'thresholds': [0],
        }).thresholds,
        curve.thresholds,
        reason: 'a one-entry curve is not a curve',
      );

      final custom = LevelCurve.fromJson(const {
        'thresholds': [0, 100, 250, 500],
      });
      expect(custom.maxLevel, 4);
      expect(custom.levelFor(300), 3);
    });
  });

  group('LevelTitles', () {
    test('names every level, in both languages', () {
      for (final level in [1, 5, 10, 12, 28, 40, 60]) {
        expect(LevelTitles.forLevel(level, amharic: false), isNotEmpty);
        expect(LevelTitles.forLevel(level, amharic: true), isNotEmpty);
      }
    });

    test('matches the design at level 12', () {
      expect(LevelTitles.forLevel(12, amharic: false), 'Wot Wanderer');
      expect(LevelTitles.forLevel(12, amharic: true), 'የወጥ መንገደኛ');
    });

    test('holds a title until the next threshold', () {
      expect(
        LevelTitles.forLevel(17, amharic: false),
        LevelTitles.forLevel(10, amharic: false),
      );
      expect(
        LevelTitles.forLevel(18, amharic: false),
        isNot(LevelTitles.forLevel(17, amharic: false)),
      );
    });
  });

  group('MasteryCalculator', () {
    test('mastery comes from repetition, not from finishing once', () {
      // The design's framing: mastery climbs when you repeat a technique.
      expect(MasteryCalculator.levelFor(0), MasteryLevel.none);
      expect(MasteryCalculator.levelFor(1), MasteryLevel.triedIt);
      expect(MasteryCalculator.levelFor(2), MasteryLevel.learning);
      expect(MasteryCalculator.levelFor(3), MasteryLevel.cook);
      expect(MasteryCalculator.levelFor(5), MasteryLevel.skilled);
      expect(MasteryCalculator.levelFor(8), MasteryLevel.expert);
      expect(MasteryCalculator.levelFor(12), MasteryLevel.master);
    });

    test('holds a level between thresholds', () {
      expect(MasteryCalculator.levelFor(4), MasteryLevel.cook);
      expect(MasteryCalculator.levelFor(7), MasteryLevel.skilled);
      expect(MasteryCalculator.levelFor(11), MasteryLevel.expert);
    });

    test('stays at master beyond the top', () {
      expect(MasteryCalculator.levelFor(100), MasteryLevel.master);
      expect(MasteryCalculator.cooksToNext(100), 0);
      expect(MasteryCalculator.progressFor(100), 1);
    });

    test('reports cooks remaining to the next level', () {
      expect(MasteryCalculator.cooksToNext(3), 2); // cook -> skilled at 5
      expect(MasteryCalculator.cooksToNext(5), 3); // skilled -> expert at 8
    });

    test('progress runs 0 to 1 within a level', () {
      expect(MasteryCalculator.progressFor(3), 0);
      expect(MasteryCalculator.progressFor(4), closeTo(0.5, 0.01));
    });

    test('every level is named in both languages', () {
      for (final level in MasteryLevel.values) {
        expect(level.localised(amharic: false), isNotEmpty);
        expect(level.localised(amharic: true), isNotEmpty);
      }
    });
  });

  group('RecipeMastery', () {
    test('a cook advances the count and the level', () {
      const before = RecipeMastery(recipeId: 'doro', cookCount: 2);
      final after = before.afterCook(rating: 4);

      expect(after.cookCount, 3);
      expect(after.level, MasteryLevel.cook);
      expect(after.bestRating, 4);
      expect(after.lastCookedAt, isNotNull);
    });

    test('keeps the best rating rather than the latest', () {
      const before =
          RecipeMastery(recipeId: 'doro', cookCount: 3, bestRating: 5);
      expect(before.afterCook(rating: 2).bestRating, 5);
    });

    test('averages ratings across cooks', () {
      const before = RecipeMastery(
        recipeId: 'doro',
        cookCount: 1,
        averageRating: 4,
      );
      expect(before.afterCook(rating: 2).averageRating, 3);
    });

    test('an unrated cook still counts towards mastery', () {
      const before = RecipeMastery(
        recipeId: 'doro',
        cookCount: 2,
        averageRating: 4,
      );
      final after = before.afterCook();

      expect(after.cookCount, 3);
      expect(after.averageRating, 4, reason: 'the average must not be diluted');
    });

    test('round trips through JSON', () {
      final original = RecipeMastery(
        recipeId: 'doro',
        cookCount: 5,
        bestRating: 5,
        averageRating: 4.2,
        lastCookedAt: DateTime(2026, 3, 1),
      );

      final restored = RecipeMastery.fromJson('doro', original.toJson());

      expect(restored.cookCount, 5);
      expect(restored.bestRating, 5);
      expect(restored.averageRating, closeTo(4.2, 0.001));
      expect(restored.level, MasteryLevel.skilled);
    });

    test('a missing document decodes to nothing cooked', () {
      final restored = RecipeMastery.fromJson('doro', null);
      expect(restored.cookCount, 0);
      expect(restored.level, MasteryLevel.none);
    });
  });
}
