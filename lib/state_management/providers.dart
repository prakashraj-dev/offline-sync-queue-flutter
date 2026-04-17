import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../local_db/cache_meta_dao.dart';
import '../local_db/notes_local_dao.dart';
import '../local_db/queue_local_dao.dart';
import '../local_db/saved_items_local_dao.dart';
import '../models/saved_item.dart';
import '../remote_api/mock_firestore_service.dart';
import '../remote_api/remote_api.dart';
import '../sync_queue/connectivity_watcher.dart';
import '../sync_queue/queue_metrics.dart';
import '../sync_queue/sync_queue_manager.dart';
import 'notes_notifier.dart';
import 'queue_notifier.dart';
import 'saved_items_notifier.dart';
import 'sync_notifier.dart';

// ── DAOs ──────────────────────────────────────────────────────────────────────

final notesLocalDaoProvider = Provider<NotesLocalDao>(
  (_) => NotesLocalDao(),
);

final queueLocalDaoProvider = Provider<QueueLocalDao>(
  (_) => QueueLocalDao(),
);

final savedItemsLocalDaoProvider = Provider<SavedItemsLocalDao>(
  (_) => SavedItemsLocalDao(),
);

final cacheMetaDaoProvider = Provider<CacheMetaDao>(
  (_) => CacheMetaDao(),
);

// ── Remote API ─────────────────────────────────────────────────────────────

/// Singleton mock service. To use real Firestore, replace [RemoteApi]
/// implementation here without touching any other provider.
final mockFirestoreProvider = Provider<MockFirestoreService>(
  (_) => MockFirestoreService(),
);

final remoteApiProvider = Provider<RemoteApi>((ref) {
  return ref.watch(mockFirestoreProvider);
});

// ── Metrics ────────────────────────────────────────────────────────────────

final queueMetricsProvider = Provider<QueueMetrics>(
  (_) => QueueMetrics(),
);

// ── Sync Queue Manager ─────────────────────────────────────────────────────

final syncQueueManagerProvider = Provider<SyncQueueManager>((ref) {
  final manager = SyncQueueManager(
    queueDao: ref.watch(queueLocalDaoProvider),
    notesDao: ref.watch(notesLocalDaoProvider),
    savedItemsDao: ref.watch(savedItemsLocalDaoProvider),
    cacheMetaDao: ref.watch(cacheMetaDaoProvider),
    remoteApi: ref.watch(remoteApiProvider),
    metrics: ref.watch(queueMetricsProvider),
  );
  ref.onDispose(manager.dispose);
  return manager;
});

// ── Connectivity Watcher ───────────────────────────────────────────────────

final connectivityWatcherProvider = Provider<ConnectivityWatcher>((ref) {
  final watcher = ConnectivityWatcher(ref.watch(syncQueueManagerProvider));
  watcher.start();
  ref.onDispose(watcher.stop);
  return watcher;
});

// ── State Notifiers ────────────────────────────────────────────────────────

final notesProvider =
    StateNotifierProvider<NotesNotifier, NotesState>((ref) {
  return NotesNotifier(
    ref.watch(notesLocalDaoProvider),
    ref.watch(queueLocalDaoProvider),
  );
});

final queueProvider =
    StateNotifierProvider<QueueNotifier, QueueState>((ref) {
  return QueueNotifier(
    ref.watch(queueLocalDaoProvider),
    ref.watch(queueMetricsProvider),
    ref.watch(syncQueueManagerProvider),
  );
});

final savedItemsProvider =
    StateNotifierProvider<SavedItemsNotifier, List<SavedItem>>((ref) {
  return SavedItemsNotifier(
    ref.watch(savedItemsLocalDaoProvider),
    ref.watch(queueLocalDaoProvider),
  );
});

final syncProvider =
    StateNotifierProvider<SyncNotifier, SyncState>((ref) {
  return SyncNotifier(
    ref.watch(syncQueueManagerProvider),
    ref.watch(connectivityWatcherProvider),
  );
});
