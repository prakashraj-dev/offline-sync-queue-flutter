part of 'queue_item.dart';

/// Manual Hive TypeAdapter for [QueueItem].
///
/// Field index map:
///   0 → id (String)
///   1 → actionType (String)
///   2 → payloadJson (String — JSON encoded Map)
///   3 → retryCount (int)
///   4 → createdAt (int — millisecondsSinceEpoch)
///   5 → status (String)
class QueueItemAdapter extends TypeAdapter<QueueItem> {
  @override
  final int typeId = AppConstants.queueItemTypeId;

  @override
  QueueItem read(BinaryReader reader) {
    return QueueItem.raw(
      id: reader.readString(),
      actionType: reader.readString(),
      payloadJson: reader.readString(),
      retryCount: reader.readInt(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
      status: reader.readString(),
    );
  }

  @override
  void write(BinaryWriter writer, QueueItem obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.actionType);
    writer.writeString(obj.payloadJson);
    writer.writeInt(obj.retryCount);
    writer.writeInt(obj.createdAt.millisecondsSinceEpoch);
    writer.writeString(obj.status);
  }
}
