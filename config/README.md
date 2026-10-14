# FlameUp — persisted client config profiles

These files are **`--dart-define-from-file`** profiles: pass one to any flutter
command and every key in it becomes a compile-time `String.fromEnvironment`
value. No retyping, no third-party package (native since Flutter 3.7).

## Profiles

| File | Use |
|---|---|
| `emulator.env` | iOS simulator / desktop against the local Firebase emulator suite |
| `emulator.android.env` | same, but `FIREBASE_EMULATOR_HOST=10.0.2.2` (Android emulator can't see 127.0.0.1) |
| `production.env.example` | copy to `production.env` and fill in — do not commit |

## Usage

```bash
# via the workspace launcher (recommended):
../run_flutter_app.sh flameup:emulator run -d <simulator-id>
../run_flutter_app.sh flameup:emulator-android run   # android device/emulator

# or directly:
flutter run --dart-define-from-file=config/emulator.env
flutter build ios --simulator --dart-define-from-file=config/emulator.env
```

## Live project (no profile needed)

The live Firebase project (`flameup-78d15`) identifiers are compiled into
`lib/firebase_options.dart`, so a bare `flutter run` targets production.

## Secrets

No secret belongs in these files. Functions secrets are set server-side with
`firebase functions:secrets:set`; the AI assistant needs none — it answers
on-device from the bundled catalogue. See `docs/DEPLOYMENT.md` and
`../ENVIRONMENT_VARIABLES.md`.
