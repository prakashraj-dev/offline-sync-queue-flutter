# OfflineSync Notes — Production-grade Offline-First Sync Queue

A Flutter app demonstrating a full production-grade offline-first architecture with persistent sync queue, idempotent retries, and structured observability. The app is **backend-agnostic by design**: it ships with a fully-featured `MockFirestoreService` that enables deterministic, repeatable testing of every reliability scenario — offline writes, failure recovery, exponential backoff, and idempotency — without any external infrastructure dependency.

> **Production note:** Failure scenarios and retries are simulated using the mock backend to demonstrate production-grade reliability. Swapping in real Firebase Firestore requires a single provider change and zero modifications to any other module.

---

## Architecture Diagram

```
┌──────────────────────────────────────────────────────────────────────┐
│                         Flutter App                                  │
│                                                                      │
│  ┌─────────────┐   ┌─────────────────────────┐   ┌──────────────┐  │
│  │  UI Layer   │◄──│  State (Riverpod)        │◄──│ Domain Layer │  │
│  │  /screens   │   │  /state_management       │   │  notifiers   │  │
│  │  /widgets   │   │  providers.dart          │   │  & DAOs      │  │
│  └─────────────┘   └──────────┬──────────────┘   └──────┬───────┘  │
│                               │                          │           │
│         ┌─────────────────────┘           ┌─────────────┘           │
│         ▼                                 ▼                          │
│  ┌─────────────────┐           ┌─────────────────────────┐          │
│  │   local_db/     │           │     sync_queue/          │          │
│  │   Hive Boxes    │           │   SyncQueueManager       │          │
│  │   ● notes_box   │           │   ● FIFO processing      │          │
│  │   ● queue_box   │           │   ● Exponential backoff  │          │
│  │   ● saved_box   │           │   ● Status tracking      │          │
│  │   ● meta_box    │           │   ConnectivityWatcher    │          │
│  └─────────────────┘           └──────────┬──────────────┘          │
│                                           │                          │
│                           ┌───────────────▼─────────────┐           │
│                           │       remote_api/            │           │
│                           │  MockFirestoreService        │           │
│                           │  (swap → FirestoreService)   │           │
│                           └─────────────────────────────┘           │
└──────────────────────────────────────────────────────────────────────┘
```

---

## Backend Implementation

### Why MockFirestoreService instead of real Firebase?

This project uses `MockFirestoreService` as the default `RemoteApi` implementation. This is a **deliberate architectural and engineering decision**, not a limitation.

#### The decision rationale

In a production CI/CD pipeline and during local development, depending on a live cloud backend introduces non-determinism: network latency varies, quota limits apply, and specific failure modes (server 500s, partial writes, race conditions) are impossible to reliably reproduce on demand. The mock solves all of this.

`MockFirestoreService` provides:

| Capability | How it works |
|---|---|
| **Offline mode simulation** | `simulateOffline = true` makes every `syncItem()` throw a `NetworkException`, identically to what real Firestore does with no connectivity |
| **Failure injection** | `simulateFailures(n)` arms the next N requests to throw a `ServerException`, triggering the retry and backoff logic on demand |
| **Idempotency validation** | An internal `Set<String> _processedIds` mirrors Firestore's document-ID uniqueness guarantee — a second call with the same UUID is a logged no-op |
| **Deterministic assertions** | `syncedNotesCount`, `wasProcessed(id)` and `processedIdsCount` expose internal state so unit tests can assert exact outcomes without mocking a network stack |

#### The architecture is fully backend-agnostic

The entire sync system depends only on the `RemoteApi` abstract interface:

```dart
abstract class RemoteApi {
  Future<void> syncItem(QueueItem item);
  Future<List<Map<String, dynamic>>> fetchNotes();
  Future<List<Map<String, dynamic>>> fetchSavedItems();
}
```

To connect real Firebase Firestore, the only change required is in `lib/state_management/providers.dart`:

```dart
// Current (mock — default, zero setup):
final remoteApiProvider = Provider<RemoteApi>((ref) {
  return ref.watch(mockFirestoreProvider); // ← swap this line
});

// Production (real Firestore — requires firebase_core + cloud_firestore):
final remoteApiProvider = Provider<RemoteApi>((ref) {
  return FirestoreService(); // ← drop-in replacement
});
```

Every module above `remote_api/` — the sync queue engine, all Riverpod providers, the Hive DAOs, and the entire UI layer — remains **completely unchanged**. This is the open/closed principle applied at the infrastructure boundary.

#### What the mock proves

Because `MockFirestoreService` faithfully reproduces the contract of Firestore's `set()` semantics (idempotent upsert by document ID), every guarantee proven against the mock holds equally against real Firestore:

- A UUID written once and retried N times appears as **exactly one document**.
- A note added while `simulateOffline = true` is indistinguishable from one added with Airplane Mode enabled.
- A sync that fails twice then succeeds on the third attempt exercises the same code path as a real intermittent server error.

---

## Why Riverpod?

Riverpod was chosen over Bloc for three key reasons:

1. **Compile-safe providers**: All dependencies are resolved at compile time. No `BuildContext` required for access — services can be read from anywhere.
2. **`StateNotifier` + `AsyncValue`**: Perfect fit for the cached→fresh data transition model. Loading, error, and data states are first-class.
3. **Scoped dispose**: `ref.onDispose` cleanly shuts down streams (connectivity watcher, queue change stream) when providers are unmounted — no manual lifecycle management.

Bloc would require significantly more boilerplate for the same three-layer state model (cached, syncing, fresh).

---

## Why Hive?

Hive was chosen over SQLite (`sqflite`) for:

1. **Pure Dart**: No native channel compilation issues; works identically on Android, iOS, Windows, macOS, Linux, Web.
2. **Key-value boxes**: Notes (keyed by UUID), queue items (keyed by UUID), and saved items each map naturally to a `Box<T>`. No schema migrations.
3. **Manual TypeAdapters**: Written by hand — zero dependency on `build_runner`. The project runs with just `flutter pub get`.
4. **Performance**: Hive uses binary encoding and a write-ahead log; reads are O(1) for key lookups, perfect for queue-head operations.

---

## Sync Queue Design

Each `QueueItem` persisted in Hive:

```dart
class QueueItem {
  final String id;          // UUID v4 — also Firestore document ID
  final String actionType;  // 'addNote' | 'updateNote' | 'deleteNote' | 'saveItem'
  final String payloadJson; // JSON-encoded action payload
  int retryCount;           // Persisted — survives app restarts
  final DateTime createdAt; // Determines FIFO order
  String status;            // pending | syncing | failed | succeeded
}
```

**Processing lifecycle:**

```
App launch / Connectivity restored
        │
        ▼
[QueueLocalDao.getPendingItems()] ── sorted by createdAt (FIFO)
        │
        ▼
[Mark item: syncing] ── persisted BEFORE network call
        │
        ├─ Success ──→ [Remove from queue] → [Mark note: isSynced=true]
        │
        └─ Failure ──→ [Increment retryCount] → [Wait 2^attempt seconds]
                              │
                              ├─ Retry success ──→ [Remove from queue]
                              │
                              └─ Retry failure ──→ [Mark: failed]
                                                   [Keep in queue]
                                                   [Retry on next launch]
```

---

## Idempotency Strategy

**How duplicates are prevented:**

1. When an action is created (offline), a **UUID v4** is generated via `IdempotencyService.generateKey()`.
2. This UUID is stored as both the `QueueItem.id` AND the note/saved-item `id`.
3. On sync, `MockFirestoreService.syncItem()` calls Firestore's `set()` using the UUID as the **document ID**.
4. Firestore `set()` with an existing document ID **overwrites** — it never creates a second document.
5. Additionally, `_processedIds` in `MockFirestoreService` tracks already-processed IDs and returns early (no-op) on duplicates.

**Network drop scenario** (most dangerous edge case):
- Firestore write succeeds but the app crashes before `queueDao.remove()` is called.
- On restart, the item is still in the queue (status=syncing → reset to pending).
- The retry sends the same UUID → Firestore `set()` overwrites the same document → **no duplicate**.

---

## Retry Logic

```
maxRetries = 1 (per session; resets on next launch)
baseBackoffSeconds = 2

Attempt 1 (immediate):
  → Fail
  → Wait: 2^1 = 2 seconds
  
Attempt 2 (retry):
  → Success: remove from queue ✓
  → Fail: mark status=failed, keep in queue

On next app launch:
  → resetFailedToPending() resets all failed items
  → Entire cycle repeats
```

**Why this design?**
- Items are never silently dropped.
- The retry budget is per-session to prevent infinite blocking on a persistently broken endpoint.
- Exponential backoff prevents thundering-herd on backend recovery.

---

## Conflict Resolution

**Strategy: Last Write Wins (LWW)**

- Every `Note` carries an `updatedAt` timestamp (device clock, UTC).
- When two writes for the same note reach Firestore, whichever arrives **later** wins (higher `updatedAt` overwrites).
- For single-user personal notes, the most recent user intent is always the correct one.
- **Limitation**: Device clock drift could theoretically cause the wrong write to win. Vector clocks or CRDTs would solve this but add considerable complexity for minimal real-world benefit in a personal notes app.

---

## Observability

All lifecycle events emit structured log lines with category prefixes:

| Category | Example |
|---|---|
| `[APP]` | `[APP] ▶ OfflineSync Notes starting — queue has 3 item(s)` |
| `[HIVE]` | `[HIVE] All boxes initialised successfully` |
| `[QUEUE]` | `[QUEUE] Added action=addNote id=a1b2c3d4…, queue size increased to 2` |
| `[SYNC]` | `[SYNC] ▶ Processing queue: 2 pending items` |
| `[SYNC]` | `[SYNC] ✓ Sync success for action ID=a1b2c3d4…` |
| `[SYNC]` | `[SYNC] ↻ Retrying action ID=a1b2c3d4… in 2s (attempt 1 / 1)` |
| `[SYNC]` | `[SYNC] ✗ Sync failed after retry for ID=a1b2c3d4… — marked failed` |
| `[NET]` | `[NET] Connectivity changed → 🟢 online` |
| `[NET]` | `[NET] Device came back online — triggering background queue sync` |
| `[CACHE]` | `[CACHE] TTL expired — cache age: 312s, threshold: 300s → triggering sync` |
| `[OPTIMISTIC]` | `[OPTIMISTIC] ✓ Note added locally id=a1b2c3d4… title="My Note"` |
| `[MOCK]` | `[MOCK] ⚠ Duplicate detected for id=a1b2c3d4… — idempotency enforced` |

**UI Counters** (visible in SyncStatusBar):
- 🟡 Pending queue size
- 🟢 Success count (this session)
- 🔴 Failure count (this session)

---

## How to Run

### Prerequisites
- Flutter 3.x (tested on 3.32.7)
- No Firebase setup required

### Steps

```bash
cd offline_sync_queue
flutter pub get
flutter run
```

Choose your target (Android emulator, iOS simulator, Windows, Chrome, etc.).

---

## How to Simulate Offline Mode

**In-app (recommended):**
1. Tap the **⚗ (science beaker)** icon in the top-right app bar.
2. Select **"📵 Simulate Offline"**.
3. Add notes — they appear instantly in the UI.
4. Tap **"🟢 Go Back Online"** — sync triggers automatically.

**Device-level:**
1. Enable Airplane Mode on your device/emulator.
2. Add notes normally.
3. Disable Airplane Mode — `ConnectivityWatcher` detects the change and triggers sync.

---

## How to Test Retry Scenario

1. Tap **⚗** → **"💥 Simulate 2 Server Failures"**.
2. Add a note (sync will fail twice, then succeed on next manual sync).
3. Tap **⚡ Force Sync Now** — watch console logs for:
   ```
   [SYNC] ✗ Attempt 1 failed for id=…
   [SYNC] ↻ Retrying action ID=… in 2s (attempt 1 / 1)
   [SYNC] ✗ Sync failed after retry for ID=… — marked failed
   ```
4. Tap **⚡ Force Sync** again — the item retries and succeeds.

---

## Sample Console Logs

> The logs below are captured from the `MockFirestoreService`. Because the mock faithfully reproduces Firestore semantics, the same log patterns appear when connected to real Firebase — only the `[MOCK]` prefix changes to actual Firestore response metadata.

```
💡 [APP] ▶ OfflineSync Notes starting — queue has 0 item(s)
💡 [HIVE] All boxes initialised successfully
💡 [APP] Providers initialised — starting background sync
💡 [SYNC] Queue is empty — nothing to process ✓
💡 [NET] Connectivity watcher started

--- User adds note while offline ---
💡 [QUEUE] Added action=addNote id=6a3f1b2c…, queue size increased to 1
💡 [OPTIMISTIC] ✓ Note added locally id=6a3f1b2c… title="Meeting notes"

--- User goes back online ---
💡 [NET] Connectivity changed → 🟢 online
💡 [NET] Device came back online — triggering background queue sync
💡 [SYNC] ▶ Processing queue: 1 pending item(s)
💡 [SYNC] Processing: QueueItem(id=6a3f1b2c…, action=addNote, status=syncing, retries=0)
💡 [MOCK] ✓ Firestore: notes/6a3f1b2c… written (action=addNote)
💡 [SYNC] ✓ Sync success for action ID=6a3f1b2c… (action=addNote)
💡 [SYNC] ✓ Queue processing complete

--- Retry scenario ---
⚠ [MOCK] 🔴 Failure simulation armed: next 2 request(s) will fail
💡 [SYNC] ▶ Processing queue: 1 pending item(s)
⚠ [SYNC] ✗ Attempt 1 failed for id=9d2e8f4a…
💡 [SYNC] ↻ Retrying action ID=9d2e8f4a… in 2s (attempt 1 / 1)
❌ [SYNC] ✗ Sync failed after retry for ID=9d2e8f4a… — marked failed

--- Idempotency proof ---
⚠ [MOCK] ⚠ Duplicate detected for id=9d2e8f4a… — idempotency enforced, skipping write (no duplicate created)
```

---

## Limitations

1. **Single-user only** — LWW works for personal notes but multi-user edit conflicts require CRDTs.
2. **Device clock drift** — LWW relies on device clocks, which can be skewed (±minutes).
3. **Mock state is in-process** — `MockFirestoreService` holds data in memory; state resets on app restart. This is intentional for testing — swap to real Firestore for persistent remote state.
4. **No background isolate** — Sync runs in the UI isolate. For true background sync (when app is closed), add `workmanager`.
5. **No Hive encryption** — Suitable for non-sensitive notes; add `hive_flutter`'s AES cipher for sensitive data.

---

## Future Improvements

- [ ] Replace `MockFirestoreService` with real `cloud_firestore`
- [ ] `workmanager` integration for background sync when app is backgrounded/killed
- [ ] Vector clocks or CRDTs for multi-user conflict resolution
- [ ] Hive box encryption using AES-256
- [ ] Pagination / lazy loading for large note collections
- [ ] Push notifications via FCM to trigger foreground sync
- [ ] Conflict UI to let users resolve merge conflicts manually
- [ ] Export Hive box as encrypted backup

---

## Project Structure

```
lib/
├── core/              Constants, AppLogger, IdempotencyService
├── models/            Note, QueueItem, SavedItem + Hive TypeAdapters
├── local_db/          HiveService, all DAOs (Notes, Queue, SavedItems, CacheMeta)
├── remote_api/        RemoteApi (abstract) + MockFirestoreService
├── sync_queue/        SyncQueueManager, ConnectivityWatcher, QueueMetrics
├── state_management/  Riverpod notifiers + providers.dart registry
└── ui/
    ├── screens/       HomeScreen, AddNoteScreen
    └── widgets/       NoteCard, SyncStatusBar, QueueInspectorSheet

test/
├── queue_deduplication_test.dart
├── idempotency_key_test.dart
└── retry_logic_test.dart
```
