import '../core/logger.dart';
import '../models/action_type.dart';
import '../models/queue_item.dart';
import 'remote_api.dart';

/// Fully self-contained mock implementation of [RemoteApi].
///
/// Simulates Firebase Firestore behaviour, including:
/// - Configurable offline mode ([simulateOffline])
/// - Configurable successive failure injection ([simulateFailures])
/// - In-memory idempotency tracking ([_processedIds])
/// - Realistic network round-trip delay
///
/// The in-memory [_processedIds] set proves idempotency:
///   Calling syncItem() twice with the same UUID only writes one document.
class MockFirestoreService implements RemoteApi {
  // ── In-Memory "Firestore" Collections ────────────────────────────────────
  final Map<String, Map<String, dynamic>> _notesCollection = {};
  final Map<String, Map<String, dynamic>> _savedItemsCollection = {};

  /// Tracks processed document IDs — a second call with the same ID is a no-op.
  final Set<String> _processedIds = {};

  // ── Simulation Controls ───────────────────────────────────────────────────

  /// When true, every syncItem call throws a NetworkException.
  bool simulateOffline = false;

  int _failNextNRequests = 0;

  /// Make the next [n] syncItem calls throw a ServerException.
  void simulateFailures(int n) {
    _failNextNRequests = n;
    AppLogger.warning(
        '[MOCK] 🔴 Failure simulation armed: next $n request(s) will fail');
  }

  /// Resets all simulation flags.
  void reset() {
    simulateOffline = false;
    _failNextNRequests = 0;
  }

  // ── RemoteApi Implementation ──────────────────────────────────────────────

  @override
  Future<void> syncItem(QueueItem item) async {
    // Simulate network round-trip latency
    await Future.delayed(const Duration(milliseconds: 600));

    if (simulateOffline) {
      AppLogger.warning(
          '[MOCK] 📵 simulateOffline=true — throwing NetworkException for id=${item.id.substring(0, 8)}…');
      throw Exception('NetworkException: No internet connection (simulated)');
    }

    if (_failNextNRequests > 0) {
      _failNextNRequests--;
      AppLogger.warning(
          '[MOCK] 💥 Simulating server failure for id=${item.id.substring(0, 8)}… '
          '(${_failNextNRequests} failure(s) still queued)');
      throw Exception(
          'ServerException: Internal server error 500 (simulated). '
          'Remaining armed failures: $_failNextNRequests');
    }

    // ── Idempotency Guard ─────────────────────────────────────────────────
    // This mirrors what Firestore set() with a known doc ID does:
    // the second call overwrites, but the net result is identical.
    if (_processedIds.contains(item.id)) {
      AppLogger.warning(
          '[MOCK] ⚠ Duplicate detected for id=${item.id.substring(0, 8)}… '
          '— idempotency enforced, skipping write (no duplicate created)');
      return;
    }

    // ── Route by Action Type ──────────────────────────────────────────────
    switch (item.action) {
      case ActionType.addNote:
      case ActionType.updateNote:
        _notesCollection[item.id] = {
          ...item.payload,
          'docId': item.id,
          'syncedAt': DateTime.now().toIso8601String(),
        };
        AppLogger.info(
            '[MOCK] ✓ Firestore: notes/${item.id.substring(0, 8)}… written '
            '(action=${item.actionType})');
        break;

      case ActionType.deleteNote:
        final noteId = item.payload['noteId'] as String? ?? item.id;
        _notesCollection.remove(noteId);
        AppLogger.info(
            '[MOCK] ✓ Firestore: notes/$noteId deleted (action=deleteNote)');
        break;

      case ActionType.likeItem:
      case ActionType.saveItem:
        _savedItemsCollection[item.id] = {
          ...item.payload,
          'docId': item.id,
          'syncedAt': DateTime.now().toIso8601String(),
        };
        AppLogger.info(
            '[MOCK] ✓ Firestore: saved_items/${item.id.substring(0, 8)}… written '
            '(action=${item.actionType})');
        break;
    }

    _processedIds.add(item.id);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchNotes() async {
    await Future.delayed(const Duration(milliseconds: 400));
    if (simulateOffline) {
      throw Exception('NetworkException: No internet connection (simulated)');
    }
    AppLogger.info(
        '[MOCK] Fetched ${_notesCollection.length} notes from Firestore');
    return _notesCollection.values.toList();
  }

  @override
  Future<List<Map<String, dynamic>>> fetchSavedItems() async {
    await Future.delayed(const Duration(milliseconds: 400));
    if (simulateOffline) {
      throw Exception('NetworkException: No internet connection (simulated)');
    }
    AppLogger.info(
        '[MOCK] Fetched ${_savedItemsCollection.length} saved items from Firestore');
    return _savedItemsCollection.values.toList();
  }

  // ── Test / Debug Helpers ──────────────────────────────────────────────────

  int get syncedNotesCount => _notesCollection.length;
  int get syncedSavedItemsCount => _savedItemsCollection.length;
  int get processedIdsCount => _processedIds.length;
  bool wasProcessed(String id) => _processedIds.contains(id);
}
