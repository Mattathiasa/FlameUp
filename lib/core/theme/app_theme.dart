import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_dimens.dart';
import 'app_typography.dart';

/// Assembles the design tokens into [ThemeData].
///
/// The palettes in [AppColors] are generated from
/// `design/extracted/tokens.json` by `tool/generate_theme.py`; this file wires
/// them into Material and nothing more. Widgets read [AppPalette] directly for
/// the design's own surfaces (glass, ambient glows, text tiers) because those
/// have no Material equivalent.
abstract final class AppTheme {
  /// Convenience re-exports, so callers do not import three files for a colour.
  static const Color accent = AppColors.accent;
  static const Color darkBackground = Color(0xFF0C0908);
  static const Color darkSurface = Color(0xFF14100E);
  static const Color darkText = Color(0xFFFFF6EE);
  static const Color lightBackground = Color(0xFFEDE3D6);
  static const Color lightSurface = Color(0xFFFCF7F0);
  static const Color lightText = Color(0xFF1D120C);

  static const String fontFamily = AppTypography.family;

  static ThemeData get dark => _build(Brightness.dark, AppColors.dark);
  static ThemeData get light => _build(Brightness.light, AppColors.light);

  static ThemeData _build(Brightness brightness, AppPalette palette) {
    final isDark = brightness == Brightness.dark;

    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: brightness,
    ).copyWith(
      primary: AppColors.accent,
      onPrimary: Colors.white,
      surface: palette.surface,
      onSurface: palette.textPrimary,
      outline: palette.glassBorder,
      error: const Color(0xFFC0301C),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: AppTypography.family,
      scaffoldBackgroundColor: palette.background,
      canvasColor: palette.surface,
      dividerColor: palette.divider,
      splashFactory: InkSparkle.splashFactory,
      textTheme:
          AppTypography.textTheme(palette.textPrimary, palette.textSecondary),

      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        foregroundColor: palette.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle:
            AppTypography.headlineSmall.copyWith(color: palette.textPrimary),
        systemOverlayStyle:
            isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),

      // The design's tab bar is a floating glass pill rendered by
      // FlameTabBar; this only styles the Material fallback.
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.tabBar,
        indicatorColor: AppColors.accent.withOpacity(0.18),
        surfaceTintColor: Colors.transparent,
        labelTextStyle: MaterialStatePropertyAll(
          AppTypography.tabLabel.copyWith(color: palette.textSecondary),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(56),
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.xlAll),
          textStyle: AppTypography.button,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.textPrimary,
          minimumSize: const Size.fromHeight(50),
          side:
              BorderSide(color: palette.glassBorder, width: AppGlass.hairline),
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.lgAll),
          textStyle: AppTypography.button,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
          textStyle: AppTypography.bodySmall.copyWith(
            fontWeight: AppTypography.medium,
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.fieldFill,
        hintStyle:
            AppTypography.bodyMedium.copyWith(color: palette.textTertiary),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: AppRadii.lgAll,
          borderSide:
              BorderSide(color: palette.glassBorder, width: AppGlass.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadii.lgAll,
          borderSide:
              BorderSide(color: palette.glassBorder, width: AppGlass.hairline),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: AppRadii.lgAll,
          borderSide: BorderSide(color: AppColors.accent, width: 1.5),
        ),
      ),

      cardTheme: CardTheme(
        color: palette.glass,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.cardAll),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadii.bar)),
        ),
      ),

      dialogTheme: DialogTheme(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.heroAll),
        titleTextStyle:
            AppTypography.titleLarge.copyWith(color: palette.textPrimary),
        contentTextStyle:
            AppTypography.bodyMedium.copyWith(color: palette.textSecondary),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.glassRaised,
        contentTextStyle:
            AppTypography.bodySmall.copyWith(color: palette.textPrimary),
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.mdAll),
        behavior: SnackBarBehavior.floating,
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accent,
        linearMinHeight: 4,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: palette.glass,
        side: BorderSide(color: palette.glassBorder, width: AppGlass.hairline),
        labelStyle: AppTypography.label.copyWith(color: palette.textSecondary),
        shape: const StadiumBorder(),
      ),
    );
  }
}
