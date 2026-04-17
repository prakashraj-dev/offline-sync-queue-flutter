import '../models/queue_item.dart';

/// Abstract contract for the remote synchronisation backend.
///
/// The production implementation uses Firebase Firestore.
/// The bundled [MockFirestoreService] is fully self-contained and allows
/// offline simulation and failure injection without any Firebase setup.
///
/// To switch to real Firebase:
///   1. Add firebase_core and cloud_firestore to pubspec.yaml
///   2. Run `flutterfire configure`
///   3. Create a FirestoreService implementing this interface
///   4. Swap the provider in providers.dart
abstract class RemoteApi {
  /// Syncs a single queue item to the remote backend using its UUID as
  /// the document ID (idempotency key). Throws on any failure.
  Future<void> syncItem(QueueItem item);

  /// Fetches the latest notes from the remote collection.
  Future<List<Map<String, dynamic>>> fetchNotes();

  /// Fetches the latest saved items from the remote collection.
  Future<List<Map<String, dynamic>>> fetchSavedItems();
}
