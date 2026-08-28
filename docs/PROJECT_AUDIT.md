# FlameUp — Project Audit (Phase 0)

Audit performed before any application code was written, per the development
brief's Phase 0 requirement. Everything below was verified on this machine
rather than assumed.

---

## 1. What the repository contained

A single commit, `26b497e "Initial Commit and Design Commit"`, holding four files:

| File | Size | What it actually is |
|---|---|---|
| `FlameUp Prototype.html` | 1,516,520 B | Claude Design bundle — the prototype |
| `github-pages/index.html` | 1,516,520 B | **Byte-identical copy** of the above |
| `github-pages/README.md` | 1,611 B | GitHub Pages *publishing* instructions |
| `github-pages/.nojekyll` | 0 B | Stops Jekyll processing on Pages |

`../Flame Up mobile app design.zip` contains the same three `github-pages/` files
and nothing more.

**There was no application code**: no `pubspec.yaml`, no `lib/`, no `android/`,
no `ios/`, no Firebase configuration, no assets.

**There were no design specification documents.** The only `.md` in the
repository was the Pages publishing README. The implementation-handoff notes that
were expected to accompany the prototype do not exist on disk. Phase 0 therefore
reconstructs them from the prototype itself (section 4).

### Changes made in Phase 0

- `FlameUp Prototype.html` → `design/FlameUp Prototype.html`.
- `github-pages/` left untouched, so any existing Pages deployment keeps working.

---

## 2. Toolchain

| Tool | Version | Notes |
|---|---|---|
| Flutter | **3.19.6** (channel `[user-branch]`, 2024-04-17) | |
| Dart | **3.3.4** | Host is `macos_x64` — an Intel Mac |
| Xcode | 15.2 (15C5500c) | iOS 17 simulators present (iPhone 15 family, SE 3rd gen) |
| CocoaPods | 1.16.2 | |
| Android SDK | present | `build-tools`, `cmake`, `cmdline-tools`, `emulator`, `ndk` |
| JDK | 25.0.2 *(default)*, **17.0.18**, 1.8.0_482 | Android Studio also bundles JBR 21 |
| Firebase CLI | 15.17.0 | authenticated as `mattathiasabraham@gmail.com` |
| FlutterFire CLI | installed at `~/.pub-cache/bin/flutterfire` | |
| Node / npm | 22.11.0 / 10.9.0 | for Cloud Functions |
| GitHub CLI | 2.89.0 | authenticated as `Mattathiasa` |

Git remote: `https://github.com/Mattathiasa/FlameUp.git`.

### 2.1 Toolchain constraints that shape the build

**Dart 3.3.4 caps every dependency.** Current pub releases require far newer
SDKs — `flutter_riverpod` 3.4.2 and `go_router` 18.0.0 need Dart `^3.12.0`;
`firebase_core` 4.14.0, `cloud_firestore` 6.9.0 and `firebase_auth` 6.6.1 need
`^3.6.0`. None of them resolve here.

We therefore pin to the versions already proven on this exact SDK by the sibling
projects in `~/Documents/Matty`:

| Package | Pin | Proven by |
|---|---|---|
| `flutter_riverpod` | `^2.5.1` | `red_cross_app` |
| `go_router` | `^14.2.7` | `red_cross_app` |
| `firebase_core` | `^3.4.0` | `fan-battle-arena/mobile` |
| `firebase_auth` | `^5.2.0` | `fan-battle-arena/mobile` |
| `cloud_firestore` | `^5.4.0` | `fan-battle-arena/mobile` |
| `firebase_storage` | `^12.x` | same generation as the above |
| `firebase_messaging` | `^15.x` | same generation |
| `firebase_analytics` | `^11.x` | same generation |
| `firebase_crashlytics` | `^4.x` | same generation |
| `cloud_functions` | `^5.x` | same generation |
| `firebase_app_check` | `^0.3.x` | same generation |

If a later phase genuinely requires a plugin that needs a newer Dart, upgrading
Flutter becomes an explicit decision to raise — not a silent change.

**The default JDK breaks Gradle.** JDK 25 is first on `java_home`, but the Gradle
8.4/8.7 wrappers used by Flutter 3.19-era projects cannot run on it. JDK
**17.0.18** is installed at
`~/Library/Java/JavaVirtualMachines/jdk-17.0.18+8/Contents/Home` and is pinned via
`org.gradle.java.home` in `android/gradle.properties` during Phase 1.

---

## 3. Firebase

**A Firebase project for this app already exists** and is being reused rather
than replaced:

- **Project:** `flameup-78d15` (display name "Flameup", number `997414781684`)
- **Firestore:** `(default)` database exists, `FIRESTORE_NATIVE`, `STANDARD` edition
- **Registered apps:** one **Android** app,
  `1:997414781684:android:1349cbb29ec5e03bf414a1`
- **No iOS app is registered** — `flutterfire configure` adds it in Phase 1
- **Cloud Functions:** `firebase functions:list` fails against the project, which
  means the Cloud Functions API is not enabled. In practice that indicates the
  project is on the **Spark (free)** plan

### 3.1 The Cloud Functions constraint

The brief requires XP awards, level changes, achievement grants and leaderboard
aggregation to be server-authoritative rather than client-trusted. That needs
Cloud Functions, and deploying Cloud Functions needs the **Blaze** plan.

Per the brief's "do not cheat" rule, this is handled as follows and not papered
over:

1. The functions are **written for real** in `functions/`.
2. They are **run and tested against the Firebase Emulator Suite**, which works
   on the Spark plan.
3. Firestore rules make XP, level and achievement fields **unwritable by
   clients**, so the client code path is the real one from day one.
4. `docs/FIREBASE_SETUP.md` states plainly that production deployment requires a
   Blaze upgrade, and nothing in the app claims otherwise.

---

## 4. The design, recovered

The prototype is a self-contained Claude Design bundle: the real sources are
gzip+base64 encoded inside a `<script type="__bundler/manifest">` block, and the
screen markup sits JSON-encoded in `<script type="__bundler/template">`.

`tool/extract_design.py` decodes it and writes `design/extracted/`. **This is the
design specification the project builds against** — the handoff document that was
missing.

| Output | Contents |
|---|---|
| `tokens.json` | 20 dark + 20 light CSS variables, accent `#FF6A2B` (3 alternates), 20 px glass blur, 6 keyframe animations, base font stack |
| `strings.json` | **206** English/Amharic copy pairs |
| `seed.json` | 12 dishes, 8 regions, 9 achievements, 4 quests, 6 mastery tracks, 4 elders, community feed, friends, leaderboard, shopping list, 7-day meal plan, tab bar definition |
| `screens/01-splash.html` … `30-empty.html` | The 30 screen markup blocks, one file each, sc-if balance verified |

Re-run at any time with `python3 tool/extract_design.py`.

### 4.1 Screen inventory

| Group | Screens |
|---|---|
| **Core loop** (10) | splash, welcome, skill, taste, home, search, recipe, cook, done, rate |
| **Progress** (5) | progress, mastery, achv, quests, streak |
| **Culture** (4) | map, region, grandma, upload |
| **Social** (4) | feed, friends, challenges, leader |
| **Utility** (4) | saved, shop, planner, settings |
| **System states** (3) | error, offline, empty |

Bottom tab bar: `home` (Today), `search` (Explore), `recipe` (Cook), `feed`
(Community), `progress` (You). Nine screens hide the tab bar: splash, welcome,
skill, taste, cook, done, rate, error, offline.

### 4.2 Design system as built

- **Two full themes.** Dark (`--bg #0C0908`, `--scr #14100E`) and light
  (`--bg #EDE3D6`, `--scr #FCF7F0`), expressed as matched variable maps — every
  surface, text tier, hairline, shadow and ambient glow has a value in both.
- **Glass surfaces.** Nearly every card is `background: --g1` +
  `backdrop-filter: blur(20px) saturate(1.7)` + a `.5px --gl` border + an inset
  top highlight. This one recipe becomes the `GlassPanel` widget.
- **Gradient tiles stand in for photography.** Each dish carries a two-colour
  gradient (`a`/`b`) plus a radial sheen. There is no recipe photography in the
  design, so these ship as real placeholders while the Storage upload path is
  built for real images.
- **Bilingual by construction.** Every string is an EN/AM pair, and Amharic is
  set in Noto Sans Ethiopic. Amharic is **LTR** — no RTL handling.
- **Radii** cluster at 8/11/16/18/20/22/24/26 px; **corner radius 48** on the
  device frame.

### 4.3 Content already written

The design ships with real, well-written content that seeds the database:
Doro Wat has 8 ingredients and 9 steps in both languages plus a cultural story;
12 dishes carry time, XP, difficulty and subtitles; 8 regions, 4 elders with
place and topic, 9 achievements, 4 quests across daily/weekly/seasonal, and a
6-track mastery model. Phase 5 expands this to the 25+ recipes the brief asks
for.

---

## 5. Gaps and risks entering Phase 1

| Item | Status | Handling |
|---|---|---|
| Cloud Functions deployment | Blocked on Blaze upgrade | Build + emulator-test; document; rules block client XP writes |
| iOS app not registered in Firebase | Missing | `flutterfire configure` in Phase 1 |
| Flutter 3.19.6 / Dart 3.3.4 | ~2 years old | Pin proven versions; raise an upgrade explicitly if ever forced |
| Default JDK 25 vs Gradle | Would break Android builds | Pin `org.gradle.java.home` to JDK 17.0.18 |
| No recipe photography | Absent from the design | Gradient tiles as real placeholders; Storage upload path fully built |
| Google / Apple sign-in credentials | Not configured | SHA-1/SHA-256 and Apple entitlement steps documented in Phase 3 |
| AI provider key | Not present | Never in the binary; Cloud Function proxy reads it from Functions config |

---

## 6. Conventions adopted

Matching the sibling Flutter projects in `~/Documents/Matty`:

- **Riverpod** for state, **go_router** for navigation, feature-first `lib/` layout.
- `publish_to: 'none'`, `flutter_lints`.
- Conventional-commit subjects (`feat:`, `fix:`, `test:`, `docs:`, `chore:`),
  one commit per phase, **no AI co-author trailers**.
