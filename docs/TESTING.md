# FlameUp — testing

```bash
flutter analyze          # must report no issues
flutter test             # unit + widget
flutter test integration_test/   # needs a connected device or emulator
cd functions && npx tsc --noEmit # Cloud Functions typecheck
```

---

## What is covered, and why that

Tests here are written where a bug costs the user something real. The
progression maths, the offline queue and the cooking timers get the most,
because those are the places where a defect quietly destroys work rather than
producing a visible error.

| Area | Tests | The property being protected |
|---|---:|---|
| Gamification | 113 | XP, levels, streaks, mastery, quests, achievements |
| Recipes | 59 | serving-size scaling, filtering, search, the catalogue itself |
| Offline cache | 40 | cached data is served, a failed refresh does not blank it |
| Components | 22 | both themes, Amharic overflow, semantics, touch targets |
| Router | 22 | the redirect truth table, including guest access |
| Cooking | 19 | wall-clock timers, kill-and-resume, idempotency |
| Shopping + planner | 19 | ingredient merging, ISO-week identity |
| Core | 53 | `Result`, `ErrorMapper`, localisation completeness |
| Auth | 14 | guest upgrade links in place, errors never leak |
| AI assistant | 9 | claims are never promoted to a higher authority |

---

## Tests that exist because a bug was found

Each of these was written after the defect, and each would catch it again.

**A timer that lies.** A session killed at 18:00 with fifteen minutes left and
reopened at 18:10 must report **five** minutes. A `Timer` counting ticks would
say fifteen. This is why deadlines are stored, not remaining seconds.

**Sign-out that does not sign out.** Clearing the Google session was attempted
before the Firebase sign-out, so a failure there left the user signed in. The
test asserts sign-out completes even when the Google teardown throws — and it
does throw, in the mock, which is how the fix is proven.

**An unsatisfiable achievement.** `AchievementRule.threshold` did double duty as
both the mastery *level* and the *count* of dishes required, so "one dish at
Skilled" was read as "four dishes" and could never be earned.

**A meal plan that crashes on bad data.** A malformed `slots` field threw a cast
error. A corrupt plan should cost the user their plan, not the screen.

**A feed that never pages.** The pagination cursor was stored but never passed
back, so "load more" would have re-fetched page one forever.

---

## Data invariants

`test/features/recipes/recipe_query_test.dart` runs against
`assets/seed/recipes.json` — the catalogue the app actually ships — rather than
fixtures that could drift from it. It asserts:

- every recipe has steps and ingredients **in both languages**
- every recipe has a cultural note in both languages
- **every fasting dish is also vegan and dairy-free**, which is what fasting
  means, and is the kind of data error that would otherwise reach a user
  mid-fast
- most steps carry a duration, so cook mode can time them

`test/core/theme/app_theme_test.dart` asserts the Dart colour constants against
`design/extracted/tokens.json`, so the implementation cannot drift from the
design without a test failing.

`test/core/localization_test.dart` asserts every `Failure.messageKey` resolves
in both languages — a missing translation fails the suite rather than rendering
a blank error to a user.

---

## Integration tests

`integration_test/cooking_journey_test.dart` covers the journeys where state
has to survive process death: a session serialised and restored mid-cook with
its timer intact, a timer that expired while the app was closed, one reward key
across every attempt, and a week of daily cooking reaching the streak
milestone.

It also asserts that **cooking twelve different dishes pays more than cooking
one dish twelve times** — the XP decay exists so the optimal strategy is
discovery rather than repetition, and that is a product property worth pinning.

These need a connected device:

```bash
flutter emulators --launch Pixel_7a
flutter test integration_test/
```

---

## Rules tests

`firestore.rules` compiles against the live project (verified by
`firebase deploy --only firestore:rules --dry-run`). Behavioural rules tests
against the emulator are the remaining gap — the invariants they should pin
are listed in `docs/GAMIFICATION.md`:

- `xp`, `level`, `flames`, mastery and achievements reject client writes
- a review requires a completed session owned by the writer
- a challenge submission is unreadable until both participants have submitted
- a family recipe author cannot set their own status to `published`

---

## What is not covered

Stated plainly rather than left to be discovered:

- **No rules tests against the emulator yet** — the rules compile and are
  reviewed, but their behaviour is not asserted in CI.
- **No end-to-end auth test against the live project** — the providers are not
  enabled yet (see `ACTION_REQUIRED.md`), so there is nothing to test against.
- **No Cloud Functions tests** — they typecheck and can be run in the emulator,
  but their behaviour is not asserted.
- **No golden/screenshot tests** — component tests assert structure and
  semantics, not pixels.
