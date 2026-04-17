import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/queue_item.dart';
import '../../models/sync_status.dart';
import '../../state_management/providers.dart';

/// Bottom sheet debug panel showing full queue contents and metrics.
class QueueInspectorSheet extends ConsumerWidget {
  const QueueInspectorSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueState = ref.watch(queueProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1A1D2E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // ── Handle ─────────────────────────────────────────────────
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 4),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // ── Header ─────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 16, 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C63FF).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.analytics_rounded,
                        color: Color(0xFF6C63FF),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Queue Inspector',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    // Retry all failed button
                    if (queueState.items
                        .any((i) => i.status == SyncStatus.failed.value))
                      TextButton.icon(
                        onPressed: () async {
                          await ref.read(syncProvider.notifier).triggerSync();
                          ref.read(queueProvider.notifier).refresh();
                        },
                        icon: const Icon(Icons.refresh_rounded,
                            size: 16, color: Color(0xFF6C63FF)),
                        label: const Text(
                          'Retry All',
                          style: TextStyle(
                            color: Color(0xFF6C63FF),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // ── Stats Row ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    _StatBox(
                        label: 'Total',
                        value: '${queueState.items.length}',
                        color: Colors.white54),
                    const SizedBox(width: 6),
                    _StatBox(
                        label: 'Pending',
                        value: '${queueState.pendingCount}',
                        color: const Color(0xFFFFB74D)),
                    const SizedBox(width: 6),
                    _StatBox(
                        label: 'Synced',
                        value: '${queueState.successCount}',
                        color: const Color(0xFF66BB6A)),
                    const SizedBox(width: 6),
                    _StatBox(
                        label: 'Failed',
                        value: '${queueState.failureCount}',
                        color: const Color(0xFFEF5350)),
                  ],
                ),
              ),

              Divider(color: Colors.white.withOpacity(0.07), height: 1),

              // ── Queue Items List ────────────────────────────────────────
              Expanded(
                child: queueState.items.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              size: 48,
                              color: Colors.greenAccent.withOpacity(0.4),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Queue is empty\nAll caught up! ✓',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.3),
                                fontSize: 15,
                                height: 1.6,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: queueState.items.length,
                        itemBuilder: (_, i) {
                          return _QueueItemTile(item: queueState.items[i]);
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Sub-Widgets ───────────────────────────────────────────────────────────────

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatBox({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.18), width: 0.5),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: color.withOpacity(0.55),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QueueItemTile extends StatelessWidget {
  final QueueItem item;
  const _QueueItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(item.status);
    final icon = _statusIcon(item.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.025),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2), width: 0.5),
      ),
      child: Row(
        children: [
          // Status icon circle
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: 12),

          // Action type + Truncated UUID
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.actionType,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'ID: ${item.id.substring(0, 8)}…',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.3),
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
                Text(
                  DateFormat('HH:mm:ss').format(item.createdAt),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.2),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),

          // Status badge + retry count
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(5),
                  border:
                      Border.all(color: color.withOpacity(0.3), width: 0.5),
                ),
                child: Text(
                  item.status.toUpperCase(),
                  style: TextStyle(
                    color: color,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'retries: ${item.retryCount}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.25),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return const Color(0xFFFFB74D);
      case 'syncing':
        return const Color(0xFF42A5F5);
      case 'failed':
        return const Color(0xFFEF5350);
      case 'succeeded':
        return const Color(0xFF66BB6A);
      default:
        return Colors.white54;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.schedule_rounded;
      case 'syncing':
        return Icons.sync_rounded;
      case 'failed':
        return Icons.error_outline_rounded;
      case 'succeeded':
        return Icons.check_rounded;
      default:
        return Icons.help_outline;
    }
  }
}
