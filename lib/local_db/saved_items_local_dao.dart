import 'package:hive_flutter/hive_flutter.dart';

import '../core/logger.dart';
import '../models/saved_item.dart';
import 'hive_service.dart';

/// Data Access Object for [SavedItem] objects stored in Hive.
class SavedItemsLocalDao {
  Box<SavedItem> get _box => HiveService.savedItemsBox;

  Future<void> save(SavedItem item) async {
    await _box.put(item.id, item);
    AppLogger.debug(
        '[LOCAL_DB] Saved item id=${item.id.substring(0, 8)}… for noteId=${item.noteId.substring(0, 8)}…');
  }

  List<SavedItem> getAll() => _box.values.toList();

  bool isNoteSaved(String noteId) =>
      _box.values.any((s) => s.noteId == noteId);

  SavedItem? getByNoteId(String noteId) {
    final matches = _box.values.where((s) => s.noteId == noteId).toList();
    return matches.isEmpty ? null : matches.first;
  }

  Future<void> markSynced(String id) async {
    final item = _box.get(id);
    if (item != null) {
      item.isSynced = true;
      await item.save();
    }
  }

  Future<void> remove(String id) async {
    await _box.delete(id);
    AppLogger.debug('[LOCAL_DB] Removed saved item id=${id.substring(0, 8)}…');
  }
}
