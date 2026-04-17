import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/note.dart';
import '../../models/saved_item.dart';
import '../../state_management/notes_notifier.dart';
import '../../state_management/providers.dart';
import '../../state_management/sync_notifier.dart';
import '../widgets/note_card.dart';
import '../widgets/queue_inspector_sheet.dart';
import '../widgets/sync_status_bar.dart';
import 'add_note_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesState = ref.watch(notesProvider);
    final syncState = ref.watch(syncProvider);
    final queueState = ref.watch(queueProvider);
    final savedItems = ref.watch(savedItemsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1D2E),
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF3D35C3)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.cloud_sync, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            const Text(
              'OfflineSync',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 20,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        actions: [
          // ── Connectivity Chip ──────────────────────────────────────────
          _ConnectivityChip(isOnline: syncState.isOnline),

          // ── Manual Sync Button ─────────────────────────────────────────
          IconButton(
            tooltip: 'Sync Now',
            icon: syncState.isSyncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.sync_rounded, color: Colors.white70),
            onPressed: syncState.isSyncing
                ? null
                : () => ref.read(syncProvider.notifier).triggerSync(),
          ),

          // ── Queue Inspector Badge ──────────────────────────────────────
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                tooltip: 'Queue Inspector',
                icon: const Icon(Icons.layers_outlined, color: Colors.white70),
                onPressed: () => _openQueueInspector(context),
              ),
              if (queueState.pendingCount > 0)
                Positioned(
                  right: 8,
                  top: 10,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF6B6B),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${queueState.pendingCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),

          // ── Simulation Menu ────────────────────────────────────────────
          PopupMenuButton<String>(
            tooltip: 'Test Controls',
            icon: const Icon(Icons.science_outlined, color: Colors.white70),
            color: const Color(0xFF252840),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (value) => _handleMenuAction(context, ref, value),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'toggle_offline',
                child: Row(
                  children: [
                    Icon(
                      syncState.isOnline ? Icons.wifi_off : Icons.wifi,
                      color: syncState.isOnline
                          ? Colors.redAccent
                          : Colors.greenAccent,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      syncState.isOnline
                          ? '📵  Simulate Offline'
                          : '🟢  Go Back Online',
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'simulate_failure',
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Colors.orangeAccent, size: 18),
                    SizedBox(width: 10),
                    Text(
                      '💥  Simulate 2 Server Failures',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'force_sync',
                child: Row(
                  children: [
                    Icon(Icons.bolt, color: Color(0xFF6C63FF), size: 18),
                    SizedBox(width: 10),
                    Text(
                      '⚡  Force Sync Now',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // ── Offline Banner ─────────────────────────────────────────────
          AnimatedCrossFade(
            firstChild: _OfflineBanner(),
            secondChild: const SizedBox.shrink(),
            crossFadeState: !syncState.isOnline
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 300),
          ),

          // ── Sync Status Bar ────────────────────────────────────────────
          const SyncStatusBar(),

          // ── Notes List ────────────────────────────────────────────────
          Expanded(
            child: notesState.isLoading
                ? const _LoadingView()
                : notesState.notes.isEmpty
                    ? const _EmptyState()
                    : _NotesList(
                        notes: notesState.notes,
                        savedItems: savedItems,
                      ),
          ),
        ],
      ),

      // ── FAB ───────────────────────────────────────────────────────────
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_note_fab',
        onPressed: () => _navigateToAddNote(context),
        backgroundColor: const Color(0xFF6C63FF),
        elevation: 8,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'New Note',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }

  void _navigateToAddNote(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddNoteScreen()),
    );
  }

  void _openQueueInspector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const QueueInspectorSheet(),
    );
  }

  void _handleMenuAction(BuildContext context, WidgetRef ref, String value) {
    final mockFirestore = ref.read(mockFirestoreProvider);
    final syncNotifier = ref.read(syncProvider.notifier);
    final syncState = ref.read(syncProvider);

    switch (value) {
      case 'toggle_offline':
        final goOffline = syncState.isOnline;
        mockFirestore.simulateOffline = goOffline;
        syncNotifier.setOnlineStatus(!goOffline);
        _showSnackBar(
          context,
          goOffline
              ? '📵 Simulating OFFLINE — writes queue locally'
              : '🟢 Back ONLINE — triggering sync…',
          goOffline ? const Color(0xFFEF5350) : const Color(0xFF66BB6A),
        );
        if (!goOffline) {
          // Re-enable → trigger immediate sync
          Future.delayed(const Duration(milliseconds: 200), () {
            ref.read(syncProvider.notifier).triggerSync();
          });
        }
        break;

      case 'simulate_failure':
        mockFirestore.simulateFailures(2);
        _showSnackBar(
          context,
          '💥 Next 2 syncs will FAIL — watch retry logs',
          Colors.deepOrange,
        );
        break;

      case 'force_sync':
        syncNotifier.triggerSync();
        _showSnackBar(context, '⚡ Force sync triggered', const Color(0xFF6C63FF));
        break;
    }
  }

  void _showSnackBar(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

// ── Sub-Widgets ───────────────────────────────────────────────────────────────

class _NotesList extends ConsumerWidget {
  final List<Note> notes;
  final List<SavedItem> savedItems;

  const _NotesList({required this.notes, required this.savedItems});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      color: const Color(0xFF6C63FF),
      backgroundColor: const Color(0xFF1A1D2E),
      onRefresh: () async {
        ref.read(notesProvider.notifier).refresh();
        await ref.read(syncProvider.notifier).triggerSync();
        ref.read(queueProvider.notifier).refresh();
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        itemCount: notes.length,
        itemBuilder: (_, i) {
          final note = notes[i];
          final isSaved = savedItems.any((s) => s.noteId == note.id);
          return NoteCard(
            note: note,
            isSaved: isSaved,
            onSaveToggle: () async {
              await ref.read(savedItemsProvider.notifier).toggleSave(note.id);
              ref.read(queueProvider.notifier).refresh();
            },
          );
        },
      ),
    );
  }
}

class _ConnectivityChip extends StatelessWidget {
  final bool isOnline;
  const _ConnectivityChip({required this.isOnline});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isOnline
            ? Colors.green.withOpacity(0.15)
            : Colors.red.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOnline ? Colors.greenAccent : Colors.redAccent,
          width: 0.6,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isOnline ? Colors.greenAccent : Colors.redAccent,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            isOnline ? 'Online' : 'Offline',
            style: TextStyle(
              color: isOnline ? Colors.greenAccent : Colors.redAccent,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFF3D1A1A),
      child: Row(
        children: [
          const Icon(Icons.wifi_off, color: Colors.redAccent, size: 16),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'No connection — notes are saved locally and will sync automatically',
              style: TextStyle(
                color: Colors.redAccent,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        color: Color(0xFF6C63FF),
        strokeWidth: 2,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: const Color(0xFF6C63FF).withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notes,
              size: 44,
              color: Color(0xFF6C63FF),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No notes yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + New Note to start.\nWorks fully offline with background sync!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.35),
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
