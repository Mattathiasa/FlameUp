import '../../features/auth/domain/auth_providers.dart';
import 'routes.dart';

/// The redirect decision, as a pure function.
///
/// Kept out of the [GoRouter] closure so the rules can be unit tested directly
/// rather than by driving a widget tree — routing bugs here strand users on the
/// wrong screen, which is exactly the class of bug tests should catch.
abstract final class RouteGuard {
  /// Returns the path to redirect to, or null to stay put.
  static String? redirect({
    required AuthStatus status,
    required bool onboarded,
    required String path,
  }) {
    // Firebase has not restored the persisted session yet. Holding on the
    // splash avoids bouncing a returning user out to the welcome screen for
    // the frame or two that restoration takes.
    if (status == AuthStatus.unknown) {
      return path == Routes.splash ? null : Routes.splash;
    }

    // Guests count as authenticated: an anonymous account has a uid, progress
    // and everything else a full account has, minus the credentials.
    final authenticated =
        status == AuthStatus.guest || status == AuthStatus.signedIn;
    final isPublic = Routes.publicPaths.contains(path);
    final isOnboarding = Routes.onboardingPaths.contains(path);

    if (!authenticated) {
      // The splash has served its purpose the moment auth resolves.
      if (path == Routes.splash) return Routes.welcome;
      return isPublic ? null : Routes.welcome;
    }

    if (!onboarded) {
      return isOnboarding ? null : Routes.onboardingSkill;
    }

    // Signed in and onboarded — the pre-app routes have nothing left to show.
    if (isPublic || isOnboarding) return Routes.home;
    return null;
  }
}
