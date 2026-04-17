import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/note.dart';

/// Displays a single note with its sync status badge and bookmark toggle.
class NoteCard extends StatelessWidget {
  final Note note;
  final bool isSaved;
  final VoidCallback onSaveToggle;

  const NoteCard({
    super.key,
    required this.note,
    required this.isSaved,
    required this.onSaveToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: note.isSynced
              ? [const Color(0xFF1C2138), const Color(0xFF191C2E)]
              : [const Color(0xFF221D38), const Color(0xFF1C1A2E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _borderColor(),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          splashColor: Colors.white.withOpacity(0.03),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header Row ─────────────────────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        note.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.1,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _SyncBadge(isSynced: note.isSynced),
                  ],
                ),

                // ── Content Preview ────────────────────────────────────
                if (note.content.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    note.content,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 14,
                      height: 1.5,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                const SizedBox(height: 12),

                // ── Footer Row ─────────────────────────────────────────
                Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 12,
                      color: Colors.white.withOpacity(0.25),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('MMM d, HH:mm').format(note.updatedAt),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.25),
                        fontSize: 11,
                      ),
                    ),

                    // ── Stale Cache Indicator ──────────────────────────
                    if (note.isCacheExpired) ...[
                      const SizedBox(width: 8),
                      _PillBadge(
                        label: 'STALE',
                        color: Colors.orange,
                      ),
                    ],

                    const Spacer(),

                    // ── Bookmark / Save Button ─────────────────────────
                    GestureDetector(
                      onTap: onSaveToggle,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: isSaved
                              ? Colors.pinkAccent.withOpacity(0.12)
                              : Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSaved
                                ? Colors.pinkAccent.withOpacity(0.4)
                                : Colors.transparent,
                            width: 0.6,
                          ),
                        ),
                        child: Icon(
                          isSaved
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          size: 18,
                          color: isSaved
                              ? Colors.pinkAccent
                              : Colors.white.withOpacity(0.35),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _borderColor() {
    if (note.isSynced) return Colors.green.withOpacity(0.2);
    return const Color(0xFF6C63FF).withOpacity(0.25);
  }
}

/// Synced / Pending badge shown in top-right of the card.
class _SyncBadge extends StatelessWidget {
  final bool isSynced;
  const _SyncBadge({required this.isSynced});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isSynced
            ? Colors.green.withOpacity(0.12)
            : const Color(0xFF6C63FF).withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSynced
              ? Colors.green.withOpacity(0.35)
              : const Color(0xFF6C63FF).withOpacity(0.35),
          width: 0.6,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSynced ? Icons.cloud_done_rounded : Icons.cloud_upload_rounded,
            size: 11,
            color: isSynced ? Colors.greenAccent : const Color(0xFF8B84FF),
          ),
          const SizedBox(width: 4),
          Text(
            isSynced ? 'synced' : 'pending',
            style: TextStyle(
              color: isSynced ? Colors.greenAccent : const Color(0xFF8B84FF),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PillBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _PillBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.4), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
