import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/auth_providers.dart';
import '../../features/auth/presentation/auth_form_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/auth/presentation/welcome_screen.dart';
import '../../features/onboarding/domain/onboarding_providers.dart';
import '../../features/onboarding/presentation/skill_screen.dart';
import '../../features/onboarding/presentation/taste_screen.dart';
import '../../shared/widgets/not_built_yet.dart';
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
        builder: (_, __) => const NotBuiltYet(
          screen: 'cook mode',
          designFile: '08-cook.html',
          phase: 'Phase 6',
        ),
      ),
      GoRoute(
        path: Routes.cookDone,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => const NotBuiltYet(
          screen: 'finished',
          designFile: '09-done.html',
          phase: 'Phase 6',
        ),
      ),
      GoRoute(
        path: Routes.cookRate,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => const NotBuiltYet(
          screen: 'rate it',
          designFile: '10-rate.html',
          phase: 'Phase 5',
        ),
      ),
      GoRoute(
        path: Routes.offline,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, __) => const NotBuiltYet(
          screen: 'offline',
          designFile: '29-offline.html',
          phase: 'Phase 12',
        ),
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
                builder: (_, __) => const NotBuiltYet(
                  screen: 'today',
                  designFile: '05-home.html',
                  phase: 'Phase 5',
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellNavigatorKeys['discover'],
            routes: [
              GoRoute(
                path: Routes.discover,
                builder: (_, __) => const NotBuiltYet(
                  screen: 'explore',
                  designFile: '06-search.html',
                  phase: 'Phase 5',
                ),
                routes: [
                  GoRoute(
                    path: 'map',
                    builder: (_, __) => const NotBuiltYet(
                      screen: 'taste ethiopia',
                      designFile: '16-map.html',
                      phase: 'Phase 8',
                    ),
                  ),
                  GoRoute(
                    path: 'region/:regionId',
                    builder: (_, __) => const NotBuiltYet(
                      screen: 'region',
                      designFile: '17-region.html',
                      phase: 'Phase 8',
                    ),
                  ),
                  GoRoute(
                    path: 'grandma',
                    builder: (_, __) => const NotBuiltYet(
                      screen: "grandma's kitchen",
                      designFile: '18-grandma.html',
                      phase: 'Phase 8',
                    ),
                  ),
                  GoRoute(
                    path: 'family-recipe/new',
                    builder: (_, __) => const NotBuiltYet(
                      screen: 'family recipe',
                      designFile: '19-upload.html',
                      phase: 'Phase 8',
                    ),
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
                builder: (_, __) => const NotBuiltYet(
                  screen: 'cook',
                  designFile: '07-recipe.html',
                  phase: 'Phase 5',
                ),
              ),
              GoRoute(
                path: Routes.recipeDetail,
                builder: (_, __) => const NotBuiltYet(
                  screen: 'recipe',
                  designFile: '07-recipe.html',
                  phase: 'Phase 5',
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellNavigatorKeys['community'],
            routes: [
              GoRoute(
                path: Routes.community,
                builder: (_, __) => const NotBuiltYet(
                  screen: 'community',
                  designFile: '20-feed.html',
                  phase: 'Phase 9',
                ),
                routes: [
                  GoRoute(
                    path: 'friends',
                    builder: (_, __) => const NotBuiltYet(
                      screen: 'friends',
                      designFile: '21-friends.html',
                      phase: 'Phase 9',
                    ),
                  ),
                  GoRoute(
                    path: 'challenges',
                    builder: (_, __) => const NotBuiltYet(
                      screen: 'challenges',
                      designFile: '22-challenges.html',
                      phase: 'Phase 9',
                    ),
                  ),
                  GoRoute(
                    path: 'leaderboard',
                    builder: (_, __) => const NotBuiltYet(
                      screen: 'leaderboard',
                      designFile: '23-leader.html',
                      phase: 'Phase 9',
                    ),
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
                builder: (_, __) => const NotBuiltYet(
                  screen: 'your kitchen',
                  designFile: '11-progress.html',
                  phase: 'Phase 7',
                ),
                routes: [
                  GoRoute(
                    path: 'mastery',
                    builder: (_, __) => const NotBuiltYet(
                      screen: 'mastery',
                      designFile: '12-mastery.html',
                      phase: 'Phase 7',
                    ),
                  ),
                  GoRoute(
                    path: 'achievements',
                    builder: (_, __) => const NotBuiltYet(
                      screen: 'achievements',
                      designFile: '13-achv.html',
                      phase: 'Phase 7',
                    ),
                  ),
                  GoRoute(
                    path: 'quests',
                    builder: (_, __) => const NotBuiltYet(
                      screen: 'quests',
                      designFile: '14-quests.html',
                      phase: 'Phase 7',
                    ),
                  ),
                  GoRoute(
                    path: 'streak',
                    builder: (_, __) => const NotBuiltYet(
                      screen: 'streak',
                      designFile: '15-streak.html',
                      phase: 'Phase 7',
                    ),
                  ),
                  GoRoute(
                    path: 'saved',
                    builder: (_, __) => const NotBuiltYet(
                      screen: 'favorites',
                      designFile: '24-saved.html',
                      phase: 'Phase 10',
                    ),
                  ),
                  GoRoute(
                    path: 'shopping',
                    builder: (_, __) => const NotBuiltYet(
                      screen: 'shopping list',
                      designFile: '25-shop.html',
                      phase: 'Phase 10',
                    ),
                  ),
                  GoRoute(
                    path: 'planner',
                    builder: (_, __) => const NotBuiltYet(
                      screen: 'meal planner',
                      designFile: '26-planner.html',
                      phase: 'Phase 10',
                    ),
                  ),
                  GoRoute(
                    path: 'settings',
                    builder: (_, __) => const NotBuiltYet(
                      screen: 'settings',
                      designFile: '27-settings.html',
                      phase: 'Phase 10',
                    ),
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
