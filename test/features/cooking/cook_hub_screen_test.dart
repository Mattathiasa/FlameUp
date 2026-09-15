import 'dart:convert';
import 'dart:io';

import 'package:flameup/core/cache/outbox.dart';
import 'package:flameup/core/cache/pending_mutation.dart';
import 'package:flameup/core/services/local_store.dart';
import 'package:flameup/core/theme/app_theme.dart';
import 'package:flameup/features/cooking/data/cooking_repository.dart';
import 'package:flameup/features/cooking/domain/cooking_session.dart';
import 'package:flameup/features/cooking/presentation/cook_hub_screen.dart';
import 'package:flameup/features/recipes/data/recipe_seed_source.dart';
import 'package:flameup/features/recipes/domain/recipe.dart';
import 'package:flameup/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Recipe _recipe(String id) {
  final raw = File('assets/seed/recipes.json').readAsStringSync();
  final json = jsonDecode(raw) as Map<String, dynamic>;
  return Recipe.fromJson(id, ((json['recipes'] as Map)[id] as Map).cast<String, dynamic>());
}

Widget _host(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      theme: AppTheme.dark,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: child,
    ),
  );
}

void main() {
  group('CookHubScreen', () {
    testWidgets(
        'shows quick cooks sorted by duration and no resume card '
        'when nothing is cooking', (tester) async {
      final store = _MemoryStore();
      await tester.pumpWidget(
        _host(
          const CookHubScreen(),
          overrides: [
            recipeSeedSourceProvider.overrideWith(
              (ref) => _StubSeedSource([_recipe('awaze'), _recipe('doro')]),
            ),
            cookingRepositoryProvider.overrideWithValue(
              CookingRepository(store: store, outbox: _NoOutbox()),
            ),
            localStoreProvider.overrideWithValue(store),
          ],
        ),
      );
      // AmbientBackground never settles; pump fixed durations instead.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Quick cooks shows the 15-minute dish and not the 2-hour one.
      expect(find.text('Awaze'), findsWidgets);
      expect(find.text('Doro Wat'), findsNothing);
      expect(find.text('Quick cooks'), findsOneWidget);
      // No session in progress, so no "pick up where you left".
      expect(find.text('PICK UP WHERE YOU LEFT'), findsNothing);
    });

    testWidgets('surfaces the in-progress cook as a resume card',
        (tester) async {
      final store = _MemoryStore();
      final repo = CookingRepository(store: store, outbox: _NoOutbox());
      final session = CookingSession(
        recipeId: 'doro',
        totalSteps: 8,
        servings: 4,
        currentStep: 2,
      );
      await repo.save(session, uid: 'u1');

      await tester.pumpWidget(
        _host(
          const CookHubScreen(),
          overrides: [
            recipeSeedSourceProvider.overrideWith(
              (ref) => _StubSeedSource([_recipe('doro'), _recipe('awaze')]),
            ),
            cookingRepositoryProvider.overrideWithValue(repo),
            localStoreProvider.overrideWithValue(store),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('PICK UP WHERE YOU LEFT'), findsOneWidget);
      expect(find.textContaining('Doro Wat'), findsWidgets);
    });

    testWidgets('lists saved recipes in the saved section', (tester) async {
      final store = _MemoryStore()..savedIds = {'kitfo'};

      await tester.pumpWidget(
        _host(
          const CookHubScreen(),
          overrides: [
            recipeSeedSourceProvider.overrideWith(
              (ref) => _StubSeedSource([_recipe('kitfo'), _recipe('doro')]),
            ),
            cookingRepositoryProvider.overrideWithValue(
              CookingRepository(store: store, outbox: _NoOutbox()),
            ),
            localStoreProvider.overrideWithValue(store),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Kitfo'), findsOneWidget);
      expect(find.text('Doro Wat'), findsNothing);
    });
  });
}

class _StubSeedSource implements RecipeSeedSource {
  _StubSeedSource(this.recipes);

  final List<Recipe> recipes;

  @override
  Future<List<Recipe>> load() async => recipes;

  @override
  Future<Recipe?> byId(String id) async =>
      recipes.where((r) => r.id == id).firstOrNull;
}

/// In-memory stand-in for the Hive-backed store: only what the hub and its
/// providers touch, which is sessions in [boxSessions] and saved ids in
/// [boxMisc].
class _MemoryStore implements LocalStore {
  final Map<String, Map<String, String>> _boxes = {};
  Set<String> savedIds = {};

  Map<String, String> _box(String name) => _boxes.putIfAbsent(name, () => {});

  @override
  Map<String, dynamic>? readJson(String boxName, String key) {
    final raw = _box(boxName)[key];
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  @override
  Future<void> writeJson(String boxName, String key, Object value) async {
    if (boxName == LocalStore.boxMisc && key == 'saved.recipes') {
      savedIds = ((value as Map)['ids'] as List).cast<String>().toSet();
    }
    _box(boxName)[key] = jsonEncode(value);
  }

  @override
  Iterable<String> keys(String boxName) => _box(boxName).keys;

  @override
  String? getString(String key) =>
      key == PrefKeys.activeSessionId ? _active : _prefs[key];

  @override
  Future<void> setString(String key, String value) async {
    if (key == PrefKeys.activeSessionId) _active = value;
    _prefs[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    if (key == PrefKeys.activeSessionId) _active = null;
    _prefs.remove(key);
  }

  String? _active;
  final Map<String, String> _prefs = {};

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
        '${invocation.memberName} not stubbed in _MemoryStore',
      );
}

class _NoOutbox implements Outbox {
  @override
  Future<PendingMutation> enqueue(PendingMutation mutation) async => mutation;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
