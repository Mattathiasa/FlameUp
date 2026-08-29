import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device-local persistence.
///
/// Two tiers, deliberately: [SharedPreferences] for small scalar settings that
/// must be readable before the first frame (theme, language, onboarding flag),
/// and Hive boxes for structured data that has to survive offline — cached
/// recipes, in-flight cooking sessions, and the mutation outbox.
class LocalStore {
  LocalStore._(this._prefs);

  final SharedPreferences _prefs;

  static const String boxRecipes = 'cache_recipes';
  static const String boxSessions = 'cooking_sessions';
  static const String boxOutbox = 'mutation_outbox';
  static const String boxMisc = 'cache_misc';

  static const List<String> _boxes = [
    boxRecipes,
    boxSessions,
    boxOutbox,
    boxMisc,
  ];

  static Future<LocalStore> open() async {
    await Hive.initFlutter();
    for (final name in _boxes) {
      if (!Hive.isBoxOpen(name)) {
        await Hive.openBox<String>(name);
      }
    }
    return LocalStore._(await SharedPreferences.getInstance());
  }

  // --- scalar settings ---------------------------------------------------

  String? getString(String key) => _prefs.getString(key);
  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);

  bool getBool(String key, {bool fallback = false}) =>
      _prefs.getBool(key) ?? fallback;
  Future<void> setBool(String key, {required bool value}) =>
      _prefs.setBool(key, value);

  int? getInt(String key) => _prefs.getInt(key);
  Future<void> setInt(String key, int value) => _prefs.setInt(key, value);

  Future<void> remove(String key) => _prefs.remove(key);

  // --- structured cache --------------------------------------------------

  Box<String> box(String name) => Hive.box<String>(name);

  /// Read a JSON document out of [boxName]. Returns null on a miss or on
  /// corrupt data — a bad cache entry must never crash a screen.
  Map<String, dynamic>? readJson(String boxName, String key) {
    final raw = box(boxName).get(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } on FormatException {
      box(boxName).delete(key);
      return null;
    }
  }

  List<Map<String, dynamic>>? readJsonList(String boxName, String key) {
    final raw = box(boxName).get(key);
    if (raw == null) return null;
    try {
      return (jsonDecode(raw) as List<dynamic>).cast<Map<String, dynamic>>();
    } on FormatException {
      box(boxName).delete(key);
      return null;
    }
  }

  Future<void> writeJson(String boxName, String key, Object value) =>
      box(boxName).put(key, jsonEncode(value));

  Future<void> deleteKey(String boxName, String key) =>
      box(boxName).delete(key);

  Iterable<String> keys(String boxName) => box(boxName).keys.cast<String>();

  /// Wipe cached content but keep user settings. Used on sign-out so the next
  /// account never sees the previous one's cached data.
  Future<void> clearCaches() async {
    for (final name in _boxes) {
      await box(name).clear();
    }
  }
}

/// Overridden in `main()` once [LocalStore.open] has completed, so no widget
/// ever has to await storage initialisation.
final localStoreProvider = Provider<LocalStore>(
  (ref) => throw UnimplementedError('localStoreProvider must be overridden'),
);

/// Preference keys, kept together so they cannot drift apart.
abstract final class PrefKeys {
  static const String themeMode = 'settings.themeMode';
  static const String locale = 'settings.locale';
  static const String onboardingComplete = 'onboarding.complete';
  static const String onboardingStep = 'onboarding.step';
  static const String activeSessionId = 'cooking.activeSessionId';
  static const String lastSyncAt = 'sync.lastSyncAt';
  static const String notificationsEnabled = 'settings.notifications';
}
