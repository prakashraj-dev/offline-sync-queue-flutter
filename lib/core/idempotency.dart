import 'package:uuid/uuid.dart';

/// Generates cryptographically unique idempotency keys (UUID v4).
///
/// Each generated key is used as the Firestore document ID so that
/// retries calling Firestore set() with the same doc ID are no-op merges —
/// no duplicate documents are ever created.
class IdempotencyService {
  IdempotencyService._();

  static const Uuid _uuid = Uuid();

  /// Generates a new UUID v4 idempotency key.
  static String generateKey() => _uuid.v4();

  /// Returns true if [key] matches a valid UUID format.
  static bool isValidKey(String key) {
    if (key.isEmpty) return false;
    final uuidRegex = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      caseSensitive: false,
    );
    return uuidRegex.hasMatch(key);
  }
}
