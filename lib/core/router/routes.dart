/// Route paths and names, in one place.
///
/// Screen ids match the design prototype so a route can be traced straight to
/// its markup in `design/extracted/screens/`.
abstract final class Routes {
  // --- outside the tab shell --------------------------------------------
  static const String splash = '/splash'; // 01-splash
  static const String welcome = '/welcome'; // 02-welcome
  static const String signIn = '/sign-in';
  static const String signUp = '/sign-up';
  static const String forgotPassword = '/forgot-password';

  /// Guest -> permanent account. Reachable while signed in, so it is not a
  /// public path: a guest is already authenticated.
  static const String upgradeAccount = '/upgrade-account';

  static const String onboardingSkill = '/onboarding/skill'; // 03-skill
  static const String onboardingTaste = '/onboarding/taste'; // 04-taste

  // --- tab shell branches ------------------------------------------------
  static const String home = '/home'; // 05-home    (Today)
  static const String discover = '/discover'; // 06-search  (Explore)
  static const String cook = '/cook'; // 07-recipe  (Cook)
  static const String community = '/community'; // 20-feed    (Community)
  static const String you = '/you'; // 11-progress (You)

  // --- recipes + cooking -------------------------------------------------
  static const String recipeDetail = '/recipe/:recipeId'; // 07-recipe
  static const String cookMode = '/recipe/:recipeId/cook'; // 08-cook
  static const String cookDone = '/session/:sessionId/done'; // 09-done
  static const String cookRate = '/session/:sessionId/rate'; // 10-rate

  static String recipeDetailOf(String recipeId) => '/recipe/$recipeId';
  static String cookModeOf(String recipeId) => '/recipe/$recipeId/cook';
  static String cookDoneOf(String sessionId) => '/session/$sessionId/done';
  static String cookRateOf(String sessionId) => '/session/$sessionId/rate';

  // --- progress ----------------------------------------------------------
  static const String mastery = '/you/mastery'; // 12-mastery
  static const String achievements = '/you/achievements'; // 13-achv
  static const String quests = '/you/quests'; // 14-quests
  static const String streak = '/you/streak'; // 15-streak

  // --- culture -----------------------------------------------------------
  static const String tasteEthiopia = '/discover/map'; // 16-map
  static const String region = '/discover/region/:regionId'; // 17-region
  static const String grandmasKitchen = '/discover/grandma'; // 18-grandma
  static const String familyRecipeNew =
      '/discover/family-recipe/new'; // 19-upload

  static String regionOf(String regionId) => '/discover/region/$regionId';

  // --- social ------------------------------------------------------------
  static const String friends = '/community/friends'; // 21-friends
  static const String challenges = '/community/challenges'; // 22-challenges
  static const String leaderboard = '/community/leaderboard'; // 23-leader

  // --- utility -----------------------------------------------------------
  static const String saved = '/you/saved'; // 24-saved
  static const String shopping = '/you/shopping'; // 25-shop
  static const String planner = '/you/planner'; // 26-planner
  static const String settings = '/you/settings'; // 27-settings

  // --- system states -----------------------------------------------------
  static const String offline = '/offline'; // 29-offline

  /// Routes reachable while signed out. Everything else redirects to
  /// [welcome]; guest sign-in is what gets a user past this.
  static const Set<String> publicPaths = {
    splash,
    welcome,
    signIn,
    signUp,
    forgotPassword,
  };

  /// Routes that belong to onboarding, reachable once authenticated but before
  /// the profile is complete.
  static const Set<String> onboardingPaths = {
    onboardingSkill,
    onboardingTaste,
  };
}
