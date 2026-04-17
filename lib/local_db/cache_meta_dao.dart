import 'package:hive_flutter/hive_flutter.dart';

import '../core/constants.dart';
import '../core/logger.dart';
import 'hive_service.dart';

/// Tracks remote data cache metadata — specifically the last successful
/// sync timestamp, used to determine when a background refresh is due.
class CacheMetaDao {
  Box<String> get _box => HiveService.cacheMetaBox;

  static const _lastSyncKey = 'last_sync_timestamp';

  Future<void> setLastSyncTimestamp(DateTime time) async {
    await _box.put(_lastSyncKey, time.toIso8601String());
    AppLogger.debug(
        '[CACHE] Last sync timestamp updated → ${time.toIso8601String()}');
  }

  DateTime? getLastSyncTimestamp() {
    final value = _box.get(_lastSyncKey);
    if (value == null) return null;
    return DateTime.tryParse(value);
  }

  /// Returns true if no sync has ever occurred, or if the last sync
  /// was more than [AppConstants.cacheTTL] ago.
  bool isCacheStale() {
    final lastSync = getLastSyncTimestamp();
    if (lastSync == null) {
      AppLogger.info('[CACHE] No sync timestamp found — cache is stale');
      return true;
    }
    final age = DateTime.now().difference(lastSync);
    final isStale = age > AppConstants.cacheTTL;
    if (isStale) {
      AppLogger.info(
          '[CACHE] TTL expired — cache age: ${age.inSeconds}s, '
          'threshold: ${AppConstants.cacheTTL.inSeconds}s → triggering sync');
    }
    return isStale;
  }
}
