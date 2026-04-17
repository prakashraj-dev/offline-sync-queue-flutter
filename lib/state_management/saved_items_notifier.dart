import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/idempotency.dart';
import '../core/logger.dart';
import '../local_db/queue_local_dao.dart';
import '../local_db/saved_items_local_dao.dart';
import '../models/action_type.dart';
import '../models/queue_item.dart';
import '../models/saved_item.dart';

/// Manages the saved/liked items list with optimistic update semantics.
class SavedItemsNotifier extends StateNotifier<List<SavedItem>> {
  final SavedItemsLocalDao _savedItemsDao;
  final QueueLocalDao _queueDao;

  SavedItemsNotifier(this._savedItemsDao, this._queueDao) : super([]) {
    _load();
  }

  void _load() {
    state = _savedItemsDao.getAll();
    AppLogger.debug('[CACHE] Loaded ${state.length} saved items from local DB');
  }

  bool isNoteSaved(String noteId) => _savedItemsDao.isNoteSaved(noteId);

  /// Toggles the saved state for a note with an immediate optimistic update.
  ///
  /// Like [NotesNotifier.addNote], the new SavedItem's UUID becomes the
  /// Firestore document ID — retries are always idempotent.
  Future<void> toggleSave(String noteId) async {
    final existing = _savedItemsDao.getByNoteId(noteId);

    if (existing != null) {
      // Unsave — remove locally; no sync needed (or queue a deleteItem action)
      await _savedItemsDao.remove(existing.id);
      state = _savedItemsDao.getAll();
      AppLogger.info(
          '[OPTIMISTIC] ✓ Unsaved note noteId=${noteId.substring(0, 8)}…');
    } else {
      // Save — write locally then queue
      final id = IdempotencyService.generateKey();
      final item = SavedItem(
        id: id,
        noteId: noteId,
        savedAt: DateTime.now(),
      );

      await _savedItemsDao.save(item);
      state = _savedItemsDao.getAll();
      AppLogger.info(
          '[OPTIMISTIC] ✓ Saved note noteId=${noteId.substring(0, 8)}… '
          'savedItem id=${id.substring(0, 8)}…');

      final queueItem = QueueItem(
        id: id, // Same UUID → Firestore document ID
        actionType: ActionType.saveItem.value,
        payload: item.toJson(),
        createdAt: DateTime.now(),
      );
      await _queueDao.enqueue(queueItem);
    }
  }
}
