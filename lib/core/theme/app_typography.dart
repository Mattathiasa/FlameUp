import 'package:flutter/material.dart';

/// The type scale, read off the design.
///
/// The prototype writes type as CSS shorthand (`font: 600 15px/1.2 ...`), so
/// these are the literal size/weight/line-height/letter-spacing triples it
/// uses, not a scale invented afterwards. Sizes were counted across all 30
/// screens: 15px and 16px dominate body copy, 9.5px is the eyebrow, and 33px
/// is the greeting.
///
/// One family covers Latin and Ethiopic, so an English/Amharic sentence never
/// changes font mid-line.
abstract final class AppTypography {
  static const String family = 'NotoSansEthiopic';

  /// Weight 200. Only the cook-mode countdown uses it.
  static const FontWeight extraLight = FontWeight.w200;
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semiBold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;

  // --- display -----------------------------------------------------------

  /// The cook-mode timer. `font: 200 54px/1`, hairline on purpose.
  static const TextStyle timer = TextStyle(
    fontFamily: family,
    fontSize: 54,
    height: 1,
    fontWeight: extraLight,
    letterSpacing: -1.5,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Welcome headline. `font: 700 40px/1.04`, letter-spacing -1.5.
  static const TextStyle displayLarge = TextStyle(
    fontFamily: family,
    fontSize: 40,
    height: 1.04,
    fontWeight: bold,
    letterSpacing: -1.5,
  );

  /// Splash wordmark. `font: 700 34px/1`.
  static const TextStyle displayMedium = TextStyle(
    fontFamily: family,
    fontSize: 34,
    height: 1,
    fontWeight: bold,
    letterSpacing: -1.1,
  );

  /// The home greeting name. `font: 700 33px/1.05`.
  static const TextStyle displaySmall = TextStyle(
    fontFamily: family,
    fontSize: 33,
    height: 1.05,
    fontWeight: bold,
    letterSpacing: -1.2,
  );

  // --- headings ----------------------------------------------------------

  /// Onboarding question. `font: 700 30px/1.12`.
  static const TextStyle headlineLarge = TextStyle(
    fontFamily: family,
    fontSize: 30,
    height: 1.12,
    fontWeight: bold,
    letterSpacing: -1,
  );

  /// Region title on a hero card. `font: 700 22px/1.05`.
  static const TextStyle headlineMedium = TextStyle(
    fontFamily: family,
    fontSize: 22,
    height: 1.05,
    fontWeight: bold,
    letterSpacing: -0.7,
  );

  /// Section header. `font: 700 20px/1`.
  static const TextStyle headlineSmall = TextStyle(
    fontFamily: family,
    fontSize: 20,
    height: 1,
    fontWeight: bold,
    letterSpacing: -0.6,
  );

  // --- titles ------------------------------------------------------------

  /// Card title. `font: 600 17px/1.15`.
  static const TextStyle titleLarge = TextStyle(
    fontFamily: family,
    fontSize: 17,
    height: 1.15,
    fontWeight: semiBold,
    letterSpacing: -0.4,
  );

  /// Dish card title. `font: 600 16px/1.15`.
  static const TextStyle titleMedium = TextStyle(
    fontFamily: family,
    fontSize: 16,
    height: 1.15,
    fontWeight: semiBold,
    letterSpacing: -0.4,
  );

  /// Row title. `font: 600 14.5px/1.2`.
  static const TextStyle titleSmall = TextStyle(
    fontFamily: family,
    fontSize: 14.5,
    height: 1.2,
    fontWeight: semiBold,
    letterSpacing: -0.2,
  );

  // --- body --------------------------------------------------------------

  /// Lead paragraph. `font: 400 16px/1.55`.
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: family,
    fontSize: 16,
    height: 1.55,
    fontWeight: regular,
  );

  /// Standard body. `font: 400 15px/1.5` -- the most common style in the app.
  static const TextStyle bodyMedium = TextStyle(
    fontFamily: family,
    fontSize: 15,
    height: 1.5,
    fontWeight: regular,
  );

  /// Supporting copy. `font: 400 13.5px/1.4`.
  static const TextStyle bodySmall = TextStyle(
    fontFamily: family,
    fontSize: 13.5,
    height: 1.4,
    fontWeight: regular,
  );

  /// Card subtitle. `font: 400 12.5px/1.35`.
  static const TextStyle caption = TextStyle(
    fontFamily: family,
    fontSize: 12.5,
    height: 1.35,
    fontWeight: regular,
  );

  // --- labels ------------------------------------------------------------

  /// Button text. `font: 600 16px/1`.
  static const TextStyle button = TextStyle(
    fontFamily: family,
    fontSize: 16,
    height: 1,
    fontWeight: semiBold,
    letterSpacing: -0.2,
  );

  /// Chip and metadata label. `font: 600 11.5px/1`.
  static const TextStyle label = TextStyle(
    fontFamily: family,
    fontSize: 11.5,
    height: 1,
    fontWeight: semiBold,
  );

  /// Tab bar label. `font: 600 9.5px/1`.
  static const TextStyle tabLabel = TextStyle(
    fontFamily: family,
    fontSize: 9.5,
    height: 1,
    fontWeight: semiBold,
    letterSpacing: 0.01,
  );

  /// Section eyebrow -- uppercase, tracked out.
  /// `font: 600 9.5px/1; letter-spacing: .1em; text-transform: uppercase`.
  static const TextStyle eyebrow = TextStyle(
    fontFamily: family,
    fontSize: 9.5,
    height: 1,
    fontWeight: semiBold,
    letterSpacing: 0.95, // .1em at 9.5px
  );

  /// XP badge. `font: 700 11px/1`.
  static const TextStyle badge = TextStyle(
    fontFamily: family,
    fontSize: 11,
    height: 1,
    fontWeight: bold,
  );

  /// Builds the [TextTheme] Material widgets read from.
  static TextTheme textTheme(Color primary, Color secondary) => TextTheme(
        displayLarge: displayLarge.copyWith(color: primary),
        displayMedium: displayMedium.copyWith(color: primary),
        displaySmall: displaySmall.copyWith(color: primary),
        headlineLarge: headlineLarge.copyWith(color: primary),
        headlineMedium: headlineMedium.copyWith(color: primary),
        headlineSmall: headlineSmall.copyWith(color: primary),
        titleLarge: titleLarge.copyWith(color: primary),
        titleMedium: titleMedium.copyWith(color: primary),
        titleSmall: titleSmall.copyWith(color: primary),
        bodyLarge: bodyLarge.copyWith(color: primary),
        bodyMedium: bodyMedium.copyWith(color: secondary),
        bodySmall: bodySmall.copyWith(color: secondary),
        labelLarge: button.copyWith(color: primary),
        labelMedium: label.copyWith(color: secondary),
        labelSmall: tabLabel.copyWith(color: secondary),
      );
}
