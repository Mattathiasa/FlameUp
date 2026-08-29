# FlameUp — Firestore schema

Paths are implemented once, in `lib/core/constants/firestore_paths.dart`.
Repositories build from that registry rather than writing string literals.

Conventions used throughout:

- Document ids are opaque; the `uid` from Firebase Auth is the user document id.
- `createdAt` / `updatedAt` are **server** timestamps (`FieldValue.serverTimestamp()`).
- Bilingual content stores both languages on the document (`title` / `titleAm`)
  rather than in a subcollection — the app always needs whichever the reader
  has selected, and a second fetch to render a card is not worth it.
- Counters that many clients increment use `FieldValue.increment`, and the
  server-authoritative ones are written only by Cloud Functions.

Fields marked **server-only** are rejected for client writes by
`firestore.rules`. That is the mechanism that keeps XP honest.

---

## users/{uid}

```
displayName        string
email              string|null       null for guests
photoUrl           string|null
isGuest            bool
preferredLanguage  'en' | 'am'
skillLevel         0 | 1 | 2         onboarding: beginner / getting there / grew up on this
heatTolerance      0..4              onboarding: mild -> mitmita
dietary            string[]          dFast, dGluten, dDairy, dMeat, dRaw, dQuick
timezone           string            IANA name, e.g. 'Africa/Addis_Ababa'
onboardingComplete bool

xp                 int    **server-only**
level              int    **server-only**
flames             int    **server-only**   current streak
longestStreak      int    **server-only**
lastCookedOn       string **server-only**   'YYYY-MM-DD' in the user's timezone
freezeDaysLeft     int    **server-only**
recipesCooked      int    **server-only**
recipesMastered    int    **server-only**
regionsTasted      int    **server-only**

leaderboardOptOut  bool
profileVisibility  'public' | 'friends' | 'private'
notificationPrefs  map<string,bool>
fcmTokens          string[]

createdAt, updatedAt  timestamp
```

`lastCookedOn` is a **date string in the user's own timezone**, not a
timestamp. Streaks are a question about calendar days where the user is, so
storing the resolved local date is what makes a flight across timezones behave
sanely.

### Subcollections of a user

| Path | Document | Notes |
|---|---|---|
| `cooking_sessions/{sessionId}` | see below | also mirrored into Hive |
| `mastery/{recipeId}` | `cookCount`, `level` 0..5, `bestRating`, `lastCookedAt`, `avgRating` | **server-only** |
| `user_quests/{questId}` | `progress`, `goal`, `completedAt`, `rewardedAt`, `expiresAt` | **server-only** progress |
| `user_achievements/{achievementId}` | `unlockedAt`, `context` | **server-only** |
| `saved_recipes/{recipeId}` | `savedAt`, `collection` | client-writable |
| `shopping_items/{itemId}` | `name`, `nameAm`, `qty`, `unit`, `aisle`, `checked`, `recipeId?`, `manual` | client-writable |
| `meal_plans/{yyyy-Www}` | `days: { mon: { breakfast, lunch, dinner }, ... }` | one doc per ISO week |
| `friends/{otherUid}` | `since`, `displayName`, `photoUrl` | denormalised for list rendering |
| `friend_requests/{otherUid}` | `direction` in/out, `status`, `createdAt` | |
| `notifications/{id}` | `type`, `body`, `readAt`, `deepLink` | |
| `outbox/{idempotencyKey}` | queued offline mutation | drained on reconnect |

---

## cooking_sessions/{sessionId}

Under the user, because it is private and always queried by owner.

```
recipeId        string
status          'in_progress' | 'completed' | 'abandoned'
currentStep     int
totalSteps      int
stepDeadlines   map<int, timestamp>   wall-clock, so timers survive backgrounding
startedAt       timestamp
completedAt     timestamp|null
lastActiveAt    timestamp
idempotencyKey  string                one reward grant per session, ever
servings        int                   scaled from the recipe default
offlineCreated  bool
```

`stepDeadlines` holds absolute times rather than remaining seconds. A timer is
then a subtraction against the clock, correct whether the app was suspended,
killed, or the phone was asleep (brief §21).

`idempotencyKey` is what makes completion safe to retry: the reward function
writes a marker keyed by it and refuses a second grant.

---

## recipes/{recipeId}

```
title, titleAm            string
slug                      string        stable, human-readable
description, descriptionAm string
story, storyAm            string        the cultural note
regionId                  string        -> regions/{id}
category                  string        wat | tibs | fasting | bread | ceremony | ...
tags                      string[]      lowercased; supports array-contains-any
difficulty                0 | 1 | 2     beginner / medium / advanced
prepMinutes, cookMinutes  int
totalMinutes              int           denormalised for range queries + sorting
servings                  int
heatLevel                 0..4
isFasting, isVegan, isGlutenFree, isDairyFree  bool
ingredients               array<Ingredient>
equipment                 array<string>
steps                     array<RecipeStep>
imageUrl, videoUrl        string|null
gradientA, gradientB      string        the design's tile colours -- used until
                                        photography exists, never removed
xpReward                  int
isTraditional             bool
isFamilyRecipe            bool
authorId                  string|null   null for curated recipes
status                    'published' | 'pending' | 'rejected' | 'removed'
searchTokens              string[]      **see the search note below**
averageRating             number  **server-only**
ratingCount               int     **server-only**
numberOfCooks             int     **server-only**
createdAt, updatedAt      timestamp
```

**Ingredient**: `{ name, nameAm, quantity: number, unit, unitAm, aisle, optional: bool }`.
Quantity is **numeric**, not `"4 large"`, because serving-size scaling has to
multiply it (brief §19). The display string is composed at render time.

**RecipeStep**: `{ index, text, textAm, durationSeconds?, hasTimer, imageUrl?, videoUrl?, tip?, tipAm?, optional }`.

### Search

Firestore has no full-text search. Two mechanisms, neither of which downloads
the collection:

1. `searchTokens` — a normalised token array written on save, queried with
   `array-contains-any`. Handles prefix-free single-word lookups.
2. `SearchService` is an interface. The Firestore implementation backs it now;
   a dedicated search backend (Algolia/Typesense, fed by a Firestore trigger)
   can replace it without any screen changing.

Filtering by region, category, tags, difficulty and time range is done with
real indexed queries declared in `firestore.indexes.json`, paginated with
`startAfterDocument` at `AppConstants.pageSize`.

---

## recipes/{recipeId}/reviews/{uid}

Document id is the reviewer's uid, so one review per person per recipe is
structural rather than enforced by a query.

```
uid, displayName, photoUrl   denormalised for rendering
taste, difficulty, instructions, authenticity   1..5
wouldCookAgain               bool
body, photoUrl               string|null
sessionId                    string    **must reference a completed session**
createdAt, updatedAt         timestamp
```

Rules require a completed `cooking_sessions/{sessionId}` owned by the writer.
That is how "you can only rate what you actually cooked" (brief §26) is
enforced where it matters.

`averageRating` and `ratingCount` on the parent recipe are recomputed by a
Cloud Function trigger, never by the client.

---

## regions/{regionId}

```
name, nameAm         string
description, descriptionAm  string
imageUrl             string|null
gradientA, gradientB string
recipeCount          int  **server-only**
order                int
```

Per-user exploration is derived from distinct regions in the user's mastery
subcollection — not stored on the region, which is shared.

---

## family_recipes/{id}

A recipe plus its provenance. Publishing writes a companion `recipes/{id}`
document with `isFamilyRecipe: true` once moderation passes.

```
recipeId          string|null    set when published
title, titleAm    string
teacherName       string         "who taught you"
relationship      string         grandmother | mother | aunt | neighbour | ...
regionId          string
story, storyAm    string
culturalNotes     string
ingredients, steps  as recipes
photoUrls         string[]
videoUrl          string|null
authorId          string
status            'draft' | 'pending' | 'published' | 'rejected' | 'removed'
moderation        { reviewedBy[], reviewedAt, note }
createdAt, updatedAt
```

`generations/{id}` subcollection records who passed the recipe down, so the
lineage the feature is about is real data rather than prose.

Drafts are visible only to their author. Nothing reaches `published` without
passing moderation (brief §32).

---

## posts/{id} — community feed

```
authorId, authorName, authorPhotoUrl   denormalised
recipeId, recipeTitle, recipeTitleAm
sessionId
body, bodyAm
photoUrl
likeCount, commentCount   **server-only**
createdAt
visibility  'public' | 'friends'
```

Subcollections `comments/{id}` and `likes/{uid}` — likes keyed by uid so a
double-tap cannot double-count, and the counter is maintained by a trigger.

The feed is a paginated `createdAt desc` query. Friends-only visibility is
resolved server-side into per-user feed fan-out if the follower counts ever
justify it; until then the query filters on `visibility`.

---

## challenges/{id} — "Who Cooks Better?"

```
createdBy, opponentId
recipeId
status  'invited' | 'accepted' | 'cooking' | 'judging' | 'complete' | 'declined'
deadline
winnerId    **server-only**
createdAt
```

`submissions/{uid}`: `sessionId`, `photoUrl`, `scores { taste, presentation, difficulty, authenticity }`, `submittedAt`.

A participant cannot read the other's submission until both exist — enforced in
rules, which is what keeps the comparison honest.

---

## leaderboards/{scope}

`scope` is `global`, `weekly_{yyyy-Www}`, `monthly_{yyyy-MM}`.

```
entries   array<{ uid, displayName, photoUrl, xp, rank }>   top N only
updatedAt
```

A **single document per scope**, written by a scheduled Cloud Function.
Rankings are never computed by reading the users collection onto a device
(brief §36). Friends leaderboards are assembled client-side from the friends
subcollection, which is bounded and already local.

Users with `leaderboardOptOut` are excluded by the aggregation function.

---

## config/*

Documents that tune the product without shipping a build:
`config/level_curve`, `config/xp_rules`, `config/featured`. Read-only to
clients. This is what keeps level thresholds and XP values out of the UI
(brief §24).

---

## reports/{id}

`targetType` (recipe | comment | post | user), `targetId`, `reporterId`,
`reason`, `status`, `createdAt`. Write-only for clients: a reporter cannot read
the queue.

---

## Indexes

Declared in `firestore.indexes.json`. The composite indexes the app needs:

| Collection | Fields |
|---|---|
| `recipes` | `status`, `regionId`, `totalMinutes` |
| `recipes` | `status`, `category`, `averageRating desc` |
| `recipes` | `status`, `isFasting`, `difficulty` |
| `recipes` | `status`, `tags array-contains`, `numberOfCooks desc` |
| `posts` | `visibility`, `createdAt desc` |
| `cooking_sessions` (group) | `status`, `lastActiveAt desc` |
| `family_recipes` | `status`, `createdAt desc` |
| `family_recipes` | `authorId`, `status` |
