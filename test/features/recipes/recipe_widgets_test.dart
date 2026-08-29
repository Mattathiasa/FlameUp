import 'dart:convert';
import 'dart:io';

import 'package:flameup/core/services/local_store.dart';
import 'package:flameup/core/theme/app_theme.dart';
import 'package:flameup/features/recipes/domain/recipe.dart';
import 'package:flameup/features/recipes/domain/recipe_providers.dart';
import 'package:flameup/features/recipes/presentation/dish_card.dart';
import 'package:flameup/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Recipe loadDoro() {
  final raw = File('assets/seed/recipes.json').readAsStringSync();
  final json = jsonDecode(raw) as Map<String, dynamic>;
  final recipes = json['recipes'] as Map<String, dynamic>;
  return Recipe.fromJson('doro', (recipes['doro'] as Map).cast());
}

Widget host(
  Widget child, {
  Brightness brightness = Brightness.dark,
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: [
      // The card only reads the language, so a real LocalStore is not needed.
      isAmharicProvider.overrideWithValue(locale.languageCode == 'am'),
      localStoreProvider.overrideWith(
        (ref) => throw UnimplementedError('not needed for this test'),
      ),
    ],
    child: MaterialApp(
      theme: brightness == Brightness.dark ? AppTheme.dark : AppTheme.light,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  late Recipe doro;

  setUpAll(() => doro = loadDoro());

  group('DishCard', () {
    testWidgets('shows the dish, its time and its XP', (tester) async {
      await tester.pumpWidget(host(DishCard(recipe: doro)));

      expect(find.text('Doro Wat'), findsOneWidget);
      expect(find.text('2h'), findsOneWidget);
      expect(find.text('+240'), findsOneWidget);
    });

    testWidgets('switches to Amharic with the locale', (tester) async {
      await tester.pumpWidget(
        host(DishCard(recipe: doro), locale: const Locale('am')),
      );

      expect(find.text('ዶሮ ወጥ'), findsOneWidget);
      expect(find.text('Doro Wat'), findsNothing);
    });

    testWidgets('renders in both themes without error', (tester) async {
      for (final brightness in Brightness.values) {
        await tester.pumpWidget(
          host(DishCard(recipe: doro), brightness: brightness),
        );
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('skips the backdrop blur, since cards sit in scrolling rails',
        (tester) async {
      // A BackdropFilter per card is the most expensive thing on the screen.
      await tester.pumpWidget(host(DishCard(recipe: doro)));
      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('describes itself to a screen reader', (tester) async {
      await tester.pumpWidget(host(DishCard(recipe: doro)));

      final node = tester.getSemantics(find.byType(DishCard));
      expect(node.label, contains('Doro Wat'));
      expect(node.label, contains('2h'));
    });

    testWidgets('marks a fasting dish', (tester) async {
      final raw = File('assets/seed/recipes.json').readAsStringSync();
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final shiro = Recipe.fromJson(
        'shiro',
        ((json['recipes'] as Map)['shiro'] as Map).cast(),
      );

      await tester.pumpWidget(host(DishCard(recipe: shiro)));
      expect(find.text('Fasting'), findsOneWidget);
    });
  });

  group('DishListTile', () {
    testWidgets('renders the dish in a row layout', (tester) async {
      await tester.pumpWidget(
        host(SizedBox(width: 360, child: DishListTile(recipe: doro))),
      );

      expect(find.text('Doro Wat'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('handles long Amharic titles without overflowing',
        (tester) async {
      await tester.pumpWidget(
        host(
          SizedBox(width: 320, child: DishListTile(recipe: doro)),
          locale: const Locale('am'),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
