part of 'saved_item.dart';

/// Manual Hive TypeAdapter for [SavedItem].
///
/// Field index map:
///   0 → id (String)
///   1 → noteId (String)
///   2 → isSynced (bool)
///   3 → savedAt (int — millisecondsSinceEpoch)
class SavedItemAdapter extends TypeAdapter<SavedItem> {
  @override
  final int typeId = AppConstants.savedItemTypeId;

  @override
  SavedItem read(BinaryReader reader) {
    return SavedItem(
      id: reader.readString(),
      noteId: reader.readString(),
      isSynced: reader.readBool(),
      savedAt: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
    );
  }

  @override
  void write(BinaryWriter writer, SavedItem obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.noteId);
    writer.writeBool(obj.isSynced);
    writer.writeInt(obj.savedAt.millisecondsSinceEpoch);
  }
}
