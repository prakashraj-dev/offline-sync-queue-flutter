import 'package:hive_flutter/hive_flutter.dart';

import '../core/logger.dart';
import '../models/note.dart';
import 'hive_service.dart';

/// Data Access Object for [Note] objects stored in Hive.
class NotesLocalDao {
  Box<Note> get _box => HiveService.notesBox;

  /// Persists or overwrites a note keyed by its UUID [id].
  Future<void> save(Note note) async {
    await _box.put(note.id, note);
    AppLogger.debug('[LOCAL_DB] Saved note id=${note.id}');
  }

  /// Returns all non-deleted notes sorted by updatedAt descending.
  List<Note> getAll() {
    final notes = _box.values
        .where((n) => !n.isDeleted)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    AppLogger.debug(
        '[CACHE] Loaded ${notes.length} notes from local DB (age: ${_cacheAgeLabel()})');
    return notes;
  }

  Note? getById(String id) => _box.get(id);

  /// Marks a note as synced and refreshes its cachedAt timestamp.
  Future<void> markSynced(String id) async {
    final note = _box.get(id);
    if (note != null) {
      note.isSynced = true;
      note.cachedAt = DateTime.now();
      await note.save(); // HiveObject.save() updates in place
    }
  }

  Future<void> markUnsynced(String id) async {
    final note = _box.get(id);
    if (note != null) {
      note.isSynced = false;
      await note.save();
    }
  }

  /// Soft-deletes a note — hidden from UI, kept until sync confirms deletion.
  Future<void> softDelete(String id) async {
    final note = _box.get(id);
    if (note != null) {
      note.isDeleted = true;
      note.isSynced = false;
      await note.save();
    }
  }

  /// Returns true if any cached note has exceeded [AppConstants.cacheTTL].
  bool hasStaleCachedData() => _box.values.any((n) => n.isCacheExpired);

  String _cacheAgeLabel() {
    if (_box.isEmpty) return 'empty';
    final oldest = _box.values
        .map((n) => DateTime.now().difference(n.cachedAt).inSeconds)
        .reduce((a, b) => a > b ? a : b);
    return '${oldest}s';
  }
}
