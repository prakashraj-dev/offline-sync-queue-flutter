import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/logger.dart';
import 'local_db/hive_service.dart';
import 'local_db/queue_local_dao.dart';
import 'state_management/providers.dart';
import 'ui/screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Step 1: Initialise Hive ─────────────────────────────────────────────
  await HiveService.init();

  // ── Step 2: On-launch queue maintenance ────────────────────────────────
  // Reset all 'failed' items to 'pending' so they are retried this session.
  // This ensures no action is permanently lost due to prior transient failures.
  final queueDao = QueueLocalDao();
  await queueDao.resetFailedToPending();

  AppLogger.info(
      '[APP] ▶ OfflineSync Notes starting — '
      'queue has ${queueDao.totalCount} item(s)');

  // ── Step 3: Launch app wrapped in ProviderScope ─────────────────────────
  runApp(const ProviderScope(child: OfflineSyncApp()));
}

class OfflineSyncApp extends StatelessWidget {
  const OfflineSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OfflineSync Notes',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
          brightness: Brightness.dark,
          surface: const Color(0xFF1A1D2E),
        ),
        scaffoldBackgroundColor: const Color(0xFF0F1117),
        appBarTheme: const AppBarTheme(elevation: 0, centerTitle: false),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      home: const _AppInitializer(),
    );
  }
}

/// Initialises Riverpod providers that have startup side-effects and
/// triggers the first background queue sync non-blockingly.
class _AppInitializer extends ConsumerStatefulWidget {
  const _AppInitializer();

  @override
  ConsumerState<_AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends ConsumerState<_AppInitializer> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  void _bootstrap() {
    // Eagerly create providers that own side-effects (connectivity watcher).
    ref.read(connectivityWatcherProvider);
    ref.read(syncProvider);

    AppLogger.info('[APP] Providers initialised — starting background sync');

    // Non-blocking background sync on launch.
    Future.microtask(
      () => ref.read(syncProvider.notifier).triggerSync(),
    );
  }

  @override
  Widget build(BuildContext context) => const HomeScreen();
}
