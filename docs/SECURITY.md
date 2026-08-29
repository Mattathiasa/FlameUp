# FlameUp — security review

Audit performed against the code as it stands. Findings and their resolution
are recorded here rather than only in commit messages.

---

## The central invariant

**Progression is server-authoritative.** `xp`, `level`, `flames`,
`longestStreak`, `lastCookedOn`, `freezeDaysLeft`, `recipesCooked`,
`recipesMastered` and `regionsTasted` are writable only by Cloud Functions,
which run with admin credentials and bypass rules.

The mechanism is `diff().affectedKeys()`, not a whole-document rule — a user
must still be able to edit their display name in the document that holds their
XP, without being able to touch the XP in that same write.

```
allow update: if isOwner(uid) && leavesProgressionAlone();
```

Verified: no client code path writes those fields. `grep` for `'xp'` and
`'level'` against `set(`/`update(` in `lib/` returns nothing.

---

## Findings

### Fixed: family recipe generations were world-readable

A family recipe draft is private to its author until moderation publishes it.
Its `generations` subcollection — **which names the relatives a recipe was
passed down through** — carried `allow read: if true`, so those names were
readable for unpublished drafts.

Now inherits the parent's visibility. This is the finding that mattered most:
the feature exists to hold family history, and leaking it before the author
chose to publish would be a betrayal of the thing the feature is for.

### Fixed: sign-out could leave a user signed in

Clearing the Google session was attempted *before* the Firebase sign-out, so a
failure there — no session, no Play Services, an offline device — meant the
user stayed signed in after asking to leave. Google teardown is now
best-effort; the Firebase sign-out is unconditional.

### Fixed: advertising permissions requested without cause

`firebase_analytics` merges in `com.google.android.gms.permission.AD_ID` plus
the Privacy Sandbox `ACCESS_ADSERVICES_AD_ID` and
`ACCESS_ADSERVICES_ATTRIBUTION` permissions. FlameUp does not advertise. All
three are removed via `tools:node="remove"`, verified absent from the built
APK.

### Fixed: release builds had no network permission

`INTERNET` was declared only in the *debug* manifest, per the Flutter template.
A release build would have had no network at all against Firebase.

---

## Reviewed and accepted

**Public reads.** `recipes`, `regions`, `config`, recipe `reviews`, published
`family_recipes` and profile avatars are readable without authentication. These
are the catalogue and its public commentary; the app is a recipe book and a
signed-out reader is a legitimate case. No private field is exposed by them.

**Reviews are attributable.** A review carries the reviewer's uid and display
name, which is how attribution works, and the user chose to publish it.

**`firebase_options.dart` and `google-services.json` are committed.** These are
client *identifiers*, not credentials. Firebase's model assumes they are public
and enforces access through rules and App Check. Committing them is what lets a
fresh clone build.

**Debug logging.** `CrashReporter` prints only under `kDebugMode` and uploads
otherwise. Breadcrumbs carry route names, never query values or user text.

---

## Enforced in rules, not merely in the UI

Each of these could be bypassed by a modified client if it lived only in Dart:

| Rule | Why it is server-side |
|---|---|
| A review requires a **completed** cooking session owned by the writer | Otherwise anyone can rate anything, and ratings are the app's quality signal |
| A challenge submission is unreadable until both participants submit | Seeing the opponent's entry first lets the second cook simply out-score it |
| `winnerId` is not client-writable | Otherwise both participants declare themselves the winner |
| Like counts are trigger-maintained | Otherwise an author inflates their own post |
| A family recipe author cannot set `status: published` | Otherwise moderation is optional |
| Reports are write-only for clients | A reporter must not be able to read the moderation queue |

---

## Privacy

- **Analytics carries the opaque uid only** — never an email, a display name,
  or free text the user typed. Event names are constants, so the collected set
  stays reviewable.
- **Account deletion** removes the Firestore subcollections via a trigger, so
  it completes even if the app is killed mid-delete.
- **Leaderboard opt-out** is honoured by the aggregation function, not filtered
  on the device.
- **Storage uploads** are scoped to the owner's path and capped by size and
  content type.

---

## Not yet done

- **Behavioural rules tests against the emulator.** The rules compile and are
  reviewed; their behaviour is not asserted in CI. This is the largest
  remaining gap.
- **App Check enforcement** is not switched on in the console, so the backend
  currently answers unattested requests.
- **No penetration testing** of the deployed backend, which cannot happen until
  it is deployed.
