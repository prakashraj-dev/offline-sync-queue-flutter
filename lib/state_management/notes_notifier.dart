import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/idempotency.dart';
import '../core/logger.dart';
import '../local_db/notes_local_dao.dart';
import '../local_db/queue_local_dao.dart';
import '../models/action_type.dart';
import '../models/note.dart';
import '../models/queue_item.dart';

/// UI-facing state for the notes list.
class NotesState {
  final List<Note> notes;
  final bool isLoading;
  final String? error;

  /// True when showing cached (possibly stale) data; false when freshly synced.
  final bool isCachedData;

  const NotesState({
    this.notes = const [],
    this.isLoading = false,
    this.error,
    this.isCachedData = true,
  });

  NotesState copyWith({
    List<Note>? notes,
    bool? isLoading,
    String? error,
    bool? isCachedData,
  }) {
    return NotesState(
      notes: notes ?? this.notes,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isCachedData: isCachedData ?? this.isCachedData,
    );
  }
}

/// Manages the notes list state with local-first semantics.
///
/// Flow for [addNote]:
///   1. Generate UUID (idempotency key)
///   2. Write to Hive immediately → optimistic UI update
///   3. Enqueue a QueueItem for background sync
///   → User sees note instantly; network sync is fire-and-forget
class NotesNotifier extends StateNotifier<NotesState> {
  final NotesLocalDao _notesDao;
  final QueueLocalDao _queueDao;

  NotesNotifier(this._notesDao, this._queueDao)
      : super(const NotesState(isLoading: true)) {
    _loadFromCache();
  }

  void _loadFromCache() {
    final cached = _notesDao.getAll();
    AppLogger.info(
        '[CACHE] Loaded ${cached.length} notes from local DB (cached state)');
    state = NotesState(notes: cached, isCachedData: true);
  }

  /// Refreshes list from local Hive (called after sync updates isSynced flags).
  void refresh() => _loadFromCache();

  // ── Write Operations ──────────────────────────────────────────────────────

  /// Adds a note with an immediate optimistic UI update.
  ///
  /// The [id] is the idempotency key — it becomes the Firestore document ID.
  /// Even if this method is called twice with the same data (e.g., double-tap),
  /// the second queue item will have a different UUID → distinct Firestore doc.
  Future<void> addNote({
    required String title,
    required String content,
  }) async {
    final id = IdempotencyService.generateKey();
    final now = DateTime.now();

    final note = Note(
      id: id,
      title: title,
      content: content,
      createdAt: now,
      updatedAt: now,
    );

    // Step 1: Persist locally → instant UI update (optimistic)
    await _notesDao.save(note);
    state = state.copyWith(notes: _notesDao.getAll());
    AppLogger.info(
        '[OPTIMISTIC] ✓ Note added locally id=${id.substring(0, 8)}… '
        'title="$title"');

    // Step 2: Enqueue for background sync
    final queueItem = QueueItem(
      id: id, // Same UUID — Firestore doc ID
      actionType: ActionType.addNote.value,
      payload: note.toJson(),
      createdAt: now,
    );
    await _queueDao.enqueue(queueItem);
  }

  Future<void> updateNote(
    String id, {
    String? title,
    String? content,
  }) async {
    final existing = _notesDao.getById(id);
    if (existing == null) return;

    final now = DateTime.now();
    final updated = existing.copyWith(
      title: title,
      content: content,
      updatedAt: now,
      isSynced: false,
    );

    await _notesDao.save(updated);
    state = state.copyWith(notes: _notesDao.getAll());

    // updateNote uses a NEW UUID for the queue item, not the note ID,
    // because each update is a distinct action.
    final queueItem = QueueItem(
      id: IdempotencyService.generateKey(),
      actionType: ActionType.updateNote.value,
      payload: updated.toJson(),
      createdAt: now,
    );
    await _queueDao.enqueue(queueItem);
    AppLogger.info('[OPTIMISTIC] ✓ Note updated id=${id.substring(0, 8)}…');
  }

  Future<void> deleteNote(String id) async {
    await _notesDao.softDelete(id);
    state = state.copyWith(notes: _notesDao.getAll());

    final queueItem = QueueItem(
      id: IdempotencyService.generateKey(),
      actionType: ActionType.deleteNote.value,
      payload: {'noteId': id},
      createdAt: DateTime.now(),
    );
    await _queueDao.enqueue(queueItem);
    AppLogger.info('[OPTIMISTIC] ✓ Note soft-deleted id=${id.substring(0, 8)}…');
  }
}
