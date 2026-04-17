part of 'note.dart';

/// Manual Hive TypeAdapter for [Note].
///
/// Written manually to avoid build_runner dependency — the app is
/// fully runnable without code generation.
///
/// Field index map:
///   0 → id (String)
///   1 → title (String)
///   2 → content (String)
///   3 → createdAt (int — millisecondsSinceEpoch)
///   4 → updatedAt (int — millisecondsSinceEpoch)
///   5 → isSynced (bool)
///   6 → isDeleted (bool)
///   7 → cachedAt (int — millisecondsSinceEpoch)
class NoteAdapter extends TypeAdapter<Note> {
  @override
  final int typeId = AppConstants.noteTypeId;

  @override
  Note read(BinaryReader reader) {
    return Note(
      id: reader.readString(),
      title: reader.readString(),
      content: reader.readString(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
      isSynced: reader.readBool(),
      isDeleted: reader.readBool(),
      cachedAt: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
    );
  }

  @override
  void write(BinaryWriter writer, Note obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.title);
    writer.writeString(obj.content);
    writer.writeInt(obj.createdAt.millisecondsSinceEpoch);
    writer.writeInt(obj.updatedAt.millisecondsSinceEpoch);
    writer.writeBool(obj.isSynced);
    writer.writeBool(obj.isDeleted);
    writer.writeInt(obj.cachedAt.millisecondsSinceEpoch);
  }
}
