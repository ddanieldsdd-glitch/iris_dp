import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Estado de conectividad de red.
enum NetworkStatus {
  online,
  offline,
}

final connectivityStatusProvider = StreamProvider<NetworkStatus>((ref) async* {
  final connectivity = Connectivity();
  yield _map(await connectivity.checkConnectivity());
  await for (final result in connectivity.onConnectivityChanged) {
    yield _map(result);
  }
});

NetworkStatus _map(List<ConnectivityResult> results) {
  if (results.isEmpty) return NetworkStatus.offline;
  if (results.every((r) => r == ConnectivityResult.none)) {
    return NetworkStatus.offline;
  }
  return NetworkStatus.online;
}

final isOnlineProvider = Provider<bool>((ref) {
  final status = ref.watch(connectivityStatusProvider);
  return status.maybeWhen(
    data: (s) => s == NetworkStatus.online,
    orElse: () => true,
  );
});
