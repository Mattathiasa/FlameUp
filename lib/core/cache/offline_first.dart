import 'dart:async';

import '../errors/error_mapper.dart';
import '../errors/failure.dart';
import 'cache_entry.dart';

/// The offline-first read policy, in one place.
///
/// The contract every repository read follows:
///
/// 1. If anything is cached, **emit it immediately**. Not "if it is fresh" —
///    always. A user with no signal still gets their app.
/// 2. If the cache was empty, or the entry is past its TTL, fetch in the
///    background and emit again when it lands.
/// 3. If the fetch fails and there was cached data, keep showing it and flag
///    [Cached.refreshFailed]. A failed refresh is not an error state.
/// 4. Only fail outright when there is **nothing cached and nothing fetched**.
///
/// That last point is the whole design: an error screen is reserved for the
/// case where there is genuinely nothing to show.
abstract final class OfflineFirst {
  /// Read [T] cache-first, then refresh.
  ///
  /// Emits once or twice: the cached value, then the fresh one if a refresh
  /// happened and actually changed something.
  static Stream<Cached<T>> read<T>({
    required CacheEntry<T>? Function() readCache,
    required Future<T> Function() fetch,
    required Future<void> Function(T value) writeCache,
    Duration ttl = const Duration(hours: 6),
    bool forceRefresh = false,
    bool Function(T cached, T fresh)? hasChanged,
  }) async* {
    final cached = readCache();
    final shouldFetch =
        forceRefresh || cached == null || cached.isStale(ttl: ttl);

    if (cached != null) {
      yield Cached<T>(
        value: cached.value,
        origin: DataOrigin.cache,
        cachedAt: cached.cachedAt,
        isRefreshing: shouldFetch,
      );
    }

    if (!shouldFetch) return;

    try {
      final fresh = await fetch();
      await writeCache(fresh);

      // Re-emitting an identical value would rebuild the screen for nothing.
      final changed =
          cached == null || (hasChanged?.call(cached.value, fresh) ?? true);
      if (changed) {
        yield Cached<T>(
          value: fresh,
          origin: DataOrigin.network,
          cachedAt: DateTime.now(),
        );
      } else {
        yield Cached<T>(
          value: cached.value,
          origin: DataOrigin.network,
          cachedAt: DateTime.now(),
        );
      }
    } catch (error, stackTrace) {
      final failure = ErrorMapper.map(error, stackTrace);

      // Nothing cached and the fetch failed: this is the one case where the
      // caller genuinely has nothing to render.
      if (cached == null) throw failure;

      yield Cached<T>(
        value: cached.value,
        origin: DataOrigin.cacheAfterFailure,
        cachedAt: cached.cachedAt,
        refreshFailed: true,
      );
    }
  }

  /// One-shot variant for callers that cannot consume a stream.
  ///
  /// Returns cached data straight away when it is fresh; otherwise waits for
  /// the fetch, falling back to stale cache if that fails.
  static Future<Cached<T>> readOnce<T>({
    required CacheEntry<T>? Function() readCache,
    required Future<T> Function() fetch,
    required Future<void> Function(T value) writeCache,
    Duration ttl = const Duration(hours: 6),
    bool forceRefresh = false,
  }) async {
    final cached = readCache();

    if (!forceRefresh && cached != null && !cached.isStale(ttl: ttl)) {
      return Cached<T>(
        value: cached.value,
        origin: DataOrigin.cache,
        cachedAt: cached.cachedAt,
      );
    }

    try {
      final fresh = await fetch();
      await writeCache(fresh);
      return Cached<T>(
        value: fresh,
        origin: DataOrigin.network,
        cachedAt: DateTime.now(),
      );
    } catch (error, stackTrace) {
      if (cached == null) throw ErrorMapper.map(error, stackTrace);
      return Cached<T>(
        value: cached.value,
        origin: DataOrigin.cacheAfterFailure,
        cachedAt: cached.cachedAt,
        refreshFailed: true,
      );
    }
  }
}

/// Thrown when there is no cached data and the fetch failed — the only
/// genuine error case in an offline-first read.
Failure asFailure(Object error) => ErrorMapper.map(error);
