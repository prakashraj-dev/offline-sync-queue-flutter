import 'package:flutter_test/flutter_test.dart';
import 'package:offline_sync_queue/models/action_type.dart';
import 'package:offline_sync_queue/models/queue_item.dart';
import 'package:offline_sync_queue/remote_api/mock_firestore_service.dart';

/// Tests that prove the idempotency guarantee:
/// Sending the same queue item multiple times never creates duplicate documents.
void main() {
  group('MockFirestoreService — Idempotency / Deduplication', () {
    late MockFirestoreService service;

    setUp(() => service = MockFirestoreService());

    // ── Test 1: Same item synced twice → only one document ─────────────────
    test('syncing the same item twice creates exactly one Firestore document',
        () async {
      final item = QueueItem(
        id: 'idempotency-uuid-1234',
        actionType: ActionType.addNote.value,
        payload: {
          'id': 'idempotency-uuid-1234',
          'title': 'Test Note',
          'content': 'Body text',
          'createdAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
          'isSynced': false,
          'isDeleted': false,
        },
        createdAt: DateTime.now(),
      );

      // First sync — should write document
      await service.syncItem(item);
      expect(service.syncedNotesCount, equals(1), reason: 'First sync writes 1 document');
      expect(service.processedIdsCount, equals(1));

      // Second sync (retry simulation) — should be a no-op
      await service.syncItem(item);
      expect(service.syncedNotesCount, equals(1),
          reason: 'Retry must NOT create a duplicate — idempotency enforced');
      expect(service.processedIdsCount, equals(1),
          reason: 'Processed IDs set must still contain exactly 1 entry');
    });

    // ── Test 2: Two different items → two documents ─────────────────────────
    test('two items with different UUIDs each create their own document',
        () async {
      final item1 = QueueItem(
        id: 'uuid-aaa-111',
        actionType: ActionType.addNote.value,
        payload: {'id': 'uuid-aaa-111', 'title': 'Note A', 'content': ''},
        createdAt: DateTime.now(),
      );
      final item2 = QueueItem(
        id: 'uuid-bbb-222',
        actionType: ActionType.addNote.value,
        payload: {'id': 'uuid-bbb-222', 'title': 'Note B', 'content': ''},
        createdAt: DateTime.now(),
      );

      await service.syncItem(item1);
      await service.syncItem(item2);

      expect(service.syncedNotesCount, equals(2));
      expect(service.processedIdsCount, equals(2));
      expect(service.wasProcessed('uuid-aaa-111'), isTrue);
      expect(service.wasProcessed('uuid-bbb-222'), isTrue);
    });

    // ── Test 3: Retry after failure still deduplicates ──────────────────────
    test('item successfully synced after failure is still idempotent on retry',
        () async {
      service.simulateFailures(1);

      final item = QueueItem(
        id: 'retry-idempotency-uuid-567',
        actionType: ActionType.addNote.value,
        payload: {
          'id': 'retry-idempotency-uuid-567',
          'title': 'Retry Note',
          'content': 'Test'
        },
        createdAt: DateTime.now(),
      );

      // Attempt 1: fails
      bool firstFailed = false;
      try {
        await service.syncItem(item);
      } catch (_) {
        firstFailed = true;
      }
      expect(firstFailed, isTrue, reason: 'First attempt should have failed');
      expect(service.syncedNotesCount, equals(0),
          reason: 'No document written on failure');

      // Attempt 2 (retry): succeeds
      await service.syncItem(item);
      expect(service.syncedNotesCount, equals(1));
      expect(service.wasProcessed('retry-idempotency-uuid-567'), isTrue);

      // Attempt 3 (duplicate retry): no-op
      await service.syncItem(item);
      expect(service.syncedNotesCount, equals(1),
          reason: 'Third call must not create a duplicate');
    });

    // ── Test 4: saveItem idempotency ────────────────────────────────────────
    test('saveItem is idempotent across multiple retries', () async {
      final item = QueueItem(
        id: 'save-uuid-789',
        actionType: ActionType.saveItem.value,
        payload: {
          'id': 'save-uuid-789',
          'noteId': 'note-uuid-abc',
          'savedAt': DateTime.now().toIso8601String(),
        },
        createdAt: DateTime.now(),
      );

      await service.syncItem(item);
      await service.syncItem(item);
      await service.syncItem(item);

      expect(service.syncedSavedItemsCount, equals(1),
          reason: 'Three calls should produce exactly one saved item');
    });
  });
}
