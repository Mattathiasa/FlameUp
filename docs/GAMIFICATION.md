# FlameUp — gamification

> **The client never awards itself anything.** XP, levels, streaks, mastery,
> quest and achievement grants are written only by Cloud Functions. Firestore
> rules make those fields unwritable by clients, so the reward function is the
> *only* path to progression, not merely the intended one.

---

## Why the rules exist twice

The progression rules are implemented in Dart
(`lib/features/gamification/domain/`) **and** in TypeScript
(`functions/src/progression.ts`). That duplication is deliberate.

The client computes an *expected* award so the UI can show a plausible figure
immediately. The server computes the *real* one, and its answer is what gets
written. Sharing the code would mean shipping the server's rules to the client,
where they can be read and gamed.

`test/features/gamification/` is the specification for both. If the two
implementations disagree, the tests are what say which is wrong.

---

## XP

Every grant names its reason, so a total can always be explained rather than
merely displayed:

| Reason | Amount |
|---|---|
| `recipeCompleted` | the recipe's XP, decayed by repetition |
| `firstTimeCooking` | +50, once per recipe |
| `streakMilestone` | +100 at 7, 14, 30, 60, 100 days |
| `questCompleted` | the quest's own reward |
| `achievementUnlocked` | the badge's own reward |

### Repeat decay

The first three cooks of a dish pay full value. After that the award declines
by 10% per cook, to a floor of 25%.

Without decay, the optimal strategy is to cook the single highest-XP dish
forever — the opposite of a discovery app. It never reaches zero, because
repetition is how mastery is earned and should still count for something.

---

## Levels

`LevelCurve` maps cumulative XP to a level. Quadratic-ish: `120n + 15n²`, which
puts level 12 at roughly 3,000 XP, matching the design's progress screen.

The curve is **config-driven** — read from `config/level_curve` when present —
so progression can be retuned without shipping a build. A malformed curve falls
back to the standard one rather than being accepted, because a bad curve would
silently change everyone's level.

Level *titles* are separate from the curve, so retuning XP does not rename
anyone's rank.

---

## Flames — the streak

A streak is a question about **calendar days where the user is**, so
`lastCookedOn` stores a local date string (`YYYY-MM-DD`), never a timestamp.
Storing an instant and converting later gets it wrong for anyone who cooks near
midnight or crosses a timezone.

| Gap since last cook | Result |
|---|---|
| Same day | unchanged — cooking twice in a day is not two days |
| 1 day | extended |
| 2 days, freeze available | extended, one freeze spent |
| Otherwise | reset to 1 |

The **displayed** streak is computed as of now, not read from the stored
number: showing 12 when the user last cooked a week ago is a lie the app tells
itself.

Bad data is handled explicitly. An unreadable stored date or a clock that went
backwards starts fresh rather than trusting arithmetic on nonsense.

---

## Mastery

Mastery climbs by **repeating** a dish, not by finishing a recipe once — the
design's own framing.

| Level | Completed cooks |
|---|---|
| Tried it | 1 |
| Learning | 2 |
| Cook | 3 |
| Skilled | 5 |
| Expert | 8 |
| Master | 12 |

---

## Achievements

Data, not branches. A rule names a metric, a threshold and (where relevant) a
recipe or mastery level; adding a badge is a row in a table, not a new code
path.

`AchievementEvaluator.newlyEarned` returns only badges *not* already unlocked,
which is what stops one being announced — and rewarded — twice.

> A bug worth recording: `threshold` originally did double duty as both the
> mastery *level* and the *count* of dishes required, making
> "one dish at Skilled" unsatisfiable because it was read as "four dishes".
> `masteryLevel` is now a separate field. A test caught it.

---

## Quests

Daily, weekly and seasonal, with local-date expiry boundaries for the same
reason streaks have them.

An expired quest is **left untouched** rather than advanced: one that ran out
yesterday should not quietly accept today's cook. A completed quest stops
counting.

`rewardedAt` is tracked separately from `completedAt`. A completion whose
reward has not yet reached the server is not mistaken for one that has, which
is what prevents paying twice.

---

## How a reward is actually granted

```
cook finishes
  -> session marked completed locally, queued to Firestore
  -> client calls claimCookingReward(sessionId)
  -> function opens a transaction:
       reads the session, checks status == completed
       looks for users/{uid}/reward_claims/{idempotencyKey}
         found    -> grants nothing, returns alreadyGranted
         not found -> writes the marker AND applies XP, level, streak,
                      mastery and cook count in the same transaction
```

The marker is written **inside** the transaction that applies the XP. A
replay — a retry after a crash, an outbox drain that ran twice, a user tapping
finish on two devices — finds the marker and grants nothing.

The idempotency key is minted when the **session starts**, not when it
completes, so a crash between finishing and claiming does not produce a second
key and a second payout.

---

## ⚠ Not yet deployed

Cloud Functions require the **Blaze** plan; `flameup-78d15` is on Spark. The
functions are written and typecheck, and run against the emulator suite, but
they are **not deployed**, so a release build against the live project cannot
award XP.

This is a real gap, stated rather than worked around. The client code path is
already the production one — it calls the function and reads the result — and
the rules already refuse client-side XP writes, so nothing needs to change when
the upgrade happens.

See [`FIREBASE_SETUP.md`](FIREBASE_SETUP.md).
