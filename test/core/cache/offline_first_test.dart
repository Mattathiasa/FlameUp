import 'package:flameup/core/cache/cache_entry.dart';
import 'package:flameup/core/cache/offline_first.dart';
import 'package:flameup/core/errors/failure.dart';
import 'package:flutter_test/flutter_test.dart';

/// A cache entry aged by [age], for testing staleness decisions.
CacheEntry<String> entry(String value, {Duration age = Duration.zero}) =>
    CacheEntry(value: value, cachedAt: DateTime.now().subtract(age));

void main() {
  group('offline-first read', () {
    test('emits cached data first, then the fresh value', () async {
      final emitted = await OfflineFirst.read<String>(
        readCache: () => entry('cached', age: const Duration(days: 1)),
        fetch: () async => 'fresh',
        writeCache: (_) async {},
        ttl: const Duration(hours: 6),
      ).toList();

      expect(emitted, hasLength(2));
      expect(emitted.first.value, 'cached');
      expect(emitted.first.origin, DataOrigin.cache);
      expect(
        emitted.first.isRefreshing,
        isTrue,
        reason: 'a stale entry should announce that it is refreshing',
      );
      expect(emitted.last.value, 'fresh');
      expect(emitted.last.origin, DataOrigin.network);
    });

    test('fresh cache is served without touching the network', () async {
      var fetched = false;

      final emitted = await OfflineFirst.read<String>(
        readCache: () => entry('cached', age: const Duration(minutes: 5)),
        fetch: () async {
          fetched = true;
          return 'fresh';
        },
        writeCache: (_) async {},
        ttl: const Duration(hours: 6),
      ).toList();

      expect(fetched, isFalse, reason: 'a fresh entry must not refetch');
      expect(emitted, hasLength(1));
      expect(emitted.single.isRefreshing, isFalse);
    });

    test('an empty cache fetches and emits only the fresh value', () async {
      final emitted = await OfflineFirst.read<String>(
        readCache: () => null,
        fetch: () async => 'fresh',
        writeCache: (_) async {},
      ).toList();

      expect(emitted, hasLength(1));
      expect(emitted.single.value, 'fresh');
      expect(emitted.single.origin, DataOrigin.network);
    });

    test('forceRefresh refetches even when the cache is fresh', () async {
      var fetched = false;

      await OfflineFirst.read<String>(
        readCache: () => entry('cached'),
        fetch: () async {
          fetched = true;
          return 'fresh';
        },
        writeCache: (_) async {},
        forceRefresh: true,
      ).toList();

      expect(fetched, isTrue);
    });

    test('writes the fetched value back to the cache', () async {
      String? written;

      await OfflineFirst.read<String>(
        readCache: () => null,
        fetch: () async => 'fresh',
        writeCache: (value) async => written = value,
      ).toList();

      expect(written, 'fresh');
    });
  });

  group('when the network fails', () {
    test('cached data keeps being shown, flagged as not live', () async {
      final emitted = await OfflineFirst.read<String>(
        readCache: () => entry('cached', age: const Duration(days: 1)),
        fetch: () async => throw const NetworkFailure(),
        writeCache: (_) async {},
      ).toList();

      expect(emitted, hasLength(2));
      expect(
        emitted.last.value,
        'cached',
        reason: 'a failed refresh must not blank the screen',
      );
      expect(emitted.last.origin, DataOrigin.cacheAfterFailure);
      expect(emitted.last.refreshFailed, isTrue);
      expect(emitted.last.isFromCache, isTrue);
    });

    test('only throws when there is nothing cached at all', () async {
      // The single genuine error case: no cache, no network.
      await expectLater(
        OfflineFirst.read<String>(
          readCache: () => null,
          fetch: () async => throw const NetworkFailure(),
          writeCache: (_) async {},
        ).toList(),
        throwsA(isA<NetworkFailure>()),
      );
    });

    test('maps a raw provider error into a Failure', () async {
      await expectLater(
        OfflineFirst.read<String>(
          readCache: () => null,
          fetch: () async => throw StateError('boom'),
          writeCache: (_) async {},
        ).toList(),
        throwsA(isA<UnknownFailure>()),
      );
    });
  });

  group('hasChanged', () {
    test('an unchanged refresh does not re-emit new data', () async {
      final emitted = await OfflineFirst.read<String>(
        readCache: () => entry('same', age: const Duration(days: 1)),
        fetch: () async => 'same',
        writeCache: (_) async {},
        hasChanged: (cached, fresh) => cached != fresh,
      ).toList();

      // Still two events -- the second reports the value is now confirmed
      // live -- but the value itself is identical, so no visible rebuild.
      expect(emitted, hasLength(2));
      expect(emitted.last.value, 'same');
      expect(emitted.last.origin, DataOrigin.network);
      expect(emitted.last.refreshFailed, isFalse);
    });
  });

  group('readOnce', () {
    test('returns fresh cache without fetching', () async {
      var fetched = false;

      final result = await OfflineFirst.readOnce<String>(
        readCache: () => entry('cached'),
        fetch: () async {
          fetched = true;
          return 'fresh';
        },
        writeCache: (_) async {},
      );

      expect(fetched, isFalse);
      expect(result.value, 'cached');
      expect(result.origin, DataOrigin.cache);
    });

    test('falls back to stale cache when the fetch fails', () async {
      final result = await OfflineFirst.readOnce<String>(
        readCache: () => entry('stale', age: const Duration(days: 3)),
        fetch: () async => throw const NetworkFailure(),
        writeCache: (_) async {},
      );

      expect(result.value, 'stale');
      expect(result.refreshFailed, isTrue);
    });

    test('throws when there is no cache and the fetch fails', () async {
      await expectLater(
        OfflineFirst.readOnce<String>(
          readCache: () => null,
          fetch: () async => throw const NetworkFailure(),
          writeCache: (_) async {},
        ),
        throwsA(isA<NetworkFailure>()),
      );
    });
  });

  group('CacheEntry', () {
    test('reports staleness against its TTL', () {
      expect(
        entry('v', age: const Duration(hours: 1))
            .isStale(ttl: const Duration(hours: 6)),
        isFalse,
      );
      expect(
        entry('v', age: const Duration(hours: 7))
            .isStale(ttl: const Duration(hours: 6)),
        isTrue,
      );
    });

    test('survives a JSON round trip', () {
      final original = entry('value', age: const Duration(minutes: 30));
      final restored = CacheEntry.fromJson<String>(
        original.toJson((v) => v),
        (raw) => raw! as String,
      );

      expect(restored, isNotNull);
      expect(restored!.value, 'value');
      expect(
        restored.cachedAt.difference(original.cachedAt).inSeconds.abs(),
        lessThan(1),
      );
    });

    test('a corrupt entry decodes to null rather than throwing', () {
      expect(CacheEntry.fromJson<String>(null, (r) => r! as String), isNull);
      expect(
        CacheEntry.fromJson<String>(
          {'value': 'x', 'cachedAt': 'not-a-date'},
          (r) => r! as String,
        ),
        isNull,
      );
    });
  });
}
