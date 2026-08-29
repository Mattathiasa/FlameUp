# FlameUp — Firebase setup

## The project

FlameUp uses an existing Firebase project. It was **not** created by this build.

| | |
|---|---|
| Project id | `flameup-78d15` |
| Project number | `997414781684` |
| Firestore | `(default)`, Native mode, Standard edition — provisioned |
| Storage bucket | `flameup-78d15.firebasestorage.app` — **not yet set up**, see below |
| Console | https://console.firebase.google.com/project/flameup-78d15 |

### Registered apps

| Platform | App id | Identifier |
|---|---|---|
| Android | `1:997414781684:android:9c3f42d99657cb12f414a1` | `com.flameup.app` |
| iOS | `1:997414781684:ios:bfd19a540321f963f414a1` | `com.flameup.app` |
| Android *(stale)* | `1:997414781684:android:1349cbb29ec5e03bf414a1` | `com.example.flame_up` |

The third entry predates this work. `com.example.*` cannot be published to
Google Play, so it was left in place rather than used. **It can be deleted from
the console** — nothing in this repository references it.

---

## ⚠ Cloud Functions require a Blaze upgrade

**This is the one thing the app cannot do on the current plan.**

`firebase functions:list --project flameup-78d15` fails, because the Cloud
Functions API is not enabled — the project is on the **Spark (free)** plan.
Cloud Functions deployment requires **Blaze** (pay-as-you-go).

FlameUp needs functions for work that must not be client-trusted:

- awarding XP, levels, mastery, streaks, quest progress and achievements when a
  cooking session completes
- recomputing `averageRating` / `ratingCount` on a recipe
- aggregating leaderboards on a schedule
- proxying the AI cooking assistant so no provider key ships in the app
- push notification triggers

### How this is handled, and what is genuinely not done

1. The functions are **written for real** in `functions/`.
2. They **run and are tested against the Firebase Emulator Suite**, which works
   on Spark. Development uses this.
3. `firestore.rules` already makes `xp`, `level`, `flames`, mastery and
   achievement documents **unwritable by clients**, so the app's code path is
   the production one today — it calls the callable function and reads the
   result back.
4. **Until the project is upgraded, those functions are not deployed**, so a
   release build talking to the live project cannot award XP. That is a real
   gap, stated here rather than papered over.

To upgrade: Firebase console → ⚙ → Usage and billing → Details & settings →
Modify plan → Blaze. Then:

```bash
firebase deploy --only functions --project flameup-78d15
```

---

## Local development

### 1. Install tooling

```bash
npm install -g firebase-tools     # already present: 15.17.0
dart pub global activate flutterfire_cli
```

Authenticated as `mattathiasabraham@gmail.com`. Check with `firebase login:list`.

### 2. Run the emulator suite

```bash
firebase emulators:start --only auth,firestore,functions,storage
```

The emulator UI is at http://localhost:4000.

### 3. Point the app at it

```bash
flutter run --dart-define=USE_FIREBASE_EMULATOR=true
```

From an **Android emulator** the host machine is `10.0.2.2`, not localhost:

```bash
flutter run \
  --dart-define=USE_FIREBASE_EMULATOR=true \
  --dart-define=FIREBASE_EMULATOR_HOST=10.0.2.2
```

Without the flag the app talks to the live `flameup-78d15` project.

### 4. Seed data

```bash
dart run tool/seed_firestore.dart --emulator      # local
dart run tool/seed_firestore.dart --project flameup-78d15
```

*(Added in Phase 5.)*

---

## Regenerating the Firebase config

`lib/firebase_options.dart`, `android/app/google-services.json` and
`ios/Runner/GoogleService-Info.plist` are generated. To refresh:

```bash
flutterfire configure \
  --project=flameup-78d15 \
  --platforms=android,ios \
  --android-package-name=com.flameup.app \
  --ios-bundle-id=com.flameup.app
```

These files hold client identifiers, not secrets, and are committed on purpose
so a fresh clone builds. Real secrets live in Functions config and `.env`,
both git-ignored.

---

## Still to configure

These are console-side steps that code cannot perform. Each is done in the
phase noted.

### ⚠ Authentication providers — required before sign-in works

**The code is complete; these console steps are not, and cannot be done from a
terminal.** Until they are, sign-in will fail against the live project with
`operation-not-allowed`.

Console → Authentication → Sign-in method. Enable:

- **Email/Password**
- **Anonymous** — this is what guest mode uses
- **Google** — needs the Android SHA-1 and SHA-256 fingerprints:
  ```bash
  cd android && ./gradlew signingReport
  ```
  Add both to the Android app, then re-download `google-services.json`.
  Add the reversed iOS client id to `ios/Runner/Info.plist` URL schemes.
- **Apple** — needs an Apple Developer account: a Services ID, a Sign in with
  Apple key, and the `com.apple.developer.applesignin` entitlement on the
  Runner target. Required by App Store review whenever another social provider
  is offered. The app hides the Apple button where the platform does not
  support it, so an un-configured Apple provider is not a crash — but it is a
  store rejection on iOS.

#### What the app already does correctly

- **Guest mode is anonymous auth**, and upgrading calls `linkWithCredential` on
  the existing user, so the uid never changes and no progress is orphaned.
  `test/features/auth/auth_repository_test.dart` asserts the repository links
  rather than creating a second account.
- **Sign-out is unconditional.** Clearing the Google session is attempted first
  so the account chooser appears next time, but a failure there cannot prevent
  the Firebase sign-out — being left signed in after asking to leave is the
  worse outcome.
- **Errors never leak.** `wrong-password` and `user-not-found` deliberately
  resolve to the same message so the app does not disclose which half was
  wrong.

### App Check — Phase 15

Console → App Check. Register Play Integrity (Android) and App Attest (iOS).
Debug builds use the debug provider; each developer machine's debug token must
be registered once.

### ⚠ Firebase Storage — not set up

`firebase deploy --only storage` fails with:

> Firebase Storage has not been set up on project 'flameup-78d15'.

Console → Storage → **Get Started**. Until then `storage.rules` cannot be
deployed, and photo upload (profile pictures, finished-dish photos, family
recipe media) will fail against the live project. The rules file is written and
the upload paths are built; this is a one-click console step, not code.

### Cloud Messaging — Phase 10

Upload an APNs auth key for iOS. Android needs no extra step.

### Crashlytics — Phase 15

Enabled by the Gradle plugin already wired in. Upload dSYMs for iOS release
builds.

---

## Security rules

`firestore.rules` and `storage.rules` are written and
**`firestore.rules` compiles against the live project** (verified with
`firebase deploy --only firestore:rules --dry-run`). Phase 13 adds emulator
rules tests. The invariants they enforce:

- a user may write only their own documents
- `xp`, `level`, `flames`, mastery and achievements are **server-only**
- a review requires a completed cooking session owned by the writer
- family recipes are author-private until moderation publishes them
- challenge submissions stay hidden until both participants have submitted
- reports are write-only for clients

`allow read, write: if true;` appears nowhere.
