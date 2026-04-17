import 'package:hive_flutter/hive_flutter.dart';

import '../core/logger.dart';
import '../models/queue_item.dart';
import '../models/sync_status.dart';
import 'hive_service.dart';

/// Data Access Object for the sync queue persisted in Hive.
///
/// All operations that mutate queue state are persisted immediately —
/// even a process kill between writes will leave the queue consistent.
///
/// FIFO ordering is enforced by sorting on [QueueItem.createdAt].
class QueueLocalDao {
  Box<QueueItem> get _box => HiveService.queueBox;

  /// Adds a new item to the end of the queue (keyed by its UUID id).
  Future<void> enqueue(QueueItem item) async {
    await _box.put(item.id, item);
    AppLogger.info(
        '[QUEUE] Added action=${item.actionType} id=${item.id.substring(0, 8)}…, '
        'queue size increased to ${_box.length}');
  }

  /// Returns all items eligible for processing (pending or stalled syncing),
  /// sorted FIFO by [createdAt].
  List<QueueItem> getPendingItems() {
    return _box.values
        .where((item) =>
            item.status == SyncStatus.pending.value ||
            item.status == SyncStatus.syncing.value)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  /// Returns ALL queue items (including succeeded placeholders if any) for
  /// the debug inspector panel.
  List<QueueItem> getAll() {
    return _box.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  /// Returns items marked as failed (for launch-time retry reset).
  List<QueueItem> getFailedItems() {
    return _box.values
        .where((item) => item.status == SyncStatus.failed.value)
        .toList();
  }

  Future<void> updateStatus(String id, SyncStatus status) async {
    final item = _box.get(id);
    if (item != null) {
      item.status = status.value;
      await item.save();
    }
  }

  Future<void> updateRetryCount(String id, int count) async {
    final item = _box.get(id);
    if (item != null) {
      item.retryCount = count;
      await item.save();
    }
  }

  /// Permanently removes a successfully synced item from the queue.
  Future<void> remove(String id) async {
    await _box.delete(id);
    AppLogger.debug(
        '[QUEUE] Removed synced item id=${id.substring(0, 8)}…, '
        'remaining queue size=${_box.length}');
  }

  /// On app launch: reset all [failed] items back to [pending] so they are
  /// retried in this session. This ensures no item is permanently lost.
  Future<void> resetFailedToPending() async {
    final failed = getFailedItems();
    for (final item in failed) {
      item.status = SyncStatus.pending.value;
      await item.save();
    }
    if (failed.isNotEmpty) {
      AppLogger.info(
          '[QUEUE] Reset ${failed.length} failed item(s) to pending on launch');
    }
  }

  int get pendingCount => getPendingItems().length;
  int get totalCount => _box.length;
}
