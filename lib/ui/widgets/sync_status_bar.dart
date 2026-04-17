import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state_management/providers.dart';

/// Persistent status bar showing queue counters and sync activity.
class SyncStatusBar extends ConsumerWidget {
  const SyncStatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueState = ref.watch(queueProvider);
    final syncState = ref.watch(syncProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF13162A),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
      ),
      child: Row(
        children: [
          // ── Pending Counter ──────────────────────────────────────────
          _MetricChip(
            label: 'Pending',
            count: queueState.pendingCount,
            color: const Color(0xFFFFB74D),
            icon: Icons.schedule_rounded,
          ),
          const SizedBox(width: 6),

          // ── Success Counter ──────────────────────────────────────────
          _MetricChip(
            label: 'Synced',
            count: queueState.successCount,
            color: const Color(0xFF66BB6A),
            icon: Icons.check_circle_outline_rounded,
          ),
          const SizedBox(width: 6),

          // ── Failure Counter ──────────────────────────────────────────
          _MetricChip(
            label: 'Failed',
            count: queueState.failureCount,
            color: const Color(0xFFEF5350),
            icon: Icons.error_outline_rounded,
          ),

          const Spacer(),

          // ── Sync Activity / Last Sync ──────────────────────────────
          if (syncState.isSyncing)
            Row(
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: const Color(0xFF6C63FF).withOpacity(0.7),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Syncing…',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 11,
                  ),
                ),
              ],
            )
          else if (syncState.lastSyncTime != null)
            Text(
              'Last sync: ${_timeAgo(syncState.lastSyncTime!)}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.25),
                fontSize: 11,
              ),
            )
          else
            Text(
              'Not synced yet',
              style: TextStyle(
                color: Colors.white.withOpacity(0.2),
                fontSize: 11,
              ),
            ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  const _MetricChip({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(count > 0 ? 0.10 : 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(count > 0 ? 0.30 : 0.10),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color.withOpacity(count > 0 ? 0.9 : 0.4)),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: TextStyle(
              color: color.withOpacity(count > 0 ? 1.0 : 0.4),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color.withOpacity(count > 0 ? 0.7 : 0.35),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
