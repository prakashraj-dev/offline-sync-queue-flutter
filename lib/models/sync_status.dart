/// Represents the synchronisation lifecycle status of a single queue item.
enum SyncStatus {
  /// Waiting to be processed.
  pending,

  /// Currently being sent to the remote API.
  syncing,

  /// All retry attempts exhausted. Item kept for next-launch retry.
  failed,

  /// Successfully synced and removed from queue.
  succeeded;

  String get value => name;

  static SyncStatus fromString(String value) {
    return SyncStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => SyncStatus.pending,
    );
  }
}
