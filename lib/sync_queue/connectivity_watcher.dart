import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../core/logger.dart';
import 'sync_queue_manager.dart';

/// Monitors device network connectivity and triggers a queue sync
/// automatically whenever the device transitions from offline → online.
class ConnectivityWatcher {
  final SyncQueueManager _queueManager;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool _wasOffline = false;

  ConnectivityWatcher(this._queueManager);

  /// Begin watching. Call once during app initialisation.
  void start() {
    _subscription = Connectivity().onConnectivityChanged.listen(
      _onConnectivityChanged,
      onError: (Object e) =>
          AppLogger.error('[NET] Connectivity stream error', e),
    );
    AppLogger.info('[NET] Connectivity watcher started');
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final isOnline = results.any((r) => r != ConnectivityResult.none);

    AppLogger.info(
        '[NET] Connectivity changed → ${isOnline ? '🟢 online' : '🔴 offline'}');

    if (isOnline && _wasOffline) {
      AppLogger.info(
          '[NET] Device came back online — triggering background queue sync');
      _queueManager.processPendingQueue();
    }

    _wasOffline = !isOnline;
  }

  /// Performs a one-shot connectivity check.
  Future<bool> isCurrentlyOnline() async {
    final results = await Connectivity().checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  /// Stop watching. Call in onDispose.
  void stop() {
    _subscription?.cancel();
    AppLogger.info('[NET] Connectivity watcher stopped');
  }
}
