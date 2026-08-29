# FlameUp 🔥

**Cook. Discover. Master.**

A gamified Ethiopian cooking app: discover a dish, cook it with guided steps and
real timers, rate it, earn XP, build mastery — and preserve the family recipes
that raised you.

Not a recipe app with gamification. A cooking game, an Ethiopian food discovery
platform, a family recipe archive and a social cooking experience, in one.

Flutter · Riverpod · go_router · Firebase · English + አማርኛ

---

## Getting started

```bash
flutter pub get
flutter gen-l10n
flutter run
```

Requires **Flutter 3.19.6 / Dart 3.3.4** — dependencies are pinned to the
generation that resolves on it. See `docs/PROJECT_AUDIT.md` §2.1 before
upgrading anything.

Android builds need **JDK 17**. It is already pinned in
`android/gradle.properties`; the machine default is JDK 25, which the Gradle
7.6 wrapper cannot run on.

### Against the local emulator suite

```bash
firebase emulators:start --only auth,firestore,functions,storage
flutter run --dart-define=USE_FIREBASE_EMULATOR=true
# Android emulator reaches the host at 10.0.2.2:
flutter run --dart-define=USE_FIREBASE_EMULATOR=true \
            --dart-define=FIREBASE_EMULATOR_HOST=10.0.2.2
```

---

## Layout

```
lib/            the app — see docs/ARCHITECTURE.md
functions/      Cloud Functions (server-authoritative XP, leaderboards, AI proxy)
design/         the Claude Design prototype and the spec extracted from it
  extracted/    tokens.json · strings.json · seed.json · screens/*.html
docs/           audit, architecture, schema, plan, Firebase setup
tool/           extract_design.py · generate_l10n.py · seed_firestore.dart
test/           unit and widget tests
github-pages/   the browsable prototype, unchanged
```

`design/extracted/` is **generated** from the prototype bundle, and is the
specification every screen is built against:

```bash
python3 tool/extract_design.py     # re-decode the prototype
python3 tool/generate_l10n.py      # rebuild the ARB files from the design copy
flutter gen-l10n
```

Do not hand-edit `lib/l10n/*.arb` or `lib/l10n/generated/`.

---

## Checks

```bash
flutter analyze
flutter test
dart format lib test tool
```

---

## Two things worth knowing up front

**Cloud Functions are not deployed.** The `flameup-78d15` Firebase project is
on the Spark plan, and Functions require Blaze. They are written and run
against the emulator; Firestore rules already forbid client-side XP writes, so
the app's code path is the production one. A release build against the live
project cannot award XP until the project is upgraded.
Details: `docs/FIREBASE_SETUP.md`.

**FlameUp is offline-first.** Cached data is shown immediately and always;
writes made offline are queued with idempotency keys and replayed in order when
the connection returns. A failed refresh keeps showing saved data rather than
blanking the screen. See `docs/OFFLINE_MODE.md`.

**There is no recipe photography.** The design uses two-colour gradient tiles
per dish, and so does the app. The Firebase Storage upload path is built for
real, so photographs drop in without a code change.

---

## Documentation

| | |
|---|---|
| [`PROJECT_AUDIT.md`](docs/PROJECT_AUDIT.md) | what existed, the toolchain, the constraints |
| [`ARCHITECTURE.md`](docs/ARCHITECTURE.md) | structure, state, errors, navigation, offline |
| [`DATABASE_SCHEMA.md`](docs/DATABASE_SCHEMA.md) | the Firestore model and why it is shaped that way |
| [`DEVELOPMENT_PLAN.md`](docs/DEVELOPMENT_PLAN.md) | the phases and their status |
| [`OFFLINE_MODE.md`](docs/OFFLINE_MODE.md) | offline-first reads, the outbox, why XP cannot double |
| [`FIREBASE_SETUP.md`](docs/FIREBASE_SETUP.md) | project, emulators, what still needs the console |
