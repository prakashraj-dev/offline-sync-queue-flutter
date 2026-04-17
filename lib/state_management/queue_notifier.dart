import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../local_db/queue_local_dao.dart';
import '../models/queue_item.dart';
import '../sync_queue/queue_metrics.dart';
import '../sync_queue/sync_queue_manager.dart';

/// UI-facing snapshot of the sync queue.
class QueueState {
  final List<QueueItem> items;
  final int pendingCount;
  final int successCount;
  final int failureCount;
  final bool isSyncing;

  const QueueState({
    this.items = const [],
    this.pendingCount = 0,
    this.successCount = 0,
    this.failureCount = 0,
    this.isSyncing = false,
  });

  QueueState copyWith({
    List<QueueItem>? items,
    int? pendingCount,
    int? successCount,
    int? failureCount,
    bool? isSyncing,
  }) {
    return QueueState(
      items: items ?? this.items,
      pendingCount: pendingCount ?? this.pendingCount,
      successCount: successCount ?? this.successCount,
      failureCount: failureCount ?? this.failureCount,
      isSyncing: isSyncing ?? this.isSyncing,
    );
  }
}

/// Keeps the UI in sync with the queue by:
/// 1. Listening to [SyncQueueManager.onQueueChanged] stream
/// 2. Listening to [QueueMetrics] ChangeNotifier
class QueueNotifier extends StateNotifier<QueueState> {
  final QueueLocalDao _queueDao;
  final QueueMetrics _metrics;
  final SyncQueueManager _syncManager;

  StreamSubscription<void>? _queueChangeSub;

  QueueNotifier(this._queueDao, this._metrics, this._syncManager)
      : super(const QueueState()) {
    _init();
  }

  void _init() {
    _refresh();
    _metrics.addListener(_onMetricsChanged);
    _queueChangeSub = _syncManager.onQueueChanged.listen((_) => _refresh());
  }

  void _onMetricsChanged() {
    state = state.copyWith(
      pendingCount: _metrics.pendingCount,
      successCount: _metrics.successCount,
      failureCount: _metrics.failureCount,
      isSyncing: _syncManager.isProcessing,
    );
  }

  void _refresh() {
    state = state.copyWith(
      items: _queueDao.getAll(),
      pendingCount: _queueDao.pendingCount,
      isSyncing: _syncManager.isProcessing,
    );
  }

  /// Manual refresh — call after enqueue operations from outside the sync engine.
  void refresh() => _refresh();

  @override
  void dispose() {
    _queueChangeSub?.cancel();
    _metrics.removeListener(_onMetricsChanged);
    super.dispose();
  }
}
