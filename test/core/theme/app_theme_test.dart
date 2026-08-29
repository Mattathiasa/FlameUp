import 'dart:convert';
import 'dart:io';

import 'package:flameup/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reads the design tokens the prototype was decoded into. Asserting the Dart
/// constants against this file is what stops the implementation drifting from
/// the design: change one without the other and this fails.
Map<String, dynamic> _tokens() {
  final file = File('design/extracted/tokens.json');
  expect(
    file.existsSync(),
    isTrue,
    reason:
        'run `python3 tool/extract_design.py` to regenerate the design spec',
  );
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

/// `#RRGGBB` from tokens.json to a Flutter [Color].
Color _hex(String value) {
  final digits = value.replaceFirst('#', '');
  return Color(int.parse('FF$digits', radix: 16));
}

void main() {
  late Map<String, dynamic> tokens;

  setUpAll(() => tokens = _tokens());

  group('theme colours come from the design tokens', () {
    test('accent matches', () {
      expect(AppTheme.accent, _hex(tokens['accent'] as String));
    });

    test('dark surfaces match --bg and --scr', () {
      final dark = tokens['dark'] as Map<String, dynamic>;
      expect(AppTheme.darkBackground, _hex(dark['--bg'] as String));
      expect(AppTheme.darkSurface, _hex(dark['--scr'] as String));
      expect(AppTheme.darkText, _hex(dark['--tx'] as String));
    });

    test('light surfaces match --bg and --scr', () {
      final light = tokens['light'] as Map<String, dynamic>;
      expect(AppTheme.lightBackground, _hex(light['--bg'] as String));
      expect(AppTheme.lightSurface, _hex(light['--scr'] as String));
      expect(AppTheme.lightText, _hex(light['--tx'] as String));
    });

    test('the design defines both themes symmetrically', () {
      // Phase 2 generates the full palette from these maps; a variable present
      // in one theme but not the other would leave a surface unpainted.
      final dark = (tokens['dark'] as Map<String, dynamic>).keys.toSet();
      final light = (tokens['light'] as Map<String, dynamic>).keys.toSet();
      expect(dark.difference(light), isEmpty);
      expect(light.difference(dark), isEmpty);
      expect(dark.length, 20);
    });
  });

  group('ThemeData', () {
    test('dark theme is dark and uses the accent', () {
      final theme = AppTheme.dark;
      expect(theme.brightness, Brightness.dark);
      expect(theme.colorScheme.primary, AppTheme.accent);
      expect(theme.scaffoldBackgroundColor, AppTheme.darkBackground);
    });

    test('light theme is light and uses the accent', () {
      final theme = AppTheme.light;
      expect(theme.brightness, Brightness.light);
      expect(theme.colorScheme.primary, AppTheme.accent);
      expect(theme.scaffoldBackgroundColor, AppTheme.lightBackground);
    });

    test('both themes use the Ethiopic-capable family', () {
      // One family renders Latin and Ethiopic, so a mixed English/Amharic
      // sentence does not change font mid-line.
      expect(
        AppTheme.dark.textTheme.bodyMedium?.fontFamily,
        AppTheme.fontFamily,
      );
      expect(
        AppTheme.light.textTheme.bodyMedium?.fontFamily,
        AppTheme.fontFamily,
      );
    });

    test('Material 3 is on', () {
      expect(AppTheme.dark.useMaterial3, isTrue);
      expect(AppTheme.light.useMaterial3, isTrue);
    });
  });

  group('the design spec is present and complete', () {
    test('all 30 screen files were extracted', () {
      final dir = Directory('design/extracted/screens');
      expect(dir.existsSync(), isTrue);
      final files = dir.listSync().whereType<File>().where(
            (f) => f.path.endsWith('.html'),
          );
      expect(files.length, 30);
    });

    test('seed data covers every group the design defines', () {
      final seed = jsonDecode(
        File('design/extracted/seed.json').readAsStringSync(),
      ) as Map<String, dynamic>;

      expect((seed['dishes'] as Map).length, 12);
      expect((seed['regions'] as List).length, 8);
      expect((seed['achievements'] as List).length, 9);
      expect((seed['quests'] as List).length, 4);
      expect((seed['elders'] as List).length, 4);
      expect((seed['doroWatSteps'] as List).length, 9);
      expect((seed['doroWatIngredients'] as List).length, 8);
      expect((seed['mealPlan'] as List).length, 7);
      expect((seed['tabs'] as List).length, 5);
    });

    test('the five tab branches match the router', () {
      final seed = jsonDecode(
        File('design/extracted/seed.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final screens = (seed['tabs'] as List)
          .map((t) => (t as Map<String, dynamic>)['screen'] as String)
          .toList();

      expect(screens, ['home', 'search', 'recipe', 'feed', 'progress']);
    });
  });
}
