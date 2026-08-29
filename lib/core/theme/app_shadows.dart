import 'package:flutter/material.dart';

/// Elevation, taken from the design's `--sh` token and the per-element shadows
/// it writes inline.
abstract final class AppShadows {
  /// Dark `--sh`: `0 14px 34px rgba(0,0,0,.45)`.
  static const List<BoxShadow> cardDark = [
    BoxShadow(
      color: Color(0x73000000),
      offset: Offset(0, 14),
      blurRadius: 34,
    ),
  ];

  /// Light `--sh`: `0 14px 34px rgba(120,60,20,.13)` -- warm, not neutral
  /// grey, which is what keeps the light theme from looking cold.
  static const List<BoxShadow> cardLight = [
    BoxShadow(
      color: Color(0x21783C14),
      offset: Offset(0, 14),
      blurRadius: 34,
    ),
  ];

  /// The glow under a primary action:
  /// `0 8px 20px rgba(255,80,30,.4)`.
  static const List<BoxShadow> accentGlow = [
    BoxShadow(
      color: Color(0x66FF501E),
      offset: Offset(0, 8),
      blurRadius: 20,
    ),
  ];

  static List<BoxShadow> card(Brightness brightness) =>
      brightness == Brightness.dark ? cardDark : cardLight;
}

/// The design's keyframes, as durations and curves.
///
/// Six animations run throughout: `fu-in` (content entry), `fu-grow`
/// (progress bars), `fu-sheen` (the sweep across a primary button),
/// `fu-flick` (the flame), `fu-rise` (XP floating up), `fu-spin`.
abstract final class AppMotion {
  /// `fu-in .4s ease` -- fade and rise, on every screen's root.
  static const Duration entry = Duration(milliseconds: 400);
  static const Offset entryOffset = Offset(0, 12);

  /// `fu-grow 1s cubic-bezier(.3,.9,.3,1)` -- progress bars filling.
  static const Duration grow = Duration(seconds: 1);
  static const Cubic growCurve = Cubic(0.3, 0.9, 0.3, 1);

  /// `fu-sheen 3.4s` -- the highlight sweeping a primary button.
  static const Duration sheen = Duration(milliseconds: 3400);

  /// `fu-flick` -- the flame icon's flicker.
  static const Duration flicker = Duration(milliseconds: 1800);

  /// `fu-rise` -- an XP number floating up and fading.
  static const Duration rise = Duration(milliseconds: 1200);

  /// Standard state change: a tap, a selection, a theme switch.
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration medium = Duration(milliseconds: 280);

  /// Theme crossfade -- the design uses `transition: background .45s ease`.
  static const Duration theme = Duration(milliseconds: 450);

  static const Curve standard = Curves.easeOutCubic;
}
