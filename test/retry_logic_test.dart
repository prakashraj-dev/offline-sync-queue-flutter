import 'package:flutter_test/flutter_test.dart';
import 'package:offline_sync_queue/models/action_type.dart';
import 'package:offline_sync_queue/models/queue_item.dart';
import 'package:offline_sync_queue/remote_api/mock_firestore_service.dart';

/// Tests verifying retry behaviour:
/// - Item succeeds after exactly 1 failure
/// - Offline simulation throws the right exception type
/// - retryCount in QueueItem correctly tracks attempts
void main() {
  group('Retry Logic', () {
    late MockFirestoreService service;

    setUp(() => service = MockFirestoreService());

    // ── Test 1: Success after 1 failure ────────────────────────────────────
    test('item succeeds after 1 simulated server failure', () async {
      service.simulateFailures(1);

      final item = QueueItem(
        id: 'retry-item-001',
        actionType: ActionType.addNote.value,
        payload: {'id': 'retry-item-001', 'title': 'Retry Test', 'content': ''},
        createdAt: DateTime.now(),
      );

      // Attempt 1: should fail
      bool attempt1Failed = false;
      try {
        await service.syncItem(item);
      } catch (e) {
        attempt1Failed = true;
        expect(e.toString(), contains('ServerException'),
            reason: 'Should throw a ServerException on simulated failure');
      }
      expect(attempt1Failed, isTrue, reason: 'First attempt must fail');
      expect(service.syncedNotesCount, equals(0));

      // Attempt 2 (retry): should succeed
      await service.syncItem(item);
      expect(service.syncedNotesCount, equals(1),
          reason: 'Second attempt should succeed after failure counter exhausted');
      expect(service.wasProcessed('retry-item-001'), isTrue);
    });

    // ── Test 2: Offline simulation ─────────────────────────────────────────
    test('offline simulation throws NetworkException and blocks all writes',
        () async {
      service.simulateOffline = true;

      final item = QueueItem(
        id: 'offline-item-001',
        actionType: ActionType.addNote.value,
        payload: {'id': 'offline-item-001', 'title': 'Offline Note', 'content': ''},
        createdAt: DateTime.now(),
      );

      bool threw = false;
      try {
        await service.syncItem(item);
      } catch (e) {
        threw = true;
        expect(e.toString(), contains('NetworkException'));
      }

      expect(threw, isTrue, reason: 'Simulated offline must throw');
      expect(service.syncedNotesCount, equals(0),
          reason: 'No document should be written while offline');
      expect(service.wasProcessed('offline-item-001'), isFalse);
    });

    // ── Test 3: Multiple failures exhaust simulation counter ───────────────
    test('simulateFailures(n) allows success on attempt n+1', () async {
      service.simulateFailures(3);

      final item = QueueItem(
        id: 'multi-fail-001',
        actionType: ActionType.addNote.value,
        payload: {'id': 'multi-fail-001', 'title': 'Multi Fail', 'content': ''},
        createdAt: DateTime.now(),
      );

      // Attempts 1-3: all fail
      for (var attempt = 1; attempt <= 3; attempt++) {
        bool failed = false;
        try {
          await service.syncItem(item);
        } catch (_) {
          failed = true;
        }
        expect(failed, isTrue,
            reason: 'Attempt $attempt should fail (simulated)');
        expect(service.syncedNotesCount, equals(0));
      }

      // Attempt 4: succeeds
      await service.syncItem(item);
      expect(service.syncedNotesCount, equals(1),
          reason: 'Attempt 4 should succeed after failures exhausted');
    });

    // ── Test 4: QueueItem retryCount tracks attempts ────────────────────────
    test('retryCount on QueueItem starts at 0 and reflects manual increments',
        () {
      final item = QueueItem(
        id: 'retry-count-test',
        actionType: ActionType.addNote.value,
        payload: {'id': 'retry-count-test', 'title': 'RC Test', 'content': ''},
        createdAt: DateTime.now(),
      );

      expect(item.retryCount, equals(0));

      item.retryCount = 1;
      expect(item.retryCount, equals(1));

      item.retryCount = 2;
      expect(item.retryCount, equals(2));
    });

    // ── Test 5: Reset clears simulation state ──────────────────────────────
    test('calling reset() clears all simulation flags', () async {
      service.simulateOffline = true;
      service.simulateFailures(5);
      service.reset();

      final item = QueueItem(
        id: 'after-reset-001',
        actionType: ActionType.addNote.value,
        payload: {'id': 'after-reset-001', 'title': 'Post Reset', 'content': ''},
        createdAt: DateTime.now(),
      );

      // Should succeed immediately after reset
      await service.syncItem(item);
      expect(service.syncedNotesCount, equals(1),
          reason: 'After reset, sync should succeed without errors');
    });
  });
}
