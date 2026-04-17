import 'package:hive_flutter/hive_flutter.dart';
import '../core/constants.dart';
import '../core/logger.dart';
import '../models/note.dart';
import '../models/queue_item.dart';
import '../models/saved_item.dart';

/// Responsible for initialising Hive and providing typed box access.
///
/// Call [init] once in [main] before [runApp]. All subsequent box access
/// is synchronous via the static getters since boxes are opened eagerly.
class HiveService {
  HiveService._();

  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    await Hive.initFlutter();

    // Register manually written TypeAdapters (no build_runner required).
    if (!Hive.isAdapterRegistered(AppConstants.noteTypeId)) {
      Hive.registerAdapter(NoteAdapter());
    }
    if (!Hive.isAdapterRegistered(AppConstants.queueItemTypeId)) {
      Hive.registerAdapter(QueueItemAdapter());
    }
    if (!Hive.isAdapterRegistered(AppConstants.savedItemTypeId)) {
      Hive.registerAdapter(SavedItemAdapter());
    }

    // Open all boxes eagerly — subsequent access is O(1) synchronous reads.
    await Hive.openBox<Note>(AppConstants.notesBox);
    await Hive.openBox<QueueItem>(AppConstants.queueBox);
    await Hive.openBox<SavedItem>(AppConstants.savedItemsBox);
    await Hive.openBox<String>(AppConstants.cacheMetaBox);

    _initialized = true;
    AppLogger.info('[HIVE] All boxes initialised successfully');
  }

  static Box<Note> get notesBox => Hive.box<Note>(AppConstants.notesBox);
  static Box<QueueItem> get queueBox =>
      Hive.box<QueueItem>(AppConstants.queueBox);
  static Box<SavedItem> get savedItemsBox =>
      Hive.box<SavedItem>(AppConstants.savedItemsBox);
  static Box<String> get cacheMetaBox =>
      Hive.box<String>(AppConstants.cacheMetaBox);
}
