import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Product analytics.
///
/// Event names are declared as constants rather than passed as free strings, so
/// the set stays reviewable and typo-free. Nothing here carries an email, a
/// display name or any free text the user typed.
class AnalyticsService {
  AnalyticsService(this._analytics);

  final FirebaseAnalytics _analytics;

  // Lifecycle
  static const String appOpen = 'app_open';
  static const String onboardingCompleted = 'onboarding_completed';
  // Recipes
  static const String recipeViewed = 'recipe_viewed';
  static const String recipeSaved = 'recipe_saved';
  static const String recipeSearched = 'recipe_searched';
  // Cooking
  static const String recipeStarted = 'recipe_started';
  static const String recipeCompleted = 'recipe_completed';
  static const String recipeAbandoned = 'recipe_abandoned';
  static const String recipeRated = 'recipe_rated';
  // Progression
  static const String questCompleted = 'quest_completed';
  static const String achievementUnlocked = 'achievement_unlocked';
  static const String levelUp = 'level_up';
  static const String masteryAdvanced = 'mastery_advanced';
  // Culture + social
  static const String familyRecipeCreated = 'family_recipe_created';
  static const String regionExplored = 'region_explored';
  static const String challengeCreated = 'challenge_created';
  static const String challengeCompleted = 'challenge_completed';

  Future<void> log(
    String name, [
    Map<String, Object?> parameters = const {},
  ]) async {
    if (kDebugMode) {
      debugPrint('[analytics] $name $parameters');
    }
    final clean = <String, Object>{
      for (final entry in parameters.entries)
        if (entry.value != null) entry.key: entry.value!,
    };
    await _analytics.logEvent(
      name: name,
      parameters: clean.isEmpty ? null : clean,
    );
  }

  Future<void> setScreen(String screenName) =>
      _analytics.logScreenView(screenName: screenName);

  /// Only the opaque uid — never email or display name.
  Future<void> setUser(String? uid) => _analytics.setUserId(id: uid);

  Future<void> setAnalyticsEnabled({required bool enabled}) =>
      _analytics.setAnalyticsCollectionEnabled(enabled);
}

final analyticsServiceProvider = Provider<AnalyticsService>(
  (ref) => AnalyticsService(FirebaseAnalytics.instance),
);
