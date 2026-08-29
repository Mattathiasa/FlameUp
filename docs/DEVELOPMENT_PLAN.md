# FlameUp — Development plan

Sixteen phases. Each ends with the analyzer clean, its tests passing, docs
updated, and one commit pushed to `origin/main`. A phase is not finished
because the screen renders — see **Definition of done** at the bottom.

Status legend: ✅ done · 🚧 in progress · ⬜ not started

---

## ✅ Phase 0 — Audit and design extraction
`docs: project audit and extracted design system` · commit `54e2d37`

The repository had no code and no design specification, so the specification
was recovered from the prototype bundle first.

- `tool/extract_design.py` decodes the Claude Design bundle into
  `design/extracted/`: `tokens.json` (20 dark + 20 light CSS variables, accent,
  blur, 6 keyframes), `strings.json` (206 EN/AM pairs), `seed.json` (12 dishes,
  8 regions, 9 achievements, 4 quests, 6 mastery tracks, 4 elders, feed,
  friends, leaderboard, shopping list, meal plan, tab bar), and the 30
  per-screen markup files.
- `docs/PROJECT_AUDIT.md` records the repository contents, the verified
  toolchain, the dependency ceiling Dart 3.3.4 imposes, and the existing
  `flameup-78d15` project.

---

## ✅ Phase 1 — Architecture and foundation
`docs: add GitHub Pages index.html and initial project setup`

- Flutter project at the repo root, `com.flameup.app` on both platforms.
- Dependencies pinned to the generation that resolves on Dart 3.3.4;
  `firebase_core` held at exactly 3.4.0.
- `flutterfire configure` against `flameup-78d15` — registered the missing iOS
  app and a non-`com.example` Android app.
- Gradle pinned to JDK 17; Android `minSdk 23`, multidex, core-library
  desugaring. iOS deployment target 13.0.
- Feature-first `lib/` skeleton; `Failure` / `Result` / `ErrorMapper`;
  connectivity, local store, analytics, crash reporting, Firebase bootstrap.
- go_router with a five-branch `StatefulShellRoute` and auth/onboarding guards.
- Localisation generated from the design copy — 239 strings in both languages.
- Noto Sans Ethiopic instanced to four static weights from the variable font.
- Docs: `ARCHITECTURE.md`, `DATABASE_SCHEMA.md`, `FIREBASE_SETUP.md`, this file.

**Acceptance** — analyzer clean, unit tests green, `flutter build apk --debug`
succeeds, and the redirect chain lands on the right screen for each auth state.

Also landed here: the **offline-first cache layer** (`feat: offline-first cache
layer and Android build fixes`) — see `docs/OFFLINE_MODE.md` — and the Android
toolchain upgrade to AGP 8.3.2 / Gradle 8.7 that the debug APK needed.

---

## ✅ Phase 2 — Design system
`feat: implement FlameUp design system`

Generate Dart from `design/extracted/tokens.json` rather than transcribing it.

`core/theme/`: `app_colors`, `app_typography`, `app_spacing`, `app_radii`,
`app_shadows`, `app_theme`.
`shared/widgets/`: `GlassPanel` (the blur + hairline + inset-highlight recipe
used on nearly every card), `GradientTile`, `FlameButton`, `PillChip`,
`XpBadge`, `ProgressBar`, `RingProgress`, `SectionHeader`, `DishCard`,
`EmptyState`, `ErrorState`, `LoadingState`, `ShimmerBox`, `FlameIcon`, and the
floating glass tab bar that replaces the Material one.

The palette is **generated** from `tokens.json` by `tool/generate_theme.py`
rather than transcribed — 19 colours × 2 themes, where hand-copying 40 rgba()
values would guarantee drift.

**Done.** 22 component tests covering both themes, Amharic overflow, semantics
and touch targets; `test/core/theme/app_theme_test.dart` asserts the Dart
constants against `tokens.json` so code and design cannot drift silently.
Deviations recorded in `design/PARITY.md`.

---

## ✅ Phase 3 — Authentication
`feat: implement authentication`

Splash, welcome, sign in, sign up, forgot password; Google, Apple, and guest
(anonymous). `AuthRepository` over `firebase_auth`; friendly error mapping.

The critical piece is **account upgrade**: `linkWithCredential` so a guest
becomes a permanent account without losing XP, history, achievements, saved
recipes, mastery or family recipes.

**Done.** `AuthRepository` covers email/password, Google, Apple, guest,
password reset, account deletion and the guest upgrade. `AuthController` keeps
submission state and failures out of the widgets. Splash, welcome and a single
`AuthFormScreen` (four modes) are built from the design.

The design has no auth screens — it goes splash → welcome → onboarding — so
that copy was written into `tool/l10n_extra.json` rather than borrowing
unrelated design strings. 261 strings now, 55 of them the app's own.

Two things worth noting:

- **Guest upgrade links in place.** `linkWithCredential` keeps the uid, so XP,
  history, achievements, mastery, saved and family recipes all survive. A spy
  test asserts the repository links rather than creating a second account,
  because `firebase_auth_mocks` cannot model the anonymous → permanent
  transition.
- **A real bug was found and fixed while testing:** sign-out cleared the Google
  session first, so a failure there meant Firebase sign-out never ran and the
  user stayed signed in. Firebase sign-out is now unconditional.

**Still blocked on the console** (documented in `FIREBASE_SETUP.md`): the
Email/Password, Anonymous, Google and Apple providers must be enabled in the
Firebase console, and Google needs the Android SHA fingerprints, before sign-in
works against the live project.

---

## ✅ Phase 4 — Onboarding
`feat: implement onboarding`

Skill level (3 options), heat tolerance (5 steps) and dietary flags (6
toggles), built from `03-skill.html` and `04-taste.html`.

**Local-first**, like everything else: every answer is written to disk as it is
given, so closing the app mid-flow resumes rather than restarts, and someone
installing on a bad signal still reaches the kitchen. The profile write to
`users/{uid}` goes through the outbox, so it lands whenever the device next has
a network and the user never waits on it.

`syncFromServer` reconciles after sign-in — a reinstalling user gets their
answers back from the server, while a device that answered offline keeps its
own, because those are newer than anything the server holds.

Enums serialise as ints and dietary flags as the design's own string keys, so
reordering an enum cannot corrupt saved profiles and an unknown flag from a
newer build is dropped rather than crashed on.

---

## ✅ Phase 5 — Recipe engine
`feat: implement recipe models, catalogue and offline-first repository`
`feat: build Discover and recipe detail screens`

- `Recipe`, `RecipeStep`, `Ingredient` with the brief's field set. Ingredient
  `quantity` is **numeric**, not `"4 large"`, because serving-size scaling has
  to multiply it; the display string is composed at render time and renders
  fractions (`¾ cup`, not `0.75 cup`) because that is how a cook reads.
- `RecipeRepository` reads offline-first through three layers: the **bundled
  catalogue** (always present, so a first run is never empty even with no
  network), the cache, then Firestore.
- `RecipeQuery` is a value type that doubles as a cache key, so two identical
  queries share one cache entry. Filters are pushed into indexed Firestore
  queries; the same predicates run in-memory against the bundle offline. It is
  never "download the collection and filter locally".
- Text search uses a stored `searchTokens` array (`array-contains-any`), with
  `SearchService` left as the seam for a dedicated backend later.

**The catalogue: 25 recipes**, built by `tool/build_seed.py` from the design's
12 plus 13 written for this project — Chechebsa, Genfo, Atakilt Wat, Bozena
Shiro, Fosolia, Alicha Wat, Ayib, Awaze, Tihlo, Shorba, Kinche, Ful, Ambasha.
Every one has full ingredients and steps **in both languages**, 97 of 115 steps
carry a duration so cook mode can time them, and each has a cultural note
written as *tradition rather than asserted history* — no dish is dated and no
inventor is named.

`tool/seed_firestore.dart` writes the same catalogue to Firestore or the
emulator, keyed by recipe id so re-running updates rather than duplicates.

**Screens:** Discover (`06-search`) with live search, filter chips and results
that keep showing cached data through a failed refresh; recipe detail
(`07-recipe`) with the ingredients / steps / story tabs and **live serving-size
scaling** — changing the count rescales every quantity and re-renders it as a
fraction. `DishCard` and `DishListTile` are the two card shapes the design
uses, both skipping the backdrop blur because a `BackdropFilter` per row is the
most expensive thing in a scrolling list.

## ✅ Phase 6 — Cooking engine *(critical milestone)*
`feat: implement cooking engine with wall-clock timers`
`feat: add timer notifications, finished and rate screens`

**Timers store absolute deadlines, not remaining seconds.** A timer is then a
subtraction against the wall clock, which stays correct whether the app was
backgrounded, killed, or the phone was asleep. The one-second ticker in
`CookingController` only triggers a repaint — it never *is* the timer, so a
missed tick cannot make one wrong. Coming back from the background recomputes
immediately rather than waiting for the next tick, so the number is right on
the first frame the user sees.

**Kill the app mid-cook and reopen it and the session resumes** — step, timers
and all — because every change is written to disk before it is queued for the
server. `resumableSessionProvider` surfaces it as the "pick up where you left"
card on Today.

**The idempotency key is minted when the session starts**, not when it
completes, so a retry after a crash carries the same key and the server refuses
a second XP grant. Completion records what happened; it does not award
anything — the client is not trusted with progression.

Pausing banks the remaining seconds and drops the deadline, because a paused
clock is not running. Resuming sets a fresh deadline from the banked seconds.

Leaving cook mode always asks first: backing out by accident would lose the
thread of what you were doing.

**OS-level alerts** fire when a step ends, so the phone can be put down.
Permission is requested when the first timer starts rather than at launch, so
the prompt arrives with a reason attached — and a refusal degrades the reminder
without breaking the timer, because the on-screen countdown is computed from
the deadline either way.

The finished (`09-done`) and rate (`10-rate`) screens complete the loop. The
finished screen does **not** invent an XP figure: rewards are granted
server-side, and a number the client made up would be a lie the moment the two
disagreed. A review always carries the session it rates, which is what lets the
server enforce that you can only rate what you actually cooked.

## ✅ Phase 7 — Gamification
`feat: implement gamification engine and server-authoritative rewards`

Engine, Cloud Functions, security rules and all five progress screens
(`11-progress`, `12-mastery`, `13-achv`, `14-quests`, `15-streak`).

Pure Dart, no Firebase imports, so the maths is tested without mocks:
`LevelCurve`, `StreakCalculator`, `MasteryCalculator`, `XpRules`,
`AchievementEvaluator`, `QuestEvaluator`. **113 tests** cover them.

The rules exist twice on purpose — Dart for the client's expected figure,
TypeScript for the server's real one. Sharing the code would ship the server's
rules to the client where they can be gamed. `test/features/gamification/` is
the specification for both. Full rationale in
[`GAMIFICATION.md`](GAMIFICATION.md).

**`claimCookingReward` is idempotent by construction**: the session's key is
written as a marker document *inside* the same transaction that applies the XP,
so a replay finds it and grants nothing.

**`firestore.rules` compiles against the live project** (verified by dry-run
deploy) and makes `xp`, `level`, `flames`, mastery and achievements
client-unwritable — using `diff().affectedKeys()`, so a user can edit their
display name in the same document without touching their XP. Reviews require an
existing *completed* session owned by the writer, enforced in the rules rather
than trusted from the client.

## ✅ Phase 8 — Ethiopian cultural system
`feat: implement Taste Ethiopia and family recipes`

Taste Ethiopia (`16-map`), region detail (`17-region`), Grandma's Kitchen
(`18-grandma`) and the family recipe form (`19-upload`) with local draft
saving — these are long forms, and losing one would be losing someone's
grandmother's recipe.

Submissions are written as `pending`, never `published`: the rules make the
author unable to approve their own work, so nothing user-written reaches the
public catalogue unreviewed.

**Two honest deviations.** Taste Ethiopia is a grid rather than a geographic
map — a real map needs boundary data with no authoritative source, and
approximating a country's internal borders is not a thing to guess at. And
Grandma's Kitchen leads with the contribution route instead of the design's
four named elders and their recordings, because those people do not exist and
inventing sources for cultural knowledge is exactly what this app must not do.

---

## 🚧 Phase 9 — Social
`feat: implement community, friends, challenges, leaderboards`

**Screens and backing exist; the interactions do not yet.**

Community (`20-feed`), friends (`21-friends`), challenges (`22-challenges`) and
leaderboard (`23-leader`) are built over their real Firestore collections, with
rules already enforcing the hard parts: a challenge participant cannot read the
other's submission until both exist, and like counts are trigger-maintained so
an author cannot inflate their own post.

The collections are empty until real people use them, and the screens say so
rather than shipping the design's sample posts as if they were real users.
Posting, commenting, friend requests and the challenge flow are the remaining
work.

---

## ✅ Phase 10 — Utilities
`feat: implement shopping list, meal planner, notifications`

Shopping list (`25-shop`) grouped by aisle, meal planner (`26-planner`),
favourites (`24-saved`), settings (`27-settings`) and the Today home screen
(`05-home`).

The list **merges** ingredient lines: two recipes that both want onions produce
one line, not two — the difference between a usable list and a transcript. It
will not merge into an already-checked line, because that would silently
un-buy what was bought. The planner is keyed by ISO week so "this week" cannot
change meaning on Sunday night.

Local-first without qualification: a shopping list is used *in a shop*, which
is exactly where signal fails.

FCM with per-category preferences is the remaining piece; cooking timers
already schedule OS-level alerts (Phase 6).

---

## ⬜ Phase 11 — AI assistant
`feat: implement AI cooking assistant backend`

Callable Cloud Function proxy — no provider key in the binary. Responses label
*recipe instruction*, *community tradition* and *AI suggestion* distinctly, and
never present cultural claims as authoritative.

---

## ⬜ Phase 12 — Polish
`feat: complete UI/UX polish pass`

Spacing, typography and animation parity against
`design/extracted/screens/*.html`; every loading / empty / error / offline
state; accessibility (semantic labels, 48dp targets, contrast, dynamic text,
accessible timers and rating controls); both themes; keyboard behaviour.

---

## ⬜ Phase 13 — Security audit
`feat: harden Firestore and Storage rules`

`firestore.rules` + `storage.rules` with rules tests on the emulator. Ownership,
roles, public/private, family-recipe permissions, server-only progression
fields. No `if true`.

---

## ⬜ Phase 14 — Testing
`test: unit, widget and integration coverage`

Unit for every calculator and ingredient scaling; widget for recipe card,
rating, quest card, cook screen, progress; integration for the brief's 40-step
journey including kill-and-resume and offline reconnect.

---

## ⬜ Phase 15 — Release preparation
`chore: production build configuration`

Android signing, R8, icons; iOS bundle id, signing, icons, launch screen;
Crashlytics, Analytics, App Check; `docs/DEPLOYMENT.md`.

---

## Definition of done

A phase is finished when, for each feature it delivers:

- the UI exists and matches its design file
- navigation works, including back and deep links
- data reads and writes for real
- loading, empty, error and offline states all exist
- validation exists
- security rules cover it
- tests exist
- `flutter analyze` reports no issues
- documentation reflects what was actually built

Anything that cannot be finished because a credential or service is missing
gets the proper abstraction, a documented gap, and a safe development
fallback — never a pretence that it works.
