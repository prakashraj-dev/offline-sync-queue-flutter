# AI Prompt Log — OfflineSync Notes

This document records key prompts, outputs, decisions accepted/rejected, and the rationale behind them during the design and implementation of this project.

---

## Prompt 1 — Architecture Design

**Prompt:**
> "You are a senior Flutter engineer building a production-grade Offline-first Sync Queue system. Design the architecture, tech stack, and module breakdown. Justify Riverpod vs Bloc and Hive vs SQLite."

**Key Output:**
- Layer separation: UI → State (Riverpod) → Domain (Notifiers + DAOs) → Infrastructure (Hive + Remote API)
- Riverpod chosen: compile-safe providers, no BuildContext dependency injection, `AsyncValue` for three-state data
- Hive chosen: pure Dart (no native compile issues), key-value boxes map perfectly to queue/notes/saved items

**Accepted:** Full layered architecture, manual TypeAdapters (no build_runner dependency)

**Rejected:**
- `sqflite` — would require schema migrations, JOIN queries overkill for this model
- `Bloc` — more boilerplate, `BlocProvider` tree harder to manage than Riverpod's `ref`
- `code generation` with `riverpod_generator` — adds build_runner step; decided to write StateNotifiers manually for cleaner onboarding

---

## Prompt 2 — Idempotency Design

**Prompt:**
> "Design an idempotency strategy for the sync queue. Retries must never create duplicate Firestore documents. Explain the mechanism clearly."

**Key Output:**
Each action generates a UUID v4 at write time. This UUID serves as both:
1. The `QueueItem.id` in Hive
2. The Firestore document ID on sync

Firestore `set()` with an existing document ID = no-op overwrite. Never creates a duplicate.

**Accepted:** UUID-as-document-ID pattern

**Rejected:**
- Server-side deduplication table (adds server complexity, not needed with Firestore doc ID approach)
- Sequence numbers (not globally unique; collision risk across devices)

---

## Prompt 3 — Retry Strategy

**Prompt:**
> "Design a retry strategy with exponential backoff. Items that fail all retries must not be lost. Retries should resume after app restart."

**Key Output:**
```
maxRetries = 1 (per session)
backoff = 2^attempt seconds
On failure: status=failed, kept in queue
On app launch: resetFailedToPending()
```

**Accepted:** Session-scoped retry with persistence of failed state

**Rejected:**
- Unlimited retries in one session (would block queue processing indefinitely)
- Deleting failed items (would lose user data)
- Simple linear backoff (exponential is more respectful of recovering servers)

---

## Prompt 4 — Hive TypeAdapters

**Prompt:**
> "Write manual Hive TypeAdapters for Note, QueueItem, SavedItem. No build_runner. Document every field index."

**Key Output:**
Hand-written `NoteAdapter`, `QueueItemAdapter`, `SavedItemAdapter` using `BinaryReader`/`BinaryWriter`. Each adapter documents its field index map in comments, making future field additions safe (append-only).

**Accepted:** Manual adapters with documented field indices

**Key Decision:** `QueueItem.payload` stored as JSON string (not `Map<String, dynamic>`) because Hive cannot natively serialize nested maps without a recursive custom adapter.

---

## Prompt 5 — Conflict Resolution

**Prompt:**
> "Design a conflict resolution strategy. Document clearly why you chose it."

**Key Output:**
Last Write Wins (LWW) based on `updatedAt` timestamp. Pre-selected for simplicity and correctness in single-user context.

**Accepted:** LWW with `updatedAt`

**Rejected:**
- CRDTs: overkill for single-user personal notes; adds ~2000 LoC of complexity
- Server-authoritative merge: requires custom Firebase Functions, out of scope
- Manual conflict resolution UI: good for future but over-engineered for initial version

---

## Prompt 6 — Mock Firestore Design

**Prompt:**
> "Design a self-contained mock Firestore service that proves idempotency, supports offline simulation, and failure injection without any real Firebase setup."

**Key Output:**
`MockFirestoreService` with:
- `Map<String, Map>` in-memory collections (notes, saved items)
- `Set<String> _processedIds` for idempotency tracking
- `simulateOffline: bool` flag
- `simulateFailures(n)` method — arms N successive failures

**Accepted:** In-memory mock with explicit idempotency tracking

**Rejected:**
- Storing to disk for mock (adds complexity, defeats the purpose of a mock)
- Fake Firebase using `firebase_app_check_testing` (overkill; mock is cleaner and faster)

---

## Prompt 7 — UI / Observability

**Prompt:**
> "Design a UI that clearly separates cached vs fresh state, shows queue counters, and has a debug panel. Use a premium dark theme."

**Key Output:**
- `SyncStatusBar`: always-visible pending/synced/failed counters with animated state changes
- `QueueInspectorSheet`: bottom sheet showing every queue item, its status, retry count, and UUID prefix
- `_ConnectivityChip`: animated green/red pill in AppBar
- Offline banner: animated cross-fade above content
- `⚗ Science beaker` menu: in-app simulation controls (no need to disable real WiFi)
- Dark glassmorphism theme: `#0F1117` background, `#6C63FF` accent

**Accepted:** All of the above

**Rejected:**
- Separate "debug screen" (bottom sheet is more accessible for live testing)
- Snackbar-only observability (not persistent enough)

---

## Summary of Key Decisions

| Decision | Choice | Rationale |
|---|---|---|
| State Management | Riverpod StateNotifier | Compile-safe, no BuildContext, clean dispose |
| Local DB | Hive + Manual Adapters | Pure Dart, zero build_runner, fast binary |
| Idempotency | UUID = Firestore Doc ID | Firestore set() is inherently idempotent |
| Retry | 1 retry/session, exponential backoff | Durable without infinite blocking |
| Conflict | Last Write Wins | Correct for single-user; CRDT overkill |
| Observability | Structured logs + UI counters | Both developer and user-visible proof |
| Mock vs Real Firebase | Mock (default) | Zero setup; swap via providers.dart |
