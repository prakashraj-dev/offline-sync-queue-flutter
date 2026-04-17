/// Application-wide constants for the offline-first sync queue system.
class AppConstants {
  AppConstants._();

  // ── Sync Queue ────────────────────────────────────────────────────────────
  /// Maximum retry attempts per queue item per process session.
  static const int maxRetries = 1;

  /// Base for exponential backoff: delay = baseBackoffSeconds ^ attempt (seconds).
  static const int baseBackoffSeconds = 2;

  // ── Cache / TTL ───────────────────────────────────────────────────────────
  /// Duration after which cached data is considered stale.
  static const Duration cacheTTL = Duration(minutes: 5);

  // ── Hive Box Names ────────────────────────────────────────────────────────
  static const String notesBox = 'notes_box';
  static const String queueBox = 'queue_box';
  static const String savedItemsBox = 'saved_items_box';
  static const String cacheMetaBox = 'cache_meta_box';

  // ── Hive Type IDs (must be unique across all adapters) ───────────────────
  static const int noteTypeId = 0;
  static const int queueItemTypeId = 1;
  static const int savedItemTypeId = 2;
}
