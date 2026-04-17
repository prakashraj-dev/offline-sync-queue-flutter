import 'package:flutter/foundation.dart';

/// Real-time sync queue counters exposed as a [ChangeNotifier].
///
/// The [QueueNotifier] (Riverpod) listens to this via addListener()
/// and rebuilds the UI whenever counters change.
class QueueMetrics extends ChangeNotifier {
  int _pendingCount = 0;
  int _successCount = 0;
  int _failureCount = 0;

  int get pendingCount => _pendingCount;
  int get successCount => _successCount;
  int get failureCount => _failureCount;

  void setPending(int count) {
    _pendingCount = count;
    notifyListeners();
  }

  void incrementSuccess() {
    _successCount++;
    if (_pendingCount > 0) _pendingCount--;
    notifyListeners();
  }

  void incrementFailure() {
    _failureCount++;
    if (_pendingCount > 0) _pendingCount--;
    notifyListeners();
  }

  void reset() {
    _pendingCount = 0;
    _successCount = 0;
    _failureCount = 0;
    notifyListeners();
  }
}
