import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:offline_sync_queue/main.dart';

void main() {
  testWidgets('App renders HomeScreen without crashing', (WidgetTester tester) async {
    // Note: Full widget test would require Hive initialisation.
    // This smoke test verifies the widget tree renders without errors
    // when wrapped in ProviderScope.
    await tester.pumpWidget(
      const ProviderScope(
        child: OfflineSyncApp(),
      ),
    );
    // App bar title should be present
    expect(find.text('OfflineSync'), findsOneWidget);
  });
}
