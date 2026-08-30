# Firestore rules tests

Behavioural tests for `firestore.rules`, run against the Firestore emulator.

```bash
cd rules-tests
npm install
npm test          # starts the emulator, runs the suite, shuts it down
```

The rules file is **read from the repository**, not duplicated here, so these
tests cannot drift from what actually ships.

---

## Why these exist

`firebase deploy --dry-run` only proves the rules *compile*. It says nothing
about whether they permit what they should and refuse what they should not —
and a rule can compile, run, and be exactly backwards.

The first run of this suite found a bug that had been sitting in the rules
through several commits:

```
Unsupported operation error. Received: list.hasAny(set). Expected: list.hasAny(list).
```

`keys()` and `affectedKeys()` need a **list**, not a set. Passing a set made
the whole rule error — and **an erroring rule denies**. So the profile-create
rule refused every write, including legitimate ones.

The visible symptom would have been: sign-up appears to work, Firebase Auth
creates the account, and then the user document silently never persists.
Onboarding answers would vanish. No amount of reading the file was going to
surface that; only running it did.

---

## What is covered — 61 tests

**Progression is server-authoritative** (16). A user can rename themselves but
cannot grant themselves XP, a level, a streak, mastery, an achievement or quest
progress — including smuggled in alongside a legitimate edit, which is the
attack the `diff()` rule exists to stop. A reward-claim marker cannot be forged
or deleted, since deleting it would make a completed cook claimable twice. Even
a moderator cannot hand out XP: moderation is about content, not progression.

**Reviews require a cook that happened** (9). A review must reference a
**completed** cooking session **owned by the writer**. In-progress sessions,
invented session ids, and borrowing someone else's cook are all refused.

**Family recipes stay private until published** (11). An author reads their own
draft; a stranger cannot. An author cannot set their own status to `published`,
or moderation would be optional.

Included here is the leak found in the security audit: `generations` — which
names the relatives a recipe was passed down through — was world-readable even
under an unpublished draft. Two tests pin the fix.

**Challenges cannot be gamed** (10). An opponent cannot read the first
submission until they have made their own, because seeing it would let them
simply out-score it. Submissions are immutable once made, and neither
participant can write `winnerId`.

**Posts, likes and personal lists** (15). An author can edit their own text but
not their own like count. A like is keyed by the liker's uid. Shopping lists,
saved recipes and meal plans are readable only by their owner.

---

## Notes

- Fixtures are seeded with `withSecurityRulesDisabled`. Setting them up
  *through* the rules would mean a rule change could break the setup and mask
  the thing under test.
- `fileParallelism` is off: the emulator is shared state, and parallel suites
  race on the same documents, producing failures that have nothing to do with
  rules.
- These run against a throwaway project id (`flameup-rules-test`), never
  against `flameup-78d15`.
