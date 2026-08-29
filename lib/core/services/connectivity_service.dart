import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the device currently has a usable route to the network.
///
/// `connectivity_plus` reports the *interface*, not reachability, so this is
/// treated as a hint: repositories still attempt the call and fall back to
/// cache on failure. It exists to drive offline banners and to decide when the
/// outbox should try to drain.
enum NetworkStatus { online, offline }

class ConnectivityService {
  ConnectivityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  Stream<NetworkStatus> watch() =>
      _connectivity.onConnectivityChanged.map(_fromResults).distinct();

  Future<NetworkStatus> current() async =>
      _fromResults(await _connectivity.checkConnectivity());

  Future<bool> get isOnline async => await current() == NetworkStatus.online;

  static NetworkStatus _fromResults(List<ConnectivityResult> results) {
    final hasInterface = results.any((r) => r != ConnectivityResult.none);
    return hasInterface ? NetworkStatus.online : NetworkStatus.offline;
  }
}

final connectivityServiceProvider = Provider<ConnectivityService>(
  (ref) => ConnectivityService(),
);

/// Live network status. Starts pessimistic-free: the first real value arrives
/// from [ConnectivityService.current] before the stream produces anything.
final networkStatusProvider = StreamProvider<NetworkStatus>((ref) async* {
  final service = ref.watch(connectivityServiceProvider);
  yield await service.current();
  yield* service.watch();
});

final isOfflineProvider = Provider<bool>((ref) {
  return ref.watch(networkStatusProvider).maybeWhen(
        data: (status) => status == NetworkStatus.offline,
        orElse: () => false,
      );
});
