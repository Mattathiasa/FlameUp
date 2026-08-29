import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/connectivity_service.dart';
import 'outbox.dart';

/// What the app should tell the user about its connection to the server.
enum SyncState {
  /// Online, nothing queued.
  synced,

  /// Online, writes are draining.
  syncing,

  /// Offline. Reads come from cache; writes are queued.
  offline,

  /// Offline with queued writes waiting.
  offlinePending,
}

/// The one thing a banner or status pill needs to read.
class SyncStatus {
  const SyncStatus({required this.state, required this.pendingCount});

  final SyncState state;
  final int pendingCount;

  bool get isOffline =>
      state == SyncState.offline || state == SyncState.offlinePending;

  bool get hasPendingWork => pendingCount > 0;

  /// Whether a banner is worth showing at all. Being online and fully synced
  /// is the normal case and deserves no chrome.
  bool get shouldSurface => state != SyncState.synced;
}

/// Derived from connectivity and outbox depth together, so the UI has a single
/// source for "am I offline, and is anything waiting".
final syncStatusProvider = Provider<SyncStatus>((ref) {
  final offline = ref.watch(isOfflineProvider);
  final pending = ref.watch(pendingSyncCountProvider).valueOrNull ??
      ref.watch(outboxProvider).pendingCount;

  final state = switch ((offline, pending > 0)) {
    (true, true) => SyncState.offlinePending,
    (true, false) => SyncState.offline,
    (false, true) => SyncState.syncing,
    (false, false) => SyncState.synced,
  };

  return SyncStatus(state: state, pendingCount: pending);
});
