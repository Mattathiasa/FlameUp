import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/auth_providers.dart';
import '../../features/auth/presentation/auth_form_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/auth/presentation/welcome_screen.dart';
import '../../features/community/presentation/challenges_screen.dart';
import '../../features/community/presentation/community_screen.dart';
import '../../features/community/presentation/friends_screen.dart';
import '../../features/community/presentation/leaderboard_screen.dart';
import '../../features/cooking/presentation/cook_done_screen.dart';
import '../../features/cooking/presentation/cook_mode_screen.dart';
import '../../features/cooking/presentation/cook_rate_screen.dart';
import '../../features/family_recipes/presentation/family_recipe_form.dart';
import '../../features/family_recipes/presentation/grandma_screen.dart';
import '../../features/gamification/presentation/achievements_screen.dart';
import '../../features/gamification/presentation/mastery_screen.dart';
import '../../features/gamification/presentation/progress_screen.dart';
import '../../features/gamification/presentation/quests_screen.dart';
import '../../features/gamification/presentation/streak_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/meal_planner/presentation/planner_screen.dart';
import '../../features/onboarding/domain/onboarding_providers.dart';
import '../../features/onboarding/presentation/skill_screen.dart';
import '../../features/onboarding/presentation/taste_screen.dart';
import '../../features/recipes/presentation/discover_screen.dart';
import '../../features/recipes/presentation/recipe_detail_screen.dart';
import '../../features/recipes/presentation/saved_screen.dart';
import '../../features/regions/presentation/region_screen.dart';
import '../../features/regions/presentation/taste_ethiopia_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/shopping/presentation/shopping_screen.dart';
import '../../features/system/presentation/offline_screen.dart';
import '../services/crash_reporter.dart';
import 'app_shell.dart';
import 'route_guard.dart';
import 'routes.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _shellNavigatorKeys = <String, GlobalKey<NavigatorState>>{
  for (final branch in ['home', 'discover', 'cook', 'community', 'you'])
    branch: GlobalKey<NavigatorState>(debugLabel: branch),
};

/// Republishes auth and onboarding changes as a [Listenable] so go_router
/// re-evaluates `redirect` the moment either flips.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    ref.listen(authStatusProvider, (_, __) => notifyListeners());
    ref.listen(onboardingStatusProvider, (_, __) => notifyListeners());
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    debugLogDiagnostics: false,
    redirect: (context, state) => RouteGuard.redirect(
      status: ref.read(authStatusProvider),
      onboarded: ref.read(onboardingStatusProvider),
      path: state.matchedLocation,
    ),
    errorBuilder: (context, state) =>
        _RouteNotFound(location: state.uri.toString()),
    observers: [_CrashBreadcrumbObserver(ref)],
    routes: [
      // --- pre-app ------------------------------------------------------
      GoRoute(
        path: Routes.splash,
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: Routes.welcome,
        builder: (_, __) => const WelcomeScreen(),
      ),
      GoRoute(
        path: Routes.signIn,
        builder: (_, __) => const AuthFormScreen(mode: AuthFormMode.signIn),
      ),
      GoRoute(
        path: Routes.signUp,
        builder: (_, __) => const AuthFormScreen(mode: AuthFormMode.signUp),
      ),
      GoRoute(
        path: Routes.forgotPassword,
        builder: (_, __) =>
            const AuthFormScreen(mode: AuthFormMode.forgotPassword),
      ),
      GoRoute(
        path: Routes.upgradeAccount,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) =>
            const AuthFormScreen(mode: AuthFormMode.upgradeGuest),
      ),
      GoRoute(
        path: Routes.onboardingSkill,
        builder: (_, __) => const SkillScreen(),
      ),
      GoRoute(
        path: Routes.onboardingTaste,
        builder: (_, __) => const TasteScreen(),
      ),

      // --- full-screen routes that sit above the tab shell ---------------
      GoRoute(
        path: Routes.cookMode,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, state) => CookModeScreen(
          recipeId: state.pathParameters['recipeId']!,
        ),
      ),
      GoRoute(
        path: Routes.cookDone,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, state) => CookDoneScreen(
          sessionId: state.pathParameters['sessionId']!,
        ),
      ),
      GoRoute(
        path: Routes.cookRate,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, state) => CookRateScreen(
          sessionId: state.pathParameters['sessionId']!,
        ),
      ),
      GoRoute(
        path: Routes.offline,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => const OfflineScreen(),
      ),

      // --- the five-tab shell -------------------------------------------
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            navigatorKey: _shellNavigatorKeys['home'],
            routes: [
              GoRoute(
                path: Routes.home,
                builder: (_, __) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellNavigatorKeys['discover'],
            routes: [
              GoRoute(
                path: Routes.discover,
                builder: (_, __) => const DiscoverScreen(),
                routes: [
                  GoRoute(
                    path: 'map',
                    builder: (_, __) => const TasteEthiopiaScreen(),
                  ),
                  GoRoute(
                    path: 'region/:regionId',
                    builder: (_, state) => RegionScreen(
                      regionId: state.pathParameters['regionId']!,
                    ),
                  ),
                  GoRoute(
                    path: 'grandma',
                    builder: (_, __) => const GrandmaScreen(),
                  ),
                  GoRoute(
                    path: 'family-recipe/new',
                    builder: (_, __) => const FamilyRecipeForm(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellNavigatorKeys['cook'],
            routes: [
              GoRoute(
                path: Routes.cook,
                builder: (_, __) => const DiscoverScreen(),
              ),
              GoRoute(
                path: Routes.recipeDetail,
                builder: (_, state) => RecipeDetailScreen(
                  recipeId: state.pathParameters['recipeId']!,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellNavigatorKeys['community'],
            routes: [
              GoRoute(
                path: Routes.community,
                builder: (_, __) => const CommunityScreen(),
                routes: [
                  GoRoute(
                    path: 'friends',
                    builder: (_, __) => const FriendsScreen(),
                  ),
                  GoRoute(
                    path: 'challenges',
                    builder: (_, __) => const ChallengesScreen(),
                  ),
                  GoRoute(
                    path: 'leaderboard',
                    builder: (_, __) => const LeaderboardScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellNavigatorKeys['you'],
            routes: [
              GoRoute(
                path: Routes.you,
                builder: (_, __) => const ProgressScreen(),
                routes: [
                  GoRoute(
                    path: 'mastery',
                    builder: (_, __) => const MasteryScreen(),
                  ),
                  GoRoute(
                    path: 'achievements',
                    builder: (_, __) => const AchievementsScreen(),
                  ),
                  GoRoute(
                    path: 'quests',
                    builder: (_, __) => const QuestsScreen(),
                  ),
                  GoRoute(
                    path: 'streak',
                    builder: (_, __) => const StreakScreen(),
                  ),
                  GoRoute(
                    path: 'saved',
                    builder: (_, __) => const SavedScreen(),
                  ),
                  GoRoute(
                    path: 'shopping',
                    builder: (_, __) => const ShoppingScreen(),
                  ),
                  GoRoute(
                    path: 'planner',
                    builder: (_, __) => const PlannerScreen(),
                  ),
                  GoRoute(
                    path: 'settings',
                    builder: (_, __) => const SettingsScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

/// Leaves a breadcrumb on every navigation so a crash report shows the path
/// the user took to reach it. Route paths only — never query values.
class _CrashBreadcrumbObserver extends NavigatorObserver {
  _CrashBreadcrumbObserver(this._ref);
  final Ref _ref;

  void _log(String action, Route<dynamic>? route) {
    final name = route?.settings.name;
    if (name == null) return;
    _ref.read(crashReporterProvider).leaveBreadcrumb('$action $name');
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _log('push', route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _log('replace', newRoute);
}

/// Shown for a URL that matches nothing — a stale deep link, usually.
class _RouteNotFound extends StatelessWidget {
  const _RouteNotFound({required this.location});
  final String location;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'That page does not exist',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(location, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () => context.go(Routes.home),
                child: const Text('Back to Today'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
