import 'package:flutter/material.dart';

/// Application theme.
///
/// Phase 1 wires up only what the shell needs to boot correctly: the real
/// accent, surface and text colours taken from `design/extracted/tokens.json`,
/// and the Amharic-capable font family. Phase 2 generates the full token set
/// (glass surfaces, text tiers, hairlines, shadows, ambient glows, radii and
/// the type scale) from that same file and builds the component library on top.
abstract final class AppTheme {
  /// `accent` in tokens.json.
  static const Color accent = Color(0xFFFF6A2B);

  /// Dark `--bg` / `--scr`.
  static const Color darkBackground = Color(0xFF0C0908);
  static const Color darkSurface = Color(0xFF14100E);
  static const Color darkText = Color(0xFFFFF6EE);

  /// Light `--bg` / `--scr`.
  static const Color lightBackground = Color(0xFFEDE3D6);
  static const Color lightSurface = Color(0xFFFCF7F0);
  static const Color lightText = Color(0xFF1D120C);

  /// Noto Sans Ethiopic covers both Latin and Ethiopic, so one family renders
  /// English and Amharic without a fallback hop mid-sentence.
  static const String fontFamily = 'NotoSansEthiopic';

  static ThemeData get dark => _base(
        brightness: Brightness.dark,
        background: darkBackground,
        surface: darkSurface,
        onSurface: darkText,
      );

  static ThemeData get light => _base(
        brightness: Brightness.light,
        background: lightBackground,
        surface: lightSurface,
        onSurface: lightText,
      );

  static ThemeData _base({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color onSurface,
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
    ).copyWith(
      primary: accent,
      surface: surface,
      onSurface: onSurface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: onSurface,
        elevation: 0,
        centerTitle: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: accent.withOpacity(0.18),
      ),
    );
  }
}
