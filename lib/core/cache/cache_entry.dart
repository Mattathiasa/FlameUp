import '../constants/app_constants.dart';

/// A cached value plus the metadata needed to reason about its age.
///
/// FlameUp is offline-first: a cached value is served immediately, every time,
/// and freshness only decides whether a background refresh is *also* started.
/// Staleness is never a reason to show nothing.
class CacheEntry<T> {
  const CacheEntry({
    required this.value,
    required this.cachedAt,
    this.etag,
  });

  final T value;
  final DateTime cachedAt;

  /// Optional server version marker, when the source provides one.
  final String? etag;

  Duration get age => DateTime.now().difference(cachedAt);

  /// Past its TTL. Still served — this only triggers a refresh.
  bool isStale({Duration ttl = AppConstants.cacheTtl}) => age > ttl;

  Map<String, dynamic> toJson(Object? Function(T value) encodeValue) => {
        'value': encodeValue(value),
        'cachedAt': cachedAt.toIso8601String(),
        if (etag != null) 'etag': etag,
      };

  static CacheEntry<T>? fromJson<T>(
    Map<String, dynamic>? json,
    T Function(Object? raw) decodeValue,
  ) {
    if (json == null) return null;
    final cachedAt = DateTime.tryParse(json['cachedAt'] as String? ?? '');
    if (cachedAt == null) return null;
    return CacheEntry<T>(
      value: decodeValue(json['value']),
      cachedAt: cachedAt,
      etag: json['etag'] as String?,
    );
  }
}

/// Where a value the UI is rendering came from.
///
/// Screens use this to say "showing saved data" honestly instead of implying
/// everything is live.
enum DataOrigin {
  /// Read from cache; no network attempt has resolved yet.
  cache,

  /// Fresh from the server.
  network,

  /// From cache because the network attempt failed.
  cacheAfterFailure,
}

/// A value together with where it came from and whether it is being refreshed.
///
/// This is what repositories emit, rather than a bare `T`, so a screen can
/// render real content and an "updating" hint at the same time — the thing a
/// plain `AsyncValue` cannot express, because its loading state has no data.
class Cached<T> {
  const Cached({
    required this.value,
    required this.origin,
    this.cachedAt,
    this.isRefreshing = false,
    this.refreshFailed = false,
  });

  final T value;
  final DataOrigin origin;
  final DateTime? cachedAt;

  /// A background refresh is in flight; [value] is still worth showing.
  final bool isRefreshing;

  /// The last refresh failed. [value] is cached data, not live.
  final bool refreshFailed;

  bool get isFromCache => origin != DataOrigin.network;

  Cached<T> copyWith({
    T? value,
    DataOrigin? origin,
    DateTime? cachedAt,
    bool? isRefreshing,
    bool? refreshFailed,
  }) =>
      Cached<T>(
        value: value ?? this.value,
        origin: origin ?? this.origin,
        cachedAt: cachedAt ?? this.cachedAt,
        isRefreshing: isRefreshing ?? this.isRefreshing,
        refreshFailed: refreshFailed ?? this.refreshFailed,
      );

  Cached<R> map<R>(R Function(T value) transform) => Cached<R>(
        value: transform(value),
        origin: origin,
        cachedAt: cachedAt,
        isRefreshing: isRefreshing,
        refreshFailed: refreshFailed,
      );
}
