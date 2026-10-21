import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:breakfree/main.dart';

void main() {
  const channel = MethodChannel('com.example.breakfree/native');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'getState':
          return <String, dynamic>{
            'mode': 1,
            'quotaMin': 30,
            'usedTodayMs': 60000,
            'serviceEnabled': true,
            'overlayGranted': true,
          };
        default:
          return true;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('Home screen renders and shows level 1 state', (tester) async {
    await tester.pumpWidget(const BreakFreeApp());
    await tester.pump();

    expect(find.text('BreakFree'), findsOneWidget);
    expect(find.text('Level 1 — Daily Limit'), findsOneWidget);
    expect(find.textContaining('Protection active'), findsOneWidget);
    expect(find.textContaining('Used today: 1 min'), findsOneWidget);
  });
}