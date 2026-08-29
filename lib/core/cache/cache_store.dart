import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/local_store.dart';
import 'cache_entry.dart';

/// Typed JSON cache on top of the Hive boxes opened by [LocalStore].
///
/// Deliberately not a database. FlameUp caches *documents and lists of
/// documents* keyed by a query string, which is a key-value shape; adding a
/// relational engine would buy joins nothing here needs and cost a codegen
/// step, a migration story and a native dependency.
///
/// Every read is non-throwing: a corrupt or half-written entry is dropped and
/// reported as a miss, because a bad cache entry must never take a screen down.
class CacheStore {
  const CacheStore(this._store);

  final LocalStore _store;

  /// Read one cached document.
  CacheEntry<Map<String, dynamic>>? readDoc(String box, String key) {
    final raw = _store.readJson(box, key);
    return CacheEntry.fromJson<Map<String, dynamic>>(
      raw,
      (value) => (value as Map).cast<String, dynamic>(),
    );
  }

  /// Read a cached list — a query result, a feed page, a collection.
  CacheEntry<List<Map<String, dynamic>>>? readList(String box, String key) {
    final raw = _store.readJson(box, key);
    return CacheEntry.fromJson<List<Map<String, dynamic>>>(
      raw,
      (value) => (value as List)
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList(growable: false),
    );
  }

  Future<void> writeDoc(
    String box,
    String key,
    Map<String, dynamic> value, {
    String? etag,
  }) =>
      _store.writeJson(
        box,
        key,
        CacheEntry(value: value, cachedAt: DateTime.now(), etag: etag)
            .toJson((v) => v),
      );

  Future<void> writeList(
    String box,
    String key,
    List<Map<String, dynamic>> value, {
    String? etag,
  }) =>
      _store.writeJson(
        box,
        key,
        CacheEntry(value: value, cachedAt: DateTime.now(), etag: etag)
            .toJson((v) => v),
      );

  /// Merge documents into a list cache without refetching it.
  ///
  /// Used when a single document is updated and the lists it appears in should
  /// reflect that immediately, which is what makes an offline edit feel real.
  Future<void> patchList(
    String box,
    String key,
    Map<String, dynamic> doc, {
    required String idField,
  }) async {
    final existing = readList(box, key);
    if (existing == null) return;
    final id = doc[idField];
    final merged = [
      for (final item in existing.value)
        if (item[idField] == id) doc else item,
    ];
    await writeList(box, key, merged, etag: existing.etag);
  }

  Future<void> invalidate(String box, String key) => _store.deleteKey(box, key);

  /// Drop every entry in a box whose key starts with [prefix].
  ///
  /// Query caches are keyed by their parameters, so invalidating "every recipe
  /// list" means clearing a prefix rather than naming each key.
  Future<void> invalidatePrefix(String box, String prefix) async {
    final doomed = _store.keys(box).where((k) => k.startsWith(prefix)).toList();
    for (final key in doomed) {
      await _store.deleteKey(box, key);
    }
  }

  /// A stable cache key from a collection name and its query parameters.
  ///
  /// Sorted so `{a:1, b:2}` and `{b:2, a:1}` are the same cache entry rather
  /// than two copies of one result.
  static String keyFor(
    String collection, [
    Map<String, Object?> params = const {},
  ]) {
    if (params.isEmpty) return collection;
    final entries = params.entries.where((e) => e.value != null).toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final encoded =
        entries.map((e) => '${e.key}=${jsonEncode(e.value)}').join('&');
    return '$collection?$encoded';
  }
}

final cacheStoreProvider = Provider<CacheStore>(
  (ref) => CacheStore(ref.watch(localStoreProvider)),
);
