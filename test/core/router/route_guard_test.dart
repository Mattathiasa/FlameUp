import 'package:flameup/core/router/route_guard.dart';
import 'package:flameup/core/router/routes.dart';
import 'package:flameup/features/auth/domain/auth_providers.dart';
import 'package:flutter_test/flutter_test.dart';

String? redirect(
  AuthStatus status, {
  required bool onboarded,
  required String path,
}) =>
    RouteGuard.redirect(status: status, onboarded: onboarded, path: path);

void main() {
  group('while auth is still resolving', () {
    test('every route is held on the splash', () {
      for (final path in [Routes.home, Routes.welcome, Routes.settings]) {
        expect(
          redirect(AuthStatus.unknown, onboarded: true, path: path),
          Routes.splash,
          reason: '$path should wait on the splash',
        );
      }
    });

    test('the splash itself stays put', () {
      expect(
        redirect(AuthStatus.unknown, onboarded: false, path: Routes.splash),
        isNull,
      );
    });

    test('a returning user is never bounced to welcome', () {
      // The bug this guards: redirecting on the frame before Firebase restores
      // the session would flash the welcome screen at a signed-in user.
      expect(
        redirect(AuthStatus.unknown, onboarded: true, path: Routes.home),
        isNot(Routes.welcome),
      );
    });
  });

  group('signed out', () {
    test('protected routes go to welcome', () {
      for (final path in [
        Routes.home,
        Routes.you,
        Routes.shopping,
        Routes.cook,
      ]) {
        expect(
          redirect(AuthStatus.signedOut, onboarded: false, path: path),
          Routes.welcome,
        );
      }
    });

    test('public routes are left alone', () {
      for (final path in [
        Routes.welcome,
        Routes.signIn,
        Routes.signUp,
        Routes.forgotPassword,
      ]) {
        expect(
          redirect(AuthStatus.signedOut, onboarded: false, path: path),
          isNull,
        );
      }
    });

    test('the splash moves on to welcome once auth resolves', () {
      expect(
        redirect(AuthStatus.signedOut, onboarded: false, path: Routes.splash),
        Routes.welcome,
      );
    });

    test('being onboarded does not grant access without an account', () {
      expect(
        redirect(AuthStatus.signedOut, onboarded: true, path: Routes.home),
        Routes.welcome,
      );
    });
  });

  group('authenticated but not onboarded', () {
    for (final status in [AuthStatus.guest, AuthStatus.signedIn]) {
      test('${status.name}: app routes go to onboarding', () {
        expect(
          redirect(status, onboarded: false, path: Routes.home),
          Routes.onboardingSkill,
        );
      });

      test('${status.name}: onboarding routes are left alone', () {
        expect(
          redirect(status, onboarded: false, path: Routes.onboardingSkill),
          isNull,
        );
        expect(
          redirect(status, onboarded: false, path: Routes.onboardingTaste),
          isNull,
        );
      });

      test('${status.name}: public routes also redirect into onboarding', () {
        // Onboarding takes priority: an authenticated user has no reason to be
        // on the welcome screen, finished or not.
        expect(
          redirect(status, onboarded: false, path: Routes.welcome),
          Routes.onboardingSkill,
        );
      });
    }
  });

  group('authenticated and onboarded', () {
    test('app routes are left alone', () {
      for (final path in [
        Routes.home,
        Routes.discover,
        Routes.cook,
        Routes.community,
        Routes.you,
        Routes.mastery,
        Routes.shopping,
        Routes.settings,
        Routes.tasteEthiopia,
      ]) {
        expect(
          redirect(AuthStatus.signedIn, onboarded: true, path: path),
          isNull,
          reason: '$path should be reachable',
        );
      }
    });

    test('pre-app routes send the user home', () {
      for (final path in [
        Routes.splash,
        Routes.welcome,
        Routes.signIn,
        Routes.signUp,
        Routes.forgotPassword,
        Routes.onboardingSkill,
        Routes.onboardingTaste,
      ]) {
        expect(
          redirect(AuthStatus.signedIn, onboarded: true, path: path),
          Routes.home,
          reason: '$path should fall through to home',
        );
      }
    });

    test('a guest reaches the app exactly like a full account', () {
      // Guest mode is the whole point of "try it before signing up"; if this
      // regresses, guests get stranded.
      expect(
        redirect(AuthStatus.guest, onboarded: true, path: Routes.home),
        isNull,
      );
      expect(
        redirect(AuthStatus.guest, onboarded: true, path: Routes.welcome),
        Routes.home,
      );
    });
  });

  group('guest upgrade route', () {
    test('a guest can reach it', () {
      // The whole point of the screen: a guest converting to a permanent
      // account. Redirecting it to /home would make upgrading impossible.
      expect(
        redirect(
          AuthStatus.guest,
          onboarded: true,
          path: Routes.upgradeAccount,
        ),
        isNull,
      );
    });

    test('a signed-out user cannot', () {
      expect(
        redirect(
          AuthStatus.signedOut,
          onboarded: true,
          path: Routes.upgradeAccount,
        ),
        Routes.welcome,
      );
    });

    test('it is not a public path', () {
      expect(Routes.publicPaths, isNot(contains(Routes.upgradeAccount)));
    });
  });

  group('route table', () {
    test('every public path is a real route constant', () {
      expect(Routes.publicPaths, contains(Routes.welcome));
      expect(Routes.publicPaths, contains(Routes.splash));
      expect(Routes.publicPaths.length, 5);
    });

    test('onboarding paths are not also public', () {
      expect(
        Routes.publicPaths.intersection(Routes.onboardingPaths),
        isEmpty,
        reason: 'a path in both sets would make the guards ambiguous',
      );
    });

    test('parameterised path builders produce the declared shape', () {
      expect(Routes.recipeDetailOf('doro'), '/recipe/doro');
      expect(Routes.cookModeOf('doro'), '/recipe/doro/cook');
      expect(Routes.cookDoneOf('s1'), '/session/s1/done');
      expect(Routes.regionOf('gurage'), '/discover/region/gurage');
    });
  });
}
