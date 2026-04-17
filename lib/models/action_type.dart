/// Represents the type of action stored in the sync queue.
enum ActionType {
  addNote,
  updateNote,
  deleteNote,
  likeItem,
  saveItem;

  String get value => name;

  static ActionType fromString(String value) {
    return ActionType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => throw ArgumentError('Unknown ActionType: $value'),
    );
  }
}
