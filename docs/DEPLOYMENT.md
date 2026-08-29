# FlameUp — deployment

> Everything that must happen before real users touch this. Start with
> [`../ACTION_REQUIRED.md`](../ACTION_REQUIRED.md) — the console steps come
> first, because nothing below works without them.

---

## Order of operations

```
1. Enable auth providers          console, free    -- or nobody can sign in
2. Turn on Firebase Storage       console, free    -- or no photo uploads
3. Deploy security rules          CLI, free        -- BEFORE any real user
4. Upgrade to Blaze               billing decision -- or XP is never awarded
5. Deploy Cloud Functions         CLI
6. Seed the catalogue             CLI, optional
7. Android + iOS release config   below
```

---

## Backend

```bash
# Rules and indexes -- do this before anyone signs up. The default rules
# are wide open.
firebase deploy --only firestore:rules,firestore:indexes
firebase deploy --only storage

# Functions -- needs Blaze
cd functions && npm install && npm run build && cd ..
firebase deploy --only functions
```

### The AI assistant key

Never in the app binary. Set it as a Functions secret:

```bash
firebase functions:secrets:set ANTHROPIC_API_KEY
```

Without it, `askAssistant` returns `failed-precondition` and the UI says the
assistant is not configured. That is deliberate: a stubbed answer would be
indistinguishable from a real one to the user, which is the worst possible
failure for a feature whose entire job is being trustworthy.

---

## Android

### Signing

Release builds currently use the **debug key**. Before shipping:

```bash
keytool -genkey -v -keystore ~/flameup-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias flameup
```

Create `android/key.properties` (git-ignored):

```properties
storePassword=...
keyPassword=...
keyAlias=flameup
storeFile=/Users/you/flameup-release.jks
```

Then wire it into `android/app/build.gradle` — replace
`signingConfig signingConfigs.debug` in the release block.

> **Losing this keystore means you can never update the app on Play.** Back it
> up somewhere that is not this machine.

### Re-register the SHA fingerprints

Google sign-in will fail on a Play-signed build unless the **release** SHA-1
and SHA-256 are registered in Firebase. If you use Play App Signing, take the
fingerprints from the Play Console, not from your local keystore — Play re-signs
the upload.

### Build

```bash
flutter build appbundle --release
```

Already configured: `minSdk 23`, `targetSdk 34` (Play's floor), multidex,
core-library desugaring for the timer alarms, NDK pinned to 25.1.8937393.

Advertising permissions that `firebase_analytics` merges in by default are
**removed** — FlameUp does not advertise and should not request them. Verify
after any dependency bump:

```bash
aapt2 dump permissions build/app/outputs/.../app-release.apk | grep -i ad_id
```

---

## iOS

- Bundle id `com.flameup.app`, registered in the Apple Developer portal
- **Sign in with Apple** capability — App Store review requires it whenever
  another social provider is offered
- APNs auth key uploaded to Firebase → Project settings → Cloud Messaging
- Deployment target 13.0 (already set; the Firebase pods need it)

```bash
cd ios && pod install && cd ..
flutter build ipa --release
```

Upload the dSYMs to Crashlytics, or release crashes arrive unsymbolicated and
are close to useless.

---

## App Check

Register **Play Integrity** (Android) and **App Attest** (iOS) at
Firebase → App Check. Debug builds use the debug provider, and each developer
machine's debug token has to be registered once.

App Check activation is deliberately **non-fatal** at startup: attestation
needs the network and a registered device, and a failure there must not stop
the app launching. The backend still enforces its own rules.

---

## Before the first release

- [ ] Auth providers enabled, release SHA fingerprints registered
- [ ] Firebase Storage set up, `storage.rules` deployed
- [ ] `firestore.rules` deployed — **before** any real user
- [ ] Blaze upgrade and functions deployed, or XP silently never moves
- [ ] `ANTHROPIC_API_KEY` set as a Functions secret
- [ ] Release keystore created and **backed up off this machine**
- [ ] App icon and splash replaced (currently the Flutter default)
- [ ] Privacy policy — the app collects cooking history, photos and an optional
      display name; account deletion is implemented and removes Firestore data
      via a trigger
- [ ] The 13 recipes written for this project reviewed by someone who cooks
      them, and the Amharic read by a native speaker

---

## Monitoring

- **Crashlytics** — enabled; upload iOS dSYMs per release
- **Analytics** — event names are constants on `AnalyticsService`, so the set
  stays reviewable. Only the opaque uid is attached: never an email, a display
  name, or free text the user typed
- **Functions logs** — `firebase functions:log`

The reward function logs every grant with the session and the amount, so a
disputed XP total can be traced rather than guessed at.
