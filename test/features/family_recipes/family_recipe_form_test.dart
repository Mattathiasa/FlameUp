import 'dart:convert';

import 'package:flameup/core/cache/pending_mutation.dart';
import 'package:flameup/core/errors/failure.dart';
import 'package:flameup/core/result/result.dart';
import 'package:flameup/core/services/analytics_service.dart';
import 'package:flameup/core/services/local_store.dart';
import 'package:flameup/core/theme/app_theme.dart';
import 'package:flameup/features/auth/domain/auth_providers.dart';
import 'package:flameup/features/family_recipes/data/family_recipe_repository.dart';
import 'package:flameup/features/family_recipes/domain/family_recipe.dart';
import 'package:flameup/features/family_recipes/presentation/family_recipe_form.dart';
import 'package:flameup/features/recipes/domain/recipe_providers.dart';
import 'package:flameup/features/settings/domain/settings_providers.dart';
import 'package:flameup/l10n/generated/app_localizations.dart';
import 'package:flameup/shared/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FamilyRecipe ingredients and steps', () {
    test('parses ingredients and splits steps into lines', () {
      final recipe = FamilyRecipe.fromJson('r1', {
        'authorId': 'u1',
        'status': 'pending',
        'title': 'Shiro',
        'ingredientsText': '2 cups shiro powder\n3 tbsp berbere',
        'stepsText': 'Simmer the water.\n\nWhisk in the powder.\nSeason.',
      });

      expect(recipe, isNotNull);
      expect(recipe!.ingredientsText, '2 cups shiro powder\n3 tbsp berbere');
      expect(
        recipe.stepLines,
        ['Simmer the water.', 'Whisk in the powder.', 'Season.'],
      );
    });

    test('a legacy single-blob submission still yields its one step', () {
      final recipe = FamilyRecipe.fromJson('r2', {
        'authorId': 'u1',
        'status': 'published',
        'title': 'Old submission',
        'stepsText': 'One blob, typed long ago.',
      });

      expect(recipe!.stepLines, ['One blob, typed long ago.']);
    });

    test('missing fields default instead of crashing', () {
      final recipe = FamilyRecipe.fromJson('r3', {
        'authorId': 'u1',
        'status': 'draft',
        'title': 'Barely started',
      });

      expect(recipe!.ingredientsText, isEmpty);
      expect(recipe.stepLines, isEmpty);
    });
  });

  group('settings: theme and language persist and propagate', () {
    late _MemoryStore store;
    late ProviderContainer container;

    setUp(() {
      store = _MemoryStore();
      container = ProviderContainer(
        overrides: [localStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
    });

    test('theme mode persists across a fresh read', () async {
      expect(container.read(themeModeProvider), ThemeMode.system);

      await container.read(themeModeProvider.notifier).set(ThemeMode.dark);
      expect(container.read(themeModeProvider), ThemeMode.dark);

      // The write must survive a controller rebuilt from scratch — the whole
      // point of persisting rather than keeping it in memory.
      container.dispose();
      container = ProviderContainer(
        overrides: [localStoreProvider.overrideWithValue(store)],
      );
      expect(container.read(themeModeProvider), ThemeMode.dark);
    });

    test('the Amharic toggle flips isAmharic and persists', () async {
      expect(container.read(isAmharicProvider), isFalse);

      await container.read(languageProvider.notifier).set(AppLanguage.amharic);

      expect(container.read(languageProvider), AppLanguage.amharic);
      expect(container.read(isAmharicProvider), isTrue);
      expect(store.getString(PrefKeys.locale), 'am');

      // Back to English: the toggle works both ways.
      await container.read(languageProvider.notifier).set(AppLanguage.english);
      expect(container.read(isAmharicProvider), isFalse);
    });
  });

  group('FamilyRecipeForm', () {
    late _MemoryStore store;
    late _CapturingRepo repo;
    late _NoAnalytics analytics;

    setUp(() {
      store = _MemoryStore();
      repo = _CapturingRepo();
      analytics = _NoAnalytics();
    });

    Future<void> pumpForm(WidgetTester tester) async {
      // The form is a long scrolling ListView; give the test a tall surface so
      // every field is built and tappable without scrolling.
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStoreProvider.overrideWithValue(store),
            familyRecipeRepositoryProvider.overrideWithValue(repo),
            analyticsServiceProvider.overrideWithValue(analytics),
            currentUidProvider.overrideWithValue('cook-1'),
          ],
          child: MaterialApp(
            theme: AppTheme.dark,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const FamilyRecipeForm(),
          ),
        ),
      );
      // AmbientBackground never settles; pump fixed durations instead.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('submitting sends pending with ingredients and steps',
        (tester) async {
      await pumpForm(tester);

      await tester.enterText(find.byKey(const Key('fr-name')), 'Doro Wat');
      await tester.enterText(
        find.byKey(const Key('fr-teacher')),
        'Emahoy Tsehay',
      );
      await tester.enterText(
        find.byKey(const Key('fr-ingredients')),
        '1 chicken\n2 lb berbere',
      );
      await tester.enterText(
        find.byKey(const Key('fr-step-0')),
        'Brown the onions.',
      );

      await tester.tap(find.byType(FlameButton));
      await tester.pump();

      expect(repo.submitted, isNotNull);
      expect(repo.submitted!['status'], 'pending');
      expect(repo.submitted!['ingredientsText'], '1 chicken\n2 lb berbere');
      expect(repo.submitted!['stepsText'], 'Brown the onions.');
    });

    testWidgets('add step appends another numbered field', (tester) async {
      await pumpForm(tester);

      expect(find.byKey(const Key('fr-step-0')), findsOneWidget);

      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      expect(find.byKey(const Key('fr-step-1')), findsOneWidget);
    });

    testWidgets('steps are optional: empty step fields submit cleanly',
        (tester) async {
      await pumpForm(tester);

      await tester.enterText(find.byKey(const Key('fr-name')), 'Chechebsa');
      await tester.enterText(
        find.byKey(const Key('fr-teacher')),
        'Emahoy Almaz',
      );
      await tester.enterText(
        find.byKey(const Key('fr-ingredients')),
        '2 pieces kita',
      );
      // fr-step-0 is left untouched — a recipe can be a photo and a story.

      await tester.tap(find.byType(FlameButton));
      await tester.pump();

      expect(repo.submitted, isNotNull);
      expect(repo.submitted!['status'], 'pending');
      expect(repo.submitted!['ingredientsText'], '2 pieces kita');
      expect(repo.submitted!['stepsText'], isEmpty);
    });
  });
}

class _CapturingRepo implements FamilyRecipeRepository {
  Map<String, dynamic>? submitted;

  @override
  Future<Result<void>> submit({required Map<String, dynamic> payload}) async {
    submitted = payload;
    return const Ok<void>(null);
  }

  @override
  Future<void> applyMutation(PendingMutation mutation) async {}

  @override
  Future<Result<void>> delete({required String recipeId}) async =>
      const Ok<void>(null);

  @override
  Future<Result<String>> uploadMedia({
    required String uid,
    required dynamic file,
  }) async =>
      const Err<String>(
        ValidationFailure(messageKey: 'uploadMediaFailed', field: 'media'),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoAnalytics implements AnalyticsService {
  @override
  Future<void> logFamilyRecipeCreated() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// In-memory stand-in for the Hive-backed store.
class _MemoryStore implements LocalStore {
  final Map<String, Map<String, String>> _boxes = {};
  final Map<String, String> _prefs = {};

  Map<String, String> _box(String name) => _boxes.putIfAbsent(name, () => {});

  @override
  Map<String, dynamic>? readJson(String boxName, String key) {
    final raw = _box(boxName)[key];
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  @override
  Future<void> writeJson(String boxName, String key, Object value) async {
    _box(boxName)[key] = jsonEncode(value);
  }

  @override
  Iterable<String> keys(String boxName) => _box(boxName).keys;

  @override
  String? getString(String key) => _prefs[key];

  @override
  Future<void> setString(String key, String value) async {
    _prefs[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    _prefs.remove(key);
  }

  @override
  Future<void> deleteKey(String boxName, String key) async {
    _box(boxName).remove(key);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
        '${invocation.memberName} not stubbed in _MemoryStore',
      );
}
