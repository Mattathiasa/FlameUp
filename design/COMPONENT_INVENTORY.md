# FlameUp — component inventory

Measured from the 30 extracted screens, not guessed. Regenerate the counts with
the snippet at the bottom.

**638 styled elements across 30 screens.** The repetition is what makes a
component library worth building: six style recipes account for most of it.

| Recipe | Uses | Becomes |
|---|---:|---|
| `backdrop-filter: blur(20px) saturate(1.7)` + `.5px` hairline + inset highlight | **73** | `GlassPanel` |
| Fully-rounded pill (`border-radius: 999px` / `99px`) | 46 | `PillChip`, `FlameButton`, glass pills |
| Keyframe animation (`fu-in`, `fu-grow`, `fu-sheen`, …) | 37 | `AppMotion` helpers |
| `linear-gradient(160deg, --acc, #DE3A18)` | 20 | `FlameButton`, circular action buttons |
| `linear-gradient(150deg, a, b)` | 17 | `GradientTile` (dish / region / collection art) |
| `radial-gradient(120% 80% at 24% 12%, white .3, transparent)` | 16 | sheen overlay inside `GradientTile` |

## Token usage, ranked

How often each CSS variable is referenced — this is the priority order for
`app_colors.dart`.

```
--tx   101   primary text          --acc   40   accent
--gl    90   hairline border       --fld   22   field fill
--blur  72   glass blur radius     --hr    21   divider
--t2    63   secondary text        --sh    21   shadow
--t3    59   tertiary text         --g2    10   raised glass
--g1    56   glass fill            --scr    8   screen background
--in    47   input / inset fill
```

Three text tiers (`--tx`, `--t2`, `--t3`) carry 223 of the references between
them, so the type scale is built around those before anything else.

## Radii

`6, 7, 8, 9, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 24, 26, 28, 30`
plus `99`/`999` for pills.

The heavily-used values cluster: **9** (×22), **16** (×16), **18** (×18),
**20** (×15), **22** (×18), **11** (×12). `AppRadii` names those and keeps the
long tail as literals rather than inventing a scale the design does not have.

## Type scale

Sizes actually used, most common first: **15** (×23), **16** (×21), **9.5**
(×14), **12.5** (×13), **15.5** (×13), **33** (×12 — the greeting/H1),
**13.5**, **14**, **11**, **11.5**, **10**, **17**, **13**. The long tail runs
to 54px.

Weights: **600** (×100), **700** (×59), **500** (×45), **400** (×40) — matching
the four static instances in `assets/fonts/`.

> **One exception:** `08-cook.html` uses `font: 200 54px` for the large timer
> readout. Weight 200 is not among the instanced weights, so it currently
> renders at 400. Phase 2 instances an ExtraLight face for it — the countdown
> is the visual centre of cook mode and the hairline weight is the point.

## Screens by markup size

Rough build effort, largest first: `recipe` (104 lines), `home` (82),
`settings` (81), `progress` (73), `cook` (52), `challenges` (47), `done` (44),
`feed` (43), `taste` (41), `streak` (41). The three system states (`error`,
`offline`, `empty`) are 9–19 lines each.

---

```bash
cd design/extracted/screens
grep -ho 'style="[^"]*"' *.html | grep -c backdrop-filter    # glass count
grep -ho 'border-radius:[0-9]*px' *.html | sort | uniq -c | sort -rn
grep -ho 'var(--[a-z0-9]*' *.html | sort | uniq -c | sort -rn
```
