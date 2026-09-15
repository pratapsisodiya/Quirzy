import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Wraps `connectivity_plus` behind a plain online/offline signal — callers
/// don't need to care which transport (wifi/mobile/ethernet) is active.
class ConnectivityService {
  final Connectivity _connectivity = Connectivity();

  bool _isOnline(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  Future<bool> checkIsOnline() async {
    final results = await _connectivity.checkConnectivity();
    return _isOnline(results);
  }

  Stream<bool> get onlineStatusStream =>
      _connectivity.onConnectivityChanged.map(_isOnline);
}

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService();
});

/// Live online/offline state — starts from a real check, then follows
/// connectivity changes.
final isOnlineProvider = StreamProvider<bool>((ref) async* {
  final service = ref.watch(connectivityServiceProvider);
  yield await service.checkIsOnline();
  yield* service.onlineStatusStream;
});
