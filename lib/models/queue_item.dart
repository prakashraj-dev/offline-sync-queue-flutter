import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../core/constants.dart';
import 'action_type.dart';
import 'sync_status.dart';

part 'queue_item_adapter.dart';

/// A single entry in the offline sync queue.
///
/// Key design decisions:
/// - [id] is a UUID v4 that is also used as the Firestore document ID.
///   This is the cornerstone of idempotency: Firestore set() with an
///   existing doc ID is a no-op merge — retries never create duplicates.
/// - [payloadJson] stores action data as a JSON string because Hive
///   cannot natively serialize Map<String, dynamic> without a custom adapter.
/// - [retryCount] is persisted so the retry budget survives app restarts.
class QueueItem extends HiveObject {
  /// UUID v4 — also used as the Firestore document ID for idempotency.
  final String id;

  /// Action type serialised as its enum name (e.g., 'addNote').
  final String actionType;

  /// JSON-encoded payload. Access via [payload] getter.
  final String payloadJson;

  /// Number of sync attempts made. Incremented before each retry.
  int retryCount;

  /// When this item was first enqueued (UTC). Determines FIFO processing order.
  final DateTime createdAt;

  /// Lifecycle status: pending | syncing | failed | succeeded.
  String status;

  QueueItem({
    required this.id,
    required this.actionType,
    required Map<String, dynamic> payload,
    this.retryCount = 0,
    required this.createdAt,
    String? status,
  })  : payloadJson = jsonEncode(payload),
        status = status ?? SyncStatus.pending.value;

  /// Private constructor used by the Hive adapter (reads raw JSON string).
  QueueItem.raw({
    required this.id,
    required this.actionType,
    required this.payloadJson,
    required this.retryCount,
    required this.createdAt,
    required this.status,
  });

  /// Deserialised payload map.
  Map<String, dynamic> get payload =>
      Map<String, dynamic>.from(jsonDecode(payloadJson) as Map);

  ActionType get action => ActionType.fromString(actionType);
  SyncStatus get syncStatus => SyncStatus.fromString(status);

  @override
  String toString() =>
      'QueueItem(id=${id.substring(0, 8)}…, action=$actionType, status=$status, retries=$retryCount)';
}
