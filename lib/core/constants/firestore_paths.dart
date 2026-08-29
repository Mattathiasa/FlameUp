/// Every Firestore collection and document path in one place.
///
/// Repositories build paths from here rather than writing string literals, so
/// the schema in docs/DATABASE_SCHEMA.md has exactly one implementation.
abstract final class FirestorePaths {
  // Top-level collections
  static const String users = 'users';
  static const String recipes = 'recipes';
  static const String regions = 'regions';
  static const String achievements = 'achievements';
  static const String quests = 'quests';
  static const String challenges = 'challenges';
  static const String familyRecipes = 'family_recipes';
  static const String posts = 'posts';
  static const String reports = 'reports';
  static const String leaderboards = 'leaderboards';
  static const String config = 'config';

  // Collection-group names (used with collectionGroup queries)
  static const String reviews = 'reviews';
  static const String cookingSessions = 'cooking_sessions';
  static const String mastery = 'mastery';
  static const String userQuests = 'user_quests';
  static const String userAchievements = 'user_achievements';
  static const String savedRecipes = 'saved_recipes';
  static const String shoppingItems = 'shopping_items';
  static const String mealPlans = 'meal_plans';
  static const String friends = 'friends';
  static const String friendRequests = 'friend_requests';
  static const String notifications = 'notifications';
  static const String comments = 'comments';
  static const String likes = 'likes';
  static const String submissions = 'submissions';
  static const String generations = 'generations';
  static const String outbox = 'outbox';

  // Documents
  static String user(String uid) => '$users/$uid';
  static String recipe(String id) => '$recipes/$id';
  static String region(String id) => '$regions/$id';
  static String familyRecipe(String id) => '$familyRecipes/$id';
  static String post(String id) => '$posts/$id';
  static String challenge(String id) => '$challenges/$id';

  // Per-user subcollections
  static String userCookingSessions(String uid) =>
      '${user(uid)}/$cookingSessions';
  static String userMastery(String uid) => '${user(uid)}/$mastery';
  static String userQuestsOf(String uid) => '${user(uid)}/$userQuests';
  static String userAchievementsOf(String uid) =>
      '${user(uid)}/$userAchievements';
  static String userSavedRecipes(String uid) => '${user(uid)}/$savedRecipes';
  static String userShoppingItems(String uid) => '${user(uid)}/$shoppingItems';
  static String userMealPlans(String uid) => '${user(uid)}/$mealPlans';
  static String userFriends(String uid) => '${user(uid)}/$friends';
  static String userFriendRequests(String uid) =>
      '${user(uid)}/$friendRequests';
  static String userNotifications(String uid) => '${user(uid)}/$notifications';

  // Per-recipe subcollections
  static String recipeReviews(String recipeId) =>
      '${recipe(recipeId)}/$reviews';

  // Config documents, editable without shipping a build
  static const String levelCurveDoc = '$config/level_curve';
  static const String xpRulesDoc = '$config/xp_rules';
  static const String featuredDoc = '$config/featured';
}
