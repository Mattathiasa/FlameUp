import 'package:cached_network_image/cached_network_image.dart';
import 'package:flameup/features/recipes/domain/recipe.dart';
import 'package:flameup/features/recipes/presentation/dish_photo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Recipe _recipe({String? imageUrl}) => Recipe(
      id: 'shiro',
      title: 'Shiro',
      titleAm: 'ሽሮ',
      subtitle: 'Silky spiced chickpea stew',
      subtitleAm: 'ሽሮ በበርበሬ',
      regionId: 'addis',
      category: 'vegan',
      difficulty: Difficulty.beginner,
      totalMinutes: 30,
      servings: 2,
      xpReward: 40,
      ingredients: const [],
      steps: const [],
      gradientA: '#C96F2E',
      gradientB: '#7A2E0E',
      imageUrl: imageUrl,
    );

void main() {
  group('DishPhoto', () {
    testWidgets('no imageUrl renders the recipe gradient, nothing else',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: DishPhoto(recipe: _recipe()))),
      );

      // The fallback is a gradient built from the recipe's own colors.
      final decorated = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(DishPhoto),
          matching: find.byType(DecoratedBox),
        ),
      );
      final gradient =
          (decorated.decoration as BoxDecoration).gradient as LinearGradient;
      expect(gradient.colors, contains(const Color(0xFFC96F2E)));
      expect(find.byType(Image), findsNothing);
      expect(find.byType(ClipRRect), findsNothing);
    });

    testWidgets('empty-string imageUrl also falls back to the gradient',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DishPhoto(recipe: _recipe(imageUrl: ''))),
        ),
      );

      expect(find.byType(ClipRRect), findsNothing);
    });

    testWidgets(
        'an imageUrl mounts a CachedNetworkImage carrying the recipe URL',
        (tester) async {
      const url =
          'https://upload.wikimedia.org/wikipedia/commons/9/9d/Shiro.jpg';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: DishPhoto(recipe: _recipe(imageUrl: url))),
        ),
      );
      await tester.pump();

      expect(find.byType(ClipRRect), findsOneWidget);
      final cached = tester.widget<CachedNetworkImage>(
        find.byType(CachedNetworkImage),
      );
      expect(cached.imageUrl, url);
      expect(cached.fadeInDuration, const Duration(milliseconds: 250));
    });

    testWidgets('a dead link degrades to the gradient, never a broken glyph',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DishPhoto(
              recipe: _recipe(
                imageUrl: 'https://127.0.0.1:1/nope.jpg', // fails instantly
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // The errorWidget path rebuilt to the gradient fallback.
      expect(find.byIcon(Icons.broken_image), findsNothing);
      final decorated = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(DishPhoto),
          matching: find.byType(DecoratedBox),
        ),
      );
      final gradient =
          (decorated.decoration as BoxDecoration).gradient as LinearGradient;
      expect(gradient.colors, contains(const Color(0xFFC96F2E)));
    });
  });
}
