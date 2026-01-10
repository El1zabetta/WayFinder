// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:way_finder/main.dart';

void main() {
  testWidgets('App initialization smoke test', (WidgetTester tester) async {
    // 1. Build our app
    await tester.pumpWidget(const VisionApp());
    
    // 2. Advance time by 5 seconds to clear the 3-second SplashScreen timer
    // and wait for any initial animations to run.
    await tester.pump(const Duration(seconds: 5));

    // 3. Verify that the app structure is present
    expect(find.byType(VisionApp), findsOneWidget);

    // 4. Clean up the widget tree and trigger dipose()
    await tester.pumpWidget(Container());
    await tester.pump(const Duration(seconds: 1));
  });
}
