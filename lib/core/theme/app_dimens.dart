import 'package:flutter/widgets.dart';

/// Corner radii, taken from the values the design actually uses.
///
/// Measured across the 30 screens rather than invented: the heavy hitters are
/// 22 (18 uses), 18 (18), 9 (22), 16 (16), 20 (15) and 11 (12). Those are
/// named; the long tail stays as literals rather than pretending the design
/// has a tidier scale than it does.
abstract final class AppRadii {
  /// Small chips, XP badges, inline pills.
  static const double xs = 8;

  /// Progress bars and tiny indicators.
  static const double sm = 9;

  /// List rows and compact tiles.
  static const double md = 11;

  /// Secondary buttons and small cards.
  static const double lg = 16;

  /// Primary buttons.
  static const double xl = 18;

  /// Selectable option cards.
  static const double xxl = 20;

  /// Dish cards and most content cards.
  static const double card = 22;

  /// Hero cards and large surfaces.
  static const double hero = 24;

  /// The floating tab bar.
  static const double bar = 26;

  /// Fully rounded -- 46 uses across the design.
  static const double pill = 999;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius xxlAll = BorderRadius.all(Radius.circular(xxl));
  static const BorderRadius cardAll = BorderRadius.all(Radius.circular(card));
  static const BorderRadius heroAll = BorderRadius.all(Radius.circular(hero));
  static const BorderRadius barAll = BorderRadius.all(Radius.circular(bar));
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(pill));
}

/// Spacing. The design lays out on a loose 4px grid with 20px screen gutters.
abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 6;
  static const double sm = 9;
  static const double md = 12;
  static const double lg = 14;
  static const double xl = 16;
  static const double xxl = 20;
  static const double xxxl = 26;

  /// Horizontal screen padding -- `padding: 0 20px` throughout.
  static const double gutter = 20;

  /// Top padding on a screen with no nav bar, clearing the status bar.
  static const double screenTop = 70;

  /// Bottom padding that clears the floating tab bar.
  static const double screenBottom = 130;

  static const EdgeInsets screenH = EdgeInsets.symmetric(horizontal: gutter);
}

/// The glass recipe, which appears on 73 elements across the design.
///
/// Every glass surface is the same four things: a translucent fill, a 20px
/// saturated blur, a half-pixel hairline, and an inset highlight along the top
/// edge. Centralised so it is identical everywhere.
abstract final class AppGlass {
  /// `backdrop-filter: blur(20px) saturate(1.7)`
  static const double blurSigma = 20;
  static const double saturation = 1.7;

  /// `.5px solid var(--gl)` -- a real hairline, not a 1px approximation.
  static const double hairline = 0.5;

  /// `inset 0 1px 0 rgba(255,255,255,.06)` along the top edge.
  static const double insetHighlight = 1;
}

/// Minimum interactive size. Material asks for 48; the design's smaller
/// controls get their touch target expanded rather than the visual shrunk.
abstract final class AppTouch {
  static const double minTarget = 48;
  static const Size minSize = Size(minTarget, minTarget);
}
