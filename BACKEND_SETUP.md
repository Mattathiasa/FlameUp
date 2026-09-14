# FlameUp — backend setup & runbook

Everything needed to run FlameUp's backend locally and in production.
Written after a verified end-to-end run (app ↔ emulators) on 2026-09-14.

---

## What this project's backend is

| Piece | Where | Status |
|---|---|---|
| Firebase project | `flameup-78d15` (`.firebaserc`) | baked into `lib/firebase_options.dart` |
| Cloud Functions (TS) | `functions/src/` — `askAssistant`, `claimCookingReward`, `onReviewWritten`, `rebuildLeaderboards`, `onUserDeleted` | build ✓ (`npm run build`) |
| Emulator suite | `firebase.json` — Auth :9099, Firestore :8080, Functions :5001, Storage :9199, UI :4000 | **working locally now** |
| AI assistant secret | `ANTHROPIC_API_KEY` as a Functions **secret** (`functions/src/assistant.ts` declares it) | needs `firebase login` + Blaze for deploy |
| Client profiles | `config/emulator.env`, `config/emulator.android.env` | ✓ committed |

## Running the backend locally (works right now)

```bash
export JAVA_HOME=/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home
cd /Users/mattathiasa/Projects/FlameUp
firebase emulators:start --only auth,firestore,functions,storage
```

All five services come up (`All emulators ready!`), functions load from source,
and the Emulator UI is at http://127.0.0.1:4000.

Then run the app against it:

```bash
../run_flutter_app.sh flameup:emulator run -d <simulator-id>   # iOS sim/desktop
../run_flutter_app.sh flameup:emulator.android run              # Android emulator
```

Verified: the app logs `[firebase] using emulator suite at localhost` and stays
connected; functions initialize (`askAssistant` at
`http://127.0.0.1:5001/flameup-78d15/us-central1/askAssistant`).

### ⚠️ Two machine-specific fixes that made this work (already applied)

1. **`fsevents.node` had an invalid code signature** inside firebase-tools.
   Every `emulators:start/exec` crashed instantly with
   `SIGKILL (Code Signature Invalid)` in dyld (no log output at all).
   Fixed by re-signing:
   ```bash
   codesign -s - -f /opt/homebrew/Cellar/firebase-cli/15.29.0/libexec/lib/node_modules/firebase-tools/node_modules/fsevents/fsevents.node
   ```
   If a `brew upgrade firebase-cli` reintroduces the crash, re-run that line
   (or a `brew reinstall firebase-cli`).

2. **No Java on PATH** — the Firestore/Storage emulators are Java processes.
   A JDK already exists via Homebrew; export `JAVA_HOME` as above (or
   `brew install openjdk@21` and symlink it into
   `/Library/Java/JavaVirtualMachines/` for a system-wide fix).

   Symptom if missing: `firebase emulators:start` dies instantly (empty log)
   once it tries to spawn the Firestore jar, even though `--only auth` works.

## Production setup (needs you at the console/CLI)

Ordered, from the repo's own `docs/DEPLOYMENT.md` + `ACTION_REQUIRED.md`:

```bash
# 1. Authenticate the CLI (one time)
firebase login

# 2. Console steps (free): enable Auth providers (Anonymous, Email/Password,
#    Google), and create the Storage bucket. Nothing in the terminal does this.

# 3. Deploy rules + indexes BEFORE any real user signs up
firebase deploy --only firestore:rules,firestore:indexes,storage

# 4. Blaze plan is required for Cloud Functions — then deploy them
firebase deploy --only functions

# 5. The AI assistant's key — server-side only, NEVER in the app binary
firebase functions:secrets:set ANTHROPIC_API_KEY

# 6. Optional: seed the recipe catalogue (see docs/ in repo)
```

> The emulator warning "You are not currently authenticated" is exactly what
> step 1 fixes; it doesn't block local emulator use.

## App-side env/config summary

- **Production**: no flags needed — `lib/firebase_options.dart` carries the
  project config; a bare `flutter run` targets production.
- **Emulators**: `--dart-define-from-file=config/emulator.env` (or the
  launcher profiles) sets `USE_FIREBASE_EMULATOR=true` and the host.
- **Secrets**: none belong client-side. `ANTHROPIC_API_KEY` is a Functions
  secret (step 5). `.env.example` at the repo root documents this.
