import 'package:flameup/l10n/generated/app_localizations.dart';
import 'package:flameup/l10n/generated/app_localizations_am.dart';
import 'package:flameup/l10n/generated/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every `messageKey` a [Failure] can carry. If ErrorMapper gains a key that
/// tool/l10n_extra.json does not define, this fails at test time instead of
/// rendering a blank error to a user.
const _failureMessageKeys = <String>[
  'errorOffline',
  'errorServer',
  'errorPermission',
  'errorNotFound',
  'errorCache',
  'errorCancelled',
  'errorUnknown',
  'errorTimeout',
  'errorBadResponse',
  'errorInvalidRequest',
  'errorConflict',
  'authErrorInvalidEmail',
  'authErrorUserDisabled',
  'authErrorInvalidCredentials',
  'authErrorEmailInUse',
  'authErrorWeakPassword',
  'authErrorOperationNotAllowed',
  'authErrorRequiresRecentLogin',
  'authErrorTooManyRequests',
  'authErrorAccountExistsDifferentCredential',
  'authErrorCredentialInUse',
  'authErrorProviderAlreadyLinked',
  'authErrorGeneric',
  'authErrorSignedOut',
];

/// The generated class exposes one getter per key; reflection is unavailable,
/// so resolution goes through an explicit table. Adding a key here alongside
/// the constant above is the whole maintenance cost.
String? _resolve(AppLocalizations l, String key) => switch (key) {
      'errorOffline' => l.errorOffline,
      'errorServer' => l.errorServer,
      'errorPermission' => l.errorPermission,
      'errorNotFound' => l.errorNotFound,
      'errorCache' => l.errorCache,
      'errorCancelled' => l.errorCancelled,
      'errorUnknown' => l.errorUnknown,
      'errorTimeout' => l.errorTimeout,
      'errorBadResponse' => l.errorBadResponse,
      'errorInvalidRequest' => l.errorInvalidRequest,
      'errorConflict' => l.errorConflict,
      'authErrorInvalidEmail' => l.authErrorInvalidEmail,
      'authErrorUserDisabled' => l.authErrorUserDisabled,
      'authErrorInvalidCredentials' => l.authErrorInvalidCredentials,
      'authErrorEmailInUse' => l.authErrorEmailInUse,
      'authErrorWeakPassword' => l.authErrorWeakPassword,
      'authErrorOperationNotAllowed' => l.authErrorOperationNotAllowed,
      'authErrorRequiresRecentLogin' => l.authErrorRequiresRecentLogin,
      'authErrorTooManyRequests' => l.authErrorTooManyRequests,
      'authErrorAccountExistsDifferentCredential' =>
        l.authErrorAccountExistsDifferentCredential,
      'authErrorCredentialInUse' => l.authErrorCredentialInUse,
      'authErrorProviderAlreadyLinked' => l.authErrorProviderAlreadyLinked,
      'authErrorGeneric' => l.authErrorGeneric,
      'authErrorSignedOut' => l.authErrorSignedOut,
      _ => null,
    };

void main() {
  final english = AppLocalizationsEn();
  final amharic = AppLocalizationsAm();

  test('English and Amharic are both supported', () {
    expect(
      AppLocalizations.supportedLocales,
      containsAll(const [Locale('en'), Locale('am')]),
    );
  });

  group('every Failure message key resolves', () {
    for (final key in _failureMessageKeys) {
      test('$key has copy in both languages', () {
        final en = _resolve(english, key);
        final am = _resolve(amharic, key);

        expect(en, isNotNull, reason: '$key missing from English');
        expect(am, isNotNull, reason: '$key missing from Amharic');
        expect(en, isNotEmpty);
        expect(am, isNotEmpty);
      });
    }
  });

  group('design copy survived the ARB round trip', () {
    test('keys renamed to dodge Dart keywords kept their wording', () {
      // `continue` and `of` are Dart keywords, so tool/generate_l10n.py renames
      // the identifiers. The copy itself must be untouched.
      expect(english.continueLabel, 'Continue');
      expect(amharic.continueLabel, 'ቀጥል');
      expect(english.ofWord, 'of');
      expect(amharic.ofWord, 'ከ');
    });

    test('Amharic is genuinely translated, not an English fallback', () {
      expect(amharic.tagline, isNot(english.tagline));
      expect(amharic.tabToday, 'ዛሬ');
      expect(amharic.appName, 'ፍሌም አፕ');
    });

    test('tab labels are present for all five branches', () {
      for (final label in [
        english.tabToday,
        english.tabExplore,
        english.tabCook,
        english.tabComm,
        english.tabYou,
      ]) {
        expect(label, isNotEmpty);
      }
    });
  });
}
