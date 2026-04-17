import 'package:flutter_test/flutter_test.dart';
import 'package:offline_sync_queue/core/idempotency.dart';

/// Tests proving idempotency key generation correctness and uniqueness.
void main() {
  group('IdempotencyService', () {
    // ── Uniqueness guarantee ────────────────────────────────────────────────
    test('generates unique keys across 10,000 iterations', () {
      final keys = List.generate(
        10000,
        (_) => IdempotencyService.generateKey(),
      );
      final uniqueKeys = keys.toSet();
      expect(
        uniqueKeys.length,
        equals(10000),
        reason: 'Every generated key must be globally unique',
      );
    });

    // ── Format validation ───────────────────────────────────────────────────
    test('generated key matches UUID v4 format', () {
      // UUID v4: xxxxxxxx-xxxx-4xxx-[89ab]xxx-xxxxxxxxxxxx
      final uuidV4Regex = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        caseSensitive: false,
      );

      for (var i = 0; i < 100; i++) {
        final key = IdempotencyService.generateKey();
        expect(
          uuidV4Regex.hasMatch(key),
          isTrue,
          reason: 'Key "$key" does not match UUID v4 pattern',
        );
      }
    });

    // ── isValidKey ─────────────────────────────────────────────────────────
    test('isValidKey returns true for a freshly generated key', () {
      final key = IdempotencyService.generateKey();
      expect(IdempotencyService.isValidKey(key), isTrue);
    });

    test('isValidKey returns false for an empty string', () {
      expect(IdempotencyService.isValidKey(''), isFalse);
    });

    test('isValidKey returns false for a non-UUID string', () {
      expect(IdempotencyService.isValidKey('not-a-uuid'), isFalse);
      expect(IdempotencyService.isValidKey('12345'), isFalse);
      expect(IdempotencyService.isValidKey('xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'), isFalse);
    });

    test('isValidKey returns false for UUID v1 (version bit != 4)', () {
      // A v1-like UUID with version bit '1' — should fail v4 check
      const v1Like = '550e8400-e29b-11d4-a716-446655440000';
      expect(IdempotencyService.isValidKey(v1Like), isFalse);
    });

    // ── Key length ─────────────────────────────────────────────────────────
    test('each generated key has exactly 36 characters', () {
      for (var i = 0; i < 50; i++) {
        final key = IdempotencyService.generateKey();
        expect(key.length, equals(36),
            reason: 'UUID should be 36 chars: 32 hex + 4 hyphens');
      }
    });
  });
}
