# Design parity checklist

Tracks each component against the design it came from. "Source" is the file
under `design/extracted/screens/` the measurements were taken from; the token
values come from `tokens.json` via `tool/generate_theme.py`.

Legend: ✅ built and matching · 🚧 partial · ⬜ not built

---

## Foundations

| Item | Status | Source of truth | Notes |
|---|:--:|---|---|
| Colour palette | ✅ | `tokens.json` | **Generated**, not transcribed — 19 colours × 2 themes via `tool/generate_theme.py` |
| Accent + alternates | ✅ | `tokens.json` | `#FF6A2B`, 3 alternates the design offers |
| Type scale | ✅ | measured across 30 screens | Literal size/weight/line-height triples, not an invented scale |
| Radii | ✅ | measured | Named the 6 heavily-used values; long tail stays literal |
| Spacing | ✅ | measured | 20px gutter, 4px-ish grid |
| Shadows | ✅ | `--sh` + inline | Light shadow is warm (`rgba(120,60,20,.13)`), not neutral grey |
| Motion | ✅ | 6 keyframes | `fu-in`, `fu-grow`, `fu-sheen`, `fu-flick`, `fu-rise`, `fu-spin` |
| Fonts | ✅ | — | 5 weights instanced from the variable font; **all 217 characters in the design copy verified present** |

## Components

| Component | Status | Uses in design | Notes |
|---|:--:|---:|---|
| `GlassPanel` | ✅ | 73 | Fill + 20px saturated blur + `.5px` hairline + inset top highlight. `blur: false` escape hatch for long lists |
| `GradientTile` | ✅ | 17 | `150deg` pair + radial sheen; optional scrim and real-photo overlay |
| `FlameButton` | ✅ | 20 | `160deg` accent gradient, accent glow, `fu-sheen` sweep; sheen stops when disabled |
| `PillChip` | ✅ | 46 | 32px visual, **48px touch target** |
| `XpBadge` | ✅ | — | Gold `.16` fill / `.36` border |
| `Eyebrow` | ✅ | 14 | Uppercase, `.1em` tracking |
| `FlameProgressBar` | ✅ | — | `fu-grow` fill animation, clamps bad input |
| `RingProgress` | ✅ | — | Mastery rings, cook timer |
| `SectionHeader` | ✅ | — | Title + optional action |
| `FlameIcon` | ✅ | — | The SVG flame as a `CustomPainter`; optional `fu-flick` |
| `FlameTabBar` | ✅ | — | Floating glass pill, 5 icons parsed from the design's path data |
| `ErrorView` / `EmptyView` | ✅ | 3 screens | System states |
| `ShimmerBox` | ✅ | — | Only for a genuinely cold cache |
| `StaleBanner` | ✅ | — | **New** — offline-first needs a way to say "this is saved data" |
| `DishCard` | ⬜ | 17 | Phase 5 |
| Bottom sheet / dialog | 🚧 | — | Themed; bespoke variants in Phase 12 |

## Known deviations

Each is deliberate. None is an accident of implementation.

1. **`StaleBanner` is not in the design.** Offline-first needs to tell the user
   the content is cached without hiding it. The prototype has an offline
   *screen* but no in-place indicator, which would mean either lying about
   freshness or blanking content the user could still read.

2. **Touch targets are enlarged, visuals are not.** The design's pills are
   32px and some icon buttons 28px, below the 48px accessible minimum. The
   tappable box is expanded around the unchanged visual rather than scaling the
   design up.

3. **Weight 200 needed a fifth font instance.** `08-cook.html` sets the 54px
   countdown at `font-weight: 200`. Only four weights were instanced at first,
   so it silently fell back to 400 — the hairline stroke is the whole point of
   that number, so ExtraLight was added.

4. **The 150° gradient is approximated.** CSS measures gradient angles
   clockwise from vertical; Flutter uses begin/end alignments. `Alignment(-0.5,-1)
   → (0.5,1)` is the closest match and is visually indistinguishable at tile
   sizes.

5. **Glass blur is opt-out.** A real `BackdropFilter` per row is expensive in a
   long scroll. Lists pass `blur: false` and keep the translucent fill; with no
   vivid content behind, the difference is invisible and the frame budget is not.

## Verification

- `test/shared/components_test.dart` — every component in **both themes**, plus
  an Amharic overflow check, semantics assertions and touch-target sizes.
- `test/core/theme/app_theme_test.dart` — asserts the Dart constants against
  `tokens.json`, so code and design cannot drift apart silently.
