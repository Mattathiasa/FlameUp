import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/connectivity_service.dart';
import '../services/local_store.dart';
import 'pending_mutation.dart';

/// Handles one queued write. Returns normally on success; throws to retry.
typedef MutationHandler = Future<void> Function(PendingMutation mutation);

/// The durable queue of writes made while offline.
///
/// Writes are appended here *first* and applied to the local cache
/// immediately, so the UI reflects the change at once whether or not there is
/// a network. The queue drains when connectivity returns.
///
/// Ordering matters and is preserved: mutations replay oldest-first, because
/// "start session, advance to step 4, complete" applied out of order would
/// produce a session that never ran.
class Outbox {
  Outbox(this._store, this._connectivity);

  final LocalStore _store;
  final ConnectivityService _connectivity;

  final Map<MutationKind, MutationHandler> _handlers = {};
  final StreamController<int> _depth = StreamController<int>.broadcast();

  StreamSubscription<NetworkStatus>? _watch;
  bool _draining = false;

  /// Number of writes still waiting. Screens surface this as "N changes will
  /// sync when you're back online".
  Stream<int> get depth => _depth.stream;
  int get pendingCount => _store.keys(LocalStore.boxOutbox).length;

  /// Register the handler for a kind of write. Called once per feature during
  /// startup; a kind with no handler is left queued rather than dropped.
  void registerHandler(MutationKind kind, MutationHandler handler) {
    _handlers[kind] = handler;
  }

  /// Start draining whenever the device comes back online.
  void start() {
    _watch ??= _connectivity.watch().listen((status) {
      if (status == NetworkStatus.online) unawaited(drain());
    });
    unawaited(drain());
  }

  Future<void> dispose() async {
    await _watch?.cancel();
    _watch = null;
    await _depth.close();
  }

  /// Queue a write. The caller applies its own local change separately — the
  /// outbox is about reaching the server, not about local state.
  Future<PendingMutation> enqueue(PendingMutation mutation) async {
    await _store.writeJson(
      LocalStore.boxOutbox,
      mutation.idempotencyKey,
      mutation.toJson(),
    );
    _depth.add(pendingCount);

    // Try straight away when online, so an action taken with signal feels
    // immediate rather than waiting for the next connectivity event.
    if (await _connectivity.isOnline) unawaited(drain());
    return mutation;
  }

  /// Attempt every ready mutation, oldest first.
  ///
  /// Reentrancy-guarded: connectivity flapping must not start two concurrent
  /// drains and replay a mutation twice. (The idempotency key would make that
  /// harmless, but wasting the round trip is still worth avoiding.)
  Future<void> drain() async {
    if (_draining) return;
    if (!await _connectivity.isOnline) return;

    _draining = true;
    try {
      for (final mutation in _pending()) {
        if (!mutation.isReadyToRetry) continue;

        final handler = _handlers[mutation.kind];
        if (handler == null) {
          // A feature has not registered yet — leave it queued for the next
          // drain rather than discarding the user's work.
          continue;
        }

        try {
          await handler(mutation);
          await _remove(mutation.idempotencyKey);
        } catch (error) {
          final next = mutation.copyWith(
            attempts: mutation.attempts + 1,
            lastError: error.toString(),
          );

          if (next.isExhausted) {
            // Permanently rejected. Dropping it keeps the queue moving; the
            // local change stands and the discrepancy is reported.
            debugPrint('[outbox] giving up on $mutation: $error');
            await _remove(mutation.idempotencyKey);
          } else {
            await _store.writeJson(
              LocalStore.boxOutbox,
              next.idempotencyKey,
              next.toJson(),
            );
          }

          // Stop on the first failure: a later mutation usually depends on an
          // earlier one, and a network error means the rest will fail too.
          break;
        }
      }
    } finally {
      _draining = false;
      _depth.add(pendingCount);
    }
  }

  /// Queued mutations, oldest first. Unreadable entries are dropped.
  List<PendingMutation> _pending() {
    final out = <PendingMutation>[];
    for (final key in _store.keys(LocalStore.boxOutbox).toList()) {
      final json = _store.readJson(LocalStore.boxOutbox, key);
      final mutation = json == null ? null : PendingMutation.fromJson(json);
      if (mutation == null) {
        unawaited(_store.deleteKey(LocalStore.boxOutbox, key));
        continue;
      }
      out.add(mutation);
    }
    out.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return out;
  }

  Future<void> _remove(String key) =>
      _store.deleteKey(LocalStore.boxOutbox, key);
}

final outboxProvider = Provider<Outbox>((ref) {
  final outbox = Outbox(
    ref.watch(localStoreProvider),
    ref.watch(connectivityServiceProvider),
  );
  ref.onDispose(outbox.dispose);
  return outbox;
});

/// How many writes are waiting to sync. Drives the "will sync later" hint.
final pendingSyncCountProvider = StreamProvider<int>((ref) {
  final outbox = ref.watch(outboxProvider);
  return outbox.depth;
});
