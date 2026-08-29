# What you need to do

Everything in this list is a **console click or an account decision** — none of
it can be done from a terminal, which is why it is not already done. The code
for each is written and waiting.

Ordered by what unblocks the most.

---

## 1. Enable sign-in providers — 5 minutes, free

**Without this, nobody can sign in at all.** Every sign-in attempt fails with
`operation-not-allowed`.

→ [Authentication → Sign-in method](https://console.firebase.google.com/project/flameup-78d15/authentication/providers)

Enable, in this order of importance:

| Provider | Why | Extra steps |
|---|---|---|
| **Anonymous** | Guest mode. The app's whole "try before you sign up" path | none |
| **Email/Password** | The main account type | none |
| **Google** | One-tap sign-in | needs SHA fingerprints, see below |
| **Apple** | **Required by App Store review** if any other social provider is offered | needs a paid Apple Developer account |

### Google also needs the Android fingerprints

```bash
cd /Users/needsreset/Documents/Matty/FlameUp/FlameUp/android
./gradlew signingReport
```

Copy the **SHA-1** and **SHA-256** from the `debug` variant into
→ [Project settings → Your apps → Android](https://console.firebase.google.com/project/flameup-78d15/settings/general)

Then re-download `google-services.json` and replace `android/app/google-services.json`.

> You will need to repeat this with your **release** signing key before
> shipping — Google sign-in will fail on a Play-signed build otherwise.

---

## 2. Turn on Firebase Storage — 1 minute, free

**Without this, no photo can be uploaded** — profile pictures, finished-dish
photos, family recipe media.

→ [Storage](https://console.firebase.google.com/project/flameup-78d15/storage) →
**Get Started** → accept the default rules → pick a location

Then, from the project root:

```bash
firebase deploy --only storage
```

I could not do this step: `firebase deploy --only storage` currently fails with
*"Firebase Storage has not been set up on project 'flameup-78d15'"*.

---

## 3. Upgrade to the Blaze plan — decides whether XP works

**Without this, XP is never awarded.** People can cook, but their progress
never moves.

→ [Usage and billing → Details & settings → Modify plan](https://console.firebase.google.com/project/flameup-78d15/usage/details)

Blaze is pay-as-you-go and includes the Spark free tier. For an app this size,
expect **≈ $0/month** until you have real traffic; set a budget alert at $5 if
you want a hard signal.

Then deploy the functions:

```bash
cd /Users/needsreset/Documents/Matty/FlameUp/FlameUp
firebase deploy --only functions
```

### Why this cannot be worked around

XP, levels, streaks and achievements are written **only** by Cloud Functions.
That is deliberate: `firestore.rules` refuses client-side writes to those
fields, so a modified app cannot award itself anything. Making it work without
Blaze would mean letting the client write its own XP — which is the one thing
the design exists to prevent.

The functions are written, typecheck, and run against the local emulator today.

---

## 4. Deploy the security rules — 1 minute, free

```bash
cd /Users/needsreset/Documents/Matty/FlameUp/FlameUp
firebase deploy --only firestore:rules,firestore:indexes
```

`firestore.rules` already **compiles successfully** against your project
(verified with a dry run). This just pushes it. Do it **before** any real user
touches the app — the default rules are wide open.

---

## 5. Seed the recipe catalogue — optional

The app ships all 25 recipes bundled, so it works fully without this. Do it
when you want the backend to hold them too (needed before user reviews and
cook-counts aggregate properly):

```bash
# against the emulator
firebase emulators:start --only firestore
dart run tool/seed_firestore.dart --emulator

# against the live project (needs an admin credential)
dart run tool/seed_firestore.dart --project flameup-78d15
```

---

## 6. Before shipping to the stores

Not urgent, but nothing below can be skipped at release.

- **Android release signing** — a keystore, and `android/key.properties`
  (git-ignored). Currently release builds are signed with the debug key.
- **iOS** — an Apple Developer account, a bundle id registered for
  `com.flameup.app`, and the Sign in with Apple capability.
- **App Check** — register Play Integrity and App Attest
  → [App Check](https://console.firebase.google.com/project/flameup-78d15/appcheck)
- **APNs key** for iOS push notifications
  → Project settings → Cloud Messaging
- **App icon and splash** — currently the Flutter default.
- **Delete the stale Firebase app.** There is an old Android registration for
  `com.example.flame_up` from before this work. `com.example.*` cannot be
  published to Play. Nothing references it; it is safe to delete
  → [Project settings → Your apps](https://console.firebase.google.com/project/flameup-78d15/settings/general)

---

## Things I decided, that you may want to overrule

I made these calls rather than stopping to ask. Each is reversible.

1. **No invented content.** The design shows a community feed with named users,
   and Grandma's Kitchen with four named elders and their recordings. Those
   people and recordings do not exist. I built those screens with honest empty
   states pointing at the contribution routes, rather than shipping fabricated
   posts and invented elders — inventing sources for cultural knowledge is the
   one thing this app should not do. If you have real contributors, the screens
   are ready for them.

2. **Cultural notes are written as tradition, not history.** No dish is dated,
   no inventor named. "In much of Ethiopia it is the dish that ends a fast"
   describes practice; a date would be a claim I have no source for.

3. **Taste Ethiopia is a grid, not a map.** A real map needs regional boundary
   data I have no authoritative source for, and approximating a country's
   internal borders is not something to guess at.

4. **The 13 recipes I added.** The design supplied 12; the brief asked for
   25–30. I wrote Chechebsa, Genfo, Atakilt Wat, Bozena Shiro, Fosolia, Alicha
   Wat, Ayib, Awaze, Tihlo, Shorba, Kinche, Ful and Ambasha, each with full
   ingredients and steps in both languages. **These should be checked by
   someone who cooks them** — they are written carefully, but I am not an
   Ethiopian cook and the app's credibility rests on them being right.

5. **Amharic throughout.** All 277 strings and all 25 recipes are translated.
   Worth a native speaker's read before launch.

---

## What is done and verified

- `flutter analyze` — **no issues**
- **340 tests passing**
- `flutter build apk --debug` — **succeeds**
- **Every route renders a real screen** — no placeholders remain
- `firestore.rules` — **compiles against your live project**
- `functions/` — **typechecks** under `tsc --noEmit`

Run it yourself:

```bash
cd /Users/needsreset/Documents/Matty/FlameUp/FlameUp
flutter analyze && flutter test && flutter build apk --debug
```
