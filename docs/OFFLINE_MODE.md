# FlameUp — offline mode

FlameUp is **offline-first**, not merely offline-tolerant. The distinction that
matters: a cached value is served **immediately, every time**. Freshness only
decides whether a background refresh also runs. Staleness is never a reason to
show nothing.

This is a product requirement, not a technical nicety. People cook in kitchens
with bad signal, and a step timer that stops because the network dropped is a
ruined dish.

---

## Not a local database

The cache is a **key-value JSON store over Hive**, not SQLite/Drift.

The app caches documents and lists of documents keyed by their query — a
key-value shape. A relational engine would add codegen, a migration story and a
native dependency to buy joins nothing here performs. Firestore already ships
an offline cache for ordinary reads; the layer described here exists for what
that cache cannot express: **a query result the UI can reason about**, and
**writes that must survive being made offline**.

| Tier | Technology | Holds |
|---|---|---|
| Firestore persistence | built in, `persistenceEnabled: true` | document reads and live listeners |
| `CacheStore` | Hive boxes, JSON | query results, feed pages, recipe lists |
| `Outbox` | Hive box, JSON | writes waiting to reach the server |
| `SharedPreferences` | scalars | theme, language, onboarding flag, active session id |

---

## Reading — `OfflineFirst.read`

Every repository read follows one policy, implemented once in
`lib/core/cache/offline_first.dart`:

1. **Anything cached is emitted immediately** — not "if fresh", always.
2. If the cache was empty or past its TTL, fetch in the background and emit
   again when it lands.
3. **If the fetch fails and there was cached data, keep showing it** and set
   `refreshFailed`. A failed refresh is not an error state.
4. **Only fail outright when there is nothing cached and nothing fetched.**

Point 4 is the design. An error screen is reserved for the one case where there
is genuinely nothing to show.

### What the UI receives

Repositories emit `Cached<T>`, not a bare `T`:

```dart
class Cached<T> {
  final T value;
  final DataOrigin origin;      // cache | network | cacheAfterFailure
  final DateTime? cachedAt;
  final bool isRefreshing;      // real content AND an updating hint
  final bool refreshFailed;     // this is saved data, not live
}
```

`AsyncValue.loading` cannot express "here is real content, and it is being
updated" — its loading state carries no data. `Cached` can, which is why
screens can render content and a subtle refresh hint at the same time instead
of flashing a spinner over data the user was already reading.

`DataOrigin` also lets screens say *"showing saved data"* honestly rather than
implying everything on screen is live.

---

## Writing — the outbox

Offline writes are not dropped and not silently retried into oblivion. They are
**appended to a durable queue first**, and applied to the local cache
immediately, so the UI reflects the change at once regardless of network.

```
user acts
   -> local cache updated immediately (UI is correct now)
   -> PendingMutation appended to the outbox
   -> drains when connectivity returns, oldest first
```

### Idempotency keys — why XP cannot double

Each `PendingMutation` carries an `idempotencyKey` generated **when the user
acts**, on the device — not when the request is sent.

A retry, an app restart mid-drain, or a double tap all carry the *same* key,
and the server refuses the second grant. This is what stops a recipe finished
on a plane from awarding XP twice when the phone lands.

### Ordering

Mutations replay **oldest first**, and the drain **stops at the first failure**.
"Start session → advance to step 4 → complete" applied out of order would
produce a session that never ran. A later mutation usually depends on an
earlier one, so a network error means the rest would fail too.

### Backoff and giving up

Exponential and capped: `0s, 2s, 8s, 30s, 2m, 10m, 30m…`, keyed off attempt
count rather than wall time so a device offline for a week does not hammer the
server on reconnect.

After `maxAttempts` (8) a mutation is dropped so a permanently rejected write
cannot block the queue behind it forever. The local change stands and the
discrepancy is reported.

### Robustness

Every cache and outbox read is non-throwing. A corrupt or half-written entry is
dropped and reported as a miss — one unreadable row must never take down a
screen or stop the rest of the queue draining.

---

## Sync status

`syncStatusProvider` combines connectivity with outbox depth into the single
thing a banner needs:

| State | Meaning |
|---|---|
| `synced` | Online, nothing queued — **no chrome shown** |
| `syncing` | Online, writes draining |
| `offline` | Offline; reads from cache, writes queued |
| `offlinePending` | Offline with writes waiting |

Being online and synced is the normal case and deserves no banner.

---

## Cooking offline

Cook mode is the hardest case and drives the design.

- The recipe is cached when the session starts, so every step is readable
  without signal.
- The session document is written locally first and mirrored to Firestore.
- **Timers store absolute wall-clock deadlines**, not remaining seconds, so a
  timer is a subtraction against the clock — correct whether the app was
  suspended, killed, or the phone was asleep.
- Completion queues a mutation with an idempotency key. XP is granted
  server-side, once, whenever the device next reaches the network.

---

## Testing

`test/core/cache/` covers the policy directly:

- cached data is emitted before any fetch
- fresh cache does not touch the network
- **a failed refresh keeps showing cached data** rather than blanking
- the read throws *only* when there is no cache and no network
- idempotency keys survive retries; separate actions get separate keys
- backoff is exponential and capped
- corrupt cache and outbox entries decode to null instead of throwing
