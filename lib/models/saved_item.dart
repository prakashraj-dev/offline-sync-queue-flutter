import 'package:hive_flutter/hive_flutter.dart';
import '../core/constants.dart';

part 'saved_item_adapter.dart';

/// Represents a user's "saved / liked" note bookmark.
///
/// Like [Note], the [id] is a UUID v4 used as the Firestore document ID
/// to ensure idempotent saves even after retries.
class SavedItem extends HiveObject {
  /// UUID v4 — also used as Firestore document ID.
  final String id;

  /// The ID of the note being saved.
  final String noteId;

  /// True once acknowledged by the remote API.
  bool isSynced;

  /// When the user saved this note.
  final DateTime savedAt;

  SavedItem({
    required this.id,
    required this.noteId,
    this.isSynced = false,
    required this.savedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'noteId': noteId,
        'isSynced': isSynced,
        'savedAt': savedAt.toIso8601String(),
      };

  @override
  String toString() =>
      'SavedItem(id=${id.substring(0, 8)}…, noteId=${noteId.substring(0, 8)}…, isSynced=$isSynced)';
}
