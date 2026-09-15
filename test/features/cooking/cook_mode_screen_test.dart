import 'dart:convert';

import 'package:flameup/core/cache/cache_entry.dart';
import 'package:flameup/core/cache/outbox.dart';
import 'package:flameup/core/cache/pending_mutation.dart';
import 'package:flameup/core/services/local_store.dart';
import 'package:flameup/core/services/timer_completion_alert.dart';
import 'package:flameup/core/theme/app_theme.dart';
import 'package:flameup/features/auth/domain/auth_providers.dart';
import 'package:flameup/features/cooking/data/cooking_repository.dart';
import 'package:flameup/features/cooking/domain/cooking_session.dart';
import 'package:flameup/features/cooking/presentation/cook_mode_screen.dart';
import 'package:flameup/features/recipes/domain/recipe.dart';
import 'package:flameup/features/recipes/domain/recipe_providers.dart';
import 'package:flameup/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Steps: an untimed one, then a timed one. The expired case mounts the
/// session already on the timed step with its deadline in the past, which is
/// exactly how a timer that ran out while the app was closed reports itself.
Map<String, dynamic> _stepJson(int index, {int? durationSeconds}) => {
      'index': index,
      'text': 'Step $index',
      'textAm': 'ደረጃ $index',
      if (durationSeconds != null) 'durationSeconds': durationSeconds,
    };

Recipe _recipe() => Recipe.fromJson('shiro', {
      'title': 'Shiro',
      'titleAm': 'ሽሮ',
      'subtitle': 'Quick and comforting',
      'subtitleAm': 'ፈጣን እና ማስታወሻ',
      'regionId': 'addis',
      'category': 'stew',
      'difficulty': 0,
      'totalMinutes': 30,
      'servings': 2,
      'xpReward': 40,
      'ingredients': <Map<String, dynamic>>[
        {
          'name': 'chickpea flour',
          'nameAm': 'ሽሮ ዱቄት',
          'quantity': 2,
          'unit': 'cups',
        },
      ],
      'steps': <Map<String, dynamic>>[
        _stepJson(0),
        _stepJson(1, durationSeconds: 600),
        // A third, untimed step: the expired case sits on step 1 and the done
        // card must offer "Next step", which only exists if more steps follow.
        _stepJson(2),
      ],
    });

Widget _host(Widget child, List<Override> overrides) {
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

List<Override> _overrides({
  required _MemoryStore store,
  required Recipe recipe,
  required _RecordingAlert alert,
}) =>
    [
      // The screen resolves the recipe through recipeProvider; feeding it a
      // ready stream keeps the Firestore-backed repository out of the test.
      recipeProvider.overrideWith(
        (ref, id) => Stream.value(
          Cached(value: recipe, origin: DataOrigin.network),
        ),
      ),
      cookingRepositoryProvider.overrideWithValue(
        CookingRepository(store: store, outbox: _NoOutbox()),
      ),
      localStoreProvider.overrideWithValue(store),
      currentUidProvider.overrideWithValue('u1'),
      isAmharicProvider.overrideWithValue(false),
      timerCompletionAlertProvider.overrideWithValue(alert),
    ];

void main() {
  group('CookModeScreen timers', () {
    testWidgets(
        'a timer that expired shows the done card with next and '
        'more-time actions, and announces itself once', (tester) async {
      final store = _MemoryStore();
      final alert = _RecordingAlert();

      // Session already on the timed step (1), deadline long past — the
      // reopen-the-app-and-the-timer-is-done case.
      final session = CookingSession(
        recipeId: 'shiro',
        totalSteps: 3,
        servings: 2,
        currentStep: 1,
        stepDeadlines: {
          1: DateTime.now().subtract(const Duration(minutes: 2)),
        },
      );
      await CookingRepository(store: store, outbox: _NoOutbox())
          .save(session, uid: 'u1');

      await tester.pumpWidget(
        _host(
          const CookModeScreen(recipeId: 'shiro'),
          _overrides(store: store, recipe: _recipe(), alert: alert),
        ),
      );
      // AmbientBackground never settles; pump fixed durations instead.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // The done card replaces the ring and the step text. "Next step"
      // appears twice — the card and the persistent bottom bar offer the same
      // forward action.
      expect(find.text('Timer done'), findsOneWidget);
      expect(find.text('Next step'), findsNWidgets(2));
      expect(find.text('Needs more time'), findsOneWidget);
      // The old ring is gone; the countdown text is 0:00 only inside it.
      expect(find.text('0:00'), findsNothing);
      // Tapped exactly once — the one-second ticker must not re-fire it.
      expect(alert.playCount, 1);

      // Acknowledging by moving on: the card hands over to the next step.
      // .first is the card's own button (it precedes the bottom bar); the tap
      // lands on the button that hosts the label, hence warnIfMissed: false.
      await tester.tap(find.text('Next step').first, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      // The done card is gone; the next (untimed) step's text is up.
      expect(find.text('Timer done'), findsNothing);
      expect(find.text('Step 2'), findsOneWidget);
    });

    testWidgets('a running timer shows the ring, not the done card',
        (tester) async {
      final store = _MemoryStore();
      final alert = _RecordingAlert();

      final session = CookingSession(
        recipeId: 'shiro',
        totalSteps: 3,
        servings: 2,
        currentStep: 1,
        stepDeadlines: {1: DateTime.now().add(const Duration(minutes: 9))},
      );
      await CookingRepository(store: store, outbox: _NoOutbox())
          .save(session, uid: 'u1');

      await tester.pumpWidget(
        _host(
          const CookModeScreen(recipeId: 'shiro'),
          _overrides(store: store, recipe: _recipe(), alert: alert),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Timer done'), findsNothing);
      // The bottom bar's forward button is the only "Next step" — no card.
      // A live countdown is on screen (9:xx or 8:xx on the tick boundary).
      expect(find.textContaining(RegExp(r'^[89]:')), findsOneWidget);
      expect(alert.playCount, 0);

      // Pause and restart are wired to real controller actions; exercising
      // pause then resume round-trips through the session store.
      await tester.tap(find.text('Pause'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Paused'), findsWidgets);
      await tester.tap(find.text('Resume'));
      await tester.pump(const Duration(milliseconds: 200));
    });
  });
}

class _RecordingAlert implements TimerCompletionAlert {
  int playCount = 0;

  @override
  Future<void> play() async {
    playCount++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoOutbox implements Outbox {
  @override
  Future<PendingMutation> enqueue(PendingMutation mutation) async => mutation;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// In-memory stand-in for the Hive-backed store, mirroring the hub test: only
/// what cook mode and its providers touch.
class _MemoryStore implements LocalStore {
  final Map<String, Map<String, String>> _boxes = {};

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

  final Map<String, String> _prefs = {};

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
        '${invocation.memberName} not stubbed in _MemoryStore',
      );
}
