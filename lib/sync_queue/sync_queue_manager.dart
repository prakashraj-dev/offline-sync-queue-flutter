import 'dart:async';
import 'dart:math';

import '../core/constants.dart';
import '../core/logger.dart';
import '../local_db/cache_meta_dao.dart';
import '../local_db/notes_local_dao.dart';
import '../local_db/queue_local_dao.dart';
import '../local_db/saved_items_local_dao.dart';
import '../models/action_type.dart';
import '../models/queue_item.dart';
import '../models/sync_status.dart';
import '../remote_api/remote_api.dart';
import 'queue_metrics.dart';

/// Core sync engine: processes the offline queue with FIFO ordering,
/// exponential backoff, idempotent retries, and structured observability.
///
/// Guarantees:
/// ● FIFO processing — items sorted by [QueueItem.createdAt]
/// ● Re-entrant safe — concurrent [processPendingQueue] calls are ignored
/// ● Idempotent — UUID is Firestore doc ID; repeated calls are no-ops
/// ● Durable — every status change is persisted before the network call
/// ● Observable — all lifecycle events emit structured log lines
class SyncQueueManager {
  final QueueLocalDao _queueDao;
  final NotesLocalDao _notesDao;
  final SavedItemsLocalDao _savedItemsDao;
  final CacheMetaDao _cacheMetaDao;
  final RemoteApi _remoteApi;
  final QueueMetrics _metrics;

  bool _isProcessing = false;

  /// Broadcast stream that fires whenever queue state changes.
  /// UI layers subscribe to this to refresh without polling.
  final _queueChangedController = StreamController<void>.broadcast();
  Stream<void> get onQueueChanged => _queueChangedController.stream;

  SyncQueueManager({
    required QueueLocalDao queueDao,
    required NotesLocalDao notesDao,
    required SavedItemsLocalDao savedItemsDao,
    required CacheMetaDao cacheMetaDao,
    required RemoteApi remoteApi,
    required QueueMetrics metrics,
  })  : _queueDao = queueDao,
        _notesDao = notesDao,
        _savedItemsDao = savedItemsDao,
        _cacheMetaDao = cacheMetaDao,
        _remoteApi = remoteApi,
        _metrics = metrics;

  bool get isProcessing => _isProcessing;

  // ── Public Entry Point ────────────────────────────────────────────────────

  /// Processes all pending queue items sequentially (FIFO).
  ///
  /// Re-entrant safe: if already running, this call is a no-op.
  /// Call this on: app launch, connectivity restored, or user-triggered sync.
  Future<void> processPendingQueue() async {
    if (_isProcessing) {
      AppLogger.debug(
          '[SYNC] Already processing — ignoring duplicate trigger');
      return;
    }

    _isProcessing = true;
    _emit();

    try {
      final items = _queueDao.getPendingItems();

      if (items.isEmpty) {
        AppLogger.info('[SYNC] Queue is empty — nothing to process ✓');
        return;
      }

      AppLogger.info(
          '[SYNC] ▶ Processing queue: ${items.length} pending item(s)');
      _metrics.setPending(items.length);

      for (final item in items) {
        await _processItem(item);
        _emit(); // notify UI after each item
      }

      await _cacheMetaDao.setLastSyncTimestamp(DateTime.now());
      AppLogger.info('[SYNC] ✓ Queue processing complete');
    } catch (e, st) {
      AppLogger.error('[SYNC] Unexpected error during queue processing', e, st);
    } finally {
      _isProcessing = false;
      _emit();
    }
  }

  // ── Item Processing ───────────────────────────────────────────────────────

  Future<void> _processItem(QueueItem item) async {
    AppLogger.info('[SYNC] Processing: $item');

    // Mark syncing BEFORE the network call so a crash mid-flight leaves
    // the item in 'syncing' state, which is re-queued on next launch.
    await _queueDao.updateStatus(item.id, SyncStatus.syncing);

    try {
      await _remoteApi.syncItem(item);
      await _onSuccess(item);
    } catch (e) {
      AppLogger.warning(
          '[SYNC] ✗ Attempt 1 failed for id=${item.id.substring(0, 8)}… — $e');

      if (item.retryCount < AppConstants.maxRetries) {
        await _retryWithBackoff(item);
      } else {
        // Already exhausted retries in a previous session
        await _onFailed(item, 'max retries already exhausted');
      }
    }
  }

  /// Waits for exponential backoff then retries once.
  ///
  /// Delay formula: 2^attempt seconds (e.g., attempt=1 → 2s, attempt=2 → 4s).
  Future<void> _retryWithBackoff(QueueItem item) async {
    final attempt = item.retryCount + 1;
    final delaySecs =
        pow(AppConstants.baseBackoffSeconds, attempt).toInt();
    final delay = Duration(seconds: delaySecs);

    AppLogger.info(
        '[SYNC] ↻ Retrying action ID=${item.id.substring(0, 8)}… '
        'in ${delay.inSeconds}s (attempt $attempt / ${AppConstants.maxRetries})');

    await Future.delayed(delay);

    // Persist the incremented retry count before the next attempt
    item.retryCount = attempt;
    await _queueDao.updateRetryCount(item.id, attempt);

    try {
      await _remoteApi.syncItem(item);
      await _onSuccess(item);
    } catch (e) {
      AppLogger.error(
          '[SYNC] ✗ Sync failed after retry for ID=${item.id.substring(0, 8)}… '
          '— marked failed',
          e);
      await _onFailed(item, 'retry attempt $attempt failed');
    }
  }

  // ── Result Handlers ───────────────────────────────────────────────────────

  Future<void> _onSuccess(QueueItem item) async {
    await _queueDao.remove(item.id);
    _metrics.incrementSuccess();

    // Update local sync flag so UI shows the "synced" badge
    switch (item.action) {
      case ActionType.addNote:
      case ActionType.updateNote:
        final noteId = item.payload['id'] as String? ?? item.id;
        await _notesDao.markSynced(noteId);
        break;
      case ActionType.saveItem:
      case ActionType.likeItem:
        await _savedItemsDao.markSynced(item.id);
        break;
      case ActionType.deleteNote:
        break; // nothing to update locally
    }

    AppLogger.info(
        '[SYNC] ✓ Sync success for action ID=${item.id.substring(0, 8)}… '
        '(action=${item.actionType})');
  }

  Future<void> _onFailed(QueueItem item, String reason) async {
    await _queueDao.updateStatus(item.id, SyncStatus.failed);
    _metrics.incrementFailure();
    AppLogger.error(
        '[SYNC] ✗ Sync failed after retry for ID=${item.id.substring(0, 8)}… '
        '— $reason — kept in queue for next launch');
  }

  void _emit() => _queueChangedController.add(null);

  void dispose() {
    _queueChangedController.close();
  }
}
