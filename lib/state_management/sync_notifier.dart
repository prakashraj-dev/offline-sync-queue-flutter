import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logger.dart';
import '../sync_queue/connectivity_watcher.dart';
import '../sync_queue/sync_queue_manager.dart';

/// UI-facing sync and connectivity state.
class SyncState {
  final bool isOnline;
  final bool isSyncing;
  final DateTime? lastSyncTime;

  const SyncState({
    this.isOnline = true,
    this.isSyncing = false,
    this.lastSyncTime,
  });

  SyncState copyWith({
    bool? isOnline,
    bool? isSyncing,
    DateTime? lastSyncTime,
  }) {
    return SyncState(
      isOnline: isOnline ?? this.isOnline,
      isSyncing: isSyncing ?? this.isSyncing,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
    );
  }
}

/// Exposes sync running state and manual sync trigger to the UI.
class SyncNotifier extends StateNotifier<SyncState> {
  final SyncQueueManager _syncManager;
  final ConnectivityWatcher _connectivityWatcher;

  SyncNotifier(this._syncManager, this._connectivityWatcher)
      : super(const SyncState()) {
    _checkConnectivity();
  }

  Future<void> _checkConnectivity() async {
    final isOnline = await _connectivityWatcher.isCurrentlyOnline();
    if (mounted) {
      state = state.copyWith(isOnline: isOnline);
    }
  }

  /// User-initiated or auto-triggered sync.
  Future<void> triggerSync() async {
    if (!state.isOnline) {
      AppLogger.warning(
          '[SYNC] Skipping sync trigger — device reported as offline in UI state');
      return;
    }

    state = state.copyWith(isSyncing: true);

    try {
      await _syncManager.processPendingQueue();
      if (mounted) {
        state = state.copyWith(
          isSyncing: false,
          lastSyncTime: DateTime.now(),
        );
      }
    } catch (e) {
      if (mounted) state = state.copyWith(isSyncing: false);
      AppLogger.error('[SYNC] Unexpected error in manual sync trigger', e);
    }
  }

  /// Called from the UI "Simulate Offline" toggle.
  void setOnlineStatus(bool isOnline) {
    if (mounted) state = state.copyWith(isOnline: isOnline);
  }
}
