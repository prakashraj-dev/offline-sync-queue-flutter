import 'package:hive_flutter/hive_flutter.dart';
import '../core/constants.dart';

part 'note_adapter.dart';

/// Local-first note model.
///
/// [id] is a UUID v4 that doubles as the Firestore document ID —
/// this is the linchpin of idempotent sync.
class Note extends HiveObject {
  String id;
  String title;
  String content;
  DateTime createdAt;

  /// Last user modification time (UTC). Used for Last-Write-Wins conflict resolution.
  DateTime updatedAt;

  /// True once the remote API has acknowledged this write.
  bool isSynced;

  /// Soft-delete flag — item is hidden from UI but kept until sync confirms deletion.
  bool isDeleted;

  /// When this record was last written (locally or from remote). Used for TTL checks.
  DateTime cachedAt;

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.isSynced = false,
    this.isDeleted = false,
    DateTime? cachedAt,
  }) : cachedAt = cachedAt ?? DateTime.now();

  /// Returns true if the cache age exceeds [AppConstants.cacheTTL].
  bool get isCacheExpired =>
      DateTime.now().difference(cachedAt) > AppConstants.cacheTTL;

  Note copyWith({
    String? title,
    String? content,
    DateTime? updatedAt,
    bool? isSynced,
    bool? isDeleted,
    DateTime? cachedAt,
  }) {
    return Note(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
      isDeleted: isDeleted ?? this.isDeleted,
      cachedAt: cachedAt ?? this.cachedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'isSynced': isSynced,
        'isDeleted': isDeleted,
      };

  @override
  String toString() =>
      'Note(id=$id, title="$title", isSynced=$isSynced, isDeleted=$isDeleted)';
}
